@echo off
rem Internal launcher for start.bat / start-gpu.bat / start-cpu.bat
rem   _start-laya.bat gpu|cpu|auto [port]
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "MODE=%~1"
set "PORT=%~2"
if "%MODE%"=="" set "MODE=auto"
if "%PORT%"=="" set "PORT=8002"

set "TORCH_INDEX=https://download.pytorch.org/whl/cpu"
set "TORCH_LABEL=CPU"
set "LAYA_DEVICE=cpu"
set "SERVER_DEVICE=cpu"
set "ENSURE_TORCH=cpu"

if /i "%MODE%"=="gpu" (
    set "TORCH_INDEX=https://download.pytorch.org/whl/cu124"
    set "TORCH_LABEL=NVIDIA GPU (CUDA 12.4)"
    set "LAYA_DEVICE=cuda"
    set "SERVER_DEVICE=cuda"
    set "ENSURE_TORCH=gpu"
    where nvidia-smi >nul 2>&1
    if errorlevel 1 (
        echo [error] start-gpu requires an NVIDIA GPU and nvidia-smi on PATH.
        exit /b 1
    )
) else if /i "%MODE%"=="cpu" (
    rem defaults above
) else if /i not "%MODE%"=="auto" (
    echo [error] Unknown mode "%MODE%". Use gpu, cpu, or auto.
    exit /b 1
) else (
    where nvidia-smi >nul 2>&1
    if not errorlevel 1 (
        set "TORCH_INDEX=https://download.pytorch.org/whl/cu124"
        set "TORCH_LABEL=NVIDIA GPU (CUDA 12.4)"
        set "LAYA_DEVICE=cuda"
        set "SERVER_DEVICE=cuda"
        set "ENSURE_TORCH=gpu"
    )
)

if not exist ".venv\Scripts\python.exe" (
    echo [setup] Creating virtual environment...
    set "PYEXE="
    for %%V in (3.13 3.12 3.11 3.10) do if not defined PYEXE (py -%%V -c "pass" >nul 2>&1 && set "PYEXE=py -%%V")
    if not defined PYEXE (
        echo [error] No supported Python found. Install Python 3.10 or newer from python.org.
        exit /b 1
    )
    !PYEXE! -m venv .venv || goto :fail
    ".venv\Scripts\python.exe" -m pip install -q --upgrade pip || goto :fail
    echo [setup] Installing PyTorch for !TORCH_LABEL!...
    ".venv\Scripts\python.exe" -m pip install -q torch --index-url "!TORCH_INDEX!" || goto :fail
    ".venv\Scripts\python.exe" -m pip install -q -e ".[serve]" || goto :fail
) else (
    ".venv\Scripts\python.exe" -c "import fastapi" >nul 2>&1
    if errorlevel 1 (
        echo [setup] Installing serve dependencies in existing .venv...
        ".venv\Scripts\python.exe" -m pip install -q -e ".[serve]" || goto :fail
    )
    if /i "!ENSURE_TORCH!"=="gpu" call :ensure_gpu_torch
)

set USE_TF=0
set USE_TORCH=1
set TOKENIZERS_PARALLELISM=false
set PYTHONUTF8=1
echo Laya UI: http://localhost:%PORT%   Mode: %MODE%   PyTorch: %TORCH_LABEL%   (Ctrl+C to stop)
start "" /b cmd /c "timeout /t 8 /nobreak >nul & start http://localhost:%PORT%"
".venv\Scripts\python.exe" examples\server.py --host 127.0.0.1 --port %PORT% --device %SERVER_DEVICE%
goto :eof

:ensure_gpu_torch
".venv\Scripts\python.exe" -c "import torch,sys; sys.exit(0 if torch.cuda.is_available() else 1)" >nul 2>&1
if not errorlevel 1 goto :eof
echo [setup] Installing CUDA PyTorch build...
".venv\Scripts\python.exe" -m pip install -q --force-reinstall torch --index-url "%TORCH_INDEX%" || exit /b 1
goto :eof

:fail
echo [error] Setup failed. See the messages above.
exit /b 1
