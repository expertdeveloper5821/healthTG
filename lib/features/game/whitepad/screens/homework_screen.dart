import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/whiteboard_enums.dart';
import '../models/stroke_model.dart';
import '../models/shape_model.dart';
import '../models/homework_state.dart';
import '../providers/homework_provider.dart';
import '../providers/whiteboard_provider.dart';
import '../painters/canvas_painter.dart';
import '../painters/grid_painter.dart';
import '../widgets/top_toolbar.dart';
import '../widgets/table_widget.dart';
import '../dialogs/table_dialog.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final AnimationController _submitCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final currentSlide = ref.read(homeworkProvider).currentSlide;
    _pageCtrl = PageController(initialPage: currentSlide);
    _submitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _submitCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _goToPage(int index) {
    ref.read(homeworkProvider.notifier).goToSlide(index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _onTableTap(int slideIndex) async {
    final result = await showTableDialog(context);
    if (result == null || !mounted) return;
    const canvasCenter = Offset(200, 300);
    final table = tableFromResult(result, canvasCenter);
    ref.read(homeworkProvider.notifier).addTable(table);
  }

  Future<void> _submit() async {
    final confirmed = await _showSubmitDialog();
    if (!confirmed || !mounted) return;
    await ref.read(homeworkProvider.notifier).submit();
  }

  Future<bool> _showSubmitDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E2021),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Submit homework?',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
                'Are you sure you want to submit all 5 slides?',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit',
                    style: TextStyle(
                        color: Color(0xFF43C3FF),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final hw = ref.watch(homeworkProvider);

    // Show submit animation overlay
    if (hw.showSubmitAnimation) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: _SubmitSuccessOverlay(
          onDone: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _HomeworkHeader(
            currentSlide: hw.currentSlide,
            totalSlides: kHomeworkSlideCount,
            onClose: () => Navigator.pop(context),
          ),

          // ── Slide progress indicators ──────────────────────────────────────
          _SlideProgressBar(
            currentSlide: hw.currentSlide,
            slides: hw.slides,
            onTap: _goToPage,
          ),

          // ── Toolbar for current slide ──────────────────────────────────────
          _HomeworkToolbar(
            slideIndex: hw.currentSlide,
            onTableTap: () => _onTableTap(hw.currentSlide),
          ),

          // ── Canvas pages ───────────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kHomeworkSlideCount,
              onPageChanged: (i) =>
                  ref.read(homeworkProvider.notifier).goToSlide(i),
              itemBuilder: (context, index) {
                return _HomeworkSlideCanvas(slideIndex: index);
              },
            ),
          ),

          // ── Navigation ─────────────────────────────────────────────────────
          _NavigationBar(
            currentSlide: hw.currentSlide,
            totalSlides: kHomeworkSlideCount,
            onPrev: hw.isFirstSlide ? null : () => _goToPage(hw.currentSlide - 1),
            onNext: hw.isLastSlide ? null : () => _goToPage(hw.currentSlide + 1),
            onSubmit: hw.isLastSlide ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// ── Slide Canvas ──────────────────────────────────────────────────────────────

class _HomeworkSlideCanvas extends ConsumerStatefulWidget {
  final int slideIndex;

  const _HomeworkSlideCanvas({required this.slideIndex});

  @override
  ConsumerState<_HomeworkSlideCanvas> createState() =>
      _HomeworkSlideCanvasState();
}

class _HomeworkSlideCanvasState extends ConsumerState<_HomeworkSlideCanvas> {
  int _activePointers = 0;
  bool _isDrawing = false;
  StrokeModel? _currentStroke;
  ShapeModel? _previewShape;

  // Local canvas transform (independent per slide)
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset? _gestureStartFocal;
  Offset? _gestureStartOffset;
  double? _gestureStartScale;

  Offset _toCanvas(Offset screen) => (screen - _offset) / _scale;

  void _onScaleStart(ScaleStartDetails d) {
    _activePointers = d.pointerCount;
    final hw = ref.read(homeworkProvider);
    final tool = _activeToolForSlide(hw);

    if (_activePointers == 1) {
      _isDrawing = true;
      final pt = _toCanvas(d.localFocalPoint);
      if (tool == DrawingTool.shape) {
        setState(() {
          _previewShape = ShapeModel(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            type: ref.read(whiteboardProvider).activeShape,
            start: pt,
            end: pt,
            color: ref.read(whiteboardProvider).activeColor,
            strokeWidth: ref.read(whiteboardProvider).brushSize,
          );
        });
      } else {
        setState(() {
          _currentStroke = StrokeModel(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            points: [StrokePoint.fromOffset(pt)],
            color: tool == DrawingTool.eraser
                ? Colors.white
                : ref.read(whiteboardProvider).activeColor,
            width: tool == DrawingTool.eraser
                ? ref.read(whiteboardProvider).brushSize * 4
                : ref.read(whiteboardProvider).brushSize,
            isEraser: tool == DrawingTool.eraser,
          );
        });
      }
    } else {
      _isDrawing = false;
      _gestureStartFocal = d.localFocalPoint;
      _gestureStartOffset = _offset;
      _gestureStartScale = _scale;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_isDrawing && d.pointerCount == 1) {
      final pt = _toCanvas(d.localFocalPoint);
      setState(() {
        if (_previewShape != null) {
          _previewShape = _previewShape!.copyWith(end: pt);
        } else if (_currentStroke != null) {
          _currentStroke = _currentStroke!.copyWith(
            points: [..._currentStroke!.points, StrokePoint.fromOffset(pt)],
          );
        }
      });
    } else if (d.pointerCount > 1 && _gestureStartFocal != null) {
      final newScale = (_gestureStartScale! * d.scale).clamp(0.25, 5.0);
      final focalDelta = d.localFocalPoint - _gestureStartFocal!;
      final scaleRatio = newScale / _gestureStartScale!;
      setState(() {
        _scale = newScale;
        _offset = d.localFocalPoint -
            (_gestureStartFocal! - _gestureStartOffset!) * scaleRatio +
            focalDelta -
            d.localFocalPoint +
            _gestureStartFocal!;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_isDrawing) {
      if (_previewShape != null) {
        ref.read(homeworkProvider.notifier).addShape(_previewShape!);
        setState(() => _previewShape = null);
      } else if (_currentStroke != null &&
          _currentStroke!.points.isNotEmpty) {
        ref.read(homeworkProvider.notifier).addStroke(_currentStroke!);
        setState(() => _currentStroke = null);
      } else {
        setState(() {
          _currentStroke = null;
          _previewShape = null;
        });
      }
      _isDrawing = false;
    }
    _gestureStartFocal = null;
    _gestureStartOffset = null;
    _gestureStartScale = null;
    _activePointers = 0;
  }

  DrawingTool _activeToolForSlide(HomeworkState hw) {
    // Homework slides share tool setting from whiteboard provider
    return ref.read(whiteboardProvider).activeTool;
  }

  @override
  Widget build(BuildContext context) {
    final slide = ref.watch(homeworkProvider
        .select((s) => s.slides[widget.slideIndex]));
    final wbState = ref.watch(whiteboardProvider);

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Grid
            if (wbState.showGrid)
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(scale: _scale, offset: _offset),
                ),
              ),
            // Strokes + shapes
            Positioned.fill(
              child: CustomPaint(
                painter: CanvasPainter(
                  strokes: slide.strokes,
                  currentStroke: _currentStroke,
                  shapes: slide.shapes,
                  previewShape: _previewShape,
                  scale: _scale,
                  offset: _offset,
                ),
              ),
            ),
            // Tables
            ...slide.tables.map((table) {
              final screenPos = _offset +
                  Offset(
                    table.position.dx * _scale,
                    table.position.dy * _scale,
                  );
              return Positioned(
                left: screenPos.dx,
                top: screenPos.dy,
                child: Transform.scale(
                  scale: _scale,
                  alignment: Alignment.topLeft,
                  child: TableWidget(
                    table: table,
                    onMove: (delta) {
                      ref
                          .read(homeworkProvider.notifier)
                          .moveTable(table.id, table.position + delta / _scale);
                    },
                    onCellChanged: (r, c, text) => ref
                        .read(homeworkProvider.notifier)
                        .updateTableCell(table.id, r, c, text),
                    onRemove: () => ref
                        .read(homeworkProvider.notifier)
                        .removeTable(table.id),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}



class _HomeworkHeader extends StatelessWidget {
  final int currentSlide;
  final int totalSlides;
  final VoidCallback onClose;

  const _HomeworkHeader({
    required this.currentSlide,
    required this.totalSlides,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, color: Colors.white70, size: 22),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.menu_book_rounded,
                color: Color(0xFF43C3FF), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Homework',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF43C3FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${currentSlide + 1} / $totalSlides',
                style: const TextStyle(
                  color: Color(0xFF43C3FF),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideProgressBar extends StatelessWidget {
  final int currentSlide;
  final List<HomeworkSlideState> slides;
  final ValueChanged<int> onTap;

  const _SlideProgressBar({
    required this.currentSlide,
    required this.slides,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(slides.length, (i) {
          final isCurrent = i == currentSlide;
          final hasContent = !slides[i].isEmpty;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: isCurrent ? 6 : 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF43C3FF)
                      : hasContent
                          ? const Color(0xFF43C3FF).withValues(alpha: 0.4)
                          : Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HomeworkToolbar extends ConsumerWidget {
  final int slideIndex;
  final VoidCallback onTableTap;

  const _HomeworkToolbar({required this.slideIndex, required this.onTableTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slide = ref.watch(
      homeworkProvider.select((s) => s.slides[slideIndex]),
    );
    return TopToolbar(
      onTableTap: onTableTap,
      onClearOverride: () =>
          ref.read(homeworkProvider.notifier).clearCurrentSlide(),
      isCanvasEmpty: slide.isEmpty,
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final int currentSlide;
  final int totalSlides;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;

  const _NavigationBar({
    required this.currentSlide,
    required this.totalSlides,
    required this.onPrev,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            _NavBtn(
              icon: Icons.arrow_back_ios_new,
              label: 'Prev',
              enabled: onPrev != null,
              onTap: onPrev,
            ),
            const Spacer(),
            // Dot indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(totalSlides, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == currentSlide ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == currentSlide
                        ? const Color(0xFF43C3FF)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const Spacer(),
            if (onSubmit != null)
              _SubmitBtn(onTap: onSubmit!)
            else
              _NavBtn(
                icon: Icons.arrow_forward_ios,
                label: 'Next',
                enabled: onNext != null,
                onTap: onNext,
                trailing: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool trailing;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.trailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: trailing
                ? [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Icon(icon, color: Colors.white70, size: 14),
                  ]
                : [
                    Icon(icon, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                  ],
          ),
        ),
      ),
    );
  }
}

class _SubmitBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _SubmitBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF43C3FF), Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF43C3FF).withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Submit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitSuccessOverlay extends StatelessWidget {
  final VoidCallback onDone;

  const _SubmitSuccessOverlay({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF43C3FF), size: 80)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: 700.ms),
          const SizedBox(height: 24),
          const Text(
            'Homework Submitted!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 10),
          const Text(
            'Great work! All 5 slides saved.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF43C3FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF43C3FF).withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Back to Whiteboard',
                style: TextStyle(
                  color: Color(0xFF43C3FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
