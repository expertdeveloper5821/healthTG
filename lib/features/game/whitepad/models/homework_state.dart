import 'stroke_model.dart';
import 'shape_model.dart';
import 'table_model.dart';
import 'whiteboard_enums.dart';

const int kHomeworkSlideCount = 5;

class HomeworkSlideState {
  final List<StrokeModel> strokes;
  final List<ShapeModel> shapes;
  final List<TableModel> tables;

  const HomeworkSlideState({
    this.strokes = const [],
    this.shapes = const [],
    this.tables = const [],
  });

  factory HomeworkSlideState.empty() => const HomeworkSlideState();

  bool get isEmpty => strokes.isEmpty && shapes.isEmpty && tables.isEmpty;

  HomeworkSlideState copyWith({
    List<StrokeModel>? strokes,
    List<ShapeModel>? shapes,
    List<TableModel>? tables,
  }) =>
      HomeworkSlideState(
        strokes: strokes ?? this.strokes,
        shapes: shapes ?? this.shapes,
        tables: tables ?? this.tables,
      );

  Map<String, dynamic> toJson() => {
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'shapes': shapes.map((s) => s.toJson()).toList(),
        'tables': tables.map((t) => t.toJson()).toList(),
      };

  factory HomeworkSlideState.fromJson(Map<String, dynamic> j) =>
      HomeworkSlideState(
        strokes: (j['strokes'] as List)
            .map((s) => StrokeModel.fromJson(s as Map<String, dynamic>))
            .toList(),
        shapes: (j['shapes'] as List)
            .map((s) => ShapeModel.fromJson(s as Map<String, dynamic>))
            .toList(),
        tables: (j['tables'] as List)
            .map((t) => TableModel.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

class HomeworkState {
  final int currentSlide;
  final List<HomeworkSlideState> slides;
  final HomeworkStatus status;
  final bool isLoading;
  final bool showSubmitAnimation;

  const HomeworkState({
    this.currentSlide = 0,
    required this.slides,
    this.status = HomeworkStatus.notStarted,
    this.isLoading = false,
    this.showSubmitAnimation = false,
  });

  factory HomeworkState.initial() => HomeworkState(
        slides: List.generate(kHomeworkSlideCount, (_) => HomeworkSlideState.empty()),
      );

  HomeworkSlideState get currentSlideState => slides[currentSlide];

  bool get isLastSlide => currentSlide == kHomeworkSlideCount - 1;
  bool get isFirstSlide => currentSlide == 0;
  bool get isSubmitted => status == HomeworkStatus.submitted;

  int get completedSlides =>
      slides.where((s) => !s.isEmpty).length;

  HomeworkState copyWith({
    int? currentSlide,
    List<HomeworkSlideState>? slides,
    HomeworkStatus? status,
    bool? isLoading,
    bool? showSubmitAnimation,
  }) =>
      HomeworkState(
        currentSlide: currentSlide ?? this.currentSlide,
        slides: slides ?? this.slides,
        status: status ?? this.status,
        isLoading: isLoading ?? this.isLoading,
        showSubmitAnimation: showSubmitAnimation ?? this.showSubmitAnimation,
      );

  HomeworkState updateSlide(int index, HomeworkSlideState slide) {
    final updated = List<HomeworkSlideState>.from(slides);
    updated[index] = slide;
    return copyWith(slides: updated);
  }

  Map<String, dynamic> toJson() => {
        'currentSlide': currentSlide,
        'slides': slides.map((s) => s.toJson()).toList(),
        'status': status.index,
      };

  factory HomeworkState.fromJson(Map<String, dynamic> j) => HomeworkState(
        currentSlide: j['currentSlide'] as int? ?? 0,
        slides: (j['slides'] as List)
            .map((s) => HomeworkSlideState.fromJson(s as Map<String, dynamic>))
            .toList(),
        status: HomeworkStatus.values[j['status'] as int? ?? 0],
      );
}
