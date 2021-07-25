import 'dart:convert' hide jsonEncode;

import 'package:http/http.dart' as http;

/// Maximum time for any web request to complete.
const requestTimeout = const Duration(seconds: 120);

/// A JSON encoder using tabs for indenting.
final jsonEncode = JsonEncoder.withIndent('\t').convert;

/// Fetches the JSON file at [uri].
///
/// Returns the decoded JSON project.
///
/// Throws if the URI cannot be loaded, times out, or is not valid JSON.
Future<Object?> fetchJson(Uri uri, {Map<String, String>? headers}) async {
  traceFetch(uri);
  final response = await http.get(uri, headers: headers).timeout(requestTimeout,
      onTimeout: () => throw 'Timed out fetching $uri');

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw 'Fetching "$uri" failed: '
        '${response.statusCode}: ${response.reasonPhrase}\n\n'
        '${response.body.length < 100 ? response.body.length : response.body.substring(0, 100)}';
  }
}

void trace(String message) {
  print(message);
}

void traceFetch(Uri uri) {
  trace('Fetching $uri...');
}
