import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:demo_p/core/widgets/custom_appbar.dart';
class RightScreen extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTopTabTap;

  const RightScreen({
    super.key,
    required this.selectedIndex,
    required this.onTopTabTap,
  });

  @override
  State<RightScreen> createState() => _RightScreenState();
}

class _RightScreenState extends State<RightScreen> {
  bool showBanner = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundright,
      appBar: CustomAppBar(
        selectedIndex: widget.selectedIndex,
        onTap: widget.onTopTabTap,
      ),
     body: SafeArea(
  child: SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

//         if (showBanner)
//   Container(
//     width: double.infinity,
//     height: 110,
//     decoration: BoxDecoration(
//       color: const Color(0xFF00486A),
//       borderRadius: const BorderRadius.only(
//         bottomLeft: Radius.circular(30),
//       ),
//       boxShadow: [
//         BoxShadow(
//           color: const Color(0xFF1A4035).withOpacity(0.3),
//           blurRadius: 30,
//           offset: const Offset(0, 8),
//         ),
//       ],
//     ),
//     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
//     child: Stack(
//       children: [

//         Row(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [

//             /// LEFT TEXT
//             const Expanded(
//               child: Text(
//                 "It’s time to check your\nblood sugar level",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w300,
//                   height: 1.3,
                
//                 ),
//               ),
//             ),

//             const SizedBox(width: 10),
//   /// RIGHT BUTTON (⬇️ shifted down)
//     Padding(
//       padding: const EdgeInsets.only(top: 40), // 👈 THIS LINE
//       child: Container(
//         height: 40,
//         padding: const EdgeInsets.symmetric(horizontal: 20),
//         decoration: BoxDecoration(
//           color: const Color(0xFF161819),
//           borderRadius: BorderRadius.circular(30),
//         ),
//         alignment: Alignment.center,
//         child: const Text(
//           "Check now",
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 14,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ),
//     ),
//   ],
// ),

      
//         Positioned(
//           right: 0,
          
//           top: 0,
//           child: GestureDetector(
//             onTap: () {
//               setState(() {
//                 showBanner = false;
//               });
//             },
//             child: const Icon(
//               Icons.close,
//               color: Colors.white,
//               size: 27,
//             ),
//           ),
//         ),
//       ],
//     ),
//   ),
          const SizedBox(height: 16),

       
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.white.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppColors.white, size: 20),
                      8.w,
                      Text("Search", style: TextStyle(color: AppColors.white,fontSize: 16)),
                    ],
                  ),
                ),
              ),
              10.h,
              Image.asset(
                "assets/Images/filter.png",
                width: 42,
                height: 42,
              ),
            ],
          ),

          26.h,

         
          const Text(
            "My categories",
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

         12.h,

          /// CHIPS
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _CategoryChip(
                text: "My Hospitals",
                iconPath: "assets/Images/my_hospitals.svg",
              ),
              _CategoryChip(
                text: "My Doctors",
                iconPath: "assets/Images/my_doctors.svg",
              ),
              _CategoryChip(
                text: "My Pharmacy",
                iconPath: "assets/Images/my_pharmacy.svg",
              ),
              _CategoryChip(
                text: "Add more",
                iconPath: "assets/Images/add_more.svg",
              ),
            ],
          ),
            30.h,

          /// HORIZONTAL FILTER
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _IconItem(
                  label: "Hospitals",
                  iconPath: "assets/Images/my_hospitals.svg",
                  isActive: false,
                ),
                SizedBox(width: 10),
                _IconItem(
                  label: "Clinics",
                  iconPath: "assets/Images/my_hospitals.svg",
                  isActive: true,
                ),
                SizedBox(width: 10),
                _IconItem(
                  label: "Doctors",
                  iconPath: "assets/Images/my_doctors.svg",
                  isActive: false,
                ),
                SizedBox(width: 10),
                _IconItem(
                  label: "Ambulance",
                  iconPath: "assets/Images/ambulance.svg",
                  isActive: false,
                ),
                SizedBox(width: 10),
                _IconItem(
                  label: "Transport",
                  iconPath: "assets/Images/transportation.svg",
                  isActive: false,
                ),
              ],
            ),
          ),

         20.h,

          /// GRID
          GridView.builder(
            itemCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              return const _ClinicCard();
            },
          ),

          150.h,
        ],
      ),
    ),
  ),
),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;
  final String iconPath;

  const _CategoryChip({
    required this.text,
    required this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
   
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.08), // 8% white
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        
          SvgPicture.asset(
            iconPath,
            width: 17.02,
            height: 15.34,
            color: AppColors.white, // white icon
          ),

          const SizedBox(width: 6),

        
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500, 
              color: AppColors.white,
              height: 1, 
              letterSpacing: 0,
              fontFamily: 'Mulish',
            ),
          ),
        ],
      ),
    );
  }
}
class _IconItem extends StatelessWidget {
  final String label;
  final String iconPath;
  final bool isActive;

  const _IconItem({
    required this.label,
    required this.iconPath,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65,
      height: 55,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.white.withOpacity(0.08) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        
          SvgPicture.asset(
            iconPath,
            width: 18,
            height: 18,
            color: isActive
                ? AppColors.white
                : AppColors.unselected,
          ),

          const SizedBox(height: 6),

         
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isActive
                 ? AppColors.white
                : AppColors.unselected,
              height: 1,
              letterSpacing: 0,
              fontFamily: 'Mulish',
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      height: 191,
      decoration: BoxDecoration(
        color: AppColors.backgroundright, // background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.white.withOpacity(0.1), // 10% border
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE
          Padding(
            padding: const EdgeInsets.only(
              top: 5,
              left: 6,
              right: 6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                "assets/Images/clinic.png",
                width: 172.95,
                height: 106.84,
                fit: BoxFit.cover,
              ),
            ),
          ),

        8.h,

    
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "Clinic St. Lambert",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500, 
                color: AppColors.white,
                height: 16 / 14, // line height
                letterSpacing: 0,
                fontFamily: 'Montserrat',
              ),
            ),
          ),

        6.h,

         
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
         
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SvgPicture.asset(
                    "assets/Images/locations.svg",
                    width: 12,
                    height: 12,
                    color: AppColors.location,
                  ),
                ),

                6.w,

                const Expanded(
                  child: Text(
                    "1200, Brussels, Avenu J. Brell, 58",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.location,
                      height: 1.3,
                     fontWeight: FontWeight.w400,
                      fontFamily: 'Mulish',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}