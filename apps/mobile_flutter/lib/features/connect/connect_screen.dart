import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/instance_store.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ios_chrome.dart';
import '../../theme/oc_glyphs.dart';

/// Capacitor connection onboarding — not a local PIN / Face ID lock.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _url = TextEditingController();
  final _label = TextEditingController();
  final _token = TextEditingController();
  final _pairing = TextEditingController();
  final _password = TextEditingController();
  bool _manualOpen = true;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    _token.dispose();
    _pairing.dispose();
    _password.dispose();
    super.dispose();
  }

  AppController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.connectForm == ConnectForm.password) {
          return _passwordView(context);
        }
        return _welcomeView(context);
      },
    );
  }

  Widget _welcomeView(BuildContext context) {
    final error = controller.connectErrorKey;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
              child: Text(
                t(context, 'connect.welcome.title'),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
              child: Text(
                t(context, 'connect.welcome.description'),
                style: const TextStyle(fontSize: 15, color: OcChrome.secondary, height: 1.35),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
              child: FilledButton.icon(
                key: const Key('connect-scan-qr'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: controller.scanAndConnect,
                icon: const OcGlyph(OcGlyphKind.qr, size: 20, color: Colors.white),
                label: Text(t(context, 'connect.scanQr')),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
              child: Text(t(context, 'connect.scanHint'), style: const TextStyle(fontSize: 13, color: OcChrome.secondary)),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('connect-manual-toggle'),
              onPressed: () => setState(() => _manualOpen = !_manualOpen),
              child: Text(t(context, 'connect.manual.toggle')),
            ),
            if (_manualOpen) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(OcChrome.pageGutter, 4, OcChrome.pageGutter, 8),
                child: Text(
                  t(context, 'connect.address.divider'),
                  style: const TextStyle(fontSize: 13, color: OcChrome.secondary, fontWeight: FontWeight.w500),
                ),
              ),
              GroupedInsetCard(
                child: Column(
                  children: [
                    InsetTextField(
                      fieldKey: const Key('connect-url'),
                      controller: _url,
                      label: t(context, 'connect.url.label'),
                      hint: t(context, 'connect.url.placeholder'),
                      keyboardType: TextInputType.url,
                    ),
                    const Divider(height: 1, indent: 16),
                    InsetTextField(
                      controller: _label,
                      label: t(context, 'connect.label.label'),
                      hint: t(context, 'connect.label.placeholder'),
                    ),
                    const Divider(height: 1, indent: 16),
                    InsetTextField(
                      fieldKey: const Key('connect-token'),
                      controller: _token,
                      label: t(context, 'connect.token.label'),
                      hint: t(context, 'connect.token.placeholder'),
                      helper: t(context, 'connect.token.hint'),
                      obscureText: true,
                    ),
                    const Divider(height: 1, indent: 16),
                    InsetTextField(
                      fieldKey: const Key('connect-pairing'),
                      controller: _pairing,
                      label: t(context, 'connect.link.label'),
                      hint: t(context, 'connect.link.placeholder'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: FilledButton(
                  key: const Key('connect-submit'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: controller.connecting
                      ? null
                      : () => controller.connect(
                            url: _url.text,
                            label: _label.text,
                            clientToken: _token.text,
                            pairingLink: _pairing.text,
                          ),
                  child: Text(
                    controller.connecting ? t(context, 'connect.connecting') : t(context, 'connect.connectButton'),
                  ),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: Text(t(context, error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
              child: Text(t(context, 'connect.saved.title'), style: const TextStyle(fontSize: 13, color: OcChrome.secondary)),
            ),
            const SizedBox(height: 8),
            if (controller.instances.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: Text(t(context, 'connect.saved.empty'), style: const TextStyle(color: OcChrome.secondary)),
              )
            else
              GroupedInsetCard(
                child: Column(
                  children: controller.instances.map(_savedTile).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _passwordView(BuildContext context) {
    final pending = controller.pendingUnlock;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircularChromeButton(
                  key: const Key('connect-cancel-password'),
                  glyph: OcGlyphKind.xmark,
                  tooltip: t(context, 'connect.cancelPassword'),
                  onPressed: controller.cancelPassword,
                ),
              ),
            ),
            LargeTitleHeader(title: t(context, 'connect.password.label')),
            if (pending != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
                child: Text(pending.displayLabel),
              ),
            GroupedInsetCard(
              child: InsetTextField(
                fieldKey: const Key('connect-password'),
                controller: _password,
                label: t(context, 'connect.password.label'),
                hint: t(context, 'connect.password.placeholder'),
                obscureText: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OcChrome.pageGutter),
              child: FilledButton(
                key: const Key('connect-unlock'),
                onPressed: () => controller.unlockWithPassword(_password.text),
                child: Text(t(context, 'connect.unlockButton')),
              ),
            ),
            TextButton(
              onPressed: controller.cancelPassword,
              child: Text(t(context, 'connect.cancelPassword')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedTile(SavedInstance instance) {
    return ListTile(
      key: Key('saved-instance-${instance.id}'),
      title: Text(instance.displayLabel),
      subtitle: Text(instance.relayUrl == null ? instance.url : t(context, 'connect.relay.badge')),
      onTap: () => controller.activateExisting(instance.id),
      trailing: IconButton(
        tooltip: t(context, 'connect.delete'),
        onPressed: () => controller.deleteInstance(instance.id),
        icon: const OcGlyph(OcGlyphKind.xmark, size: 18, color: Color(0xFFFF3B30)),
      ),
    );
  }
}
