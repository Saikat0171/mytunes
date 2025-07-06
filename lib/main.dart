import 'dart:io' show Directory, File, Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:logging/logging.dart';
import 'player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Use logging framework instead of print
    // You can also write to a file or remote server here if needed
    // Example: log to console
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyTunes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MusicPlayerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SongData {
  final String title;
  final String? artist;
  final String uri;
  final int? id;
  final String? album;

  SongData({
    required this.title,
    this.artist,
    required this.uri,
    this.id,
    this.album,
  });
}

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});
  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final _logger = Logger('MyTunes');
  List<SongData> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    try {
      if (Platform.isAndroid) {
        await _requestPermissionAndFetchAndroidSongs();
      } else if (Platform.isLinux) {
        await _scanLinuxSongs();
      } else if (Platform.isWindows) {
        await _scanWindowsSongs();
      } else if (Platform.isMacOS) {
        await _scanMacOSSongs();
      }
    } catch (e, stack) {
      _logger.severe('Error fetching songs: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading songs: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPermissionAndFetchAndroidSongs() async {
    var storageStatus = await Permission.storage.request();
    var audioStatus = await Permission.audio.request();
    if (storageStatus.isGranted || audioStatus.isGranted) {
      List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.DISPLAY_NAME,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      setState(() {
        _songs = songs
            .where((s) => s.uri != null)
            .map(
              (s) => SongData(
                title: s.title,
                artist: s.artist,
                uri: s.uri!,
                id: s.id,
                album: s.album,
              ),
            )
            .toList();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage or audio permission is required to list songs.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _scanLinuxSongs() async {
    final home = Platform.environment['HOME'] ?? '/home';
    final musicDirs = [
      Directory('$home/Music'),
      Directory('$home/Downloads'),
      Directory('$home/Downloads/Music'),
    ];
    final audioExtensions = ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'];
    final List<SongData> foundSongs = [];
    for (final dir in musicDirs) {
      _logger.info('Scanning directory: ${dir.path}');
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (audioExtensions.contains(ext)) {
                _logger.fine('Found audio file: ${entity.path}');
                foundSongs.add(
                  SongData(
                    title: entity.uri.pathSegments.last,
                    artist: null,
                    uri: entity.path,
                    id: null,
                  ),
                );
              }
            }
          }
        } catch (e) {
          _logger.severe('Error scanning ${dir.path}: $e');
          continue;
        }
      } else {
        _logger.warning('Directory does not exist: ${dir.path}');
      }
    }
    setState(() {
      _songs = foundSongs;
    });
  }

  Future<void> _scanWindowsSongs() async {
    final userProfile =
        Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
    final musicDirs = [
      Directory('$userProfile\\Music'),
      Directory('$userProfile\\Downloads'),
      Directory('$userProfile\\Downloads\\Music'),
    ];
    final audioExtensions = ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'];
    final List<SongData> foundSongs = [];
    for (final dir in musicDirs) {
      _logger.info('Scanning directory: ${dir.path}');
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (audioExtensions.contains(ext)) {
                _logger.fine('Found audio file: ${entity.path}');
                foundSongs.add(
                  SongData(
                    title: entity.uri.pathSegments.last,
                    artist: null,
                    uri: entity.path,
                    id: null,
                  ),
                );
              }
            }
          }
        } catch (e) {
          _logger.severe('Error scanning ${dir.path}: $e');
          continue;
        }
      } else {
        _logger.warning('Directory does not exist: ${dir.path}');
      }
    }
    setState(() {
      _songs = foundSongs;
    });
  }

  Future<void> _scanMacOSSongs() async {
    final home = Platform.environment['HOME'] ?? '/Users/Shared';
    final musicDirs = [
      Directory('$home/Music'),
      Directory('$home/Downloads'),
      Directory('$home/Downloads/Music'),
    ];
    final audioExtensions = ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'];
    final List<SongData> foundSongs = [];
    for (final dir in musicDirs) {
      _logger.info('Scanning directory: ${dir.path}');
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (audioExtensions.contains(ext)) {
                _logger.fine('Found audio file: ${entity.path}');
                foundSongs.add(
                  SongData(
                    title: entity.uri.pathSegments.last,
                    artist: null,
                    uri: entity.path,
                    id: null,
                  ),
                );
              }
            }
          }
        } catch (e) {
          _logger.severe('Error scanning ${dir.path}: $e');
          continue;
        }
      } else {
        _logger.warning('Directory does not exist: ${dir.path}');
      }
    }
    setState(() {
      _songs = foundSongs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('MyTunes', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _songs.isEmpty
                      ? const Center(child: Text('No songs found.'))
                      : ListView.builder(
                          itemCount: _songs.length,
                          itemBuilder: (context, index) {
                            final song = _songs[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.music_note,
                                color: Colors.deepPurple,
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(song.artist ?? "Unknown Artist"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerPage(
                                      songs: _songs,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
