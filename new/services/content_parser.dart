import '../models/shared_content.dart';
import '../models/chat_message.dart';

/// 内容解析服务抽象类
abstract class ContentParser {
  /// 解析分享内容为聊天消息列表
  List<ChatMessage> parseSharedContent(SharedContent content);
  
  /// 生成历史记录标题
  String generateHistoryTitle(SharedContent content);
  
  /// 检测内容来源应用
  String detectSourceApp(String? packageName);
}

/// 内容解析服务实现类
class ContentParserImpl implements ContentParser {
  @override
  List<ChatMessage> parseSharedContent(SharedContent content) {
    final messages = <ChatMessage>[];
    
    final text = content.text?.trim();
    
    // 如果有文本内容，创建文本消息
    if (text != null && text.isNotEmpty) {
      messages.add(ChatMessage(
        id: '${content.id}_text',
        content: text,
        type: ChatMessageType.text,
        timestamp: content.receivedAt,
        isFromMe: false,
      ));
    }
    
    // 处理图片消息
    for (int i = 0; i < content.images.length; i++) {
      final image = content.images[i];
      messages.add(ChatMessage(
        id: '${content.id}_image_$i',
        content: '[图片]',
        type: ChatMessageType.image,
        timestamp: content.receivedAt,
        imageUrl: image.localPath ?? image.uri,
        isFromMe: false,
      ));
    }
    
    return messages;
  }
  
  @override
  String generateHistoryTitle(SharedContent content) {
    // 优先使用文本内容的前30个字符作为标题
    if (content.text != null && content.text!.isNotEmpty) {
      final cleanText = content.text!.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
      if (cleanText.length > 30) {
        return '${cleanText.substring(0, 30)}...';
      }
      return cleanText.isNotEmpty ? cleanText : '文本分享';
    }
    
    // 如果只有图片，根据图片数量生成标题
    if (content.images.isNotEmpty) {
      if (content.images.length == 1) {
        return '[图片]';
      }
      return '[${content.images.length}张图片]';
    }
    
    // 默认标题
    return '分享记录';
  }
  
  @override
  String detectSourceApp(String? packageName) {
    if (packageName == null) return '未知应用';
    
    // 常见应用包名映射
    const appNameMap = {
      'com.tencent.mm': '微信',
      'com.tencent.mobileqq': 'QQ',
      'com.sina.weibo': '微博',
      'com.alibaba.android.rimet': '钉钉',
      'com.tencent.wework': '企业微信',
      'com.ss.android.ugc.aweme': '抖音',
      'com.smile.gifmaker': '快手',
      'com.zhihu.android': '知乎',
      'com.jingdong.app.mall': '京东',
      'com.taobao.taobao': '淘宝',
    };
    
    return appNameMap[packageName] ?? _extractAppNameFromPackage(packageName);
  }
  
  /// 从文本中提取发送者名称（简单实现）

  /// 从包名中提取应用名称
  String _extractAppNameFromPackage(String packageName) {
    final parts = packageName.split('.');
    if (parts.length >= 2) {
      // 取最后一个部分作为应用名，首字母大写
      final appName = parts.last;
      return appName.isNotEmpty 
          ? '${appName[0].toUpperCase()}${appName.substring(1)}'
          : '未知应用';
    }
    return '未知应用';
  }
}