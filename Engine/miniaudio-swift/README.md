# miniaudio-swift
## tl;dr - a SPM package for the cross-platform miniaudio library.

## Description
[miniaudio](https://github.com/mackron/miniaudio) is an audio playback and capture library for C and C++. It's made up of a single source file, has no external dependencies and is released into the public domain. This project wraps this library into a SPM package, which allows it to be used for cross-platform Swift.

## Usage
I've included an executable named `AudioGallery` that will be used to test the miniaudio library. It currently takes the path to a media file an attempts to play it back.

## Notes
**This is currently untested** - As I use this project more, I will add testing data here. Currently, I know that WAV file playback works on macOS.
