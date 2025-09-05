import 'unified_history.dart';
import 'content_type.dart';
import 'shared_content.dart';

/// 分享内容记录模型
/// 继承自 UnifiedHistory，添加分享特有的属性
class ShareContent extends UnifiedHistory {
  /// 消息数量
  final int messageCount;
  
  /// 图片数量
  final int imageCount;
  
  /// 来源应用
  final String sourceApp;
  
  /// 目录路径
  final String directoryPath;
  
  /// 原始分享数据
  final SharedContent? originalContent;
  
  const ShareContent({
    required super.id,
    required super.timestamp,
    required super.title,
    super.description,
    super.metadata = const {},
    super.filePath,
    super.thumbnailPath,
    required this.messageCount,
    required this.imageCount,
    required this.sourceApp,
    required this.directoryPath,
    this.originalContent,
  }) : super(contentType: ContentType.share);
  
  /// 从现有的 ShareHistory 创建实例
  factory ShareContent.fromShareHistory(ShareHistory shareHistory) {
    return ShareContent(
      id: shareHistory.id,
      timestamp: shareHistory.createdAt,
      title: shareHistory.title,
      messageCount: shareHistory.messageCount,
      imageCount: shareHistory.imageCount,
      sourceApp: shareHistory.sourceApp,
      directoryPath: shareHistory.directoryPath,
      filePath: shareHistory.directoryPath,
    );
  }
  
  /// 从 JSON 创建实例
  factory ShareContent.fromJson(Map<String, dynamic> json) {
    return ShareContent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      filePath: json['filePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      messageCount: json['messageCount'] as int,
      imageCount: json['imageCount'] as int,
      sourceApp: json['sourceApp'] as String,
      directoryPath: json['directoryPath'] as String,
    );
  }
  
  /// 转换为 JSON
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'messageCount': messageCount,
      'imageCount': imageCount,
      'sourceApp': sourceApp,
      'directoryPath': directoryPath,
    });
    return json;
  }
  
  /// 转换为 ShareHistory（向后兼容）
  ShareHistory toShareHistory() {
    return ShareHistory(
      id: id,
      title: title,
      createdAt: timestamp,
      directoryPath: directoryPath,
      messageCount: messageCount,
      imageCount: imageCount,
      sourceApp: sourceApp,
    );
  }
  
  /// 获取内容类型描述
  String get contentTypeDescription {
    if (imageCount > 0 && messageCount > 0) {
      return '混合内容';
    } else if (imageCount > 0) {
      return '图片内容';
    } else {
      return '文本内容';
    }
  }
  
  /// 获取内容统计描述
  String get contentSummary {
    final parts = <String>[];
    if (messageCount > 0) {
      parts.add('$messageCount条消息');
    }
    if (imageCount > 0) {
      parts.add('$imageCount张图片');
    }
    return parts.join('，');
  }
  
  /// 格式化日期显示
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    }
  }
}