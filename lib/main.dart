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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
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
  List<SongData> _filteredSongs = [];
  bool _loading = true;
  String _searchQuery = '';
  String _sortOption = 'A-Z';

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  void _applyFilters() {
    List<SongData> filtered = _songs.where((song) {
      return song.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    switch (_sortOption) {
      case 'A-Z':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'Z-A':
        filtered.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case 'Newest First':
        filtered = filtered.reversed.toList();
        break;
      case 'Oldest First':
        break;
    }

    setState(() {
      _filteredSongs = filtered;
    });
  }

  Future<void> _fetchSongs() async {
    try {
      if (Platform.isAndroid) {
        await _requestPermissionAndFetchAndroidSongs();
      } else if (Platform.isLinux) {
        await _scanSongs(['/home']);
      } else if (Platform.isWindows) {
        await _scanSongs([
          '${Platform.environment['USERPROFILE']}\\Music',
          '${Platform.environment['USERPROFILE']}\\Downloads',
        ]);
      } else if (Platform.isMacOS) {
        await _scanSongs([
          '${Platform.environment['HOME']}/Music',
          '${Platform.environment['HOME']}/Downloads',
        ]);
      }
    } catch (e, stack) {
      _logger.severe('Error fetching songs: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading songs: $e')));
      }
    } finally {
      if (mounted) {
        _applyFilters();
        setState(() => _loading = false);
      }
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
      final fetchedSongs = songs
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

      setState(() {
        _songs = fetchedSongs;
        _applyFilters();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission required to load songs.')),
        );
      }
    }
  }

  Future<void> _scanSongs(List<String> paths) async {
    final audioExtensions = ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'];
    final List<SongData> foundSongs = [];

    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              final ext = entity.path.split('.').last.toLowerCase();
              if (audioExtensions.contains(ext)) {
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
          _logger.severe('Error scanning $path: $e');
        }
      }
    }

    setState(() {
      _songs = foundSongs;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'MyTunes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search songs',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                        _applyFilters();
                      });
                    },
                  ),
                ),

                // Sort dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sort by',
                        style: TextStyle(color: Colors.white),
                      ),
                      DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E1E1E),
                        value: _sortOption,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                        underline: Container(),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortOption = value;
                              _applyFilters();
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
                          DropdownMenuItem(value: 'Z-A', child: Text('Z-A')),
                          DropdownMenuItem(
                            value: 'Newest First',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'Oldest First',
                            child: Text('Oldest'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Song list
                Expanded(
                  child: _filteredSongs.isEmpty
                      ? const Center(
                          child: Text(
                            'No songs found.',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredSongs.length,
                          itemBuilder: (context, index) {
                            final song = _filteredSongs[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                song.artist ?? 'Unknown Artist',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerPage(
                                      songs: _filteredSongs,
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
