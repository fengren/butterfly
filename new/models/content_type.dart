/// 内容类型枚举
/// 用于区分不同类型的历史记录
enum ContentType {
  /// 分享内容（文本、图片等）
  share('share'),
  
  /// 音频录音内容
  audio('audio');
  
  const ContentType(this.value);
  
  final String value;
  
  /// 从字符串值创建 ContentType
  static ContentType fromString(String value) {
    switch (value) {
      case 'share':
        return ContentType.share;
      case 'audio':
        return ContentType.audio;
      default:
        throw ArgumentError('Unknown ContentType: $value');
    }
  }
  
  /// 转换为字符串
  @override
  String toString() => value;
}