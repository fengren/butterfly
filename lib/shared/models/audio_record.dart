import '../models/unified_history.dart';
import '../models/content_type.dart';

/// 录音记录模型
class AudioRecord extends UnifiedHistory {
  final String filePath;
  final int duration; // 录音时长（秒）
  final int fileSize; // 文件大小（字节）
  final String? transcription; // 转录文本
  
  AudioRecord({
    required String id,
    required String title,
    required DateTime timestamp,
    required this.filePath,
    required this.duration,
    required this.fileSize,
    this.transcription,
    String? description,
    Map<String, dynamic>? metadata,
  }) : super(
          id: id,
          title: title,
          description: description ?? '录音时长: ${_formatDuration(duration)}',
          timestamp: timestamp,
          contentType: ContentType.audio,
          filePath: filePath,
          metadata: metadata ?? {},
        );
  
  /// 从 JSON 创建 AudioRecord
  factory AudioRecord.fromJson(Map<String, dynamic> json) {
    return AudioRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      filePath: json['filePath'] as String,
      duration: json['duration'] as int,
      fileSize: json['fileSize'] as int,
      transcription: json['transcription'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  /// 转换为 JSON
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'filePath': filePath,
      'duration': duration,
      'fileSize': fileSize,
      'transcription': transcription,
    });
    return json;
  }
  
  /// 复制并修改属性
  @override
  AudioRecord copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? timestamp,
    ContentType? contentType,
    String? filePath,
    String? thumbnailPath,
    Map<String, dynamic>? metadata,
    // AudioRecord 特有属性
    int? duration,
    int? fileSize,
    String? transcription,
  }) {
    return AudioRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      transcription: transcription ?? this.transcription,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 格式化录音时长
  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  /// 获取格式化的文件大小
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  /// 获取格式化的录音时长
  String get formattedDuration => _formatDuration(duration);
}