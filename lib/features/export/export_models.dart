import '../../domain/field_types.dart';

/// مدل ساده و مستقل از دیتابیس برای ساخت خروجی
class ExportField {
  ExportField({
    required this.stableKey,
    required this.label,
    required this.type,
    required this.isRequired,
    required this.value,
  });
  final String stableKey;
  final String label;
  final FieldType type;
  final bool isRequired;
  final String? value;
}

class ExportSection {
  ExportSection(this.title, this.fields);
  final String title;
  final List<ExportField> fields;
}

class ExportForm {
  ExportForm({
    required this.name,
    required this.templateName,
    required this.templateVersion,
    required this.dealership,
    required this.createdAt,
    required this.isFinal,
    required this.inspectorName,
    required this.inspectorCode,
    required this.dealerSigner,
    required this.finalizedAt,
    required this.sections,
  });
  final String name;
  final String templateName;
  final int templateVersion;
  final String dealership;
  final DateTime createdAt;
  final bool isFinal;
  final String inspectorName;
  final String inspectorCode;
  final String dealerSigner;
  final DateTime? finalizedAt;
  final List<ExportSection> sections;
}
