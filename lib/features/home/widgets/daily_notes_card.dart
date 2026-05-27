import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_text_styles.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
class DailyNotesCard extends StatelessWidget {
  const DailyNotesCard({super.key});

  static const List<String> _notes = [
    'I did not smoke today.',
    'I had a migraine today so did not work in the second half of the day',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(



      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),

      decoration: BoxDecoration(
        color: AppColors.deepOcean,

        borderRadius: BorderRadius.circular(19.42),

      
        border: Border.all(
          color: AppColors.white.withOpacity(0.3),
          width: 1,
        ),

  
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F0F10).withOpacity(0.10),
            offset: const Offset(0, 19.42),
            blurRadius: 24.28,
            spreadRadius: -4.86,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        
     Row(
  children: [
    SvgPicture.asset(
      "assets/Images/daily_notes.svg",
      width: 18,
      height: 18,
      color: AppColors.white,
    ),
    const SizedBox(width: 8),
    Text(
      'Daily Notes',
      style: AppTextStyles.base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  ],
),

        14.h,


          ..._notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// DOT
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// TEXT
                  Expanded(
                    child: Text(
                      note,
                      style: AppTextStyles.base.copyWith(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white.withOpacity(0.85),
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
}