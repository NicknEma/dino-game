@echo off

set root=%cd%
set opts=-debug

if not exist build mkdir build
pushd build
odin build %root%\source %opts% -out:dino.exe
popd
