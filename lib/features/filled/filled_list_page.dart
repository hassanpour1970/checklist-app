import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/jalali_picker.dart';
import '../../core/persian_utils.dart';
import '../../data/database.dart';
import '../../data/form_repository.dart';
import '../../data/template_repository.dart';
import '../../domain/field_types.dart';
import '../export/excel_exporter.dart';
import '../export/export_repository.dart';
import '../fill/fill_page.dart';
import '../fill/form_meta_dialog.dart';

class FilledListPage extends StatefulWidget {
  const FilledListPage(
      {super.key, required this.repo, required this.templates});
  final FormRepository repo;
  final TemplateRepository templates;

  @override
  State<FilledListPage> createState() => _FilledListPageState();
}

class _FilledListPageState extends State<FilledListPage> {
  String _query = '';
  String? _status; // draft | finalized
  String? _dealer;
  String? _template;
  DateTime? _from;
  DateTime? _to;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _match(FilledForm f) {
    final q = _query.trim();
    if (q.isNotEmpty &&
        ![f.name, f.dealershipName, f.templateName, f.inspectorName]
            .any((s) => s.contains(q))) {
      return false;
    }
    if (_status != null && f.status != _status) return false;
    if (_dealer != null && f.dealershipName != _dealer) return false;
    if (_template != null && f.templateName != _template) return false;
    if (_from != null && f.createdAt.isBefore(_day(_from!))) return false;
    if (_to != null &&
        !f.createdAt.isBefore(_day(_to!).add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }

  bool get _hasFilter =>
      _status != null ||
      _dealer != null ||
      _template != null ||
      _from != null ||
      _to != null;

  void _clear() => setState(() {
        _status = null;
        _dealer = null;
        _template = null;
        _from = null;
        _to = null;
      });

  Future<void> _newForm() async {
    final templates = await widget.templates.watchTemplates().first;
    if (!mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ابتدا در بخش «قالب‌ها» یک قالب بسازید')));
      return;
    }
    final t = await showModalBottomSheet<FormTemplate>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('کدام قالب؟')),
          for (final t in templates)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(t.name),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ]),
      ),
    );
    if (t == null || !mounted) return;
    final names = await widget.repo.dealershipNames();
    if (!mounted) return;
    final meta = await showDialog<FormMeta>(
      context: context,
      builder: (_) => FormMetaDialog(
        title: 'چک‌لیست جدید',
        initialName: '${t.name} ${Fa.jalaliDisplay(DateTime.now())}',
        initialDealership: '',
        dealershipOptions: names,
      ),
    );
    if (meta == null) return;
    final id = await widget.repo
        .createForm(templateId: t.id, name: meta.name, dealershipName: meta.dealership);
    if (!mounted) return;
    _open(id);
  }

  Future<void> _open(String id) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FillPage(repo: widget.repo, formId: id)));

  Future<void> _pickDate(bool from) async {
    final d = await showJalaliDatePicker(context, initial: from ? _from : _to);
    if (d == null) return;
    setState(() => from ? _from = d : _to = d);
  }

  Future<void> _delete(FilledForm f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('پیش‌نویس «${f.name}» حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await widget.repo.deleteDraft(f.id);
  }

  Future<void> _export(List<FilledForm> items) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('در حال ساخت فایل اکسل...')));
    try {
      final data = await ExportRepository(widget.repo.db)
          .load(items.map((e) => e.id).toList());
      final file = await ExcelExporter.build(data);
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: 'خروجی چک‌لیست‌ها',
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('خطا در ساخت اکسل: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<FilledForm>>(
        stream: widget.repo.watchForms(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final dealers = (all.map((f) => f.dealershipName).toSet()
                ..removeWhere((e) => e.isEmpty))
              .toList()
            ..sort();
          final templates = (all.map((f) => f.templateName).toSet()).toList()
            ..sort();
          final items = all.where(_match).toList();

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'جستجو در نام، نمایندگی، قالب، بازرس',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                IconButton(
                  tooltip: 'خروجی اکسل از نتایج',
                  onPressed: items.isEmpty ? null : () => _export(items),
                  icon: const Icon(Icons.file_download_outlined),
                ),
              ]),
            ),
            ExpansionTile(
              title: Text(_hasFilter ? 'فیلترها (فعال)' : 'فیلترها'),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                DropdownButton<String?>(
                  isExpanded: true,
                  value: _status,
                  hint: const Text('وضعیت'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('همه‌ی وضعیت‌ها')),
                    DropdownMenuItem(value: 'draft', child: Text('پیش‌نویس')),
                    DropdownMenuItem(value: 'finalized', child: Text('نهایی')),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: dealers.contains(_dealer) ? _dealer : null,
                  hint: const Text('نمایندگی'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('همه‌ی نمایندگی‌ها')),
                    for (final d in dealers)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setState(() => _dealer = v),
                ),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: templates.contains(_template) ? _template : null,
                  hint: const Text('فرم (قالب)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('همه‌ی فرم‌ها')),
                    for (final t in templates)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _template = v),
                ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text(_from == null
                          ? 'از تاریخ'
                          : 'از ${Fa.jalaliDisplay(_from!)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text(_to == null
                          ? 'تا تاریخ'
                          : 'تا ${Fa.jalaliDisplay(_to!)}'),
                    ),
                  ),
                ]),
                if (_hasFilter)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                        onPressed: _clear, child: const Text('پاک کردن فیلترها')),
                  ),
              ],
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(all.isEmpty
                          ? 'هنوز چک‌لیستی پر نشده'
                          : 'موردی با این فیلتر پیدا نشد'))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final f = items[i];
                        final isFinal = f.status == FormStatus.finalized.name;
                        return ListTile(
                          leading: Icon(
                            isFinal ? Icons.lock_outline : Icons.edit_note,
                            color: isFinal ? Colors.green : Colors.orange,
                          ),
                          title: Text(f.name),
                          subtitle: Text(
                              '${f.dealershipName} • ${f.templateName} • ${Fa.jalaliDisplay(f.createdAt)}'),
                          trailing: isFinal
                              ? const Text('نهایی')
                              : PopupMenuButton<String>(
                                  onSelected: (_) => _delete(f),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'del', child: Text('حذف پیش‌نویس')),
                                  ],
                                ),
                          onTap: () => _open(f.id),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newForm,
        icon: const Icon(Icons.add),
        label: const Text('چک‌لیست جدید'),
      ),
    );
  }
}
