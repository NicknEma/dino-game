@echo off

set root=%cd%
set opts=-debug -o:speed -vet-shadowing -vet-unused-variables -vet-cast -vet-using-param -vet-using-stmt

if not exist build mkdir build
pushd build
del dino.pdb > NUL 2> NUL
rc /nologo /fodino_resources.res %root%\source\dino_resources.rc
odin build %root%\source %opts% -out:dino.exe -subsystem:windows -extra-linker-flags:"dino_resources.res"
del *.res > NUL 2> NUL
popd
