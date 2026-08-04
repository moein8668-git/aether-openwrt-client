# راهنمای کلاینت Aether برای OpenWrt

این کلاینت هسته Aether را با OpenWrt یکپارچه می‌کند. باینری Aether، سرویس
procd، دستور `aether-ctl` و صفحه LuCI در مسیر **Services -> Aether** نصب می‌شوند.

## چه کاری انجام می‌دهد؟

Aether یک پراکسی محلی SOCKS5 ایجاد می‌کند و ترافیک را از تونل عبور می‌دهد.
این یکپارچه‌سازی OpenWrt:

- هسته را با procd اجرا و مدیریت می‌کند؛
- هویت‌ها را در `/etc/aether` نگه می‌دارد؛
- start، stop، restart، status، لاگ و تست اتصال را فراهم می‌کند؛
- صفحه تنظیمات LuCI دارد؛
- مسیر واقعی داده را بررسی می‌کند و در صورت گیر کردن هسته آن را بازیابی می‌کند.

آدرس پیش‌فرض پراکسی `0.0.0.0:1819` است. اگر پراکسی فقط باید روی خود روتر
قابل دسترسی باشد، آن را به `127.0.0.1:1819` تغییر دهید.

## پروتکل‌ها

- **MASQUE**: حالت مدرن با HTTP/3 و QUIC. اگر UDP یا QUIC مسدود است، HTTP/2
  را فعال کنید. پروفایل پیشنهادی MASQUE، `firewall` است.
- **WireGuard**: در شبکه‌هایی که WireGuard مسدود نیست معمولاً سریع‌تر است.
  پروفایل‌های آن `balanced`، `aggressive`، `light` و `off` هستند.
- **WARP-in-WARP (gool)**: دو لایه WireGuard دارد و ممکن است در شبکه‌های سخت‌گیر
  بهتر کار کند، اما سربار بیشتری دارد. از `balanced` شروع کنید.

کلاینت endpointها را اسکن کرده و قبل از باز کردن SOCKS5، عبور واقعی داده را
بررسی می‌کند. گزینه **Quick Reconnect** ابتدا endpoint موفق قبلی را بررسی
می‌کند تا در صورت امکان از اسکن کامل جلوگیری شود.

## تنظیمات

### تنظیمات پایه و شبکه

- **Enable on Boot** فقط شروع خودکار بعد از ریبوت روتر را کنترل می‌کند و مانع
  استفاده از دکمه‌های Start و Stop یا دستورات CLI در زمان فعلی نمی‌شود.
- **Scan Mode**: حالت `turbo` سریع‌تر است؛ `balanced` انتخاب معمول است؛
  حالت‌های `thorough`، `stealth` و `ironclad` زمان بیشتری برای کشف یا اعتبارسنجی
  صرف می‌کنند.
- **IP Version**: اگر IPv6 روی روتر فعال و سالم نیست، IPv4 را انتخاب کنید.
- **Force Peer**: با وارد کردن `ip:port` اسکن را رد می‌کند.
- **HTTP/2 Mode** و **H2 Peer** فقط برای MASQUE هستند.
- **TLS Fragmentation** برای MASQUE روی HTTP/2 و در صورت مسدود بودن handshake است.

### تنظیمات پایداری

- **Keepalive** برای WireGuard و gool استفاده می‌شود.
- **Reconnect Delay** فاصله تلاش مجدد هسته را تعیین می‌کند.
- **Validation Timeout** زمان انتظار اعتبارسنجی مسیر داده است.
- **Quick Reconnect** endpoint ذخیره‌شده را قبل از اسکن دوباره بررسی می‌کند.
- **Data-plane Watchdog** ترافیک SOCKS5 را دوره‌ای تست می‌کند و پس از چند خطای
  متوالی، هسته گیرکرده را متوقف می‌کند تا procd یک نمونه سالم اجرا کند. برای
  فعال شدن آن باید `curl` نصب باشد.

## Zero Trust

بخش **Zero Trust** در LuCI از اتصال headless به سازمان Cloudflare پشتیبانی می‌کند:

- نام Team؛
- Access Client ID؛
- Access Client Secret؛
- حالت اختیاری Gateway سازمان.

Secret در `/etc/config/aether` ذخیره می‌شود، فایل فقط برای root قابل خواندن است
و مقدار آن در خروجی CLI و فهرست فرمان سرویس نمایش داده نمی‌شود. Gateway به صورت
پیش‌فرض خاموش است، چون فیلتر و لاگ سازمان باید انتخابی باشد.

ورود تعاملی با کد ایمیل را از ترمینال و با خود هسته Aether انجام دهید؛ سرویس boot
برای ورود تعاملی مناسب نیست.

## دستورات CLI

```sh
aether-ctl start
aether-ctl stop
aether-ctl restart
aether-ctl status
aether-ctl show
aether-ctl log 100
aether-ctl test google.com
aether-ctl set protocol wg
```

گزینه Enable on Boot از کنترل runtime جدا است:

```sh
aether-ctl set enabled yes   # فعال‌سازی شروع بعد از ریبوت
aether-ctl set enabled no    # غیرفعال‌سازی شروع بعد از ریبوت
aether-ctl start             # شروع همین حالا، مستقل از تنظیم بوت
aether-ctl stop              # توقف همین حالا، مستقل از تنظیم بوت
```

## نصب و به‌روزرسانی

اسکریپت نصب را با دسترسی root روی روتر اجرا کنید. این اسکریپت باینری مناسب
معماری را دانلود، checksum از نوع SHA-256 را بررسی، فایل‌ها را مرحله‌بندی،
کانفیگ موجود را به صورت پیش‌فرض حفظ، cacheهای LuCI را پاک و سرویس‌های وب لازم
را restart می‌کند.

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh
chmod +x /tmp/aether-install.sh
/tmp/aether-install.sh --start
```

اگر بعد از آپدیت صفحه جدید LuCI را نمی‌بینید، با `Ctrl+F5` صفحه را hard refresh
کنید یا از پنجره incognito/private و یا یک مرورگر جدید استفاده کنید. cache
جاوااسکریپت مرورگر ممکن است صفحه قبلی را نگه دارد.

## حذف نصب

در حذف معمولی، کانفیگ و هویت‌ها باقی می‌مانند:

```sh
wget -qO /tmp/aether-uninstall.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/uninstall.sh
chmod +x /tmp/aether-uninstall.sh
/tmp/aether-uninstall.sh
```

فقط زمانی از `--purge` استفاده کنید که می‌خواهید `/etc/config/aether` و
`/etc/aether`، شامل هویت‌های ثبت‌شده، نیز حذف شوند.

## عیب‌یابی

- وضعیت سرویس: `aether-ctl status`
- لاگ‌های اخیر: `aether-ctl log 100`
- تست از داخل تونل: `aether-ctl test google.com`
- اگر سرویس روشن است ولی ترافیک عبور نمی‌کند، کمی برای watchdog صبر کنید یا
  `aether-ctl restart` را اجرا کنید.
- اگر LuCI قدیمی است، ابتدا پنجره private یا مرورگر جدید را امتحان کنید.
