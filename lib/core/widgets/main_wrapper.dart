import 'package:demo_p/features/home/view/home_screen.dart';
import 'package:demo_p/features/home/view/left_home_screen.dart';
import 'package:demo_p/features/home/view/right_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {


  int topIndex = 1;     
  int bottomIndex = 0;  

  final PageController _pageController =
      PageController(initialPage: 1);

 
  List<Widget> get topScreens => [
        LeftScreen(
          selectedIndex: topIndex,
          onTopTabTap: _onTopTabTap,
        ),
        HomeScreen(
          selectedIndex: topIndex,
          onTopTabTap: _onTopTabTap,
        ),
        RightScreen(
          selectedIndex: topIndex,
          onTopTabTap: _onTopTabTap,
        ),
      ];

 
  final List<Widget> bottomScreens = [
    const SizedBox(), // Home (upar PageView show hoga)
    const Center(child: Text("Appointments", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Emergency", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Telehealth", style: TextStyle(color: Colors.white))),
    const Center(child: Text("Profile", style: TextStyle(color: Colors.white))),
  ];


  void _onTopTabTap(int index) {
    setState(() {
      topIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }


  void _onItemTap(int index) {
    setState(() {
      bottomIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

       
          Positioned.fill(
            child: Container(
              color: const Color(0xFF161819),
              child: bottomScreens[bottomIndex],
            ),
          ),

  
          if (bottomIndex == 0)
            Positioned.fill(
              child:PageView(
  controller: _pageController,
  physics: const NeverScrollableScrollPhysics(),
  onPageChanged: (index) {
    setState(() {
      topIndex = index;
    });
  },
  children: topScreens,
),
            ),

  
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

 
 Widget _buildBottomBar() {
  bool isFull = bottomIndex == 0 && topIndex == 1;

  return Container(
    width: double.infinity,
    height: isFull ? 130 : 75,
    padding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: isFull ? 14 : 8,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2021),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(40),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 16,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        /// 🔥 ONLY FULL MODE
        if (isFull) ...[
          SvgPicture.asset(
            "assets/Images/daily_check_in.svg",
            height: 15,
            width: 18,
          ),

          const SizedBox(height: 6),

          const Text(
            "Daily Check-Ins",
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),

          const SizedBox(height: 8),
        ],

        /// 🔻 NAV ITEMS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              iconPath: "assets/Images/Home.svg",
              label: "Home",
              isActive: bottomIndex == 0,
              onTap: () => _onItemTap(0),
            ),
            _NavItem(
              iconPath: "assets/Images/Calendar.svg",
              label: "My Appoint.",
              isActive: bottomIndex == 1,
              // onTap: () => _onItemTap(1),
            ),
            _NavItem(
              iconPath: "assets/Images/Emergency.svg",
              label: "Emergency",
              isActive: bottomIndex == 2,
              // onTap: () => _onItemTap(2),
            ),
            _NavItem(
              iconPath: "assets/Images/telehealth.svg",
              label: "Telehealth",
              isActive: bottomIndex == 3,
              // onTap: () => _onItemTap(3),
            ),
            _NavItem(
              iconPath: "assets/Images/Profile.svg",
              label: "Me",
              isActive: bottomIndex == 4,
              // onTap: () => _onItemTap(4),
            ),
          ],
        ),
      ],
    ),
  );
}
}


class _NavItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isActive;
  final bool showDot;
  final VoidCallback? onTap;

  const _NavItem({
    required this.iconPath,
    required this.label,
    this.isActive = false,
    this.showDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SvgPicture.asset(
            iconPath,
            height: 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}