// import 'package:demo_p/core/widgets/main_wrapper.dart';
// import 'package:demo_p/features/Login%20Screen/login_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _controller;

//   late Animation<double> progress; // main animation progress
//   late Animation<double> fadeInAnim;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 3),
//     );

//     progress = CurvedAnimation(
//       parent: _controller,
//       curve: const Interval(0.3, 0.6, curve: Curves.easeInOut),
//     );

//     fadeInAnim = CurvedAnimation(
//       parent: _controller,
//       curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
//     );

//     _controller.forward();
 
//   _controller.addStatusListener((status) {
//     if (status == AnimationStatus.completed) {
//       _navigateToHome();
//     }
//   });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
// void _navigateToHome() async {


//   if (!mounted) return;

//   Navigator.pushReplacement(
//     context,
//     MaterialPageRoute(
//       builder: (context) => const LoginScreen(),
//     ),
//   );
// }

//   double lerp(double start, double end, double t) {
//     return start + (end - start) * t;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           /// 🔥 Background
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Color(0xFFEFEFEF),
//                   Color(0xFFBFD6E2),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),

//           Container(
//             color: Colors.white.withOpacity(0.5),
//           ),

//           AnimatedBuilder(
//             animation: _controller,
//             builder: (context, child) {
//               double t = progress.value;

          
//               double careTop = lerp(375, 231, t);

      
//               double byTop = 276;

             
//               double logoTop = 351;

//               return Stack(
//                 children: [
//                   Positioned(
//                     top: careTop,
//                     left: (MediaQuery.of(context).size.width - 276) / 2,
//                     child: Transform.scale(
//                       scale: lerp(1.0, 0.8, t),
//                       child: const SizedBox(
//                         width: 276,
//                         height: 50,
//                         child: Text(
//                           "Care Companion",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             fontFamily: 'Mulish',
//                             fontSize: 35,
//                             height: 1,
//                             color: Color(0xFFDD1066),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),

              
//                   Positioned(
//                     top: byTop,
//                     left: (MediaQuery.of(context).size.width - 21) / 2,
//                     child: Opacity(
//                       opacity: fadeInAnim.value,
//                       child: const Text(
//                         "by",
//                         style: TextStyle(
//                           fontFamily: 'BacasimeAntique',
//                           fontSize: 18,
//                           color: Colors.black,
//                         ),
//                       ),
//                     ),
//                   ),

                 
//                   Positioned(
//                     top: logoTop,
//                     left: (MediaQuery.of(context).size.width - 247) / 2,
//                     child: Opacity(
//                       opacity: fadeInAnim.value,
//                       child: SizedBox(
//                         width: 247,
//                         height: 158,
//                         child: Image.asset(
//                           "assets/Images/health_tg.png",
//                           fit: BoxFit.contain,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),

//           /// 🔻 BOTTOM SECTION
//           Positioned(
//             bottom: 20,
//             left: 0,
//             right: 0,
//             child: Column(
//               children: [
//                 const Text(
//                   "Pending compliance..",
//                   style: TextStyle(
//                     fontFamily: 'Mulish',
//                     fontSize: 8,
//                     color: Colors.black,
//                   ),
//                 ),
//                 const SizedBox(height: 8),

//                 SizedBox(
//                   width: 275,
//                   height: 50,
//                   child: Image.asset(
//                     "assets/Images/patner.png",
//                     fit: BoxFit.contain,
//                   ),
//                 ),

//                 const SizedBox(height: 10),

//                 const Text(
//                   "(C) Copyright 2024 Health Jeanie, Inc.",
//                   style: TextStyle(
//                     fontFamily: 'Mulish',
//                     fontSize: 12,
//                     color: Colors.black,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }