import 'dart:io';

import 'package:metadata_scripts/utils.dart';

/// The maximum number of pages of pools to fetch before giving up (assuming
/// we're somehow stuck on a loop).
const maxPoolsPages = 500;

/// The Blockfrost API endpoint to use.
const _endpoint = 'https://cardano-mainnet.blockfrost.io/api/v0';

/// Delay required between blockfrost API calls to avoid hitting rate limit.
const Duration _requestDelay = Duration(milliseconds: 100);

/// API key for Blockfrost. Read from a .blockfrost file or environment variable.
late final _apiKey = Platform.environment['BLOCKFROST_API_KEY'] ??
    File('.blockfrost').readAsStringSync().trim();

/// A future that is bumped into the future by [_requestDelay] on each request
/// to easily allow waiting until the next API call can be made.
Future<void> _nextRequestAllowed = Future.value();

/// Fetches pool metadata from the Blockfrost API.
Future<Map<String, Object?>> getMetadata(String poolId) async {
  return (await _fetchJson('pools/$poolId/metadata')) as Map<String, Object?>;
}

/// Fetches pool IDs from the Blockfrost API, enumerating all pages until there
/// are no more results.
Stream<String> getPoolIds() async* {
  for (var page = 1; page < maxPoolsPages; page++) {
    final resp = await _fetchJson('pools', {'page': '$page'});
    final pools = (resp as List).cast<String>();
    if (pools.isEmpty) {
      break;
    }
    for (final pool in pools) {
      yield pool;
    }
  }
}

/// Calls the Blockfrost [api] API with [args].
///
/// Returns the decoded JSON project.
///
/// Throws if the URI cannot be loaded, times out, or is not valid JSON.
Future<Object?> _fetchJson(String api, [Map<String, Object?>? args]) async {
  // Update _nextRequestAllowed to be a future that completes when the next
  // request will be allowed, and then await the previous one.
  final previous = _nextRequestAllowed;
  _nextRequestAllowed =
      _nextRequestAllowed.then((_) => Future.delayed(_requestDelay));
  await previous;

  final uri = Uri.parse('$_endpoint/$api').replace(queryParameters: args);
  return fetchJson(uri, headers: {'project_id': _apiKey});
}
