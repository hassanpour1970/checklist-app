import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../data/form_repository.dart';
import '../../data/template_repository.dart';
import '../backup/backup_page.dart';
import '../filled/filled_list_page.dart';
import '../templates/templates_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final templates = TemplateRepository(widget.db);
  late final forms = FormRepository(widget.db);
  int _index = 1;

  static const _titles = ['قالب‌های چک‌لیست', 'چک‌لیست‌های پرشده'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'بک‌آپ و بازیابی',
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BackupPage(db: widget.db))),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: [
        TemplatesPage(repo: templates),
        FilledListPage(repo: forms, templates: templates),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.description_outlined), label: 'قالب‌ها'),
          NavigationDestination(
              icon: Icon(Icons.fact_check_outlined), label: 'پرشده‌ها'),
        ],
      ),
    );
  }
}
