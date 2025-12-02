import 'package:objectbox/objectbox.dart';

// ignore_for_file: public_member_api_docs
// todo: keep track of voice used to generate audio

@Entity()
class GeneratedAudioMeta {
  @Id()
  int id;
  String? prompt;
  String? originalFilePath;
  String? trimmedFilePath;
  String? voice;
  String? gender;

  GeneratedAudioMeta({
    this.id = 0,
    this.prompt,
    this.originalFilePath,
    this.trimmedFilePath,
    this.voice,
    this.gender,
  });
}
