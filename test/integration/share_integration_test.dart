import 'package:flutter_test/flutter_test.dart';
import 'package:butterfly/shared/services/unified_history_service.dart';
import 'package:butterfly/shared/models/unified_history.dart';
import 'package:butterfly/shared/models/content_type.dart';
import 'package:butterfly/shared/models/share_content.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

void main() {
  group('Share Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      // 创建临时目录用于测试
      tempDir = await Directory.systemTemp.createTemp('butterfly_test');
    });

    tearDown(() async {
      // 清理测试数据
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create valid ShareContent instance', () {
      // 准备测试数据
      final shareContent = ShareContent(
        id: 'test-id',
        title: 'Test share content',
        timestamp: DateTime.now(),
        messageCount: 1,
        imageCount: 0,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
      );

      // 验证结果
      expect(shareContent.id, 'test-id');
      expect(shareContent.title, 'Test share content');
      expect(shareContent.contentType, ContentType.share);
      expect(shareContent.messageCount, 1);
      expect(shareContent.imageCount, 0);
      expect(shareContent.sourceApp, 'test-app');
    });

    test('should handle empty share content', () {
      // 测试空内容
      final shareContent = ShareContent(
        id: 'test-empty',
        title: '',
        timestamp: DateTime.now(),
        messageCount: 0,
        imageCount: 0,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
      );

      expect(shareContent.title, '');
      expect(shareContent.messageCount, 0);
      expect(shareContent.imageCount, 0);
    });

    test('should handle share content with images', () {
      final shareContent = ShareContent(
        id: 'test-with-images',
        title: 'Content with image',
        timestamp: DateTime.now(),
        messageCount: 1,
        imageCount: 1,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
        metadata: {'hasImages': true},
      );

      expect(shareContent.title, 'Content with image');
      expect(shareContent.imageCount, 1);
      expect(shareContent.metadata['hasImages'], true);
    });

    test('should convert to JSON and back', () {
      final now = DateTime.now();
      final shareContent = ShareContent(
        id: 'test-json',
        title: 'JSON test content',
        timestamp: now,
        messageCount: 2,
        imageCount: 1,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
        description: 'Test description',
        metadata: {'key': 'value'},
      );

      final json = shareContent.toJson();
      final restored = ShareContent.fromJson(json);

      expect(restored.id, shareContent.id);
      expect(restored.title, shareContent.title);
      expect(restored.messageCount, shareContent.messageCount);
      expect(restored.imageCount, shareContent.imageCount);
      expect(restored.sourceApp, shareContent.sourceApp);
      expect(restored.metadata['key'], 'value');
    });

    test('should provide content type description', () {
      final textOnly = ShareContent(
        id: 'text-only',
        title: 'Text content',
        timestamp: DateTime.now(),
        messageCount: 1,
        imageCount: 0,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
      );

      final imageOnly = ShareContent(
        id: 'image-only',
        title: 'Image content',
        timestamp: DateTime.now(),
        messageCount: 0,
        imageCount: 1,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
      );

      final mixed = ShareContent(
        id: 'mixed',
        title: 'Mixed content',
        timestamp: DateTime.now(),
        messageCount: 1,
        imageCount: 1,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
      );

      expect(textOnly.contentTypeDescription, '文本内容');
      expect(imageOnly.contentTypeDescription, '图片内容');
      expect(mixed.contentTypeDescription, '混合内容');
    });

    test('should provide content summary', () {
      final shareContent = ShareContent(
        id: 'test-summary',
        title: 'Summary test',
        timestamp: DateTime.now(),
        messageCount: 3,
        imageCount: 2,
        sourceApp: 'test-app',
        directoryPath: tempDir.path,
      );

      expect(shareContent.contentSummary, '3条消息，2张图片');
    });
  });

  group('UnifiedHistory Model Tests', () {
    test('should create valid UnifiedHistory from share content', () {
      final now = DateTime.now();
      final history = UnifiedHistory(
        id: 'test-id',
        title: 'Test Title',
        description: 'Test Description',
        timestamp: now,
        contentType: ContentType.share,
        filePath: '/test/path',
        metadata: {'key': 'value'},
      );

      expect(history.id, 'test-id');
      expect(history.title, 'Test Title');
      expect(history.contentType, ContentType.share);
      expect(history.timestamp, now);
      expect(history.metadata?['key'], 'value');
    });

    test('should handle null metadata', () {
      final history = UnifiedHistory(
        id: 'test-id',
        title: 'Test Title',
        description: 'Test Description',
        timestamp: DateTime.now(),
        contentType: ContentType.share,
        filePath: '/test/path',
      );

      // UnifiedHistory 构造函数会将 null 转换为空 Map
      expect(history.metadata, {});
    });
  });
}