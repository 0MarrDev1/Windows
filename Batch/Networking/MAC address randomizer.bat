@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===== Usage =====
REM mac-change.bat "Interface Name"
REM mac-change.bat "Interface Name" revert

REM --- Admin check ---
net session >nul 2>&1 || (echo [!] Run as Administrator.& exit /b 1)

set "IFNAME=%~1"
if not defined IFNAME (
  echo [i] Detected interfaces:
  getmac /v /fo table
  echo.
  set /p "IFNAME=Type the exact Connection Name (e.g. Wi-Fi or Ethernet): "
)

if not defined IFNAME (
  echo [!] No interface selected. Exiting.
  exit /b 2
)

set "ACTION=set"
if /i "%~2"=="revert" set "ACTION=revert"

echo.
echo === Target interface: "%IFNAME%" ===

REM --- Get current MAC ---
for /f "tokens=1,2,3,4,5" %%A in ('getmac /v /fo table ^| findstr /i "%IFNAME%"') do (
  set "OLDMAC=%%C"
)

if not defined OLDMAC (
  echo [!] Could not detect current MAC for "%IFNAME%".
  exit /b 3
)
echo [i] Current MAC: %OLDMAC%

REM --- Get adapter GUID (NetCfgInstanceId) ---
set "NICGUID="
for /f "usebackq tokens=2 delims==" %%G in (`wmic nic where "PhysicalAdapter=true and NetConnectionID='%IFNAME%'" get GUID /value ^| find "="`) do (
  set "NICGUID=%%G"
)
if not defined NICGUID (
  echo [!] Could not find a physical NIC with NetConnectionID "%IFNAME%".
  exit /b 4
)

REM --- Locate registry subkey ---
set "CLASSKEY=HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
set "FOUNDKEY="

for /l %%N in (0,1,99) do (
  set "IDX=0000%%N"
  set "IDX=!IDX:~-4!"
  for /f "tokens=2,*" %%A in ('reg query "%CLASSKEY%\!IDX!" /v NetCfgInstanceId 2^>nul ^| find /i "REG_SZ"') do (
    echo %%B | find /i "%NICGUID%" >nul && set "FOUNDKEY=%CLASSKEY%\!IDX!"
  )
  if defined FOUNDKEY goto :FOUND
)

echo [!] Could not locate registry subkey for "%IFNAME%".
exit /b 5

:FOUND
if /i "%ACTION%"=="revert" goto :DOREVERT

REM --- Generate new MAC ---
set "HEX=ABCDEF0123456789"
set "HEX2=26AE"
set "MAC="
set /a COUNT=0
:gen
set /a COUNT+=1
set /a R=%random%%%16
for %%H in (!R!) do set "CH=!HEX:~%%H,1!"
if "!COUNT!"=="2" (
  set /a R2=%random%%%4
  for %%Q in (!R2!) do set "CH=!HEX2:~%%Q,1!"
)
set "MAC=!MAC!!CH!"
if !COUNT! LSS 12 goto gen

echo [i] New MAC candidate: !MAC!

REM --- Apply override ---
reg add "%FOUNDKEY%" /v NetworkAddress /t REG_SZ /d "!MAC!" /f >nul || (
  echo [!] Failed to write NetworkAddress.
  exit /b 6
)
goto :RESTART

:DOREVERT
echo [i] Clearing NetworkAddress to revert to hardware MAC...
reg add "%FOUNDKEY%" /v NetworkAddress /t REG_SZ /d "" /f >nul
set "MAC=(hardware default)"
goto :RESTART

:RESTART
echo [i] Restarting "%IFNAME%"...
netsh interface set interface name="%IFNAME%" admin=disabled >nul 2>&1
netsh interface set interface name="%IFNAME%" admin=enabled  >nul 2>&1

REM --- Show results ---
for /f "tokens=1,2,3,4,5" %%A in ('getmac /v /fo table ^| findstr /i "%IFNAME%"') do (
  set "NEWMAC=%%C"
)
timeout 5
echo.
echo ====================================
echo   Adapter   : %IFNAME%
echo   Old MAC   : %OLDMAC%
echo   New MAC   : %NEWMAC%
echo ====================================
echo.
echo [*] If Old and New are the same, the driver may ignore overrides.
exit /b 0
