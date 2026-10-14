import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:isar/isar.dart';
import '../services/db.dart';
import '../models/models.dart';
import 'edit_template_screen.dart';
import 'fill_screen.dart';

class TemplatesScreen extends StatelessWidget {
  final ChecklistGroup group;
  const TemplatesScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: StreamBuilder<List<ChecklistTemplate>>(
        stream: DB.isar.checklistTemplates
            .filter()
            .groupIdEqualTo(group.id)
            .watch(fireImmediately: true),
        builder: (context, snapshot) {
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(child: Text('no_templates'.tr()));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final t = list[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.checklist),
                  title: Text(t.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditTemplateScreen(template: t),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await DB.isar.writeTxn(() async {
                            await t.items.load();
                            for (final item in t.items) {
                              await DB.isar.checklistItems.delete(item.id);
                            }
                            await DB.isar.checklistTemplates.delete(t.id);
                          });
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FillScreen(template: t)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newTemplate = ChecklistTemplate()
            ..name = ''
            ..groupId = group.id;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditTemplateScreen(template: newTemplate),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
