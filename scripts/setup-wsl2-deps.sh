#!/usr/bin/env bash
set -euo pipefail
echo "==> تحديث قائمة الحزم وتثبيت الأدوات الأساسية لـ Buildroot وQEMU"
sudo apt update
sudo apt install -y build-essential git wget cpio unzip rsync bc \
  libncurses-dev libssl-dev qemu-system-x86 qemu-utils
echo "==> تحقق من وجود الأدوات المهمة"
echo -n "git: " && git --version
echo -n "make: " && make --version | head -n1
echo -n "qemu: " && qemu-system-x86_64 --version | head -n1
echo "==> انتهى تثبيت الحزم. تأكد من تشغيل هذا السكربت داخل WSL2 Ubuntu 22.04."
