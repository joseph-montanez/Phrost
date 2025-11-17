#!/usr/bin/env bash

set -eu

# Clean build directory
rm -rdf build
git clone --recursive https://github.com/slembcke/Chipmunk2D.git build/Chipmunk2D

pushd build/Chipmunk2D

# Checkout the required release version (adjust if needed)
git checkout master --force  # You can specify a release tag or branch here

# Apply the fixes for the missing void in function declarations (for declaration)
find . -name "cpSweep1D.c" -exec sed -i '' 's/static inline cpSpatialIndexClass \*Klass();/static inline cpSpatialIndexClass \*Klass(void);/g' {} +
find . -name "cpSpaceHash.c" -exec sed -i '' 's/static inline cpSpatialIndexClass \*Klass();/static inline cpSpatialIndexClass \*Klass(void);/g' {} +
find . -name "cpBBTree.c" -exec sed -i '' 's/static inline cpSpatialIndexClass \*Klass();/static inline cpSpatialIndexClass \*Klass(void);/g' {} +

# Apply the fixes for the missing void in function definitions (for definition)
find . -name "cpSweep1D.c" -exec sed -i '' 's/static inline cpSpatialIndexClass \*Klass(){/static inline cpSpatialIndexClass \*Klass(void){/g' {} +
find . -name "cpSpaceHash.c" -exec sed -i '' 's/static inline cpSpatialIndexClass \*Klass(){/static inline cpSpatialIndexClass \*Klass(void){/g' {} +
find . -name "cpBBTree.c" -exec sed -i '' 's/static inline cpSpatialIndexClass \*Klass(){/static inline cpSpatialIndexClass \*Klass(void){/g' {} +

# Fix missing void in cpBody.c function declarations and definitions
find . -name "cpBody.c" -exec sed -i '' 's/cpBodyNewKinematic()/cpBodyNewKinematic(void)/g' {} +
find . -name "cpBody.c" -exec sed -i '' 's/cpBodyNewStatic()/cpBodyNewStatic(void)/g' {} +

# Add newline at the end of necessary header files
find . -name "cpPolyline.h" -exec sh -c 'echo "" >> {}' \;
find . -name "cpMarch.h" -exec sh -c 'echo "" >> {}' \;

BUILD_DIR=".."
current_dir=$(pwd)

# Copy Chipmunk2D header files for macOS and iOS
COMMON_HEADER_FILES=(
    "include/chipmunk/chipmunk.h"
    "include/chipmunk/chipmunk_ffi.h"
    "include/chipmunk/chipmunk_private.h"
    "include/chipmunk/chipmunk_structs.h"
    "include/chipmunk/chipmunk_types.h"
    "include/chipmunk/chipmunk_unsafe.h"
    "include/chipmunk/cpArbiter.h"
    "include/chipmunk/cpBB.h"
    "include/chipmunk/cpBody.h"
    "include/chipmunk/cpConstraint.h"
    "include/chipmunk/cpDampedRotarySpring.h"
    "include/chipmunk/cpDampedSpring.h"
    "include/chipmunk/cpGearJoint.h"
    "include/chipmunk/cpGrooveJoint.h"
    "include/chipmunk/cpHastySpace.h"
    "include/chipmunk/cpMarch.h"
    "include/chipmunk/cpPinJoint.h"
    "include/chipmunk/cpPivotJoint.h"
    "include/chipmunk/cpPolyShape.h"
    "include/chipmunk/cpPolyline.h"
    "include/chipmunk/cpRatchetJoint.h"
    "include/chipmunk/cpRobust.h"
    "include/chipmunk/cpRotaryLimitJoint.h"
    "include/chipmunk/cpShape.h"
    "include/chipmunk/cpSimpleMotor.h"
    "include/chipmunk/cpSlideJoint.h"
    "include/chipmunk/cpSpace.h"
    "include/chipmunk/cpSpatialIndex.h"
    "include/chipmunk/cpTransform.h"
    "include/chipmunk/cpVect.h"
)

# Create directories for macOS and iOS headers
mkdir -p "../Headers-macos"
mkdir -p "../Headers-ios"

# Copy chipmunk.h to the appropriate directories
for hFile in "${COMMON_HEADER_FILES[@]}"; do
  cp "${hFile}" "../Headers-macos"
  cp "${hFile}" "../Headers-ios"
done

# Generate module map for macOS and iOS
MM_OUT_MACOS="module Chipmunk2D {\n    header \"chipmunk.h\"\n    export *\n    link \"Chipmunk2D\"\n"
MM_OUT_IOS="module Chipmunk2D {\n    header \"chipmunk.h\"\n    export *\n    link \"Chipmunk2D\"\n"

COMMON_LINKED_FRAMEWORKS=(
    "CoreGraphics"
    "Foundation"
)

# Add linked frameworks for both macOS and iOS
for fw in "${COMMON_LINKED_FRAMEWORKS[@]}"; do
    MM_OUT_MACOS+="    link framework \"${fw}\"\n"
    MM_OUT_IOS+="    link framework \"${fw}\"\n"
done

# Finalize the module map
MM_OUT_MACOS+="}\n"
MM_OUT_IOS+="}\n"

# Output the module maps
printf "%b" "${MM_OUT_MACOS}" > "../Headers-macos/module.modulemap"
printf "%b" "${MM_OUT_IOS}" > "../Headers-ios/module.modulemap"

echo "Building Chipmunk2D archives..."

# Build Chipmunk2D archives for macOS and iOS
xcodebuild archive \
    -destination "generic/platform=macOS" \
    -quiet ONLY_ACTIVE_ARCH=NO \
    -scheme "Chipmunk-Mac" \
    -project "xcode/Chipmunk7.xcodeproj" \
    -archivePath "${BUILD_DIR}/Chipmunk2D-macosx/" \
    -destination "generic/platform=macOS" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    MACOSX_DEPLOYMENT_TARGET=10.13 \
    ALWAYS_SEARCH_USER_PATHS=YES \
    USE_HEADERMAP=NO

xcodebuild archive \
    -quiet ONLY_ACTIVE_ARCH=NO \
    -scheme "Chipmunk-iOS" \
    -project "xcode/Chipmunk7.xcodeproj" \
    -archivePath "${BUILD_DIR}/Chipmunk2D-iphoneos/" \
    -destination "generic/platform=iOS"  \
    IPHONEOS_DEPLOYMENT_TARGET=12.0 \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    ALWAYS_SEARCH_USER_PATHS=YES \
    USE_HEADERMAP=NO

popd

BUILD_DIR="build"
HEADERS_DIR="build/Headers"

# Clean up previous build artifacts
rm -rdf "${BUILD_DIR}/Chipmunk2D.xcframework"

# Assemble xcframework
xcodebuild -create-xcframework \
    -library "${BUILD_DIR}/Chipmunk2D-macosx.xcarchive/Products/usr/local/lib/libChipmunk-Mac.a" \
    -headers "${HEADERS_DIR}-macos" \
    -library "${BUILD_DIR}/Chipmunk2D-iphoneos.xcarchive/Products/usr/local/lib/libChipmunk-iOS.a" \
    -headers "${HEADERS_DIR}-ios" \
    -output "${BUILD_DIR}/Chipmunk2D.xcframework"

# Move xcframework to the final location
rm -rf Chipmunk2D.xcframework
cp -Ra "${BUILD_DIR}/Chipmunk2D.xcframework" Chipmunk2D.xcframework