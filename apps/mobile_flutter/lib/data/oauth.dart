/// Official provider OAuth authorize payload (`provider.oauth.authorize`).
class ProviderOAuthStart {
  const ProviderOAuthStart({
    this.url,
    this.instructions,
    this.userCode,
    this.mode = 'code',
  });

  final String? url;
  final String? instructions;
  final String? userCode;
  final String mode;

  bool get canOpenBrowser => url != null && url!.isNotEmpty;
  bool get isAuto => mode == 'auto';
}

ProviderOAuthStart parseProviderOAuthStart(Object? payload) {
  final root = payload is Map ? Map<String, Object?>.from(payload) : const <String, Object?>{};
  final nested = root['data'];
  final data = nested is Map ? Map<String, Object?>.from(nested) : root;
  final url = _firstString(data, const [
    'url',
    'verification_uri_complete',
    'verification_uri',
  ]);
  return ProviderOAuthStart(
    url: url,
    instructions: _firstString(data, const ['instructions', 'message']),
    userCode: _firstString(data, const ['user_code', 'userCode', 'code']),
    mode: data['method']?.toString() == 'auto' ? 'auto' : 'code',
  );
}

String? parseMcpAuthorizationUrl(Object? payload) {
  final root = payload is Map ? Map<String, Object?>.from(payload) : const <String, Object?>{};
  final nested = root['data'];
  final data = nested is Map ? Map<String, Object?>.from(nested) : root;
  return _firstString(data, const ['authorizationUrl', 'authorization_url', 'url']);
}

class OAuthCallback {
  const OAuthCallback({this.code, this.state, this.error, this.errorDescription, this.server});

  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;
  final String? server;

  bool get hasCode => code != null && code!.isNotEmpty;
}

OAuthCallback parseOAuthCallbackUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return const OAuthCallback();
  final params = uri.queryParameters;
  return OAuthCallback(
    code: _nonEmpty(params['code']),
    state: _nonEmpty(params['state']),
    error: _nonEmpty(params['error']),
    errorDescription: _nonEmpty(params['error_description']),
    server: _nonEmpty(params['server']),
  );
}

String? mcpOAuthStateKey(String authorizationUrl) {
  final uri = Uri.tryParse(authorizationUrl);
  return uri == null ? null : _nonEmpty(uri.queryParameters['state']);
}

bool isOAuthCallbackLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.contains('/mcp/oauth/callback') || trimmed.contains('/oauth/callback')) {
    return true;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (uri.scheme != 'openchamber') return false;
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('state') ||
      uri.queryParameters.containsKey('error');
}

String? _firstString(Map<String, Object?> data, List<String> keys) {
  for (final key in keys) {
    final value = _nonEmpty(data[key]?.toString());
    if (value != null) return value;
  }
  return null;
}

String? _nonEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
