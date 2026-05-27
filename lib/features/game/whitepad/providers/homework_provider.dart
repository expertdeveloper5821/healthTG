import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/homework_state.dart';
import '../controllers/homework_controller.dart';

final homeworkProvider =
    NotifierProvider<HomeworkController, HomeworkState>(
  HomeworkController.new,
);
