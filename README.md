
# PBWebcam

Webcam/camera access in [PureBasic](https://www.purebasic.com/) via [SDL3](https://libsdl.org/)

## Requirements

1. Get the latest `PBWebcam.pbi` from this repo
2. Get the latest `SDL3.pbi` from my [SDLx repo](https://github.com/kenmo-pb/SDLx)
3. Get the latest `libSDL3` binary for your operating system

You can find the [latest SDL3 release on GitHub](https://github.com/libsdl-org/SDL/releases).  
On Windows, you need `SDL3.dll` but pay attention to **x86** or **x64** to match your PureBasic compiler.  
On Linux, you need `libSDL3.so`, but you may prefer to build it from SDL source using [these simple cmake instructions](https://github.com/libsdl-org/SDL/blob/main/docs/README-cmake.md).

You may also encounter SDL3 definitions conflicting with existing SDL1 or SDL2 definitions!  
One easy fix is to temporarily move `sdl.res` out of your `purebasic/residents/` folder.

## How to Use PBWebcam

Let's call them "Webcams" because PureBasic already has a "Camera" library for the 3D engine.

- `ExamineWebcams()`, `CountWebcams()`, `WebcamName()` to inspect available webcams
- `CountWebcamFormats()` and `WebcamFormatName()` to inspect their supported specs
- `OpenWebcam()` to open a webcam by index, or `OpenWebcamBestFramerate()`, `OpenWebcamBestResolution()`, `OpenWebcamClosestResolution()`, `WebcamIndexFromName()` to simplify code
- `WebcamWidth()`, `WebcamHeight()`, `WebcamFramerate()` to inspect the currently open webcam
- `FlipWebcam()` to mirror it horizontally (common) or flip it vertically
- `GetWebcamFrame()` to prepare a new frame
- `DrawWebcamImage()` to draw the frame to a 2DDrawing output like any other PB image
- `SaveWebcamImage()` to save the frame to a file like any other PB image
- `CloseWebcam()` and `FinishWebcams()` when you're done!

## Try It!

Download or `git clone` this repo, and run `PBWebcam_Demo.pb`!  
It should enumerate your available webcams and their formats, give you a live view (mirroring and flipping optional), and let you save images.

(You still need to get `SDL3.pbi` and `libSDL3` separately, see **Requirements** above.)
