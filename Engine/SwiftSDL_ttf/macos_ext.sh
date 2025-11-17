# Set environment variables (replace path with your actual macOS path)
export SDL3_INCLUDE="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL/include"
export SDL3_LIB="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL/build/Release"

export SDL3_TTF_INCLUDE="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_ttf/include"
export SDL3_TTF_LIB="/Users/josephmontanez/Documents/dev/Phrost2/Engine/deps/SDL_ttf/build/Release"

# Run the swift build command
swift build -c release -vv -Xcc "-I${SDL3_INCLUDE}" -Xcc "-I${SDL3_TTF_INCLUDE}"
