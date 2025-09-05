import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/shared_content.dart';

/// 本地存储服务抽象类
abstract class LocalStorageService {
  Future<void> initialize();
  Future<String> saveSharedContent(SharedContent content);
  Future<List<ShareHistory>> getShareHistory();
  Future<ShareHistory?> getShareHistoryById(String id);
  Future<void> deleteShareHistory(String id);
  Future<void> updateShareContent(String id, String newContent);
  Future<String> saveImageToLocal(String sourceUri, String localDirectory, String fileName);
  Future<void> createDirectory(String path);
}

/// 本地存储服务实现类
class LocalStorageServiceImpl implements LocalStorageService {
  static const String _tag = '[LocalStorageService]';
  
  String? _appDocumentsPath;
  
  @override
  Future<void> initialize() async {
    try {
      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      
      // 确保共享内容目录存在
      final sharedContentDir = Directory(path.join(_appDocumentsPath!, 'shared_content'));
      if (!await sharedContentDir.exists()) {
        await sharedContentDir.create(recursive: true);
      }
      
      print('$_tag: Service initialized successfully');
    } catch (e) {
      print('$_tag: Failed to initialize service: $e');
      rethrow;
    }
  }
  
  @override
  Future<String> saveSharedContent(SharedContent content) async {
    try {
      // 创建本地目录
      final localDirectory = path.join(_appDocumentsPath!, 'shared_content', content.localDirectory);
      await createDirectory(localDirectory);
      
      // 保存图片到本地
      final updatedImages = <SharedImage>[];
      if (content.images.isNotEmpty) {
        final imagesDir = path.join(localDirectory, 'images');
        await createDirectory(imagesDir);
        
        for (final image in content.images) {
          String localPath;
          
          // 检查是否已经是内部存储路径（原生层已处理）
          if (image.localPath.contains('/data/data/') || 
              image.localPath.contains('shared_files')) {
            // 已经是内部存储路径，直接使用
            localPath = image.localPath;
            print('$_tag: Using existing internal path: $localPath');
          } else {
            // 需要复制到本地
            localPath = await saveImageToLocal(
              image.uri,
              imagesDir,
              image.fileName ?? 'image.jpg',
            );
            print('$_tag: Copied to local path: $localPath');
          }
          
          updatedImages.add(SharedImage(
            uri: image.uri,
            localPath: localPath,
            fileName: image.fileName,
            fileSize: image.fileSize,
          ));
        }
      }
      
      // 保存内容信息到content.json文件
       final contentFile = File(path.join(localDirectory, 'content.json'));
       final contentData = {
         'id': content.id,
         'text': content.text,
         'images': updatedImages.map((img) => {
           'uri': img.uri,
           'localPath': img.localPath,
           'fileName': img.fileName,
           'fileSize': img.fileSize,
         }).toList(),
         'receivedAt': content.receivedAt.millisecondsSinceEpoch,
         'sourceApp': content.sourceApp,
         'localDirectory': content.localDirectory,
       };
       await contentFile.writeAsString(json.encode(contentData));
      
      print('$_tag: Saved shared content to $localDirectory');
      return localDirectory;
    } catch (e) {
      print('$_tag: Failed to save shared content: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<ShareHistory>> getShareHistory() async {
    try {
      print('$_tag: Scanning local directories for share history');
      
      // 确保服务已初始化
      if (_appDocumentsPath == null) {
        await initialize();
      }
      
      final sharedContentDir = Directory(path.join(_appDocumentsPath!, 'shared_content'));
      
      if (!await sharedContentDir.exists()) {
        print('$_tag: Shared content directory does not exist');
        return [];
      }
      
      final List<ShareHistory> histories = [];
      final subDirs = await sharedContentDir.list().where((entity) => entity is Directory).cast<Directory>().toList();
      
      print('$_tag: Found ${subDirs.length} content directories');
      
      for (final dir in subDirs) {
        try {
          final contentFile = File(path.join(dir.path, 'content.json'));
          if (await contentFile.exists()) {
            final contentJson = await contentFile.readAsString();
            final contentData = json.decode(contentJson) as Map<String, dynamic>;
            
            // 从content.json构建ShareHistory
            final dirName = path.basename(dir.path);
            
            // 解析目录名获取时间戳 (格式: YYYYMMDD_HHMMSS)
            DateTime? createdAt;
            try {
              final parts = dirName.split('_');
              if (parts.length == 2) {
                final datePart = parts[0]; // YYYYMMDD
                final timePart = parts[1]; // HHMMSS
                final year = int.parse(datePart.substring(0, 4));
                final month = int.parse(datePart.substring(4, 6));
                final day = int.parse(datePart.substring(6, 8));
                final hour = int.parse(timePart.substring(0, 2));
                final minute = int.parse(timePart.substring(2, 4));
                final second = int.parse(timePart.substring(4, 6));
                createdAt = DateTime(year, month, day, hour, minute, second);
              }
            } catch (e) {
              print('$_tag: Failed to parse timestamp from directory name: $dirName');
            }
            
            // 生成基于内容的标题
            final text = contentData['text'] as String?;
            final images = contentData['images'] as List?;
            
            String title;
            if (text?.isNotEmpty == true) {
              // 使用文本内容的前30个字符作为标题
              final cleanText = text!.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
              if (cleanText.length > 30) {
                title = '${cleanText.substring(0, 30)}...';
              } else {
                title = cleanText.isNotEmpty ? cleanText : '文本分享';
              }
            } else if (images?.isNotEmpty == true) {
              final imageCount = images!.length;
              title = imageCount == 1 ? '[图片]' : '[${imageCount}张图片]';
            } else {
              title = '分享记录';
            }
            
            final history = ShareHistory(
              id: contentData['id'] as String? ?? dirName,
              title: title,
              createdAt: createdAt ?? DateTime.now(),
              directoryPath: dir.path,
              messageCount: text?.isNotEmpty == true ? 1 : 0,
              imageCount: images?.length ?? 0,
              sourceApp: contentData['sourceApp'] as String? ?? '未知应用',
            );
            
            histories.add(history);
            print('$_tag: Added history from ${dir.path}');
          }
        } catch (e) {
          print('$_tag: Failed to process directory ${dir.path}: $e');
        }
      }
      
      // 按创建时间降序排序
      histories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('$_tag: Successfully loaded ${histories.length} share histories');
      return histories;
    } catch (e) {
      print('$_tag: Failed to get share history: $e');
      return [];
    }
  }
  
  @override
  Future<ShareHistory?> getShareHistoryById(String id) async {
    try {
      final histories = await getShareHistory();
      return histories.firstWhere(
        (history) => history.id == id,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      print('$_tag: Failed to get share history by id: $e');
      return null;
    }
  }
  
  @override
  Future<void> deleteShareHistory(String id) async {
    try {
      // 获取历史记录
      final history = await getShareHistoryById(id);
      if (history == null) return;
      
      // 删除本地文件夹
      final directory = Directory(history.directoryPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      
      // 记录已通过删除目录被移除
      
      print('$_tag: Deleted share history: $id');
    } catch (e) {
      print('$_tag: Failed to delete share history: $e');
      rethrow;
    }
  }
  
  @override
  Future<String> saveImageToLocal(String sourceUri, String localDirectory, String fileName) async {
    try {
      final sourceFile = File(sourceUri);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: $sourceUri');
      }
      
      final localPath = path.join(localDirectory, fileName);
      
      // 复制文件到本地目录
      await sourceFile.copy(localPath);
      
      print('$_tag: Saved image to $localPath');
      return localPath;
    } catch (e) {
      print('$_tag: Failed to save image: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> createDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      print('$_tag: Failed to create directory: $e');
      rethrow;
    }
  }
  

  
  /// 生成标题
  String _generateTitle(SharedContent content) {
    if (content.text != null && content.text!.isNotEmpty) {
      // 如果有文本，使用文本的前30个字符作为标题
      final text = content.text!.trim();
      if (text.length <= 30) {
        return text;
      }
      return '${text.substring(0, 30)}...';
    }
    
    if (content.images.isNotEmpty) {
      // 如果只有图片，根据图片数量生成标题
      final count = content.images.length;
      return count == 1 ? '分享的图片' : '分享的 $count 张图片';
    }
    
    // 默认标题
    return '分享内容';
  }
  
  @override
  Future<void> updateShareContent(String id, String newContent) async {
    try {
      if (_appDocumentsPath == null) {
        throw Exception('LocalStorageService not initialized');
      }
      
      print('$_tag: Updating share content for id: $id');
      
      // 查找包含该ID的目录
      final sharedContentDir = Directory(path.join(_appDocumentsPath!, 'shared_content'));
      if (!await sharedContentDir.exists()) {
        throw Exception('Shared content directory not found');
      }
      
      Directory? targetDir;
      await for (final entity in sharedContentDir.list()) {
        if (entity is Directory) {
          final contentFile = File(path.join(entity.path, 'content.json'));
          if (await contentFile.exists()) {
            try {
              final contentJson = json.decode(await contentFile.readAsString());
              if (contentJson['id'] == id) {
                targetDir = entity;
                break;
              }
            } catch (e) {
              print('$_tag: Failed to read content file in ${entity.path}: $e');
            }
          }
        }
      }
      
      if (targetDir == null) {
        throw Exception('Share content with id $id not found');
      }
      
      // 更新content.json文件
      final contentFile = File(path.join(targetDir.path, 'content.json'));
      final contentJson = json.decode(await contentFile.readAsString());
      
      // 更新文本内容
      contentJson['text'] = newContent;
      contentJson['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      
      // 写回文件
      await contentFile.writeAsString(json.encode(contentJson));
      
      print('$_tag: Successfully updated share content for id: $id');
    } catch (e) {
      print('$_tag: Failed to update share content: $e');
      rethrow;
    }
  }
  
  /// 从文本生成标题
  String _generateTitleFromText(String text) {
    if (text.isEmpty) return '分享内容';
    
    final trimmedText = text.trim();
    if (trimmedText.length <= 30) {
      return trimmedText;
    }
    return '${trimmedText.substring(0, 30)}...';
  }

  /// 释放资源
  Future<void> dispose() async {
    print('$_tag: Service disposed');
  }
}

/// SharedImage 扩展方法
extension SharedImageExtension on SharedImage {
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