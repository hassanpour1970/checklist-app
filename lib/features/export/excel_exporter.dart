import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/persian_utils.dart';
import '../../domain/field_types.dart';
import 'export_models.dart';

/// فونتی که روی همه‌ی ویندوزها هست و فارسی را درست نشان می‌دهد
const kExcelFont = 'Tahoma';

/// false: ارقام انگلیسی (مناسب مرتب‌سازی و آنالیز) ؛ true: ارقام فارسی
const kExcelPersianDigits = false;

String _d(String s) => kExcelPersianDigits ? Fa.digits(s) : s;

class ExcelExporter {
  static Future<File> build(List<ExportForm> forms) async {
    final excel = Excel.createExcel();

    const summaryName = 'خلاصه';
    const answersName = 'پاسخ‌ها';
    final def = excel.getDefaultSheet();
    if (def != null) excel.rename(def, summaryName);
    final summary = excel[summaryName];
    final answers = excel[answersName];
    summary.isRTL = true;
    answers.isRTL = true;

    final head = CellStyle(fontFamily: kExcelFont, bold: true);
    final body = CellStyle(fontFamily: kExcelFont);

    // ---------- شیت خلاصه (هر چک‌لیست یک سطر) ----------
    _row(summary, 0, [
      'نام چک‌لیست', 'فرم (قالب)', 'نسخه‌ی قالب', 'نمایندگی',
      'تاریخ (شمسی)', 'وضعیت', 'بازرس', 'کد پرسنلی',
      'امضاکننده‌ی نمایندگی', 'تاریخ نهایی‌سازی',
    ].map(TextCellValue.new).toList(), head);
    const sw = [28.0, 28.0, 12.0, 24.0, 14.0, 12.0, 22.0, 14.0, 22.0, 16.0];
    for (var i = 0; i < sw.length; i++) {
      summary.setColumnWidth(i, sw[i]);
    }

    // ---------- شیت پاسخ‌ها (هر پاسخ یک سطر؛ مناسب Pivot) ----------
    _row(answers, 0, [
      'نام چک‌لیست', 'فرم (قالب)', 'نسخه‌ی قالب', 'نمایندگی',
      'تاریخ (شمسی)', 'وضعیت', 'بخش', 'عنوان فیلد',
      'نوع فیلد', 'اجباری', 'پاسخ', 'کلید فیلد',
    ].map(TextCellValue.new).toList(), head);
    const aw = [28.0, 28.0, 12.0, 24.0, 14.0, 12.0, 22.0, 36.0, 16.0, 10.0, 40.0, 38.0];
    for (var i = 0; i < aw.length; i++) {
      answers.setColumnWidth(i, aw[i]);
    }

    var sr = 1;
    var ar = 1;
    for (final f in forms) {
      final date = _d(Fa.jalaliText(f.createdAt));
      final status = f.isFinal ? 'نهایی' : 'پیش‌نویس';
      _row(summary, sr++, [
        TextCellValue(f.name),
        TextCellValue(f.templateName),
        IntCellValue(f.templateVersion),
        TextCellValue(f.dealership),
        TextCellValue(date),
        TextCellValue(status),
        TextCellValue(f.inspectorName),
        TextCellValue(_d(f.inspectorCode)),
        TextCellValue(f.dealerSigner),
        TextCellValue(
            f.finalizedAt == null ? '' : _d(Fa.jalaliText(f.finalizedAt!))),
      ], body);

      for (final s in f.sections) {
        for (final fld in s.fields) {
          _row(answers, ar++, [
            TextCellValue(f.name),
            TextCellValue(f.templateName),
            IntCellValue(f.templateVersion),
            TextCellValue(f.dealership),
            TextCellValue(date),
            TextCellValue(status),
            TextCellValue(s.title),
            TextCellValue(fld.label),
            TextCellValue(fld.type.faLabel),
            TextCellValue(fld.isRequired ? 'بله' : 'خیر'),
            _answer(fld),
            TextCellValue(fld.stableKey),
          ], body);
        }
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('ساخت فایل اکسل ناموفق بود');

    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'exports'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'checklists_${Fa.jalaliText(now).replaceAll('/', '')}_${two(now.hour)}${two(now.minute)}.xlsx';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static void _row(Sheet sheet, int r, List<CellValue> values, CellStyle style) {
    for (var c = 0; c < values.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = values[c];
      cell.cellStyle = style;
    }
  }

  static CellValue _answer(ExportField f) {
    final v = f.value;
    if (v == null || v.isEmpty) return TextCellValue('');
    switch (f.type) {
      case FieldType.checkbox:
        return TextCellValue(v == 'true' ? 'بله' : 'خیر');
      case FieldType.number:
        final i = int.tryParse(v);
        if (i != null) return IntCellValue(i);
        final d = double.tryParse(v);
        if (d != null) return DoubleCellValue(d);
        return TextCellValue(v);
      case FieldType.date:
        final dt = DateTime.tryParse(v);
        // تاریخ شمسی به‌صورت «متن» (نه تاریخ میلادی)
        return TextCellValue(dt == null ? v : _d(Fa.jalaliText(dt)));
      case FieldType.location:
        try {
          final m = jsonDecode(v) as Map<String, dynamic>;
          return TextCellValue(
              '${(m['lat'] as num).toStringAsFixed(6)}, ${(m['lng'] as num).toStringAsFixed(6)}');
        } catch (_) {
          return TextCellValue(v);
        }
      case FieldType.image:
        try {
          final n = (jsonDecode(v) as List).length;
          return TextCellValue(_d('$n تصویر'));
        } catch (_) {
          return TextCellValue('');
        }
      default:
        return TextCellValue(v);
    }
  }
}
