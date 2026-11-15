# CLAUDE.md - working rules for this repository

Read README.md first. The rules follow TFFMpegAPI's and TWhisper's
CLAUDE.md (same owner); where this file is silent, theirs apply.

## Project
github.com/G3DGames/ffmpeg-dev (owner, 2026-11-15: "Similar to whisper-dev
a super make would fit this"; "This will be all supported OSes"). Builds
FFmpeg's shared libraries for TFFMpegAPI's platforms: windows-x64 (Visual
Studio cl through MSYS2, build.bat), linux-x64, macos-arm64 / macos-x64,
android-arm64 (NDK). FFmpeg is the submodule ffmpeg/ at tag n8.1.
- LGPL ONLY: --enable-gpl / --enable-nonfree refused; the licence in
  config.h is checked after configure.
- --disable-autodetect: the same features on every machine; threads
  enabled explicitly per target.
- dlls/<target>/: libraries, ffmpeg / ffprobe, licence texts,
  BUILD-INFO.txt (tag, commit, licence, configure line).

## Rules
- build.sh is POSIX sh (LF - .gitattributes); build.bat CRLF.
- Never commit or push, and don't offer to; the owner does.
- Zips: files changed since the previous zip, paths from the repo root,
  ffmpeg-dev-NN-topic.zip, numbers never reused; every delivery says what
  it goes on top of. Last number used: 01.

## Test notes (zip 01)
- linux-x64 built here (gcc 13, 2 cores: 5 min): LGPL 2.1+; RUNPATH
  [$ORIGIN] on libraries and programs (readelf); ffprobe reads an AAC mp4
  with no LD_LIBRARY_PATH; TFFMpegAPI's FFmpegConsole --check --lgpl,
  --play with --end and --speed 0.75 (avfilter) against dlls/linux-x64.
- The rpath escaping was found by trying: configure drops a level of
  backslashes, make expands $$ once for programs and TWICE for the
  libraries (their link rules go through $(eval)) - see build.sh.
- NOT RUN: windows-x64 (owner: build.bat), macOS, android-arm64.
