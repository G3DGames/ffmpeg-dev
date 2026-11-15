@echo off
rem ffmpeg-dev: builds FFmpeg's shared libraries - LGPL, 64-bit - with Visual
rem Studio's compiler and collects them in dlls\windows-x64\
rem
rem Works from any prompt: when the x64 Visual Studio build environment is not
rem active it is set up here (vswhere + vcvars64), as whisper-dev does. FFmpeg's
rem configure is a shell script: it runs in MSYS2's bash (build.sh), which
rem inherits the Visual Studio environment (cl.exe, link.exe, INCLUDE, LIB).
rem
rem Needs: Visual Studio with the C++ workload; MSYS2 in C:\msys64 (or set
rem MSYS2_ROOT) with:  pacman -S --needed make diffutils nasm pkgconf
rem
rem Extra arguments go to FFmpeg's configure, e.g.  build.bat --disable-network
rem set JOBS=n first to limit parallel compiles.
setlocal
cd /d "%~dp0"

if not exist ffmpeg\configure (
  git submodule update --init || exit /b 1
)

if /i "%VSCMD_ARG_TGT_ARCH%"=="x64" goto have_env
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo vswhere.exe not found: install Visual Studio with the C++ workload
  exit /b 1
)
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR (
  echo Visual Studio with the C++ x64 tools not found
  exit /b 1
)
echo Setting up the x64 build environment of %VSDIR%
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
:have_env

if not defined MSYS2_ROOT set "MSYS2_ROOT=C:\msys64"
if not exist "%MSYS2_ROOT%\usr\bin\bash.exe" (
  echo MSYS2 not found in %MSYS2_ROOT%: install it from https://www.msys2.org
  echo or set MSYS2_ROOT to its folder
  exit /b 1
)

rem MSYS2's bash: the plain MSYS environment (no MinGW compiler on PATH), the
rem Windows PATH - with Visual Studio's tools - after its own, started here
set "MSYSTEM=MSYS"
set "MSYS2_PATH_TYPE=inherit"
set "CHERE_INVOKING=1"
set "FFMPEG_DEV_ARGS=%*"
"%MSYS2_ROOT%\usr\bin\bash.exe" -lc "./build.sh windows-x64"
if errorlevel 1 exit /b 1
echo.
echo Libraries are in %~dp0dlls\windows-x64
