@echo on

dub build --compiler=ldc2 --build=%BUILD% --arch=%ARCH%

sdlfmt.exe --help

7z a sdlfmt.zip sdlfmt.exe
