@ECHO off
bin\debug\premake5.exe ^
--scripts=modules ^
--to=build ^
vscode %*
