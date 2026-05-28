import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/vtg_controller.dart';
import '../models/vtg_state.dart';

final vtgProvider = NotifierProvider.autoDispose<VtgController, VtgState>(
  VtgController.new,
);
