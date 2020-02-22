@ECHO off
bin\debug\premake5.exe ^
--scripts=modules ^
--file=modules\vscode\tests\workspace\premake5.lua ^
vscode %*

REM TODO: Why doesn't this work?
REM --to=build ^
