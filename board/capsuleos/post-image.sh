#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:?target dir required}"
BUILDROOT_DIR="$(cd "$(dirname "$0")/../../" && pwd)/buildroot"
IMAGES_DIR="${BUILDROOT_DIR}/output/images"
[ -d "${IMAGES_DIR}" ] || IMAGES_DIR="$(pwd)/output/images"

echo "Using images dir: ${IMAGES_DIR}"
mkdir -p "${IMAGES_DIR}"

KERNEL=""
[ -f "${IMAGES_DIR}/bzImage" ] && KERNEL="bzImage"
[ -z "$KERNEL" ] && [ -f "${IMAGES_DIR}/vmlinuz" ] && KERNEL="vmlinuz"
[ -z "$KERNEL" ] && [ -f "${IMAGES_DIR}/Image" ] && KERNEL="Image"

INITRD=""
[ -f "${IMAGES_DIR}/rootfs.cpio" ] && INITRD="rootfs.cpio"
[ -z "$INITRD" ] && [ -f "${IMAGES_DIR}/rootfs.cpio.gz" ] && INITRD="rootfs.cpio.gz"
[ -z "$INITRD" ] && [ -f "${IMAGES_DIR}/rootfs.ext4" ] && INITRD="rootfs.ext4"

ELTORITO=""
[ -f "${IMAGES_DIR}/grub-eltorito.img" ] && ELTORITO="grub-eltorito.img"
[ -z "$ELTORITO" ] && [ -f "${IMAGES_DIR}/grub.img" ] && ELTORITO="grub.img"

ISO_OUT="${IMAGES_DIR}/rootfs.iso9660"
echo "Detected: kernel=${KERNEL:-none} initrd=${INITRD:-none} eltorito=${ELTORITO:-none}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
mkdir -p "${WORKDIR}/boot/grub"

[ -n "${KERNEL}" ] && cp "${IMAGES_DIR}/${KERNEL}" "${WORKDIR}/boot/vmlinuz"
[ -n "${INITRD}" ] && cp "${IMAGES_DIR}/${INITRD}" "${WORKDIR}/boot/initrd"

if [ -d "${TARGET_DIR}/boot/grub" ]; then
  cp -a "${TARGET_DIR}/boot/grub/"* "${WORKDIR}/boot/grub/" || true
fi

if [ ! -f "${WORKDIR}/boot/grub/grub.cfg" ]; then
  cat > "${WORKDIR}/boot/grub/grub.cfg" <<'CFG'
set timeout=3
set default=0

menuentry "Run-OS kernel" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initrd
}
CFG
fi

if [ -n "${ELTORITO}" ] && [ -f "${IMAGES_DIR}/${ELTORITO}" ]; then
  cp "${IMAGES_DIR}/${ELTORITO}" "${WORKDIR}/boot/grub/eltorito.img"
  xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "RUN-OS" \
    -output "${ISO_OUT}" \
    -eltorito-boot boot/grub/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table \
    -R -J -V "RUN-OS" "${WORKDIR}"
else
  if command -v grub-mkrescue >/dev/null 2>&1; then
    (cd "${WORKDIR}" && grub-mkrescue -o "${ISO_OUT}" .) || true
  else
    xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "RUN-OS" \
      -output "${ISO_OUT}" -R -J -V "RUN-OS" "${WORKDIR}"
  fi
fi

echo "ISO assembled: ${ISO_OUT}"
