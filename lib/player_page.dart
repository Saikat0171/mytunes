import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:just_audio/just_audio.dart';
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
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _currentIndex = widget.initialIndex;
    _playSong(_currentIndex);

    _audioPlayer.positionStream.listen((p) {
      setState(() {
        _position = p;
      });
    });
    _audioPlayer.durationStream.listen((d) {
      setState(() {
        _duration = d ?? Duration.zero;
      });
    });
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_currentIndex < widget.songs.length - 1) {
          _playSong(_currentIndex + 1);
        }
      }
    });
  }

  Future<void> _playSong(int index) async {
    final song = widget.songs[index];
    _logger.info('Trying to play: ${song.uri}');
    try {
      await _audioPlayer.stop();
      if (Platform.isAndroid || Platform.isIOS) {
        await _audioPlayer.setUrl(song.uri);
      } else {
        await _audioPlayer.setFilePath(song.uri);
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Now Playing', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Album art icon
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.music_note,
                size: 120,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Song title
            Text(
              song.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Artist name
            Text(
              song.artist ?? "Unknown Artist",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Progress bar
            Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble().clamp(
                1,
                double.infinity,
              ),
              value: _position.inMilliseconds
                  .clamp(0, _duration.inMilliseconds)
                  .toDouble(),
              onChanged: _seekTo,
              activeColor: Colors.greenAccent,
              inactiveColor: Colors.grey[700],
            ),

            // Time indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous,
                    size: 36,
                    color: Colors.white,
                  ),
                  onPressed: _currentIndex > 0
                      ? () => _playSong(_currentIndex - 1)
                      : null,
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 64,
                    color: Colors.greenAccent,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next,
                    size: 36,
                    color: Colors.white,
                  ),
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
