import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whiteboard_state.dart';
import '../controllers/whiteboard_controller.dart';

final whiteboardProvider =
    NotifierProvider<WhiteboardController, WhiteboardState>(
  WhiteboardController.new,
);
