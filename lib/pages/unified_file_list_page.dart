import 'package:flutter/material.dart';
import '../shared/models/unified_history.dart';
import '../shared/models/content_type.dart';
import '../shared/models/audio_content.dart';
import '../shared/services/unified_content_service.dart';
import '../shared/widgets/unified_content_list.dart';
import '../audio_player_page.dart';
import '../record_page.dart';
// import '../share_receiver_page.dart'; // TODO: 创建分享页面

/// 统一文件列表页面
/// 整合录音和分享记录的统一界面
class UnifiedFileListPage extends StatefulWidget {
  const UnifiedFileListPage({Key? key}) : super(key: key);
  
  @override
  State<UnifiedFileListPage> createState() => _UnifiedFileListPageState();
}

class _UnifiedFileListPageState extends State<UnifiedFileListPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final UnifiedContentService _contentService = UnifiedContentServiceImpl();
  
  List<UnifiedHistory> _allItems = [];
  List<UnifiedHistory> _audioItems = [];
  List<UnifiedHistory> _shareItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadContent();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// 加载所有内容
  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final allContent = await _contentService.getAllContent();
      final audioContent = await _contentService.getAudioHistory();
      final shareContent = await _contentService.getShareHistory();
      
      setState(() {
        _allItems = allContent;
        _audioItems = audioContent;
        _shareItems = shareContent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载内容失败: $e';
        _isLoading = false;
      });
    }
  }
  
  /// 处理内容项点击
  void _handleItemTap(UnifiedHistory item) {
    switch (item.contentType) {
      case ContentType.audio:
        if (item is AudioContent) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioPlayerPage(
                filePath: item.filePath,
                waveform: item.waveform ?? [],
                displayName: item.title ?? 'Unknown',
              ),
            ),
          ).then((_) => _loadContent());
        }
        break;
      case ContentType.share:
        // 处理分享内容点击
        _showShareContentDetail(item);
        break;
    }
  }
  
  /// 处理内容项长按
  void _handleItemLongPress(UnifiedHistory item) {
    _showItemOptions(item);
  }
  
  /// 处理更多按钮点击
  void _handleMorePressed(UnifiedHistory item) {
    _showItemOptions(item);
  }
  
  /// 显示内容项选项
  void _showItemOptions(UnifiedHistory item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(item);
            },
          ),
          if (item.contentType == ContentType.audio)
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('编辑标签'),
              onTap: () {
                Navigator.pop(context);
                _showEditTagDialog(item as AudioContent);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmDialog(item);
            },
          ),
        ],
      ),
    );
  }
  
  /// 显示分享内容详情
  void _showShareContentDetail(UnifiedHistory item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('分享详情')),
          body: const Center(
            child: Text('分享详情页面开发中'),
          ),
        ),
      ),
    ).then((_) => _loadContent());
  }
  
  /// 显示重命名对话框
  void _showRenameDialog(UnifiedHistory item) {
    final controller = TextEditingController(text: item.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != item.title) {
                try {
                  await _contentService.renameContent(item.id, item.contentType, newName);
                  Navigator.pop(context);
                  _loadContent();
                  _showSnackBar('重命名成功');
                } catch (e) {
                  _showSnackBar('重命名失败: $e');
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示编辑标签对话框
  void _showEditTagDialog(AudioContent item) {
    // 这里可以实现标签编辑功能
    _showSnackBar('标签编辑功能开发中');
  }
  
  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(UnifiedHistory item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${item.title}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _contentService.deleteContent(item.id, item.contentType);
                Navigator.pop(context);
                _loadContent();
                _showSnackBar('删除成功');
              } catch (e) {
                Navigator.pop(context);
                _showSnackBar('删除失败: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  /// 显示提示消息
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  /// 开始录音
  void _startRecording() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordPage(),
      ),
    ).then((_) => _loadContent());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的记录'),
        actions: [
          // 根据用户反馈：移除主题切换，保持亮色模式
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.all_inbox),
              text: '全部 (${_allItems.length})',
            ),
            Tab(
              icon: const Icon(Icons.mic),
              text: '录音 (${_audioItems.length})',
            ),
            Tab(
              icon: const Icon(Icons.share),
              text: '分享 (${_shareItems.length})',
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: _errorMessage != null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: [
                // 全部内容
                RefreshIndicator(
                  onRefresh: _loadContent,
                  child: UnifiedContentList(
                    items: _allItems,
                    onItemTap: _handleItemTap,
                    onItemLongPress: _handleItemLongPress,
                    onMorePressed: _handleMorePressed,
                    isLoading: _isLoading,
                    emptyMessage: '还没有任何记录\n开始录音或分享内容',
                  ),
                ),
                // 录音内容
                RefreshIndicator(
                  onRefresh: _loadContent,
                  child: UnifiedContentList(
                    items: _audioItems,
                    filterType: ContentType.audio,
                    onItemTap: _handleItemTap,
                    onItemLongPress: _handleItemLongPress,
                    onMorePressed: _handleMorePressed,
                    isLoading: _isLoading,
                  ),
                ),
                // 分享内容
                RefreshIndicator(
                  onRefresh: _loadContent,
                  child: UnifiedContentList(
                    items: _shareItems,
                    filterType: ContentType.share,
                    onItemTap: _handleItemTap,
                    onItemLongPress: _handleItemLongPress,
                    onMorePressed: _handleMorePressed,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startRecording,
        child: const Icon(Icons.mic),
        tooltip: '开始录音',
      ),
    );
  }
  
  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadContent,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
  
  /// 构建侧边栏
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.flutter_dash,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Text(
                  'Butterfly',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '录音与分享助手',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upgrade),
            title: const Text('升级到专业版'),
            onTap: () {
              Navigator.pop(context);
              _showSnackBar('升级功能开发中');
            },
          ),
          // 根据用户反馈：移除主题切换，保持亮色模式
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              Navigator.pop(context);
              _showSnackBar('设置功能开发中');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('常见问题'),
            onTap: () {
              Navigator.pop(context);
              _showSnackBar('帮助功能开发中');
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('反馈'),
            onTap: () {
              Navigator.pop(context);
              _showSnackBar('反馈功能开发中');
            },
          ),
        ],
      ),
    );
  }
}