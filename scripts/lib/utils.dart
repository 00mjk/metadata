import 'dart:convert' hide jsonEncode;
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Maximum time for any web request to complete.
const requestTimeout = const Duration(seconds: 20);

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
    final preview = (response.body.length < 100
            ? response.body
            : response.body.substring(0, 100))
        .split('\n')
        .first;
    throw 'Fetching "$uri" failed: '
        '${response.statusCode}: ${response.reasonPhrase}\n\n'
        '$preview';
  }
}

void trace(String message) {
  print(message);
}

void traceFetch(Uri uri) {
  trace('Fetching $uri...');
}

/// Similar to Future.wait() but processes in buckets of [concurrency] to avoid
/// trying to run too many things in parallel.
Future<void> wait<T>(
  List<T> items,
  Future<Object?> Function(T) func, {
  int concurrency = 20,
}) async {
  for (var i = 0; i < items.length; i += concurrency) {
    final start = math.min(i, items.length - 1);
    final end = math.min(i + concurrency, items.length);
    final bucket = items.sublist(start, end);
    await Future.wait(bucket.map(func));
  }
}
