# CLAUDE.md - working rules for this repository

Read README.md first. The rules follow TFFMpegAPI's and TWhisper's
CLAUDE.md (same owner); where this file is silent, theirs apply.

## Project
github.com/G3DGames/ffmpeg-dev (owner, 2026-11-15: "Similar to whisper-dev
a super make would fit this"; "This will be all supported OSes"). Builds
FFmpeg's shared libraries for TFFMpegAPI's platforms: windows-x64 (Visual
Studio cl through MSYS2, build.bat), linux-x64, macos-arm64 / macos-x64,
android-arm64 (NDK). FFmpeg is the submodule ffmpeg/ at tag n8.1.3 (zip 05; was n8.1).
- LGPL ONLY: --enable-gpl / --enable-nonfree refused; the licence in
  config.h is checked after configure.
- --disable-autodetect: the same features on every machine; threads
  enabled explicitly per target.
- dlls/<target>/: libraries, ffmpeg / ffprobe, licence texts,
  BUILD-INFO.txt (tag, commit, licence, configure line).

## Rules
- build.sh is POSIX sh (LF - .gitattributes); build.bat CRLF.
- README code blocks must paste and run as they are (owner, zip 02): no
  notes on command lines - comments on their own line (# in a shell,
  rem in cmd), no <placeholders> (cmd reads < as a redirection): set a
  variable instead.
- Never commit or push, and don't offer to; the owner does.
- Zips: files changed since the previous zip, paths from the repo root,
  ffmpeg-dev-NN-topic.zip, numbers never reused; every delivery says what
  it goes on top of. Last number used: 06.

## Owner's first run (zip 03)
build.bat in a clone without the submodule: 'git submodule update --init'
succeeded with nothing to do, and build.sh went on to configure ("cd:
.../ffmpeg: No such file"). Both scripts now stop with the two commands
that add it. Zip 04 (owner: "The docs should state this will happen and
inform of what to do"): README "Adding FFmpeg's source" - the two
commands, the ~500 MB download, the .gitmodules LF/CRLF warning, the
detached HEAD message (expected for a pinned submodule), add + commit.

## n8.1.3 (zip 05)
Owner, 2026-11-15: "Are we on the latest version of 8.1 (which is 8.1.3)".
Same library majors as n8.1 (avutil 60, avcodec 62, avformat 62,
swresample 6, swscale 9, avfilter 11): no TFFMpegAPI change. Built here
(linux-x64, commit 1041abdc96): LGPL 2.1+, ffmpeg_layout.py 0 errors,
FFmpegConsole --check --lgpl and --play --end --speed 0.75 pass.

## Owner's Windows build (2026-11-15)
build.bat on Windows 11, Visual Studio 2026 (folder 18), MSYS2: n8.1.3
built; FFmpegConsole --check --lgpl accepts it - LGPL version 2.1 or
later, configure line exactly build.sh's windows-x64 one (--toolchain=msvc
--target-os=win64 --enable-w32threads --extra-cflags=-MT,
--disable-autodetect ...); TFFMpegAPI's play range and speed (avfilter)
work with it on WASAPI. First setup: the submodule was not added yet
(zip 03 / 04 cover it).

## Test notes (zip 01)
- linux-x64 built here (gcc 13, 2 cores: 5 min): LGPL 2.1+; RUNPATH
  [$ORIGIN] on libraries and programs (readelf); ffprobe reads an AAC mp4
  with no LD_LIBRARY_PATH; TFFMpegAPI's FFmpegConsole --check --lgpl,
  --play with --end and --speed 0.75 (avfilter) against dlls/linux-x64.
- The rpath escaping was found by trying: configure drops a level of
  backslashes, make expands $$ once for programs and TWICE for the
  libraries (their link rules go through $(eval)) - see build.sh.
- NOT RUN: windows-x64 (owner: build.bat), macOS, android-arm64.
