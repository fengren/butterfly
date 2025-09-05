import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/shared_content.dart';
import '../models/share_content.dart' hide SharedImage;
import '../models/chat_message.dart';
import '../services/content_parser.dart';
import '../services/local_storage_service.dart';
import '../widgets/chat_display_widget.dart';

// SharedContent 已经有 copyWith 方法，无需扩展

/// 分享记录详细查看页面
/// 参照 butterfly_lib/audio_player_page.dart 的设计风格
class ShareDetailPage extends StatefulWidget {
  final ShareContent history;
  
  const ShareDetailPage({
    super.key,
    required this.history,
  });
  
  @override
  State<ShareDetailPage> createState() => _ShareDetailPageState();
}

class _ShareDetailPageState extends State<ShareDetailPage> {
  final ContentParser _contentParser = ContentParserImpl();
  final LocalStorageService _localStorageService = LocalStorageServiceImpl();
  final TextEditingController _textController = TextEditingController();
  
  SharedContent? _sharedContent;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isEditing = true;  // 默认进入编辑模式
  bool _hasChanges = false;

  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      await _localStorageService.initialize();
      _loadShareContent();
    } catch (e) {
      print('Failed to initialize services: $e');
      setState(() {
        _error = '初始化失败: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
  
  void _handleMenuAction(String action) {
    switch (action) {
      case 'summarize_to_jira':
        _summarizeToJira();
        break;
    }
  }
  
  void _initializeTextContent() {
    String textContent = '';
    
    if (_sharedContent != null && _sharedContent!.text != null) {
      // 优先使用原始分享内容
      textContent = _sharedContent!.text!;
    } else if (_messages.isNotEmpty) {
      // 如果没有原始内容，从消息中获取
      textContent = _messages
          .where((msg) => msg.type == ChatMessageType.text)
          .map((msg) => msg.content)
          .join('\n\n');
    }
    
    _textController.text = textContent;
    print('📝 初始化文本编辑器: "$textContent"');
    
    // 初始化后检查变更状态
    _checkForChanges();
  }
  
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // 退出编辑模式时检查是否有变更
        _checkForChanges();
      }
    });
  }
  
  void _checkForChanges() {
    // 获取原始文本内容
    String originalContent = '';
    if (_sharedContent != null && _sharedContent!.text != null) {
      originalContent = _sharedContent!.text!;
    } else {
      // 如果没有原始内容，从消息中获取
      originalContent = _messages
          .where((msg) => msg.type == ChatMessageType.text)
          .map((msg) => msg.content)
          .join('\n\n');
    }
    
    final currentText = _textController.text.trim();
    final originalText = originalContent.trim();
    
    _hasChanges = currentText != originalText;
    print('🔍 检查变更: 原文="$originalText", 当前="$currentText", 有变更=$_hasChanges');
  }
  
  Future<void> _saveContent() async {
    if (_sharedContent == null) return;
    
    // 检查是否有变更
    _checkForChanges();
    if (!_hasChanges) {
      print('💾 没有需要保存的更改');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有需要保存的更改')),
      );
      return;
    }
    
    try {
      print('💾 开始保存内容: ${widget.history.id}');
      print('💾 原文本: ${_sharedContent!.text}');
      print('💾 新文本: ${_textController.text}');
      
      // 更新文本内容
      final updatedContent = _sharedContent!.copyWith(
        text: _textController.text,
      );
      
      // 保存到本地存储（更新content.json文件）
      await _localStorageService.updateShareContent(widget.history.id, _textController.text);
      print('💾 本地存储更新成功');
      
      setState(() {
        _sharedContent = updatedContent;
        _hasChanges = false;
        _isEditing = false;
      });
      
      // 重新解析消息
      final messages = _contentParser.parseSharedContent(updatedContent);
      setState(() {
        _messages = messages;
      });
      
      print('✅ 内容保存完成');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    } catch (e, stackTrace) {
      print('❌ 保存失败: $e');
      print('❌ 错误堆栈: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }
  
  Future<void> _summarizeToJira() async {
    if (_sharedContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容尚未加载完成')),
      );
      return;
    }
    
    // TODO: 实现总结并发布到 Jira 的功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('总结并发布到 Jira 功能开发中...')),
    );
  }
  
  Future<void> _loadShareContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      print('🔄 开始加载分享内容: ${widget.history.id}');
      print('🔄 目录路径: ${widget.history.directoryPath}');
      print('🔄 是否有原始内容: ${widget.history.originalContent != null}');
      
      // 优先使用原始内容（新分享的内容）
      if (widget.history.originalContent != null) {
        print('🔄 使用原始内容加载');
        final messages = _contentParser.parseSharedContent(widget.history.originalContent!);
        
        setState(() {
          _sharedContent = widget.history.originalContent;
          _messages = messages;
          _isLoading = false;
        });
        
        // 初始化文本编辑器内容
        _initializeTextContent();
        print('✅ 原始内容加载完成，消息数量: ${_messages.length}');
        return;
      }
      
      // 从本地文件加载（历史记录）
      print('🔄 从本地文件加载内容');
      final contentFile = File('${widget.history.directoryPath}/content.json');
      
      if (!await contentFile.exists()) {
        print('❌ 内容文件不存在: ${contentFile.path}');
        setState(() {
          _error = '内容文件不存在: ${contentFile.path}';
          _isLoading = false;
        });
        return;
      }
      
      final contentJson = await contentFile.readAsString();
      final contentData = jsonDecode(contentJson) as Map<String, dynamic>;
      print('🔄 解析内容文件成功');
      
      // 重建 SharedImage 列表
      final List<SharedImage> images = [];
      if (contentData['images'] != null) {
        for (final imageData in contentData['images'] as List) {
          final imageMap = imageData as Map<String, dynamic>;
          images.add(SharedImage(
            uri: imageMap['uri'] as String? ?? '',
            localPath: imageMap['localPath'] as String? ?? '',
            fileName: imageMap['fileName'] as String?,
            fileSize: imageMap['fileSize'] as int?,
          ));
        }
      }
      
      // 重建 SharedContent 对象
      final content = SharedContent(
        id: contentData['id'] as String? ?? widget.history.id,
        text: contentData['text'] as String?,
        images: images,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          contentData['receivedAt'] as int? ?? widget.history.timestamp.millisecondsSinceEpoch
        ),
        sourceApp: contentData['sourceApp'] as String? ?? widget.history.sourceApp,
        localDirectory: contentData['localDirectory'] as String? ?? path.basename(widget.history.directoryPath),
      );
      
      final messages = _contentParser.parseSharedContent(content);
      
      setState(() {
        _sharedContent = content;
        _messages = messages;
        _isLoading = false;
      });
      
      // 初始化文本编辑器内容
      _initializeTextContent();
      print('✅ 本地内容加载完成，消息数量: ${_messages.length}');
      
    } catch (e, stackTrace) {
      print('❌ 加载内容失败: $e');
      print('❌ 错误堆栈: $stackTrace');
      setState(() {
        _error = '加载内容失败: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.history.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _hasChanges ? _saveContent : null,
              icon: Icon(
                Icons.save,
                color: _hasChanges ? Colors.blue : Colors.grey,
              ),
              tooltip: '保存',
            ),
          IconButton(
            onPressed: _toggleEdit,
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.black),
            tooltip: _isEditing ? '取消编辑' : '编辑',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: _handleMenuAction,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'summarize_to_jira',
                child: Row(
                  children: [
                    Icon(Icons.summarize, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('总结并发布到 Jira'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            
            // 内容展示区域（参照播放器的波形区域）
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadShareContent,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                      : _buildContentView(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContentView() {
    if (_messages.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                '暂无内容',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _isEditing ? _buildEditView() : _buildDisplayView(),
      ),
    );
  }
  
  Widget _buildDisplayView() {
    // 直接显示文本内容，不使用聊天对话形式
    final textContent = _messages
        .where((msg) => msg.type == ChatMessageType.text)
        .map((msg) => msg.content)
        .join('\n\n');
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: textContent.isEmpty
          ? const Center(
              child: Text(
                '暂无文本内容',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: SelectableText(
                  textContent,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildEditView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: TextField(
          controller: _textController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          onChanged: (value) {
            _checkForChanges();
            setState(() {});
          },
          decoration: const InputDecoration(
            hintText: '在此编辑分享内容...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
  

}