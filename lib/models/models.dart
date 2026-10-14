import 'package:isar/isar.dart';

part 'models.g.dart';

@collection
class ChecklistGroup {
  Id id = Isar.autoIncrement;
  late String name;
}

@collection
class ChecklistTemplate {
  Id id = Isar.autoIncrement;
  late String name;
  late int groupId;
  final items = IsarLinks<ChecklistItem>();
}

@collection
class ChecklistItem {
  Id id = Isar.autoIncrement;
  late String title;
  @enumerated
  late ItemType type;
  List<String> options = [];
}

enum ItemType {
  check,
  text,
  radio,
  combo,
  date,
}

@collection
class FilledChecklist {
  Id id = Isar.autoIncrement;
  late int templateId;
  late DateTime createdAt;
  final answers = IsarLinks<FilledAnswer>();
}

@collection
class FilledAnswer {
  Id id = Isar.autoIncrement;
  late int itemId;
  bool? checkValue;
  String? textValue;
  String? selectedOption;
  DateTime? dateValue;
}
