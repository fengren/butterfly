import 'package:flutter/material.dart';
import 'card_theme.dart' as custom_theme;

/// 卡片进入动画组件
class CardEnterAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  final bool enabled;
  
  const CardEnterAnimation({
    Key? key,
    required this.child,
    this.delay = 0,
    this.enabled = true,
  }) : super(key: key);
  
  @override
  State<CardEnterAnimation> createState() => _CardEnterAnimationState();
}

class _CardEnterAnimationState extends State<CardEnterAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: custom_theme.CardAnimations.enterDuration,
      vsync: this,
    );
    
    // 淡入动画
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));
    
    // 滑动动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: custom_theme.CardAnimations.enterCurve),
    ));
    
    // 缩放动画
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));
    
    if (widget.enabled) {
      // 延迟启动动画
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.value = 1.0;
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// 卡片交互动画组件
class CardInteractiveAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHover;
  
  const CardInteractiveAnimation({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHover = true,
  }) : super(key: key);
  
  @override
  State<CardInteractiveAnimation> createState() => _CardInteractiveAnimationState();
}

class _CardInteractiveAnimationState extends State<CardInteractiveAnimation>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _tapAnimation;
  
  bool _isHovered = false;
  bool _isTapped = false;
  
  @override
  void initState() {
    super.initState();
    
    _hoverController = AnimationController(
      duration: custom_theme.CardAnimations.hoverDuration,
      vsync: this,
    );
    
    _tapController = AnimationController(
      duration: custom_theme.CardAnimations.tapDuration,
      vsync: this,
    );
    
    _hoverAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: custom_theme.CardAnimations.hoverCurve,
    ));
    
    _tapAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _tapController,
      curve: custom_theme.CardAnimations.tapCurve,
    ));
  }
  
  @override
  void dispose() {
    _hoverController.dispose();
    _tapController.dispose();
    super.dispose();
  }
  
  void _handleHoverEnter() {
    if (!widget.enableHover) return;
    setState(() {
      _isHovered = true;
    });
    _hoverController.forward();
  }
  
  void _handleHoverExit() {
    if (!widget.enableHover) return;
    setState(() {
      _isHovered = false;
    });
    _hoverController.reverse();
  }
  
  void _handleTapDown() {
    setState(() {
      _isTapped = true;
    });
    _tapController.forward();
  }
  
  void _handleTapUp() {
    setState(() {
      _isTapped = false;
    });
    _tapController.reverse();
  }
  
  void _handleTapCancel() {
    setState(() {
      _isTapped = false;
    });
    _tapController.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _handleTapDown(),
        onTapUp: (_) => _handleTapUp(),
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverController, _tapController]),
          builder: (context, child) {
            final scale = _hoverAnimation.value * _tapAnimation.value;
            return Transform.scale(
              scale: scale,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}

/// 卡片阴影动画组件
class CardShadowAnimation extends StatefulWidget {
  final Widget child;
  final bool isHovered;
  final bool isTapped;
  
  const CardShadowAnimation({
    Key? key,
    required this.child,
    this.isHovered = false,
    this.isTapped = false,
  }) : super(key: key);
  
  @override
  State<CardShadowAnimation> createState() => _CardShadowAnimationState();
}

class _CardShadowAnimationState extends State<CardShadowAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shadowAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: custom_theme.CardAnimations.hoverDuration,
      vsync: this,
    );
    
    _shadowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: custom_theme.CardAnimations.hoverCurve,
    ));
  }
  
  @override
  void didUpdateWidget(CardShadowAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isHovered != oldWidget.isHovered) {
      if (widget.isHovered) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shadowAnimation,
      builder: (context, child) {
        final normalShadow = custom_theme.CardTheme.cardShadow;
        final hoverShadow = custom_theme.CardTheme.cardHoverShadow;
        
        final interpolatedShadow = normalShadow.map((shadow) {
          final hoverIndex = normalShadow.indexOf(shadow);
          if (hoverIndex < hoverShadow.length) {
            final hoverShadowItem = hoverShadow[hoverIndex];
            return BoxShadow(
              color: Color.lerp(
                shadow.color,
                hoverShadowItem.color,
                _shadowAnimation.value,
              )!,
              blurRadius: shadow.blurRadius +
                  (hoverShadowItem.blurRadius - shadow.blurRadius) *
                      _shadowAnimation.value,
              offset: Offset.lerp(
                shadow.offset,
                hoverShadowItem.offset,
                _shadowAnimation.value,
              )!,
            );
          }
          return shadow;
        }).toList();
        
        return Container(
          decoration: BoxDecoration(
            boxShadow: interpolatedShadow,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 涟漪效果组件
class CardRippleEffect extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? rippleColor;
  
  const CardRippleEffect({
    Key? key,
    required this.child,
    this.onTap,
    this.rippleColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(custom_theme.CardTheme.cardRadius),
        splashColor: rippleColor?.withOpacity(0.1) ??
            Theme.of(context).primaryColor.withOpacity(0.1),
        highlightColor: rippleColor?.withOpacity(0.05) ??
            Theme.of(context).primaryColor.withOpacity(0.05),
        child: child,
      ),
    );
  }
}