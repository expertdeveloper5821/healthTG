import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../model/vehicle_model.dart';

final rushProvider =
    ChangeNotifierProvider<RushProvider>((ref) => RushProvider());

class RushProvider extends ChangeNotifier {
  static const int gridSize = 6;
  static const int exitRow = 2;

  List<VehicleModel> vehicles = [];
  bool isWon = false;
  int moves = 0;

  RushProvider() {
    _init();
  }

  void _init() {
    isWon = false;
    moves = 0;
    vehicles = _generateSolvable();
    notifyListeners();
  }

  void reset() => _init();

  // ── guaranteed-solvable generation ────────────────────────────────────────

  List<VehicleModel> _generateSolvable() {
    final rng = Random();
    for (int attempt = 0; attempt < 60; attempt++) {
      final candidates = _randomLayout(rng);
      if (_isSolvable(candidates)) return candidates;
    }
    return _fallback(); // always solvable
  }

  // ── random layout (5–6 vehicles, only vertical on exit row) ───────────────

  static const _vertSpecs = [
    {'len': 2, 'color': 0xFFFFD700, 'emoji': '🚕'},
    {'len': 2, 'color': 0xFF2196F3, 'emoji': '🚙'},
    {'len': 3, 'color': 0xFFFF6B35, 'emoji': '🚌'},
    {'len': 2, 'color': 0xFFE91E8C, 'emoji': '🚕'},
    {'len': 3, 'color': 0xFF009688, 'emoji': '🚌'},
    {'len': 2, 'color': 0xFF9C27B0, 'emoji': '🚙'},
    {'len': 2, 'color': 0xFF03A9F4, 'emoji': '🚗'},
  ];

  static const _horizSpecs = [
    {'len': 2, 'color': 0xFF4CAF50, 'emoji': '🚗'},
    {'len': 2, 'color': 0xFFFF9800, 'emoji': '🚕'},
    {'len': 3, 'color': 0xFF795548, 'emoji': '🚌'},
    {'len': 2, 'color': 0xFF607D8B, 'emoji': '🚙'},
  ];

  List<VehicleModel> _randomLayout(Random rng) {
    final occupied = <(int, int)>{};
    final result = <VehicleModel>[];

    // Red car: fixed at row 2, col 0, horizontal, length 2
    final red = VehicleModel(
      id: 'red',
      row: exitRow,
      col: 0,
      length: 2,
      isHorizontal: true,
      color: Colors.red,
      emoji: '🚗',
      isRedCar: true,
    );
    result.add(red);
    for (final c in red.cells) occupied.add(c);

    // Place 2–3 vertical blockers covering the exit row
    final blockerCols = [2, 3, 4, 5]..shuffle(rng);
    final wantBlockers = 2 + rng.nextInt(2);
    int placed = 0;

    for (final col in blockerCols) {
      if (placed >= wantBlockers) break;
      final spec = _vertSpecs[rng.nextInt(_vertSpecs.length)];
      final len = spec['len'] as int;
      final minR = (exitRow - len + 1).clamp(0, gridSize - len);
      final maxR = exitRow.clamp(0, gridSize - len);
      if (minR > maxR) continue;
      final row = minR + rng.nextInt(maxR - minR + 1);

      final v = VehicleModel(
        id: 'b$placed',
        row: row, col: col,
        length: len, isHorizontal: false,
        color: Color(spec['color'] as int),
        emoji: spec['emoji'] as String,
      );
      if (v.cells.every((c) => !occupied.contains(c))) {
        result.add(v);
        for (final c in v.cells) occupied.add(c);
        placed++;
      }
    }

    // Fill to 5 or 6 total, no horizontal on exit row
    final target = 5 + rng.nextInt(2);
    final vSpecs = List.of(_vertSpecs)..shuffle(rng);
    final hSpecs = List.of(_horizSpecs)..shuffle(rng);
    final extras = [...vSpecs, ...hSpecs]..shuffle(rng);

    for (final spec in extras) {
      if (result.length >= target) break;
      final len = spec['len'] as int;
      final horiz = _horizSpecs.contains(spec);

      for (int t = 0; t < 80; t++) {
        final maxR = gridSize - (horiz ? 1 : len);
        final maxC = gridSize - (horiz ? len : 1);
        final row = rng.nextInt(maxR + 1);
        final col = rng.nextInt(maxC + 1);
        if (horiz && row == exitRow) continue;

        final v = VehicleModel(
          id: 'x${result.length}',
          row: row, col: col,
          length: len, isHorizontal: horiz,
          color: Color(spec['color'] as int),
          emoji: spec['emoji'] as String,
        );
        if (v.cells.every((c) => !occupied.contains(c))) {
          result.add(v);
          for (final c in v.cells) occupied.add(c);
          break;
        }
      }
    }

    return result;
  }

  // ── BFS solvability check ─────────────────────────────────────────────────

  bool _isSolvable(List<VehicleModel> initial) {
    final redIdx = initial.indexWhere((v) => v.isRedCar);
    if (redIdx == -1) return false;
    final winPos = gridSize - initial[redIdx].length; // col=4 for len=2

    final startPos = initial.map((v) => v.isHorizontal ? v.col : v.row).toList();
    if (startPos[redIdx] == winPos) return true;

    final queue = <List<int>>[startPos];
    int head = 0;
    final visited = <String>{startPos.join(',')};

    while (head < queue.length) {
      final pos = queue[head++];

      for (int i = 0; i < initial.length; i++) {
        final v = initial[i];
        final cur = pos[i];
        final maxP = gridSize - v.length;

        for (final dir in [-1, 1]) {
          for (int s = 1; s <= maxP; s++) {
            final next = cur + dir * s;
            if (next < 0 || next > maxP) break;

            // Leading-edge cell for this step
            final leadR = v.isHorizontal
                ? v.row
                : (dir > 0 ? next + v.length - 1 : next);
            final leadC = v.isHorizontal
                ? (dir > 0 ? next + v.length - 1 : next)
                : v.col;

            // Check every other vehicle for collision
            bool blocked = false;
            outer:
            for (int j = 0; j < initial.length; j++) {
              if (j == i) continue;
              final ov = initial[j];
              final op = pos[j];
              for (int k = 0; k < ov.length; k++) {
                final or_ = ov.isHorizontal ? ov.row : op + k;
                final oc = ov.isHorizontal ? op + k : ov.col;
                if (or_ == leadR && oc == leadC) {
                  blocked = true;
                  break outer;
                }
              }
            }
            if (blocked) break;

            if (i == redIdx && next == winPos) return true;

            final newPos = List<int>.from(pos)..[i] = next;
            final key = newPos.join(',');
            if (!visited.contains(key)) {
              visited.add(key);
              queue.add(newPos);
            }
          }
        }
      }
    }
    return false;
  }

  // ── fallback: simple hand-crafted solvable puzzle (5 vehicles) ────────────

  List<VehicleModel> _fallback() => [
    VehicleModel(id: 'red', row: 2, col: 0, length: 2, isHorizontal: true,
        color: Colors.red, emoji: '🚗', isRedCar: true),
    VehicleModel(id: 'b0', row: 1, col: 2, length: 2, isHorizontal: false,
        color: const Color(0xFFFFD700), emoji: '🚕'),
    VehicleModel(id: 'b1', row: 2, col: 3, length: 2, isHorizontal: false,
        color: const Color(0xFF2196F3), emoji: '🚙'),
    VehicleModel(id: 'b2', row: 1, col: 4, length: 2, isHorizontal: false,
        color: const Color(0xFFE91E8C), emoji: '🚕'),
    VehicleModel(id: 'x0', row: 4, col: 1, length: 2, isHorizontal: true,
        color: const Color(0xFF4CAF50), emoji: '🚗'),
  ];

  // ── movement ──────────────────────────────────────────────────────────────

  Set<(int, int)> _occupiedExcluding(String id) => vehicles
      .where((v) => v.id != id)
      .expand((v) => v.cells)
      .toSet();

  int _reachable(VehicleModel v, int from, int desired, Set<(int, int)> occ) {
    if (desired == from) return from;
    final dir = (desired - from).sign;
    int pos = from;
    for (int step = 1; step <= (desired - from).abs(); step++) {
      final next = from + dir * step;
      if (v.isHorizontal) {
        if (next < 0 || next + v.length - 1 >= gridSize) break;
        final edge = dir > 0 ? next + v.length - 1 : next;
        if (occ.contains((v.row, edge))) break;
      } else {
        if (next < 0 || next + v.length - 1 >= gridSize) break;
        final edge = dir > 0 ? next + v.length - 1 : next;
        if (occ.contains((edge, v.col))) break;
      }
      pos = next;
    }
    return pos;
  }

  /// Returns the actual new position after the move (may equal current if blocked).
  int dragVehicle({
    required String vehicleId,
    required int startCol,
    required int startRow,
    required int deltaCols,
    required int deltaRows,
  }) {
    final idx = vehicles.indexWhere((v) => v.id == vehicleId);
    if (idx == -1 || isWon) return -1;

    final v = vehicles[idx];
    final occ = _occupiedExcluding(vehicleId);

    if (v.isHorizontal) {
      final desired = (startCol + deltaCols).clamp(0, gridSize - v.length);
      final actual = _reachable(v, startCol, desired, occ);
      if (actual != v.col) {
        moves++;
        vehicles[idx] = v.copyWith(col: actual);
        if (v.isRedCar && actual == gridSize - v.length) isWon = true;
        notifyListeners();
      }
      return actual;
    } else {
      final desired = (startRow + deltaRows).clamp(0, gridSize - v.length);
      final actual = _reachable(v, startRow, desired, occ);
      if (actual != v.row) {
        moves++;
        vehicles[idx] = v.copyWith(row: actual);
        notifyListeners();
      }
      return actual;
    }
  }
}
