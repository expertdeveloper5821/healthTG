import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_text_styles.dart';
import 'package:demo_p/core/utils/extensions.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 366,
      height: 245,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: AppColors.blueCardGradient,
        borderRadius: BorderRadius.circular(11.65),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  "assets/Images/medication.svg",
                  width: 20,
                  height: 20,
                ),
                8.w,
                Text(
                  "Medication",
                  style: AppTextStyles.medicationHeader,
                ),
                const Spacer(),
                Text(
                  "See All",
                  style: AppTextStyles.seeAll,
                ),
              ],
            ),
          ),

          12.h,

        
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              physics: const ClampingScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const _MedicineItem(),
            ),
          ),

          24.h,

      
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              height: 31.08,
              decoration: BoxDecoration(
                color: AppColors.deepOcean,
                borderRadius: BorderRadius.circular(19.42),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    offset: const Offset(0, 1.94),
                    blurRadius: 2.91,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Morning Medicines Taken",
                  style: AppTextStyles.medicationButton,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineItem extends StatelessWidget {
  const _MedicineItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 147,
      height: 115,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 65,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      "assets/Images/medicine.png",
                      width: 61,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              10.h,

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "Omeprazole ",
                            style: AppTextStyles.medicationTitle,
                          ),
                          TextSpan(
                            text: "50 mg",
                            style: AppTextStyles.medicationDose,
                          ),
                        ],
                      ),
                    ),
                    5.h,
                    Text(
                      "Omeprazole Magnesium",
                      style: AppTextStyles.medicationSubtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),

          Positioned(
            top: 7,
            right: 7,
            child: Container(
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF59C9FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child:  Center(
                child: Text(
                  "Stomach",
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: AppColors.black,
                    fontFamily: "Mulish",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}