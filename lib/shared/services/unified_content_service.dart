import '../models/unified_history.dart';
import '../models/content_type.dart';
import '../models/audio_content.dart';
import '../models/share_content.dart';
import 'audio_content_service.dart';
import 'unified_history_service.dart';

/// 统一内容服务接口
abstract class UnifiedContentService {
  /// 获取所有内容（录音+分享）
  Future<List<UnifiedHistory>> getAllContent();
  
  /// 按类型获取内容
  Future<List<UnifiedHistory>> getContentByType(ContentType type);
  
  /// 删除内容
  Future<bool> deleteContent(String id, ContentType type);
  
  /// 重命名内容
  Future<bool> renameContent(String id, ContentType type, String newTitle);
  
  /// 获取录音历史
  Future<List<AudioContent>> getAudioHistory();
  
  /// 获取分享历史
  Future<List<UnifiedHistory>> getShareHistory();
}

/// 统一内容服务实现
class UnifiedContentServiceImpl implements UnifiedContentService {
  static const String _tag = 'UnifiedContentService';
  
  final AudioContentService _audioService;
  final UnifiedHistoryService _historyService;
  
  UnifiedContentServiceImpl({
    AudioContentService? audioService,
    UnifiedHistoryService? historyService,
  }) : _audioService = audioService ?? AudioContentService(),
       _historyService = historyService ?? UnifiedHistoryServiceImpl();
  
  @override
  Future<List<UnifiedHistory>> getAllContent() async {
    try {
      print('$_tag: Loading all content...');
      
      // 并行加载录音和分享内容
      final results = await Future.wait([
        getAudioHistory(),
        getShareHistory(),
      ]);
      
      final audioContent = results[0] as List<AudioContent>;
      final shareContent = results[1] as List<UnifiedHistory>;
      
      // 合并所有内容
      final allContent = <UnifiedHistory>[
        ...audioContent,
        ...shareContent,
      ];
      
      // 按时间排序（最新的在前）
      allContent.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('$_tag: Loaded ${allContent.length} total items (${audioContent.length} audio, ${shareContent.length} share)');
      return allContent;
      
    } catch (e) {
      print('$_tag: Error loading all content: $e');
      return [];
    }
  }
  
  @override
  Future<List<UnifiedHistory>> getContentByType(ContentType type) async {
    try {
      print('$_tag: Loading content by type: $type');
      
      switch (type) {
        case ContentType.audio:
          return await getAudioHistory();
        case ContentType.share:
          return await getShareHistory();
      }
    } catch (e) {
      print('$_tag: Error loading content by type $type: $e');
      return [];
    }
  }
  
  @override
  Future<bool> deleteContent(String id, ContentType type) async {
    try {
      print('$_tag: Deleting content: $id (type: $type)');
      
      switch (type) {
        case ContentType.audio:
          return await _audioService.deleteAudioContent(id);
        case ContentType.share:
          // TODO: 实现分享内容删除
          print('$_tag: Share content deletion not implemented yet');
          return false;
      }
    } catch (e) {
      print('$_tag: Error deleting content $id: $e');
      return false;
    }
  }
  
  @override
  Future<bool> renameContent(String id, ContentType type, String newTitle) async {
    try {
      print('$_tag: Renaming content: $id to "$newTitle" (type: $type)');
      
      switch (type) {
        case ContentType.audio:
          return await _audioService.renameAudioContent(id, newTitle);
        case ContentType.share:
          // TODO: 实现分享内容重命名
          print('$_tag: Share content renaming not implemented yet');
          return false;
      }
    } catch (e) {
      print('$_tag: Error renaming content $id: $e');
      return false;
    }
  }
  
  @override
  Future<List<AudioContent>> getAudioHistory() async {
    try {
      return await _audioService.getAudioHistory();
    } catch (e) {
      print('$_tag: Error loading audio history: $e');
      return [];
    }
  }
  
  @override
  Future<List<UnifiedHistory>> getShareHistory() async {
    try {
      return await _historyService.getHistoryByType(ContentType.share);
    } catch (e) {
      print('$_tag: Error loading share history: $e');
      return [];
    }
  }
  
  /// 根据ID和类型获取单个内容
  Future<UnifiedHistory?> getContentById(String id, ContentType type) async {
    try {
      final contentList = await getContentByType(type);
      return contentList.cast<UnifiedHistory?>().firstWhere(
        (content) => content?.id == id,
        orElse: () => null,
      );
    } catch (e) {
      print('$_tag: Error getting content by id $id: $e');
      return null;
    }
  }
  
  /// 搜索内容
  Future<List<UnifiedHistory>> searchContent(String query, {ContentType? type}) async {
    try {
      final allContent = type != null 
          ? await getContentByType(type)
          : await getAllContent();
      
      if (query.isEmpty) {
        return allContent;
      }
      
      final lowerQuery = query.toLowerCase();
      return allContent.where((content) {
        return content.title.toLowerCase().contains(lowerQuery) ||
               (content.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
      
    } catch (e) {
      print('$_tag: Error searching content: $e');
      return [];
    }
  }
  
  /// 获取内容统计信息
  Future<Map<String, int>> getContentStats() async {
    try {
      final results = await Future.wait([
        getAudioHistory(),
        getShareHistory(),
      ]);
      
      final audioCount = (results[0] as List).length;
      final shareCount = (results[1] as List).length;
      
      return {
        'total': audioCount + shareCount,
        'audio': audioCount,
        'share': shareCount,
      };
      
    } catch (e) {
      print('$_tag: Error getting content stats: $e');
      return {
        'total': 0,
        'audio': 0,
        'share': 0,
      };
    }
  }
}