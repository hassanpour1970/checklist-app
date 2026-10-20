import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/persian_utils.dart';
import 'database.dart';

/// فرمت فایل بک‌آپ (.dab):
///   "DAB1" | u32 طول manifest | manifest(JSON) |
///   تکرار: u16 طول مسیر | مسیر(utf8) | u64 طول داده | داده
/// فایل‌ها: db.sqlite (اسنپ‌شات سازگار) + images/* + signatures/*
const _magic = [0x44, 0x41, 0x42, 0x31];

class BackupManifest {
  BackupManifest(this.createdAt, this.schema, this.files);
  final DateTime createdAt;
  final int schema;
  final int files;
}

class PreparedRestore {
  PreparedRestore(this.dir, this.manifest);
  final Directory dir;
  final BackupManifest manifest;
}

Uint8List _u16(int v) => (ByteData(2)..setUint16(0, v)).buffer.asUint8List();
Uint8List _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
Uint8List _u64(int v) => (ByteData(8)..setUint64(0, v)).buffer.asUint8List();
ByteData _bd(Uint8List b) => ByteData.sublistView(b);

class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  // ---------------- ساخت بک‌آپ ----------------
  Future<File> createBackup() async {
    final dataDir = await appDataDir();
    final tmp = await getTemporaryDirectory();
    final outDir = Directory(p.join(tmp.path, 'backups'));
    if (await outDir.exists()) await outDir.delete(recursive: true);
    await outDir.create(recursive: true);

    // اسنپ‌شات سازگار از دیتابیس (حتی وقتی برنامه باز است)
    final snap = File(p.join(outDir.path, 'snapshot.sqlite'));
    final q = snap.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$q'");

    final entries = <MapEntry<String, File>>[MapEntry('db.sqlite', snap)];
    for (final sub in const ['images', 'signatures']) {
      final d = Directory(p.join(dataDir.path, sub));
      if (!await d.exists()) continue;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File) {
          final rel =
              p.relative(e.path, from: dataDir.path).replaceAll(r'\', '/');
          entries.add(MapEntry(rel, e));
        }
      }
    }

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'dealer_audit_backup_${Fa.jalaliText(now).replaceAll('/', '')}_${two(now.hour)}${two(now.minute)}.dab';
    final out = File(p.join(outDir.path, name));

    final sink = out.openWrite();
    try {
      sink.add(_magic);
      final manifest = utf8.encode(jsonEncode({
        'app': 'dealer_audit',
        'schema': db.schemaVersion,
        'createdAt': now.toIso8601String(),
        'files': entries.length,
      }));
      sink.add(_u32(manifest.length));
      sink.add(manifest);
      for (final e in entries) {
        final pathBytes = utf8.encode(e.key);
        final len = await e.value.length();
        sink.add(_u16(pathBytes.length));
        sink.add(pathBytes);
        sink.add(_u64(len));
        await sink.addStream(e.value.openRead());
      }
    } finally {
      await sink.close();
    }
    await snap.delete();
    return out;
  }

  // ---------------- بازیابی: مرحله‌ی ۱ (استخراج و اعتبارسنجی) ----------------
  Future<Uint8List> _readExact(RandomAccessFile raf, int n) async {
    final b = await raf.read(n);
    if (b.length != n) throw const FormatException('فایل بک‌آپ ناقص است');
    return b;
  }

  void _checkPath(String rel) {
    final ok = rel == 'db.sqlite' ||
        ((rel.startsWith('images/') || rel.startsWith('signatures/')) &&
            !rel.contains('..'));
    if (!ok) throw const FormatException('فایل بک‌آپ معتبر نیست');
  }

  /// بک‌آپ را در پوشه‌ی موقت استخراج و بررسی می‌کند؛ به داده‌ی فعلی دست نمی‌زند.
  Future<PreparedRestore> prepare(String archivePath) async {
    final tmp = await getTemporaryDirectory();
    final out = Directory(p.join(tmp.path, 'restore_extract'));
    if (await out.exists()) await out.delete(recursive: true);
    await out.create(recursive: true);

    final raf = await File(archivePath).open();
    try {
      final magic = await _readExact(raf, 4);
      for (var i = 0; i < 4; i++) {
        if (magic[i] != _magic[i]) {
          throw const FormatException('این فایل، بک‌آپ این برنامه نیست');
        }
      }
      final mlen = _bd(await _readExact(raf, 4)).getUint32(0);
      if (mlen > 1 << 20) throw const FormatException('فایل بک‌آپ معتبر نیست');
      final m = jsonDecode(utf8.decode(await _readExact(raf, mlen)))
          as Map<String, dynamic>;
      if (m['app'] != 'dealer_audit') {
        throw const FormatException('این فایل، بک‌آپ این برنامه نیست');
      }
      final schema = m['schema'] as int;
      if (schema > db.schemaVersion) {
        throw const FormatException(
            'این بک‌آپ با نسخه‌ی جدیدتری از برنامه ساخته شده؛ برنامه را به‌روز کنید');
      }
      final count = m['files'] as int;

      var hasDb = false;
      for (var i = 0; i < count; i++) {
        final plen = _bd(await _readExact(raf, 2)).getUint16(0);
        final rel = utf8.decode(await _readExact(raf, plen));
        _checkPath(rel);
        final dlen = _bd(await _readExact(raf, 8)).getUint64(0);

        final target = File(p.join(out.path, rel));
        await target.parent.create(recursive: true);
        final sink = target.openWrite();
        try {
          var remaining = dlen;
          while (remaining > 0) {
            final chunk = await raf.read(min(65536, remaining));
            if (chunk.isEmpty) {
              throw const FormatException('فایل بک‌آپ ناقص است');
            }
            sink.add(chunk);
            remaining -= chunk.length;
          }
        } finally {
          await sink.close();
        }
        if (rel == 'db.sqlite') hasDb = true;
      }
      if (!hasDb) throw const FormatException('دیتابیس داخل بک‌آپ نیست');

      return PreparedRestore(
          out,
          BackupManifest(DateTime.parse(m['createdAt'] as String), schema, count));
    } catch (_) {
      if (await out.exists()) await out.delete(recursive: true);
      rethrow;
    } finally {
      await raf.close();
    }
  }

  // ---------------- بازیابی: مرحله‌ی ۲ (جایگزینی) ----------------
  Future<void> _copyDir(Directory src, Directory dst) async {
    await for (final e in src.list(recursive: true, followLinks: false)) {
      if (e is File) {
        final rel = p.relative(e.path, from: src.path);
        final target = File(p.join(dst.path, rel));
        await target.parent.create(recursive: true);
        await e.copy(target.path);
      }
    }
  }

  /// پایگاه‌داده بسته می‌شود؛ بعد از این برنامه باید دوباره اجرا شود.
  /// اگر چیزی خطا بدهد، داده‌ی قبلی برمی‌گردد.
  Future<void> apply(PreparedRestore prep) async {
    final dataDir = await appDataDir();
    await db.close();

    final old = Directory(
        '${dataDir.path}_old_${DateTime.now().millisecondsSinceEpoch}');
    await dataDir.rename(old.path);
    try {
      await Directory(dataDir.path).create(recursive: true);
      await _copyDir(prep.dir, Directory(dataDir.path));
      await old.delete(recursive: true);
    } catch (e) {
      final cur = Directory(dataDir.path);
      if (await cur.exists()) await cur.delete(recursive: true);
      await old.rename(dataDir.path);
      rethrow;
    }
    if (await prep.dir.exists()) await prep.dir.delete(recursive: true);
  }
}
