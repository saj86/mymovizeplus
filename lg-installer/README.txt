MyMoviz Plus - LG webOS TV installer
=====================================

[FA] نصب خودکار مای موویز پلاس روی تلویزیون LG

راهنمای کامل با تصویر: فایل LG-install-guide.html را در مرورگر باز کن.

یک‌بار روی تلویزیون:
  1. از LG Content Store اپ «Developer Mode» را نصب کن و با حساب developer.lge.com وارد شو.
  2. Dev Mode Status را ON کن (تلویزیون ری‌استارت می‌شود).
  3. دوباره اپ Developer Mode را باز کن: Key Server را ON کن و IP و Passphrase را یادداشت کن.

روی کامپیوتر (روی همان شبکه‌ی WiFi/LAN تلویزیون):
  اول کل فایل zip را در یک پوشه باز کن (همه‌ی فایل‌ها باید کنار هم باشند).
  ویندوز:      روی install-lg.bat دوبار کلیک کن.
  مک:          روی install-lg.command دوبار کلیک کن.
               (بار اول: راست‌کلیک ← Open، چون مک فایل دانلودشده را بلاک می‌کند)
  لینوکس:      در ترمینال:  bash install-lg.sh

اسکریپت خودش این کارها را می‌کند:
  - اگر Node.js نباشد، یک نسخه‌ی مستقل دانلود می‌کند (نیازی به Admin نیست)
  - ابزار LG webOS CLI را نصب می‌کند
  - فایل اپ (moviz-webos.ipk) که داخل همین پکیج است را نصب می‌کند
  - IP و Passphrase را می‌پرسد، به تلویزیون وصل می‌شود، اپ را نصب و اجرا می‌کند

برای آپدیت بعدی فقط دوباره همین اسکریپت را اجرا کن.
اگر پیغام خطای passphrase آمد، در اپ Developer Mode مقدار تازه را ببین و دوباره وارد کن.

[EN]
Full illustrated guide: open LG-install-guide.html in a browser.

On the TV (once): install "Developer Mode" from the LG Content Store, log in, turn
Dev Mode Status ON (TV restarts), then turn Key Server ON and note the IP + Passphrase.

On the computer (same network as the TV), after extracting the whole zip into one folder
(the app file moviz-webos.ipk ships in the package, next to the scripts):
  Windows:      double-click install-lg.bat
  macOS:        double-click install-lg.command
                (first time: right-click > Open, macOS blocks downloaded scripts)
  Linux:        bash install-lg.sh

Optional arguments:
  install-lg.bat -Ip 10.0.0.55 -Passphrase AB12CD -Ipk C:\path\moviz-webos.ipk
  bash install-lg.sh --ip 10.0.0.55 --passphrase AB12CD --ipk ./moviz-webos.ipk

Private files are kept in %LOCALAPPDATA%\MovizLG (Windows) or ~/.moviz-lg (mac/Linux).
