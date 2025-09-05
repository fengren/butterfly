
import 'dart:async';

import 'package:butterfly/shared/models/history_item.dart';
import 'package:butterfly/shared/models/history_type.dart';
import 'package:butterfly/shared/models/share_details.dart';
import 'package:butterfly/shared/models/shared_content.dart';
import 'package:butterfly/shared/models/share_content.dart';
import 'package:butterfly/shared/pages/share_editor_page.dart';
import 'package:butterfly/shared/pages/share_detail_page.dart';
import 'package:butterfly/shared/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';

// Global navigator key to allow navigation from outside the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ShareHandlerService {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();
  
  final LocalStorageService _localStorageService = LocalStorageServiceImpl();
  StreamSubscription? _intentDataStreamSubscription;

  void init() {
    print('🚀 ShareHandlerService: 开始初始化');
    print('🔧 ReceiveSharingIntent 插件版本检查');
    print('📱 初始化时间: ${DateTime.now()}');
    print('🔍 检查应用启动方式');
    
    // For sharing content coming from outside the app while it is in the memory
    print('👂 设置共享媒体流监听器');
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      print('\n🎯 ========== 媒体流事件触发 ==========');
      print('📨 [媒体流] 收到共享媒体流数据: ${value.length} 个项目');
      print('📨 [媒体流] 接收时间: ${DateTime.now()}');
      print('📨 [媒体流] 数据来源: 应用运行时分享');
      if (value.isNotEmpty) {
        print('📨 [媒体流] 开始处理媒体流数据');
        _handleSharedMedia(value);
      } else {
        print('📨 [媒体流] 接收到空的媒体流数据');
      }
      print('🎯 ========== 媒体流事件结束 ==========\n');
    }, onError: (err) {
      print("❌ [媒体流] getMediaStream error: $err");
      print("❌ [媒体流] 错误类型: ${err.runtimeType}");
      print("❌ [媒体流] 错误时间: ${DateTime.now()}");
    });
    
    print('👂 媒体流监听器设置完成');

    // For sharing content coming from outside the app while it is closed
    print('🔍 [初始检查] 开始检查初始共享媒体');
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      print('\n🎯 ========== 初始媒体检查结果 ==========');
      print('📥 [初始检查] 获取到初始共享媒体: ${value.length} 个项目');
      print('📥 [初始检查] 检查时间: ${DateTime.now()}');
      print('📥 [初始检查] 数据来源: 应用冷启动分享');
      
      if (value.isNotEmpty) {
        print('📥 [初始检查] 发现初始共享媒体，详细信息:');
        for (int i = 0; i < value.length; i++) {
          var media = value[i];
          print('📄 [初始检查] 媒体文件 $i:');
          print('   - 路径: "${media.path}"');
          print('   - 类型: ${media.type}');
          print('   - 缩略图: "${media.thumbnail}"');
          print('   - 持续时间: ${media.duration}');
          print('   - 路径长度: ${media.path?.length ?? 0}');
        }
        print('📥 [初始检查] 开始处理初始共享媒体');
        _handleSharedMedia(value);
      } else {
        print('ℹ️  [初始检查] 无初始共享媒体 - 应用正常启动');
      }
      print('🎯 ========== 初始媒体检查结束 ==========\n');
    }).catchError((error) {
      print('❌ [初始检查] getInitialMedia error: $error');
      print('❌ [初始检查] 错误类型: ${error.runtimeType}');
      print('❌ [初始检查] 错误时间: ${DateTime.now()}');
    });
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedMedia) async {
    print('\n🔥 ========== 开始处理共享媒体数据 ==========');
    print('📱 ShareHandlerService: 接收到共享媒体数据');
    print('📊 处理时间: ${DateTime.now()}');
    print('📊 共享媒体数量: ${sharedMedia.length}');
    print('📊 处理线程: ${DateTime.now().millisecondsSinceEpoch}');
    
    if (sharedMedia.isEmpty) {
      print('⚠️  共享媒体列表为空，退出处理');
      print('🔥 ========== 处理结束（空列表）==========\n');
      return;
    }
    
    // 打印所有共享媒体信息
    print('📋 共享媒体详细信息:');
    for (int i = 0; i < sharedMedia.length; i++) {
      final media = sharedMedia[i];
      print('📄 ===== 媒体文件 $i =====');
      print('   🏷️  类型: ${media.type}');
      print('   📁 路径: "${media.path}"');
      print('   🖼️  缩略图: "${media.thumbnail}"');
      print('   ⏱️  持续时间: ${media.duration}');
      print('   📏 路径长度: ${media.path?.length ?? 0}');
      print('   🔍 路径是否为空: ${media.path?.isEmpty ?? true}');
      print('   🔍 路径是否为null: ${media.path == null}');
    }
    
    // Handle the first shared item (can be extended to handle multiple items)
    final SharedMediaFile mediaFile = sharedMedia.first;
    print('🎯 处理第一个媒体文件: ${mediaFile.type}');
    
    String? text;
    String? url;
    
    // Check if it's a text/URL share
    print('🔍 检查媒体类型: ${mediaFile.type}');
    print('🔍 SharedMediaType.text = ${SharedMediaType.text}');
    print('🔍 mediaFile.path = "${mediaFile.path}"');
    print('🔍 mediaFile.thumbnail = "${mediaFile.thumbnail}"');
    
    if (mediaFile.type == SharedMediaType.text) {
      final sharedText = mediaFile.path; // For text shares, path contains the text content
      print('📝 原始共享文本: "$sharedText"');
      
      // Extract URL from text if present
      final urlRegExp = RegExp(r'(https?://[\w-./?%&=]+)');
      final urlMatch = urlRegExp.firstMatch(sharedText);
      
      url = urlMatch?.group(0);
      text = sharedText.replaceAll(url ?? '', '').trim();
      
      print('🔗 提取的URL: "$url"');
      print('📄 提取的文本: "$text"');
    } else {
      print('❌ 非文本类型媒体，类型: ${mediaFile.type}');
      // 尝试处理其他类型，可能微信发送的不是text类型
      if (mediaFile.path.isNotEmpty && !mediaFile.path.startsWith('/')) {
        print('🔄 尝试将path作为文本内容处理: "${mediaFile.path}"');
        text = mediaFile.path;
      }
    }
    
    // 创建 SharedContent 对象
    final sharedContent = SharedContent(
      id: const Uuid().v4(),
      text: text?.isNotEmpty == true ? text : (url != null ? '$text\n$url'.trim() : mediaFile.path),
      images: const [],
      receivedAt: DateTime.now(),
      sourceApp: 'Unknown',
      localDirectory: 'shared_${DateTime.now().millisecondsSinceEpoch}',
    );
    print('📋 创建 SharedContent: text="${sharedContent.text}", id=${sharedContent.id}');

    // 使用全局导航键导航到分享详情页
    final context = navigatorKey.currentContext;
    if (context != null) {
      print('🧭 导航到分享详情页面');
      
      try {
        // 先保存SharedContent到本地存储
        print('💾 保存SharedContent到本地存储');
        await _localStorageService.initialize();
        await _localStorageService.saveSharedContent(sharedContent);
        print('✅ SharedContent保存成功');
        
        // 创建 ShareContent 对象用于导航
        final shareContent = ShareContent(
          id: sharedContent.id,
          title: sharedContent.text?.isNotEmpty == true ? 
            (sharedContent.text!.length > 50 ? sharedContent.text!.substring(0, 50) + '...' : sharedContent.text!) : 
            '分享内容',
          timestamp: DateTime.now(),
          messageCount: 1,
          imageCount: 0,
          sourceApp: 'Unknown',
          directoryPath: '/shared/${sharedContent.id}',
          originalContent: sharedContent,
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShareDetailPage(history: shareContent),
          ),
        );
      } catch (e) {
        print('❌ 保存SharedContent失败: $e');
        // 即使保存失败也继续导航，但显示错误信息
        final shareContent = ShareContent(
          id: sharedContent.id,
          title: sharedContent.text?.isNotEmpty == true ? 
            (sharedContent.text!.length > 50 ? sharedContent.text!.substring(0, 50) + '...' : sharedContent.text!) : 
            '分享内容',
          timestamp: DateTime.now(),
          messageCount: 1,
          imageCount: 0,
          sourceApp: 'Unknown',
          directoryPath: '/shared/${sharedContent.id}',
          originalContent: sharedContent,
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShareDetailPage(history: shareContent),
          ),
        );
      }
    } else {
      print('❌ navigatorKey.currentContext 为 null，无法导航');
    }
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
