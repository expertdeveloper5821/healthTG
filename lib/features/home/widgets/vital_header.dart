import 'package:flutter/material.dart';


class VitalHeader extends StatelessWidget {
  const VitalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 19, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Vital signs",
              style: const TextStyle(
                fontFamily: "Inter", 
                fontSize: 15.46,
                fontWeight: FontWeight.w400, 
                height: 1, 
                letterSpacing: 0.5 * 15.46 / 100, 
                color: Colors.white,
              ),
            ),

       
            Row(
              children: [

                Text(
                  "See all",
                  style: const TextStyle(
                    fontFamily: "Inter",
                    fontSize: 14.49, 
                    fontWeight: FontWeight.w600, 
                    height: 1,
                    letterSpacing: 0.5 * 14.49 / 100,
                    color: Color(0xFF7CA9D8), 
                  ),
                ),

                const SizedBox(width: 6),

               
                Image.asset(
                  "assets/Images/bar_chart.png",
                  width: 18,
                  height: 18,
          
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}