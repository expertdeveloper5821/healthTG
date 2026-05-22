import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();


  final List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.WATER,
  ];


  Future<bool> isAvailable() async {
    try {
      return await _health.isHealthConnectAvailable();
    } catch (e) {
      print(" Availability Error: $e");
      return false;
    }
  }


  Future<bool> requestPermissions() async {
    try {
      await _health.configure();
      await Future.delayed(const Duration(milliseconds: 300));

  
      final permissions = [
        HealthDataAccess.READ_WRITE, // STEPS
        HealthDataAccess.READ_WRITE, // HEART_RATE
        HealthDataAccess.READ_WRITE, // ACTIVE_ENERGY_BURNED
        HealthDataAccess.READ_WRITE, // TOTAL_CALORIES_BURNED
        HealthDataAccess.READ_WRITE, // DISTANCE_WALKING_RUNNING
        HealthDataAccess.READ_WRITE, // SLEEP_ASLEEP
        HealthDataAccess.READ_WRITE, // BLOOD_OXYGEN
        HealthDataAccess.READ_WRITE, // BLOOD_PRESSURE_SYSTOLIC
        HealthDataAccess.READ_WRITE, // BLOOD_PRESSURE_DIASTOLIC
        HealthDataAccess.READ_WRITE, // BODY_TEMPERATURE
        HealthDataAccess.READ_WRITE, // WEIGHT
        HealthDataAccess.READ_WRITE, // HEIGHT
        HealthDataAccess.READ_WRITE, // BODY_MASS_INDEX
        HealthDataAccess.READ_WRITE, // BLOOD_GLUCOSE
        HealthDataAccess.READ_WRITE, // RESPIRATORY_RATE
        HealthDataAccess.READ_WRITE, // WATER
      ];

      print(" Requesting ${types.length} permissions...");

      bool granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      bool hasPermission =
          await _health.hasPermissions(types, permissions: permissions) ??
              false;

      print(" granted: $granted | hasPermission: $hasPermission");
      return granted || hasPermission;
    } catch (e) {
      print("Permission error: $e");
      return false;
    }
  }


  Future<Map<String, dynamic>> fetchAllData() async {
    final Map<String, dynamic> result = {
      'steps': 0,
      'heartRate': 0.0,
      'activeCalories': 0.0,
      'totalCalories': 0.0,
      'distance': 0.0,
      'sleepHours': 0.0,
      'bloodOxygen': 0.0,
      'systolic': 0.0,
      'diastolic': 0.0,
      'temperature': 0.0,
      'weight': 0.0,
      'height': 0.0,
      'bmi': 0.0,
      'bloodGlucose': 0.0,
      'respiratoryRate': 0.0,
      'water': 0.0,
    };

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));

    
      try {
        int? steps = await _health.getTotalStepsInInterval(today, now);
        result['steps'] = steps ?? 0;
        print(" Steps: ${result['steps']}");
      } catch (e) {
        print(" Steps error: $e");
      }

     
      try {
        List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
          types: [
            HealthDataType.HEART_RATE,
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.TOTAL_CALORIES_BURNED,
        
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.BLOOD_OXYGEN,
            HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
            HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
            HealthDataType.BODY_TEMPERATURE,
            HealthDataType.WEIGHT,
            HealthDataType.HEIGHT,
            HealthDataType.BODY_MASS_INDEX,
            HealthDataType.BLOOD_GLUCOSE,
            HealthDataType.RESPIRATORY_RATE,
            HealthDataType.WATER,
          ],
          startTime: weekAgo,
          endTime: now,
        );

        data = _health.removeDuplicates(data);
        print(" Total data points: ${data.length}");

        double heartRateSum = 0, heartRateCount = 0;
        double activeCalSum = 0;
        double totalCalSum = 0;
        double distanceSum = 0;
        double sleepSum = 0;
        double spo2Sum = 0, spo2Count = 0;
        double systolicSum = 0, systolicCount = 0;
        double diastolicSum = 0, diastolicCount = 0;
        double tempSum = 0, tempCount = 0;
        double waterSum = 0;
        double respSum = 0, respCount = 0;

        for (var point in data) {
          double val =
          (point.value as NumericHealthValue).numericValue.toDouble();
          bool isToday = point.dateFrom.isAfter(today);

          switch (point.type) {
            case HealthDataType.HEART_RATE:
              if (isToday) {
                heartRateSum += val;
                heartRateCount++;
              }
              break;
            case HealthDataType.ACTIVE_ENERGY_BURNED:
              if (isToday) activeCalSum += val;
              break;
            case HealthDataType.TOTAL_CALORIES_BURNED:
              if (isToday) totalCalSum += val;
              break;
           
            case HealthDataType.SLEEP_ASLEEP:
              if (!isToday) sleepSum += val;
              break;
            case HealthDataType.BLOOD_OXYGEN:
              if (isToday) {
                spo2Sum += val;
                spo2Count++;
              }
              break;
            case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
              if (isToday) {
                systolicSum += val;
                systolicCount++;
              }
              break;
            case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
              if (isToday) {
                diastolicSum += val;
                diastolicCount++;
              }
              break;
            case HealthDataType.BODY_TEMPERATURE:
              if (isToday) {
                tempSum += val;
                tempCount++;
              }
              break;
            case HealthDataType.WEIGHT:
              result['weight'] = val;
              break;
            case HealthDataType.HEIGHT:
              result['height'] = val;
              break;
            case HealthDataType.BODY_MASS_INDEX:
              result['bmi'] = val;
              break;
            case HealthDataType.BLOOD_GLUCOSE:
              result['bloodGlucose'] = val;
              break;
            case HealthDataType.RESPIRATORY_RATE:
              if (isToday) {
                respSum += val;
                respCount++;
              }
              break;
            case HealthDataType.WATER:
              if (isToday) waterSum += val;
              break;
            default:
              break;
          }
        }

        result['heartRate'] =
        heartRateCount > 0 ? heartRateSum / heartRateCount : 0.0;
        result['activeCalories'] = activeCalSum;
        result['totalCalories'] = totalCalSum;
        result['distance'] = distanceSum / 1000;
        result['sleepHours'] = sleepSum / 60;
        result['bloodOxygen'] =
        spo2Count > 0 ? spo2Sum / spo2Count : 0.0;
        result['systolic'] =
        systolicCount > 0 ? systolicSum / systolicCount : 0.0;
        result['diastolic'] =
        diastolicCount > 0 ? diastolicSum / diastolicCount : 0.0;
        result['temperature'] =
        tempCount > 0 ? tempSum / tempCount : 0.0;
        result['water'] = waterSum;
        result['respiratoryRate'] =
        respCount > 0 ? respSum / respCount : 0.0;
      } catch (e) {
        print(" Data fetch error: $e");
      }
    } catch (e) {
      print(" fetchAllData error: $e");
    }

    print(" Final: $result");
    return result;
  }
}