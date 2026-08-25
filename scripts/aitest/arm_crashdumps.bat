@echo off
rem Arms Windows LocalDumps for AoE3DE_s.exe: every crash leaves a minidump
rem (~2-10 MB) in Games\Age of Empires 3 DE\CrashDumps, keeping the last 10.
rem RIGHT-CLICK -> RUN AS ADMINISTRATOR (HKLM needs elevation).
rem Read a dump afterwards with: python scripts\aitest\crashdump_triage.py <file.dmp>

set KEY=HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\AoE3DE_s.exe
set DUMPDIR=C:\Users\rosti\Games\Age of Empires 3 DE\CrashDumps

if not exist "%DUMPDIR%" mkdir "%DUMPDIR%"
reg add "%KEY%" /f
reg add "%KEY%" /v DumpFolder /t REG_EXPAND_SZ /d "%DUMPDIR%" /f
reg add "%KEY%" /v DumpCount /t REG_DWORD /d 10 /f
reg add "%KEY%" /v DumpType /t REG_DWORD /d 1 /f
echo.
echo LocalDumps armed for AoE3DE_s.exe - dumps land in %DUMPDIR%
pause
