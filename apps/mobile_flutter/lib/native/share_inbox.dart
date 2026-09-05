import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/share_delivery.dart';
import '../native/share_targeting.dart';
import 'platform_channels.dart';

/// Native OpenChamberShare: official `listPending` / `ack` / `releaseFiles`
/// / `listDrafts` / `cancelDraft` / `updateCatalog`.
class ShareInbox {
  ShareInbox({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(OpenChamberChannels.share);

  final MethodChannel _channel;

  void listen(void Function() onChange) {
    if (BindingBase.debugBindingType() == null) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shareReceived' || call.method == 'shareDraftReceived') {
        onChange();
      }
      return null;
    });
  }

  Future<void> updateCatalog(List<ShareTarget> entries) async {
    try {
      await _channel
          .invokeMethod<void>('updateCatalog', entries.map((entry) => entry.toNativeEntry()).toList())
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<List<NativeShareEnvelope>> listPending() async {
    try {
      final value = await _channel.invokeMethod<dynamic>('listPending').timeout(const Duration(seconds: 2));
      return _envelopesFrom(value);
    } on MissingPluginException {
      return _listPendingLegacy();
    } catch (_) {
      return _listPendingLegacy();
    }
  }

  Future<List<NativeShareEnvelope>> _listPendingLegacy() async {
    try {
      final value = await _channel.invokeMethod<dynamic>('pending').timeout(const Duration(seconds: 2));
      return _envelopesFrom(value);
    } catch (_) {
      return const [];
    }
  }

  Future<List<NativeShareDraft>> listDrafts() async {
    try {
      final value = await _channel.invokeMethod<dynamic>('listDrafts').timeout(const Duration(seconds: 2));
      return _draftsFrom(value);
    } catch (_) {
      return const [];
    }
  }

  Future<void> ack(String operationID) async {
    await _invokeEither('ack', 'acknowledge', {'operationID': operationID});
  }

  Future<void> releaseFiles(String operationID) async {
    try {
      await _channel.invokeMethod<void>('releaseFiles', {'operationID': operationID}).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> cancelDraft(String draftID) async {
    try {
      await _channel.invokeMethod<void>('cancelDraft', {'draftID': draftID}).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _invokeEither(String primary, String fallback, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(primary, args).timeout(const Duration(seconds: 2));
    } on MissingPluginException {
      await _channel.invokeMethod<void>(fallback, args).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  List<NativeShareEnvelope> _envelopesFrom(Object? value) {
    final rows = _rows(value, 'envelopes');
    return rows.map(parseShareEnvelope).whereType<NativeShareEnvelope>().toList();
  }

  List<NativeShareDraft> _draftsFrom(Object? value) {
    final rows = _rows(value, 'drafts');
    return rows.map(parseShareDraft).whereType<NativeShareDraft>().toList();
  }

  List<Object?> _rows(Object? value, String key) {
    if (value is List) return value;
    if (value is Map) {
      final nested = value[key];
      if (nested is List) return nested;
    }
    return const [];
  }
}

/// In-memory inbox for tests. Never talks to a plugin.
class MemoryShareInbox extends ShareInbox {
  MemoryShareInbox() : super(channel: const MethodChannel('openchamber/share-memory'));

  final List<NativeShareEnvelope> pending = [];
  final List<NativeShareDraft> drafts = [];
  final List<ShareTarget> catalog = [];
  final List<String> acked = [];
  final List<String> released = [];
  final List<String> cancelled = [];

  @override
  void listen(void Function() onChange) {}

  @override
  Future<void> updateCatalog(List<ShareTarget> entries) async {
    catalog
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<List<NativeShareEnvelope>> listPending() async => List.unmodifiable(pending);

  @override
  Future<List<NativeShareDraft>> listDrafts() async => List.unmodifiable(drafts);

  @override
  Future<void> ack(String operationID) async {
    acked.add(operationID);
    pending.removeWhere((item) => item.operationID == operationID);
  }

  @override
  Future<void> releaseFiles(String operationID) async {
    released.add(operationID);
    pending.removeWhere((item) => item.operationID == operationID);
  }

  @override
  Future<void> cancelDraft(String draftID) async {
    cancelled.add(draftID);
    drafts.removeWhere((item) => item.draftID == draftID);
  }
}
