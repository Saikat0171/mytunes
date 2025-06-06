import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'main.dart'; // Import SongData

class PlayerPage extends StatefulWidget {
  final List<SongData> songs;
  final int initialIndex;
  const PlayerPage({
    super.key,
    required this.songs,
    required this.initialIndex,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AudioPlayer _audioPlayer;
  late int _currentIndex;
  final _logger = Logger('MyTunesPlayer');
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState? _playerState;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _currentIndex = widget.initialIndex;
    _playSong(_currentIndex);

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
    _audioPlayer.durationStream.listen((d) {
      setState(() {
        _duration = d ?? Duration.zero;
      });
    });
    _audioPlayer.positionStream.listen((p) {
      setState(() {
        _position = p;
      });
    });
  }

  Future<void> _playSong(int index) async {
    final song = widget.songs[index];
    _logger.info('Trying to play: ${song.uri}');
    try {
      await _audioPlayer.stop();
      if (Platform.isLinux) {
        if (!await File(song.uri).exists()) {
          _logger.warning('File does not exist: ${song.uri}');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File does not exist: ${song.title}')),
          );
          return;
        }
        await _audioPlayer.setFilePath(song.uri);
      } else if (Platform.isAndroid) {
        _logger.info('Android song URI: ${song.uri}');
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(song.uri)));
      }
      await _audioPlayer.play();
      setState(() {
        _currentIndex = index;
        _position = Duration.zero;
      });
    } catch (e, stack) {
      _logger.severe('Cannot play this song: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot play this song')));
    }
  }

  void _seekTo(double value) {
    final seekPosition = Duration(milliseconds: value.round());
    _audioPlayer.seek(seekPosition);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songs[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Now Playing', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 120, color: Colors.deepPurple),
            const SizedBox(height: 32),
            Text(
              song.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              song.artist ?? "Unknown Artist",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble().clamp(
                1,
                double.infinity,
              ),
              value: _position.inMilliseconds
                  .clamp(0, _duration.inMilliseconds)
                  .toDouble(),
              onChanged: (value) => _seekTo(value),
              activeColor: Colors.deepPurple,
              inactiveColor: Colors.deepPurple[100],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position)),
                Text(_formatDuration(_duration)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: _currentIndex > 0
                      ? () => _playSong(_currentIndex - 1)
                      : null,
                ),
                IconButton(
                  icon: Icon(
                    _playerState?.playing == true
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    if (_playerState?.playing == true) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: _currentIndex < widget.songs.length - 1
                      ? () => _playSong(_currentIndex + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
