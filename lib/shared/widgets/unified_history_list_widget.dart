import 'package:flutter/material.dart';
import '../models/unified_history.dart';
import '../models/share_content.dart';
import '../models/audio_record.dart';
import '../models/content_type.dart';
import '../services/unified_history_service.dart';

/// 统一历史记录列表组件
class UnifiedHistoryListWidget extends StatefulWidget {
  final Function(UnifiedHistory)? onHistoryDelete;
  final Function(UnifiedHistory)? onHistoryTap;

  const UnifiedHistoryListWidget({
    super.key,
    this.onHistoryDelete,
    this.onHistoryTap,
  });

  @override
  State<UnifiedHistoryListWidget> createState() => _UnifiedHistoryListWidgetState();
}

class _UnifiedHistoryListWidgetState extends State<UnifiedHistoryListWidget> {
  final UnifiedHistoryService _historyService = UnifiedHistoryServiceImpl();
  List<UnifiedHistory> _histories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  Future<void> _loadHistories() async {
    try {
      final histories = await _historyService.getAllHistory();
      setState(() {
        _histories = histories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_histories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无历史记录',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistories,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _histories.length,
        itemBuilder: (context, index) {
          final history = _histories[index];
          return _buildHistoryItem(history);
        },
      ),
    );
  }

  Widget _buildHistoryItem(UnifiedHistory history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildLeadingIcon(history),
        title: Text(
          history.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (history.description?.isNotEmpty == true)
              Text(
                history.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(history.timestamp),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteHistory(history);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          widget.onHistoryTap?.call(history);
        },
      ),
    );
  }

  Widget _buildLeadingIcon(UnifiedHistory history) {
    IconData iconData;
    Color iconColor;

    switch (history.contentType) {
      case ContentType.audio:
        iconData = Icons.mic;
        iconColor = Colors.blue;
        break;
      case ContentType.share:
        iconData = Icons.share;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.help;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Future<void> _deleteHistory(UnifiedHistory history) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${history.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _historyService.deleteHistory(history.id);
        widget.onHistoryDelete?.call(history);
        await _loadHistories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}