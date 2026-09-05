import 'package:flutter_test/flutter_test.dart';
import 'package:openchamber/data/app_controller.dart';
import 'package:openchamber/data/oauth.dart';
import 'package:openchamber/data/openchamber_api.dart';
import 'package:openchamber/data/secure_store.dart';
import 'package:openchamber/native/deep_link.dart';
import 'package:openchamber/native/external_browser.dart';

void main() {
  test('parses provider and MCP openchamber callback query strings', () {
    final provider = parseOAuthCallbackUri('openchamber://oauth/callback?code=prov-code&state=st-1&server=lan');
    expect(provider.hasCode, isTrue);
    expect(provider.code, 'prov-code');
    expect(provider.state, 'st-1');
    expect(provider.server, 'lan');
    expect(provider.error, isNull);

    final mcp = parseOAuthCallbackUri(
      'openchamber://mcp/oauth/callback?code=mcp%2Fcode&state=mcp-state-1',
    );
    expect(mcp.hasCode, isTrue);
    expect(mcp.code, 'mcp/code');
    expect(mcp.state, 'mcp-state-1');

    expect(isOAuthCallbackLink('openchamber://oauth/callback?code=abc'), isTrue);
    expect(isOAuthCallbackLink('openchamber://mcp/oauth/callback?code=x&state=s'), isTrue);
    expect(classifyDeepLink('openchamber://oauth/callback?code=abc').kind, DeepLinkKind.oauth);
    expect(classifyDeepLink('openchamber://mcp/oauth/callback?code=x&state=s').kind, DeepLinkKind.oauth);
  });

  test('parses error callbacks and ignores empty codes', () {
    final denied = parseOAuthCallbackUri(
      'openchamber://oauth/callback?error=access_denied&error_description=User%20denied',
    );
    expect(denied.hasCode, isFalse);
    expect(denied.error, 'access_denied');
    expect(denied.errorDescription, 'User denied');

    final blank = parseOAuthCallbackUri('openchamber://oauth/callback?code=%20&state=');
    expect(blank.hasCode, isFalse);
    expect(blank.code, isNull);
    expect(blank.state, isNull);

    expect(parseOAuthCallbackUri('not a url').hasCode, isFalse);
    expect(isOAuthCallbackLink('openchamber://connect?v=2&p=abc'), isFalse);
    expect(classifyDeepLink('https://example.invalid/oauth/callback?code=x').kind, DeepLinkKind.oauth);
  });

  test('official authorize URLs are http(s) only for the external browser', () async {
    final browser = MemoryExternalBrowser();
    expect(() => browser.open('openchamber://oauth/callback?code=abc'), throwsA(isA<ExternalBrowserException>()));
    expect(() => browser.open('javascript:alert(1)'), throwsA(isA<ExternalBrowserException>()));
    expect(() => browser.open('file:///tmp/secret'), throwsA(isA<ExternalBrowserException>()));
    expect(() => browser.open('https://'), throwsA(isA<ExternalBrowserException>()));
    expect(() => browser.open('ftp://example.invalid/oauth'), throwsA(isA<ExternalBrowserException>()));

    await browser.open('https://example.invalid/oauth/provider?state=s');
    await browser.open('http://127.0.0.1:4280/oauth');
    expect(browser.opened, [
      'https://example.invalid/oauth/provider?state=s',
      'http://127.0.0.1:4280/oauth',
    ]);
  });

  test('incoming callback URI is stored then consumed exactly once', () async {
    final controller = AppController(
      store: MemorySecureStore(),
      api: OpenChamberApi(transport: MemoryOpenChamberTransport()),
      browser: MemoryExternalBrowser(),
    );
    await controller.bootstrap(skipDelay: true);
    await controller.handleIncomingLink('openchamber://oauth/callback?code=once-code&state=once-state');
    expect(controller.pendingOAuthCallback?.code, 'once-code');
    expect(controller.pendingOAuthCallback?.state, 'once-state');
    expect(controller.takeOAuthCallback()?.code, 'once-code');
    expect(controller.pendingOAuthCallback, isNull);
    expect(controller.takeOAuthCallback(), isNull);
  });
}
