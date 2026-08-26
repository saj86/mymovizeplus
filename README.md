# صفحه‌ی نصب / دانلود (UI سرور)

این پوشه، رابط وبِ دانلود و نصب است که روی سرور خانگی (LAN) سرو می‌شود
(مثلاً `http://10.0.0.70:8000`). سه دسته دارد: اندروید TV، LG webOS، سامسونگ Tizen.

- `index.html` — صفحه‌ی دانلود با سه دکمه‌ی دسته‌بندی.
- `lg-guide.html` — راهنمای نصب روی LG (webOS).
- `samsung-guide.html` — راهنمای نصب روی سامسونگ (Tizen).

## سرو کردن
فایل‌های بسته (`moviz-universal.apk`, `moviz-arm64.apk`, `moviz-webos.ipk`) را کنار
این‌ها بگذار و از همین پوشه سرو کن:
```bash
python3 -m http.server 8000
```
