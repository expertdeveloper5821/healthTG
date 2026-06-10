import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:demo_p/health_services.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final HealthService _healthService = HealthService();

  bool _loading = false;
  bool _permissionDenied = false;
  bool _isFetching = false;
  bool _dataLoaded = false;

  int _steps = 0;
  double _heartRate = 0;
  double _activeCalories = 0;
  double _totalCalories = 0;
  double _distance = 0;
  double _sleepHours = 0;
  double _bloodOxygen = 0;
  double _systolic = 0;
  double _diastolic = 0;
  double _temperature = 0;
  double _weight = 0;
  double _height = 0;
  double _bmi = 0;
  double _bloodGlucose = 0;
  double _respiratoryRate = 0;
  double _water = 0;


  Future<bool> requestActivityPermission() async {
    var status = await Permission.activityRecognition.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    await Permission.activityRecognition.request();
    var finalStatus = await Permission.activityRecognition.status;
    return finalStatus.isGranted;
  }


  Future<void> fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    bool available = await _healthService.isAvailable();
    if (!available) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      _isFetching = false;
      return;
    }

    bool activityGranted = await requestActivityPermission();
    if (!activityGranted) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      _isFetching = false;
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    await _healthService.requestPermissions();

    final data = await _healthService.fetchAllData();

    setState(() {
      _steps = data['steps'] ?? 0;
      _heartRate = data['heartRate'] ?? 0.0;
      _activeCalories = data['activeCalories'] ?? 0.0;
      _totalCalories = data['totalCalories'] ?? 0.0;
      _distance = data['distance'] ?? 0.0;
      _sleepHours = data['sleepHours'] ?? 0.0;
      _bloodOxygen = data['bloodOxygen'] ?? 0.0;
      _systolic = data['systolic'] ?? 0.0;
      _diastolic = data['diastolic'] ?? 0.0;
      _temperature = data['temperature'] ?? 0.0;
      _weight = data['weight'] ?? 0.0;
      _height = data['height'] ?? 0.0;
      _bmi = data['bmi'] ?? 0.0;
      _bloodGlucose = data['bloodGlucose'] ?? 0.0;
      _respiratoryRate = data['respiratoryRate'] ?? 0.0;
      _water = data['water'] ?? 0.0;
      _loading = false;
      _dataLoaded = true;
      _permissionDenied = false;
    });

    _isFetching = false;
  }



  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Health Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Today, ${_formatDate(DateTime.now())}",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Steps highlight card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_walk,
                    color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$_steps",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Steps Today",
                      style:
                      TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const Spacer(),
                // Steps progress
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: (_steps / 10000).clamp(0.0, 1.0),
                    backgroundColor: Colors.white30,
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String unit,
    String? subtitle,
  }) {
    bool isEmpty = value == "0" ||
        value == "0.0" ||
        value == "0.00" ||
        value == "--";

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (isEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "No data",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEmpty ? "0" : value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isEmpty ? Colors.grey : Colors.black87,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              color: isEmpty ? Colors.grey : color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureCard() {
    bool isEmpty = _systolic == 0 && _diastolic == 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite,
                    color: Colors.red, size: 22),
              ),
              if (isEmpty)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "No data",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEmpty
                ? "0/0"
                : "${_systolic.toStringAsFixed(0)}/${_diastolic.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isEmpty ? Colors.grey : Colors.black87,
            ),
          ),
          Text(
            "mmHg",
            style: TextStyle(
              fontSize: 11,
              color: isEmpty ? Colors.grey : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Blood Pressure",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Text(
            "Systolic / Diastolic",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  String _bmiLabel(double bmi) {
    if (bmi == 0) return "";
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Health"),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Fetching health data..."),
          ],
        ),
      )
          : !_dataLoaded
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/health_icon.png',
              width: 100,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.health_and_safety,
                size: 100,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your Health Dashboard",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tap below to load your health data\nfrom Health Connect",
              textAlign: TextAlign.center,
              style:
              TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: fetchData,
              icon: const Icon(Icons.sync),
              label: const Text("Load Health Data"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            if (_permissionDenied) ...[
              const SizedBox(height: 16),
              const Text(
                " Permission not granted.\nPlease allow Health Connect access.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Activity ──
                    _sectionTitle("🏃 Activity"),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildCard(
                          icon: Icons.local_fire_department,
                          color: Colors.orange,
                          title: "Active Calories",
                          value: _activeCalories
                              .toStringAsFixed(0),
                          unit: "kcal",
                        ),
                        _buildCard(
                          icon: Icons.whatshot,
                          color: Colors.deepOrange,
                          title: "Total Calories",
                          value: _totalCalories.toStringAsFixed(0),
                          unit: "kcal",
                        ),
                        _buildCard(
                          icon: Icons.social_distance,
                          color: Colors.green,
                          title: "Distance",
                          value: _distance.toStringAsFixed(2),
                          unit: "km",
                        ),
                        _buildCard(
                          icon: Icons.bedtime,
                          color: Colors.indigo,
                          title: "Sleep",
                          value: _sleepHours.toStringAsFixed(1),
                          unit: "hours",
                          subtitle: "Last 7 days avg",
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Vitals ──
                    _sectionTitle("❤️ Vitals"),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildCard(
                          icon: Icons.favorite,
                          color: Colors.red,
                          title: "Heart Rate",
                          value:
                          _heartRate.toStringAsFixed(0),
                          unit: "bpm",
                          subtitle: "Avg today",
                        ),
                        _buildCard(
                          icon: Icons.air,
                          color: Colors.lightBlue,
                          title: "Blood Oxygen",
                          value:
                          _bloodOxygen.toStringAsFixed(1),
                          unit: "SpO2 %",
                        ),
                        _buildBloodPressureCard(),
                        _buildCard(
                          icon: Icons.thermostat,
                          color: Colors.amber,
                          title: "Temperature",
                          value:
                          _temperature.toStringAsFixed(1),
                          unit: "°C",
                        ),
                        _buildCard(
                          icon: Icons.chat??
                              Icons.air,
                          color: Colors.teal,
                          title: "Respiratory Rate",
                          value: _respiratoryRate
                              .toStringAsFixed(0),
                          unit: "breaths/min",
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Body ──
                    _sectionTitle("⚖️ Body"),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildCard(
                          icon: Icons.monitor_weight,
                          color: Colors.purple,
                          title: "Weight",
                          value: _weight.toStringAsFixed(1),
                          unit: "kg",
                        ),
                        _buildCard(
                          icon: Icons.height,
                          color: Colors.cyan,
                          title: "Height",
                          value: _height.toStringAsFixed(2),
                          unit: "m",
                        ),
                        _buildCard(
                          icon: Icons.accessibility_new,
                          color: Colors.pink,
                          title: "BMI",
                          value: _bmi.toStringAsFixed(1),
                          unit: "kg/m²",
                          subtitle: _bmiLabel(_bmi),
                        ),
                        _buildCard(
                          icon: Icons.water_drop,
                          color: Colors.blue,
                          title: "Water",
                          value: _water.toStringAsFixed(2),
                          unit: "liters",
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Medical ──
                    _sectionTitle("🩸 Medical"),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildCard(
                          icon: Icons.bloodtype,
                          color: Colors.red,
                          title: "Blood Glucose",
                          value:
                          _bloodGlucose.toStringAsFixed(1),
                          unit: "mmol/L",
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: fetchData,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh Data"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}