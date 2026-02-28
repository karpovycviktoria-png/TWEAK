@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

title NUCLEAR BOOST / RESTORE DEFAULTS
color 0C

:: ------------------------------
:: Admin check
:: ------------------------------
net session >nul 2>&1
if not %errorlevel%==0 (
  echo [!] Запусти файл от имени администратора.
  pause
  exit /b 1
)

set "STATE_DIR=%ProgramData%\NuclearBoost"
set "RAMTRIM_PS=%STATE_DIR%\ramtrim.ps1"
set "RAMTRIM_PID=%STATE_DIR%\ramtrim.pid"
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1

echo.
echo ==============================================
echo        N U C L E A R   B O O S T
 echo ==============================================
echo 1 ^) NUCLEAR BOOST  (агрессивный режим)
echo 2 ^) RESTORE DEFAULTS
echo 3 ^) Выход
echo.
set /p MODE=Выбери режим [1-3]: 

if "%MODE%"=="1" goto :BOOST
if "%MODE%"=="2" goto :RESTORE
if "%MODE%"=="3" exit /b 0

echo [!] Неверный выбор.
exit /b 1

:BOOST
cls
color 4F
echo [!] ВНИМАНИЕ: режим может ухудшить стабильность и безопасность системы.
choice /C YN /N /M "Продолжить? [Y/N]: "
if errorlevel 2 exit /b 0

echo [1/10] Убийство explorer.exe ...
taskkill /f /im explorer.exe >nul 2>&1

echo [2/10] Отключение ограничений Spectre/Meltdown (нужна перезагрузка) ...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f >nul

echo [3/10] Игровой приоритет в планировщике ...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v Priority /t REG_DWORD /d 6 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d High /f >nul

echo [4/10] План питания Ultimate Performance ...
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
for /f "tokens=2 delims=:" %%i in ('powercfg -list ^| findstr /i "Ultimate Performance Максимальная производительность"') do (
  set "UP_GUID=%%i"
)
if defined UP_GUID (
  set "UP_GUID=!UP_GUID: =!"
  powercfg -setactive !UP_GUID! >nul 2>&1
) else (
  powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
)

echo [5/10] Очистка shader cache (NVIDIA/AMD/DirectX) ...
for %%D in (
  "%LocalAppData%\NVIDIA\DXCache"
  "%LocalAppData%\NVIDIA\GLCache"
  "%LocalAppData%\NVIDIA\ComputeCache"
  "%LocalAppData%\AMD\DxCache"
  "%LocalAppData%\AMD\GLCache"
  "%LocalAppData%\D3DSCache"
) do (
  if exist %%~D rd /s /q %%~D >nul 2>&1
  mkdir %%~D >nul 2>&1
)

echo [6/10] Запуск фоновой очистки памяти (каждые 8 сек) ...
>"%RAMTRIM_PS%" (
  echo while ^($true^) {
  echo   ^$null = [System.GC]::Collect^(^)
  echo   Start-Sleep -Seconds 8
  echo }
)
for /f %%p in ('powershell -NoProfile -WindowStyle Hidden -Command "^$p = Start-Process PowerShell -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%RAMTRIM_PS%\"'' -PassThru; ^$p.Id"') do set RAM_PID=%%p
if defined RAM_PID echo %RAM_PID%>"%RAMTRIM_PID%"

echo [7/10] Остановка служб WSearch / DiagTrack / Spooler ...
for %%S in (WSearch DiagTrack Spooler) do (
  sc stop %%S >nul 2>&1
  sc config %%S start= demand >nul 2>&1
)

echo [8/10] Жесткая очистка временных файлов ...
for %%T in ("%TEMP%" "%SystemRoot%\Temp") do (
  if exist %%~T del /f /s /q "%%~T\*" >nul 2>&1
)

echo [9/10] Отключение HAGS/GameDVR overlays ...
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f >nul

echo [10/10] Форс отключения idle timeout ...
powercfg -change -monitor-timeout-ac 0 >nul 2>&1
powercfg -change -disk-timeout-ac 0 >nul 2>&1
powercfg -change -standby-timeout-ac 0 >nul 2>&1

color 0A
echo.
echo [+] NUCLEAR BOOST применен.
echo [+] Рекомендуется перезагрузка для применения mitigation/power параметров.
pause
exit /b 0

:RESTORE
cls
color 1F
echo [1/8] Возврат explorer.exe ...
start explorer.exe

echo [2/8] Возврат защит Spectre/Meltdown ...
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /f >nul 2>&1

echo [3/8] Сброс игровых приоритетов и сетевых лимитов ...
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 2 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v Priority /t REG_DWORD /d 2 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d Medium /f >nul

echo [4/8] Возврат плана питания Balanced ...
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1

echo [5/8] Остановка фоновой очистки ОЗУ ...
if exist "%RAMTRIM_PID%" (
  set /p PID=<"%RAMTRIM_PID%"
  taskkill /f /pid !PID! >nul 2>&1
  del /f /q "%RAMTRIM_PID%" >nul 2>&1
)
del /f /q "%RAMTRIM_PS%" >nul 2>&1

echo [6/8] Запуск остановленных служб ...
for %%S in (WSearch DiagTrack Spooler) do (
  sc config %%S start= auto >nul 2>&1
  sc start %%S >nul 2>&1
)

echo [7/8] Возврат параметров GameDVR/HAGS ...
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 1 /f >nul
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 1 /f >nul
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /f >nul 2>&1

echo [8/8] Возврат энергосбережения ...
powercfg -change -monitor-timeout-ac 15 >nul 2>&1
powercfg -change -disk-timeout-ac 20 >nul 2>&1
powercfg -change -standby-timeout-ac 30 >nul 2>&1

color 0A
echo.
echo [+] RESTORE DEFAULTS завершен.
echo [+] Для полного возврата параметров рекомендуется перезагрузка.
pause
exit /b 0
