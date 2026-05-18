import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:demo_p/features/Login%20Screen/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

// ═══════════════════════════════════════════════════════════════════════
//  HealthcareIntroScreen
//
//  Animation sequence (exact same as original + orbit circles):
//  1. 1000 ms delay
//  2. Logo zooms BIG → small  (900 ms, easeOut)   ← ORIGINAL preserved
//  3. Logo moves up vertically (900 ms, easeOut)  ← ORIGINAL preserved
//  4. BG blobs fade in         (600 ms)            ← ORIGINAL preserved
//  5. 3 concentric rings pop in (700 ms, easeOutBack)
//  6. 5 orbit circles → full 360° continuous orbit (20 s loop)
//  7. Bottom text + CTA button slides in (600 ms)
// ═══════════════════════════════════════════════════════════════════════

class HealthcareIntroScreen extends StatefulWidget {
  const HealthcareIntroScreen({super.key});

  @override
  State<HealthcareIntroScreen> createState() =>
      _HealthcareIntroScreenState();
}

class _HealthcareIntroScreenState extends State<HealthcareIntroScreen>
    with TickerProviderStateMixin {

  // ── 1. Logo zoom (ORIGINAL) ───────────────────────────────────────
  late AnimationController _logoController;
  late Animation<double>   _scaleAnimation;

  // ── 2. Logo move up (ORIGINAL) ────────────────────────────────────
  late AnimationController _moveController;
  late Animation<double>   _topAnimation;

  // ── 3. Background blobs (ORIGINAL) ───────────────────────────────
  late AnimationController _bgController;
  late Animation<double>   _bgOpacity;

  // ── 4. Rings pop-in ───────────────────────────────────────────────
  late AnimationController _ringsController;
  late Animation<double>   _circleOpacity;
  late Animation<double>   _circleScale;

  // ── 5. Full 360° orbit (continuous) ──────────────────────────────
  late AnimationController _orbitController;

  // ── 6. Bottom content ─────────────────────────────────────────────
  late AnimationController _bottomController;
  late Animation<double>   _bottomOpacity;
  late Animation<Offset>   _bottomSlide;
  late AnimationController _swapController;
late Animation<double> _swapAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scaleAnimation = Tween<double>(begin: 16.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic,),
    );
_swapController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 8000),
);

_swapAnimation = CurvedAnimation(
  parent: _swapController,
  curve: Curves.easeInOut,
);

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _topAnimation = Tween<double>(begin: 320.5, end: 200.0).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeOut),
    );

 
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_bgController);


    _ringsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _circleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringsController, curve: Curves.easeOut),
    );
    _circleScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ringsController, curve: Curves.easeOutBack),
    );

  
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _bottomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bottomOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bottomController, curve: Curves.easeOut),
    );
    _bottomSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bottomController, curve: Curves.easeOut),
    );


    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;


    await _logoController.forward();
    if (!mounted) return;

    _bgController.forward();
    await _moveController.forward();
    if (!mounted) return;

    await _ringsController.forward();
    if (!mounted) return;


    _bottomController.forward();
    _swapLoop();
  }
void _swapLoop() async {
  while (mounted) {
    await _swapController.forward();
    await _swapController.reverse();
  }
}
  @override
  void dispose() {
    _logoController.dispose();
    _moveController.dispose();
    _bgController.dispose();
    _ringsController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  static const List<_FeatureItem> _features = [
    _FeatureItem(   imagePath: 'assets/Images/exercise.png',   ),
    _FeatureItem( imagePath: 'assets/Images/yoga.png',     ),
    _FeatureItem( imagePath:'assets/Images/online_exercie.png',    ),
    _FeatureItem(    imagePath: 'assets/Images/games.png',    ),
    _FeatureItem( imagePath: 'assets/Images/online_consult.png',  ),

  ];
  static const List<Offset> _positions = [
  Offset(136.57, 0.98),  
  Offset(259.39, 98.41),  
  Offset(220.79, 244.48), 
  Offset(53.18, 248.91),  
  Offset(0.88, 96.91),   
];


  static const double _cx           = 181.44;
  static const double _cy           = 241.15;
  static const double _orbitRadius  = 131.4;  
  static const double _dotSize = 72.12;

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, child) =>
                Opacity(opacity: _bgOpacity.value, child: child!),
            child: Stack(
              children: [
                Positioned(
                  top: -205, left: -454,
                  child: Transform.rotate(
                    angle: 33.57 * pi / 90,
                    child: _blurEllipse(),
                  ),
                ),
                Positioned(
                  top: 100, right: -450,
                  child: Transform.rotate(
                    angle: 33.57 * pi / 90,
                    child: _blurEllipse(),
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
       animation: Listenable.merge([_ringsController, _swapController]),
            builder: (_, child) => Positioned(
              top:  108.25,
              left: 50.04,
              child: Opacity(
                opacity: _circleOpacity.value,
                child: Transform.scale(
                  scale: _circleScale.value,
                  child: child,
                ),
              ),
            ),
            child: Container(
              width: 262.8, height: 265.8,
              decoration: BoxDecoration(
                color: const Color(0xFF46C3FE).withOpacity(0.09),
                borderRadius: BorderRadius.circular(190),
                border: Border.all(
                  color: const Color(0xFF46C3FE).withOpacity(0.18),
                  width: 1,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ringsController,
            builder: (_, child) => Positioned(
              top:  152.25,
              left: 95.04,
              child: Opacity(
                opacity: _circleOpacity.value,
                child: Transform.scale(
                  scale: _circleScale.value,
                  child: child,
                ),
              ),
            ),
            child: Container(
              width: 171.8, height: 173.8,
              decoration: BoxDecoration(
                color: const Color(0xFF46C3FE).withOpacity(0.12),
                borderRadius: BorderRadius.circular(120),
                border: Border.all(
                  color: const Color(0xFF46C3FE).withOpacity(0.20),
                  width: 1,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ringsController,
            builder: (_, child) => Positioned(
              top:  186.25,
              left: 128.04,
              child: Opacity(
                opacity: _circleOpacity.value,
                child: Transform.scale(
                  scale: _circleScale.value,
                  child: child,
                ),
              ),
            ),
            child: Container(
              width: 104.8, height: 104.8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          AnimatedBuilder(
animation: Listenable.merge([_ringsController, _swapController]),
            builder: (context, _) {
              return Stack(
                children: List.generate(_features.length, (i) {
                final current = _positions[i];
final next = _positions[(i + 1) % _positions.length];

final dx = lerpDouble(current.dx, next.dx, _swapAnimation.value)!;
final dy = lerpDouble(current.dy, next.dy, _swapAnimation.value)!;

return Positioned(
  left: 16.04 + dx,
  top:  71.25 + dy,
                    child: Opacity(
                      opacity: _circleOpacity.value,
                      child: _OrbitCircle(
                        item: _features[i],
                        
                        size: _dotSize,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_logoController, _moveController]),
            builder: (context, child) {
              final double top = _moveController.isDismissed
                  ? sh / 2 - 40
                  : _topAnimation.value;
              return Positioned(
                top:  top,
                left: sw / 2 - 40,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: 80, height: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  'assets/Images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left:   24,
            right:  24,
            child: AnimatedBuilder(
              animation: _bottomController,
              builder: (_, child) => FadeTransition(
                opacity: _bottomOpacity,
                child: SlideTransition(
                  position: _bottomSlide,
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: const Text(
                      'All Your Healthcare\nNeeds, In One App',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   28,
                        fontWeight: FontWeight.w700,
                        height:     1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Consult doctors, monitor your health, and\nget medicines—without switching apps.',
                      style: TextStyle(
                        color:    Color(0XFF9FA2A5),
                        fontSize: 15,
                        height:   1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width:  double.infinity,
                    height:44 ,
                    child: ElevatedButton(
                   onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const LoginScreen(),
    ),
  );
},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF46C3FE),
                        foregroundColor: Color(0XFF1E2021),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w600,
              
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
  Widget _blurEllipse() {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
      child: Container(
        width: 609, height: 372,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -1),
            end:   Alignment(-2, -3),
            colors: [Color(0xFF47CEEC), Color(0xFF5F2FE8)],
          ),
        ),
      ),
    );
  }
}
class _OrbitCircle extends StatelessWidget {
  const _OrbitCircle({required this.item, required this.size});

  final _FeatureItem item;
  final double       size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF111827),
          ),
          child: ClipOval(
          child: Image.asset(
  item.imagePath,
  fit: BoxFit.cover,
),
          ),
        ),
      
      ],
    );
  }
}


class _FeatureItem {
  const _FeatureItem({

    required this.imagePath,

  });
 
  final String imagePath;
 
}