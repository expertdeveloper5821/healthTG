import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/vehicle_model.dart';
import '../provider/rush_provider.dart';

class RushScreen extends ConsumerStatefulWidget {
  final bool isPaused;

  const RushScreen({super.key, this.isPaused = false});

  @override
  ConsumerState<RushScreen> createState() => _RushScreenState();
}

class _RushScreenState extends ConsumerState<RushScreen> {
  // Per-drag tracking
  String? _draggingId;
  int _dragStartCol = 0;
  int _dragStartRow = 0;
  double _accumDx = 0;
  double _accumDy = 0;

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(rushProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Traffic Jam',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Moves: ${game.moves}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Instruction banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🚗', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text(
                        'Slide the RED car to the EXIT',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.red, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 64),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellSize = constraints.maxWidth / RushProvider.gridSize;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _Board(cellSize: cellSize),
                          _ExitArrow(cellSize: cellSize),
                          ...game.vehicles.map(
                            (v) => _VehicleTile(
                              key: ValueKey(v.id),
                              vehicle: v,
                              cellSize: cellSize,
                              isDragging: _draggingId == v.id,
                              onDragStart: (details) {
                                if (widget.isPaused) return;
                                _draggingId = v.id;
                                _dragStartCol = v.col;
                                _dragStartRow = v.row;
                                _accumDx = 0;
                                _accumDy = 0;
                              },
                              onDragUpdate: (details) {
                                if (widget.isPaused) return;
                                if (_draggingId != v.id) return;
                                _accumDx += details.delta.dx;
                                _accumDy += details.delta.dy;
                                final deltaCols = (_accumDx / cellSize).round();
                                final deltaRows = (_accumDy / cellSize).round();
                                ref.read(rushProvider).dragVehicle(
                                  vehicleId: v.id,
                                  startCol: _dragStartCol,
                                  startRow: _dragStartRow,
                                  deltaCols: deltaCols,
                                  deltaRows: deltaRows,
                                );
                              },
                              onDragEnd: (_) {
                                setState(() => _draggingId = null);
                              },
                            ),
                          ),
                          if (game.isWon) _WinOverlay(onPlay: () => ref.read(rushProvider).reset()),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.isPaused ? null : () => ref.read(rushProvider).reset(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A3E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Reset', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ── Board background ──────────────────────────────────────────────────────────

class _Board extends StatelessWidget {
  const _Board({required this.cellSize});
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final n = RushProvider.gridSize;
    final size = cellSize * n;
    return CustomPaint(
      size: Size(size, size),
      painter: _GridPainter(n: n, cellSize: cellSize),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.n, required this.cellSize});
  final int n;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF5EFD6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bgPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFCBC29A)
      ..strokeWidth = 1;

    for (int i = 1; i < n; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final borderPaint = Paint()
      ..color = const Color(0xFF8B7D55)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Exit arrow ────────────────────────────────────────────────────────────────

class _ExitArrow extends StatefulWidget {
  const _ExitArrow({required this.cellSize});
  final double cellSize;

  @override
  State<_ExitArrow> createState() => _ExitArrowState();
}

class _ExitArrowState extends State<_ExitArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exitRow = RushProvider.exitRow;
    final boardWidth = widget.cellSize * RushProvider.gridSize;
    return Positioned(
      left: boardWidth + 4,
      top: exitRow * widget.cellSize,
      width: 56,
      height: widget.cellSize,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1 + 0.15 * _pulse.value),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5 + 0.5 * _pulse.value),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.red.withValues(alpha: 0.6 + 0.4 * _pulse.value),
                  size: widget.cellSize * 0.48),
              Text(
                'EXIT',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: widget.cellSize * 0.18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vehicle tile ──────────────────────────────────────────────────────────────

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    super.key,
    required this.vehicle,
    required this.cellSize,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final VehicleModel vehicle;
  final double cellSize;
  final bool isDragging;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    const double pad = 4.0;
    final double w = vehicle.isHorizontal
        ? cellSize * vehicle.length - pad * 2
        : cellSize - pad * 2;
    final double h = vehicle.isHorizontal
        ? cellSize - pad * 2
        : cellSize * vehicle.length - pad * 2;

    // Base emoji text — very large so FittedBox fills the whole background
    Widget emojiWidget = Text(
      vehicle.emoji,
      style: const TextStyle(fontSize: 256, height: 1.0),
    );

    // Vertical vehicles: quarter-turn so the car faces downward
    if (!vehicle.isHorizontal) {
      emojiWidget = RotatedBox(quarterTurns: 1, child: emojiWidget);
    }

    // Red car: mirror so its front faces LEFT toward the exit arrow
    if (vehicle.isRedCar) {
      emojiWidget = Transform.scale(scaleX: -1.0, child: emojiWidget);
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 80),
      left: vehicle.col * cellSize + pad,
      top: vehicle.row * cellSize + pad,
      width: w,
      height: h,
      child: GestureDetector(
        onPanStart: onDragStart,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: vehicle.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDragging
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              width: isDragging ? 3.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: vehicle.color.withValues(alpha: isDragging ? 0.7 : 0.45),
                blurRadius: isDragging ? 16 : 8,
                spreadRadius: isDragging ? 3 : 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: FittedBox(
              fit: BoxFit.contain,
              child: emojiWidget,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Win overlay ───────────────────────────────────────────────────────────────

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text(
              'You Win!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Red car escaped!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Play Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
