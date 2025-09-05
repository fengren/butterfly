/// 内容类型枚举
enum ContentType {
  /// 录音内容
  audio('audio'),
  /// 分享内容
  share('share');
  
  const ContentType(this.value);
  
  final String value;
  
  /// 从字符串创建内容类型
  static ContentType fromString(String value) {
    switch (value) {
      case 'audio':
        return ContentType.audio;
      case 'share':
        return ContentType.share;
      default:
        throw ArgumentError('Unknown content type: $value');
    }
  }
  
  @override
  String toString() => value;
}