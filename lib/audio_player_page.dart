import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  List<Duration> _marks = [];
  double waveformDragOffset = 0.0;
  bool isDraggingWaveform = false;

  // 新增：拖动时记录播放状态
  bool wasPlaying = false;

  // 新增：播放倍速
  double _playbackRate = 1.0;
  final List<double> _playbackRates = [1.0, 1.5, 2.0, 0.5, 0.75];

  // 新增：顶部时间更新定时器
  Timer? _topTimeTimer;
  Duration _displayPosition = Duration.zero;
  DateTime? _playStartTime;
  Duration _playStartPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _startTopTimeTimer();
  }

  void _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();

    // 监听播放状态变化
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          // 如果播放完成，重置播放位置到开始
          if (state == PlayerState.stopped) {
            _position = Duration.zero;
          }
        });
        
        // 记录播放开始时间和位置
        if (state == PlayerState.playing) {
          _playStartTime = DateTime.now();
          _playStartPosition = _position;
        } else {
          _playStartTime = null;
        }
      }
    });

    // 监听播放位置变化
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // 监听音频时长变化
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // 监听播放完成
    _audioPlayer.onPlayerComplete.listen((_) async {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero; // 重置进度
          _displayPosition = Duration.zero; // 重置显示
        });
        _playStartTime = null;
        // 确保音频播放器也seek到开始位置
        await _audioPlayer.seek(Duration.zero);
      }
    });

    // 加载音频文件
    try {
      await _audioPlayer.setSource(DeviceFileSource(widget.filePath));
      await _loadMarks();
    } catch (e) {
      print('加载音频文件失败: $e');
    }
  }

  Future<void> _loadMarks() async {
    try {
      final marksFile = File('${widget.filePath}.marks.json');
      if (await marksFile.exists()) {
        final content = await marksFile.readAsString();
        final data = jsonDecode(content);
        _marks = data
            .map<Duration>((e) => Duration(milliseconds: e as int))
            .toList();
      }
    } catch (e) {
      print('加载标记数据失败: $e');
    }
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // 如果播放位置在末尾或播放已完成，重新开始播放
      if (_position >= _duration && _duration > Duration.zero) {
        await _audioPlayer.seek(Duration.zero);
        setState(() {
          _position = Duration.zero;
          _displayPosition = Duration.zero;
          _playStartTime = DateTime.now();
          _playStartPosition = Duration.zero;
        });
      } else {
        setState(() {
          _playStartTime = DateTime.now();
          _playStartPosition = _position;
        });
      }
      await _audioPlayer.resume();
    }
  }

  void _addMark() {
    setState(() {
      _marks.add(_position);
    });
    
    // 保存标记数据
    _saveMarks();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加标记点: ${_formatDuration(_position)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveMarks() async {
    try {
      final marksData = _marks
          .map((duration) => duration.inMilliseconds)
          .toList();
      final marksFile = File('${widget.filePath}.marks.json');
      await marksFile.writeAsString(jsonEncode(marksData));
    } catch (e) {
      print('保存标记数据失败: $e');
    }
  }

  // 新增：切换播放倍速
  void _togglePlaybackRate() async {
    setState(() {
      int currentIndex = _playbackRates.indexOf(_playbackRate);
      int nextIndex = (currentIndex + 1) % _playbackRates.length;
      _playbackRate = _playbackRates[nextIndex];
    });

    // 应用新的播放倍速
    await _audioPlayer.setPlaybackRate(_playbackRate);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    // 计算0.01秒精度：毫秒数除以10，然后取整
    int centiseconds = (d.inMilliseconds % 1000) ~/ 10;
    String cs = centiseconds.toString().padLeft(2, '0');
    // 使用固定宽度格式：00:00.00
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}.$cs';
  }

  // 新增：时间轴格式化函数（00:01格式）
  String _formatTimeAxis(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  int? _calculateCursorIndex(int barCount) {
    if (_duration.inMilliseconds == 0) return null;
    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    return (progress * barCount).round();
  }

  List<int> _calculateMarkIndices(int barCount) {
    if (_duration.inMilliseconds == 0) return [];
    return _marks.map((mark) {
      final progress = mark.inMilliseconds / _duration.inMilliseconds;
      return (progress * barCount).round();
    }).toList();
  }

  void _startTopTimeTimer() {
    _topTimeTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (mounted) {
        if (_isPlaying && _playStartTime != null) {
          // 计算从开始播放到现在的时间
          final elapsed = DateTime.now().difference(_playStartTime!);
          final newPosition = _playStartPosition + elapsed;
          setState(() {
            _displayPosition = newPosition;
          });
        } else {
          // 不在播放时，直接使用当前位置
          setState(() {
            _displayPosition = _position;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    _topTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 极简浅色主题
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          '文件名/标题',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
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
                _formatDuration(_displayPosition),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // AI识音按钮（如有）
            // Center(
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
            //       borderRadius: BorderRadius.circular(24),
            //     ),
            //     child: const Text('AI识音', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            //   ),
            // ),
            // const SizedBox(height: 8),
            // 波形区+时间轴整体拖动
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GestureDetector(
                onHorizontalDragStart: (details) async {
                  wasPlaying = _isPlaying;
                  // 拖动开始时强制暂停
                  await _audioPlayer.pause();
                  setState(() {
                    isDraggingWaveform = true;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    waveformDragOffset += details.delta.dx * 0.3; // 调整拖动灵敏度到30%
                  });

                  // 拖动过程中实时更新播放位置，让声纹图显示正确的播放状态
                  final width = MediaQuery.of(context).size.width - 16;
                  final int totalSeconds = _duration.inSeconds;
                  final int totalDataPoints = totalSeconds * 20;
                  final int barCount = (totalDataPoints / 2).round().clamp(
                    50,
                    200,
                  );
                  final percentDelta = -waveformDragOffset / width;

                  double currentPercent;
                  if (_position >= _duration) {
                    currentPercent = 1.0 + percentDelta;
                  } else {
                    currentPercent =
                        (_position.inMilliseconds /
                            (_duration.inMilliseconds == 0
                                ? 1
                                : _duration.inMilliseconds)) +
                        percentDelta;
                  }
                  currentPercent = currentPercent.clamp(0.0, 1.0);
                  final newMillis = (currentPercent * _duration.inMilliseconds)
                      .toInt();

                  // 实时更新位置状态，让声纹图显示正确的播放进度
                  if (newMillis >= 0 && newMillis <= _duration.inMilliseconds) {
                    setState(() {
                      _position = Duration(milliseconds: newMillis);
                      _displayPosition = Duration(milliseconds: newMillis);
                    });
                  }
                },
                onHorizontalDragEnd: (details) async {
                  // 拖动结束时执行seek操作
                  final width = MediaQuery.of(context).size.width - 16;
                  final int totalSeconds = _duration.inSeconds;
                  final int totalDataPoints = totalSeconds * 20;
                  final int barCount = (totalDataPoints / 2).round().clamp(
                    50,
                    200,
                  );
                  final percentDelta = -waveformDragOffset / width;

                  double currentPercent;
                  if (_position >= _duration) {
                    currentPercent = 1.0 + percentDelta;
                  } else {
                    currentPercent =
                        (_position.inMilliseconds /
                            (_duration.inMilliseconds == 0
                                ? 1
                                : _duration.inMilliseconds)) +
                        percentDelta;
                  }
                  currentPercent = currentPercent.clamp(0.0, 1.0);
                  final newMillis = (currentPercent * _duration.inMilliseconds)
                      .toInt();

                  setState(() {
                    isDraggingWaveform = false;
                    waveformDragOffset = 0.0;
                  });

                  // 执行seek操作
                  if (newMillis >= 0 && newMillis <= _duration.inMilliseconds) {
                    await _audioPlayer.seek(Duration(milliseconds: newMillis));
                  }

                  // 拖动结束后根据当前位置恢复播放
                  if (_position < _duration) {
                    if (wasPlaying) await _audioPlayer.resume();
                  } else {
                    // 拖到结尾，重置到开头并播放
                    await _audioPlayer.seek(Duration.zero);
                    setState(() {
                      _position = Duration.zero;
                      _displayPosition = Duration.zero;
                    });
                    if (wasPlaying) await _audioPlayer.resume();
                  }
                },
                child: Column(
                  children: [
                    // 波形区（高度提升，时间轴下移）
                    SizedBox(
                      height: 240,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          // 基于每秒20个数据计算barCount
                          final int totalSeconds = _duration.inSeconds;
                          final int totalDataPoints =
                              totalSeconds * 20; // 每秒20个数据
                          final int barCount = (totalDataPoints / 2)
                              .round()
                              .clamp(50, 200); // 限制在合理范围内
                          final cursorIndex =
                              _calculateCursorIndex(barCount * 2) ?? 0;
                          final markIndices = _calculateMarkIndices(
                            barCount * 2,
                          );
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              BarWaveformPainter(
                                widget.waveform,
                                cursorIndex: cursorIndex,
                                barCount: barCount * 2,
                                dragOffset: waveformDragOffset,
                                isLight: true,
                              ).buildWidget(),
                              CustomPaint(
                                painter: MarksPainter(
                                  markIndices: markIndices,
                                  barCount: barCount * 2,
                                  sortedMarkIndices: markIndices,
                                  dragOffset: waveformDragOffset,
                                  isLight: true,
                                ),
                                size: Size(width, 240),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 时间轴区（下移）
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          // 基于每秒20个数据计算barCount
                          final int totalSeconds = _duration.inSeconds;
                          final int totalDataPoints =
                              totalSeconds * 20; // 每秒20个数据
                          final int barCount = (totalDataPoints / 2)
                              .round()
                              .clamp(50, 200); // 限制在合理范围内
                          final cursorIndex =
                              _calculateCursorIndex(barCount * 2) ?? 0;
                          final markIndices = _calculateMarkIndices(
                            barCount * 2,
                          );
                          return TimeRulerPainter(
                            duration: _duration,
                            barCount: barCount * 2,
                            cursorIndex: cursorIndex,
                            markIndices: markIndices,
                            dragOffset: waveformDragOffset,
                            isLight: true,
                            formatFunction: _formatTimeAxis,
                          ).buildWidget();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // 进度条（极简灰色，下移）
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 16.0,
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.grey[400],
                  inactiveTrackColor: Colors.grey[200],
                  thumbColor: Colors.black,
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble().clamp(
                    0,
                    _duration.inMilliseconds.toDouble(),
                  ),
                  min: 0,
                  max: _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1,
                  onChanged: (value) {
                    final newPosition = Duration(milliseconds: value.toInt());
                    _audioPlayer.seek(newPosition);
                    _position = newPosition; // 立即更新位置状态
                    // 如果正在播放，更新播放开始位置
                    if (_isPlaying) {
                      _playStartTime = DateTime.now();
                      _playStartPosition = _position;
                    }
                  },
                ),
              ),
            ),
            // 底部控制区
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 小旗子（标记）按钮
                  IconButton(
                    onPressed: _addMark,
                    icon: Icon(Icons.flag, color: Colors.black, size: 28),
                  ),
                  // 快退按钮
                  _QuickSeekButton(
                    forward: false,
                    seconds: 5,
                    onTap: () {
                      final newPosition =
                          _position - const Duration(seconds: 5);
                      if (newPosition.inMilliseconds >= 0) {
                        _audioPlayer.seek(newPosition);
                        _position = newPosition; // 立即更新位置状态
                        // 如果正在播放，更新播放开始位置
                        if (_isPlaying) {
                          _playStartTime = DateTime.now();
                          _playStartPosition = _position;
                        }
                      } else {
                        // 时间不足时直接从头开始
                        _audioPlayer.seek(Duration.zero);
                        _position = Duration.zero; // 立即更新位置状态
                        // 如果正在播放，更新播放开始位置
                        if (_isPlaying) {
                          _playStartTime = DateTime.now();
                          _playStartPosition = _position;
                        }
                      }
                    },
                  ),
                  // 播放/暂停大圆按钮（居中）
                  GestureDetector(
                    onTap: _playPause,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 36,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // 快进按钮
                  _QuickSeekButton(
                    forward: true,
                    seconds: 5,
                    onTap: () {
                      final newPosition =
                          _position + const Duration(seconds: 5);
                      if (newPosition.inMilliseconds <=
                          _duration.inMilliseconds) {
                        _audioPlayer.seek(newPosition);
                        _position = newPosition; // 立即更新位置状态
                        // 如果正在播放，更新播放开始位置
                        if (_isPlaying) {
                          _playStartTime = DateTime.now();
                          _playStartPosition = _position;
                        }
                      } else {
                        // 时间不足时直接到最后
                        _audioPlayer.seek(_duration);
                        _position = _duration; // 立即更新位置状态
                        // 如果正在播放，更新播放开始位置
                        if (_isPlaying) {
                          _playStartTime = DateTime.now();
                          _playStartPosition = _position;
                        }
                      }
                    },
                  ),
                  // 速度按钮（可点击切换倍速）
                  TextButton(
                    onPressed: _togglePlaybackRate,
                    child: Text(
                      '${_playbackRate.toStringAsFixed(_playbackRate == _playbackRate.toInt() ? 0 : 1)}x',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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

// 自定义快进/快退按钮（只保留图标）
class _QuickSeekButton extends StatelessWidget {
  final bool forward;
  final int seconds;
  final VoidCallback onTap;
  const _QuickSeekButton({
    required this.forward,
    required this.seconds,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          forward ? Icons.forward_5 : Icons.replay_5,
          color: Colors.black,
          size: 32,
        ),
      ),
    );
  }
}

// BarWaveformPainter
class BarWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final int cursorIndex;
  final int barCount;
  final double dragOffset;
  final bool isLight;
  BarWaveformPainter(
    this.waveform, {
    required this.cursorIndex,
    required this.barCount,
    required this.dragOffset,
    required this.isLight,
  });

  Widget buildWidget() =>
      CustomPaint(painter: this, size: Size(double.infinity, 240));

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = 2; // 增加barWidth以适应较低密度数据
    final double gap = 1; // 增加gap以适应较低密度数据
    final double centerX = size.width / 2;
    final double baseY = size.height / 2;
    final int half = barCount ~/ 2;

    // 计算当前播放进度
    final double playProgress = cursorIndex / barCount;
    final int totalBars = waveform.length;
    final int currentBar = (playProgress * totalBars).round();

    // 已播放区域画笔（深色）
    final Paint playedPaint = Paint()
      ..color = isLight ? Colors.black : Colors.white
      ..strokeCap = StrokeCap.round;

    // 未播放区域画笔（浅灰色）
    final Paint unplayedPaint = Paint()
      ..color = isLight ? Colors.grey[300]! : Colors.grey[700]!
      ..strokeCap = StrokeCap.round;

    // 超出范围画笔（较窄的竖线）
    final Paint overflowPaint = Paint()
      ..color = isLight ? Colors.grey[200]! : Colors.grey[800]!
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1; // 恢复正常的线条宽度

    // 绘制波形：从中间开始，向左显示已播放部分，向右显示未播放部分
    for (int i = 0; i < barCount; i++) {
      int dataIdx = currentBar - half + i;
      double x = centerX + (i - half) * (barWidth + gap) + dragOffset;

      if (dataIdx < 0 || dataIdx >= totalBars) {
        // 超出范围的部分显示为较窄的浅灰色竖线
        double barHeight = 15; // 恢复正常的默认高度
        canvas.drawLine(
          Offset(x, baseY - barHeight / 2),
          Offset(x, baseY + barHeight / 2),
          overflowPaint,
        );
        continue;
      }
      
      double value = waveform[dataIdx];
      double barHeight = value * (size.height * 0.6);

      // 判断是已播放还是未播放区域
      Paint paint = i < half ? playedPaint : unplayedPaint;
      paint.strokeWidth = barWidth;
      
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

// 居中高亮游标Painter（带上下圆点）
class CenterCursorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
    // 上下圆点
    canvas.drawCircle(Offset(midX, 0), 5, paint);
    canvas.drawCircle(Offset(midX, size.height), 5, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// TimeRulerPainter
class TimeRulerPainter extends StatelessWidget {
  final Duration duration;
  final int barCount;
  final int cursorIndex;
  final List<int> markIndices;
  final double dragOffset;
  final bool isLight;
  final String Function(Duration) formatFunction;
  const TimeRulerPainter({
    super.key, 
    required this.duration,
    required this.barCount,
    required this.cursorIndex,
    required this.markIndices,
    required this.dragOffset,
    required this.isLight,
    required this.formatFunction,
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
      ..color = parent.isLight ? Colors.grey[400]! : Colors.grey[600]!
      ..strokeWidth = 1;

    // 计算当前播放进度对应的秒数
    final double playProgress = parent.cursorIndex / parent.barCount;
    final int currentSecond = (playProgress * parent.duration.inSeconds)
        .round();

    // 绘制时间刻度：以当前播放位置为中心
    for (int i = -15; i <= 15; i++) {
      int second = currentSecond + i;
      if (second < 0 || second > parent.duration.inSeconds) continue;

      double x = centerX + i * 20.0 + parent.dragOffset;

      // 主刻度
      canvas.drawLine(Offset(x, 0), Offset(x, 16), tickPaint);
      
      // 时间数字（每1秒显示一次）
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: parent.formatFunction(Duration(seconds: second)),
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
    
    // 起止时间
    TextPainter startTp = TextPainter(
      text: TextSpan(
        text: '00:00',
        style: TextStyle(
          color: parent.isLight ? Colors.grey[600] : Colors.grey[300],
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    startTp.layout();
    startTp.paint(canvas, Offset(0, 36));

    TextPainter endTp = TextPainter(
      text: TextSpan(
        text: parent.formatFunction(parent.duration),
        style: TextStyle(
          color: parent.isLight ? Colors.grey[600] : Colors.grey[300],
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    endTp.layout();
    endTp.paint(canvas, Offset(size.width - endTp.width, 36));
    
    // 当前时间在游标下方（移到底部时间轴）
    TextPainter curTp = TextPainter(
      text: TextSpan(
        text: parent.formatFunction(Duration(seconds: currentSecond)),
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
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// MarksPainter
class MarksPainter extends CustomPainter {
  final List<int> markIndices;
  final int barCount;
  final List<int> sortedMarkIndices;
  final double dragOffset;
  final bool isLight;
  MarksPainter({
    required this.markIndices,
    required this.barCount,
    required this.sortedMarkIndices,
    required this.dragOffset,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = 2;
    final double gap = 1;
    final double centerX = size.width / 2;
    final int half = barCount ~/ 2;

    // 计算当前播放进度
    final double playProgress = sortedMarkIndices.isNotEmpty
        ? sortedMarkIndices.first / barCount
        : 0;
    final int totalBars = 1000; // 假设总波形长度
    final int currentBar = (playProgress * totalBars).round();

    final Paint markPaint = Paint()
      ..color = Colors.grey[500]!
      ..strokeWidth = 2;

    for (int i = 0; i < markIndices.length; i++) {
      int markBar = markIndices[i];
      // 计算标记点相对于当前播放位置的位置
      int relativePos = markBar - currentBar;
      double x = centerX + relativePos * (barWidth + gap) + dragOffset;

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

