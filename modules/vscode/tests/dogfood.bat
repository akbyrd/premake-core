@ECHO off
bin\debug\premake5.exe ^
--scripts=modules ^
vscode %*

REM TODO: Why doesn't this work?
REM --to=build ^
