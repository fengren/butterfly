import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/unified_history.dart';
import '../models/content_type.dart';
import '../models/shared_content.dart' as storage;
import '../models/share_content.dart';
import '../models/audio_record.dart';
import 'local_storage_service.dart';

/// 统一历史记录服务接口
abstract class UnifiedHistoryService {
  /// 初始化服务
  Future<void> initialize();
  
  /// 获取所有历史记录
  Future<List<UnifiedHistory>> getAllHistory();
  
  /// 根据内容类型获取历史记录
  Future<List<UnifiedHistory>> getHistoryByType(ContentType type);
  
  /// 根据ID获取历史记录
  Future<UnifiedHistory?> getHistoryById(String id);
  
  /// 添加分享历史记录
  Future<void> addShareHistory(ShareContent shareContent);
  
  /// 添加录音历史记录
  Future<void> addAudioHistory(AudioRecord audioRecord);
  
  /// 删除历史记录
  Future<void> deleteHistory(String id);
  
  /// 搜索历史记录
  Future<List<UnifiedHistory>> searchHistory(String query);
}

/// 统一历史记录服务实现
class UnifiedHistoryServiceImpl implements UnifiedHistoryService {
  static const String _tag = 'UnifiedHistoryService';
  
  String? _appDocumentsPath;
  late LocalStorageService _localStorageService;
  
  UnifiedHistoryServiceImpl() {
    _localStorageService = LocalStorageServiceImpl();
  }
  
  @override
  Future<void> initialize() async {
    try {
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      _appDocumentsPath = appDocumentsDir.path;
      
      // 初始化本地存储服务
      await _localStorageService.initialize();
      
      // 确保目录结构存在
      await _ensureDirectoryStructure();
      
      print('$_tag: Service initialized successfully');
    } catch (e) {
      print('$_tag: Failed to initialize service: $e');
      rethrow;
    }
  }
  
  /// 确保目录结构存在
  Future<void> _ensureDirectoryStructure() async {
    if (_appDocumentsPath == null) return;
    
    final directories = [
      path.join(_appDocumentsPath!, 'shared_content'),
      path.join(_appDocumentsPath!, 'audio_content'),
    ];
    
    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        print('$_tag: Created directory: $dirPath');
      }
    }
  }
  
  @override
  Future<List<UnifiedHistory>> getAllHistory() async {
    try {
      final shareHistories = await _getShareHistories();
      final audioHistories = await _getAudioHistories();
      
      final allHistories = <UnifiedHistory>[
        ...shareHistories,
        ...audioHistories,
      ];
      
      // 按时间戳降序排序
      allHistories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('$_tag: Loaded ${allHistories.length} total histories');
      return allHistories;
    } catch (e) {
      print('$_tag: Failed to get all history: $e');
      return [];
    }
  }
  
  @override
  Future<List<UnifiedHistory>> getHistoryByType(ContentType type) async {
    try {
      switch (type) {
        case ContentType.share:
          return await _getShareHistories();
        case ContentType.audio:
          return await _getAudioHistories();
      }
    } catch (e) {
      print('$_tag: Failed to get history by type $type: $e');
      return [];
    }
  }
  
  @override
  Future<UnifiedHistory?> getHistoryById(String id) async {
    try {
      final allHistories = await getAllHistory();
      return allHistories.firstWhere(
        (history) => history.id == id,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      print('$_tag: Failed to get history by id $id: $e');
      return null;
    }
  }
  
  @override
  Future<void> addShareHistory(ShareContent shareContent) async {
    try {
      print('$_tag: Adding share history: ${shareContent.title}');
      
      // 创建 SharedContent 对象用于持久化
      final sharedContent = storage.SharedContent(
        id: shareContent.id,
        text: shareContent.title,
        images: shareContent.originalContent?.images?.cast<storage.SharedImage>() ?? const [],
        receivedAt: shareContent.timestamp,
        sourceApp: shareContent.sourceApp,
        localDirectory: path.basename(shareContent.directoryPath),
      );
      
      await _localStorageService.saveSharedContent(sharedContent);
      
      print('$_tag: Added share history: ${shareContent.id}');
    } catch (e) {
      print('$_tag: Error adding share history: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> addAudioHistory(AudioRecord audioRecord) async {
    try {
      if (_appDocumentsPath == null) {
        throw StateError('Service not initialized');
      }
      
      final audioContentDir = Directory(path.join(_appDocumentsPath!, 'audio_content'));
      if (!await audioContentDir.exists()) {
        await audioContentDir.create(recursive: true);
      }
      
      // 创建以时间戳命名的目录
      final timestamp = audioRecord.timestamp.millisecondsSinceEpoch;
      final recordDir = Directory(path.join(audioContentDir.path, timestamp.toString()));
      await recordDir.create();
      
      // 保存录音元数据
      final metadataFile = File(path.join(recordDir.path, 'metadata.json'));
      await metadataFile.writeAsString(json.encode(audioRecord.toJson()));
      
      print('$_tag: Added audio history: ${audioRecord.id}');
    } catch (e) {
      print('$_tag: Failed to add audio history: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> deleteHistory(String id) async {
    try {
      final history = await getHistoryById(id);
      if (history == null) return;
      
      switch (history.contentType) {
        case ContentType.share:
          await _localStorageService.deleteShareHistory(id);
          break;
        case ContentType.audio:
          await _deleteAudioHistory(id);
          break;
      }
      
      print('$_tag: Deleted history: $id');
    } catch (e) {
      print('$_tag: Failed to delete history: $e');
      rethrow;
    }
  }
  
  @override
  Future<List<UnifiedHistory>> searchHistory(String query) async {
    try {
      final allHistories = await getAllHistory();
      final lowerQuery = query.toLowerCase();
      
      return allHistories.where((history) {
        return history.title.toLowerCase().contains(lowerQuery) ||
               (history.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      print('$_tag: Failed to search history: $e');
      return [];
    }
  }
  
  /// 获取分享历史记录
  Future<List<UnifiedHistory>> _getShareHistories() async {
    try {
      final shareHistories = await _localStorageService.getShareHistory();
      return shareHistories.map((history) => UnifiedHistory(
        id: history.id,
        title: history.title,
        description: '来自 ${history.sourceApp}',
        timestamp: history.createdAt,
        contentType: ContentType.share,
        filePath: history.directoryPath,
        metadata: {
          'messageCount': history.messageCount,
          'imageCount': history.imageCount,
          'sourceApp': history.sourceApp,
        },
      )).toList();
    } catch (e) {
      print('$_tag: Failed to get share histories: $e');
      return [];
    }
  }
  
  /// 获取录音历史记录
  Future<List<UnifiedHistory>> _getAudioHistories() async {
    try {
      if (_appDocumentsPath == null) return [];
      
      final audioContentDir = Directory(path.join(_appDocumentsPath!, 'audio_content'));
      if (!await audioContentDir.exists()) return [];
      
      final audioHistories = <UnifiedHistory>[];
      final subDirs = await audioContentDir.list()
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();
      
      for (final dir in subDirs) {
        try {
          final metadataFile = File(path.join(dir.path, 'metadata.json'));
          if (await metadataFile.exists()) {
            final metadataJson = await metadataFile.readAsString();
            final metadataData = json.decode(metadataJson) as Map<String, dynamic>;
            
            // 创建 UnifiedHistory 对象
            final audioHistory = UnifiedHistory(
              id: metadataData['id'] as String,
              title: metadataData['title'] as String? ?? '录音记录',
              description: '录音时长: ${metadataData['duration'] ?? '未知'}',
              timestamp: DateTime.fromMillisecondsSinceEpoch(metadataData['timestamp'] as int),
              contentType: ContentType.audio,
              filePath: dir.path,
              metadata: metadataData,
            );
            audioHistories.add(audioHistory);
          }
        } catch (e) {
          print('$_tag: Failed to process audio directory ${dir.path}: $e');
        }
      }
      
      // 按时间戳降序排序
      audioHistories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('$_tag: Loaded ${audioHistories.length} audio histories');
      return audioHistories;
    } catch (e) {
      print('$_tag: Failed to get audio histories: $e');
      return [];
    }
  }
  
  /// 删除录音历史记录
  Future<void> _deleteAudioHistory(String id) async {
    try {
      if (_appDocumentsPath == null) return;
      
      final audioContentDir = Directory(path.join(_appDocumentsPath!, 'audio_content'));
      if (!await audioContentDir.exists()) return;
      
      final subDirs = await audioContentDir.list()
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();
      
      for (final dir in subDirs) {
        try {
          final metadataFile = File(path.join(dir.path, 'metadata.json'));
          if (await metadataFile.exists()) {
            final metadataJson = await metadataFile.readAsString();
            final metadataData = json.decode(metadataJson) as Map<String, dynamic>;
            
            if (metadataData['id'] == id) {
              await dir.delete(recursive: true);
              print('$_tag: Deleted audio history directory: ${dir.path}');
              return;
            }
          }
        } catch (e) {
          print('$_tag: Failed to check audio directory ${dir.path}: $e');
        }
      }
    } catch (e) {
      print('$_tag: Failed to delete audio history: $e');
      rethrow;
    }
  }
}