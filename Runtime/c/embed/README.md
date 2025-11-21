
## Windows Debug

    Remove-Item -Recurse -Force .\out\build\arm64-Debug
    cmake -S . -B out/build/arm64-Debug -G "Visual Studio 17 2022" -A ARM64
    cmake --build out/build/arm64-Debug
    out\build\arm64-Debug\Debug\PhrostHost.exe

## Windows Release

    Remove-Item -Recurse -Force .\out\build\arm64-Release
    cmake -S . -B out/build/arm64-Release -G "Visual Studio 17 2022" -A ARM64
    cmake --build out/build/arm64-Release --config Release
    out\build\arm64-Release\Release\PhrostHost.exe
