# ffmpeg-dev

Builds **FFmpeg 8.1.3's shared libraries, LGPL, 64-bit** for every platform
[TFFMpegAPI](https://github.com/G3DGames/TFFMpegAPI) supports - and so for
TWhisper and the WhisperBooks reader - and collects each platform's in
`dlls/<target>/`. FFmpeg is a submodule pinned to the release tag `n8.1.3`;
`build.sh` is the one build script, and `build.bat` sets Windows up for it.

```
git clone --recurse-submodules https://github.com/G3DGames/ffmpeg-dev
cd ffmpeg-dev
```

`--recurse-submodules` also fetches FFmpeg's source (`ffmpeg/`, about
500 MB of history): it takes a few minutes. A clone made without it gets
the source with `git submodule update --init`. (Setting up a new copy of
this repository from scratch: see "Adding FFmpeg's source" below.)

Then, by platform (every block below can be pasted as it is):

```
build.bat
```

builds `dlls\windows-x64` on Windows;

```
./build.sh
```

builds `dlls/linux-x64` on Linux, or the Mac's own architecture on a Mac.
Built that way on Linux, the libraries need the build system's glibc or
newer; **for libraries that run on every Linux (glibc 2.35+), build in
whisper-dev's container instead** - `container-build/build.sh
../ffmpeg-dev` from a whisper-dev clone next to this one, with Docker or
Podman (whisper-dev's `container-build/README.md` explains all of it);

```
./build.sh macos
```

builds `dlls/macos-arm64` and `dlls/macos-x64` on a Mac;

```
./build.sh android-arm64
```

builds `dlls/android-arm64` on Linux or a Mac, with `ANDROID_NDK_HOME` set.

## Targets

| Target | Delphi platform | Built on | Compiler | Files in `dlls/<target>/` |
|---|---|---|---|---|
| `windows-x64` | Win64 | Windows (`build.bat`) | Visual Studio's cl, C runtime linked in (`-MT`) | `avutil-60.dll`, `swresample-6.dll`, `avcodec-62.dll`, `avformat-62.dll`, `swscale-9.dll`, `avfilter-11.dll`, `ffmpeg.exe`, `ffprobe.exe` |
| `linux-x64` | Linux64 | Linux | gcc | `libavutil.so.60`, ... (each finds the others in its own folder: rpath `$ORIGIN`), `ffmpeg`, `ffprobe` |
| `macos-arm64` | OSXARM64 | a Mac | Apple clang | `libavutil.60.dylib`, ... (`@loader_path`), `ffmpeg`, `ffprobe` |
| `macos-x64` | OSX64 | a Mac | Apple clang | as above |
| `android-arm64` | Android64 | Linux or a Mac | the NDK's clang | `libavutil.so`, ... (Android's libraries carry no version in their names) |

Every folder also gets FFmpeg's licence texts (`COPYING.LGPLv2.1`,
`COPYING.LGPLv3`, `LICENSE.md`) and `BUILD-INFO.txt`: the tag, the commit,
the licence, the target and the full configure line. The headers go to
`install/<target>/include` (TFFMpegAPI's `tools/ffmpeg_layout.py` reads
them; the C layout is the same on every 64-bit target).

FFmpeg is configured with `--prefix=/usr/local` and installed through
`DESTDIR` into `install/<target>`: the configure line is compiled into
the libraries (TFFMpegAPI shows it as "Build options"), and a prefix
naming the build folder put that machine's path - user name included -
into the logs of everyone who uses the libraries. `/usr/local` is never
used at run time.

**Licence: LGPL.** No `--enable-gpl`, no `--enable-nonfree`: `build.sh`
refuses both, and stops if configure reports anything but an LGPL licence.
FFmpeg's own decoders cover what TFFMpegAPI plays (AAC / M4B, MP3, Opus,
Vorbis, FLAC, WAV, ...); no external library is used.

**The same features everywhere:** `--disable-autodetect`, so nothing is
picked up from whatever else is installed on the build machine. Threads
are enabled explicitly. Not built: avdevice (capture devices), ffplay, the
docs. Extra arguments after the target go to configure.

Variables: `JOBS=n` limits the parallel compiles; `MACOS_MIN` (default
`11.0`) and `ANDROID_API` (default `24`) are the lowest system versions
the libraries run on.

## Adding FFmpeg's source (once, in a new repository)

The repository records FFmpeg as a submodule pinned to a release tag.
When the repository is new, or `ffmpeg/` was never added, `build.bat` /
`build.sh` stop with "FFmpeg's source is missing". Add it from the
repository's folder (PowerShell, cmd or a shell - the same commands):

```
git submodule add https://github.com/FFmpeg/FFmpeg.git ffmpeg
```

This downloads FFmpeg's whole history - about 500 MB, 800 000+ objects -
which takes a few minutes. On Windows Git may also say
`warning: in the working copy of '.gitmodules', LF will be replaced by
CRLF`: harmless, Git reads the file either way. Then pin the version:

```
git -C ffmpeg checkout n8.1.3
```

Git answers `Note: switching to 'n8.1.3'. You are in 'detached HEAD'
state ...` and `HEAD is now at 1041abdc96 ...`: that is what a pinned
submodule is - it points at the tag's commit, not at a branch. Nothing to
do about it; ignore the advice about `git switch`. Record the submodule:

```
git add .
git commit -m "FFmpeg n8.1.3 submodule"
```

and push. Clones made with `--recurse-submodules` then get FFmpeg at that
commit.

## Windows

Once per machine:

1. **Visual Studio** (2022 or 2026) with the **Desktop development with
   C++** workload - the same as for whisper-dev.
2. **MSYS2** from https://www.msys2.org, installed in `C:\msys64` (or set
   `MSYS2_ROOT` to its folder). FFmpeg's configure is a shell script: MSYS2
   gives it bash and make. The compiler is still Visual Studio's.
3. In the **MSYS2 MSYS** shell (from the Start menu), update it:
   ```
   # it may close the shell when it is done: open it again and run it again
   pacman -Syu
   ```
   then add the build tools:
   ```
   pacman -S --needed make diffutils nasm pkgconf
   ```
4. **Git for Windows**, as for whisper-dev.

Then, from any prompt (cmd, PowerShell, the IDE's terminal):

```
cd ffmpeg-dev
build.bat
```

It finds Visual Studio (vswhere, vcvars64), starts MSYS2's bash with that
environment and runs `build.sh windows-x64`: configure, about 10 to 20
minutes of compiling, install, then `dlls\windows-x64`. `set JOBS=4` first
limits the parallel compiles. Running it again reuses
`build\windows-x64` and compiles only what changed.

Windows Defender scanning every object file slows the build a lot:
excluding the ffmpeg-dev folder from real-time scanning helps.

## Linux

```
sudo apt install build-essential nasm git
./build.sh
```

## macOS

Xcode's command line tools and nasm:

```
xcode-select --install
brew install nasm
```

Either Mac builds both architectures:

```
./build.sh macos
```

## Android

The Android NDK (r26 or later; Android Studio's SDK Manager installs it,
or download it) on Linux or a Mac (on Windows: WSL):

```
# your NDK's folder (Android Studio puts it under Sdk/ndk/<version>):
export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/27.2.12479018
./build.sh android-arm64
```

Delphi deploys the `.so` files with the app (Project > Deployment, remote
path `library\lib\arm64-v8a\`).

## Using the libraries

Copy `dlls\<target>` next to the program (`demos\FFmpegConsole\Win64\Debug`,
`WhisperDemo`, `EpubReader`, ...), or pass the folder (`FFmpegConsole
--ffmpeg <folder>`, `TFFmpegLibrary.Create('<folder>')`). Check it:

```
rem the folder of your ffmpeg-dev clone, and an audio file of yours:
set FFDLLS=C:\Dev\ffmpeg-dev\dlls\windows-x64
set AUDIO=C:\Books\book.m4b
FFmpegConsole --check --lgpl --ffmpeg %FFDLLS%
FFmpegConsole %AUDIO% --play --start 60 --end 65 --speed 0.75 --ffmpeg %FFDLLS%
```

(cmd; in PowerShell write `$env:FFDLLS = "..."` and `$env:FFDLLS`.)

`--lgpl` refuses anything but an LGPL build; `--speed` uses avfilter.

## Shipping them (LGPL - guidance, not legal advice)

The libraries are loaded dynamically, as the LGPL expects. With a program
that ships them:
- include the licence texts from `dlls/<target>` and say which FFmpeg it
  is (`BUILD-INFO.txt`);
- say where the source is: FFmpeg's tag `n8.1.3` (the commit in
  `BUILD-INFO.txt`) and this repository's scripts, which rebuild it;
- let users replace the libraries with their own build (TFFMpegAPI loads
  them by name from a folder, so they can).

## Another FFmpeg version

```
cd ffmpeg
git fetch --tags
git checkout n8.2
cd ..
git add ffmpeg
git commit -m "FFmpeg n8.2"
```

A new **major** version of a library (avutil 61, ...) also needs
TFFMpegAPI's `tools/ffmpeg_layout.py` rerun on `install/<target>/include`
(the binding checks the majors when it loads).

## Layout

- `ffmpeg/` - FFmpeg, submodule (https://github.com/FFmpeg/FFmpeg), tag `n8.1.3`
- `build.sh` - the build, every target
- `build.bat` - Windows: Visual Studio + MSYS2, then `build.sh windows-x64`
- `build/<target>/`, `install/<target>/`, `dlls/` - made by the build (not in git)
