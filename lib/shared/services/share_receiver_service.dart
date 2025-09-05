import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';

import '../models/shared_content.dart';

/// 分享接收服务 - 基于 cross_lib 的简洁实现
class ShareReceiverService {
  static const String _tag = 'ShareReceiverService';
  static const MethodChannel _methodChannel = MethodChannel('com.example.butterfly/share_intent');
  
  final StreamController<SharedContent> _sharedContentController = 
      StreamController<SharedContent>.broadcast();
  
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  
  final Uuid _uuid = const Uuid();

  Stream<SharedContent> get sharedContentStream => _sharedContentController.stream;

  void initialize() {
    debugPrint('$_tag: ========== 开始初始化 ShareReceiverService ==========');
    debugPrint('$_tag: 方法通道名称: ${_methodChannel.name}');
    
    // 设置原生方法处理器
    _methodChannel.setMethodCallHandler(_handleNativeMethodCall);
    debugPrint('$_tag: 已设置方法通道处理器');
    
    // 注释掉receive_sharing_intent监听，避免重复处理
    // _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
    //   _handleSharedMedia,
    //   onError: (error) {
    //     debugPrint('$_tag: Media stream error: $error');
    //   },
    // );
    debugPrint('$_tag: 使用原生方法通道处理分享，避免重复监听');
  }

  /// 处理原生方法调用
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    debugPrint('$_tag: ========== 接收到原生方法调用 ==========');
    debugPrint('$_tag: 方法名称: ${call.method}');
    debugPrint('$_tag: 参数类型: ${call.arguments.runtimeType}');
    debugPrint('$_tag: 参数内容: ${call.arguments}');
    
    try {
      switch (call.method) {
        case 'onShareReceived':
          final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
          await _handleNativeShareData(data);
          break;
        default:
          debugPrint('$_tag: Unknown method: ${call.method}');
      }
    } catch (e) {
      debugPrint('$_tag: Error handling native method call: $e');
    }
  }

  /// 处理来自 MainActivity 的分享数据
  Future<void> _handleNativeShareData(Map<String, dynamic> data) async {
    try {
      debugPrint('$_tag: ========== 开始处理原生分享数据 ==========');
      debugPrint('$_tag: 原始数据: $data');
      
      final String? text = data['text'] as String?;
      final List<dynamic>? files = data['files'] as List<dynamic>?;
      final String? type = data['type'] as String?;
      final String? sourceApp = data['sourceApp'] as String?;
      
      debugPrint('$_tag: 提取的文本: $text');
      debugPrint('$_tag: 提取的文件: $files');
      debugPrint('$_tag: 提取的类型: $type');
      debugPrint('$_tag: 提取的应用来源: $sourceApp');
      
      final SharedContent content = await _createSharedContent(
        text: text,
        imagePaths: files?.cast<String>(),
        sourceAppParam: sourceApp,
      );
      
      debugPrint('$_tag: 创建的SharedContent: ${content.toString()}');
      _sharedContentController.add(content);
      debugPrint('$_tag: ========== 原生分享数据处理完成 ==========');
    } catch (e) {
      debugPrint('$_tag: Error processing native share data: $e');
    }
  }

  /// 处理媒体分享
  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedFiles) async {
    try {
      if (sharedFiles.isEmpty) return;
      
      final SharedContent content = await _createSharedContentFromMedia(sharedFiles, sourceAppParam: 'unknown');
      _sharedContentController.add(content);
    } catch (e) {
      debugPrint('$_tag: Error handling shared media: $e');
    }
  }

  /// 从 SharedMediaFile 创建 SharedContent
  Future<SharedContent> _createSharedContentFromMedia(List<SharedMediaFile> sharedFiles, {String? sourceAppParam}) async {
    final String localDir = await _createLocalDirectory(DateTime.now());
    final List<SharedImage> images = [];
    String? text;

    for (final file in sharedFiles) {
       // 检查文本内容 - 优先使用 message 字段
       if (file.message != null && file.message!.isNotEmpty) {
         text = file.message;
       } else if (file.type == SharedMediaType.text) {
         text = file.path;
       }
       
       // 处理图片文件
       if (file.type == SharedMediaType.image && file.path != null) {
        final String localPath = await _copyFileToLocal(file.path!, localDir);
        images.add(SharedImage(
          uri: file.path!,
          localPath: localPath,
        ));
       }
     }

     // 提取相对路径用于localDirectory字段
     final String relativePath = path.basename(localDir);
     debugPrint('$_tag: 从媒体创建SharedContent - 完整路径: $localDir, 相对路径: $relativePath');

     return SharedContent(
       id: _uuid.v4(),
       text: text,
       images: images,
       receivedAt: DateTime.now(),
       sourceApp: _detectSourceApp(sourceAppParam ?? 'unknown'),
       localDirectory: relativePath,  // 使用相对路径而不是完整路径
     );
  }

  /// 创建 SharedContent
  Future<SharedContent> _createSharedContent({
    String? text,
    List<String>? imagePaths,
    String? sourceAppParam,
  }) async {
    final String localDir = await _createLocalDirectory(DateTime.now());
    final List<SharedImage> images = [];

    if (imagePaths != null) {
      for (final imagePath in imagePaths) {
        final String localPath = await _copyFileToLocal(imagePath, localDir);
        images.add(SharedImage(
          uri: imagePath,
          localPath: localPath,
        ));
      }
    }

    // 提取相对路径用于localDirectory字段
    final String relativePath = path.basename(localDir);
    debugPrint('$_tag: 创建SharedContent - 完整路径: $localDir, 相对路径: $relativePath');

    return SharedContent(
       id: _uuid.v4(),
       text: text,
       images: images,
       receivedAt: DateTime.now(),
       sourceApp: _detectSourceApp(sourceAppParam ?? 'unknown'),
       localDirectory: relativePath,  // 使用相对路径而不是完整路径
     );
  }

  /// 检查初始分享内容
  Future<SharedContent?> checkInitialSharedContent() async {
    try {
      // Web 平台处理
      if (kIsWeb) {
        debugPrint('$_tag: Web platform, no initial shared content');
        return null;
      }

      // 获取初始媒体
      final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
      
      if (initialMedia.isNotEmpty) {
        debugPrint('$_tag: Found initial shared content: ${initialMedia.length} items');
        return await _createSharedContentFromMedia(initialMedia);
      }
      
      return null;
    } catch (e) {
      debugPrint('$_tag: Error checking initial shared content: $e');
      return null;
    }
  }

  /// 检测并转换应用来源
  String _detectSourceApp(String packageName) {
    if (packageName == 'unknown' || packageName.isEmpty) {
      return 'Unknown';
    }
    
    // 包名到应用名的映射
    const Map<String, String> packageToAppName = {
      'com.tencent.mm': '微信',
      'com.tencent.mobileqq': 'QQ',
      'com.sina.weibo': '微博',
      'com.android.chrome': 'Chrome',
      'com.UCMobile': 'UC浏览器',
      'com.tencent.mtt': 'QQ浏览器',
      'com.ss.android.ugc.aweme': '抖音',
      'com.zhihu.android': '知乎',
      'com.taobao.taobao': '淘宝',
      'com.tmall.wireless': '天猫',
      'com.jingdong.app.mall': '京东',
    };
    
    return packageToAppName[packageName] ?? packageName;
  }
  
  /// 创建本地目录
  Future<String> _createLocalDirectory(DateTime timestamp) async {
    final String formattedDate = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
    
    // 使用应用的私有目录而不是/tmp
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String dirPath = path.join(appDir.path, 'shared_content', formattedDate);
    
    debugPrint('$_tag: 创建本地目录: $dirPath');
    final Directory dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('$_tag: 目录创建成功: $dirPath');
    }
    
    return dirPath;
  }

  /// 复制文件到本地
  Future<String> _copyFileToLocal(String sourcePath, String localDir) async {
    debugPrint('$_tag: 开始复制文件: $sourcePath -> $localDir');
    final File sourceFile = File(sourcePath);
    final String fileName = path.basename(sourcePath);
    final String localPath = path.join(localDir, fileName);
    
    await sourceFile.copy(localPath);
    debugPrint('$_tag: 文件复制成功: $localPath');
    return localPath;
  }

  /// 处理错误
  void _handleError(dynamic error) {
    debugPrint('$_tag: Stream error: $error');
  }

  /// 释放资源
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _sharedContentController.close();
    debugPrint('$_tag: Service disposed');
  }
}