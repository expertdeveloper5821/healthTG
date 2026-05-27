import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/whiteboard_enums.dart';
import '../providers/whiteboard_provider.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/top_toolbar.dart';
import '../dialogs/table_dialog.dart';
import 'homework_screen.dart';

class WhiteboardScreen extends ConsumerStatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  ConsumerState<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends ConsumerState<WhiteboardScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _onTableTap() async {
    final result = await showTableDialog(context);
    if (result == null || !mounted) return;
    final state = ref.read(whiteboardProvider);
    // Place table at current visible center of canvas
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final canvasCenter = (screenCenter - state.canvasOffset) / state.canvasScale;
    final table = tableFromResult(result, canvasCenter);
    ref.read(whiteboardProvider.notifier).addTable(table);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          // ── Canvas ────────────────────────────────────────────────────────
          Positioned.fill(child: DrawingCanvas()),

          // ── Loading overlay ───────────────────────────────────────────────
          if (state.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF43C3FF),
                  ),
                ),
              ),
            ),

          // ── Top toolbar ───────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ScrollableToolbar(onTableTap: _onTableTap)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.3, end: 0, duration: 300.ms),
          ),

       

          // ── Tool active label ──────────────────────────────────────────────
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _ToolLabel(tool: state.activeTool, key: ValueKey(state.activeTool)),
              ),
            ),
          ),

          // ── Zoom indicator ─────────────────────────────────────────────────
          if (state.canvasScale != 1.0)
            Positioned(
              bottom: 90,
              right: 16,
              child: _ZoomBadge(scale: state.canvasScale),
            ),

          // ── Homework FAB ───────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            right: 16,
            child: SafeArea(
              child: _HomeworkFAB()
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms)
                  .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _ScrollableToolbar extends StatelessWidget {
  final VoidCallback onTableTap;

  const _ScrollableToolbar({required this.onTableTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56), // leave space for back btn
      child: TopToolbar(onTableTap: onTableTap),
    );
  }
}

class _FloatingIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2021).withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }
}

class _ToolLabel extends StatelessWidget {
  final DrawingTool tool;

  const _ToolLabel({required this.tool, super.key});

  String get _label => switch (tool) {
        DrawingTool.pencil => 'Pencil',
        DrawingTool.eraser => 'Eraser',
        DrawingTool.shape => 'Shape',
        DrawingTool.table => 'Table',
      };

  IconData get _icon => switch (tool) {
        DrawingTool.pencil => Icons.edit,
        DrawingTool.eraser => Icons.auto_fix_normal,
        DrawingTool.shape => Icons.category_outlined,
        DrawingTool.table => Icons.grid_on,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2021).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: const Color(0xFF43C3FF), size: 14),
          const SizedBox(width: 6),
          Text(
            _label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  final double scale;

  const _ZoomBadge({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2021).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(scale * 100).round()}%',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeworkFAB extends ConsumerWidget {
  const _HomeworkFAB();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HomeworkScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF43C3FF), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF43C3FF).withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'HOMEWORK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
