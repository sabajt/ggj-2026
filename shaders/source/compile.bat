@echo off
for %%f in (*.vert.hlsl *.frag.hlsl *.comp.hlsl) do (
    call :compile "%%f"
)
goto :eof

:compile
set "full=%~n1"
set "base=%full:.vert=%"
set "base=%base:.frag=%"
set "base=%base:.comp=%"
set "ext=.vert"
echo %full% | findstr /i ".frag." >nul && set "ext=.frag"
echo %full% | findstr /i ".comp." >nul && set "ext=.comp"
shadercross "%~1" -o "..\compiled\spirv\%base%%ext%.spv"
shadercross "%~1" -o "..\compiled\msl\%base%%ext%.msl"
shadercross "%~1" -o "..\compiled\dxil\%base%%ext%.dxil"
goto :eof
