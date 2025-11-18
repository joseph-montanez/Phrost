# --- Setup Paths ---
ROOT := ../../..
SDL_BUILD := $(ROOT)/Engine/deps/SDL/build/Release
SDL_IMG_BUILD := $(ROOT)/Engine/deps/SDL_image/build/Release
SDL_TTF_BUILD := $(ROOT)/Engine/deps/SDL_ttf/build/Release
CHIPMUNK_BUILD := $(ROOT)/Engine/SwiftChipmunk2D/Chipmunk2D.xcframework/macos-arm64_x86_64

# --- PHP Paths ---
PHP_BUILDROOT := $(ROOT)/Engine/deps/buildroot
PHP_INCLUDE := $(PHP_BUILDROOT)/include/php
PHP_LIB_DIR := $(PHP_BUILDROOT)/lib

# Detect Homebrew Path
BREW_PREFIX := $(shell if [ -d /opt/homebrew ]; then echo /opt/homebrew; else echo /usr/local; fi)

# Executable
APP_NAME := Phrost
APP_BUNDLE := $(APP_NAME).app
APP_BIN_DIR := $(APP_BUNDLE)/Contents/MacOS
APP_RESOURCES_DIR := $(APP_BUNDLE)/Contents/Resources

# --- Build Configuration (Debug vs Release) ---
# Usage: make build MODE=release
MODE ?= debug

ifeq ($(MODE),release)
	# Release Fast: Aggressive optimizations, no debug symbols, disable assertions
	CFLAGS := -O3 -ffast-math -DNDEBUG -flto -fvisibility=hidden
	LDFLAGS_OPT := -dead_strip
else
	# Debug: No optimization, debug symbols included
	CFLAGS := -O0 -g
	LDFLAGS_OPT :=
endif

# --- Define Static Libraries ---
STATIC_LIBS := \
	libPhrostShared.a \
	$(SDL_BUILD)/libSDL3.a \
	$(SDL_IMG_BUILD)/libSDL3_image.a \
	$(SDL_TTF_BUILD)/libSDL3_ttf.a \
	$(CHIPMUNK_BUILD)/libChipmunk-Mac.a \
	$(PHP_LIB_DIR)/libphp.a \
	$(PHP_LIB_DIR)/libxml2.a \
	$(PHP_LIB_DIR)/libcurl.a \
	$(PHP_LIB_DIR)/libssl.a \
	$(PHP_LIB_DIR)/libcrypto.a \
	$(PHP_LIB_DIR)/libiconv.a \
	$(PHP_LIB_DIR)/libz.a

# --- Define macOS System Frameworks ---
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
	-framework CoreHaptics \
	-framework SystemConfiguration

# --- Swift Toolchain Lookup ---
SWIFT_BIN := $(shell xcrun -find swiftc)
SWIFT_LIB_PATH := $(shell dirname $(shell dirname $(SWIFT_BIN)))/lib/swift/macosx

# --- Rules ---
all: build

build:
	@echo "--- Building in $(MODE) mode ---"
	@echo "--- Linking C Host (with PHP Thread) ---"
	# Set deployment target to match your libs to reduce warnings
	export MACOSX_DEPLOYMENT_TARGET=14.0; \
	clang main.c ../plugin/event_packer.c php_thread.c -o game_host \
	$(CFLAGS) \
	$(LDFLAGS_OPT) \
	-I . \
	-I ../plugin \
	-I $(PHP_INCLUDE) \
	-I $(PHP_INCLUDE)/main \
	-I $(PHP_INCLUDE)/Zend \
	-I $(PHP_INCLUDE)/TSRM \
	$(STATIC_LIBS) \
	-L "$(SWIFT_LIB_PATH)" \
	-Wl,-rpath,"$(SWIFT_LIB_PATH)" \
	-lswiftCore \
	-lswiftFoundation \
	-lswiftDarwin \
	-lc++ \
	-lpthread \
	-lresolv \
	-L$(BREW_PREFIX)/lib \
	-lfreetype \
	-lharfbuzz \
	$(FRAMEWORKS)

bundle: build
	@echo "--- Creating App Bundle ---"
	mkdir -p $(APP_BIN_DIR)
	mkdir -p $(APP_RESOURCES_DIR)
	cp game_host $(APP_BIN_DIR)/$(APP_NAME)
	cp -r game $(APP_BIN_DIR)/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(APP_BUNDLE)/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '<plist version="1.0">' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '<dict>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleExecutable</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleIdentifier</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>com.phrost.engine</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundleName</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>CFBundlePackageType</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>APPL</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <key>LSMinimumSystemVersion</key>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '    <string>11.0</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '</dict>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '</plist>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo "--- Bundle Created: $(APP_BUNDLE) ---"

.PHONY: all build
