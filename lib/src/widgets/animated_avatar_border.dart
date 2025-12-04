import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedAvatarBorder extends StatefulWidget {
  final Widget child;
  final String style;
  final Color staticColor;
  final double borderWidth;
  final double size;
  final Animation<double>? animation;

  const AnimatedAvatarBorder({
    super.key,
    required this.child,
    this.style = 'static',
    required this.staticColor,
    this.borderWidth = 3,
    required this.size,
    this.animation,
  });

  @override
  State<AnimatedAvatarBorder> createState() => _AnimatedAvatarBorderState();
}

class GalaxyParticle {
  double angle;
  double distance;
  double size;
  Color color;
  double opacity;

  GalaxyParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    this.opacity = 0.0,
  });
}

class _AnimatedAvatarBorderState extends State<AnimatedAvatarBorder> with SingleTickerProviderStateMixin {
  AnimationController? _localController;
  late Animation<double> _animation;
  
  final List<GalaxyParticle> _galaxyParticles = [];
  final List<double> _lightningJitter = [];
  int _frame = 0;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    if (widget.animation != null) {
      _animation = widget.animation!;
    } else {
      _localController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      );
      if (widget.style != 'static') {
        _localController!.repeat();
      }
      _animation = _localController!;
    }
    
    if (widget.style != 'static') {
      _animation.addListener(_updateParticles);
    }
  }

  @override
  void didUpdateWidget(AnimatedAvatarBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 1. Handle Animation Provider Change
    if (widget.animation != oldWidget.animation) {
      if (oldWidget.style != 'static') {
        _animation.removeListener(_updateParticles);
      }
      
      if (widget.animation != null) {
        _localController?.dispose();
        _localController = null;
        _animation = widget.animation!;
      } else {
        _localController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 6),
        );
        if (widget.style != 'static') {
          _localController!.repeat();
        }
        _animation = _localController!;
      }
      
      if (widget.style != 'static') {
        _animation.addListener(_updateParticles);
      }
    } 
    // 2. Handle Style Change (when animation source stays same)
    else if (widget.style != oldWidget.style) {
       if (widget.style == 'static') {
          _animation.removeListener(_updateParticles);
          if (_localController != null && _localController!.isAnimating) {
             _localController!.stop();
          }
       } else {
          // Becoming non-static
          if (oldWidget.style == 'static') {
             _animation.addListener(_updateParticles);
             if (_localController != null && !_localController!.isAnimating) {
                _localController!.repeat();
             }
          }
       }
    }
  }

  void _updateParticles() {
    // --- Galaxy Logic ---
    if (widget.style == 'galaxy') {
      final radius = widget.size / 2;
      
      // Spawn particles spiraling in
      // Optimize: Reduce spawn rate for smaller icons to save resources
      // Reduced particle count by ~70%
      final spawnThreshold = widget.size < 50 ? 0.955 : 0.88;
      if (_random.nextDouble() > spawnThreshold) {
        final angle = _random.nextDouble() * 2 * math.pi;
        // Start outside the border
        final startDist = radius + (_random.nextDouble() * 15 + 5); 
        
        // Scale size for small icons
        final minScale = widget.size < 50 ? 0.5 : 1.0;
        final scaleFactor = math.max(widget.size / 100.0, minScale);

        _galaxyParticles.add(GalaxyParticle(
          angle: angle,
          distance: startDist,
          size: (_random.nextDouble() * 2 + 1) * scaleFactor,
          color: _random.nextBool() ? Colors.white : Colors.purpleAccent,
        ));
      }

      for (int i = _galaxyParticles.length - 1; i >= 0; i--) {
        final p = _galaxyParticles[i];
        p.angle += 0.02; // Spiral rotation (Slower)
        p.distance -= 0.3; // Suck in towards center
        
        // Fade in
        if (p.opacity < 1.0 && p.distance > radius) {
          p.opacity += 0.1;
          if (p.opacity > 1.0) p.opacity = 1.0;
        }
        // Fade out as it hits the "event horizon" (the border ring)
        if (p.distance <= radius) {
          p.opacity -= 0.1;
        }

        if (p.opacity <= 0 || p.distance < radius - 5) {
          _galaxyParticles.removeAt(i);
        }
      }
    } else {
      if (_galaxyParticles.isNotEmpty) _galaxyParticles.clear();
    }

    // --- Electric Logic ---
    if (widget.style == 'electric') {
      _frame++;
      // Update jitter every 8 frames for a less frantic effect
      if (_frame % 8 == 0) {
        _lightningJitter.clear();
        const int segments = 24; // More segments for smoother look
        for (int i = 0; i < segments; i++) {
          // Jitter relative to size - reduced amplitude
          double maxJitter = widget.size * 0.03; 
          _lightningJitter.add((_random.nextDouble() - 0.5) * 2 * maxJitter);
        }
      }
    } else {
      if (_lightningJitter.isNotEmpty) _lightningJitter.clear();
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_updateParticles);
    _localController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == 'static') {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.staticColor, width: widget.borderWidth),
        ),
        child: widget.child,
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          RepaintBoundary(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _BorderPainter(
                      style: widget.style,
                      animationValue: _animation.value,
                      width: widget.borderWidth,
                      galaxyParticles: widget.style == 'galaxy' ? List.of(_galaxyParticles) : null,
                      lightningJitter: widget.style == 'electric' ? List.of(_lightningJitter) : null,
                      size: widget.size, // Pass size to painter for optimization
                    ),
                    size: Size(widget.size, widget.size),
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

class _BorderPainter extends CustomPainter {
  final String style;
  final double animationValue;
  final double width;
  final List<GalaxyParticle>? galaxyParticles;
  final List<double>? lightningJitter;
  final double size; // Add size field

  _BorderPainter({
    required this.style,
    required this.animationValue,
    required this.width,
    this.galaxyParticles,
    this.lightningJitter,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - width) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    if (style == 'rainbow') {
      final sweepGradient = SweepGradient(
        colors: const [
          Colors.red, Colors.orange, Colors.yellow, Colors.green, 
          Colors.blue, Colors.indigo, Colors.purple, Colors.red
        ],
        transform: GradientRotation(animationValue * 2 * math.pi),
      );
      paint.shader = sweepGradient.createShader(rect);
      canvas.drawCircle(center, radius, paint);
    } else if (style == 'gold') {
       final sweepGradient = SweepGradient(
        colors: const [
          Color(0xFFFFD700), Color(0xFFFFFACD), Color(0xFFFFD700), 
          Color(0xFFB8860B), Color(0xFFFFD700)
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      );
      paint.shader = sweepGradient.createShader(rect);
      canvas.drawCircle(center, radius, paint);
    } else if (style == 'neon_blue') {
       // Pulse from 0.2 to 1.0 opacity (weaker low point)
       final opacity = (math.sin(animationValue * 2 * math.pi) + 1) / 2 * 0.8 + 0.2;
       
       // Reduce intensity for small icons (Home Page)
       final isSmall = size.width < 50;
       final intensity = isSmall ? 0.5 : 1.0;

       // Outer Glow (Ambient)
       paint.color = Colors.cyanAccent.withOpacity(opacity * 0.6 * intensity);
       paint.strokeWidth = width * 3.0;
       paint.maskFilter = MaskFilter.blur(BlurStyle.normal, isSmall ? 5 : 12);
       canvas.drawCircle(center, radius, paint);

       // Core (Bright)
       paint.color = Colors.cyanAccent.withOpacity(opacity * (isSmall ? 0.8 : 1.0));
       paint.strokeWidth = width;
       paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
       canvas.drawCircle(center, radius, paint);
    } else if (style == 'fire') {
      // Realistic Fire Effect using layered noise paths
      final baseRadius = radius;
      final isSmall = size.width < 50;
      
      // Helper to draw a flame layer
      void drawFlameLayer(Color color, double scale, double speed, double offset, double blur) {
        final path = Path();
        // Optimize: Reduce steps for smaller icons
        final int steps = isSmall ? 20 : 60;
        final angleStep = 2 * math.pi / steps;

        for (int i = 0; i <= steps; i++) {
          final theta = i * angleStep;
          // Sum of sines to create random-looking flame fluctuations
          double noise = math.sin(theta * 6 - animationValue * speed * 10 + offset) * 0.4 +
                         math.sin(theta * 13 + animationValue * speed * 20 + offset * 2) * 0.3 +
                         math.sin(theta * 20 - animationValue * speed * 15 + offset * 3) * 0.3;
          
          // Ensure noise pushes outwards mostly
          // Reduce noise scale for small icons
          double effectiveScale = scale * (isSmall ? 0.6 : 1.0);
          double r = baseRadius + (math.max(0, noise) * width * effectiveScale);
          
          final x = center.dx + math.cos(theta) * r;
          final y = center.dy + math.sin(theta) * r;

          if (i == 0) path.moveTo(x, y);
          else path.lineTo(x, y);
        }
        path.close();

        paint.color = color;
        paint.style = PaintingStyle.stroke;
        // Thinner stroke for small icons
        paint.strokeWidth = width * (isSmall ? 0.5 : 0.8); 
        // Less blur for small icons (makes it look more opaque/defined)
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur * (isSmall ? 0.3 : 1.0));
        paint.shader = null;
        canvas.drawPath(path, paint);
      }

      // Layer 1: Outer/Darker (Red/Deep Orange)
      drawFlameLayer(Colors.deepOrange, 2.5, 1.0, 0.0, 6.0);
      
      // Layer 2: Middle (Orange)
      drawFlameLayer(Colors.orange, 1.8, 1.2, 2.0, 4.0);
      
      // Layer 3: Inner/Hot (Yellow)
      drawFlameLayer(Colors.yellow, 1.0, 1.5, 4.0, 2.0);

    } else if (style == 'galaxy') {
      // Black hole accretion disk effect
      final sweepGradient = SweepGradient(
        colors: const [
          Colors.black, Colors.deepPurple, Colors.purpleAccent, Colors.white, Colors.purpleAccent, Colors.deepPurple, Colors.black
        ],
        stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      );
      paint.shader = sweepGradient.createShader(rect);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
      canvas.drawCircle(center, radius, paint);

      // Draw galaxy particles
      if (galaxyParticles != null) {
        final particlePaint = Paint()..style = PaintingStyle.fill;
        for (final p in galaxyParticles!) {
          particlePaint.color = p.color.withOpacity(p.opacity);
          
          final pos = Offset(
             center.dx + math.cos(p.angle) * p.distance,
             center.dy + math.sin(p.angle) * p.distance,
          );
          
          canvas.drawCircle(pos, p.size, particlePaint);
        }
      }
    } else if (style == 'electric') {
      // Electric / Lightning effect
      if (lightningJitter != null && lightningJitter!.isNotEmpty) {
        final path = Path();
        final segments = lightningJitter!.length;
        final angleStep = 2 * math.pi / segments;
        
        for (int i = 0; i <= segments; i++) {
           final index = i % segments;
           final jitter = lightningJitter![index];
           final r = radius + jitter;
           final angle = i * angleStep;
           final x = center.dx + math.cos(angle) * r;
           final y = center.dy + math.sin(angle) * r;
           
           if (i == 0) path.moveTo(x, y);
           else path.lineTo(x, y);
        }
        path.close();

        // Glow
        paint.color = Colors.cyanAccent;
        paint.strokeWidth = width;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
        paint.shader = null; 
        canvas.drawPath(path, paint);

        // Core
        paint.color = Colors.white;
        paint.strokeWidth = width / 2;
        paint.maskFilter = null;
        canvas.drawPath(path, paint);
      }
    } else if (style == 'liquid') {
      // Liquid Flow: Full liquid blob ring
      final path = Path();
      path.fillType = PathFillType.evenOdd; // Optimization: Use evenOdd instead of Path.combine
      
      const int steps = 80; // Reduced from 100
      final angleStep = 2 * math.pi / steps;
      
      // Outer liquid shape
      for (int i = 0; i <= steps; i++) {
        final theta = i * angleStep;
        // Undulating radius
        final r = radius + 10 + 
                  math.sin(theta * 3 + animationValue * 2 * math.pi) * 5 + 
                  math.cos(theta * 5 - animationValue * 2 * math.pi) * 3;
        
        final x = center.dx + math.cos(theta) * r;
        final y = center.dy + math.sin(theta) * r;
        
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();

      // Inner circle (hole)
      path.addOval(Rect.fromCircle(center: center, radius: radius));

      // Draw the liquid body
      paint.color = Colors.blueAccent.withOpacity(0.6);
      paint.style = PaintingStyle.fill;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, paint);
      
      // Highlight (Stroke only outer path)
      // Reconstruct outer path for stroke to avoid stroking the inner circle
      final highlightPath = Path();
      for (int i = 0; i <= steps; i++) {
        final theta = i * angleStep;
        final r = radius + 10 + 
                  math.sin(theta * 3 + animationValue * 2 * math.pi) * 5 + 
                  math.cos(theta * 5 - animationValue * 2 * math.pi) * 3;
        
        final x = center.dx + math.cos(theta) * r;
        final y = center.dy + math.sin(theta) * r;
        
        if (i == 0) highlightPath.moveTo(x, y);
        else highlightPath.lineTo(x, y);
      }
      highlightPath.close();

      paint.color = Colors.lightBlueAccent.withOpacity(0.9);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      paint.maskFilter = null;
      canvas.drawPath(highlightPath, paint);

    } else if (style == 'ice') {
      // Ice Aura: Crystalline structure with drifting sparkles
      
      // 1. Aura (Pulsing Glow)
      final auraPath = Path();
      auraPath.addOval(Rect.fromCircle(center: center, radius: radius));
      
      final auraOpacity = 0.2 + 0.1 * math.sin(animationValue * 2 * math.pi);
      paint.color = Colors.cyanAccent.withOpacity(auraOpacity);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = width * 3;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(auraPath, paint);
      paint.maskFilter = null;

      // 2. Base Icy Ring (Jagged)
      final path = Path();
      const int segments = 50; // Reduced from 60
      final angleStep = 2 * math.pi / segments;
      
      for (int i = 0; i <= segments; i++) {
        final theta = i * angleStep;
        // Jagged noise - static
        final noise = math.sin(theta * 10) * math.cos(theta * 25);
        final r = radius + (noise * 3);
        
        final x = center.dx + math.cos(theta) * r;
        final y = center.dy + math.sin(theta) * r;
        
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();

      paint.color = Colors.cyanAccent;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = width;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
      canvas.drawPath(path, paint);
      
      paint.color = Colors.white;
      paint.strokeWidth = 1;
      paint.maskFilter = null;
      canvas.drawPath(path, paint);

      // 3. Drifting Ice Motes (Procedural Particles)
      final random = math.Random(123); // Fixed seed
      paint.style = PaintingStyle.fill;
      
      for (int i = 0; i < 15; i++) {
        // Each particle has a unique cycle based on i
        final offset = random.nextDouble() * 2 * math.pi;
        // Integer speed for seamless loop
        final speed = 1.0 + random.nextInt(2); 
        
        // Cycle 0..1 based on time
        double t = (animationValue * speed + offset) % 1.0;
        
        // Spiral out
        final angle = offset + (t * math.pi); // Rotate as it moves out
        final dist = radius + (t * 20); // Move out 20px
        final size = 2.0 * (1.0 - t); // Shrink as it moves out
        final opacity = 1.0 - t; // Fade out
        
        final px = center.dx + math.cos(angle) * dist;
        final py = center.dy + math.sin(angle) * dist;
        
        paint.color = Colors.white.withOpacity(opacity);
        
        // Draw diamond shape
        final pPath = Path();
        pPath.moveTo(px, py - size);
        pPath.lineTo(px + size, py);
        pPath.lineTo(px, py + size);
        pPath.lineTo(px - size, py);
        pPath.close();
        
        canvas.drawPath(pPath, paint);
      }

    } else if (style == 'nature') {
      // Nature's Embrace: Intertwining vines with green aura
      
      // 1. Aura (Blurred Glow)
      final auraPath = Path();
      auraPath.addOval(Rect.fromCircle(center: center, radius: radius));
      
      // Pulse opacity seamlessly
      final auraOpacity = 0.3 + 0.15 * math.sin(animationValue * 2 * math.pi);
      paint.color = Colors.greenAccent.withOpacity(auraOpacity);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = width * 4;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawPath(auraPath, paint);
      paint.maskFilter = null; // Reset

      // 2. Base Vine (Darker Green)
      final vinePath1 = Path();
      const int steps = 80; // Reduced from 100
      final angleStep = 2 * math.pi / steps;
      
      for (int i = 0; i <= steps; i++) {
        final theta = i * angleStep;
        // Gentle wave
        final r = radius + math.sin(theta * 6 + animationValue * 2 * math.pi) * 4;
        
        final x = center.dx + math.cos(theta) * r;
        final y = center.dy + math.sin(theta) * r;
        
        if (i == 0) vinePath1.moveTo(x, y);
        else vinePath1.lineTo(x, y);
      }
      vinePath1.close();
      
      paint.color = Colors.green[800]!;
      paint.strokeWidth = width;
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(vinePath1, paint);

      // 3. Secondary Vine (Lighter Green, intertwining)
      final vinePath2 = Path();
      for (int i = 0; i <= steps; i++) {
        final theta = i * angleStep;
        // Opposite wave phase
        final r = radius + math.sin(theta * 6 + animationValue * 2 * math.pi + math.pi) * 4;
        
        final x = center.dx + math.cos(theta) * r;
        final y = center.dy + math.sin(theta) * r;
        
        if (i == 0) vinePath2.moveTo(x, y);
        else vinePath2.lineTo(x, y);
      }
      vinePath2.close();
      
      paint.color = Colors.lightGreen;
      paint.strokeWidth = width * 0.6;
      canvas.drawPath(vinePath2, paint);

      // 4. Floating Spores (Procedural)
      final random = math.Random(456); // Fixed seed
      final sporePaint = Paint()..style = PaintingStyle.fill;
      
      for (int i = 0; i < 16; i++) {
        final offset = random.nextDouble() * 2 * math.pi;
        // Use integer speeds for seamless looping
        final speed = 1.0 + random.nextInt(2); 
        
        double t = (animationValue * speed + offset) % 1.0;
        
        final angle = offset + (t * math.pi * 0.5); // Gentle drift
        final dist = radius + (t * 15); // Move out
        final size = 2.0 * (1.0 - t);
        final opacity = (1.0 - t) * 0.8;
        
        final px = center.dx + math.cos(angle) * dist;
        final py = center.dy + math.sin(angle) * dist;
        
        sporePaint.color = Colors.lightGreenAccent.withOpacity(opacity);
        canvas.drawCircle(Offset(px, py), size, sporePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BorderPainter oldDelegate) => true;
}
