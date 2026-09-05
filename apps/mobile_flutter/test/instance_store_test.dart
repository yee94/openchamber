import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/instance_store.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/openchamber_http.dart';
import 'package:openchamber/data/secure_store.dart';

void main() {
  test('validateServerUrl allows LAN http', () {
    expect(validateServerUrl('http://192.168.1.74:2606'), isNull);
    expect(validateServerUrl('https://example.test'), isNull);
    expect(validateServerUrl('ftp://x'), 'connect.error.invalidUrl');
    expect(validateServerUrl(''), 'connect.error.urlRequired');
  });

  test('parsePairingLink reads openchamber://connect?v=2&p=', () {
    final parsed = parsePairingLink('openchamber://connect?v=2&p=payload');
    expect(parsed, isNotNull);
    expect(parsed!.isV2, isTrue);
    expect(parsed.payload, 'payload');
    expect(parsePairingLink('https://example.test'), isNull);
  });

  test('connect persists instance and delete-active returns to connect', () async {
    final store = MemorySecureStore();
    final controller = AppController(store: store);
    await controller.bootstrap(skipDelay: true);
    expect(controller.phase, AppPhase.connect);

    final ok = await controller.connect(url: 'http://192.168.1.74:2606', label: 'lan');
    expect(ok, isTrue);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeInstance?.url, 'http://192.168.1.74:2606');
    expect(store.snapshot.containsKey(instancesStorageKey), isTrue);

    await controller.deleteInstance(controller.activeInstance!.id);
    expect(controller.phase, AppPhase.connect);
    expect(controller.activeInstance, isNull);
  });

  test('password unlock is instance UI password, not a local PIN', () async {
    final transport = MemoryOpenChamberTransport()..auth = {'authenticated': false, 'locked': true};
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: transport),
    );
    await controller.bootstrap(skipDelay: true);
    final opened = await controller.connect(url: 'http://10.0.0.8:2606');
    expect(opened, isFalse);
    expect(controller.connectForm, ConnectForm.password);
    expect(controller.phase, AppPhase.connect);

    final unlocked = await controller.unlockWithPassword('ui-password');
    expect(unlocked, isTrue);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeInstance?.clientToken, 'oc_client_test');
  });

  test('auto-connects last instance after token hydrate', () async {
    final store = MemorySecureStore();
    final instance = const SavedInstance(
      id: 'inst-last',
      url: 'http://192.168.1.74:2606',
      label: 'lan',
      lastUsedAt: 9,
    );
    await InstanceRepository(store).persist(InstanceSnapshot(instances: [instance], activeId: instance.id));
    await store.write(
      tokenStorageKey(connectionKeyFor(url: instance.url)),
      'oc_client_test',
    );
    final controller = AppController(store: store);
    await controller.bootstrap(skipDelay: true);
    expect(controller.phase, AppPhase.shell);
    expect(controller.activeInstance?.id, 'inst-last');
    expect(controller.activeInstance?.clientToken, 'oc_client_test');
  });
}
