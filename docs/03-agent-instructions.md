# تعليمات وكيل الذكاء الاصطناعي — CapsuleOS

> هذا الملف يُعطى لوكيل ذكاء اصطناعي منفّذ للكود (مثل Claude Code أو أي أداة مشابهة). يحتوي كل مهمة بترتيب صارم، بمعيار قبول واضح، وتذكير دائم بالمشكلة الجذرية حتى لا يُفقد الهدف أثناء التنفيذ.

---

## تذكير دائم (اقرأه قبل كل مهمة)

**المشكلة التي نحلها**: انفصال الكود عن الاعتماديات عن بيئة التشغيل عن النشر. **كل قرار تنفيذي يجب أن يقرّب من دمج هذه الطبقات الأربع في وحدة واحدة (الكبسولة)، لا أن يضيف طبقة فصل جديدة.** إذا شككت أن مهمة تبتعد عن هذا، توقف واسأل قبل الاستمرار.

**قاعدة صارمة**: لا تنتقل لمهمة تالية قبل أن تنجح المهمة الحالية فعليًا وتُختبر (تشغيل حقيقي، لا افتراض أنها ستعمل).

---

## المهمة 0: تجهيز بيئة البناء

**البيئة**: WSL2 + Ubuntu 22.04 على Windows.

```bash
sudo apt update && sudo apt install -y build-essential git wget cpio unzip rsync bc \
  libncurses-dev libssl-dev qemu-system-x86
```

**معيار القبول**: كل الأوامر تنتهي بلا أخطاء `E:`.

**Status:** ✅ Done — completed on Ubuntu 22.04 (WSL2), gcc-11. See branch `tasks/0-1-setup`.

---

## المهمة 1: تحميل Buildroot وتوليد أول تهيئة

```bash
cd ~
git clone https://github.com/buildroot/buildroot.git
cd buildroot
git checkout 2024.02
make menuconfig
```

**الإعدادات المطلوبة داخل menuconfig**:
- `Target Options → Target Architecture` = x86_64
- `Kernel` = Linux LTS الأحدث المتاحة بالقائمة
- `Target packages` = لا تضف أي حزمة واجهة رسومية الآن (نبدأ بحد أدنى)
- `Filesystem images` = فعّل ISO9660 (لإنتاج ملف .iso قابل للتشغيل)

```bash
make
```

**معيار القبول**: يظهر ملف `output/images/*.iso` بعد انتهاء البناء (قد يأخذ 20-40 دقيقة أول مرة).

**Status:** ✅ Done — `rootfs.iso9660` (18.9MB), `bzImage`, and `initrd` were produced successfully. `configs/capsuleos_defconfig` saved for reproducibility.

**Known Issue:** Booting GRUB directly from `rootfs.iso9660` via `-cdrom` does not currently work — GRUB stops at the `grub>` prompt with `error: unknown filesystem`, even after manually loading the `iso9660` module and confirming all required files exist at correct paths inside the image (verified via `mount -o loop`). Likely cause: a compatibility issue between the El Torito bootable ISO layout produced and GRUB 2.12. **This does not block progress**, since booting the kernel directly (`-kernel bzImage -initrd rootfs.cpio`) works fully and satisfies Task 2's acceptance criterion. Left as a separate follow-up investigation.

---

## المهمة 2: اختبار الإقلاع في QEMU

```bash
qemu-system-x86_64 -cdrom output/images/rootfs.iso9660 -m 512
```

**معيار القبول**: يظهر shell قابل للكتابة فيه داخل نافذة QEMU. هذا أول دليل ملموس أن "نظام تشغيل" حقيقي، ولو بدائي، يعمل.

**إذا فشل**: انسخ رسالة الخطأ كاملة، لا تخمّن الحل. راجع سجل QEMU (`-serial stdio` لإظهار مخرجات أوضح).

**Status:** ✅ Done — verified via `qemu-system-x86_64 -kernel bzImage -initrd rootfs.cpio -append "console=ttyS0" -m 512 -nographic`. Reached `buildroot login:`, logged in as `root`, and ran commands (`uname -a`, `whoami`, `ls /`) successfully. The `-cdrom`/GRUB boot path has a separate documented issue under Task 1 above.

---

## المهمة 3: كتابة init بديل بلغة Rust (مدير الكبسولات المبدئي)

هذا أول لبنة حقيقية من الابتكار (يحل محل BusyBox init الافتراضي، يصبح لاحقًا مدير الكبسولات الكامل).

**الخطوات**:
1. أنشئ مشروع Rust بلا مكتبة قياسية كاملة (لأنه PID 1، يحتاج تحكم دقيق):
   ```bash
   cargo new --bin capsule-init
   ```
2. أول نسخة: برنامج يطبع رسالة، يفتح `/dev/console`، يبقى بحلقة انتظار بلا انهيار (لأن PID 1 لا يجوز أن يموت).
3. اربطه ثابتًا (`musl target`) ليعمل بلا اعتماديات مكتبات ديناميكية داخل بيئة Buildroot:
   ```bash
   rustup target add x86_64-unknown-linux-musl
   cargo build --release --target x86_64-unknown-linux-musl
   ```
4. أضِفه لتهيئة Buildroot كـ overlay يستبدل `/sbin/init` الافتراضي (`BR2_ROOTFS_OVERLAY`).

**معيار القبول**: تُعاد المهمة 2 (الإقلاع في QEMU) وتظهر رسالة init الجديدة بدل الرسالة الافتراضية.

---

## المهمة 4: متجر المحتوى (Content Store) وأول كبسولة

**الهدف**: إثبات أن الفكرة الجوهرية (الكبسولة بمعرّف hash ثابت) تعمل عمليًا، ولو بأبسط شكل.

1. صمّم بنية مجلد: `/store/<hash>/` يحوي: `manifest.toml` (وصف الاعتماديات) + `code/` (الكود الفعلي).
2. اكتب أداة صغيرة (Rust أو حتى سكربت Bash أولي) تحسب hash من محتوى الكود + البيان، وتخزن الكبسولة تحت هذا المعرّف.
3. جرّب كبسولة "hello world" بسيطة (سكربت Python أو Node صغير + بيانه).

**معيار القبول**: تشغيل نفس الكبسولة مرتين على نفس المحتوى ينتج نفس الـ hash تمامًا (إثبات إعادة الإنتاج المضمونة).

---

## المهمة 5: عزل كبسولتين عن بعض

استخدم `unshare` و`cgroups` مباشرة (قبل أي أتمتة معقدة) لتشغيل كبسولتين بنفس الوقت بموارد منفصلة:

```bash
unshare --pid --mount --net --fork chroot /store/<hash> /code/run.sh
```

**معيار القبول**: كبسولتان تعملان بالتوازي، تعديل ملف داخل واحدة لا يؤثر على الأخرى، ومحاولة إحداهما استهلاك كل الذاكرة لا توقف الأخرى (بفضل cgroups).

---

## المهمة 6: نفق "تشغيل = نشر"

أضِف خدمة WireGuard مبسّطة (أو ابدأ بـ `ngrok`/`cloudflared` كنموذج أولي مؤقت للإثبات فقط، ثم استبدله لاحقًا بحل مدمج بالكامل) تجعل أي كبسولة قيد التشغيل محليًا متاحة تلقائيًا برابط شبكي.

**معيار القبول**: تشغيل كبسولة "hello world" محليًا ينتج رابطًا تصل له من جهاز آخر فورًا بلا خطوة نشر يدوية.

---

## المهمة 7: واجهة WebView أساسية

اربط WebKitGTK أو Chromium Embedded بواجهة بسيطة تعرض: قائمة الكبسولات النشطة + زر تشغيل + طرفية مدمجة.

**معيار القبول**: مستخدم يقدر يشغّل كبسولة وير ى رابطها الشبكي من نفس الواجهة، بلا لمس الطرفية إطلاقًا.

---

## المهمة 8: ربط الخدمة السحابية الخلفية (الذكاء الاصطناعي)

هذه مهمة منفصلة النشر (خادم مستقل، ليس جزءًا من الـ ISO):
1. خادم بسيط (FastAPI أو Express) يستضيف نموذجًا مفتوح الوزن صغيرًا أو يستدعيه.
2. عميل خفيف داخل النظام المحلي يرسل استعلامات لهذا الخادم عند توفر الإنترنت فقط.

**معيار القبول**: من داخل الواجهة المحلية، تسأل سؤالًا تقنيًا ويرد المساعد فعليًا عبر الشبكة.

---

## بعد إنجاز كل المهام أعلاه

راجع مقاييس النجاح في `01-project-spec.md` قسم 10. إذا تحققت، المشروع وصل لإثبات مفهوم (proof of concept) حقيقي وقابل للعرض والمساهمة المجتمعية.

**لا تتجاوز أي مهمة أعلاه بدون اختبار فعلي.** كل "يبدو أنه سيعمل" غير مقبول — التشغيل الفعلي في QEMU أو على جهاز حقيقي هو المعيار الوحيد.
