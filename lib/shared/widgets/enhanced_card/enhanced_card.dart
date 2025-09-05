import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/unified_history.dart';
import '../../models/content_type.dart';
import 'card_theme.dart' as custom_theme;
import 'card_animations.dart';

/// UnifiedHistory扩展方法
extension UnifiedHistoryExtension on UnifiedHistory {
  String get type => contentType.toString().split('.').last;
  bool get isRead => metadata['isRead'] ?? false;
  List<String> get tags => (metadata['tags'] as List<dynamic>?)?.cast<String>() ?? [];
  String get content => description ?? '';
  ShareSource? get shareSource {
    final sourceData = metadata['shareSource'] as Map<String, dynamic>?;
    if (sourceData != null) {
      return ShareSource(
        appName: sourceData['appName'] ?? 'Unknown',
        packageName: sourceData['packageName'] ?? '',
      );
    }
    return null;
  }
}

/// 分享来源模型
class ShareSource {
  final String appName;
  final String packageName;
  
  const ShareSource({
    required this.appName,
    required this.packageName,
  });
}

/// 增强版卡片组件
class EnhancedCard extends StatefulWidget {
  final UnifiedHistory item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showAnimation;
  final int animationDelay;
  final bool enableHover;
  
  const EnhancedCard({
    Key? key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.showAnimation = true,
    this.animationDelay = 0,
    this.enableHover = true,
  }) : super(key: key);
  
  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isTapped = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // 脉冲动画控制器
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // 如果有未读消息，启动脉冲动画
    if (!widget.item.isRead) {
      _pulseController.repeat(reverse: true);
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return CardEnterAnimation(
      delay: widget.animationDelay,
      enabled: widget.showAnimation,
      child: Container(
        margin: custom_theme.CardTheme.cardMargin,
        child: CardShadowAnimation(
          isHovered: _isHovered,
          isTapped: _isTapped,
          child: MouseRegion(
            onEnter: (_) => _handleHoverEnter(),
            onExit: (_) => _handleHoverExit(),
            child: GestureDetector(
              onTap: _handleTap,
              onLongPress: _handleLongPress,
              onTapDown: (_) => _handleTapDown(),
              onTapUp: (_) => _handleTapUp(),
              onTapCancel: _handleTapCancel,
              child: AnimatedScale(
                scale: _getScale(),
                duration: custom_theme.CardAnimations.hoverDuration,
                curve: custom_theme.CardAnimations.hoverCurve,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(custom_theme.CardTheme.cardRadius),
                    boxShadow: _getShadow(),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(custom_theme.CardTheme.cardRadius),
                    child: InkWell(
                      onTap: null, // 由外层GestureDetector处理
                      borderRadius: BorderRadius.circular(custom_theme.CardTheme.cardRadius),
                      splashColor: _getRippleColor().withOpacity(0.1),
                      highlightColor: _getRippleColor().withOpacity(0.05),
                      child: Padding(
                        padding: custom_theme.CardTheme.cardPadding,
                        child: _buildCardContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _handleHoverEnter() {
    if (!widget.enableHover) return;
    setState(() {
      _isHovered = true;
    });
  }
  
  void _handleHoverExit() {
    if (!widget.enableHover) return;
    setState(() {
      _isHovered = false;
    });
  }
  
  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }
  
  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }
  
  void _handleTapDown() {
    setState(() {
      _isTapped = true;
    });
  }
  
  void _handleTapUp() {
    setState(() {
      _isTapped = false;
    });
  }
  
  void _handleTapCancel() {
    setState(() {
      _isTapped = false;
    });
  }
  
  double _getScale() {
    // 根据用户反馈：减少动画效果幅度
    if (_isTapped) return 0.99;
    if (_isHovered) return 1.01;
    return 1.0;
  }
  
  List<BoxShadow> _getShadow() {
    if (_isHovered) {
      return custom_theme.CardTheme.cardHoverShadow;
    }
    return custom_theme.CardTheme.cardShadow;
  }
  
  Color _getRippleColor() {
    final gradientColors = custom_theme.CardColors.getGradientByType(widget.item.type);
    return gradientColors.first;
  }
  
  Widget _buildCardContent() {
    return Row(
      children: [
        _buildLeadingIcon(),
        const SizedBox(width: 16),
        Expanded(
          child: _buildContentColumn(),
        ),
        _buildTrailingActions(),
      ],
    );
  }
  
  Widget _buildLeadingIcon() {
    final gradientColors = custom_theme.CardColors.getGradientByType(widget.item.type);
    final iconData = _getIconData();
    
    return Container(
      width: custom_theme.CardTheme.iconSize,
      height: custom_theme.CardTheme.iconSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(custom_theme.CardTheme.iconRadius),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedRotation(
        turns: _isHovered ? 0.05 : 0.0,
        duration: custom_theme.CardAnimations.hoverDuration,
        curve: custom_theme.CardAnimations.hoverCurve,
        child: Icon(
          iconData,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
  
  IconData _getIconData() {
    switch (widget.item.type.toLowerCase()) {
      case 'audio':
      case '录音':
        return Icons.mic_rounded;
      case 'share':
      case '分享':
        return Icons.share_rounded;
      case 'text':
      case '文本':
        return Icons.text_snippet_rounded;
      case 'image':
      case '图片':
        return Icons.image_rounded;
      case 'video':
      case '视频':
        return Icons.videocam_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
  
  Widget _buildContentColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitleRow(),
        // 根据用户反馈：分享卡片也显示summary，保持高度一致
        const SizedBox(height: 4),
        _buildSubtitle(),
        const SizedBox(height: 8),
        _buildMetaInfo(),
      ],
    );
  }
  
  Widget _buildTitleRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.item.title,
            style: custom_theme.CardTheme.titleStyle.copyWith(
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!widget.item.isRead) ...[
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: custom_theme.CardColors.unreadIndicator.withOpacity(
                      0.8 + 0.2 * (_pulseAnimation.value - 1.0),
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: custom_theme.CardColors.unreadIndicator.withOpacity(0.4),
                        blurRadius: 4.0 + 2.0 * (_pulseAnimation.value - 1.0),
                        spreadRadius: 1.0 + 0.5 * (_pulseAnimation.value - 1.0),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
  
  Widget _buildSubtitle() {
    // 根据用户反馈：录音显示时长，分享显示summary
    if (widget.item.contentType == ContentType.audio) {
      return Text(
        '录音 • ${_formatDuration()}',
        style: custom_theme.CardTheme.subtitleStyle.copyWith(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      // 分享卡片显示description内容
       final summary = widget.item.description?.isNotEmpty == true 
           ? widget.item.description! 
           : widget.item.title;
      
      return Text(
        summary,
        style: custom_theme.CardTheme.subtitleStyle.copyWith(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
  }
  
  Widget _buildMetaInfo() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _buildTimeChip(),
        if (widget.item.tags.isNotEmpty) ...
          widget.item.tags.take(2).map(_buildTagChip),
        // 根据用户反馈：移除分享应用来源显示
      ],
    );
  }
  
  Widget _buildTimeChip() {
    final timeText = _formatTime(widget.item.timestamp);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        timeText,
        style: custom_theme.CardTheme.metaStyle.copyWith(
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
  
  Widget _buildTagChip(String tag) {
    final tagColor = custom_theme.CardColors.getTagColor(tag);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tagColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: custom_theme.CardTheme.metaStyle.copyWith(
          color: tagColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildSourceChip() {
    final source = widget.item.shareSource!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: custom_theme.CardColors.shareGradient.first.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: custom_theme.CardColors.shareGradient.first.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.apps_rounded,
            size: 12,
            color: custom_theme.CardColors.shareGradient.first,
          ),
          const SizedBox(width: 4),
          Text(
            source.appName,
            style: custom_theme.CardTheme.metaStyle.copyWith(
              color: custom_theme.CardColors.shareGradient.first,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration() {
    final duration = widget.item.metadata['duration'] as int? ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  Widget _buildTrailingActions() {
    // 根据用户反馈：移除三个点菜单，保留长按操作
    return const SizedBox.shrink();
  }
  
  void _showMoreOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现编辑功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现分享功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('删除'),
              textColor: custom_theme.CardColors.errorColor,
              iconColor: custom_theme.CardColors.errorColor,
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现删除功能
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}