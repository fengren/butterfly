import 'package:flutter/material.dart';

/// 卡片主题和样式配置
class CardTheme {
  // 卡片基础样式
  static const double cardRadius = 20.0;
  static const double cardElevation = 0.0; // 使用自定义阴影
  // 根据用户反馈：进一步减少卡片间距，增加宽度
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );
  // 根据用户反馈：略微增加卡片高度
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 20,
  );
  
  // 图标样式
  static const double iconSize = 56.0;
  static const double iconRadius = 16.0;
  
  // 文字样式
  static const TextStyle titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 14,
    height: 1.3,
  );
  
  static const TextStyle metaStyle = TextStyle(
    fontSize: 12,
    height: 1.2,
  );
  
  // 自定义阴影
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 40,
      offset: const Offset(0, 8),
    ),
  ];
  
  // 悬停阴影
  static List<BoxShadow> get cardHoverShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 60,
      offset: const Offset(0, 16),
    ),
  ];
}

/// 卡片颜色系统
class CardColors {
  // 录音文件渐变
  static const List<Color> audioGradient = [
    Color(0xFF667eea), // 深蓝紫
    Color(0xFF764ba2), // 紫色
  ];
  
  // 分享文件渐变
  static const List<Color> shareGradient = [
    Color(0xFF11998e), // 青绿
    Color(0xFF38ef7d), // 浅绿
  ];
  
  // 文本文件渐变
  static const List<Color> textGradient = [
    Color(0xFFf093fb), // 粉紫
    Color(0xFFf5576c), // 粉红
  ];
  
  // 图片文件渐变
  static const List<Color> imageGradient = [
    Color(0xFF4facfe), // 蓝色
    Color(0xFF00f2fe), // 青色
  ];
  
  // 视频文件渐变
  static const List<Color> videoGradient = [
    Color(0xFFfa709a), // 粉色
    Color(0xFFfee140), // 黄色
  ];
  
  // 默认渐变
  static const List<Color> defaultGradient = [
    Color(0xFF74b9ff), // 蓝色
    Color(0xFF0984e3), // 深蓝
  ];
  
  // 状态颜色
  static const Color unreadIndicator = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF00b894);
  static const Color warningColor = Color(0xFFfdcb6e);
  static const Color errorColor = Color(0xFFe17055);
  
  // 标签颜色
  static const Map<String, Color> tagColors = {
    '重要': Color(0xFFFF6B6B),
    '工作': Color(0xFF4ECDC4),
    '个人': Color(0xFFFFE66D),
    '紧急': Color(0xFFFF8A80),
    '学习': Color(0xFF81C784),
    '娱乐': Color(0xFFFFB74D),
    '默认': Color(0xFF95A5A6),
  };
  
  /// 根据内容类型获取渐变色
  static List<Color> getGradientByType(String type) {
    switch (type.toLowerCase()) {
      case 'audio':
      case '录音':
        return audioGradient;
      case 'share':
      case '分享':
        return shareGradient;
      case 'text':
      case '文本':
        return textGradient;
      case 'image':
      case '图片':
        return imageGradient;
      case 'video':
      case '视频':
        return videoGradient;
      default:
        return defaultGradient;
    }
  }
  
  /// 根据标签获取颜色
  static Color getTagColor(String tag) {
    return tagColors[tag] ?? tagColors['默认']!;
  }
}

/// 动画配置
class CardAnimations {
  static const Duration enterDuration = Duration(milliseconds: 600);
  static const Duration hoverDuration = Duration(milliseconds: 200);
  static const Duration tapDuration = Duration(milliseconds: 150);
  
  static const Curve enterCurve = Curves.elasticOut;
  static const Curve hoverCurve = Curves.easeInOut;
  static const Curve tapCurve = Curves.easeInOut;
  
  // 交错动画延迟
  static int getStaggerDelay(int index) {
    return (index * 100).clamp(0, 500);
  }
}