import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:demo_p/core/widgets/custom_appbar.dart';
import 'package:demo_p/core/widgets/section_header.dart';
import 'package:demo_p/features/home/viewmodel/health_provider.dart';
import 'package:demo_p/features/home/widgets/activity_card.dart';
import 'package:demo_p/features/home/widgets/health_widgets_section.dart';
import 'package:demo_p/features/home/widgets/medication_card.dart';
import 'package:demo_p/features/home/widgets/nutrition_progess_card.dart';
import 'package:demo_p/features/home/widgets/nutrition_section.dart';
import 'package:demo_p/features/home/widgets/vital_header.dart';
import 'package:demo_p/features/home/widgets/vital_sign_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



class HomeScreen extends ConsumerStatefulWidget {
  final int selectedIndex;
  final Function(int) onTopTabTap;

  const HomeScreen({
    super.key,
    required this.selectedIndex,
    required this.onTopTabTap,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  @override
  void initState() {
    super.initState();

  
    Future.microtask(() {
      ref.read(healthProvider.notifier).fetchHealthData();
    });
  }

  @override
  Widget build(BuildContext context) {


    final healthData = ref.watch(healthProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
    appBar: CustomAppBar(
  selectedIndex: widget.selectedIndex,
  onTap: widget.onTopTabTap,
),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               10.h,
              SectionHeader(
                title: "Schedule Exercise",
                onTap: () {},
              ),

              20.h,

              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    ActivityCard(
                      image: "assets/Images/schedule_2.png",
                      title: "Squat Exercise",
                      subtitle: "Mon, Tue, Wed",
                      time: "10:00 AM",
                    ),
                    ActivityCard(
                      image: "assets/Images/schedule_1.png",
                      title: "Squat Exercise",
                      subtitle: "28 march 2026",
                      time: "10:00 AM",
                    ),
                  ],
                ),
              ),

              20.h,

      
              const MedicationCard(),

              20.h,

              const NutritionSection(),

              const SizedBox(height: 20),

              const NutritionProgressCard(),

              const SizedBox(height: 36),

              const VitalHeader(),
              const SizedBox(height: 9),

              VitalSignsCard(data: healthData),

              const SizedBox(height: 9),
              const HealthWidgetsSection(),

              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
    );
  }
}