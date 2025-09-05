import 'package:flutter/material.dart';
import '../models/unified_history.dart';
import '../models/content_type.dart';
import '../models/audio_content.dart';
import '../models/share_content.dart';

/// 统一内容列表组件
/// 用于展示录音和分享记录的统一列表
class UnifiedContentList extends StatelessWidget {
  final List<UnifiedHistory> items;
  final ContentType? filterType;
  final Function(UnifiedHistory) onItemTap;
  final Function(UnifiedHistory)? onItemLongPress;
  final Function(UnifiedHistory)? onMorePressed;
  final bool isLoading;
  final String? emptyMessage;
  
  const UnifiedContentList({
    Key? key,
    required this.items,
    this.filterType,
    required this.onItemTap,
    this.onItemLongPress,
    this.onMorePressed,
    this.isLoading = false,
    this.emptyMessage,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final filteredItems = _getFilteredItems();
    
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? _getDefaultEmptyMessage(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
               ),
             ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredItems.length,
      itemBuilder: (context, index) => _buildContentItem(
        context,
        filteredItems[index],
        index,
      ),
    );
  }
  
  /// 获取过滤后的内容列表
  List<UnifiedHistory> _getFilteredItems() {
    if (filterType == null) {
      return items;
    }
    
    return items.where((item) => item.contentType == filterType).toList();
  }
  
  /// 构建内容项
  Widget _buildContentItem(BuildContext context, UnifiedHistory item, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _buildLeadingIcon(item),
        title: _buildTitle(item),
        subtitle: _buildSubtitle(item),
        trailing: _buildTrailing(item),
        onTap: () => onItemTap(item),
        onLongPress: onItemLongPress != null ? () => onItemLongPress!(item) : null,
      ),
    );
  }
  
  /// 构建前导图标
  Widget _buildLeadingIcon(UnifiedHistory item) {
    switch (item.contentType) {
      case ContentType.audio:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
            size: 24,
          ),
        );
      case ContentType.share:
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.share,
            color: Colors.white,
            size: 24,
          ),
        );
    }
  }
  
  /// 构建标题
  Widget _buildTitle(UnifiedHistory item) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (item is AudioContent && item.tags.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getTagColor(item.primaryTag),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.primaryTag,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
  
  /// 构建副标题
  Widget _buildSubtitle(UnifiedHistory item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _formatTimestamp(item.timestamp),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _getContentInfo(item),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            // 为分享内容添加应用来源显示
            if (item.contentType == ContentType.share && item is ShareContent) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getSourceAppColor(item.sourceApp),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSourceAppIcon(item.sourceApp),
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.sourceApp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (item.description != null) ..[
          const SizedBox(height: 2),
          Text(
            item.description!,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
  
  /// 构建尾部操作
  Widget? _buildTrailing(UnifiedHistory item) {
    if (onMorePressed == null) {
      return null;
    }
    
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () => onMorePressed!(item),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
  
  /// 获取内容信息文本
  String _getContentInfo(UnifiedHistory item) {
    switch (item.contentType) {
      case ContentType.audio:
        if (item is AudioContent) {
          return '${item.formattedDuration} • ${item.formattedFileSize}';
        }
        return '录音文件';
      case ContentType.share:
        final messageCount = item.metadata['messageCount'] as int? ?? 0;
        final imageCount = item.metadata['imageCount'] as int? ?? 0;
        final parts = <String>[];
        if (messageCount > 0) parts.add('$messageCount条消息');
        if (imageCount > 0) parts.add('$imageCount张图片');
        return parts.isNotEmpty ? parts.join(' • ') : '分享内容';
    }
  }
  
  /// 格式化时间戳
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    }
  }
  
  /// 获取标签颜色
  Color _getTagColor(String tag) {
    switch (tag.toLowerCase()) {
      case '重要':
        return Colors.red;
      case '工作':
        return Colors.blue;
      case '学习':
        return Colors.green;
      case '生活':
        return Colors.orange;
      case '会议':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  /// 获取空状态图标
  IconData _getEmptyIcon() {
    if (filterType == ContentType.audio) {
      return Icons.mic_off;
    } else if (filterType == ContentType.share) {
      return Icons.share_outlined;
    } else {
      return Icons.inbox_outlined;
    }
  }
  
  /// 获取默认空状态消息
  String _getDefaultEmptyMessage() {
    if (filterType == ContentType.audio) {
      return '还没有录音记录\n点击下方按钮开始录音';
    } else if (filterType == ContentType.share) {
      return '还没有分享记录\n从其他应用分享内容到这里';
    } else {
      return '还没有任何记录\n开始录音或分享内容';
    }
  }
  
  /// 获取应用来源颜色
  Color _getSourceAppColor(String sourceApp) {
    switch (sourceApp) {
      case '微信':
        return const Color(0xFF07C160);
      case 'QQ':
        return const Color(0xFF12B7F5);
      case '微博':
        return const Color(0xFFE6162D);
      case 'Chrome':
        return const Color(0xFF4285F4);
      case '抖音':
        return const Color(0xFF000000);
      case '知乎':
        return const Color(0xFF0084FF);
      case '淘宝':
        return const Color(0xFFFF6A00);
      case '京东':
        return const Color(0xFFE3101E);
      default:
        return Colors.grey;
    }
  }
  
  /// 获取应用来源图标
  IconData _getSourceAppIcon(String sourceApp) {
    switch (sourceApp) {
      case '微信':
      case 'QQ':
        return Icons.chat;
      case '微博':
        return Icons.public;
      case 'Chrome':
      case 'UC浏览器':
      case 'QQ浏览器':
        return Icons.web;
      case '抖音':
        return Icons.video_library;
      case '知乎':
        return Icons.question_answer;
      case '淘宝':
      case '天猫':
      case '京东':
        return Icons.shopping_cart;
      default:
        return Icons.apps;
    }
  }
}