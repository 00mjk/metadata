import 'dart:convert' hide jsonEncode;
import 'dart:io';

import 'package:metadata_scripts/blockfrost.dart' as bf;
import 'package:metadata_scripts/utils.dart';

Future<void> main(List<String> args) async {
  final extendedMetadataOnly = args.contains('--extended-only');

  Directory('../data/metadata').createSync(recursive: true);
  Directory('../data/extended').createSync(recursive: true);

  // Fetch all pool IDs and store them.
  final poolFile = File('../data/pools.json');
  late List<String> poolIds;

  if (extendedMetadataOnly) {
    poolIds = (jsonDecode(poolFile.readAsStringSync()) as List)
        .cast<String>()
        .toList();
  } else {
    poolIds = await bf.getPoolIds().toList();
    poolFile.writeAsStringSync(jsonEncode(poolIds));
  }

  // Fetch the metadata files and store them.
  await runConcurrently(poolIds, (poolId) async {
    String? extendedUrl;
    try {
      final metadataFile = File('../data/metadata/$poolId.json');
      final extendedFile = File('../data/extended/$poolId.json');

      late Map<String, Object?> metadata;
      if (extendedMetadataOnly) {
        // Skip sites that we were unable to download metadata for.
        if (!metadataFile.existsSync()) {
          return;
        }
        metadata =
            jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>;
      } else {
        metadata = await _getMetadata(poolId);
        metadataFile.writeAsStringSync(jsonEncode(metadata));
      }

      extendedUrl = metadata['extended'] as String?;
      if (extendedUrl != null) {
        final uri = Uri.tryParse(extendedUrl.trim());
        if (uri != null && uri.isAbsolute) {
          final extended = await fetchJson(Uri.parse(extendedUrl));
          extendedFile.writeAsStringSync(jsonEncode(extended));
        }
      }
    } catch (e) {
      trace('Failed to fetch metadata for $poolId ${extendedUrl ?? ''}: $e');
    }
  });

  // Because of how we use .timeout() on http.get(), the requests may still be
  // going even if we timed them out, so to avoid sitting around waiting, just
  // quit.
  exit(0);
}

/// Gets the raw metadata file for the pool.
///
/// This is the real metadata file fetched from the web and not the reduced set
/// from the Blockfrost API, as we need to be able to get the extended metadata
/// file.
Future<Map<String, Object?>> _getMetadata(poolId) async {
  final metadata = await bf.getMetadata(poolId);
  final metadataUrl = metadata['url'] as String;
  final uri = Uri.parse(metadataUrl);

  // Hashes are not currently checked. We could do this, but since we have no
  // hash for the extended metadata file, we're already making the assumption
  // that only the SPO has access to modify these files.

  return await fetchJson(uri) as Map<String, Object?>;
}
