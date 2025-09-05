import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'rust_waveform.dart';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart'; // for calloc
import 'package:shared_preferences/shared_preferences.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Timer? _timer;
  Duration _duration = Duration.zero;
  String? _filePath;
  final List<double> _waveform = [];
  final List<Duration> _marks = [];
  final double _currentAmplitude = 0.5; // 实时音量
  static const int sampleRate = 16; // 每秒16个采样点
  static const int maxBars = 800; // 最多显示的波形条数

  // 添加动画控制器
  late AnimationController _waveformController;
  late AnimationController _timerController;
  double _currentWaveformValue = 0.0;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _timerController = AnimationController(
      duration: const Duration(milliseconds: 62),
      vsync: this,
    );

    // 监听波形动画，使用更平滑的插值
    _waveformController.addListener(() {
      setState(() {
        // 使用更平滑的插值函数，减少一顿一顿的感觉
        _currentWaveformValue =
            0.7 + 0.3 * (1.0 + sin(_waveformController.value * 2 * pi)) / 2;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveformController.dispose();
    _timerController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // 请求麦克风权限
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      print('麦克风权限被拒绝');
      return;
    }

    // 请求存储权限（Android）
    if (Platform.isAndroid) {
      if (await Permission.microphone.request() != PermissionStatus.granted) {
        print('麦克风权限被拒绝');
        return;
      }
      if (await Permission.storage.request() != PermissionStatus.granted) {
        print('存储权限被拒绝，尝试继续录音');
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final folderName = _generateFolderName();
    final folder = Directory('${dir.path}/$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    final quality = prefs.getString('audio_quality') ?? 'wav';
    String ext = quality == 'aac' ? 'aac' : 'wav';
    AudioEncoder encoder = quality == 'aac'
        ? AudioEncoder.aacLc
        : AudioEncoder.wav;
    final filePath = '${folder.path}/audio.$ext'; // 动态文件名
    _filePath = filePath;

    try {
      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: _filePath!,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _duration = Duration.zero;
        _waveform.clear();
        _marks.clear();
      });

      _timer = Timer.periodic(const Duration(milliseconds: 62), (_) {
        if (!_isPaused && _isRecording) {
          _duration += const Duration(milliseconds: 62);
          final random = Random();
          final amplitude = 0.2 + 0.8 * random.nextDouble();
          _waveform.add(amplitude);
          if (_waveform.length > maxBars) {
            _waveform.removeAt(0);
          }
          if (_waveform.length % 8 == 0) {
            setState(() {});
          }
        }
      });
      _waveformController.repeat();
    } catch (e) {
      print('开始录音失败: $e');
    }
  }

  void _onAudioData(List<int> data) {
    // 此方法暂时未使用，因为record插件的onData回调在当前版本中不可用
    // 在实际项目中可以通过其他方式获取实时音频数据
  }

  void _togglePause() async {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _timer?.cancel();
        // 暂停录音
        _recorder.pause();
      } else {
        // 恢复录音
        _recorder.resume();
        _timer = Timer.periodic(const Duration(milliseconds: 62), (_) {
          if (!_isPaused && _isRecording) {
            setState(() {
              _duration += const Duration(milliseconds: 62);
              double amp = 0.2 + 0.8 * Random().nextDouble();
              _waveform.add(amp);
              if (_waveform.length > maxBars) _waveform.removeAt(0);
            });
          }
        });
      }
    });
  }

  void _addMark() {
    if (_isRecording && !_isPaused) {
      setState(() {
        _marks.add(_duration);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加标记点: ${_formatTimer(_duration)}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      // 先停止定时器和动画
      _timer?.cancel();
      _waveformController.stop();

      // 停止录音
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      // 检查录音文件是否生成
      if (path != null && path.isNotEmpty) {
        _filePath = path;
        final audioFile = File(path);

        // 等待文件写入完成
        await Future.delayed(const Duration(milliseconds: 500));

        if (await audioFile.exists()) {
          final fileSize = await audioFile.length();
          print('录音文件已生成: ${audioFile.path}, 大小: $fileSize 字节');

          if (fileSize > 0) {
            await _saveWaveformData();
            await _saveMarksData();
            await _saveSubtitleData([]);
            print('录音完成，文件大小正常');
            await _addToMetaData();
          } else {
            print('警告：录音文件大小为0，可能录音失败');
          }
        } else {
          print('错误：录音文件未生成');
        }
      } else {
        print('错误：录音停止但未返回文件路径');
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
      final normalizedWaveData = _normalizeWaveData(_waveform);
      final folder = File(_filePath!).parent;
      final waveFile = File('${folder.path}/wave.json');
      await waveFile.writeAsString(jsonEncode(normalizedWaveData));
      print('波形数据已保存到: ${waveFile.path}');
    } catch (e) {
      print('保存波形数据时出错: $e');
      try {
        final defaultWaveData = List.generate(
          200,
          (index) => (0.2 + 0.4 * (index % 10) / 10.0).toDouble(),
        );
        final folder = File(_filePath!).parent;
        final waveFile = File('${folder.path}/wave.json');
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
      final folder = File(_filePath!).parent;
      final marksFile = File('${folder.path}/marks.json');
      await marksFile.writeAsString(jsonEncode(marksData));
      print('标记数据已保存到: ${marksFile.path}');
    } catch (e) {
      print('保存标记数据时出错: $e');
    }
  }

  Future<void> _saveSubtitleData(List<Map<String, dynamic>> subtitles) async {
    try {
      final folder = File(_filePath!).parent;
      final subtitleFile = File('${folder.path}/subtitle.json');
      await subtitleFile.writeAsString(jsonEncode(subtitles));
      print('字幕数据已保存到: ${subtitleFile.path}');
    } catch (e) {
      print('保存字幕数据时出错: $e');
    }
  }

  Future<void> _addToMetaData() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = File(_filePath!).parent;
    final timeKey = folder.path.split(Platform.pathSeparator).last;
    // 文件名直接为 marks.json、wave.json、subtitle.json
    final prefs = await SharedPreferences.getInstance();
    final quality = prefs.getString('audio_quality') ?? 'wav';
    final audioFileName = 'audio.$quality';
    final audioRelPath = '$timeKey/$audioFileName';
    final waveRelPath = '$timeKey/wave.json';
    final marksRelPath = '$timeKey/marks.json';
    final subtitleRelPath = '$timeKey/subtitle.json';
    final metaFile = File('${dir.path}/meta.json');
    print('meta.json 路径: ${metaFile.path}');
    print('写入meta.json: $timeKey');
    List<dynamic> metaList = [];
    try {
      if (await metaFile.exists()) {
        metaList = jsonDecode(await metaFile.readAsString());
      }
      metaList.add({
        'id': timeKey,
        'audioPath': audioRelPath,
        'wavePath': waveRelPath,
        'marksPath': marksRelPath,
        'subtitlePath': subtitleRelPath,
        'displayName': timeKey,
        'tag': '--',
        'created': DateTime.now().toIso8601String(),
        'played': false,
      });
      await metaFile.writeAsString(jsonEncode(metaList));
      print('meta.json 写入成功');
    } catch (e) {
      print('meta.json 写入失败: $e');
    }
  }

  List<double> _normalizeWaveData(List<double> data) {
    if (data.isEmpty) return data;
    double maxVal = data.map((e) => e.abs()).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return data;
    return data.map((e) => e / maxVal).toList();
  }

  String _generateRandomId() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return '$year-$month-${day}_${hour}_${minute}_$second';
  }

  String _generateFolderName() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$year$month${day}_$hour$minute$second';
  }

  String _formatTimer(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    String hundredths = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}.$hundredths';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRecording) {
          await _stopRecording();
          return false; // 等待保存后再返回
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            '录音',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onPressed: () {},
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // 大号计时器
              Center(
                child: SizedBox(
                  width: 200,
                  child: Text(
                    _formatTimer(_duration),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 实时波形显示（与播放器保持一致的高度和布局）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    // 波形区（高度提升，与播放器一致）
                    SizedBox(
                      height: 220,
                      child: CustomPaint(
                        painter: VerticalWaveformPainter(
                          waveform: _waveform,
                          barCount: maxBars,
                          marks: _marks,
                          duration: _duration,
                        ),
                        child: Container(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 时间轴（与播放器一致）
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final barCount = width ~/ 3;
                          return TimeRulerPainter(
                            duration: _duration,
                            barCount: barCount * 2,
                            waveform: _waveform,
                          ).buildWidget();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 底部控制区（与播放器保持一致的布局）
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 标记按钮
                    IconButton(
                      onPressed: _isRecording && !_isPaused ? _addMark : null,
                      icon: Icon(
                        Icons.flag,
                        color: Theme.of(context).iconTheme.color,
                        size: 28,
                      ),
                    ),
                    // 录音/停止大圆按钮（始终居中）
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red : Colors.black,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // 暂停/恢复按钮（仅录音时可用）
                    IconButton(
                      onPressed: _isRecording ? _togglePause : null,
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: _isRecording
                            ? Theme.of(context).iconTheme.color
                            : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerticalWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final int barCount;
  final List<Duration> marks;
  final Duration duration;
  VerticalWaveformPainter({
    required this.waveform,
    required this.barCount,
    required this.marks,
    required this.duration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final barWidth = 2.0, gap = 2.0;
    final spacing = barWidth + gap;
    final half = barCount ~/ 2;
    final totalBars = waveform.length;
    final barMaxLen = size.height / 2 - 24;
    final Paint barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    // 居中对齐，中心为当前录音点
    for (int i = 0; i < barCount; i++) {
      int dataIdx = totalBars - half + i;
      double amp = (dataIdx < 0)
          ? 0
          : (dataIdx < waveform.length ? waveform[dataIdx] : 0);
      double barLen = barMaxLen * amp;
      // 渐变色
      barPaint.shader =
          LinearGradient(
            colors: [Colors.blue, Colors.orange],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(
              centerX + (i - half) * spacing,
              centerY - barLen,
              barWidth,
              barLen * 2,
            ),
          );
      canvas.drawLine(
        Offset(centerX + (i - half) * spacing, centerY - barLen),
        Offset(centerX + (i - half) * spacing, centerY + barLen),
        barPaint,
      );
    }
    // 标记点
    for (final mark in marks) {
      final seconds = mark.inMilliseconds / 1000.0;
      final idx =
          (seconds.isNaN || seconds.isInfinite ? 0 : seconds) *
          (_RecordPageState.sampleRate > 0 ? _RecordPageState.sampleRate : 1);
      int markIdx = idx.round();
      double x = centerX + (markIdx - totalBars) * spacing;
      if (x < 0 || x > size.width) continue;
      final Paint markPaint = Paint()
        ..color = Colors.grey[300]!
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markPaint);
      canvas.drawCircle(Offset(x, 10), 8, markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TimeRulerPainter extends StatelessWidget {
  final Duration duration;
  final int barCount;
  final List<double> waveform;
  const TimeRulerPainter({
    super.key,
    required this.duration,
    required this.barCount,
    required this.waveform,
  });

  Widget buildWidget() => CustomPaint(
    painter: _TimeRulerPainterImpl(this),
    size: Size(double.infinity, 48),
  );

  @override
  Widget build(BuildContext context) => buildWidget();
}

class _TimeRulerPainterImpl extends CustomPainter {
  final TimeRulerPainter parent;
  _TimeRulerPainterImpl(this.parent);

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final Paint tickPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;

    final int totalBars = parent.waveform.length;
    final double barWidth = 2.0, gap = 2.0, spacing = barWidth + gap;
    final int sampleRate = _RecordPageState.sampleRate;
    final int totalSeconds = parent.duration.inSeconds;
    final int half = parent.barCount ~/ 2;

    // 以当前录音点为中心，绘制前后各15秒
    for (int i = -15; i <= 15; i++) {
      int second = totalSeconds + i;
      if (second < 0) continue;
      int dataIdx = (sampleRate > 0 ? second * sampleRate : 0);
      double x = centerX + (dataIdx - totalBars) * spacing;
      if (x.isNaN || x.isInfinite) x = 0.0;
      // 主刻度
      canvas.drawLine(Offset(x, 0), Offset(x, 16), tickPaint);
      // 时间数字（每1秒显示一次，格式00:01）
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: _formatTimeLabel(second),
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 18));
    }
  }

  String _formatTimeLabel(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Save waveform data to file as JSON
dynamic saveWaveformToFile(List<double> waveformData, String filePath) async {
  final file = File(filePath);
  final jsonStr = jsonEncode(waveformData);
  await file.writeAsString(jsonStr);
}

/// Load waveform data from file as List<double>
dynamic loadWaveformFromFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('Waveform file not found');
  }
  final jsonStr = await file.readAsString();
  final List<dynamic> jsonList = jsonDecode(jsonStr);
  return jsonList.cast<double>();
}

// 在录音结束的地方补充保存波形数据逻辑
void onRecordFinish(String audioPath, List<double> waveformData) async {
  // Save waveform data file with same name as audio file
  final waveformPath = audioPath.replaceAll(
    RegExp(r'\.(wav|aac|m4a|mp3)\$'),
    '.waveform.json',
  );
  await saveWaveformToFile(waveformData, waveformPath);
  // ... 其他录音结束逻辑 ...
}

// 录音页面暂未实现 extractPcmSamples，直接引用播放器页面的未实现方法
Future<List<double>> extractPcmSamples(String audioPath) async {
  // TODO: Implement actual PCM extraction logic (AAC to PCM float array)
  throw UnimplementedError('extractPcmSamples must be implemented');
}
