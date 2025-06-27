import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  late final RecorderController _recorderController;
  bool _isRecording = false;
  bool _isPaused = false;
  Timer? _timer;
  Duration _duration = Duration.zero;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController()
      ..updateFrequency = const Duration(milliseconds: 50)
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..sampleRate = 16000;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorderController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${_generateRandomId()}.m4a';
    await _recorderController.record(path: filePath);
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _filePath = filePath;
      _duration = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isPaused && _isRecording) {
        setState(() {
          _duration += const Duration(milliseconds: 50);
        });
      }
    });
  }

  Future<void> _pauseRecording() async {
    await _recorderController.pause();
    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _resumeRecording() async {
    await _recorderController.record();
    setState(() {
      _isPaused = false;
    });
  }

  Future<void> _stopRecording() async {
    await _recorderController.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    _timer?.cancel();
    // 保存 waveData
    if (_filePath != null) {
      final waveData = _recorderController.waveData;
      final waveFile = File(_filePath! + '.wave.json');
      await waveFile.writeAsString(jsonEncode(waveData));
    }
    // print('录音已保存: $_filePath');
  }

  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(
      10,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String ms = (d.inMilliseconds % 1000)
        .toString()
        .padLeft(3, '0')
        .substring(0, 2);
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}.${ms}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // 大号计时器
            Text(
              _formatDuration(_duration),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFFBDBDBD),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '高品质音质',
              style: TextStyle(fontSize: 16, color: Color(0xFFBDBDBD)),
            ),
            const SizedBox(height: 32),
            // 波形
            SizedBox(
              height: 180,
              child: Center(
                child: AudioWaveforms(
                  enableGesture: false,
                  size: Size(MediaQuery.of(context).size.width * 0.85, 120),
                  recorderController: _recorderController,
                  waveStyle: WaveStyle(waveColor: const Color(0xFF4A90E2)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 底部按钮区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 标记按钮
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark,
                      size: 36,
                      color: Color(0xFF4A90E2),
                    ),
                    onPressed: () {
                      // TODO: 实现标记功能
                    },
                  ),
                  // 录音/停止按钮
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFFFF6F61)],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            size: 36,
                            color: _isRecording
                                ? const Color(0xFFFF6F61)
                                : const Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 暂停/恢复按钮
                  if (_isRecording && !_isPaused)
                    IconButton(
                      icon: const Icon(
                        Icons.pause_circle_filled,
                        size: 36,
                        color: Color(0xFF4A90E2),
                      ),
                      onPressed: _pauseRecording,
                    )
                  else if (_isRecording && _isPaused)
                    IconButton(
                      icon: const Icon(
                        Icons.play_circle_fill,
                        size: 36,
                        color: Color(0xFF4A90E2),
                      ),
                      onPressed: _resumeRecording,
                    )
                  else
                    const SizedBox(width: 36),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
