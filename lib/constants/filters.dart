class FFmpegFilter {
  final String name;
  final String description;
  final String command;
  bool isSelected;

  FFmpegFilter({
    required this.name,
    required this.description,
    required this.command,
    this.isSelected = false,
  });

  // copyWith method
  FFmpegFilter copyWith({
    String? name,
    String? description,
    String? command,
    bool? isSelected,
  }) {
    return FFmpegFilter(
      name: name ?? this.name,
      description: description ?? this.description,
      command: command ?? this.command,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

final List<FFmpegFilter> videoFfmpegFilters = [
  FFmpegFilter(
    name: 'Blur',
    description: 'Apply Gaussian blur to the video',
    command: 'boxblur=2:1',
  ),
  FFmpegFilter(
    name: 'Brightness',
    description: 'Adjust video brightness',
    command: 'eq=brightness=0.2',
  ),
  FFmpegFilter(
    name: 'Contrast',
    description: 'Adjust video contrast',
    command: 'eq=contrast=1.5',
  ),
  FFmpegFilter(
    name: 'Saturation',
    description: 'Adjust color saturation',
    command: 'eq=saturation=2',
  ),
  FFmpegFilter(
    name: 'Sharpen',
    description: 'Sharpen the video',
    command: 'unsharp=5:5:1:5:5:0',
  ),
  FFmpegFilter(
    name: 'Noise Reduction',
    description: 'Remove video noise',
    command: 'nlmeans=10:7:5:3:3',
  ),
  FFmpegFilter(
    name: 'Rotate',
    description: 'Rotate video 90 degrees clockwise',
    command: 'transpose=1',
  ),
  FFmpegFilter(
    name: 'Mirror',
    description: 'Flip video horizontally',
    command: 'hflip',
  ),
  // FFmpegFilter(
  //   name: 'Sepia',
  //   description: 'Apply sepia tone effect',
  //   command: 'colorize=hue=30:saturation=0.8:brightness=0.8',
  // ),
  // FFmpegFilter(
  //   name: 'Sepia',
  //   description: 'Apply sepia tone effect',
  //   command:
  //       'colorbalance=rs=.393:gs=.769:bs=.189:rm=.349:gm=.686:bm=.168:rh=.272:gh=.534:bh=.131',
  // ),
  FFmpegFilter(
    name: 'Vignette',
    description: 'Add vignette effect',
    command: 'vignette=PI/4',
  ),
];
