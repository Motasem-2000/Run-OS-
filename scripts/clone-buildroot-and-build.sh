#!/usr/bin/env bash
# scripts/clone-buildroot-and-build.sh
# Robust Buildroot clone/prefetch/build script for Run-OS (CapsuleOS)
#
# Features:
# - Disk space check (abort if < MIN_DISK_GB)
# - Memory-aware job selection (reduce parallelism on low RAM)
# - Defconfig handling
# - Prefetch stage (make source) to detect download issues early
# - BR2_DL_DIR cache support
# - Optional QEMU smoke test for x86_64 ISO
# - Logging, artifact packaging, and checksums
#
# Usage:
#   ./scripts/clone-buildroot-and-build.sh [--prefetch-only] [--no-build] [--smoke-test]
#       [--buildroot-dir /path/to/buildroot] [--cache-dir /path/to/cache]
#       [--min-disk 10] [--jobs N]

set -euo pipefail

# ---------------------------
# Default configuration
# ---------------------------
BUILDROOT_DIR="${HOME}/buildroot"
BUILDROOT_CACHE="${HOME}/.cache/buildroot-dl"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIN_DISK_GB=10
DEFCONFIG_PATH="${REPO_ROOT}/configs/capsuleos_defconfig"
DEFAULT_BUILD_JOBS="$(nproc || echo 1)"
TARGET_ARCH="x86_64"
IMAGE_TYPE="iso"
RUN_QEMU_TEST="${RUN_QEMU_TEST:-0}"
PREFETCH_ONLY=0
NO_BUILD=0
BUILD_JOBS_OVERRIDE=""
VERBOSE=1
QEMU_BOOT_TIMEOUT=90
ARTIFACTS_DIR="${REPO_ROOT}/artifacts"

# ---------------------------
# Helpers
# ---------------------------
log() {
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%s\n' "[INFO] $*"
    fi
}

warn() {
    printf '%s\n' "[WARN] $*" >&2
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --prefetch-only         Run prefetch (make source) only; do not build.
  --no-build              Do not run 'make'.
  --smoke-test            Run QEMU smoke test after build.
  --buildroot-dir PATH    Set buildroot clone dir (default: ${BUILDROOT_DIR}).
  --cache-dir PATH        Set BR2_DL_DIR (default: ${BUILDROOT_CACHE}).
  --min-disk N            Minimum free disk (GB) required (default: ${MIN_DISK_GB}).
  --jobs N                Override parallel jobs for make.
  --arch ARCH             Target arch (default: ${TARGET_ARCH}).
  --image-type TYPE       Image type: iso|img|initramfs (default: ${IMAGE_TYPE}).
  -h, --help              Show this help and exit.

Examples:
  $0 --prefetch-only
  $0 --smoke-test --buildroot-dir /mnt/buildroot --cache-dir /mnt/cache
EOF
}

# ---------------------------
# CLI parsing
# ---------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --prefetch-only) PREFETCH_ONLY=1; shift ;;
        --no-build) NO_BUILD=1; shift ;;
        --smoke-test) RUN_QEMU_TEST=1; shift ;;
        --buildroot-dir) BUILDROOT_DIR="$2"; shift 2 ;;
        --cache-dir) BUILDROOT_CACHE="$2"; shift 2 ;;
        --min-disk) MIN_DISK_GB="$2"; shift 2 ;;
        --jobs) BUILD_JOBS_OVERRIDE="$2"; shift 2 ;;
        --arch) TARGET_ARCH="$2"; shift 2 ;;
        --image-type) IMAGE_TYPE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ---------------------------
# Functions
# ---------------------------
check_disk_space() {
    local dir="${1:-$REPO_ROOT}"
    local avail_kb
    avail_kb=$(df -Pk "$dir" | awk 'NR==2 {print $4}')
    local avail_gb=$((avail_kb / 1024 / 1024))
    if [ "$avail_gb" -lt "$MIN_DISK_GB" ]; then
        die "Not enough free disk space on $(df -P "$dir" | awk 'NR==2 {print $6}'): ${avail_gb}GB available; ${MIN_DISK_GB}GB required."
    fi
    log "Disk check passed: ${avail_gb} GB available on $(df -P "$dir" | awk 'NR==2 {print $6}')."
}

check_memory_and_set_jobs() {
    local mem_kb
    mem_kb=$(awk '/MemAvailable/ {print $2} /MemTotal/ {if (!mem_kb) print $2}' /proc/meminfo | head -n1)
    [ -n "$mem_kb" ] || mem_kb=0
    local mem_mb=$((mem_kb / 1024))
    log "Memory available: ${mem_mb} MB"
    if [ -n "$BUILD_JOBS_OVERRIDE" ]; then
        BUILD_JOBS="$BUILD_JOBS_OVERRIDE"
    else
        local nproc_val
        nproc_val=$(nproc || echo 1)
        if [ "$mem_mb" -lt 2000 ]; then
            BUILD_JOBS=1
            warn "Low memory ($mem_mb MB): forcing single-threaded build (BUILD_JOBS=1)."
        else
            local jobs_calc=$((mem_mb / 1500))
            [ "$jobs_calc" -lt 1 ] && jobs_calc=1
            [ "$jobs_calc" -gt "$nproc_val" ] && jobs_calc="$nproc_val"
            BUILD_JOBS="$jobs_calc"
        fi
    fi
    log "Using BUILD_JOBS=${BUILD_JOBS}"
    export MAKEFLAGS="-j${BUILD_JOBS}"
}

download_with_retries() {
    local url="$1"
    local dest="$2"
    local want_sha="${3:-}"
    local tries=5
    local attempt=1
    local sleep_base=5
    while [ $attempt -le $tries ]; do
        log "Download attempt $attempt/$tries: $url"
        if command -v curl >/dev/null 2>&1; then
            curl --fail --location --connect-timeout 15 --output "$dest" "$url" && rc=0 || rc=$?
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$dest" "$url" && rc=0 || rc=$?
        else
            die "Neither curl nor wget is available for downloads."
        fi

        if [ "$rc" -eq 0 ] && [ -n "$want_sha" ]; then
            echo "${want_sha}  ${dest}" | sha256sum -c - >/dev/null 2>&1 || rc=2
            if [ "$rc" -ne 0 ]; then
                warn "Checksum mismatch for $dest"
                rm -f "$dest"
            else
                log "Checksum OK for $dest"
            fi
        fi

        if [ "$rc" -eq 0 ]; then
            return 0
        fi

        sleep $((sleep_base * attempt))
        attempt=$((attempt + 1))
    done
    return 1
}

ensure_buildroot() {
    if [ -d "${BUILDROOT_DIR}" ]; then
        log "Buildroot already present at ${BUILDROOT_DIR}; fetching latest refs."
        cd "${BUILDROOT_DIR}"
        git fetch --all --tags || warn "git fetch failed, continuing with existing clone"
    else
        log "Cloning Buildroot into ${BUILDROOT_DIR}..."
        git clone https://github.com/buildroot/buildroot.git "${BUILDROOT_DIR}" || die "Failed to clone Buildroot"
        cd "${BUILDROOT_DIR}"
    fi
    git checkout 2024.02 >/dev/null 2>&1 || log "Warning: could not checkout 2024.02 - using current branch"
}

apply_defconfig_or_menuconfig() {
    cd "${BUILDROOT_DIR}"
    if [ -f "${DEFCONFIG_PATH}" ]; then
        log "Applying saved defconfig: ${DEFCONFIG_PATH}"
        make BR2_DEFCONFIG="${DEFCONFIG_PATH}" defconfig
    else
        log "No saved defconfig found at ${DEFCONFIG_PATH}. Launching interactive make menuconfig."
        log "After exiting menuconfig this script will run make savedefconfig and copy the defconfig to ${DEFCONFIG_PATH}."
        make menuconfig
        log "Saving defconfig..."
        make savedefconfig
        mkdir -p "$(dirname "${DEFCONFIG_PATH}")"
        cp defconfig "${DEFCONFIG_PATH}"
        log "Defconfig saved to ${DEFCONFIG_PATH}. Please review and commit it to the repo to enable deterministic builds."
    fi
}

prefetch_sources() {
    cd "${BUILDROOT_DIR}"
    export BR2_DL_DIR="${BUILDROOT_CACHE}"
    mkdir -p "${BR2_DL_DIR}"
    log "Prefetching sources (make source) to detect download errors early..."
    if make -n source >/dev/null 2>&1; then
        if ! make source 2>&1 | tee "${BUILDROOT_DIR}/prefetch.log"; then
            warn "make source failed; see ${BUILDROOT_DIR}/prefetch.log"
            return 1
        fi
    elif make -n download >/dev/null 2>&1; then
        if ! make download 2>&1 | tee "${BUILDROOT_DIR}/prefetch.log"; then
            warn "make download failed; see ${BUILDROOT_DIR}/prefetch.log"
            return 1
        fi
    else
        warn "This Buildroot version does not support 'make source' or 'make download'. Skipping prefetch stage."
    fi
    log "Prefetch completed successfully."
    return 0
}

run_build() {
    cd "${BUILDROOT_DIR}"
    export BR2_DL_DIR="${BUILDROOT_CACHE}"
    log "Starting build with MAKEFLAGS='${MAKEFLAGS:-}' and BR2_DL_DIR='${BR2_DL_DIR}'. This may take many minutes."
    if ! make 2>&1 | tee "${BUILDROOT_DIR}/build-output.log"; then
        warn "Build failed; see ${BUILDROOT_DIR}/build-output.log for details"
        return 1
    fi
    log "Build finished successfully."
    return 0
}

collect_artifacts() {
    local ts branch shortsha artifact_dir images_dir manifest_file
    ts=$(date -u +"%Y%m%dT%H%M%SZ")
    if git rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        shortsha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        branch="local"
        shortsha="unknown"
    fi
    artifact_dir="${ARTIFACTS_DIR}/${branch}-${ts}-${shortsha}"
    mkdir -p "${artifact_dir}"
    images_dir="${BUILDROOT_DIR}/output/images"
    if [ -d "${images_dir}" ]; then
        cp -a "${images_dir}" "${artifact_dir}/images"
        if [ -n "$(ls -A "${artifact_dir}/images" 2>/dev/null || true)" ]; then
            (cd "${artifact_dir}/images" && sha256sum * > "${artifact_dir}/images-SHA256SUMS.txt" || true)
        fi
    else
        warn "No images directory found at ${images_dir}"
    fi
    manifest_file="${artifact_dir}/manifest.txt"
    {
        echo "project: Run-OS (CapsuleOS)"
        echo "timestamp: ${ts}"
        echo "git_branch: ${branch}"
        echo "git_short_sha: ${shortsha}"
        echo "buildroot_dir: ${BUILDROOT_DIR}"
        echo "defconfig: ${DEFCONFIG_PATH} (exists: $( [ -f "${DEFCONFIG_PATH}" ] && echo yes || echo no ))"
        echo "BR2_DL_DIR: ${BR2_DL_DIR}"
        echo "build_jobs: ${BUILD_JOBS:-unknown}"
    } > "${manifest_file}"
    tail -n 200 "${BUILDROOT_DIR}/build-output.log" 2>/dev/null > "${artifact_dir}/build-output-tail.log" || true
    log "Artifacts collected under ${artifact_dir}"
}

qemu_smoke_test_iso() {
    local iso_path="${BUILDROOT_DIR}/output/images/rootfs.iso9660"
    if [ ! -f "${iso_path}" ]; then
        warn "ISO not found at ${iso_path}; skipping QEMU smoke test."
        return 2
    fi

    local console_log tmp_pid elapsed
    console_log="${BUILDROOT_DIR}/qemu-console.log"
    rm -f "${console_log}"
    log "Launching QEMU (headless) to boot ISO: ${iso_path}"
    qemu-system-x86_64 -machine accel=tcg -m 512 -cdrom "${iso_path}" -serial file:"${console_log}" -nographic -no-reboot -monitor none &
    tmp_pid=$!
    log "QEMU PID: ${tmp_pid}. Waiting up to ${QEMU_BOOT_TIMEOUT}s for shell prompt..."
    elapsed=0
    while [ "${elapsed}" -lt "${QEMU_BOOT_TIMEOUT}" ]; do
        if grep -E "login:|BusyBox|/ #|login:" "${console_log}" >/dev/null 2>&1; then
            log "QEMU smoke test: detected shell/login prompt in console log."
            kill "${tmp_pid}" >/dev/null 2>&1 || true
            sleep 1
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    warn "QEMU smoke test timeout (${QEMU_BOOT_TIMEOUT}s). See ${console_log} for details."
    kill "${tmp_pid}" >/dev/null 2>&1 || true
    return 1
}

# ---------------------------
# Main flow
# ---------------------------
log "Starting Buildroot helper script"
log "Repository root: ${REPO_ROOT}"
log "Buildroot dir: ${BUILDROOT_DIR}"
log "BR2_DL_DIR (cache): ${BUILDROOT_CACHE}"
log "Minimum disk: ${MIN_DISK_GB} GB"

check_disk_space "${REPO_ROOT}"
check_memory_and_set_jobs

ensure_buildroot
apply_defconfig_or_menuconfig

mkdir -p "${BUILDROOT_CACHE}"
export BR2_DL_DIR="${BUILDROOT_CACHE}"
log "Using BR2_DL_DIR=${BR2_DL_DIR}"

if ! prefetch_sources; then
    die "Prefetch stage failed. Inspect ${BUILDROOT_DIR}/prefetch.log and ${BUILDROOT_DIR}/dl for failed URLs."
fi

if [ "${PREFETCH_ONLY}" -eq 1 ]; then
    log "--prefetch-only specified: exiting after prefetch stage."
    exit 0
fi

if [ "${NO_BUILD}" -eq 1 ]; then
    log "--no-build specified: skipping make. You can run make manually in ${BUILDROOT_DIR}."
    exit 0
fi

if ! run_build; then
    collect_artifacts || true
    die "Build failed. See ${BUILDROOT_DIR}/build-output.log and artifacts for details."
fi

collect_artifacts

POST_IMAGE_SCRIPT="${REPO_ROOT}/board/capsuleos/post-image.sh"
TARGET_DIR="${BUILDROOT_DIR}/output/target"
if [ -x "${POST_IMAGE_SCRIPT}" ]; then
    if [ -d "${TARGET_DIR}" ]; then
        log "Running post-image script: ${POST_IMAGE_SCRIPT} ${TARGET_DIR}"
        "${POST_IMAGE_SCRIPT}" "${TARGET_DIR}" || warn "post-image script returned non-zero"
    else
        warn "Post-image script present but target dir missing: ${TARGET_DIR}"
    fi
fi

if [ "${RUN_QEMU_TEST}" = "1" ] || [ "${RUN_QEMU_TEST}" = "true" ]; then
    log "RUN_QEMU_TEST enabled: performing smoke test"
    if [ "${TARGET_ARCH}" != "x86_64" ] || [ "${IMAGE_TYPE}" != "iso" ]; then
        warn "Smoke test currently supports x86_64 ISO only. Skipping smoke test for arch=${TARGET_ARCH} image_type=${IMAGE_TYPE}."
    else
        if qemu_smoke_test_iso; then
            log "QEMU smoke test passed."
        else
            warn "QEMU smoke test failed. Check QEMU console logs in ${BUILDROOT_DIR}/qemu-console.log"
        fi
    fi
else
    log "QEMU smoke test not requested (set RUN_QEMU_TEST=1 or use --smoke-test)."
fi

log "Build script completed successfully. Artifacts are under ${ARTIFACTS_DIR} (if produced)."
exit 0
