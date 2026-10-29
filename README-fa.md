[فارسی](README-fa.md) | [English](README.md)

راهنمای سریع: [راهنمای فارسی کلاینت](CLIENT-GUIDE.fa.md) | [English client guide](CLIENT-GUIDE.en.md)

# Aether OpenWrt Client

**نسخه کلاینت: v0.10.0**

اینتگریشن OpenWrt برای [Aether](https://github.com/CluvexStudio/Aether) — یک کلاینت دور زدن سانسور.

**Aether توسط [CluvexStudio](https://github.com/CluvexStudio) توسعه داده می‌شود. این ریپو یک نصب‌کننده OpenWrt و رابط وب LuCI فراهم می‌کند.**

## پیش‌نیازها

- **OpenWrt 24.10 یا جدیدتر** (musl libc؛ apk روی 25.12+، opkg روی 24.10 و قدیمی‌تر)
- تست شده روی OpenWrt 25.12.5 (x86_64)
- ~10 MB فضای دیسک آزاد
- معماری‌ها: x86_64، arm64 (aarch64)، armv7

## نصب (یک خط)

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh && chmod +x /tmp/aether-install.sh && /tmp/aether-install.sh --start
```

در حین نصب از شما پرسیده می‌شود:

- **نسخه هسته Aether**: حداکثر پنج ریلیز پایدار از v1.5.0 به بعد نمایش داده
  می‌شود. با Enter نسخه پیش‌فرض v2.4.0 انتخاب می‌شود؛ می‌توانید یک گزینه یا
  نسخه معتبر v1.5.0 به بعد را وارد کنید.
- **curl نصب شود؟** به صورت پیش‌فرض **بله**. curl برای تست اتصال در LuCI و
  watchdog بازیابی تونل لازم است. با `--no-curl` از آن صرف‌نظر کنید؛ تونل کار
  می‌کند اما watchdog فعال نمی‌شود.

## این اسکریپت چه کاری انجام می‌دهد

1. معماری روتر شما را به صورت خودکار تشخیص می‌دهد (x86_64، arm64، armv7)
2. آخرین فایل باینری رسمی Aether را از [ریلیزهای CluvexStudio/Aether](https://github.com/CluvexStudio/Aether/releases) دانلود می‌کند
3. سرویس Aether (procd)، ابزار CLI، و رابط وب LuCI را نصب می‌کند
4. فایل‌های پشتیبانی (اسکریپت init، اپ LuCI، CLI، کانفیگ) را از GitHub دانلود می‌کند
5. checksum نوع SHA-256 فایل Aether دانلودشده را بررسی می‌کند

## قابلیت‌ها

- **CLI**: `aether-ctl start|stop|restart|status|show|log|test <host>|check-ip|check-tor` (با نام مستعار `tor-ip` و خروجی `Tor: true|false IP:`)، `aether-ctl change-version <vX.Y.Z>`، `aether-ctl passwall <…>`، گزینه‌های عملکرد/gool و تنظیمات MIM، QUIC v2، ECH و Tor در v2. `set` مقدارها را اعتبارسنجی می‌کند (`tor_bind` به شکل `ip:port`، `tor_dir` مطلق، و `reverse` فقط روی MASQUE/MIM یا gool مدرن)؛ `status` و `show` تنظیم مؤثر را نیز نشان می‌دهند؛ مثلاً `balanced (stored firewall)`.
- **LuCI**: Services -> Aether
  - جدول وضعیت (وضعیت، نسخه، endpoint، transport، آدرس SOCKS5 و وضعیت پیکربندی Tor)
  - دکمه‌های Start / Stop / Restart
  - دکمه‌های تست اتصال با زمان‌بندی دقیق میلی‌ثانیه، بررسی IP عمومی و کشور و بررسی خروجی Tor (هنگام فعال بودن Tor)
  - لاگ‌های زنده بلادرنگ (به‌روزرسانی خودکار، توقف/ادامه، اسکرول خودکار)
  - یکپارچگی Passwall2 (زیر بخش Advanced): هشدار در صورت پروکسی شدن ترافیک خود روتر توسط Passwall2، غیرفعال‌سازی با یک کلیک و ساخت با یک کلیک نود socks اشاره‌کننده به Aether
  - پیکربندی کامل (پروتکل، حالت اسکن، obfuscation، HTTP/2 و غیره)
  - بخش Custom Command: خط فرمان تولیدشده/دستی هسته با پیش‌نمایش فرمان فعلی procd
- **سرویس**: ادغام procd، شروع خودکار هنگام بوت
- **watchdog بازیابی**: مسیر واقعی SOCKS5 را بررسی می‌کند و در صورت گیر کردن
  هسته، پس از چند خطای متوالی آن را بازیابی می‌کند
- **زنجیره پروکسی بالادستی** (هسته v1.7+): خروج از طریق یک پروکسی دیگر
  SOCKS5/HTTP پیش از رسیدن به Cloudflare (از طریق پرچم `--upstream`)
- **ECH** (هسته v1.9+): پیکربندی اختیاری Encrypted ClientHello
- **هسته v2**: MASQUE-in-MASQUE، کنترل انتخابی QUIC v2 و حالت‌های Tor برای بسته‌های هسته دارای Tor
- **Zero Trust**: اتصال headless به سازمان با Access service token
- **معماری**: x86_64، arm64، armv7 (باینری‌های استاتیک musl)

## گزینه‌های نصب

```sh
/tmp/aether-install.sh                 # فقط نصب
/tmp/aether-install.sh --start         # نصب و شروع فوری
/tmp/aether-install.sh --force-config  # بازنویسی کانفیگ موجود
/tmp/aether-install.sh --no-curl       # رد شدن از پرامپت نصب curl
/tmp/aether-install.sh --version v1.5.0 --start
/tmp/aether-install.sh --non-interactive --start  # نسخه v2.4.0 بدون پرامپت
```

## حذف نصب

```sh
wget -qO /tmp/aether-uninstall.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/uninstall.sh
chmod +x /tmp/aether-uninstall.sh
/tmp/aether-uninstall.sh           # حذف فایل‌های برنامه؛ حفظ کانفیگ و هویت‌ها
/tmp/aether-uninstall.sh --purge   # حذف کانفیگ و داده‌های هویت نیز
```

## دستورات CLI

```sh
aether-ctl start
aether-ctl stop
aether-ctl restart
aether-ctl status
aether-ctl show
aether-ctl log              # نمایش لاگ‌های اخیر
aether-ctl test google.com  # تست اتصال از طریق تونل (نیاز به curl)
aether-ctl check-ip         # بررسی IP عمومی، کشور و پینگ (ipwho.is)
aether-ctl check-tor        # بررسی IP خروجی Tor و IsTor (هسته v2.0.0+ با یکی از حالت‌های Tor)
aether-ctl passwall status            # نمایش وضعیت Passwall2 و نودهای مرتبط
aether-ctl passwall localhost off     # توقف پروکسی ترافیک خود روتر توسط Passwall2
aether-ctl passwall add-node          # ساخت نود socks اشاره‌کننده به Aether
aether-ctl version
aether-ctl update                       # دریافت updater جدید کلاینت؛ پیش‌فرض هسته v2.4.0 باقی می‌ماند
aether-ctl change-version v1.5.0 --start
aether-ctl update --version v1.5.0 --start
aether-ctl set tor_mode tunnel            # Tor از طریق WARP (نیازمند بسته Tor در v2.0.0+)
aether-ctl set command_mode manual        # استفاده از آرگومان‌های دلخواه هسته
aether-ctl set custom_command '--bind 0.0.0.0:1819 --wg'  # آرگومان‌های جداشده با فاصله
```

## به‌روزرسانی

دستور `aether-ctl update` آخرین `update.sh` این ریپو را دانلود و نصب‌کننده را
دوباره اجرا می‌کند. کانفیگ `/etc/config/aether` و هویت‌های معتبر `/etc/aether`
حفظ می‌شوند، مگر این‌که `--force-config` داده شود. فایل هسته همیشه با SHA-256
ریلیز رسمی بررسی می‌شود. کلاینت از هسته v1.5.0 و جدیدتر پشتیبانی می‌کند و
پیش‌فرض آن v2.4.0 است. پیش از شروع سرویس و پیش از رندر رابط LuCI، نسخه هسته
تشخیص داده می‌شود. در v1.5، گزینه‌های مخصوص v1.6 شامل HTTP CONNECT proxy،
MASQUE startup deadline و کنترل سطح لاگ نمایش داده نشده و به هسته ارسال
نمی‌شوند. نسخه‌های v1.6 پروفایل قابلیت v1.6 را دارند و نسخه‌های v1.7 زنجیره
پروکسی بالادستی (گزینه UCI `upstream_proxy`) را پشتیبانی می‌کنند. نسخه‌های
v1.8 پروفایل عملکرد را اضافه می‌کنند (گزینه UCI `perf_profile`؛ تشخیص خودکار توسط
`install.sh` یا `aether-ctl auto-perf` و قابل انتخاب به صورت `low`/`medium`/`high`).
قوانین مسیریابی، DNS درون‌تونل، firewall mark و کنترل‌های منابع عمداً توسط این
کلاینت ارائه نمی‌شوند (تقسیم ترافیک توسط Passwall2 بهتر انجام می‌شود).
نسخه‌های v1.9 به بعد endpointهای دو مرحله‌ای gool را اضافه می‌کنند (گزینه‌های
UCI `wiw_outer` و `wiw_inner`؛ خالی = اسکن هر دو مرحله توسط هسته).
هسته v2.0.0 و جدیدتر MASQUE-in-MASQUE (`mim` با endpointهای `mim_*`)، کنترل
انتخابی QUIC v2 و کنترل‌های Tor را اضافه می‌کند. Tor به بسته‌ای از هسته نیاز دارد
که با قابلیت Tor کامپایل شده باشد؛ کلاینت کنترل‌ها را بر اساس نسخه هسته نمایش
می‌دهد، اما این قابلیت build را از پیش تشخیص نمی‌دهد.

- **هسته v2.3.0 به بعد:** `--gool` اکنون **gool مدرن** (WireGuard داخل MASQUE) است و
  حالت قدیمی WireGuard-در-WireGuard با `--gool-classic` انتخاب می‌شود. گزینهٔ جدید
  `gool_mode` (`modern`/`classic`) بین این دو انتخاب می‌کند: نصب تازه روی `modern` است و
  `install.sh` پیکربندی‌های gool موجود را روی `classic` نگه می‌دارد. همچنین دستور
  `aether-ctl register` و گزینه‌های `tls_verify`، `ech_dns`، `ech_domain` اضافه شده‌اند.
- **هسته v2.4.0 به بعد:** `masque_sni`، دسترسی به API وارپ (`api_address`/`api_host`/`api_sni`)،
  تنظیم اثرانگشت TLS، اسکن `verified` (نام جدید `stealth`) و اعتبارسنجی سخت‌گیرانهٔ
  `upstream_proxy` (هستهٔ 2.4 در صورت وصل‌نشدن upstream خارج می‌شود). اندازهٔ پیش‌فرض
  fragment برابر `8-16` است. آمادگی سرویس باید از لاگ خوانده شود
  (`masque tunnel validated` / `socks5 server listening on`)، نه از باز بودن پورت.
## رابط وب LuCI

پس از نصب، رابط وب روتر خود را باز کنید -> **Services -> Aether**

![رابط وب LuCI](screenshots/luci.png)

قابلیت‌ها:
- جدول وضعیت (وضعیت، نسخه، endpoint، transport و وضعیت پیکربندی Tor)
- دکمه‌های Start / Stop / Restart
- دکمه‌های تست اتصال (google.com، youtube.com، github.com، telegram.org) با زمان دقیق ms، بررسی IP عمومی و بررسی خروجی Tor
- بخش Custom Command (پیش‌نمایش فرمان تولیدشده فعلی / آرگومان‌های دستی هسته)
- لاگ‌های زنده بلادرنگ (به‌روزرسانی خودکار هر 2 ثانیه، بدون نیاز به رفرش دستی)
- توقف/ادامه استریم لاگ
- تاگل اسکرول خودکار
- دکمه پاک کردن لاگ‌ها
- بخش Passwall2 Integration (زیر تنظیمات Advanced) برای اتصال شفاف کل شبکه از طریق تونل Aether
- پروفایل عملکرد (زیر Advanced؛ هسته v1.8+) با انتخاب خودکار بر اساس رم روتر، و endpointهای gool دو مرحله‌ای (هسته v1.9+)
- پیکربندی کامل (پروتکل، حالت اسکن، obfuscation، HTTP/2 و غیره)

اگر بعد از به‌روزرسانی صفحه جدید LuCI یا فیلدهای جدید را نمی‌بینید، با
`Ctrl+F5` صفحه را hard refresh کنید یا از پنجره incognito/private و یا یک
مرورگر جدید استفاده کنید. cache جاوااسکریپت مرورگر ممکن است رابط قبلی را
نمایش دهد.

## به‌روزرسانی دستی (از کامپیوتر شما)

اگر ریپو را به صورت محلی کلون کرده‌اید و می‌خواهید فایل‌های به‌روزرسانی شده را بدون عبور از GitHub به روتر خود منتقل کنید:

```sh
# ایجاد آرشیو از دایرکتوری files
cd aether-openwrt-client
tar czf /tmp/aether-files.tar.gz files/

# انتقال به روتر (OpenWrt سرور scp ندارد، از wget در روتر استفاده کنید)
# در کامپیوتر شما، فایل را موقتاً سرو کنید:
python -m http.server 8888 --directory /tmp

# در روتر:
wget -O /tmp/aether-files.tar.gz http://<your-pc-ip>:8888/aether-files.tar.gz
tar xzf /tmp/aether-files.tar.gz -C /
/etc/init.d/aether restart
/etc/init.d/rpcd restart
```

یا فقط اسکریپت نصب را دوباره اجرا کنید (همیشه آخرین فایل‌ها را از GitHub دانلود می‌کند):

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh && chmod +x /tmp/aether-install.sh && /tmp/aether-install.sh --start
```

## استفاده همزمان با Passwall 2 (پروکسی کل شبکه)

اگر می‌خواهید از **Passwall 2** (یا ابزارهای پروکسی شفاف مشابه) برای هدایت کل ترافیک شبکه از طریق پروکسی SOCKS5 نرم‌افزار Aether (پورت `127.0.0.1:1819`) استفاده کنید، **حتماً باید گزینه پروکسی لوکال‌هاست (Localhost Proxy / پروکسی خود روتر) را در سوییچ اصلی (Main Switch) پس‌وال غیرفعال (Disable) کنید.**

### چرا باید Localhost Proxy را غیرفعال کنیم؟ (زیر کاپوت چی می‌گذرد؟)
- **مشکل لوپ بی‌پایان (Routing Loop):** وقتی گزینه پروکسی لوکال‌هاست در Passwall فعال باشد، فایروال روتر تمام ترافیک خروجی که *از داخل خود روتر* تولید می‌شود (زنجیره `OUTPUT`) را شنود کرده و به سمت هسته پس‌وال هدایت می‌کند. از آنجایی که خود هسته Aether نیز به عنوان یک برنامه محلی روی روتر در حال اجراست، بسته‌های اسکن و هندشیک اولیه Aether (پکت‌های UDP 443 یا UDP 2408 که باید مستقیم به سرورهای کلودفلر برسند) توسط Passwall رهگیری شده و دوباره به سمت پروکسی Aether بازگردانده می‌شوند! این چرخه باعث یک لوپ بسته و باطل می‌شود و Aether هرگز موفق به برقراری ارتباط با اینترنت و بالا آوردن تونل نمی‌شود.
- **وقتی Localhost Proxy را غیرفعال می‌کنیم چه اتفاقی می‌افتد؟**
  1. **هسته Aether مستقیم وصل می‌شود:** ترافیک برنامه‌های داخلی روتر (شامل هسته Aether) از شنود Passwall عبور نکرده و مستقیماً از طریق رابط اینترنت WAN ارسال می‌شوند؛ در نتیجه Aether بدون اختلال آی‌پی‌ها را اسکن کرده و تونل را با کلودفلر برقرار می‌کند.
  2. **تمام دستگاه‌های متصل به شبکه (LAN) به صورت کامل پروکسی می‌شوند:** ترافیک کلاینت‌های متصل به شبکه محلی (موبایل‌ها، کامپیوترها، تلویزیون‌ها و...) همچنان از طریق زنجیره `PREROUTING` توسط Passwall دریافت شده و به صورت شفاف و کامل از داخل تونل امن Aether عبور داده می‌شود.

### یکپارچگی داخلی (v0.5.1)

کلاینت این تنظیمات را خودکار می‌کند و معمولاً نیازی به مراحل دستی بالا نیست:

- بخش **Passwall2 Integration** در LuCI (زیر *تنظیمات Advanced*) وضعیت فعلی را نشان می‌دهد، در صورت فعال بودن Localhost Proxy هشدار می‌دهد و دکمه غیرفعال‌سازی با یک کلیک به همراه دکمه ساخت نود socks اشاره‌کننده به Aether دارد.
- در خط فرمان، `aether-ctl passwall status` وضعیت را گزارش می‌کند، `aether-ctl passwall localhost off|on` پروکسی لوکال‌هاست را تغییر می‌دهد و `aether-ctl passwall add-node` تنها یک نود رسمی به نام `aether_node` رو به آدرس فعلی Aether می‌سازد.
- اگر از قبل نودی متعلق به Aether به آدرس/پورت دیگری اشاره کند، هیچ ورود تکراری ساخته نمی‌شود؛ در CLI و LuCI دستورالعمل اصلاح دستی نمایش داده می‌شود (ویرایش همان نود در Services -> Passwall2 -> Nodes یا حذف آن و ساخت دوباره).

## نکات

- نیاز به OpenWrt 24.10+ با musl libc (apk روی 25.12+، opkg روی قدیمی‌تر)
- در نصب تازه، SOCKS5 روی `0.0.0.0:1819` است تا کلاینت‌های LAN استفاده کنند.
  SOCKS5 احراز هویت ندارد؛ firewall بگذارید یا برای استفاده فقط روی روتر،
  آدرس را به `127.0.0.1:1819` تغییر دهید.
- `curl` اختیاری است (در حین نصب پرسیده می‌شود، به صورت پیش‌فرض بله). برای
  تست اتصال LuCI و watchdog بازیابی تونل استفاده می‌شود.
- Secretهای Zero Trust در UCI فقط برای root ذخیره و در خروجی CLI و فرمان سرویس
  مخفی می‌شوند.
- Tor (بسته‌های Tor در هسته v2): کنترل‌ها بر اساس نسخه هسته نشان داده می‌شوند،
  اما خود بسته هسته نیز باید Tor را داشته باشد. اگر `:1820` گوش می‌دهد ولی Tor
  وصل نمی‌شود، در `logread -e aether` دنبال خطای permission بگردید؛ سرویس در
  شروع، مالکیت و modeهای `/` و `/etc` را ترمیم می‌کند. با `aether-ctl check-tor`
  بررسی کنید (خروجی موفق: `Tor: true IP: …`).
- حالت فرمان دستی همه گزینه‌های UCI، از جمله Tor، را دور می‌زند. می‌توانید کل
  فرمان یا آرگومان‌های مستقل را paste کنید؛ `/usr/bin/aether(-run)` ابتدای فرمان
  خودکار حذف می‌شود. probeها bind فرمان دستی را می‌خوانند و بدون `--tor`،
  `check-tor` فوری رد می‌شود.
- برای تنظیمات، پروتکل‌ها، watchdog، Zero Trust و عیب‌یابی، [راهنمای فارسی
  کلاینت](CLIENT-GUIDE.fa.md) را ببینید.
- این پروژه وابسته به CluvexStudio نیست
- این پروژه عمدتاً به‌صورت «vide-coded» ساخته شده است.

## مجوز

MIT — فقط این نصب‌کننده و اپ LuCI. خود Aether تحت AGPL-3.0 است.

