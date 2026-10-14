import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import '../services/db.dart';
import '../models/models.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  Future<String> _templateName(int id) async {
    final t = await DB.isar.checklistTemplates.get(id);
    return t?.name ?? 'Unknown';
  }

  Future<void> _export(BuildContext context, FilledChecklist fc) async {
    final excel = Excel.createExcel();
    final sheet = excel['Checklist'];

    sheet.appendRow([
      TextCellValue('Item'),
      TextCellValue('Type'),
      TextCellValue('Answer'),
    ]);

    await fc.answers.load();
    final answers = fc.answers.toList();

    final template = await DB.isar.checklistTemplates.get(fc.templateId);
    if (template == null) return;
    await template.items.load();
    final items = template.items.toList();

    for (final item in items) {
      final ans = answers.firstWhereOrNull((a) => a.itemId == item.id);
      String answerText = '';
      switch (item.type) {
        case ItemType.check:
          answerText = ans?.checkValue?.toString() ?? '';
          break;
        case ItemType.text:
          answerText = ans?.textValue ?? '';
          break;
        case ItemType.radio:
        case ItemType.combo:
          answerText = ans?.selectedOption ?? '';
          break;
        case ItemType.date:
          answerText = ans?.dateValue != null
              ? DateFormat('yyyy-MM-dd').format(ans!.dateValue!)
              : '';
          break;
      }
      sheet.appendRow([
        TextCellValue(item.title),
        TextCellValue(item.type.name),
        TextCellValue(answerText),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/checklist_${fc.id}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Checklist Export',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('export_success'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('filled'.tr()),
        centerTitle: true,
      ),
      body: StreamBuilder<List<FilledChecklist>>(
        stream: DB.isar.filledChecklists.where().watch(fireImmediately: true),
        builder: (context, snapshot) {
          final list = (snapshot.data ?? [])
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (list.isEmpty) {
            return Center(child: Text('no_filled'.tr()));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final fc = list[index];
              return FutureBuilder<String>(
                future: _templateName(fc.templateId),
                builder: (context, nameSnap) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(nameSnap.data ?? '...'),
                      subtitle: Text(
                        DateFormat.yMd().add_Hm().format(fc.createdAt),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.table_chart, color: Colors.green),
                        tooltip: 'export'.tr(),
                        onPressed: () => _export(context, fc),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
