import 'dart:math';
import 'package:flutter/material.dart';

class ChestWidget extends StatefulWidget {
  final Color color;
  final String multiplierLabel;
  final int multiplierValue;
  final bool isSelected;
  final bool isWinner;
  final double openProgress; // 0.0 to 1.0 (controlled by reveal animation)
  final double userBetAmount;
  final String totalBets;
  final bool isHot;
  final String gameStatus; // To trigger animations based on state (BETTING, CALCULATING, etc.)

  const ChestWidget({
    super.key,
    required this.color,
    required this.multiplierLabel,
    required this.multiplierValue,
    required this.isSelected,
    required this.isWinner,
    required this.userBetAmount,
    required this.totalBets,
    required this.isHot,
    required this.gameStatus,
    this.openProgress = 0.0,
  });

  @override
  State<ChestWidget> createState() => _ChestWidgetState();
}

class _ChestWidgetState extends State<ChestWidget> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _glowController;
  late AnimationController _openController;
  late Animation<double> _idleAnimation;
  late Animation<double> _glowAnimation;

  // Particle list for coin explosion
  final List<CoinParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // 1. Idle Floating Animation (Phase 1: every 2 seconds, up/down 5px)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _idleAnimation = Tween<double>(begin: 0.0, end: -5.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    // 2. Glow Pulse Animation (Phase 2: fast glow pulse)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _openController.addListener(() {
      if (_openController.value > 0.1 && _particles.isEmpty && widget.isWinner) {
        _spawnParticles();
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(ChestWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Phase 2: Start Glow Pulse on CALCULATING
    if (widget.gameStatus == "CALCULATING") {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.setValue(0.0);
    }

    // Phase 5 & 6: Trigger lid open & coin particles when winner
    if (widget.openProgress > 0) {
      if (_openController.value != widget.openProgress) {
        _openController.animateTo(widget.openProgress, duration: const Duration(milliseconds: 300));
      }
    } else {
      _openController.reset();
      _particles.clear();
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _glowController.dispose();
    _openController.dispose();
    super.dispose();
  }

  void _spawnParticles() {
    _particles.clear();
    // Spawn 30 to 50 coin particles
    final count = 30 + _random.nextInt(21);
    for (int i = 0; i < count; i++) {
      final double angle = -pi / 6 - _random.nextDouble() * (2 * pi / 3); // upward arc
      final double speed = 3.0 + _random.nextDouble() * 5.0;
      _particles.add(
        CoinParticle(
          x: 0,
          y: -10,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.5,
          scale: 0.6 + _random.nextDouble() * 0.6,
        ),
      );
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.25; // gravity
      p.rotation += p.rotationSpeed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium = widget.multiplierValue > 5;
    final double baseWidth = isPremium ? 78.0 : 68.0;
    final double baseHeight = isPremium ? 74.0 : 64.0;
    final isCash = widget.totalBets.contains("💵") || widget.totalBets.contains("Cash");

    if (_particles.isNotEmpty) {
      _updateParticles();
    }

    // Phase 3 & 4: Winner scale up and dimming others
    // If there is a winner, darken non-winners. Scale winner by 1.2
    final isAnyWinnerRevealed = widget.gameStatus == "REVEALING" || widget.gameStatus == "FINALIZING";
    final double targetOpacity = (isAnyWinnerRevealed && !widget.isWinner) ? 0.35 : 1.0;
    
    // Scale transition for winner (1.0 -> 1.2)
    final double targetScale = (isAnyWinnerRevealed && widget.isWinner) ? 1.2 : 1.0;

    return Opacity(
      opacity: targetOpacity,
      child: AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: _idleAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _idleAnimation.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Total Bets
                  if (widget.totalBets.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.totalBets,
                        style: TextStyle(
                          fontSize: 9,
                          color: isCash ? Colors.cyanAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 14),

                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // Pseudo 3D Glow underlay
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, _) {
                          final double glowPower = (widget.gameStatus == "CALCULATING")
                              ? _glowAnimation.value
                              : (widget.isWinner ? 1.0 : (widget.isSelected ? 0.6 : 0.0));
                          if (glowPower <= 0) return const SizedBox.shrink();

                          return Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.isWinner
                                        ? Colors.green.withOpacity(0.6 * glowPower)
                                        : widget.color.withOpacity(0.5 * glowPower),
                                    blurRadius: 25 * glowPower,
                                    spreadRadius: 3 * glowPower,
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Draw Custom Pseudo 3D Chest and Coin Explosion Particles
                      CustomPaint(
                        size: Size(baseWidth, baseHeight),
                        painter: ChestPainter(
                          color: widget.color,
                          multiplier: widget.multiplierValue,
                          isSelected: widget.isSelected,
                          isWinner: widget.isWinner,
                          openProgress: _openController.value,
                          particles: widget.isWinner ? _particles : [],
                        ),
                      ),

                      // Phase 7: Payout Multiplier display (Bounce In above chest)
                      if (widget.isWinner && _openController.value > 0.6)
                        Positioned(
                          top: -30,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.amber, Colors.orange],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
                                    ],
                                    border: Border.all(color: Colors.white70, width: 1),
                                  ),
                                  child: Text(
                                    "🎉 ${widget.multiplierValue}X",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Checkmark tick
                      if (widget.isSelected)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),

                      // Hot fire badge
                      if (widget.isHot)
                        Positioned(
                          top: -8,
                          left: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.local_fire_department_rounded,
                                color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.multiplierLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  if (widget.userBetAmount > 0) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCash
                              ? Colors.cyanAccent.withOpacity(0.6)
                              : Colors.amberAccent.withOpacity(0.6),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        widget.userBetAmount.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 9,
                          color: isCash ? Colors.cyanAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ] else
                    const SizedBox(height: 14),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class CoinParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  double scale;

  CoinParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.scale,
  });
}

class ChestPainter extends CustomPainter {
  final Color color;
  final int multiplier;
  final bool isSelected;
  final bool isWinner;
  final double openProgress;
  final List<CoinParticle> particles;

  ChestPainter({
    required this.color,
    required this.multiplier,
    required this.isSelected,
    required this.isWinner,
    required this.openProgress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Theme values corresponding to standard and premium tiers
    Color primaryColor = color;
    Color borderMetalColor = const Color(0xFFB0BEC5); // Sleek silver borders/metals
    Color gemsColor = Colors.transparent;

    // Stylize each box specific theme and gems (Mobile Casino Premium Style)
    if (multiplier == 45) {
      primaryColor = const Color(0xFFFF3D00);    // Royal red-orange
      borderMetalColor = const Color(0xFFFFD700); // Gold borders
      gemsColor = const Color(0xFFFF1744);        // Big red ruby gem
    } else if (multiplier == 25) {
      primaryColor = const Color(0xFF1A237E);    // Deep sapphire indigo
      borderMetalColor = const Color(0xFF90A4AE); // Steel borders
      gemsColor = const Color(0xFF00E5FF);        // Big blue diamond gem
    } else if (multiplier == 15) {
      primaryColor = const Color(0xFF880E4F);    // Deep magenta
      borderMetalColor = const Color(0xFFFF80AB); // Soft rose gold borders
      gemsColor = const Color(0xFFE040FB);        // Purple amethyst gem
    } else if (multiplier == 10) {
      primaryColor = const Color(0xFF0D47A1);    // Arctic ice blue
      borderMetalColor = const Color(0xFFE0F7FA); // Ice crystals silver borders
      gemsColor = const Color(0xFF00B0FF);        // Glowing cyan icy star gem
    }

    final double bodyTop = h * 0.44;
    final double bodyBottom = h * 0.88;
    final double bodyLeft = w * 0.16;
    final double bodyRight = w * 0.84;

    // ─── 1. Draw Wings for 45x Legendary Chest ───
    if (multiplier == 45) {
      final Paint wingPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF3D00), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(0, h * 0.1, w, h * 0.9))
        ..style = PaintingStyle.fill;

      // Left Wing Path
      final Path leftWing = Path()
        ..moveTo(bodyLeft, h * 0.45)
        ..cubicTo(w * 0.05, h * 0.25, -w * 0.15, h * 0.4, bodyLeft, h * 0.75)
        ..cubicTo(w * 0.02, h * 0.65, w * 0.05, h * 0.55, bodyLeft, h * 0.55)
        ..close();
      canvas.drawPath(leftWing, wingPaint);

      // Right Wing Path
      final Path rightWing = Path()
        ..moveTo(bodyRight, h * 0.45)
        ..cubicTo(w * 0.95, h * 0.25, w * 1.15, h * 0.4, bodyRight, h * 0.75)
        ..cubicTo(w * 0.98, h * 0.65, w * 0.95, h * 0.55, bodyRight, h * 0.55)
        ..close();
      canvas.drawPath(rightWing, wingPaint);
    }

    // ─── 2. Draw Chest Body Base ───
    final RRect bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom),
      const Radius.circular(8),
    );

    // Body gradient for Pseudo 3D volumetric shading
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.darken(0.05), primaryColor.darken(0.45)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom));
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Inner gold stack showing when lid is open
    if (openProgress > 0) {
      final Paint goldStackPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(bodyLeft + 4, bodyTop - 8, bodyRight - 4, bodyTop + 4))
        ..style = PaintingStyle.fill;

      final RRect goldRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(bodyLeft + 4, bodyTop - 6 * openProgress, bodyRight - 4, bodyTop + 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(goldRRect, goldStackPaint);

      // Draw shiny sparkle stars
      final Paint sparklePaint = Paint()..color = Colors.white;
      _drawSparkle(canvas, w * 0.5, bodyTop - 8, 4 * openProgress, sparklePaint);
      _drawSparkle(canvas, w * 0.3, bodyTop - 4, 3 * openProgress, sparklePaint);
      _drawSparkle(canvas, w * 0.7, bodyTop - 5, 3 * openProgress, sparklePaint);
    }

    // Metal Borders for Chest base
    final Paint metalBorderPaint = Paint()
      ..shader = LinearGradient(
        colors: [borderMetalColor, borderMetalColor.darken(0.3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(bodyRRect, metalBorderPaint);

    // Side vertical metal bands (straps)
    final Paint metalBandPaint = Paint()
      ..shader = LinearGradient(
        colors: [borderMetalColor, borderMetalColor.darken(0.4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom));

    canvas.drawRect(Rect.fromLTRB(w * 0.26, bodyTop, w * 0.34, bodyBottom), metalBandPaint);
    canvas.drawRect(Rect.fromLTRB(w * 0.66, bodyTop, w * 0.74, bodyBottom), metalBandPaint);

    // ─── 3. Draw Lid/Cover with Rotation (Rotate X simulation) ───
    canvas.save();

    final double pivotY = bodyTop;
    // Rotate lid upward based on progress (Translate & scale vertically to mimic 3D angle)
    final double lidRotationAngle = -openProgress * (pi / 2.2);
    final double verticalCompression = cos(lidRotationAngle); // Mimic 3D perspective

    canvas.translate(w * 0.5, pivotY);
    canvas.scale(1.0, verticalCompression);
    canvas.translate(-w * 0.5, -pivotY);

    final double lidTop = h * 0.12;
    final double lidBottom = bodyTop;
    final double lidLeft = w * 0.14;
    final double lidRight = w * 0.86;

    // Curved Dome Cover
    final Path lidPath = Path()
      ..moveTo(lidLeft, lidBottom)
      ..quadraticBezierTo(lidLeft - 1, lidTop + (lidBottom - lidTop) * 0.25, lidLeft + (lidRight - lidLeft) * 0.1, lidTop)
      ..lineTo(lidRight - (lidRight - lidLeft) * 0.1, lidTop)
      ..quadraticBezierTo(lidRight + 1, lidTop + (lidBottom - lidTop) * 0.25, lidRight, lidBottom)
      ..close();

    final Paint lidPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, primaryColor.darken(0.35)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(lidLeft, lidTop, lidRight, lidBottom));
    canvas.drawPath(lidPath, lidPaint);

    // Lid Metal Border
    final Paint lidMetalBorder = Paint()
      ..shader = LinearGradient(
        colors: [borderMetalColor, borderMetalColor.darken(0.3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(lidLeft, lidTop, lidRight, lidBottom))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(lidPath, lidMetalBorder);

    // Lid Straps
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.26, lidBottom)
        ..lineTo(w * 0.34, lidBottom)
        ..quadraticBezierTo(w * 0.34, lidTop + 4, w * 0.32, lidTop)
        ..lineTo(w * 0.28, lidTop)
        ..quadraticBezierTo(w * 0.26, lidTop + 4, w * 0.26, lidBottom)
        ..close(),
      metalBandPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.66, lidBottom)
        ..lineTo(w * 0.74, lidBottom)
        ..quadraticBezierTo(w * 0.74, lidTop + 4, w * 0.72, lidTop)
        ..lineTo(w * 0.68, lidTop)
        ..quadraticBezierTo(w * 0.66, lidTop + 4, w * 0.66, lidBottom)
        ..close(),
      metalBandPaint,
    );

    // Premium Features (Crown/Jewels on Lid)
    if (multiplier == 45) {
      // Crown on top
      final Paint crownPaint = Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)]).createShader(Rect.fromLTRB(w * 0.35, lidTop - 12, w * 0.65, lidTop));
      final Path crownPath = Path()
        ..moveTo(w * 0.35, lidTop)
        ..lineTo(w * 0.38, lidTop - 8)
        ..lineTo(w * 0.44, lidTop - 2)
        ..lineTo(w * 0.50, lidTop - 12) // Center tip
        ..lineTo(w * 0.56, lidTop - 2)
        ..lineTo(w * 0.62, lidTop - 8)
        ..lineTo(w * 0.65, lidTop)
        ..close();
      canvas.drawPath(crownPath, crownPaint);
    }

    canvas.restore(); // Lid restore

    // ─── 4. Draw Center Plate, Latch & Gems ───
    final double lockX = w * 0.5;
    final double lockY = bodyTop + 2;

    // Backing Lock Plate (Glossy metal shield)
    final Paint platePaint = Paint()
      ..shader = LinearGradient(
        colors: [borderMetalColor, borderMetalColor.darken(0.45)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: Offset(lockX, lockY), width: 18, height: 18))
      ..style = PaintingStyle.fill;

    final RRect lockBackingRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(lockX, lockY), width: 16, height: 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(lockBackingRRect, platePaint);

    // Gems / Gemstones embedding (Casinos Luxury Style)
    if (gemsColor != Colors.transparent) {
      final Paint gemPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, gemsColor, gemsColor.darken(0.35)],
        ).createShader(Rect.fromCircle(center: Offset(lockX, lockY), radius: 5))
        ..style = PaintingStyle.fill;

      if (multiplier == 45) {
        // Heart Gem / Large ruby
        _drawHeart(canvas, lockX, lockY - 3, 5, gemPaint);
      } else if (multiplier == 25) {
        // Large Diamond cut gem
        final Path diamond = Path()
          ..moveTo(lockX, lockY - 5)
          ..lineTo(lockX + 5, lockY)
          ..lineTo(lockX, lockY + 5)
          ..lineTo(lockX - 5, lockY)
          ..close();
        canvas.drawPath(diamond, gemPaint);
      } else if (multiplier == 15) {
        // Magic star gem
        final Path star = _createStarPath(lockX, lockY, 5, 2.2);
        canvas.drawPath(star, gemPaint);
      } else if (multiplier == 10) {
        // Snowflake crystal star
        _drawSparkle(canvas, lockX, lockY, 5, gemPaint);
      }
    } else {
      // Standard Keyhole
      final Paint keyholePaint = Paint()..color = const Color(0xFF121212);
      canvas.drawCircle(Offset(lockX, lockY - 1), 2.0, keyholePaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(lockX, lockY + 2), width: 1.8, height: 3.5), keyholePaint);
    }

    // ─── 5. Draw Explosive Coin Particles (Casino Phase 6) ───
    if (particles.isNotEmpty) {
      final Paint coinOuterPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: Offset(lockX, lockY), radius: 6));

      final Paint coinInnerPaint = Paint()..color = const Color(0xFFFFF59D);

      for (var p in particles) {
        canvas.save();
        // Translate to particle position (offset relative to the chest center)
        canvas.translate(lockX + p.x, bodyTop + p.y);
        canvas.rotate(p.rotation);
        canvas.scale(p.scale);

        // Volumetric Casino coin
        canvas.drawCircle(Offset.zero, 4.5, coinOuterPaint);
        canvas.drawCircle(Offset.zero, 3.0, coinInnerPaint);
        
        canvas.restore();
      }
    }
  }

  void _drawSparkle(Canvas canvas, double cx, double cy, double r, Paint paint) {
    if (r <= 0) return;
    final Path path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx, cy, cx + r, cy)
      ..quadraticBezierTo(cx, cy, cx, cy + r)
      ..quadraticBezierTo(cx, cy, cx - r, cy)
      ..quadraticBezierTo(cx, cy, cx, cy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, double cx, double cy, double size, Paint paint) {
    final Path path = Path();
    path.moveTo(cx, cy + size * 0.3);
    path.cubicTo(cx - size * 0.5, cy - size * 0.3, cx - size, cy + size * 0.2, cx, cy + size);
    path.cubicTo(cx + size, cy + size * 0.2, cx + size * 0.5, cy - size * 0.3, cx, cy + size * 0.3);
    canvas.drawPath(path, paint);
  }

  Path _createStarPath(double cx, double cy, double outerRadius, double innerRadius) {
    final Path path = Path();
    double angle = -pi / 2;
    final double step = pi / 5;

    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? outerRadius : innerRadius;
      final double x = cx + cos(angle) * r;
      final double y = cy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant ChestPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.multiplier != multiplier ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isWinner != isWinner ||
        oldDelegate.openProgress != openProgress ||
        oldDelegate.particles.length != particles.length;
  }
}

extension ColorDarken on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final hsvDark = hsv.withValue((hsv.value - amount).clamp(0.0, 1.0));
    return hsvDark.toColor();
  }
}
