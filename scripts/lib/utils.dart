import 'dart:collection';
import 'dart:convert' hide jsonEncode;

import 'package:http/http.dart' as http;

/// Maximum time for any web request to complete.
const requestTimeout = const Duration(seconds: 10);

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
    // response.body is not decoded as UTF8 if not specified in the content
    // type, so for now we need to decode explicitly.
    // https://github.com/dart-lang/http/issues/494
    return jsonDecode(utf8.decode(response.bodyBytes));
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
  // trace('Fetching $uri...');
}

/// Similar to Future.wait() but processes in buckets of [concurrency] to avoid
/// trying to run too many things in parallel.
Future<void> runConcurrently<T>(
  List<T> items,
  Future<Object?> Function(T) func, {
  int concurrency = 30,
}) async {
  final queue = Queue.of(items);
  // Helper that will process the queue until it's done. Runs concurrently
  // so must take from the queue atomically.
  Future<void> processQueue(int workerIndex) async {
    while (queue.isNotEmpty) {
      final item = queue.removeFirst();
      await func(item);
    }
  }

  await Future.wait(List.generate(concurrency, processQueue));
}
