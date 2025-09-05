import 'content_type.dart';

/// 统一历史记录模型
/// 用于统一管理分享内容和音频录音的历史记录
class UnifiedHistory {
  final String id;
  final ContentType contentType;
  final DateTime timestamp;
  final String title;
  final String? description;
  final Map<String, dynamic> metadata;
  final String? filePath;
  final String? thumbnailPath;
  
  const UnifiedHistory({
    required this.id,
    required this.contentType,
    required this.timestamp,
    required this.title,
    this.description,
    this.metadata = const {},
    this.filePath,
    this.thumbnailPath,
  });
  
  /// 从 JSON 创建实例
  factory UnifiedHistory.fromJson(Map<String, dynamic> json) {
    return UnifiedHistory(
      id: json['id'] as String,
      contentType: ContentType.fromString(json['contentType'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      filePath: json['filePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
  
  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentType': contentType.value,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'description': description,
      'metadata': metadata,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
    };
  }
  
  /// 创建副本
  UnifiedHistory copyWith({
    String? id,
    ContentType? contentType,
    DateTime? timestamp,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
    String? filePath,
    String? thumbnailPath,
  }) {
    return UnifiedHistory(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedHistory && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'UnifiedHistory(id: $id, contentType: $contentType, title: $title)';
  }
}