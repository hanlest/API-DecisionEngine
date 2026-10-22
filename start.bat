@echo off
rem Start the Laya web UI + API on http://localhost:8002
rem Usage: start.bat [port]   (GPU if nvidia-smi is available, else CPU)
cd /d "%~dp0"
call "%~dp0_start-laya.bat" auto %*
