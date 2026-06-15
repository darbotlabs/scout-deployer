@echo off
:: ScoutDeployer.cmd — double-click launcher for ScoutDeployer.ps1
:: Runs in the directory of this .cmd file so relative paths (Logs\, connectors\, etc.) resolve correctly.
setlocal

cd /d "%~dp0"

echo.
echo ============================================================
echo  ScoutDeployer — Microsoft Scout Cluster Node Provisioner
echo  Cypherdyne Tenant  /  timelarp.com
echo  App reg: cb08267c-55a2-4f0d-9c5a-58d90444b82d
echo ============================================================
echo.

:: Require PowerShell 5.1+
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: powershell.exe not found. Install PowerShell 5.1 or later.
    pause
    exit /b 1
)

:: Launch the script with Bypass so double-click works even on restricted machines
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ScoutDeployer.ps1" %*

set EXIT_CODE=%ERRORLEVEL%

echo.
if %EXIT_CODE% equ 0 (
    echo ScoutDeployer completed successfully.
) else (
    echo ScoutDeployer exited with code %EXIT_CODE%. Check Logs\ for details.
)

echo.
pause
exit /b %EXIT_CODE%
