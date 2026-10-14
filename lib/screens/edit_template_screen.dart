import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/db.dart';
import '../models/models.dart';

class EditTemplateScreen extends StatefulWidget {
  final ChecklistTemplate template;
  const EditTemplateScreen({super.key, required this.template});

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  late TextEditingController _nameCtrl;
  List<ChecklistItem> _items = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name);
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (widget.template.id != 0) {
      await widget.template.items.load();
      setState(() {
        _items = widget.template.items.toList();
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;

    widget.template.name = _nameCtrl.text.trim();

    await DB.isar.writeTxn(() async {
      await DB.isar.checklistTemplates.put(widget.template);

      // Clear old links
      await widget.template.items.load();
      final oldItems = widget.template.items.toList();
      for (final old in oldItems) {
        await DB.isar.checklistItems.delete(old.id);
      }
      await widget.template.items.clear();

      for (final item in _items) {
        item.id = 0; // new id
        await DB.isar.checklistItems.put(item);
        widget.template.items.add(item);
      }
      await widget.template.items.save();
    });

    if (mounted) Navigator.pop(context);
  }

  void _addItem(ItemType type) async {
    final item = ChecklistItem()
      ..title = 'new_item'.tr()
      ..type = type
      ..options = (type == ItemType.radio || type == ItemType.combo)
          ? ['Option 1', 'Option 2']
          : [];

    final edited = await showDialog<ChecklistItem>(
      context: context,
      builder: (_) => _ItemEditor(item: item),
    );

    if (edited != null) {
      setState(() => _items.add(edited));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.id == 0
            ? 'add'.tr()
            : 'edit'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'title'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  key: ValueKey('${item.title}_$index'),
                  leading: Icon(_iconForType(item.type)),
                  title: Text(item.title),
                  subtitle: Text(item.type.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                  onTap: () async {
                    final edited = await showDialog<ChecklistItem>(
                      context: context,
                      builder: (_) => _ItemEditor(item: item),
                    );
                    if (edited != null) {
                      setState(() => _items[index] = edited);
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: ItemType.values.map((type) {
                return ActionChip(
                  avatar: Icon(_iconForType(type), size: 18),
                  label: Text(type.name.tr()),
                  onPressed: () => _addItem(type),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(ItemType type) {
    switch (type) {
      case ItemType.check:
        return Icons.check_box;
      case ItemType.text:
        return Icons.text_fields;
      case ItemType.radio:
        return Icons.radio_button_checked;
      case ItemType.combo:
        return Icons.arrow_drop_down_circle;
      case ItemType.date:
        return Icons.calendar_today;
    }
  }
}

class _ItemEditor extends StatefulWidget {
  final ChecklistItem item;
  const _ItemEditor({required this.item});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late TextEditingController _titleCtrl;
  List<TextEditingController> _optCtrls = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    if (widget.item.type == ItemType.radio || widget.item.type == ItemType.combo) {
      _optCtrls = widget.item.options.map((o) => TextEditingController(text: o)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('edit'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: 'title'.tr()),
            ),
            if (widget.item.type == ItemType.radio || widget.item.type == ItemType.combo) ...[
              const SizedBox(height: 16),
              Text('options'.tr(), style: Theme.of(context).textTheme.titleSmall),
              ..._optCtrls.asMap().entries.map((e) {
                return Row(
                  children: [
                    Expanded(child: TextField(controller: e.value)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _optCtrls.removeAt(e.key)),
                    ),
                  ],
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => _optCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: Text('add_option'.tr()),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
        FilledButton(
          onPressed: () {
            widget.item.title = _titleCtrl.text.trim();
            if (widget.item.type == ItemType.radio || widget.item.type == ItemType.combo) {
              widget.item.options = _optCtrls
                  .map((c) => c.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
            Navigator.pop(context, widget.item);
          },
          child: Text('save'.tr()),
        ),
      ],
    );
  }
}
