import 'dart:io';

import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/persian_utils.dart';
import '../../data/backup_service.dart';
import '../../data/database.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.db});
  final AppDatabase db;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupService _svc = BackupService(widget.db);
  bool _busy = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final file = await _svc.createBackup();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: 'بک‌آپ ارزیابی نمایندگی‌ها',
      ));
    } catch (e) {
      if (mounted) _snack('خطا در ساخت بک‌آپ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await openFile();
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    PreparedRestore? prep;
    try {
      // کپی فایل انتخاب‌شده در پوشه‌ی موقت (به‌صورت استریم؛ حافظه‌ی کم)
      final tmp = await getTemporaryDirectory();
      final input = File(p.join(tmp.path, 'restore_input.dab'));
      final sink = input.openWrite();
      await sink.addStream(picked.openRead());
      await sink.close();

      prep = await _svc.prepare(input.path);
      await input.delete();
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('خواندن بک‌آپ ناموفق بود: $e');
      }
      return;
    }

    if (!mounted) return;
    final c = prep.manifest.createdAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی اطلاعات'),
        content: Text(
            'بک‌آپ مربوط به ${Fa.jalaliDisplay(c)} ساعت ${Fa.digits('${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}')} است.\n\n'
            'با ادامه، همه‌ی اطلاعات فعلی این گوشی (قالب‌ها، چک‌لیست‌ها، تصاویر و امضاها) '
            'با محتوای بک‌آپ جایگزین می‌شود و برنامه بسته خواهد شد.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('جایگزین کن')),
        ],
      ),
    );
    if (ok != true) {
      await prep.dir.delete(recursive: true);
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      await _svc.apply(prep);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('بازیابی ناموفق بود (اطلاعات قبلی حفظ شد): $e');
      }
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('بازیابی انجام شد'),
          content: const Text(
              'برنامه بسته می‌شود. دوباره آن را باز کنید تا اطلاعات بازیابی‌شده نمایش داده شود.'),
          actions: [
            FilledButton(
              onPressed: () async {
                await SystemNavigator.pop();
                exit(0);
              },
              child: const Text('بستن برنامه'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بک‌آپ و بازیابی')),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('گرفتن بک‌آپ'),
                subtitle: const Text(
                    'همه‌ی اطلاعات (قالب‌ها، چک‌لیست‌ها، تصاویر، امضاها) در یک فایل ذخیره می‌شود. '
                    'در پنجره‌ی باز‌شده «ذخیره در فایل‌ها» یا Drive/تلگرام را انتخاب کنید.'),
                onTap: _busy ? null : _backup,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('بازیابی از بک‌آپ'),
                subtitle: const Text(
                    'برای گوشی جدید یا بعد از پاک شدن برنامه. اطلاعات فعلی جایگزین می‌شود.'),
                onTap: _busy ? null : _restore,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
