import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:async';

class AudioPlayerPage extends StatefulWidget {
  final String filePath;
  final List<double> waveform;
  const AudioPlayerPage({
    super.key,
    required this.filePath,
    required this.waveform,
  });

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _soloud.init();
    _source = await _soloud.loadFile(widget.filePath);
    final duration = await _soloud.getLength(_source!);
    setState(() {
      _duration = duration;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _soloud.deinit();
    super.dispose();
  }

  void _playPause() async {
    if (_isPlaying) {
      if (_handle != null) _soloud.pauseSwitch(_handle!);
      _timer?.cancel();
    } else {
      if (_source != null) {
        await _soloud.play(_source!);
        _handle = await _soloud.play(_source!);
        _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
          if (_handle != null) {
            final position = await _soloud.getPosition(_handle!);
            setState(() {
              _position = position;
            });
          }
        });
      }
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音频播放')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.waveform.isEmpty
                  ? const Text(
                      '无波形数据',
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    )
                  : SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: WaveformPainter(widget.waveform),
                      ),
                    ),
              const SizedBox(height: 32),
              Text(
                _formatDuration(_position) + ' / ' + _formatDuration(_duration),
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.blue,
                ),
                onPressed: _source == null ? null : _playPause,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  WaveformPainter(this.waveform);

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final double midY = size.height / 2;
    final double step = size.width / waveform.length;
    final path = Path();
    for (int i = 0; i < waveform.length; i++) {
      double x = i * step;
      double y = midY - waveform[i] * (size.height / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform;
  }
}
