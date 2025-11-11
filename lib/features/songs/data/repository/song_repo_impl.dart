import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wereb/core/error/failure.dart';
import 'package:wereb/core/network/network_info_impl.dart';
import 'package:wereb/features/songs/data/local/server_1_content.dart';
import 'package:wereb/features/songs/data/local/song_model.dart';
import 'package:wereb/features/songs/domain/entities/SongModel.dart';
import 'package:wereb/features/songs/domain/repository/song_repo.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart'; // optional for natural sorting

class SongRepoImpl implements SongRepository {
  final SharedPreferences sharedPreferences;
  final NetworkInfo networkInfo;
  final http.Client client;
  final Box<SongModel> songsBox;
  SongRepoImpl({
    required this.sharedPreferences,
    required this.networkInfo,
    required this.client,
    required this.songsBox,
  });
  @override
  Future<String> changeTheme(String theme) {
    print(theme);
    return Future.value(
      sharedPreferences.setString('theme', theme).then((value) => theme),
    );
  }

  @override
  Future<String> getCurrentTheme() {
    return Future.value(sharedPreferences.getString('theme') ?? 'light');
  }

  int _sortByName(SongModel a, SongModel b) {
    // Extract leading numbers if any
    final regex = RegExp(r'^(\d+)-?');
    final aMatch = regex.firstMatch(a.name);
    final bMatch = regex.firstMatch(b.name);

    if (aMatch != null && bMatch != null) {
      // both have numbers, sort numerically first
      final aNum = int.parse(aMatch.group(1)!);
      final bNum = int.parse(bMatch.group(1)!);
      if (aNum != bNum) return aNum.compareTo(bNum);
    } else if (aMatch != null) {
      // a has number, b doesn't → a comes first
      return -1;
    } else if (bMatch != null) {
      // b has number, a doesn't → b comes first
      return 1;
    }

    // fallback to lexicographic sort (Amharic or text)
    return a.name.compareTo(b.name);
  }

  List<SongModel> _sortRecursive(List<SongModel> list) {
    for (var song in list) {
      if (song.children.isNotEmpty) {
        song.children = _sortRecursive(song.children);
      }
    }
    list.sort(_sortByName);
    return list;
  }

  @override
  Future<List<SongModel>> loadSongs() async {
    try {
      if (songsBox.containsKey('root')) {
        final SongModel root = songsBox.get('root')!;
        return Future.value(root.children);
      }

      final jsonValue = server1Content;
      List<SongModel> songs = jsonValue
          .map<SongModel>((json) => SongModel.fromJson(json))
          .toList();

      songs = _sortRecursive(songs);

      final root = SongModel(
        id: 'root',
        name: 'Root',
        listHere: true,
        url: null,
        isAudio: false,
        children: songs,
      );
      await songsBox.put('root', root);

      return Future.value(songs);
    } catch (e) {
      return Future.error("Error loading songs: $e");
    }
  }

  @override
  Future<List<SongModel>> saveImageLocally(
    SongModel song,
    String imagePath,
  ) async {
    try {
      final root = songsBox.get('root');
      if (root == null) return Future.error("Root not found");

      void updateImageRecursive(List<SongModel> list) {
        for (var s in list) {
          if (s.id == song.id) {
            s.imageLocalPath = imagePath;
            return;
          }
          if (s.children.isNotEmpty) {
            updateImageRecursive(s.children);
          }
        }
      }

      updateImageRecursive(root.children);

      await songsBox.put('root', root);
      return Future.value(root.children);
    } catch (e) {
      return Future.error("Error saving image locally: $e");
    }
  }

  @override
  Stream<Either<Failure, DownloadAudioReport>> downloadAudio(
    String url,
    SongModel song,
  ) async* {
    if (!await networkInfo.isConnected) {
      yield Left(ServerFailure(message: "No internet connection!!!"));
    }

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield Left(ServerFailure(message: 'Failed to download file.'));
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/Audio/${song.id.replaceAll("/", "_")}';
      await Directory(path).create(recursive: true);
      final file = File('$path/${decodeAndTrimUrl(url)}');

      int downloaded = 0;
      final total = response.contentLength ?? 0;

      // Open file for writing chunks
      final sink = file.openWrite();

      // Listen to download progress
      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        // calculate progress
        double progress = total > 0 ? downloaded / total : 0;
        print(
          "Downloading ${song.name}: ${(progress * 100).toStringAsFixed(0)}%",
        );
        yield Right(
          DownloadAudioReport(songModel: song, progress: progress * 100),
        );
      }

      await sink.close();

      // // Return updated song model with new path
      // song.localPath = file.path;
      print("^^^^^^^^^^^^^^^^^");
      print("Download completed: ${file.path}");
      for (var son in song.children) {
        if (son.url == url) {
          son.isDownloaded = true;
          son.audioLocalPath = file.path;
        }
      }
      final root = songsBox.get('root');
      if (root == null) {
        yield Left(ServerFailure(message: "Root not found"));
        return;
      }

      void updateAudioPathRecursive(List<SongModel> list) {
        for (var s in list) {
          if (s.id == song.id) {
            s.audioLocalPath = file.path;
            return;
          }
          if (s.children.isNotEmpty) {
            updateAudioPathRecursive(s.children);
          }
        }
      }

      updateAudioPathRecursive(root.children);
      await songsBox.put('root', root!);
      yield Right(DownloadAudioReport(progress: 100, songModel: song));
    } catch (e) {
      print("Error downloading file: $e");
      yield Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<bool> isConnected() async {
    return await networkInfo.isConnected;
  }
}

String decodeAndTrimUrl(String url) {
  final decoded = Uri.decodeFull(url);
  final filename = decoded.substring(decoded.lastIndexOf('/') + 1);
  final match = RegExp(r'^(.*)_[^_]+(\.\w+)$').firstMatch(filename);
  return match != null ? '${match.group(1)}${match.group(2)}' : filename;
}
