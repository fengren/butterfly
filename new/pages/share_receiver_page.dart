import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/shared_content.dart';
import '../models/share_content.dart';
import '../models/chat_message.dart';
import '../services/share_receiver_service.dart';
import '../services/local_storage_service.dart';
import '../services/unified_history_service.dart';
import '../services/content_parser.dart';
import '../widgets/chat_display_widget.dart';
import '../widgets/share_history_list_widget.dart';
import '../widgets/unified_history_list_widget.dart';
import 'debug_console_page.dart';
import 'debug_navigation_page.dart';
import 'share_detail_page.dart';

/// 分享接收主页面
class ShareReceiverPage extends StatefulWidget {
  const ShareReceiverPage({super.key});
  
  @override
  State<ShareReceiverPage> createState() => _ShareReceiverPageState();
}

class _ShareReceiverPageState extends State<ShareReceiverPage> {
  final ShareReceiverService _shareService = ShareReceiverServiceImpl();
  final LocalStorageService _storageService = LocalStorageServiceImpl();
  final UnifiedHistoryService _unifiedHistoryService = UnifiedHistoryServiceImpl();
  final ContentParser _contentParser = ContentParserImpl();
  
  final ShareHistoryListController _historyController = ShareHistoryListController();
  
  SharedContent? _currentSharedContent;
  List<ChatMessage> _currentMessages = [];
  bool _isProcessingShare = false;
  String? _shareError;
  
  // 调试日志
  final List<String> _debugLogs = [];
  bool _showDebugLogs = false;
  
  @override
  void initState() {
    super.initState();
    _initializeShareReceiver();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _debugLogs.add('[$timestamp] $message');
      // 保持最新的50条日志
      if (_debugLogs.length > 50) {
        _debugLogs.removeAt(0);
      }
    });
    print('ShareReceiver: $message'); // 同时输出到控制台
  }

  Future<void> _initializeShareReceiver() async {
    _addDebugLog('开始初始化分享接收器');
    
    try {
      // 初始化存储服务
      _addDebugLog('初始化存储服务...');
      await _storageService.initialize();
      _addDebugLog('存储服务初始化完成');
      
      // 初始化统一历史服务
      _addDebugLog('初始化统一历史服务...');
      await _unifiedHistoryService.initialize();
      _addDebugLog('统一历史服务初始化完成');
      
      // 初始化分享接收服务
      _addDebugLog('初始化分享接收服务...');
      await _shareService.initialize();
      _addDebugLog('分享接收服务初始化完成');
      
      // 监听分享数据流
      _addDebugLog('开始监听分享数据流...');
      _shareService.sharedContentStream.listen(
        (sharedContent) {
          _addDebugLog('收到分享内容: 文本=${sharedContent.text?.length ?? 0}字符, 图片=${sharedContent.images.length}张');
          _handleSharedContent(sharedContent);
        },
        onError: (error) {
          _addDebugLog('分享数据流错误: $error');
          setState(() {
            _shareError = '接收分享数据失败: $error';
          });
        },
      );
      _addDebugLog('分享数据流监听已启动');
      
      // 检查初始分享数据
      _addDebugLog('检查初始分享数据...');
      final initialContent = await _shareService.getInitialSharedContent();
      if (initialContent != null) {
        _addDebugLog('发现初始分享数据');
        _handleSharedContent(initialContent);
      } else {
        _addDebugLog('未发现初始分享数据');
      }
      
      _addDebugLog('分享接收器初始化完成');
    } catch (e) {
      _addDebugLog('初始化失败: $e');
      setState(() {
        _shareError = '初始化失败: $e';
      });
    }
  }
  
  Future<void> _handleSharedContent(SharedContent content) async {
    _addDebugLog('开始处理分享内容: ID=${content.id}');
    
    setState(() {
      _isProcessingShare = true;
      _shareError = null;
    });
    
    try {
      _addDebugLog('分享内容详情: 文本="${content.text ?? 'null'}", 图片数量=${content.images.length}');
      
      // 保存分享内容到本地存储
      _addDebugLog('保存分享内容到本地存储...');
      await _storageService.saveSharedContent(content);
      _addDebugLog('分享内容保存完成');
      
      // 创建 ShareContent 对象并添加到统一历史
      _addDebugLog('添加到统一历史记录...');
      final documentsDir = await getApplicationDocumentsDirectory();
      final fullDirectoryPath = path.join(documentsDir.path, 'shared_content', content.localDirectory);
      
      final shareContent = ShareContent(
        id: content.id,
        title: _contentParser.generateHistoryTitle(content),
        timestamp: content.receivedAt,
        messageCount: content.text != null ? 1 : 0,
        imageCount: content.images.length,
        sourceApp: content.sourceApp ?? '未知应用',
        directoryPath: fullDirectoryPath,
        originalContent: content,
      );
      
      await _unifiedHistoryService.addShareHistory(shareContent);
      _addDebugLog('统一历史记录添加完成');
      
      // 创建历史记录对象用于跳转（保持向后兼容）
      final history = ShareHistory(
        id: content.id,
        title: _contentParser.generateHistoryTitle(content),
        createdAt: content.receivedAt,
        directoryPath: fullDirectoryPath,
        messageCount: content.text != null ? 1 : 0,
        imageCount: content.images.length,
        sourceApp: content.sourceApp ?? '未知应用',
      );
       
       // 直接跳转到编辑模式
       _addDebugLog('跳转到分享详情编辑页面...');
       if (mounted) {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => ShareDetailPage(
               history: history,
             ),
           ),
         );
       }
      
      // 解析为聊天消息
      _addDebugLog('解析分享内容为聊天消息...');
      final messages = _contentParser.parseSharedContent(content);
      _addDebugLog('解析完成，生成${messages.length}条消息');
      
      setState(() {
        _currentSharedContent = content;
        _currentMessages = messages;
        _isProcessingShare = false;
      });
      
      _addDebugLog('分享内容处理完成，已切换到聊天页面');
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功接收分享内容，共${messages.length}条消息'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _addDebugLog('处理分享内容失败: $e');
      setState(() {
        _shareError = '处理分享内容失败: $e';
        _isProcessingShare = false;
      });
    }
  }
  

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '分享记录',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // 调试日志开关
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _showDebugLogs ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                _showDebugLogs ? Icons.visibility : Icons.visibility_off,
                color: _showDebugLogs ? Colors.blue : Colors.grey[600],
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _showDebugLogs = !_showDebugLogs;
                });
              },
              tooltip: _showDebugLogs ? '隐藏调试日志' : '显示调试日志',
            ),
          ),
          // 调试导航入口
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.navigation,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugNavigationPage(),
                  ),
                );
              },
              tooltip: '调试导航',
            ),
          ),
          // 调试控制台入口
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.terminal,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugConsolePage(),
                  ),
                );
              },
              tooltip: '调试控制台',
            ),
          ),
        ],

      ),
      body: Column(
        children: [
          // 调试日志区域
          if (_showDebugLogs) _buildDebugLogSection(),
          // 主要内容区域
          Expanded(
            child: _buildHistoryTab(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatTab() {
    if (_isProcessingShare) {
      return Container(
        color: Colors.grey[50],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在处理分享内容...'),
            ],
          ),
        ),
      );
    }
    
    if (_shareError != null) {
      return Container(
        color: Colors.grey[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _shareError!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _shareError = null;
                  });
                  _initializeShareReceiver();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_currentMessages.isEmpty) {
      return Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            if (_showDebugLogs) _buildDebugLogSection(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.share_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '等待分享内容',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '从其他应用（如微信）分享聊天记录到此应用',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          if (_showDebugLogs) _buildDebugLogSection(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ChatDisplayWidget(
                  messages: _currentMessages,
                  title: _currentSharedContent != null 
                      ? _contentParser.generateHistoryTitle(_currentSharedContent!)
                      : null,
                ),
              ),
            ),
          ),
          if (_currentSharedContent != null) _buildSaveButton(),
        ],
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.blue[500]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saveCurrentContent,
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.save_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '保存到历史记录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentContent() async {
    if (_currentSharedContent == null) return;
    
    try {
      print('手动保存分享内容到历史记录');
      await _storageService.saveSharedContent(_currentSharedContent!);
      
      // 刷新历史记录列表
      _historyController.refreshHistories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab() {
    return Container(
      color: Colors.grey[50],
      child: UnifiedHistoryListWidget(
        onHistoryDelete: (history) {
          // 如果删除的是当前显示的内容，清空聊天显示
          if (history is ShareContent && _currentSharedContent?.id == history.id) {
            setState(() {
              _currentSharedContent = null;
              _currentMessages = [];
            });
          }
        },
        onHistoryTap: (history) {
           // 处理历史记录点击事件
           if (history is ShareContent && history.originalContent != null) {
             setState(() {
               _currentSharedContent = history.originalContent;
               _currentMessages = _contentParser.parseSharedContent(history.originalContent!);
             });
           }
         },
      ),
    );
  }

  Widget _buildDebugLogSection() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.terminal,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '调试日志',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: Colors.white,
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() {
                        _debugLogs.clear();
                      });
                    },
                    tooltip: '清空日志',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                itemCount: _debugLogs.length,
                itemBuilder: (context, index) {
                  final log = _debugLogs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      _debugLogs[index],
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}