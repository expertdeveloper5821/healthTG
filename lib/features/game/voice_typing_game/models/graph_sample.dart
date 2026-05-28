import 'vtg_enums.dart';

class GraphSample {
  final double value;
  final DateTime timestamp;
  final ZoneStatus zoneStatus;

  const GraphSample({
    required this.value,
    required this.timestamp,
    required this.zoneStatus,
  });
}
