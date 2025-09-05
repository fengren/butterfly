import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../models/shared_content.dart';
import '../models/chat_message.dart';
import '../services/content_parser.dart';
import '../services/local_storage_service.dart';
import '../../lib/shared/widgets/chat_display_widget.dart';

/// 分享记录详细查看页面
/// 参照 butterfly_lib/audio_player_page.dart 的设计风格
class ShareDetailPage extends StatefulWidget {
  final ShareHistory history;
  
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
  bool _isEditing = false;
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
    if (_messages.isNotEmpty) {
      final textContent = _messages
          .where((msg) => msg.type == ChatMessageType.text)
          .map((msg) => msg.content)
          .join('\n\n');
      _textController.text = textContent;
    }
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
    final originalContent = _messages
        .where((msg) => msg.type == ChatMessageType.text)
        .map((msg) => msg.content)
        .join('\n\n');
    _hasChanges = _textController.text != originalContent;
  }
  
  Future<void> _saveContent() async {
    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有需要保存的更改')),
      );
      return;
    }
    
    try {
      // 调用本地存储服务更新内容
      await _localStorageService.updateShareContent(
        widget.history.id,
        _textController.text,
      );
      
      setState(() {
        _hasChanges = false;
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    } catch (e) {
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
      
      // 读取 content.json 文件
      final contentFile = File('${widget.history.directoryPath}/content.json');
      if (await contentFile.exists()) {
        final contentJson = await contentFile.readAsString();
        final contentData = jsonDecode(contentJson) as Map<String, dynamic>;
        
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
          id: contentData['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          text: contentData['text'] as String?,
          images: images,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            contentData['receivedAt'] as int? ?? widget.history.createdAt.millisecondsSinceEpoch
          ),
          sourceApp: contentData['sourceApp'] as String? ?? 'unknown',
          localDirectory: contentData['localDirectory'] as String? ?? widget.history.directoryPath,
        );
        
        final messages = _contentParser.parseSharedContent(content);
        
        setState(() {
          _sharedContent = content;
          _messages = messages;
          _isLoading = false;
        });
        
        // 初始化文本编辑器内容并进入编辑模式
        _initializeTextContent();
        setState(() {
          _isEditing = true;
        });
      } else {
        setState(() {
          _error = '内容文件不存在';
          _isLoading = false;
        });
      }
    } catch (e) {
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