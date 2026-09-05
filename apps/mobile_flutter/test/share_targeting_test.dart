import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/native/share_targeting.dart';

void main() {
  const catalog = [
    ShareTarget(serverInstanceId: 'inst-a', assistantId: 'asst-1', name: 'A1'),
    ShareTarget(serverInstanceId: 'inst-b', assistantId: 'asst-2', name: 'B2'),
  ];

  test('honors exact instance+assistant and never defaults', () {
    expect(
      exactShareTarget(catalog: catalog, serverInstanceId: 'inst-a', assistantId: 'asst-1')?.name,
      'A1',
    );
    expect(exactShareTarget(catalog: catalog, serverInstanceId: 'inst-a', assistantId: 'asst-2'), isNull);
    expect(exactShareTarget(catalog: catalog, serverInstanceId: 'inst-a', assistantId: null), isNull);
    expect(exactShareTarget(catalog: catalog), isNull);
  });
}
