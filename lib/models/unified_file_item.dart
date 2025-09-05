/// 统一文件项数据模型
/// 用于统一展示录音文件和分享文件

enum FileType {
  audio,    // 录音文件
  share,    // 分享文件
}

class UnifiedFileItem {
  final String id;
  final String title;
  final DateTime createdAt;
  final FileType type;
  final String absolutePath;
  final Map<String, dynamic> metadata;
  
  const UnifiedFileItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.type,
    required this.absolutePath,
    required this.metadata,
  });
  
  // 录音文件特有属性
  String? get audioPath => type == FileType.audio ? metadata['audioPath'] : null;
  String? get wavePath => type == FileType.audio ? metadata['wavePath'] : null;
  String? get marksPath => type == FileType.audio ? metadata['marksPath'] : null;
  String? get duration => type == FileType.audio ? metadata['duration'] : null;
  bool? get played => type == FileType.audio ? metadata['played'] : null;
  String? get tag => type == FileType.audio ? metadata['tag'] : null;
  
  // 分享文件特有属性
  int? get messageCount => type == FileType.share ? metadata['messageCount'] : null;
  int? get imageCount => type == FileType.share ? metadata['imageCount'] : null;
  String? get sourceApp => type == FileType.share ? metadata['sourceApp'] : null;
  
  /// 从录音文件元数据创建UnifiedFileItem
  factory UnifiedFileItem.fromAudioMeta(
    Map<String, dynamic> meta, 
    String documentsPath,
  ) {
    return UnifiedFileItem(
      id: meta['id'] ?? '',
      title: meta['displayName'] ?? meta['audioPath']?.split('/').first ?? 'Unknown',
      createdAt: DateTime.tryParse(meta['created'] ?? '') ?? DateTime.now(),
      type: FileType.audio,
      absolutePath: '$documentsPath/${meta['audioPath'] ?? ''}',
      metadata: Map<String, dynamic>.from(meta),
    );
  }
  
  /// 从分享历史创建UnifiedFileItem
  factory UnifiedFileItem.fromShareHistory(dynamic history) {
    return UnifiedFileItem(
      id: history.id ?? '',
      title: history.title ?? 'Shared Content',
      createdAt: history.createdAt ?? DateTime.now(),
      type: FileType.share,
      absolutePath: history.directoryPath ?? '',
      metadata: {
        'messageCount': history.messageCount ?? 0,
        'imageCount': history.imageCount ?? 0,
        'sourceApp': history.sourceApp ?? 'Unknown',
      },
    );
  }
  
  /// 获取文件大小（仅录音文件）
  int? get fileSize {
    if (type == FileType.audio && metadata.containsKey('fileSize')) {
      return metadata['fileSize'] as int?;
    }
    return null;
  }
  
  /// 获取显示用的副标题
  String getSubtitle() {
    switch (type) {
      case FileType.audio:
        final duration = this.duration;
        final tag = this.tag;
        if (duration != null && tag != null && tag.isNotEmpty) {
          return '$duration • $tag';
        } else if (duration != null) {
          return duration;
        } else if (tag != null && tag.isNotEmpty) {
          return tag;
        }
        return 'Audio File';
        
      case FileType.share:
        final msgCount = messageCount ?? 0;
        final imgCount = imageCount ?? 0;
        final source = sourceApp ?? 'Unknown';
        
        List<String> parts = [];
        if (msgCount > 0) parts.add('$msgCount messages');
        if (imgCount > 0) parts.add('$imgCount images');
        parts.add('from $source');
        
        return parts.join(' • ');
    }
  }
  
  /// 获取格式化的创建时间
  String getFormattedDate() {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inDays == 0) {
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedFileItem &&
        other.id == id &&
        other.type == type;
  }
  
  @override
  int get hashCode => Object.hash(id, type);
  
  @override
  String toString() {
    return 'UnifiedFileItem(id: $id, title: $title, type: $type, createdAt: $createdAt)';
  }
}