import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

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

  // 字幕数据
  List<Map<String, dynamic>> _subtitles = fakeSubtitle;
  String _summary = fakeSummary;
  bool _showFullSubtitle = false;
  bool _showSubtitle = false;

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
        print('播放状态变化: $state');
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });

        // 如果播放完成，立即重新开始播放
        if (state == PlayerState.completed) {
          print('检测到completed状态，重新开始播放');
          _restartPlayback();
        }
      }
    });

    // 监听播放位置变化
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        print('播放位置变化: ${position.inMilliseconds}ms');
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
      print('播放完成事件触发');
      // 播放状态监听器会处理重复播放，这里不需要额外操作
    });

    // 加载音频文件
    try {
      await _audioPlayer.setSource(DeviceFileSource(widget.filePath));
      await _loadMarks();
      // 自动开始播放
      await _audioPlayer.resume();
      print('音频加载完成，自动开始播放');
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
      print('暂停播放');
      await _audioPlayer.pause();
    } else {
      print(
        '开始播放，当前位置: ${_position.inMilliseconds}ms, 总时长: ${_duration.inMilliseconds}ms',
      );

      // 如果播放位置在末尾或播放已完成，重新开始播放
      if (_position >= _duration && _duration > Duration.zero) {
        print('重新开始播放：seek到开始位置');
        await _audioPlayer.seek(Duration.zero);
        setState(() {
          _position = Duration.zero;
          _displayPosition = Duration.zero;
          waveformDragOffset = 0.0;
        });
      }

      try {
        print('调用resume...');
        await _audioPlayer.resume();
        print('resume调用完成');
      } catch (e) {
        print('resume调用失败: $e');
        // 如果resume失败，尝试重新加载音频源
        try {
          print('重新加载音频源...');
          await _audioPlayer.setSource(DeviceFileSource(widget.filePath));
          await _audioPlayer.seek(_position);
          await _audioPlayer.resume();
          print('重新加载音频源后播放成功');
        } catch (e2) {
          print('重新加载音频源也失败: $e2');
        }
      }
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

    // 按照时间顺序排序标记点
    final sortedMarks = List<Duration>.from(_marks)..sort();

    return sortedMarks.map((mark) {
      final progress = mark.inMilliseconds / _duration.inMilliseconds;
      return (progress * barCount).round();
    }).toList();
  }

  void _startTopTimeTimer() {
    _topTimeTimer?.cancel();
    _topTimeTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_isPlaying && mounted) {
        setState(() {
          // 让_displayPosition更细腻地跟随_position
          _displayPosition =
              _position + Duration(milliseconds: 10); // 近似推算，提升流畅感
        });
      } else if (mounted) {
        setState(() {
          _displayPosition = _position;
        });
      }
    });
  }

  @override
  void dispose() {
    _topTimeTimer?.cancel();
    _audioPlayer.dispose();
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
          (() {
            final nameWithExt = widget.filePath
                .split(Platform.pathSeparator)
                .last;
            final name = nameWithExt.contains('.')
                ? nameWithExt.substring(0, nameWithExt.lastIndexOf('.'))
                : nameWithExt;
            return name;
          })(),
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
            if (!_showSubtitle)
              Center(
                child: SizedBox(
                  width: 180,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatDuration(
                            _displayPosition,
                          ).replaceAll('.', '').substring(0, 5),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        WidgetSpan(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Text(
                              '.',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: _formatDuration(_displayPosition).substring(6),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // 声纹区/文本区共用同一块区域
            if (_showSubtitle)
              Expanded(
                child: SubtitleWithMarksWidget(
                  subtitles: _subtitles,
                  position: _displayPosition,
                  marks: _marks,
                  audioDuration: _duration,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GestureDetector(
                  onHorizontalDragStart: (details) async {
                    wasPlaying = _isPlaying;
                    await _audioPlayer.pause();
                    setState(() {
                      isDraggingWaveform = true;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      waveformDragOffset += details.delta.dx * 0.15;
                    });
                    final width = MediaQuery.of(context).size.width - 16;
                    final int totalBars = widget.waveform.length;
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
                    final newMillis =
                        (currentPercent * _duration.inMilliseconds).toInt();
                    if (newMillis >= 0 &&
                        newMillis <= _duration.inMilliseconds) {
                      setState(() {
                        _position = Duration(milliseconds: newMillis);
                        _displayPosition = Duration(milliseconds: newMillis);
                      });
                    }
                  },
                  onHorizontalDragEnd: (details) async {
                    final width = MediaQuery.of(context).size.width - 16;
                    final int totalBars = widget.waveform.length;
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
                    final newMillis =
                        (currentPercent * _duration.inMilliseconds).toInt();
                    setState(() {
                      isDraggingWaveform = false;
                      waveformDragOffset = 0.0;
                    });
                    if (newMillis >= 0 &&
                        newMillis <= _duration.inMilliseconds) {
                      await _audioPlayer.seek(
                        Duration(milliseconds: newMillis),
                      );
                    }
                    if (_position < _duration) {
                      if (wasPlaying) await _audioPlayer.resume();
                    } else {
                      await _audioPlayer.seek(Duration.zero);
                      setState(() {
                        _position = Duration.zero;
                        _displayPosition = Duration.zero;
                      });
                      if (wasPlaying) await _audioPlayer.resume();
                    }
                  },
                  child: SizedBox(
                    height: 240,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final int totalSeconds = _duration.inSeconds;
                        final int totalDataPoints = totalSeconds * 20;
                        final int barCount = (totalDataPoints / 2)
                            .round()
                            .clamp(50, 200);
                        final cursorIndex =
                            _calculateCursorIndex(barCount * 2) ?? 0;
                        final markIndices = _calculateMarkIndices(barCount * 2);
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
                                duration: _duration,
                                position: _position,
                                waveform: widget.waveform,
                              ),
                              size: Size(width, 240),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

            // 时间轴 - 只在显示声纹时显示
            if (!_showSubtitle)
              SizedBox(
                height: 48,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final int totalSeconds = _duration.inSeconds;
                    final int totalDataPoints = totalSeconds * 20;
                    final int barCount = (totalDataPoints / 2).round().clamp(
                      50,
                      200,
                    );
                    final cursorIndex =
                        _calculateCursorIndex(barCount * 2) ?? 0;
                    final markIndices = _calculateMarkIndices(barCount * 2);
                    return TimeRulerPainter(
                      duration: _duration,
                      barCount: barCount * 2,
                      cursorIndex: cursorIndex,
                      markIndices: markIndices,
                      dragOffset: waveformDragOffset,
                      isLight: true,
                      formatFunction: _formatTimeAxis,
                      waveform: widget.waveform,
                    ).buildWidget();
                  },
                ),
              ),
            const SizedBox(height: 16),
            // Spacer 占位
            const Spacer(),
            // 切换按钮固定在底部控制区正上方
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSubtitle = !_showSubtitle;
                    });
                  },
                  child: Text(
                    _showSubtitle ? '显示声纹' : '显示文本',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 4),
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
                  },
                ),
              ),
            ),
            // 起止时间显示区域（在进度条下方）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '00:00',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _formatTimeAxis(_position),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _formatTimeAxis(_duration),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 底部控制区
            Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 32.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左侧按钮组
                  IconButton(
                    onPressed: _addMark,
                    icon: Icon(Icons.flag, color: Colors.black, size: 28),
                  ),
                  SizedBox(width: 24),
                  _QuickSeekButton(
                    forward: false,
                    seconds: 5,
                    onTap: () {
                      final newPosition =
                          _position - const Duration(seconds: 5);
                      if (newPosition.inMilliseconds >= 0) {
                        _audioPlayer.seek(newPosition);
                        _position = newPosition;
                      } else {
                        _audioPlayer.seek(Duration.zero);
                        _position = Duration.zero;
                      }
                    },
                  ),
                  // 左侧占位
                  Expanded(child: SizedBox()),
                  // 播放/暂停按钮（居中）
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
                  // 右侧占位
                  Expanded(child: SizedBox()),
                  // 右侧按钮组
                  _QuickSeekButton(
                    forward: true,
                    seconds: 5,
                    onTap: () {
                      final newPosition =
                          _position + const Duration(seconds: 5);
                      if (newPosition.inMilliseconds <=
                          _duration.inMilliseconds) {
                        _audioPlayer.seek(newPosition);
                        _position = newPosition;
                      } else {
                        _audioPlayer.seek(_duration);
                        _position = _duration;
                      }
                    },
                  ),
                  SizedBox(width: 24),
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

  Future<void> _restartPlayback() async {
    print('重新开始播放');
    try {
      // 在completed状态下需要重新加载音频源
      await _audioPlayer.setSource(DeviceFileSource(widget.filePath));
      await _audioPlayer.seek(Duration.zero);
      setState(() {
        _position = Duration.zero;
        _displayPosition = Duration.zero;
        waveformDragOffset = 0.0;
      });
      print('重新开始播放成功');
    } catch (e) {
      print('重新开始播放失败: $e');
    }
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
    final double barWidth = 2; // 设置为2
    final double gap = 2; // 设置为2，与barWidth一致
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
        // 超出范围的部分显示为高度为0的竖线（不显示）
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
  final List<double> waveform;
  const TimeRulerPainter({
    super.key,
    required this.duration,
    required this.barCount,
    required this.cursorIndex,
    required this.markIndices,
    required this.dragOffset,
    required this.isLight,
    required this.formatFunction,
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
      ..color = parent.isLight ? Colors.grey[400]! : Colors.grey[600]!
      ..strokeWidth = 1;

    // 检查duration是否有效
    if (parent.duration.inSeconds <= 0) {
      return; // 如果duration无效，不绘制时间轴
    }

    // 使用与波形绘制器完全相同的计算逻辑
    final double playProgress = parent.cursorIndex / parent.barCount;
    final int totalBars = parent.waveform.length; // 使用实际的波形数据长度
    final int currentBar = (playProgress * totalBars).round();
    final int half = parent.barCount ~/ 2;

    // 使用与波形绘制器相同的间距计算方式
    final double barWidth = 2;
    final double gap = 2;
    final double spacing = barWidth + gap; // 4像素间距

    // 计算当前播放位置对应的秒数
    final int currentSecond = (playProgress * parent.duration.inSeconds)
        .round();

    // 绘制时间刻度：只在整秒位置显示时间标签
    for (int i = -10; i <= 10; i++) {
      int second = currentSecond + i;
      if (second < 0 || second > parent.duration.inSeconds) continue;

      // 计算整秒对应的数据索引位置
      final double secondProgress = second / parent.duration.inSeconds;
      final int dataIdx = (secondProgress * totalBars).round();
      final int relativePos = dataIdx - currentBar;

      double x = centerX + relativePos * spacing + parent.dragOffset;

      // 主刻度
      canvas.drawLine(Offset(x, 0), Offset(x, 16), tickPaint);

      // 时间数字（每1秒显示一次，格式为00:01）
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
  final Duration duration;
  final Duration position;
  final List<double> waveform;
  MarksPainter({
    required this.markIndices,
    required this.barCount,
    required this.sortedMarkIndices,
    required this.dragOffset,
    required this.isLight,
    required this.duration,
    required this.position,
    required this.waveform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = 2;
    final double gap = 2;
    final double centerX = size.width / 2;

    // 检查duration是否有效
    if (duration.inSeconds <= 0) {
      return; // 如果duration无效，不绘制标记点
    }

    // 使用与波形绘制器完全相同的计算逻辑
    final double playProgress =
        position.inMilliseconds / duration.inMilliseconds;
    final int totalBars = waveform.length; // 使用实际的波形数据长度
    final int currentBar = (playProgress * totalBars).round();
    final int half = barCount ~/ 2;

    final Paint markPaint = Paint()
      ..color = isLight ? Colors.grey[300]! : Colors.grey[700]!
      ..strokeWidth = 2;

    // 按照时间顺序排序标记点
    final sortedMarks = List<Duration>.from(
      markIndices.map((index) {
        final progress = index / barCount;
        return Duration(
          milliseconds: (progress * duration.inMilliseconds).round(),
        );
      }),
    )..sort();

    // 创建时间到序号的映射
    final Map<Duration, int> timeToOrder = {};
    for (int i = 0; i < sortedMarks.length; i++) {
      timeToOrder[sortedMarks[i]] = i + 1;
    }

    for (int i = 0; i < markIndices.length; i++) {
      // 计算标记点的实际时间
      final progress = markIndices[i] / barCount;
      final markTime = Duration(
        milliseconds: (progress * duration.inMilliseconds).round(),
      );

      // 计算标记点在波形数据中的索引
      final markProgress = markTime.inMilliseconds / duration.inMilliseconds;
      final markDataIdx = (markProgress * totalBars).round();

      // 计算标记点相对于当前播放位置的位置（与波形绘制器完全一致）
      final int relativePos = markDataIdx - currentBar;
      double x = centerX + relativePos * (barWidth + gap) + dragOffset;

      // 检查标记点是否在可视范围内
      if (x < 0 || x > size.width) continue;

      // 获取按照时间顺序的序号
      final orderNumber = timeToOrder[markTime] ?? (i + 1);

      // 竖线
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markPaint);

      // 圆圈
      canvas.drawCircle(Offset(x, 10), 8, markPaint);

      // 数字（按照时间顺序的序号）
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '$orderNumber',
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

// 假字幕数据
final List<Map<String, dynamic>> fakeSubtitle = List.generate(
  60,
  (i) => {
    "start": (i * 5).toDouble(),
    "end": ((i + 1) * 5).toDouble(),
    "text": "第${i + 1}段字幕，时间：${i * 5}~${(i + 1) * 5}秒。这里是测试内容，内容可根据需要自行扩展。",
  },
);
final String fakeSummary =
    '这是一个很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长很长';

class SubtitleWithMarksWidget extends StatefulWidget {
  final List<Map<String, dynamic>> subtitles;
  final Duration position;
  final List<Duration> marks;
  final Duration audioDuration;
  const SubtitleWithMarksWidget({
    required this.subtitles,
    required this.position,
    required this.marks,
    required this.audioDuration,
    super.key,
  });
  @override
  State<SubtitleWithMarksWidget> createState() =>
      _SubtitleWithMarksWidgetState();
}

class _SubtitleWithMarksWidgetState extends State<SubtitleWithMarksWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  final GlobalKey _listViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _itemKeys.clear();
    for (int i = 0; i < widget.subtitles.length; i++) {
      _itemKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(covariant SubtitleWithMarksWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitles.length != widget.subtitles.length) {
      _itemKeys.clear();
      for (int i = 0; i < widget.subtitles.length; i++) {
        _itemKeys.add(GlobalKey());
      }
    }
  }

  double _getItemOffset(int idx) {
    final RenderBox? listBox =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? itemBox =
        _itemKeys[idx].currentContext?.findRenderObject() as RenderBox?;
    if (listBox != null && itemBox != null) {
      final listOffset = listBox.localToGlobal(Offset.zero);
      final itemOffset = itemBox.localToGlobal(Offset.zero);
      return (itemOffset.dy - listOffset.dy).clamp(0.0, listBox.size.height);
    }
    return 0.0;
  }

  int? _currentIndex() {
    final t = widget.position.inMilliseconds / 1000.0;
    for (int i = 0; i < widget.subtitles.length; i++) {
      final s = widget.subtitles[i];
      if (t >= s['start'] && t < s['end']) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex() ?? 0;
    final total = widget.subtitles.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
        // 调试日志：打印约束信息
        print("=== SubtitleWithMarksWidget 调试信息 ===");
        print("约束信息: maxHeight=${constraints.maxHeight}, maxWidth=${constraints.maxWidth}");
        print("约束信息: minHeight=${constraints.minHeight}, minWidth=${constraints.minWidth}");
        print("当前索引: $currentIdx, 总字幕数: $total");
        
        // 当前高亮字幕块的像素位置
        final double currentOffset = _getItemOffset(currentIdx);
        print("当前字幕偏移: $currentOffset");
        
        // 标记点像素位置
        List<double> markOffsets = widget.marks.map((mark) {
          int markSubtitleIndex = 0;
          for (int i = 0; i < widget.subtitles.length; i++) {
            final s = widget.subtitles[i];
            final markSec = mark.inMilliseconds / 1000.0;
            if (markSec >= s["start"] && markSec < s["end"]) {
              markSubtitleIndex = i;
              break;
            }
          }
          return _getItemOffset(markSubtitleIndex);
        }).toList();
        print("标记点偏移: $markOffsets");
        print("Container高度: ${constraints.maxHeight}");
          children: [
            // 字幕滚动区
            Expanded(
              child: ListView.builder(
                key: _listViewKey,
                controller: _scrollController,
                itemCount: widget.subtitles.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, i) {
                  final s = widget.subtitles[i];
                  final isActive = i == currentIdx;
                  return Container(
                    key: _itemKeys[i],
                    color: isActive
                        ? Colors.blue.withOpacity(0.08)
                        : Colors.white,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Text(
                      s['text'],
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        color: isActive ? Colors.blue[900] : Colors.black87,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            // 进度条
            Container(
              width: 28,
              height: listViewHeight,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // 竖线
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 当前节点
                  Positioned(
                    top: currentOffset + 10, // +padding
                    left: 5,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 标记点
                  ...markOffsets.map(
                    (offset) => Positioned(
                      top: offset + 10, // +padding
                      left: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
