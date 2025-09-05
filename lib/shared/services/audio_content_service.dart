import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/audio_content.dart';

/// 录音内容服务
/// 负责加载、管理录音文件和元数据
class AudioContentService {
  static const String _tag = 'AudioContentService';
  
  /// 获取录音历史记录
  Future<List<AudioContent>> getAudioHistory() async {
    try {
      print('$_tag: Loading audio history...');
      
      final documentsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(path.join(documentsDir.path, 'audio_files'));
      
      if (!await audioDir.exists()) {
        print('$_tag: Audio directory does not exist');
        return [];
      }
      
      // 获取所有音频文件
      final audioFiles = await _getAudioFiles(audioDir);
      print('$_tag: Found ${audioFiles.length} audio files');
      
      // 加载元数据
      final metadataList = await _loadAllMetadata(audioDir);
      print('$_tag: Loaded ${metadataList.length} metadata entries');
      
      // 转换为 AudioContent 对象
      final audioContentList = <AudioContent>[];
      
      for (final file in audioFiles) {
        try {
          final audioContent = await _createAudioContentFromFile(file, metadataList);
          if (audioContent != null) {
            audioContentList.add(audioContent);
          }
        } catch (e) {
          print('$_tag: Error processing file ${file.path}: $e');
        }
      }
      
      // 按时间排序（最新的在前）
      audioContentList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('$_tag: Successfully loaded ${audioContentList.length} audio content items');
      return audioContentList;
      
    } catch (e) {
      print('$_tag: Error loading audio history: $e');
      return [];
    }
  }
  
  /// 根据ID获取单个录音内容
  Future<AudioContent?> getAudioContentById(String id) async {
    final allContent = await getAudioHistory();
    try {
      return allContent.firstWhere((content) => content.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// 删除录音内容
  Future<bool> deleteAudioContent(String id) async {
    try {
      final audioContent = await getAudioContentById(id);
      if (audioContent == null) {
        print('$_tag: Audio content not found: $id');
        return false;
      }
      
      // 删除音频文件
      final audioFile = File(audioContent.audioFilePath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      
      // 删除波形文件
      if (audioContent.waveFilePath != null) {
        final waveFile = File(audioContent.waveFilePath!);
        if (await waveFile.exists()) {
          await waveFile.delete();
        }
      }
      
      // 删除标记文件
      if (audioContent.marksFilePath != null) {
        final marksFile = File(audioContent.marksFilePath!);
        if (await marksFile.exists()) {
          await marksFile.delete();
        }
      }
      
      // 删除元数据
      await _deleteMetadata(audioContent.id);
      
      print('$_tag: Successfully deleted audio content: $id');
      return true;
      
    } catch (e) {
      print('$_tag: Error deleting audio content $id: $e');
      return false;
    }
  }
  
  /// 重命名录音内容
  Future<bool> renameAudioContent(String id, String newTitle) async {
    try {
      final audioContent = await getAudioContentById(id);
      if (audioContent == null) {
        print('$_tag: Audio content not found: $id');
        return false;
      }
      
      // 更新元数据
      final updatedMetadata = Map<String, dynamic>.from(audioContent.metadata);
      updatedMetadata['displayName'] = newTitle;
      updatedMetadata['title'] = newTitle;
      
      await _saveMetadata(id, updatedMetadata);
      
      print('$_tag: Successfully renamed audio content $id to "$newTitle"');
      return true;
      
    } catch (e) {
      print('$_tag: Error renaming audio content $id: $e');
      return false;
    }
  }
  
  // 私有方法
  
  /// 获取所有音频文件
  Future<List<File>> _getAudioFiles(Directory audioDir) async {
    final files = <File>[];
    
    await for (final entity in audioDir.list()) {
      if (entity is File && entity.path.endsWith('.wav')) {
        files.add(entity);
      }
    }
    
    return files;
  }
  
  /// 加载所有元数据
  Future<List<Map<String, dynamic>>> _loadAllMetadata(Directory audioDir) async {
    final metadataList = <Map<String, dynamic>>[];
    
    await for (final entity in audioDir.list()) {
      if (entity is File && entity.path.endsWith('meta.json')) {
        try {
          final content = await entity.readAsString();
          final metadata = json.decode(content) as Map<String, dynamic>;
          metadataList.add(metadata);
        } catch (e) {
          print('$_tag: Error reading metadata file ${entity.path}: $e');
        }
      }
    }
    
    return metadataList;
  }
  
  /// 从文件创建 AudioContent 对象
  Future<AudioContent?> _createAudioContentFromFile(
    File audioFile, 
    List<Map<String, dynamic>> metadataList
  ) async {
    try {
      final fileName = path.basenameWithoutExtension(audioFile.path);
      final fileId = fileName;
      
      // 查找对应的元数据
      Map<String, dynamic>? metadata;
      try {
        metadata = metadataList.firstWhere(
          (meta) => meta['id'] == fileId || meta['fileName'] == fileName
        );
      } catch (e) {
        // 如果没有找到元数据，创建默认的
        metadata = {
          'id': fileId,
          'fileName': fileName,
          'displayName': fileName,
          'title': fileName,
          'tags': <String>[],
          'quality': 'standard',
        };
      }
      
      // 获取文件信息
      final fileStat = await audioFile.stat();
      final fileSize = fileStat.size;
      final timestamp = fileStat.modified;
      
      // 获取音频时长
      final duration = await _getAudioDuration(audioFile.path);
      
      // 修正显示名称
      if (metadata['displayName'] == null || metadata['displayName'].toString().isEmpty) {
        metadata['displayName'] = fileName;
      }
      
      return AudioContent.fromMetadata(
        id: fileId,
        audioFilePath: audioFile.path,
        metadata: metadata,
        timestamp: timestamp,
        duration: duration,
        fileSize: fileSize,
      );
      
    } catch (e) {
      print('$_tag: Error creating AudioContent from file ${audioFile.path}: $e');
      return null;
    }
  }
  
  /// 获取音频时长
  Future<Duration> _getAudioDuration(String audioFilePath) async {
    try {
      // 首先尝试从波形文件获取时长
      final waveFilePath = audioFilePath.replaceAll('.wav', '_wave.json');
      final waveFile = File(waveFilePath);
      
      if (await waveFile.exists()) {
        final waveContent = await waveFile.readAsString();
        final waveData = json.decode(waveContent) as Map<String, dynamic>;
        
        if (waveData.containsKey('duration')) {
          final durationSeconds = (waveData['duration'] as num).toDouble();
          return Duration(milliseconds: (durationSeconds * 1000).round());
        }
      }
      
      // 如果波形文件不存在或没有时长信息，返回默认值
      // 这里可以集成音频库来获取真实时长，暂时返回0
      return Duration.zero;
      
    } catch (e) {
      print('$_tag: Error getting audio duration for $audioFilePath: $e');
      return Duration.zero;
    }
  }
  
  /// 保存元数据
  Future<void> _saveMetadata(String id, Map<String, dynamic> metadata) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final metaFilePath = path.join(documentsDir.path, 'audio_files', '${id}_meta.json');
      final metaFile = File(metaFilePath);
      
      await metaFile.writeAsString(json.encode(metadata));
      
    } catch (e) {
      print('$_tag: Error saving metadata for $id: $e');
      rethrow;
    }
  }
  
  /// 删除元数据
  Future<void> _deleteMetadata(String id) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final metaFilePath = path.join(documentsDir.path, 'audio_files', '${id}_meta.json');
      final metaFile = File(metaFilePath);
      
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
      
    } catch (e) {
      print('$_tag: Error deleting metadata for $id: $e');
    }
  }
}