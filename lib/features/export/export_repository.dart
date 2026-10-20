import '../../data/database.dart';
import '../../data/form_repository.dart';
import '../../domain/field_types.dart';
import 'export_models.dart';

class ExportRepository {
  ExportRepository(this.db) : _forms = FormRepository(db);
  final AppDatabase db;
  final FormRepository _forms;

  Future<List<ExportForm>> load(List<String> formIds) async {
    final out = <ExportForm>[];
    for (final id in formIds) {
      final lf = await _forms.load(id);
      final f = lf.form;
      final ver = await (db.select(db.templateVersions)
            ..where((v) => v.id.equals(f.templateVersionId)))
          .getSingle();
      out.add(ExportForm(
        name: f.name,
        templateName: f.templateName,
        templateVersion: ver.version,
        dealership: f.dealershipName,
        createdAt: f.createdAt,
        isFinal: f.status == FormStatus.finalized.name,
        inspectorName: f.inspectorName,
        inspectorCode: f.inspectorCode,
        dealerSigner: f.dealerSignerName,
        finalizedAt: f.finalizedAt,
        sections: [
          for (final s in lf.sections)
            ExportSection(s.section.title, [
              for (final fld in s.fields)
                if (FieldTypeX.parse(fld.type).hasValue)
                  ExportField(
                    stableKey: fld.stableKey,
                    label: fld.label,
                    type: FieldTypeX.parse(fld.type),
                    isRequired: fld.isRequired,
                    value: lf.answers[fld.id],
                ),
            ]),
        ],
      ));
    }
    return out;
  }
}
