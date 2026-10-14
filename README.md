# Checklist Pro - اپ چک‌لیست حرفه‌ای

## ویژگی‌ها
- پشتیبانی کامل چندزبانه + RTL (فارسی)
- ساخت و ویرایش چک‌لیست‌های سفارشی و گروه‌بندی
- پر کردن چک‌لیست و ذخیره جداگانه هر مورد
- انواع آیتم: چک‌باکس، متن، رادیو، کمبوباکس، تاریخ
- خروجی اکسل برای تحلیل خارجی

## ساخت APK (خیلی ساده)

### پیش‌نیاز
1. Flutter نصب باشد (نسخه 3.16 به بالا)
2. Android SDK نصب باشد

### مراحل ساخت APK

```bash
# 1. برو داخل پوشه پروژه
cd checklist_app

# 2. نصب پکیج‌ها
flutter pub get

# 3. تولید کدهای Isar (خیلی مهم)
flutter pub run build_runner build --delete-conflicting-outputs

# 4. ساخت APK
flutter build apk --release
```

فایل APK اینجا ساخته می‌شود:
`build/app/outputs/flutter-apk/app-release.apk`

### تست روی گوشی
```bash
flutter run
```

### تغییر زبان
دکمه شناور Language در پایین صفحه را بزنید.

## ساختار پروژه
- lib/models → مدل‌های دیتابیس
- lib/screens → صفحات اصلی
- lib/services → سرویس دیتابیس
- assets/translations → فایل‌های ترجمه en و fa
