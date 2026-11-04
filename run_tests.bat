@echo off
rem Runs rts_base's tests from a terminal on Windows.
rem Usage:  run_tests.bat "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
rem Or set a GODOT environment variable to that path once and just run: run_tests.bat
rem Use the *_console.exe: the regular Godot exe doesn't print to the terminal.
rem
rem Pass extra options after the exe, behind a -- :
rem   run_tests.bat "...console.exe" -- --only=player --verbose

setlocal
set "GODOT_EXE=%~1"
if "%GODOT_EXE%"=="" set "GODOT_EXE=%GODOT%"
if "%GODOT_EXE%"=="" (
    echo Pass the path to your Godot console exe, or set the GODOT environment variable.
    exit /b 2
)
if not "%~1"=="" shift

cd /d "%~dp0"
"%GODOT_EXE%" --headless --import >nul 2>&1
"%GODOT_EXE%" --headless -s res://tests/run_tests.gd %*
exit /b %ERRORLEVEL%
