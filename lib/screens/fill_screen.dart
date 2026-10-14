import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../services/db.dart';
import '../models/models.dart';

class FillScreen extends StatefulWidget {
  final ChecklistTemplate template;
  const FillScreen({super.key, required this.template});

  @override
  State<FillScreen> createState() => _FillScreenState();
}

class _FillScreenState extends State<FillScreen> {
  List<ChecklistItem> _items = [];
  final Map<int, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.template.items.load();
    setState(() {
      _items = widget.template.items.toList();
    });
  }

  Future<void> _save() async {
    final filled = FilledChecklist()
      ..templateId = widget.template.id
      ..createdAt = DateTime.now();

    await DB.isar.writeTxn(() async {
      await DB.isar.filledChecklists.put(filled);

      for (final entry in _answers.entries) {
        final answer = FilledAnswer()..itemId = entry.key;
        final value = entry.value;

        if (value is bool) {
          answer.checkValue = value;
        } else if (value is DateTime) {
          answer.dateValue = value;
        } else if (value is String) {
          // could be text or selected option
          final item = _items.firstWhere((i) => i.id == entry.key);
          if (item.type == ItemType.text) {
            answer.textValue = value;
          } else {
            answer.selectedOption = value;
          }
        }
        await DB.isar.filledAnswers.put(answer);
        filled.answers.add(answer);
      }
      await filled.answers.save();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('saved_success'.tr())),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _buildItem(item);
              },
            ),
    );
  }

  Widget _buildItem(ChecklistItem item) {
    switch (item.type) {
      case ItemType.check:
        return Card(
          child: CheckboxListTile(
            title: Text(item.title),
            value: _answers[item.id] as bool? ?? false,
            onChanged: (v) => setState(() => _answers[item.id] = v),
          ),
        );
      case ItemType.text:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                labelText: item.title,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _answers[item.id] = v,
            ),
          ),
        );
      case ItemType.radio:
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              ...item.options.map((opt) => RadioListTile<String>(
                    title: Text(opt),
                    value: opt,
                    groupValue: _answers[item.id] as String?,
                    onChanged: (v) => setState(() => _answers[item.id] = v),
                  )),
            ],
          ),
        );
      case ItemType.combo:
        return Card(
          child: ListTile(
            title: Text(item.title),
            trailing: DropdownButton<String>(
              value: _answers[item.id] as String?,
              hint: Text('select'.tr()),
              items: item.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _answers[item.id] = v),
            ),
          ),
        );
      case ItemType.date:
        final date = _answers[item.id] as DateTime?;
        return Card(
          child: ListTile(
            title: Text(item.title),
            subtitle: Text(date == null
                ? '—'
                : DateFormat.yMd(context.locale.toString()).format(date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _answers[item.id] = picked);
              }
            },
          ),
        );
    }
  }
}
