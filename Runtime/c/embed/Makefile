# --- 1. Setup Paths ---
ROOT := ../../..
SDL_BUILD := $(ROOT)/Engine/deps/SDL/build/Release
SDL_IMG_BUILD := $(ROOT)/Engine/deps/SDL_image/build/Release
SDL_TTF_BUILD := $(ROOT)/Engine/deps/SDL_ttf/build/Release
CHIPMUNK_BUILD := $(ROOT)/Engine/SwiftChipmunk2D/Chipmunk2D.xcframework/macos-arm64_x86_64

# Detect Homebrew Path
BREW_PREFIX := $(shell if [ -d /opt/homebrew ]; then echo /opt/homebrew; else echo /usr/local; fi)

# --- 2. Define Static Libraries ---
STATIC_LIBS := \
	libPhrostShared.a \
	$(SDL_BUILD)/libSDL3.a \
	$(SDL_IMG_BUILD)/libSDL3_image.a \
	$(SDL_TTF_BUILD)/libSDL3_ttf.a \
	$(CHIPMUNK_BUILD)/libChipmunk-Mac.a

# --- 3. Define macOS System Frameworks ---
# ADDED: QuartzCore (Fixes _OBJC_CLASS_$_CAMetalLayer error)
FRAMEWORKS := \
	-framework Cocoa \
	-framework IOKit \
	-framework Carbon \
	-framework CoreVideo \
	-framework CoreAudio \
	-framework AudioToolbox \
	-framework Metal \
	-framework QuartzCore \
	-framework CoreFoundation \
	-framework Foundation \
	-framework GameController \
	-framework ForceFeedback \
	-framework UniformTypeIdentifiers \
	-framework AVFoundation \
	-framework CoreMedia \
	-framework CoreHaptics

# --- 4. Swift Toolchain Lookup ---
SWIFT_BIN := $(shell xcrun -find swiftc)
SWIFT_LIB_PATH := $(shell dirname $(shell dirname $(SWIFT_BIN)))/lib/swift/macosx

# --- Rules ---
all: build

build:
	@echo "--- Linking C Host ---"
	# Set deployment target to match your libs to reduce warnings
	export MACOSX_DEPLOYMENT_TARGET=14.0; \
	clang main.c ../plugin/event_packer.c -o game_host \
	-I . \
	$(STATIC_LIBS) \
	-L "$(SWIFT_LIB_PATH)" \
	-Wl,-rpath,"$(SWIFT_LIB_PATH)" \
	-lswiftCore \
	-lswiftFoundation \
	-lswiftDarwin \
	-lc++ \
	-L$(BREW_PREFIX)/lib \
	-lfreetype \
	-lharfbuzz \
	$(FRAMEWORKS)

.PHONY: all build
