@echo off
setlocal
cd /d "%~dp0"

set "AGENTGUARD_VENV=%~dp0.venv"
set "AGENTGUARD_PYTHON=%AGENTGUARD_VENV%\Scripts\python.exe"
set "AGENTGUARD_PORT=8001"
set "PYTHONPATH=%~dp0"

if not exist "%AGENTGUARD_PYTHON%" (
    echo Creating the AgentGuard Python environment...
    py -3 -m venv "%AGENTGUARD_VENV%" >nul 2>nul
    if errorlevel 1 python -m venv "%AGENTGUARD_VENV%"
)

if not exist "%AGENTGUARD_PYTHON%" (
    echo ERROR: Python 3 is required but could not be found.
    echo Install Python 3.10 or newer, then run this file again.
    pause
    exit /b 1
)

"%AGENTGUARD_PYTHON%" -c "import fastapi, uvicorn" >nul 2>nul
if errorlevel 1 (
    echo Installing AgentGuard dependencies. An internet connection is required the first time.
    "%AGENTGUARD_PYTHON%" -m pip install -r requirements.txt
    if errorlevel 1 goto install_failed
)

netstat -ano | findstr /R /C:":%AGENTGUARD_PORT% .*LISTENING" >nul
if errorlevel 1 (
    echo Starting AgentGuard API and dashboard...
    start "AgentGuard API" /min "%AGENTGUARD_PYTHON%" -m uvicorn agentguard.api:app --host 127.0.0.1 --port %AGENTGUARD_PORT%
) else (
    echo ERROR: Port %AGENTGUARD_PORT% is already in use.
    echo Close the other service or change AGENTGUARD_PORT in this file.
    pause
    exit /b 1
)

timeout /t 3 /nobreak >nul
echo AgentGuard dashboard: http://127.0.0.1:%AGENTGUARD_PORT%
echo API documentation:    http://127.0.0.1:%AGENTGUARD_PORT%/docs
start "" "http://127.0.0.1:%AGENTGUARD_PORT%"
endlocal
exit /b 0

:install_failed
echo.
echo ERROR: Dependency installation did not complete.
echo Check your internet connection, then run this file again.
echo You can also install manually with:
echo   "%AGENTGUARD_PYTHON%" -m pip install -r requirements.txt
pause
endlocal
exit /b 1
