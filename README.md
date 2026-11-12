# NEXORA — برنامه‌ریز من (Flutter + Kotlin)

اپلیکیشن برنامه‌ریز کاملاً آفلاین با رابط فارسی و تقویم شمسی. رابط با Flutter ساخته شده و هشدار پایان تمرکز با `AlarmManager.setAlarmClock` و سرویس بومی Kotlin اجرا می‌شود.

## امکانات
- سه نمای روزانه، هفتگی و ماهانه با تاریخ شمسی
- برنامه روزانه در بازه ۰۶:۰۰ تا ۲۴:۰۰ با گام‌های ۳۰ دقیقه‌ای
- ثبت تسک در خانه زمانی و انتقال تسک تیک‌خورده به «فعالیت‌های انجام‌شده»
- ورودی دستی برای نام فعالیت و مدت‌زمان
- گزارش زمان ثبت‌شده و نمودار ساده هفتگی؛ تقویم ماهانه با شدت فعالیت
- تم روشن/تاریک و تنظیمات پومودورو
- SQLite محلی + SharedPreferences
- هشدار بومی Android فقط برای پایان دوره تمرکز
- بازیابی آلارم پس از راه‌اندازی مجدد دستگاه

## ساخت محلی
```bash
flutter pub get
flutter analyze
flutter build apk --release
```
خروجی: `build/app/outputs/flutter-apk/app-release.apk`

## ساخت APK با GitHub Actions (بدون نیاز به Android Studio)

۱. این مخزن را روی GitHub بسازید و کل محتوای ریشه پروژه (شامل `lib/`, `android/`, `pubspec.yaml`, `.github/` و ...) را push کنید.

۲. به تب **Actions** بروید.

۳. workflow با نام **Build Android APK** را انتخاب کنید و روی **Run workflow** بزنید (یا با push به `main`/`master` خودکار اجرا می‌شود).

۴. پس از موفقیت، در صفحه اجرای workflow از بخش **Artifacts** فایل `planner-android-release-apk` را دانلود کنید. داخل آن `app-release.apk` قرار دارد.

این workflow روی runner ابری GitHub اجرا می‌شود و برای ساخت APK به Android Studio روی لپ‌تاپ نیاز ندارد.

## مجوز آلارم دقیق
در Android ممکن است اجازه **Alarms & reminders** لازم باشد. در تنظیمات گوشی این دسترسی را برای برنامه فعال کنید. از Android 13 به بعد مجوز اعلان نیز لازم است.

## ساختار
- `lib/main.dart`: رابط کاربری، تقویم شمسی، پایگاه داده و منطق پومودورو
- `android/app/src/main/kotlin/.../MainActivity.kt`: کانال ارتباطی Flutter و زمان‌بند
- `android/app/src/main/kotlin/.../AlarmReceivers.kt`: گیرنده آلارم، سرویس صدا و BootReceiver

## نکته Gradle Wrapper
فایل‌های wrapper از قبل در پروژه قرار داده شده‌اند. اگر لازم بود، یک‌بار اجرا کنید:
```bash
bash scripts/prepare_gradle_wrapper.sh
```
