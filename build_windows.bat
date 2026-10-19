@echo off
setlocal enabledelayedexpansion
title Building SparkChess for Windows (MSVC)

echo ====================================================
echo        SparkChess Windows Auto-Builder (MSVC)
echo ====================================================
echo.

:: 1. Search for Visual Studio installation path
set "VS_PATH="

if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set "VS_PATH=%%i"
    )
)

if "%VS_PATH%"=="" (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat" set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" set "VS_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat" set "VS_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional"
)

where cl >nul 2>nul
if %errorlevel% equ 0 (
    echo [INFO] Detected MSVC compiler in current environment.
    goto :COMPILE
)

if "%VS_PATH%"=="" (
    echo [ERROR] Visual Studio with C++ tools was not detected automatically.
    echo Please either:
    echo  1. Open "x64 Native Tools Command Prompt for VS" and run this script, OR
    echo  2. Ensure Visual Studio has "Desktop development with C++" installed.
    echo.
    pause
    exit /b 1
)

echo [INFO] Found Visual Studio at: %VS_PATH%
echo [INFO] Initializing x64 build tools...
call "%VS_PATH%\VC\Auxiliary\Build\vcvars64.bat" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to initialize x64 environment.
    pause
    exit /b 1
)

:COMPILE
echo.
echo [INFO] Compiling SparkChess with high-performance flags (/O2 /GL /LTCG /std:c++20)...
if not exist "bin" mkdir "bin"

:: Explicitly compile only the SparkChess core source files
set "SRCS=src\bitboard.cpp src\board.cpp src\book.cpp src\evaluate.cpp src\main.cpp src\movegen.cpp src\nnue.cpp src\search.cpp src\trainer.cpp src\tt.cpp src\uci.cpp src\zobrist.cpp"

cl.exe /O2 /Oi /Ot /GL /std:c++20 /permissive- /EHsc /W3 /Fe:bin\sparkchess.exe %SRCS% /link /LTCG

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Compilation failed! Check error messages above.
    pause
    exit /b 1
)

echo.
echo ====================================================
echo   BUILD SUCCESSFUL!
echo   Executable created: bin\sparkchess.exe
echo ====================================================
echo.
echo Running benchmark verification...
bin\sparkchess.exe bench 5
echo.
echo You can now load bin\sparkchess.exe into Arena, CuteChess, or Lichess Bot!
echo.
pause
