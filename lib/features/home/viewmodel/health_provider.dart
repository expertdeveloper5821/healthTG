import 'package:demo_p/health_services.dart';
import 'package:flutter_riverpod/legacy.dart';


final healthProvider =
    StateNotifierProvider<HealthNotifier, Map<String, dynamic>>((ref) {
  return HealthNotifier();
});

class HealthNotifier extends StateNotifier<Map<String, dynamic>> {
  final HealthService _service = HealthService();

  HealthNotifier() : super({});

  bool isLoading = false;

  Future<void> fetchHealthData() async {
    if (isLoading) return;
    isLoading = true;

    try {
      bool available = await _service.isAvailable();
      if (!available) return;

      await _service.requestPermissions();

      final data = await _service.fetchAllData();

      state = data; 
    } catch (e) {
      print("Provider error: $e");
    }

    isLoading = false;
  }
}