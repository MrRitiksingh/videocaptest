class AddTextModel {
  int startFrom;
  int endAt;
  int durationSeconds = 0;
  int x;
  int y;
  String text = "";

  AddTextModel({
    required this.endAt,
    required this.startFrom,
    required this.durationSeconds,
    required this.x,
    required this.y,
    required this.text,
  });

  AddTextModel copyWith({
    int? startFrom,
    int? endAt,
    int? durationSeconds,
    int? x,
    int? y,
    String? text,
  }) {
    return AddTextModel(
      startFrom: startFrom ?? this.startFrom,
      endAt: endAt ?? this.endAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      x: x ?? this.x,
      y: y ?? this.y,
      text: text ?? this.text,
    );
  }
}
