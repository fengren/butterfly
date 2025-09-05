
/// 分享内容数据模型
class SharedContent {
  final String id;
  final String? text;
  final List<SharedImage> images;
  final DateTime receivedAt;
  final String sourceApp;
  final String localDirectory;

  const SharedContent({
    required this.id,
    this.text,
    required this.images,
    required this.receivedAt,
    required this.sourceApp,
    required this.localDirectory,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'images': images.map((img) => img.toJson()).toList(),
      'receivedAt': receivedAt.toIso8601String(),
      'sourceApp': sourceApp,
      'localDirectory': localDirectory,
    };
  }

  factory SharedContent.fromJson(Map<String, dynamic> json) {
    return SharedContent(
      id: json['id'] as String? ?? '',
      text: json['text'] as String?,
      images: (json['images'] as List<dynamic>? ?? [])
          .map((img) => SharedImage.fromJson(img as Map<String, dynamic>))
          .toList(),
      receivedAt: DateTime.parse(json['receivedAt'] as String? ?? DateTime.now().toIso8601String()),
      sourceApp: json['sourceApp'] as String? ?? '',
      localDirectory: json['localDirectory'] as String? ?? '',
    );
  }

  SharedContent copyWith({
    String? id,
    String? text,
    List<SharedImage>? images,
    DateTime? receivedAt,
    String? sourceApp,
    String? localDirectory,
  }) {
    return SharedContent(
      id: id ?? this.id,
      text: text ?? this.text,
      images: images ?? this.images,
      receivedAt: receivedAt ?? this.receivedAt,
      sourceApp: sourceApp ?? this.sourceApp,
      localDirectory: localDirectory ?? this.localDirectory,
    );
  }
}

/// 分享图片数据模型
class SharedImage {
  final String uri;
  final String localPath;
  final String? fileName;
  final int? fileSize;

  const SharedImage({
    required this.uri,
    required this.localPath,
    this.fileName,
    this.fileSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'localPath': localPath,
      'fileName': fileName,
      'fileSize': fileSize,
    };
  }

  factory SharedImage.fromJson(Map<String, dynamic> json) {
    return SharedImage(
      uri: json['uri'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }

  SharedImage copyWith({
    String? uri,
    String? localPath,
    String? fileName,
    int? fileSize,
  }) {
    return SharedImage(
      uri: uri ?? this.uri,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}

/// 分享历史记录模型
class ShareHistory {
  final String id;
  final String title;
  final DateTime createdAt;
  final String directoryPath;
  final int messageCount;
  final int imageCount;
  final String sourceApp;
  
  const ShareHistory({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.directoryPath,
    required this.messageCount,
    required this.imageCount,
    required this.sourceApp,
  });
  
  /// 格式化日期显示
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
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
      return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    }
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'directory_path': directoryPath,
      'message_count': messageCount,
      'image_count': imageCount,
      'source_app': sourceApp,
    };
  }
  
  /// 从JSON创建实例
  factory ShareHistory.fromJson(Map<String, dynamic> json) {
    return ShareHistory(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '未知标题',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch
      ),
      directoryPath: json['directory_path'] as String? ?? '',
      messageCount: json['message_count'] as int? ?? 0,
      imageCount: json['image_count'] as int? ?? 0,
      sourceApp: json['source_app'] as String? ?? '未知应用',
    );
  }

  ShareHistory copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? directoryPath,
    int? messageCount,
    int? imageCount,
    String? sourceApp,
  }) {
    return ShareHistory(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      directoryPath: directoryPath ?? this.directoryPath,
      messageCount: messageCount ?? this.messageCount,
      imageCount: imageCount ?? this.imageCount,
      sourceApp: sourceApp ?? this.sourceApp,
    );
  }
}