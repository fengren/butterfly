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
  late AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  List<Duration> _marks = []; // 标记点列表

  // 新增：波形拖动相关状态
  double waveformDragOffset = 0.0;
  bool isDraggingWaveform = false;

  // 新增：拖动时记录播放状态
  bool wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadMarks();
  }

  Future<void> _initAudio() async {
    try {
      _positionSubscription = _audioPlayer.onPositionChanged.listen((
        Duration position,
      ) {
        setState(() {
          _position = position;
        });
      });
      _durationSubscription = _audioPlayer.onDurationChanged.listen((
        Duration duration,
      ) {
        setState(() {
          _duration = duration;
        });
      });
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        
        // 处理播放完成
        if (state == PlayerState.stopped) {
          setState(() {
            _position = Duration.zero;
            _isPlaying = false;
          });
        }
      });
      
      await _audioPlayer.setSource(DeviceFileSource(widget.filePath));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('初始化音频失败: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMarks() async {
    try {
      final marksFile = File('${widget.filePath}.marks.json');
      if (await marksFile.exists()) {
        final content = await marksFile.readAsString();
        final marksData = jsonDecode(content) as List;
        setState(() {
          _marks = marksData
              .map((milliseconds) => Duration(milliseconds: milliseconds))
              .toList();
        });
        print('成功加载标记点，数量: ${_marks.length}');
      } else {
        print('标记文件不存在: ${marksFile.path}');
      }
    } catch (e) {
      print('加载标记点时出错: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // 如果播放位置在末尾或播放已完成，重新开始播放
        if (_position >= _duration && _duration > Duration.zero) {
          await _audioPlayer.seek(Duration.zero);
          setState(() {
            _position = Duration.zero;
          });
        }
        await _audioPlayer.resume();
      }
    } catch (e) {
      print('播放/暂停操作失败: $e');
    }
  }

  void _seekToPosition(double dx, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    if (_duration.inMilliseconds == 0) return;
    final percent = (dx / width).clamp(0.0, 1.0);
    final seekMillis = (_duration.inMilliseconds * percent).toInt();
    _audioPlayer.seek(Duration(milliseconds: seekMillis));
  }

  int? _calculateCursorIndex(int barCount) {
    if (widget.waveform.isEmpty || _duration.inMilliseconds == 0) return null;
    final totalBars = barCount;
    final percent = _position.inMilliseconds / _duration.inMilliseconds;
    final cursorIndex = (totalBars * percent).floor();
    return (cursorIndex >= 0 && cursorIndex < totalBars) ? cursorIndex : null;
  }

  List<int> _calculateMarkIndices(int barCount) {
    if (_marks.isEmpty || _duration.inMilliseconds == 0) return [];
    final totalBars = barCount;
    return _marks
        .map((mark) {
          final percent = mark.inMilliseconds / _duration.inMilliseconds;
          final markIndex = (totalBars * percent).floor();
          return (markIndex >= 0 && markIndex < totalBars) ? markIndex : -1;
        })
        .where((index) => index >= 0)
        .toList();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inMinutes}:${two(d.inSeconds % 60)}';
  }

  void _retryPlay() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _audioPlayer.setSource(DeviceFileSource(widget.filePath));
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('重试播放失败: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _addMark() {
    if (_isPlaying || !_isPlaying) {
      // 播放或暂停时都可以添加标记
      setState(() {
        _marks.add(_position);
        // 按时间顺序排序
        _marks.sort((a, b) => a.compareTo(b));
      });

      // 保存标记到文件
      _saveMarks();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已添加标记点 ${_marks.length}: ${_formatDuration(_position)}',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveMarks() async {
    try {
      final marksData = _marks
          .map((duration) => duration.inMilliseconds)
          .toList();
      final marksFile = File('${widget.filePath}.marks.json');
      await marksFile.writeAsString(jsonEncode(marksData));
      print('标记数据已保存到: ${marksFile.path}');
    } catch (e) {
      print('保存标记数据时出错: $e');
    }
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
                _formatDuration(_position),
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
                  // 拖动开始时暂停播放
                  if (_isPlaying) {
                    await _audioPlayer.pause();
                  }
                  setState(() {
                    isDraggingWaveform = true;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    waveformDragOffset += details.delta.dx * 0.2; // 调整拖动灵敏度到20%
                    final width = MediaQuery.of(context).size.width - 16;
                    final barCount = (width ~/ 3) * 2;
                    final percentDelta = -waveformDragOffset / width;
                    double currentPercent =
                        (_position.inMilliseconds /
                            (_duration.inMilliseconds == 0
                                ? 1
                                : _duration.inMilliseconds)) +
                        percentDelta;
                    currentPercent = currentPercent.clamp(0.0, 1.0);
                    final newMillis =
                        (currentPercent * _duration.inMilliseconds).toInt();
                    _audioPlayer.seek(Duration(milliseconds: newMillis));
                  });
                },
                onHorizontalDragEnd: (details) async {
                  setState(() {
                    isDraggingWaveform = false;
                    waveformDragOffset = 0.0;
                  });
                  // 如果之前正在播放，拖动结束后恢复播放
                  if (wasPlaying) {
                    await _audioPlayer.resume();
                  }
                },
                child: Column(
                  children: [
                    // 波形区（高度提升，时间轴下移）
                    SizedBox(
                      height: 200,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final barCount = width ~/ 3;
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
                                size: Size(width, 200),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 时间轴区（下移）
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final barCount = width ~/ 3;
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
                          ).buildWidget();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 进度条（极简灰色）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                    _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
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
                  // 快退按钮（自定义带3的图标）
                  _QuickSeekButton(
                    forward: false,
                    seconds: 5,
                    onTap: () {
                      final newPosition =
                          _position - const Duration(seconds: 5);
                      if (newPosition.inMilliseconds >= 0) {
                        _audioPlayer.seek(newPosition);
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  // 播放/暂停大圆按钮
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
                  const SizedBox(width: 24),
                  // 快进按钮（自定义带3的图标）
                  _QuickSeekButton(
                    forward: true,
                    seconds: 5,
                    onTap: () {
                      final newPosition =
                          _position + const Duration(seconds: 5);
                      if (newPosition.inMilliseconds <=
                          _duration.inMilliseconds) {
                        _audioPlayer.seek(newPosition);
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  // 速度按钮（1x，黑色字体，右对齐）
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          '1x',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
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

// 自定义快进/快退按钮（图标内部带数字3）
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 主图标
            Icon(
              forward ? Icons.forward_5 : Icons.replay_5,
              color: Colors.black,
              size: 32,
            ),
            // 数字3，覆盖在图标上
            Positioned(
              right: forward ? 12 : null,
              left: forward ? null : 12,
              bottom: 12,
              child: Text(
                '$seconds',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
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
      CustomPaint(painter: this, size: Size(double.infinity, 200));

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = 2;
    final double gap = 1;
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

    // 绘制波形：从中间开始，向左显示已播放部分，向右显示未播放部分
    for (int i = 0; i < barCount; i++) {
      int dataIdx = currentBar - half + i;
      if (dataIdx < 0 || dataIdx >= totalBars) {
        // 超出范围的部分显示为浅灰色
        double x = centerX + (i - half) * (barWidth + gap) + dragOffset;
        double barHeight = 20; // 默认高度
        canvas.drawLine(
          Offset(x, baseY - barHeight / 2),
          Offset(x, baseY + barHeight / 2),
          unplayedPaint..strokeWidth = barWidth,
        );
        continue;
      }
      
      double value = waveform[dataIdx];
      double x = centerX + (i - half) * (barWidth + gap) + dragOffset;
      double barHeight = value * (size.height * 0.6);

      // 判断是已播放还是未播放区域
      Paint paint = i < half ? playedPaint : unplayedPaint;
      
      canvas.drawLine(
        Offset(x, baseY - barHeight / 2),
        Offset(x, baseY + barHeight / 2),
        paint..strokeWidth = barWidth,
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
  const TimeRulerPainter({
    required this.duration,
    required this.barCount,
    required this.cursorIndex,
    required this.markIndices,
    required this.dragOffset,
    required this.isLight,
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
    final double barWidth = 2;
    final double gap = 1;
    final int half = parent.barCount ~/ 2;

    // 计算当前播放进度
    final double playProgress = parent.cursorIndex / parent.barCount;
    final int currentSecond = (playProgress * parent.duration.inSeconds)
        .round();

    final Paint tickPaint = Paint()
      ..color = parent.isLight ? Colors.grey[400]! : Colors.grey[600]!
      ..strokeWidth = 1;

    // 绘制时间刻度：以当前播放位置为中心
    for (int i = -15; i <= 15; i++) {
      int second = currentSecond + i;
      if (second < 0 || second > parent.duration.inSeconds) continue;

      double x = centerX + i * 20.0 + parent.dragOffset;

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

    TextPainter endTp = TextPainter(
      text: TextSpan(
        text: _formatDuration(parent.duration),
        style: TextStyle(
          color: parent.isLight ? Colors.grey[600] : Colors.grey[300],
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    endTp.layout();
    endTp.paint(canvas, Offset(size.width - endTp.width, 36));
    
    // 当前时间在游标下方
    TextPainter curTp = TextPainter(
      text: TextSpan(
        text: _formatDuration(Duration(seconds: currentSecond)),
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
