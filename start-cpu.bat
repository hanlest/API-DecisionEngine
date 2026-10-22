@echo off
rem Laya server on CPU only. Usage: start-cpu.bat [port]
cd /d "%~dp0"
call "%~dp0_start-laya.bat" cpu %*
