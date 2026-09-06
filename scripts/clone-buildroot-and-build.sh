#!/usr/bin/env bash
set -euo pipefail
BUILDROOT_DIR="$HOME/buildroot"
BR_VERSION="2024.02"

echo "==> التحقق إن كان المجلد موجودًا: $BUILDROOT_DIR"
if [ -d "$BUILDROOT_DIR" ]; then
  echo "مجلد buildroot موجود بالفعل في $BUILDROOT_DIR. سأقوم بعمل git fetch وreset للفرع المطلوب."
  cd "$BUILDROOT_DIR"
  git fetch --all --prune
  git checkout --detach
else
  echo "==> استنساخ Buildroot إلى $BUILDROOT_DIR"
  git clone https://github.com/buildroot/buildroot.git "$BUILDROOT_DIR"
  cd "$BUILDROOT_DIR"
fi

echo "==> التبديل إلى الإصدار المطلوب: $BR_VERSION"
git checkout "$BR_VERSION" || (echo "الفرع/الوسم $BR_VERSION غير موجود محليًا، حاول git fetch ثم إعادة المحاولة." && exit 1)

echo "==> تشغيل make menuconfig (تفاعلي). اضبط الخيارات كما يلي:"
echo "  - Target Options → Target Architecture = x86_64"
echo "  - Kernel → اختَر Linux LTS الأحدث المتوفّر"
echo "  - Target packages → لا تضف حزم رسومية"
echo "  - Filesystem images → فعّل ISO9660"
echo
echo "بعد تعديل الخيارات: احفظ واخرج من menuconfig ليستمر البناء."
make menuconfig

echo "==> بدء البناء: هذا قد يستغرق 20-40 دقيقة أو أكثر لأول مرة"
make -j$(nproc) 2>&1 | tee build-output.log

if [ -f output/images/rootfs.iso9660 ]; then
  echo "==> تمّ الإنشاء بنجاح: output/images/rootfs.iso9660"
else
  echo "==> البناء اكتمل لكن لم يعثر على ملف ISO المتوقع. راجع build-output.log للخطأ."
  exit 1
fi
