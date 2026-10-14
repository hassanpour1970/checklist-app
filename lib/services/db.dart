import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class DB {
  static late Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        ChecklistGroupSchema,
        ChecklistTemplateSchema,
        ChecklistItemSchema,
        FilledChecklistSchema,
        FilledAnswerSchema,
      ],
      directory: dir.path,
    );
  }
}
