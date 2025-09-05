import 'unified_history.dart';
import 'content_type.dart';

/// 录音内容记录模型
/// 继承自 UnifiedHistory，添加录音特有的属性
class AudioContent extends UnifiedHistory {
  /// 音频文件路径
  final String audioFilePath;
  
  /// 波形文件路径
  final String? waveFilePath;
  
  /// 标记文件路径
  final String? marksFilePath;
  
  /// 音频时长
  final Duration duration;
  
  /// 文件大小（字节）
  final int fileSize;
  
  /// 标签列表
  final List<String> tags;
  
  /// 音频质量
  final String? quality;
  
  /// 显示名称（用于兼容现有逻辑）
  final String? displayName;
  
  /// 波形数据
  final List<double>? waveform;
  
  const AudioContent({
    required super.id,
    required super.timestamp,
    required super.title,
    super.description,
    super.metadata = const {},
    required this.audioFilePath,
    this.waveFilePath,
    this.marksFilePath,
    required this.duration,
    required this.fileSize,
    this.tags = const [],
    this.quality,
    this.displayName,
    this.waveform,
  }) : super(
    contentType: ContentType.audio, 
    filePath: audioFilePath
  );
  
  /// 从现有的元数据和文件信息创建实例
  factory AudioContent.fromMetadata({
    required String id,
    required String audioFilePath,
    required Map<String, dynamic> metadata,
    required DateTime timestamp,
    required Duration duration,
    required int fileSize,
  }) {
    final title = metadata['displayName'] as String? ?? 
                 metadata['title'] as String? ?? 
                 _extractFileNameFromPath(audioFilePath);
    
    final tags = (metadata['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final quality = metadata['quality'] as String?;
    final displayName = metadata['displayName'] as String?;
    
    return AudioContent(
      id: id,
      timestamp: timestamp,
      title: title,
      description: '录音时长 ${_formatDuration(duration)}',
      audioFilePath: audioFilePath,
      waveFilePath: _getWaveFilePath(audioFilePath),
      marksFilePath: _getMarksFilePath(audioFilePath),
      duration: duration,
      fileSize: fileSize,
      tags: tags,
      quality: quality,
      displayName: displayName,
      waveform: metadata['waveform'] != null ? List<double>.from(metadata['waveform']) : null,
      metadata: {
        ...metadata,
        'duration': duration.inSeconds,
        'fileSize': fileSize,
        'audioFilePath': audioFilePath,
      },
    );
  }
  
  /// 从 JSON 创建实例
  factory AudioContent.fromJson(Map<String, dynamic> json) {
    return AudioContent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      audioFilePath: json['audioFilePath'] as String,
      waveFilePath: json['waveFilePath'] as String?,
      marksFilePath: json['marksFilePath'] as String?,
      duration: Duration(seconds: json['duration'] as int),
      fileSize: json['fileSize'] as int,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      quality: json['quality'] as String?,
      displayName: json['displayName'] as String?,
      waveform: (json['waveform'] as List<dynamic>?)?.cast<double>(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
  
  /// 转换为 JSON
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'audioFilePath': audioFilePath,
      'waveFilePath': waveFilePath,
      'marksFilePath': marksFilePath,
      'duration': duration.inSeconds,
      'fileSize': fileSize,
      'tags': tags,
      'quality': quality,
      'displayName': displayName,
      'waveform': waveform,
    });
    return json;
  }
  
  /// 创建副本（重写父类方法）
  @override
  AudioContent copyWith({
    String? id,
    ContentType? contentType,
    DateTime? timestamp,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
    String? filePath,
    String? thumbnailPath,
  }) {
    return AudioContent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      audioFilePath: filePath ?? this.audioFilePath,
      waveFilePath: this.waveFilePath,
      marksFilePath: this.marksFilePath,
      duration: this.duration,
      fileSize: this.fileSize,
      tags: this.tags,
      quality: this.quality,
      displayName: this.displayName,
      waveform: this.waveform,
    );
  }
  
  /// 创建音频内容的完整副本
  AudioContent copyWithAudio({
    String? id,
    DateTime? timestamp,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
    String? audioFilePath,
    String? waveFilePath,
    String? marksFilePath,
    Duration? duration,
    int? fileSize,
    List<String>? tags,
    String? quality,
    String? displayName,
    List<double>? waveform,
  }) {
    return AudioContent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      waveFilePath: waveFilePath ?? this.waveFilePath,
      marksFilePath: marksFilePath ?? this.marksFilePath,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
      quality: quality ?? this.quality,
      displayName: displayName ?? this.displayName,
      waveform: waveform ?? this.waveform,
    );
  }
  
  /// 格式化文件大小
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  /// 格式化时长
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 获取主要标签（第一个标签或默认值）
  String get primaryTag {
    return tags.isNotEmpty ? tags.first : '录音';
  }
  
  /// 检查是否有波形文件
  bool get hasWaveFile {
    return waveFilePath != null;
  }
  
  /// 检查是否有标记文件
  bool get hasMarksFile {
    return marksFilePath != null;
  }
  
  // 私有辅助方法
  static String _extractFileNameFromPath(String filePath) {
    final fileName = filePath.split('/').last;
    final nameWithoutExtension = fileName.split('.').first;
    return nameWithoutExtension;
  }
  
  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
  
  static String? _getWaveFilePath(String audioFilePath) {
    final basePath = audioFilePath.replaceAll('.wav', '');
    return '${basePath}_wave.json';
  }
  
  static String? _getMarksFilePath(String audioFilePath) {
    final basePath = audioFilePath.replaceAll('.wav', '');
    return '${basePath}_marks.json';
  }
}