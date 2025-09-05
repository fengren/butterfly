import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';

import 'package:intl/intl.dart';
import '../models/shared_content.dart';

/// 分享接收服务抽象类
abstract class ShareReceiverService {
  Stream<SharedContent> get sharedContentStream;
  Future<void> initialize();
  Future<SharedContent?> getInitialSharedContent();
  Future<String> createLocalDirectory(DateTime timestamp);
  void dispose();
}

/// 分享接收服务实现类
class ShareReceiverServiceImpl implements ShareReceiverService {
  static const String _tag = 'ShareReceiverService';
  static const MethodChannel _methodChannel = MethodChannel('com.example.cross/share_intent');
  
  final StreamController<SharedContent> _sharedContentController = 
      StreamController<SharedContent>.broadcast();
  
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  
  final Uuid _uuid = const Uuid();

  @override
  Stream<SharedContent> get sharedContentStream => _sharedContentController.stream;

  @override
  Future<void> initialize() async {
    try {
      // 设置MethodChannel监听器
      _methodChannel.setMethodCallHandler(_handleMethodCall);
      
      // 监听媒体分享流（包含文本和文件）- 作为备用方案
      _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
          .listen(_handleSharedMedia, onError: _handleError);
      
      debugPrint('$_tag: Service initialized successfully');
    } catch (e) {
      debugPrint('$_tag: Failed to initialize service: $e');
      rethrow;
    }
  }

  @override
  Future<SharedContent?> getInitialSharedContent() async {
    try {
      // 获取初始媒体分享（包含文本和文件）
      final List<SharedMediaFile> sharedFiles = 
          await ReceiveSharingIntent.instance.getInitialMedia();
      
      if (sharedFiles.isNotEmpty) {
        return await _createSharedContent(
          mediaFiles: sharedFiles,
        );
      }
      

      
      return null;
    } catch (e) {
      debugPrint('$_tag: Failed to get initial shared content: $e');
      return null;
    }
  }

  @override
  Future<String> createLocalDirectory(DateTime timestamp) async {
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    final dirName = formatter.format(timestamp);
    return dirName;
  }

  /// 处理分享的媒体文件（包含文本和文件）
  void _handleSharedMedia(List<SharedMediaFile> files) async {
    try {
      if (files.isEmpty) return;
      
      final sharedContent = await _createSharedContent(
        mediaFiles: files,
      );
      
      _sharedContentController.add(sharedContent);
      debugPrint('$_tag: Received ${files.length} shared items');
    } catch (e) {
      debugPrint('$_tag: Failed to handle shared media: $e');
    }
  }

  /// 创建分享内容对象
  Future<SharedContent> _createSharedContent({
    List<SharedMediaFile>? mediaFiles,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final localDirectory = await createLocalDirectory(now);
    
    String? sharedText;
    final images = <SharedImage>[];
    
    if (mediaFiles != null) {
      for (final file in mediaFiles) {
        // 检查是否有文本内容
        if (file.message != null && file.message!.isNotEmpty) {
          sharedText = file.message;
        }
        
        if (file.type == SharedMediaType.image) {
          final fileName = _extractFileName(file.path);
          final localPath = '$localDirectory/images/$fileName';
          
          images.add(SharedImage(
            uri: file.path,
            localPath: localPath,
            fileName: fileName,
            fileSize: await _getFileSize(file.path),
          ));
        }
      }
    }
    
    return SharedContent(
      id: id,
      text: sharedText,
      images: images,
      receivedAt: now,
      sourceApp: _detectSourceApp(),
      localDirectory: localDirectory,
    );
  }

  /// 从媒体文件列表创建分享内容对象（用于流）
  SharedContent _createSharedContentFromMediaFiles(List<SharedMediaFile> mediaFiles) {
    final now = DateTime.now();
    final id = _uuid.v4();
    final localDirectory = _generateDirectoryPath(now);
    
    String? sharedText;
    final images = <SharedImage>[];
    
    for (final file in mediaFiles) {
       // 检查是否有文本内容（通过message字段）
       if (file.message != null && file.message!.isNotEmpty) {
         sharedText = file.message;
       }
       
       if (file.type == SharedMediaType.image) {
        final fileName = _extractFileName(file.path);
        
        images.add(SharedImage(
          uri: file.path,
          localPath: '', // 稍后保存到本地时设置
          fileName: fileName,
          fileSize: _getFileSizeSync(file.path),
        ));
      }
    }
    
    return SharedContent(
      id: id,
      text: sharedText,
      images: images,
      receivedAt: now,
      sourceApp: _detectSourceApp(),
      localDirectory: localDirectory,
    );
  }

  /// 生成目录路径
  String _generateDirectoryPath(DateTime timestamp) {
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    return formatter.format(timestamp);
  }

  /// 同步获取文件大小
  int? _getFileSizeSync(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (e) {
      debugPrint('$_tag: Failed to get file size for $path: $e');
    }
    return null;
  }

  /// 提取文件名
  String _extractFileName(String path) {
    final file = File(path);
    String fileName = file.uri.pathSegments.last;
    
    // 如果没有扩展名，添加默认扩展名
    if (!fileName.contains('.')) {
      fileName += '.jpg';
    }
    
    return fileName;
  }

  /// 获取文件大小
  Future<int?> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('$_tag: Failed to get file size for $path: $e');
    }
    return null;
  }

  /// 检测源应用（简单实现）
  String _detectSourceApp() {
    // 这里可以根据实际需求实现更复杂的检测逻辑
    // 目前返回通用标识
    return 'unknown';
  }

  /// 处理MethodChannel调用
  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      if (call.method == 'onShareReceived') {
        final Map<String, dynamic> shareData = Map<String, dynamic>.from(call.arguments);
        debugPrint('$_tag: Received share data from native: $shareData');
        
        await _handleNativeShareData(shareData);
      }
    } catch (e) {
      debugPrint('$_tag: Failed to handle method call: $e');
    }
  }
  
  /// 处理原生层分享数据
  Future<void> _handleNativeShareData(Map<String, dynamic> shareData) async {
    try {
      final sharedContent = await _createSharedContentFromNative(shareData);
      _sharedContentController.add(sharedContent);
      debugPrint('$_tag: Successfully processed native share data');
    } catch (e) {
      debugPrint('$_tag: Failed to process native share data: $e');
    }
  }
  
  /// 从原生数据创建分享内容对象
  Future<SharedContent> _createSharedContentFromNative(Map<String, dynamic> shareData) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final localDirectory = await createLocalDirectory(now);
    
    final sharedText = shareData['text'] as String?;
    final files = shareData['files'] as List<dynamic>?;
    final type = shareData['type'] as String? ?? 'unknown';
    
    final images = <SharedImage>[];
    
    if (files != null && files.isNotEmpty) {
      for (final fileUri in files) {
        final filePath = fileUri.toString();
        final fileName = _extractFileName(filePath);
        
        // 原生层已经处理了文件复制，直接使用提供的路径
        images.add(SharedImage(
          uri: filePath,
          localPath: filePath, // 使用原生层提供的绝对路径
          fileName: fileName,
          fileSize: await _getFileSize(filePath),
        ));
        
        debugPrint('$_tag: Added image - URI: $filePath, LocalPath: $filePath, FileName: $fileName');
      }
    }
    
    return SharedContent(
       id: id,
       receivedAt: now,
       text: sharedText,
       images: images,
       sourceApp: _detectSourceApp(),
       localDirectory: localDirectory,
     );
  }

  /// 处理错误
  void _handleError(dynamic error) {
    debugPrint('$_tag: Stream error: $error');
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _sharedContentController.close();
    debugPrint('$_tag: Service disposed');
  }
}