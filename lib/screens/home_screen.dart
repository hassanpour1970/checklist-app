import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:isar/isar.dart';
import '../services/db.dart';
import '../models/models.dart';
import 'templates_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _addGroup(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('add'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'groups'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final group = ChecklistGroup()..name = result;
      await DB.isar.writeTxn(() => DB.isar.checklistGroups.put(group));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('groups'.tr()),
        centerTitle: true,
      ),
      body: StreamBuilder<List<ChecklistGroup>>(
        stream: DB.isar.checklistGroups.where().watch(fireImmediately: true),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(child: Text('no_groups'.tr()));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(g.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await DB.isar.writeTxn(() => DB.isar.checklistGroups.delete(g.id));
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TemplatesScreen(group: g)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGroup(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
