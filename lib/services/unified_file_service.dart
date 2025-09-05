import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/unified_file_item.dart';
import '../shared/services/local_storage_service.dart';

/// 统一文件服务
/// 负责加载和管理录音文件和分享文件
class UnifiedFileService {
  final LocalStorageService _storageService;
  
  UnifiedFileService(this._storageService);
  
  /// 加载所有文件（录音文件 + 分享文件）
  Future<List<UnifiedFileItem>> loadAllFiles() async {
    try {
      final audioFiles = await _loadAudioFiles();
      final shareFiles = await _loadShareFiles();
      
      final allFiles = [...audioFiles, ...shareFiles];
      // 按创建时间倒序排列
      allFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return allFiles;
    } catch (e) {
      print('Error loading files: $e');
      return [];
    }
  }
  
  /// 加载录音文件
  Future<List<UnifiedFileItem>> _loadAudioFiles() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final documentsPath = documentsDir.path;
      
      // 加载元数据
      final metadataList = await _loadAudioMetadata(documentsPath);
      
      // 转换为UnifiedFileItem
      return metadataList
          .map((meta) => UnifiedFileItem.fromAudioMeta(meta, documentsPath))
          .toList();
    } catch (e) {
      print('Error loading audio files: $e');
      return [];
    }
  }
  
  /// 加载录音文件元数据（复用现有逻辑）
  Future<List<Map<String, dynamic>>> _loadAudioMetadata(String documentsPath) async {
    final List<Map<String, dynamic>> metadataList = [];
    
    try {
      // 使用根目录的meta.json文件，与main.dart保持一致
      final metaFile = File('$documentsPath/meta.json');
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final List<dynamic> list = json.decode(content);
        
        for (final item in list) {
          final meta = Map<String, dynamic>.from(item);
          
          // 验证必要字段
          if (meta.containsKey('id') && meta.containsKey('audioPath')) {
            // 计算文件大小和时长
            await _enrichAudioMetadata(meta, documentsPath);
            metadataList.add(meta);
          }
        }
      }
    } catch (e) {
      print('Error loading audio metadata: $e');
    }
    
    return metadataList;
  }
  
  /// 丰富录音文件元数据（添加文件大小、时长等）
  Future<void> _enrichAudioMetadata(Map<String, dynamic> meta, String documentsPath) async {
    try {
      final audioPath = meta['audioPath'] as String?;
      if (audioPath != null) {
        final audioFile = File('$documentsPath/$audioPath');
        if (await audioFile.exists()) {
          final stat = await audioFile.stat();
          meta['fileSize'] = stat.size;
          
          // 尝试从波形文件获取时长
          final wavePath = meta['wavePath'] as String?;
          if (wavePath != null) {
            final waveFile = File('$documentsPath/$wavePath');
            if (await waveFile.exists()) {
              try {
                final waveContent = await waveFile.readAsString();
                final waveData = json.decode(waveContent);
                if (waveData['duration'] != null) {
                  final durationMs = waveData['duration'] as num;
                  meta['duration'] = _formatDuration(Duration(milliseconds: durationMs.toInt()));
                }
              } catch (e) {
                print('Error reading wave file: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error enriching audio metadata: $e');
    }
  }
  
  /// 加载分享文件
  Future<List<UnifiedFileItem>> _loadShareFiles() async {
    try {
      final shareHistories = await _storageService.getShareHistory();
      return shareHistories
          .map((history) => UnifiedFileItem.fromShareHistory(history))
          .toList();
    } catch (e) {
      print('Error loading share files: $e');
      return [];
    }
  }
  
  /// 按类型筛选文件
  List<UnifiedFileItem> filterByType(List<UnifiedFileItem> files, FileType type) {
    return files.where((file) => file.type == type).toList();
  }
  
  /// 搜索文件
  List<UnifiedFileItem> searchFiles(List<UnifiedFileItem> files, String query) {
    if (query.isEmpty) return files;
    
    final lowerQuery = query.toLowerCase();
    return files.where((file) {
      return file.title.toLowerCase().contains(lowerQuery) ||
             (file.tag?.toLowerCase().contains(lowerQuery) ?? false) ||
             (file.sourceApp?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
  
  /// 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }
}