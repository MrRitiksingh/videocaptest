class VideoGptModel {
  VideoGptModel({
    this.input,
    this.data,
    required this.generateAudio,
    required this.generateText,
  });

  VideoGptModel.fromJson(dynamic json) {
    input = json['input'];
    generateText = json['generateText'];
    generateAudio = json['generateAudio'];
    if (json['data'] != null) {
      data = [];
      json['data'].forEach((v) {
        data?.add(Data.fromJson(v));
      });
    }
  }

  String? input;
  List<Data>? data;
  bool generateText = true;
  bool generateAudio = true;

  VideoGptModel copyWith({
    String? input,
    List<Data>? data,
    bool? generateText,
    bool? generateAudio,
  }) =>
      VideoGptModel(
        input: input ?? this.input,
        data: data ?? this.data,
        generateText: generateText ?? this.generateText,
        generateAudio: generateAudio ?? this.generateAudio,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['input'] = input;
    map['generateText'] = generateText;
    map['generateAudio'] = generateAudio;
    if (data != null) {
      map['data'] = data?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class Data {
  Data({
    this.prompt,
    this.pexels,
    this.video,
    this.generatedAudioId,
  });

  Data.fromJson(dynamic json) {
    prompt = json['prompt'];
    pexels = json['pexels'];
    video = json['video'] != null ? Video.fromJson(json['video']) : null;
    generatedAudioId = json['generated_audio_id'];
  }

  String? prompt;
  String? pexels;
  Video? video;
  int? generatedAudioId;

  Data copyWith({
    String? prompt,
    String? pexels,
    Video? video,
    int? generatedAudioId,
  }) =>
      Data(
        prompt: prompt ?? this.prompt,
        pexels: pexels ?? this.pexels,
        video: video ?? this.video,
        generatedAudioId: generatedAudioId ?? this.generatedAudioId,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['prompt'] = prompt;
    map['pexels'] = pexels;
    if (video != null) {
      map['video'] = video?.toJson();
    }
    map['generated_audio_id'] = generatedAudioId;
    return map;
  }
}

class Video {
  Video({
    this.id,
    this.width,
    this.height,
    this.duration,
    this.fullRes,
    this.tags,
    this.url,
    this.image,
    this.avgColor,
    this.user,
    this.videoFiles,
    this.videoPictures,
  });

  Video.fromJson(dynamic json) {
    id = json['id'];
    width = json['width'];
    height = json['height'];
    duration = json['duration'];
    fullRes = json['full_res'];
    // if (json['tags'] != null) {
    //   tags = [];
    //   json['tags'].forEach((v) {
    //     tags?.add(Dynamic.fromJson(v));
    //   });
    // }
    url = json['url'];
    image = json['image'];
    avgColor = json['avg_color'];
    user = json['user'] != null ? User.fromJson(json['user']) : null;
    if (json['video_files'] != null) {
      videoFiles = [];
      json['video_files'].forEach((v) {
        videoFiles?.add(VideoFiles.fromJson(v));
      });
    }
    if (json['video_pictures'] != null) {
      videoPictures = [];
      json['video_pictures'].forEach((v) {
        videoPictures?.add(VideoPictures.fromJson(v));
      });
    }
  }

  num? id;
  num? width;
  num? height;
  num? duration;
  dynamic fullRes;
  List<dynamic>? tags;
  String? url;
  String? image;
  dynamic avgColor;
  User? user;
  List<VideoFiles>? videoFiles;
  List<VideoPictures>? videoPictures;

  Video copyWith({
    num? id,
    num? width,
    num? height,
    num? duration,
    dynamic fullRes,
    List<dynamic>? tags,
    String? url,
    String? image,
    dynamic avgColor,
    User? user,
    List<VideoFiles>? videoFiles,
    List<VideoPictures>? videoPictures,
  }) =>
      Video(
        id: id ?? this.id,
        width: width ?? this.width,
        height: height ?? this.height,
        duration: duration ?? this.duration,
        fullRes: fullRes ?? this.fullRes,
        tags: tags ?? this.tags,
        url: url ?? this.url,
        image: image ?? this.image,
        avgColor: avgColor ?? this.avgColor,
        user: user ?? this.user,
        videoFiles: videoFiles ?? this.videoFiles,
        videoPictures: videoPictures ?? this.videoPictures,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['width'] = width;
    map['height'] = height;
    map['duration'] = duration;
    map['full_res'] = fullRes;
    if (tags != null) {
      map['tags'] = tags?.map((v) => v.toJson()).toList();
    }
    map['url'] = url;
    map['image'] = image;
    map['avg_color'] = avgColor;
    if (user != null) {
      map['user'] = user?.toJson();
    }
    if (videoFiles != null) {
      map['video_files'] = videoFiles?.map((v) => v.toJson()).toList();
    }
    if (videoPictures != null) {
      map['video_pictures'] = videoPictures?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class VideoPictures {
  VideoPictures({
    this.id,
    this.nr,
    this.picture,
  });

  VideoPictures.fromJson(dynamic json) {
    id = json['id'];
    nr = json['nr'];
    picture = json['picture'];
  }

  num? id;
  num? nr;
  String? picture;

  VideoPictures copyWith({
    num? id,
    num? nr,
    String? picture,
  }) =>
      VideoPictures(
        id: id ?? this.id,
        nr: nr ?? this.nr,
        picture: picture ?? this.picture,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['nr'] = nr;
    map['picture'] = picture;
    return map;
  }
}

class VideoFiles {
  VideoFiles({
    this.id,
    this.quality,
    this.fileType,
    this.width,
    this.height,
    this.fps,
    this.link,
    this.size,
  });

  VideoFiles.fromJson(dynamic json) {
    id = json['id'];
    quality = json['quality'];
    fileType = json['file_type'];
    width = json['width'];
    height = json['height'];
    fps = json['fps'];
    link = json['link'];
    size = json['size'];
  }

  num? id;
  String? quality;
  String? fileType;
  num? width;
  num? height;
  num? fps;
  String? link;
  num? size;

  VideoFiles copyWith({
    num? id,
    String? quality,
    String? fileType,
    num? width,
    num? height,
    num? fps,
    String? link,
    num? size,
  }) =>
      VideoFiles(
        id: id ?? this.id,
        quality: quality ?? this.quality,
        fileType: fileType ?? this.fileType,
        width: width ?? this.width,
        height: height ?? this.height,
        fps: fps ?? this.fps,
        link: link ?? this.link,
        size: size ?? this.size,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['quality'] = quality;
    map['file_type'] = fileType;
    map['width'] = width;
    map['height'] = height;
    map['fps'] = fps;
    map['link'] = link;
    map['size'] = size;
    return map;
  }
}

class User {
  User({
    this.id,
    this.name,
    this.url,
  });

  User.fromJson(dynamic json) {
    id = json['id'];
    name = json['name'];
    url = json['url'];
  }

  num? id;
  String? name;
  String? url;

  User copyWith({
    num? id,
    String? name,
    String? url,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        url: url ?? this.url,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['url'] = url;
    return map;
  }
}
