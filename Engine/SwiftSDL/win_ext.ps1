
$env:SDL3_INCLUDE = "D:/dev/SDL3-arm64/include"
$env:SDL3_LIB = "D:/dev/SDL3-arm64/lib"

swift build -c debug -vv -Xcc "-I$($env:SDL3_INCLUDE)"