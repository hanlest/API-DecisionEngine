@echo off
rem Laya server on GPU (CUDA). Usage: start-gpu.bat [port]
cd /d "%~dp0"
call "%~dp0_start-laya.bat" gpu %*
