import 'package:flutter/material.dart';

import '../../data/app_controller.dart';
import '../../data/instance_store.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

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
  bool _requiresPassword = false;

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Text(t(context, 'connect.welcome.title'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(t(context, 'connect.welcome.description'), style: TextStyle(color: OcTokens.mutedLight)),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('connect-scan-qr'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t(context, 'connect.qr.todo'))),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(t(context, 'connect.scanQr')),
            ),
            const SizedBox(height: 8),
            Text(t(context, 'connect.scanHint'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            TextButton(
              key: const Key('connect-manual-toggle'),
              onPressed: () => setState(() => _manualOpen = !_manualOpen),
              child: Text(t(context, 'connect.manual.toggle')),
            ),
            if (_manualOpen) ...[
              const SizedBox(height: 8),
              Text(t(context, 'connect.address.divider')),
              const SizedBox(height: 8),
              TextField(
                key: const Key('connect-url'),
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: t(context, 'connect.url.label'),
                  hintText: t(context, 'connect.url.placeholder'),
                ),
              ),
              TextField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: t(context, 'connect.label.label'),
                  hintText: t(context, 'connect.label.placeholder'),
                ),
              ),
              TextField(
                key: const Key('connect-token'),
                controller: _token,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t(context, 'connect.token.label'),
                  hintText: t(context, 'connect.token.placeholder'),
                  helperText: t(context, 'connect.token.hint'),
                ),
              ),
              TextField(
                key: const Key('connect-pairing'),
                controller: _pairing,
                decoration: InputDecoration(
                  labelText: t(context, 'connect.link.label'),
                  hintText: t(context, 'connect.link.placeholder'),
                ),
              ),
              SwitchListTile(
                key: const Key('connect-requires-password'),
                contentPadding: EdgeInsets.zero,
                title: Text(t(context, 'connect.requiresPassword')),
                value: _requiresPassword,
                onChanged: (value) => setState(() => _requiresPassword = value),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('connect-submit'),
                onPressed: controller.connecting
                    ? null
                    : () => controller.connect(
                          url: _url.text,
                          label: _label.text,
                          clientToken: _token.text,
                          pairingLink: _pairing.text,
                          requiresPassword: _requiresPassword,
                        ),
                child: Text(
                  controller.connecting ? t(context, 'connect.connecting') : t(context, 'connect.connectButton'),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(t(context, error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 28),
            Text(t(context, 'connect.saved.title'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (controller.instances.isEmpty)
              Text(t(context, 'connect.saved.empty'))
            else
              ...controller.instances.map(_savedTile),
          ],
        ),
      ),
    );
  }

  Widget _passwordView(BuildContext context) {
    final pending = controller.pendingUnlock;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'connect.password.label')),
        leading: IconButton(
          key: const Key('connect-cancel-password'),
          tooltip: t(context, 'connect.cancelPassword'),
          onPressed: controller.cancelPassword,
          icon: const Icon(Icons.close),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pending != null) Text(pending.displayLabel),
            const SizedBox(height: 16),
            TextField(
              key: const Key('connect-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t(context, 'connect.password.label'),
                hintText: t(context, 'connect.password.placeholder'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('connect-unlock'),
              onPressed: () => controller.unlockWithPassword(_password.text),
              child: Text(t(context, 'connect.unlockButton')),
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
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}
