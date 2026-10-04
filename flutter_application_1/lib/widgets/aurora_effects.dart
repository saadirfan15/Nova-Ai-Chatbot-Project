import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// True when the user asked the OS to reduce motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Two soft glows (cyan and lime) that slowly drift behind the content.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_drift.value);
              return LayoutBuilder(
                builder: (context, box) {
                  final size = math.max(box.maxWidth, box.maxHeight);
                  return Stack(
                    children: [
                      _Glow(
                        color: AppTheme.glowCyan,
                        opacity: 0.30,
                        diameter: size * 0.55,
                        left: box.maxWidth * (0.28 + 0.06 * t),
                        top: -size * 0.16 + 50 * t,
                      ),
                      _Glow(
                        color: AppTheme.glowLime,
                        opacity: 0.22,
                        diameter: size * 0.6,
                        left: box.maxWidth * (0.72 - 0.05 * t),
                        top: box.maxHeight * (0.62 - 0.06 * t),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double opacity;
  final double diameter;
  final double left;
  final double top;
  const _Glow({
    required this.color,
    required this.opacity,
    required this.diameter,
    required this.left,
    required this.top,
  });

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    width: diameter,
    height: diameter,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The Nova mark: gradient tile, "N" stroke and a twinkling star.
class NovaLogo extends StatefulWidget {
  final double size;
  final bool glow;
  final bool showStar;

  /// Twinkles faster while Nova is working on a reply.
  final bool busy;
  const NovaLogo({
    super.key,
    this.size = 32,
    this.glow = false,
    this.showStar = true,
    this.busy = false,
  });

  @override
  State<NovaLogo> createState() => _NovaLogoState();
}

class _NovaLogoState extends State<NovaLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: _period,
  );

  Duration get _period => Duration(milliseconds: widget.busy ? 1100 : 2800);

  void _sync() {
    if (!widget.showStar || reduceMotion(context)) {
      _twinkle.stop();
    } else {
      _twinkle
        ..duration = _period
        ..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NovaLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        oldWidget.showStar != widget.showStar) {
      _sync();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size * 0.3;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: AppTheme.logoGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: widget.glow
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.45),
                  blurRadius: widget.size,
                  offset: Offset(0, widget.size * 0.25),
                ),
              ]
            : null,
      ),
      child: AnimatedBuilder(
        animation: _twinkle,
        builder: (context, _) => CustomPaint(
          painter: _NovaMarkPainter(
            twinkle: math.sin(_twinkle.value * math.pi),
            showStar: widget.showStar,
          ),
        ),
      ),
    );
  }
}

class _NovaMarkPainter extends CustomPainter {
  final double twinkle;
  final bool showStar;
  _NovaMarkPainter({required this.twinkle, required this.showStar});

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 32x32 grid, like the SVG mark in the design.
    final s = size.width / 32;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(10 * s, 22 * s)
        ..lineTo(10 * s, 10.5 * s)
        ..lineTo(21 * s, 21.5 * s)
        ..lineTo(21 * s, 10 * s),
      stroke,
    );

    if (!showStar) return;
    canvas.save();
    canvas.translate(25 * s, 8.7 * s);
    canvas.rotate(twinkle * math.pi / 4);
    canvas.scale(1 + 0.4 * twinkle);
    final r = 4.2 * s;
    final w = 1.1 * s;
    canvas.drawPath(
      Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(w * 0.3, -w * 0.3, r, 0)
        ..quadraticBezierTo(w * 0.3, w * 0.3, 0, r)
        ..quadraticBezierTo(-w * 0.3, w * 0.3, -r, 0)
        ..quadraticBezierTo(-w * 0.3, -w * 0.3, 0, -r)
        ..close(),
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NovaMarkPainter old) =>
      old.twinkle != twinkle || old.showStar != showStar;
}

/// Fades and slides its child up once, after an optional delay.
class RiseIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
  });

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(0.2, 0.8, 0.2, 1),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(
        offset: Offset(0, widget.offset * (1 - _curve.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Gently bobs its child up and down.
class Floating extends StatefulWidget {
  final Widget child;
  const Floating({super.key, required this.child});

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -8 * Curves.easeInOut.transform(_controller.value)),
      child: child,
    ),
    child: widget.child,
  );
}

/// Lifts its child a few pixels while hovered (desktop / web).
class HoverLift extends StatefulWidget {
  final Widget child;
  const HoverLift({super.key, required this.child});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: Offset(0, _hovered && !reduceMotion(context) ? -0.04 : 0),
      child: widget.child,
    ),
  );
}

/// Text with a soft highlight sweeping across it ("Thinking…").
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const ShimmerText(this.text, {super.key, required this.style});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style.color ?? AppTheme.muted;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = -3 + 4 * _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x, 0),
            end: Alignment(x + 2, 0),
            colors: [base, AppTheme.accentText, base],
            stops: const [0.2, 0.5, 0.8],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style),
    );
  }
}
