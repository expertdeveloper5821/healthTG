import 'package:demo_p/features/game/squat_game/logic/squat_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final squatGameProvider =
    NotifierProvider.autoDispose<SquatController, SquatGameState>(
      SquatController.new,
    );
