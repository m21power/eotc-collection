import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/SongModel.dart';

/// Safe map casting
Map<String, dynamic> safeMap(dynamic input) {
  if (input is Map<String, dynamic>) return input;
  if (input is Map) {
    return input.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

/// Fetch all Cloudinary audio files and build folder tree
Future<List<Map<String, dynamic>>> fetchCloudinaryFolderTree({
  required String cloudName,
  required String apiKey,
  required String apiSecret,
}) async {
  const int maxResults = 500;
  String? nextCursor;
  final List<Map<String, dynamic>> allResources = [];

  // --- 1. Fetch all resources with pagination ---
  do {
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/resources/video/upload',
      {
        'max_results': '$maxResults',
        if (nextCursor != null) 'next_cursor': nextCursor,
      },
    );

    final authHeader =
        'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}';

    final response = await http.get(
      uri,
      headers: {'Authorization': authHeader},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Cloudinary data: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final List resources = (data['resources'] ?? []) as List;
    allResources.addAll(resources.cast<Map<String, dynamic>>());

    nextCursor = data['next_cursor'] as String?;
  } while (nextCursor != null);

  // --- 2. Build nested folder structure ---
  final Map<String, dynamic> root = {};

  for (final r in allResources) {
    final folderPath = (r['asset_folder'] as String? ?? '').trim();
    final url = (r['secure_url'] ?? r['url']) as String;
    final fileNameWithExt = url.split('/').last;
    final fileName = fileNameWithExt.contains('.')
        ? fileNameWithExt.substring(0, fileNameWithExt.lastIndexOf('.'))
        : fileNameWithExt;
    final name = Uri.decodeFull(fileName);

    final parts = folderPath.isEmpty ? <String>[] : folderPath.split('/');

    Map<String, dynamic> current = root;

    // Traverse and create folder path
    for (final part in parts) {
      final normalizedPart = part.trim();
      if (normalizedPart.isEmpty) continue;

      final folderNode =
          (current[normalizedPart] ??= {
                '_children': <String, dynamic>{},
                '_files': <Map<String, dynamic>>[],
              })
              as Map<String, dynamic>;

      current = safeMap(folderNode['_children']);
    }

    // Add file to current folder
    List<Map<String, dynamic>> filesList = current['_files'] is List
        ? List<Map<String, dynamic>>.from(current['_files'] as List)
        : <Map<String, dynamic>>[];

    current['_files'] = filesList;

    filesList.add({
      'id': r['asset_id'] ?? '',
      'name': name,
      'url': url,
      'isAudio': true,
      'listHere': true,
      'isDownloaded': false,
      'audioLocalPath': null,
      'imageLocalPath': null,
      'children': <Map<String, dynamic>>[],
    });
  }

  // --- 3. Convert tree to final list ---
  List<Map<String, dynamic>> buildTree(Map<String, dynamic> folder) {
    final result = <Map<String, dynamic>>[];

    Map<String, dynamic> childrenMap = {};
    List<dynamic> files = [];
    final Map<String, dynamic> folderNodes = {};

    // Separate metadata and real folders
    folder.forEach((key, value) {
      final String k = key.toString();
      if (k == '_children') {
        childrenMap = safeMap(value);
      } else if (k == '_files') {
        files = value is List ? List.from(value) : [];
      } else {
        folderNodes[k] = value;
      }
    });

    // Process files in this folder
    final List<Map<String, dynamic>> fileList = files
        .where((f) => f is Map)
        .map((f) => safeMap(f))
        .toList();

    // Process subfolders from _children
    final List<Map<String, dynamic>> childFolders = buildTree(childrenMap);

    // Process real folder nodes
    folderNodes.forEach((folderName, nodeValue) {
      final Map<String, dynamic> node = safeMap(nodeValue);
      final Map<String, dynamic> nodeChildren = safeMap(node['_children']);
      final List<dynamic> nodeFilesRaw = node['_files'] is List
          ? node['_files']!
          : [];

      final List<Map<String, dynamic>> nodeFiles = nodeFilesRaw
          .where((f) => f is Map)
          .map((f) => safeMap(f))
          .toList();

      final List<Map<String, dynamic>> nodeSubfolders = buildTree(nodeChildren);

      result.add({
        'name': folderName,
        'url': null,
        'isAudio': false,
        'listHere': true,
        'isDownloaded': false,
        'audioLocalPath': null,
        'imageLocalPath': null,
        'children': [...nodeSubfolders, ...nodeFiles],
      });
    });

    // Return: real folders + child folders + files
    return [...result, ...childFolders, ...fileList];
  }

  return buildTree(root);
}

/// Send JSON to Telegram
Future<void> sendJsonToTelegram({
  required String jsonStr,
  required String token,
  required String chatId,
}) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/wereb_songs.json');

  await tempFile.writeAsString(jsonStr, flush: true);

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('https://api.telegram.org/bot$token/sendDocument'),
  );

  request.fields['chat_id'] = chatId;
  request.files.add(
    await http.MultipartFile.fromPath('document', tempFile.path),
  );

  final response = await request.send();

  if (response.statusCode == 200) {
    print('JSON sent to Telegram successfully!');
  } else {
    final resp = await response.stream.bytesToString();
    print('Failed to send: ${response.statusCode}\n$resp');
  }

  if (await tempFile.exists()) await tempFile.delete();
}

List<Songmodel> buildSongTree(List<Map<String, dynamic>> resources) {
  List<Songmodel> tree = [];

  for (var resource in resources) {
    List<String> folders = resource['asset_folder'].split('/');
    List<Songmodel> currentLevel = tree;

    for (var folder in folders) {
      // Check if folder exists at current level
      var existingFolder = currentLevel.firstWhere(
        (e) => e.name == folder && !e.isAudio,
        orElse: () => Songmodel(
          id: resource['asset_folder'] ?? folder,
          name: folder,
          listHere: true,
          children: [],
        ),
      );

      if (!currentLevel.contains(existingFolder)) {
        currentLevel.add(existingFolder);
      }

      currentLevel = existingFolder.children;
    }

    // Remove the last part after '_' in the display name
    String displayName = resource['display_name'];
    int lastUnderscore = displayName.lastIndexOf('_');
    if (lastUnderscore != -1) {
      displayName = displayName.substring(0, lastUnderscore);
    }

    // Add the song at the last folder
    currentLevel.add(
      Songmodel(
        id: resource['asset_id'],
        name: displayName,
        url: resource['secure_url'],
        listHere: false,
        isAudio: true,
      ),
    );
  }

  return tree;
}

// Helper function to print tree
void printTree(List<Songmodel> tree, [String prefix = '']) {
  for (var node in tree) {
    print('$prefix${node.isAudio ? '🎵 ' : '📁 '}${node.name}');
    if (node.children.isNotEmpty) {
      printTree(node.children, '$prefix  ');
    }
  }
}
