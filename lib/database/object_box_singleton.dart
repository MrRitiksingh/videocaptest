import 'package:ai_video_creator_editor/database/models/generated_audio_meta.dart';
import 'package:ai_video_creator_editor/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ObjectBoxSingleTon {
  static late final ObjectBoxSingleTon instance;

  late final Store _store;
  late final Box<GeneratedAudioMeta> _generatedAudioMetaBox;

  ObjectBoxSingleTon._create(this._store) {
    _generatedAudioMetaBox = Box<GeneratedAudioMeta>(_store);
  }

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = await openStore(
      directory: p.join(dir.path, "obx-box"),
      macosApplicationGroup: "objectbox.database",
    );
    instance = ObjectBoxSingleTon._create(store);
  }

  Future<bool> doesGeneratedAudioMetaExist(int? id) async {
    if (id == null) return false;
    return await _generatedAudioMetaBox.contains(id);
  }

  Future<GeneratedAudioMeta?> getGeneratedAudioMeta(int id) =>
      _generatedAudioMetaBox.getAsync(id);

  Future<int> putGeneratedAudioMeta(GeneratedAudioMeta generatedAudioMeta) =>
      _generatedAudioMetaBox.putAsync(generatedAudioMeta);

  Future<bool> removeGeneratedAudioMeta(int id) =>
      _generatedAudioMetaBox.removeAsync(id);
}
