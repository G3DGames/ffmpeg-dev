#!/bin/sh
# ffmpeg-dev: builds FFmpeg's shared libraries - LGPL, 64-bit - for every
# platform TFFMpegAPI supports, and collects each in dlls/<target>/ with the
# licence texts and a build note.
#
#   ./build.sh [target] [extra configure options]
#   build.bat  [extra configure options]          Windows: windows-x64
#
# Targets (the default is the machine's own):
#   windows-x64     Visual Studio's cl, from build.bat (MSYS2 + vcvars64)
#   linux-x64       gcc / clang
#   macos-arm64     on a Mac (Apple Silicon or Intel)
#   macos-x64       on a Mac (Apple Silicon or Intel)
#   macos           both of the above
#   android-arm64   the Android NDK (ANDROID_NDK_HOME), on Linux or a Mac
#
# JOBS=n limits the parallel compiles. FFMPEG_DEV_ARGS adds configure options
# too (build.bat passes its arguments that way). ANDROID_API (default 24) is
# the lowest Android version the libraries run on; MACOS_MIN (default 11.0)
# the lowest macOS.
#
# The build is LGPL: --enable-gpl and --enable-nonfree are refused, and the
# licence configure reports is checked after configuring.
set -e
cd "$(dirname "$0")"
ROOT=$(pwd)

if [ ! -f ffmpeg/configure ]; then
  git submodule update --init || true
fi
if [ ! -f ffmpeg/configure ]; then
  # 'git submodule update' succeeds silently when no submodule was added
  echo "FFmpeg's source is missing: ffmpeg/ is not there. Add it once (then commit):"
  echo "  git submodule add https://github.com/FFmpeg/FFmpeg.git ffmpeg"
  echo "  git -C ffmpeg checkout n8.1.3"
  exit 1
fi

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) HOST=windows ;;
  Linux) HOST=linux ;;
  Darwin) HOST=macos ;;
  *) echo "Unsupported system: $(uname -s)"; exit 1 ;;
esac

# the target: the first argument when it does not start with '-'
TARGET=""
case "$1" in
  -*|"") ;;
  *) TARGET=$1; shift ;;
esac
if [ -z "$TARGET" ]; then
  case $HOST in
    windows) TARGET=windows-x64 ;;
    linux) TARGET=linux-x64 ;;
    macos)
      if [ "$(uname -m)" = arm64 ]; then TARGET=macos-arm64; else TARGET=macos-x64; fi ;;
  esac
fi
if [ "$TARGET" = macos ]; then
  "$0" macos-arm64 "$@"
  "$0" macos-x64 "$@"
  exit 0
fi

# shellcheck disable=SC2086
set -- $FFMPEG_DEV_ARGS "$@"
for a in "$@"; do
  case "$a" in
    --enable-gpl|--enable-nonfree)
      echo "ffmpeg-dev builds LGPL FFmpeg only: $a is refused"
      exit 1 ;;
  esac
done

JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}
BUILD="$ROOT/build/$TARGET"
PREFIX="$ROOT/install/$TARGET"
OUT="$ROOT/dlls/$TARGET"

# What every platform gets. --disable-autodetect: nothing is picked up from
# whatever happens to be installed, so every build has the same features;
# threads are part of what autodetect would find, so each target enables
# them. The libraries TFFMpegAPI loads: avutil, swresample, avcodec,
# avformat, swscale (video, and avfilter needs it), avfilter (the player's
# speed change).
COMMON="--prefix=$PREFIX --enable-shared --disable-static --disable-autodetect
  --disable-doc --disable-debug --disable-avdevice --disable-ffplay"

need_host() {
  if [ "$HOST" != "$1" ]; then
    echo "$TARGET is built on $1 (this is $HOST)"
    exit 1
  fi
}

case $TARGET in
  windows-x64)
    need_host windows
    # Visual Studio's compiler (build.bat set up its environment). MSYS2's
    # coreutils have a 'link' too: cl's folder goes first so FFmpeg links
    # with Microsoft's link.exe.
    CL=$(command -v cl.exe || true)
    if [ -z "$CL" ]; then
      echo "cl.exe not found: run build.bat (it sets up Visual Studio's x64 tools)"
      exit 1
    fi
    PATH="$(dirname "$CL"):$PATH"
    export PATH
    # -MT: the C runtime linked into each DLL - nothing else to install
    PLATFORM="--toolchain=msvc --arch=x86_64 --target-os=win64 --enable-w32threads
      --extra-cflags=-MT"
    ;;
  linux-x64)
    need_host linux
    # $ORIGIN: each library (and ffmpeg / ffprobe) finds the others in its
    # own folder. The text passes several interpreters - configure drops a
    # level of backslashes, make turns $$ into $ (twice for the libraries,
    # whose link rules go through $(eval)), the link command's shell \$ into
    # $ - so configure is given \\\$\$\$\$ORIGIN for the libraries and
    # \\\$\$ORIGIN for the programs (single quotes: taken as written). Checked
    # with readelf: RUNPATH [$ORIGIN] on both.
    PLATFORM='--arch=x86_64 --enable-pthreads
      --extra-ldsoflags=-Wl,-rpath,\\\$\$\$\$ORIGIN --extra-ldexeflags=-Wl,-rpath,\\\$\$ORIGIN'
    ;;
  macos-arm64|macos-x64)
    need_host macos
    MACOS_MIN=${MACOS_MIN:-11.0}
    if [ $TARGET = macos-arm64 ]; then A=arm64; FA=aarch64; else A=x86_64; FA=x86_64; fi
    # one clang word for the architecture and the lowest macOS (no spaces:
    # the options are split on spaces); @loader_path: each library finds the
    # others in its own folder
    PLATFORM="--arch=$FA --enable-cross-compile --target-os=darwin --enable-pthreads --cc=clang
      --extra-cflags=--target=$A-apple-macos$MACOS_MIN --extra-ldflags=--target=$A-apple-macos$MACOS_MIN
      --install-name-dir=@loader_path --extra-ldexeflags=-Wl,-rpath,@loader_path"
    ;;
  android-arm64)
    if [ -z "$ANDROID_NDK_HOME" ] || [ ! -d "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" ]; then
      echo "Set ANDROID_NDK_HOME to the Android NDK's folder (r26 or later)"
      exit 1
    fi
    case $HOST in
      linux) NDKHOST=linux-x86_64 ;;
      macos) NDKHOST=darwin-x86_64 ;;
      *) echo "android-arm64 is built on Linux or a Mac (or Windows' WSL)"; exit 1 ;;
    esac
    API=${ANDROID_API:-24}
    TC="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDKHOST"
    # Android's libraries carry no version in their names (libavutil.so):
    # FFmpeg's configure does that for target-os android
    PLATFORM="--enable-cross-compile --target-os=android --arch=aarch64 --cpu=armv8-a
      --enable-pthreads --enable-pic --sysroot=$TC/sysroot
      --cc=$TC/bin/aarch64-linux-android$API-clang --cxx=$TC/bin/aarch64-linux-android$API-clang++
      --ar=$TC/bin/llvm-ar --nm=$TC/bin/llvm-nm --ranlib=$TC/bin/llvm-ranlib --strip=$TC/bin/llvm-strip
      --disable-programs"
    ;;
  *)
    echo "Unknown target $TARGET (windows-x64, linux-x64, macos-arm64, macos-x64, macos, android-arm64)"
    exit 1 ;;
esac

for tool in make nasm; do
  if ! command -v $tool >/dev/null 2>&1; then
    echo "$tool not found (Windows: pacman -S --needed make diffutils nasm pkgconf in MSYS2;"
    echo "Linux: apt install build-essential nasm; macOS: brew install nasm)"
    exit 1
  fi
done

mkdir -p "$BUILD"
cd "$BUILD"
echo "Configuring FFmpeg $(cd "$ROOT/ffmpeg" && git describe --tags 2>/dev/null || echo '(version?)') for $TARGET"
# shellcheck disable=SC2086
"$ROOT/ffmpeg/configure" $COMMON $PLATFORM "$@"

LICENSE=$(sed -n 's/^#define FFMPEG_LICENSE "\(.*\)"/\1/p' config.h)
case "$LICENSE" in
  LGPL*) ;;
  *) echo "The configured licence is \"$LICENSE\", not LGPL: stopped"; exit 1 ;;
esac

make -j"$JOBS"
make install

# dlls/<target>/: the libraries (and ffmpeg / ffprobe, to check files with),
# the licence texts and what was built
rm -rf "$OUT"
mkdir -p "$OUT"
case $TARGET in
  windows-*)
    cp "$PREFIX"/bin/*.dll "$OUT"/
    cp "$PREFIX"/bin/*.exe "$OUT"/ 2>/dev/null || true ;;
  linux-*|android-*)
    cp -a "$PREFIX"/lib/lib*.so* "$OUT"/
    cp "$PREFIX"/bin/ffmpeg "$PREFIX"/bin/ffprobe "$OUT"/ 2>/dev/null || true ;;
  macos-*)
    cp -a "$PREFIX"/lib/lib*.dylib "$OUT"/
    cp "$PREFIX"/bin/ffmpeg "$PREFIX"/bin/ffprobe "$OUT"/ 2>/dev/null || true ;;
esac
cp "$ROOT"/ffmpeg/COPYING.LGPLv2.1 "$ROOT"/ffmpeg/COPYING.LGPLv3 "$ROOT"/ffmpeg/LICENSE.md "$OUT"/
{
  echo "FFmpeg $(cd "$ROOT/ffmpeg" && git describe --tags 2>/dev/null) ($(cd "$ROOT/ffmpeg" && git rev-parse HEAD 2>/dev/null))"
  echo "Licence: $LICENSE"
  echo "Target: $TARGET, built $(date -u '+%Y-%m-%d %H:%M UTC') on $HOST by ffmpeg-dev"
  echo "Source: https://github.com/FFmpeg/FFmpeg (the tag above) + ffmpeg-dev's build.sh"
  echo "Configure: $(sed -n 's/^#define FFMPEG_CONFIGURATION "\(.*\)"/\1/p' config.h)"
} > "$OUT/BUILD-INFO.txt"

echo
echo "Licence: $LICENSE"
echo "Libraries are in $OUT; headers (for TFFMpegAPI's tools/ffmpeg_layout.py) in $PREFIX/include"
