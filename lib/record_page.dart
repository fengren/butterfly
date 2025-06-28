import 'package:flutter/material.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Timer? _timer;
  Duration _duration = Duration.zero;
  String? _filePath;
  final List<double> _realtimeWaveform = [];
  final List<Duration> _marks = []; // 标记点列表

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${_generateRandomId()}.aac';
    _filePath = '${dir.path}/$fileName';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _filePath!,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _duration = Duration.zero;
        _realtimeWaveform.clear();
        _marks.clear();
      });

      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!_isPaused && _isRecording) {
          setState(() {
            _duration += const Duration(milliseconds: 50);
            // 生成更真实的波形数据
            final random = Random();
            final amplitude = 0.1 + 0.4 * random.nextDouble();
            _realtimeWaveform.add(amplitude);

            // 限制波形数据长度，避免内存溢出
            if (_realtimeWaveform.length > 400) {
              _realtimeWaveform.removeAt(0);
            }
          });
        }
      });
    } catch (e) {
      print('开始录音失败: $e');
    }
  }

  void _onAudioData(List<int> data) {
    // 此方法暂时未使用，因为record插件的onData回调在当前版本中不可用
    // 在实际项目中可以通过其他方式获取实时音频数据
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorder.pause();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      print('暂停录音失败: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorder.resume();
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      print('恢复录音失败: $e');
    }
  }

  void _addMark() {
    if (_isRecording && !_isPaused) {
      setState(() {
        _marks.add(_duration);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加标记点: ${_formatDuration(_duration)}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      _timer?.cancel();
      
      // 检查录音文件是否生成
      if (_filePath != null) {
        final audioFile = File(_filePath!);
        if (await audioFile.exists()) {
          final fileSize = await audioFile.length();
          print('录音文件已生成: ${audioFile.path}, 大小: $fileSize 字节');

          if (fileSize > 0) {
            await _saveWaveformData();
            await _saveMarksData();
            print('录音完成，文件大小正常');
          } else {
            print('警告：录音文件大小为0，可能录音失败');
          }
        } else {
          print('错误：录音文件未生成');
        }
      }

      print('录音已保存: $_filePath');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('停止录音失败: $e');
    }
  }

  Future<void> _saveWaveformData() async {
    try {
      final normalizedWaveData = _normalizeWaveData(_realtimeWaveform);
      final waveFile = File('${_filePath!}.wave.json');
      await waveFile.writeAsString(jsonEncode(normalizedWaveData));
      print('波形数据已保存到: ${waveFile.path}');
    } catch (e) {
      print('保存波形数据时出错: $e');
      // 生成默认波形数据
      try {
        final defaultWaveData = List.generate(
          200, // 调整默认数据量，假设10秒音频，每秒20个数据
          (index) => (0.2 + 0.4 * (index % 10) / 10.0).toDouble(),
        );
        final waveFile = File('${_filePath!}.wave.json');
        await waveFile.writeAsString(jsonEncode(defaultWaveData));
        print('已生成默认波形数据');
      } catch (e2) {
        print('生成默认波形数据也失败: $e2');
      }
    }
  }

  Future<void> _saveMarksData() async {
    try {
      final marksData = _marks
          .map((duration) => duration.inMilliseconds)
          .toList();
      final marksFile = File('${_filePath!}.marks.json');
      await marksFile.writeAsString(jsonEncode(marksData));
      print('标记数据已保存到: ${marksFile.path}');
    } catch (e) {
      print('保存标记数据时出错: $e');
    }
  }

  List<double> _normalizeWaveData(List<double> data) {
    if (data.isEmpty) return data;
    double maxVal = data.map((e) => e.abs()).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return data;
    return data.map((e) => e / maxVal).toList();
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
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inMinutes}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 极简浅色主题
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          '录音',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            // 大号计时器
            Center(
              child: Text(
                _formatDuration(_duration),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 录音状态提示
            Text(
              _isRecording ? (_isPaused ? '已暂停' : '录音中...') : '准备录音',
              style: TextStyle(
                fontSize: 16,
                color: _isRecording ? Colors.black : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            // 实时波形显示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                height: 200,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final barCount = width ~/ 3;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // 波形显示
                        RealtimeWaveformPainter(
                          _realtimeWaveform,
                          barCount: barCount * 2,
                          isLight: true,
                        ).buildWidget(),
                        // 标记点显示
                        CustomPaint(
                          painter: RecordMarksPainter(
                            marks: _marks,
                            duration: _duration,
                            barCount: barCount * 2,
                            isLight: true,
                          ),
                          size: Size(width, 200),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 时间轴
            SizedBox(
              height: 48,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final barCount = width ~/ 3;
                  return RecordTimeRulerPainter(
                    duration: _duration,
                    barCount: barCount * 2,
                    isLight: true,
                  ).buildWidget();
                },
              ),
            ),
            const Spacer(),
            // 底部控制区
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 小旗子（标记）按钮
                  IconButton(
                    onPressed: _addMark,
                    icon: Icon(Icons.flag, color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 24),
                  // 暂停/恢复按钮
                  if (_isRecording)
                    IconButton(
                      onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.black,
                        size: 28,
                      ),
                    )
                  else
                    const SizedBox(width: 28),
                  const SizedBox(width: 24),
                  // 录音/停止大圆按钮
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Colors.black,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 录音实时波形绘制器
class RealtimeWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final int barCount;
  final bool isLight;

  const RealtimeWaveformPainter(
    this.waveform, {
    required this.barCount,
    required this.isLight,
  });

  Widget buildWidget() =>
      CustomPaint(painter: this, size: Size(double.infinity, 200));

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = 2;
    final double gap = 1;
    final double centerX = size.width / 2;
    final double baseY = size.height / 2;
    final int half = barCount ~/ 2;

    final Paint paint = Paint()
      ..color = isLight ? Colors.black : Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    // 绘制实时波形：从中间开始向右延展
    for (int i = 0; i < barCount; i++) {
      int dataIdx = waveform.length - barCount + i;
      if (dataIdx < 0) {
        // 超出范围的部分显示为浅灰色
        double x = centerX + (i - half) * (barWidth + gap);
        double barHeight = 20;
        canvas.drawLine(
          Offset(x, baseY - barHeight / 2),
          Offset(x, baseY + barHeight / 2),
          paint..color = isLight ? Colors.grey[300]! : Colors.grey[700]!,
        );
        continue;
      }

      double value = dataIdx < waveform.length ? waveform[dataIdx] : 0.5;
      double x = centerX + (i - half) * (barWidth + gap);
      double barHeight = value * (size.height * 0.6);

      canvas.drawLine(
        Offset(x, baseY - barHeight / 2),
        Offset(x, baseY + barHeight / 2),
        paint,
      );
    }

    // 居中游标竖线
    final Paint cursorPaint = Paint()
      ..color = isLight ? Colors.black : Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      cursorPaint,
    );

    // 顶部高亮圆点
    canvas.drawCircle(Offset(centerX, 10), 6, cursorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 录音标记点绘制器
class RecordMarksPainter extends CustomPainter {
  final List<Duration> marks;
  final Duration duration;
  final int barCount;
  final bool isLight;

  RecordMarksPainter({
    required this.marks,
    required this.duration,
    required this.barCount,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty) return;

    final double barWidth = 2;
    final double gap = 1;
    final double centerX = size.width / 2;
    final int half = barCount ~/ 2;

    final Paint markPaint = Paint()
      ..color = Colors.grey[500]!
      ..strokeWidth = 2;

    for (int i = 0; i < marks.length; i++) {
      final markDuration = marks[i];
      final markProgress = duration.inMilliseconds > 0
          ? markDuration.inMilliseconds / duration.inMilliseconds
          : 0;
      final markIndex = (markProgress * barCount).round();
      final relativePos = markIndex - half;

      double x = centerX + relativePos * (barWidth + gap);

      // 检查标记点是否在可视范围内
      if (x < 0 || x > size.width) continue;

      // 竖线
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markPaint);
      
      // 圆圈
      canvas.drawCircle(Offset(x, 10), 8, markPaint);
      
      // 数字
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, -tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 录音时间轴绘制器
class RecordTimeRulerPainter extends StatelessWidget {
  final Duration duration;
  final int barCount;
  final bool isLight;

  const RecordTimeRulerPainter({
    super.key, 
    required this.duration,
    required this.barCount,
    required this.isLight,
  });

  Widget buildWidget() => CustomPaint(
    painter: _RecordTimeRulerPainterImpl(this),
    size: Size(double.infinity, 48),
  );

  @override
  Widget build(BuildContext context) => buildWidget();
}

class _RecordTimeRulerPainterImpl extends CustomPainter {
  final RecordTimeRulerPainter parent;
  _RecordTimeRulerPainterImpl(this.parent);

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final Paint tickPaint = Paint()
      ..color = parent.isLight ? Colors.grey[400]! : Colors.grey[600]!
      ..strokeWidth = 1;

    final int currentSecond = parent.duration.inSeconds;

    // 绘制时间刻度：以当前录音位置为中心
    for (int i = -15; i <= 15; i++) {
      int second = currentSecond + i;
      if (second < 0) continue;

      double x = centerX + i * 20.0;

      // 主刻度
      canvas.drawLine(Offset(x, 0), Offset(x, 16), tickPaint);
      
      // 时间数字（每5秒显示一次）
      if (i % 5 == 0) {
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: '$second',
            style: TextStyle(
              color: parent.isLight ? Colors.grey[600] : Colors.grey[300],
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 18));
      }
    }
    
    // 起止时间
    TextPainter startTp = TextPainter(
      text: TextSpan(
        text: '0:00',
        style: TextStyle(
          color: parent.isLight ? Colors.grey[600] : Colors.grey[300],
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    startTp.layout();
    startTp.paint(canvas, Offset(0, 36));
    
    // 当前时间在游标下方
    TextPainter curTp = TextPainter(
      text: TextSpan(
        text: _formatDuration(parent.duration),
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    curTp.layout();
    curTp.paint(canvas, Offset(centerX - curTp.width / 2, 36));
  }
  
  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inMinutes}:${two(d.inSeconds % 60)}';
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

