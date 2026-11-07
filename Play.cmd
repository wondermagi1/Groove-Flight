@echo off
setlocal
set "GODOT_EXE=D:\Tool\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if defined GODOT_PATH if exist "%GODOT_PATH%" set "GODOT_EXE=%GODOT_PATH%"
if not exist "%GODOT_EXE%" (
  echo Open project.godot in Godot 4.7.2 and press F5.
  pause
  exit /b 1
)
rem Scan changed assets on every launch, including newly updated city GLBs.
"%GODOT_EXE%" --headless --editor --path "%~dp0." --import --quit --log-file "%TEMP%\GrooveFlight-import.log"
if errorlevel 1 (
  echo Asset import failed. See %%TEMP%%\GrooveFlight-import.log
  pause
  exit /b 1
)
set "RENDERER=%GROOVE_FLIGHT_RENDERER%"
if not defined RENDERER set "RENDERER=%BEATDRIFT_RENDERER%"
if /I "%RENDERER%"=="compatibility" (
  start "" "%GODOT_EXE%" --rendering-method gl_compatibility --path "%~dp0."
) else (
  start "" "%GODOT_EXE%" --path "%~dp0."
)
