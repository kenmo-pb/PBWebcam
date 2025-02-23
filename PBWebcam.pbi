; +--------------+
; | PBWebcam.pbi |
; +--------------+
; | 2025-01-30 : Creation (PureBasic 6.12)

;-
CompilerIf (Not Defined(_PBWebcam_Included, #PB_Constant))
#_PBWebcam_Included = #True

CompilerIf (#PB_Compiler_IsMainFile)
  EnableExplicit
CompilerEndIf

;- Compile Switches

CompilerIf (Not Defined(PBWebcam_AlwaysShowPixelFormat, #PB_Constant))
  #PBWebcam_AlwaysShowPixelFormat = #False
CompilerEndIf

CompilerIf (Not Defined(PBWebcam_ExcludeMJPG, #PB_Constant))
  #PBWebcam_ExcludeMJPG = #False
CompilerEndIf


#SDLx_ExcludeCameraSupport    = #False
#SDLx_IncludeHelperProcedures = #True
CompilerIf ((Not Defined(SDL_OpenCamera, #PB_Procedure)) And (Not Defined(Proto_SDL_OpenCamera, #PB_Prototype)))
  XIncludeFile "SDL3.pbi"
CompilerEndIf

;-
;- Structures (Private)

Structure _PBWebcamSpecStruct
  *format.SDL_CameraSpec
  Name.s
  
  Framerate.d
  Pixels.i
  Megapixels.d
  MegapixelsPerSecond.d
  AspectRatio.d
EndStructure

Structure _PBWebcamStruct
  instance_id.SDL_CameraID
  Name.s
  
  NumFormats.l
  *formatsPtr.SDLx_PointerArray
  
  List Spec._PBWebcamSpecStruct()
EndStructure


;-
;- Globals (Private)

Global NewList _PBWebcam._PBWebcamStruct()

Global _PBWebcamCount.l

Global *_PBWebcamActive.SDL_Camera = #Null
Global _PBWebcamActiveSpec.SDL_CameraSpec
Global _PBWebcamFlipMode.i = 0
Global _PBWebcamImage.i
Global _PBWebcamFullyInitializedSDL.i = #False

;-
;- Procedures (Public)

Declare.d _CalcWebcamFramerate(*Spec.SDL_CameraSpec)
Declare   _ClearWebcams()

Procedure CloseWebcam()
  If (*_PBWebcamActive)
    SDL_CloseCamera(*_PBWebcamActive)
    *_PBWebcamActive = #Null
    If (_PBWebcamImage)
      FreeImage(_PBWebcamImage)
      _PBWebcamImage = #Null
    EndIf
  EndIf
EndProcedure

Procedure.i OpenWebcam(WebcamIndex.i = #PB_Default, FormatIndex.i = #PB_Default)
  Protected Result.i = #False
  
  CloseWebcam()
  If (WebcamIndex = #PB_Default)
    WebcamIndex = 0
  EndIf
  If ((WebcamIndex >= 0) And (WebcamIndex < _PBWebcamCount))
    SelectElement(_PBWebcam(), WebcamIndex)
    Protected *TargetSpec.SDL_CameraSpec = #Null
    If (FormatIndex = #PB_Default) Or ((FormatIndex >= 0) And (FormatIndex < ListSize(_PBWebcam()\Spec())))
      If (FormatIndex <> #PB_Default)
        SelectElement(_PBWebcam()\Spec(), FormatIndex)
        *TargetSpec = _PBWebcam()\Spec()\format
      EndIf
      *_PBWebcamActive = SDL_OpenCamera(_PBWebcam()\instance_id, *TargetSpec)
      If (*_PBWebcamActive)
        If (SDL_GetCameraFormat(*_PBWebcamActive, @_PBWebcamActiveSpec))
          If ((_PBWebcamActiveSpec\width > 0) And (_PBWebcamActiveSpec\width > 0))
            _PBWebcamImage = CreateImage(#PB_Any, _PBWebcamActiveSpec\width, _PBWebcamActiveSpec\height, 32)
            Result = #True
          Else
            CloseWebcam()
          EndIf
        Else
          CloseWebcam()
        EndIf
      EndIf
    EndIf
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i OpenWebcamBestFramerate(MinWidth.i = 0, MinHeight.i = 0, MinFramerate.d = 0.0, WebcamIndex.i = #PB_Default)
  Protected Result.i = #False
  
  Protected FoundWebcam.i = -1
  Protected FoundFormat.i = -1
  Protected BestFramerate.d = 0.0
  Protected BestMegapixels.d = 0.0
  ForEach (_PBWebcam())
    If ((WebcamIndex < 0) Or (WebcamIndex = ListIndex(_PBWebcam())))
      ForEach (_PBWebcam()\Spec())
        Protected Valid.i = #False
        If (_PBWebcam()\Spec()\format\width >= MinWidth)
          If (_PBWebcam()\Spec()\format\height >= MinHeight)
            If (_PBWebcam()\Spec()\Framerate >= MinFramerate)
              Valid = #True
            EndIf
          EndIf
        EndIf
        If (Valid)
          If (_PBWebcam()\Spec()\Framerate > BestFramerate)
            Valid = #True
          ElseIf ((_PBWebcam()\Spec()\Framerate = BestFramerate) And (_PBWebcam()\Spec()\Megapixels > BestMegapixels))
            Valid = #True
          Else
            Valid = #False
          EndIf
          If (Valid)
            FoundWebcam = ListIndex(_PBWebcam())
            FoundFormat = ListIndex(_PBWebcam()\Spec())
            BestFramerate = _PBWebcam()\Spec()\Framerate
            BestMegapixels = _PBWebcam()\Spec()\Megapixels
          EndIf
        EndIf
      Next
    EndIf
  Next
  
  If ((FoundWebcam >= 0) And (FoundFormat >= 0))
    Result = OpenWebcam(FoundWebcam, FoundFormat)
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i OpenWebcamBestResolution(MinWidth.i = 0, MinHeight.i = 0, MinFramerate.d = 0.0, WebcamIndex.i = #PB_Default)
  Protected Result.i = #False
  
  Protected FoundWebcam.i = -1
  Protected FoundFormat.i = -1
  Protected BestFramerate.d = 0.0
  Protected BestMegapixels.d = 0.0
  ForEach (_PBWebcam())
    If ((WebcamIndex < 0) Or (WebcamIndex = ListIndex(_PBWebcam())))
      ForEach (_PBWebcam()\Spec())
        Protected Valid.i = #False
        If (_PBWebcam()\Spec()\format\width >= MinWidth)
          If (_PBWebcam()\Spec()\format\height >= MinHeight)
            If (_PBWebcam()\Spec()\Framerate >= MinFramerate)
              Valid = #True
            EndIf
          EndIf
        EndIf
        If (Valid)
          If (_PBWebcam()\Spec()\Megapixels > BestMegapixels)
            Valid = #True
          ElseIf ((_PBWebcam()\Spec()\Megapixels = BestMegapixels) And (_PBWebcam()\Spec()\Framerate > BestFramerate))
            Valid = #True
          Else
            Valid = #False
          EndIf
          If (Valid)
            FoundWebcam = ListIndex(_PBWebcam())
            FoundFormat = ListIndex(_PBWebcam()\Spec())
            BestFramerate = _PBWebcam()\Spec()\Framerate
            BestMegapixels = _PBWebcam()\Spec()\Megapixels
          EndIf
        EndIf
      Next
    EndIf
  Next
  
  If ((FoundWebcam >= 0) And (FoundFormat >= 0))
    Result = OpenWebcam(FoundWebcam, FoundFormat)
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i OpenWebcamClosestResolution(TargetWidth.i, TargetHeight.i, MinFramerate.d = 0.0, WebcamIndex.i = #PB_Default)
  Protected Result.i = #False
  
  Protected FoundWebcam.i = -1
  Protected FoundFormat.i = -1
  Protected BestFramerate.d = 0.0
  Protected LeastDifference.i = -1
  ForEach (_PBWebcam())
    If ((WebcamIndex < 0) Or (WebcamIndex = ListIndex(_PBWebcam())))
      ForEach (_PBWebcam()\Spec())
        Protected Valid.i = #False
        If (_PBWebcam()\Spec()\Framerate >= MinFramerate)
          Valid = #True
        EndIf
        If (Valid)
          Protected Difference.i = Abs(_PBWebcam()\Spec()\format\width - TargetWidth) + Abs(_PBWebcam()\Spec()\format\height - TargetHeight)
          If ((LeastDifference = -1) Or (Difference < LeastDifference))
            Valid = #True
          ElseIf ((Difference = LeastDifference) And (_PBWebcam()\Spec()\Framerate > BestFramerate))
            Valid = #True
          Else
            Valid = #False
          EndIf
          If (Valid)
            FoundWebcam = ListIndex(_PBWebcam())
            FoundFormat = ListIndex(_PBWebcam()\Spec())
            BestFramerate = _PBWebcam()\Spec()\Framerate
            LeastDifference = Difference
          EndIf
        EndIf
      Next
    EndIf
  Next
  
  If ((FoundWebcam >= 0) And (FoundFormat >= 0))
    Result = OpenWebcam(FoundWebcam, FoundFormat)
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i WebcamIndexFromName(Name.s, ExactMatch.i = #False)
  Protected Result.i = -1
  ForEach (_PBWebcam())
    If (ExactMatch)
      If (_PBWebcam()\Name = Name)
        Result = ListIndex(_PBWebcam())
        Break
      EndIf
    Else
      If (FindString(_PBWebcam()\Name, Name, 1, #PB_String_NoCase))
        Result = ListIndex(_PBWebcam())
        Break
      EndIf
    EndIf
  Next
  ProcedureReturn (Result)
EndProcedure

Procedure.i DrawWebcamImage(x.i, y.i, Width.i = #PB_Default, Height.i = #PB_Default)
  Protected Result.i = #False
  If (_PBWebcamImage)
    If ((Width > 0) And (Height > 0)) ; if either is specified, both must be specified (for now)
      DrawImage(ImageID(_PBWebcamImage), x, y, Width, Height)
      Result = #True
    Else
      DrawImage(ImageID(_PBWebcamImage), x, y)
      Result = #True
    EndIf
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure.i DrawWebcamToCanvasGadget(Gadget.i)
  Protected Result.i = #False
  If (_PBWebcamImage)
    If (StartDrawing(CanvasOutput(Gadget)))
      DrawWebcamImage(0, 0)
      StopDrawing()
      Result = #True
    EndIf
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure.i SaveWebcamImage(FileName$, Format.i = #PB_ImagePlugin_BMP, Flags.i = #PB_Default, Depth.i = #PB_Default)
  Protected Result.i = #False
  If (_PBWebcamImage)
    If (Flags = #PB_Default)
      If ((Format = #PB_ImagePlugin_JPEG) Or (Format = #PB_ImagePlugin_JPEG2000))
        Flags = 7
      Else
        Flags = 0
      EndIf
    EndIf
    If (Depth = #PB_Default)
      Depth = ImageDepth(_PBWebcamImage)
    EndIf
    Result = Bool(SaveImage(_PBWebcamImage, FileName$, Format, Flags, Depth))
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure FlipWebcam(Horizontal.i, Vertical.i)
  _PBWebcamFlipMode = (Bool(Horizontal) * $01) | (Bool(Vertical) * $02)
EndProcedure

Procedure.i WebcamWidth()
  If (*_PBWebcamActive)
    ProcedureReturn (_PBWebcamActiveSpec\width)
  EndIf
  ProcedureReturn (0)
EndProcedure

Procedure.i WebcamHeight()
  If (*_PBWebcamActive)
    ProcedureReturn (_PBWebcamActiveSpec\height)
  EndIf
  ProcedureReturn (0)
EndProcedure

Procedure.d WebcamFramerate()
  If (*_PBWebcamActive)
    ProcedureReturn (_CalcWebcamFramerate(@_PBWebcamActiveSpec))
  EndIf
  ProcedureReturn (0.0)
EndProcedure

Procedure.i GetWebcamFrame()
  Protected Result.i = #False
  
  If (*_PBWebcamActive)
    Protected *surface.SDL_Surface = SDL_AcquireCameraFrame(*_PBWebcamActive, #Null)
    If (*surface)
      If (StartDrawing(ImageOutput(_PBWebcamImage)))
        
        Protected dst_format.SDL_PixelFormat
        Protected YFlipped.i = Bool(DrawingBufferPixelFormat() & #PB_PixelFormat_ReversedY)
        Protected BPP.i = 0
        Select (DrawingBufferPixelFormat() & (~(#PB_PixelFormat_ReversedY | 0))) ; add #PB_PixelFormat_NoAlpha
          Case #PB_PixelFormat_24Bits_RGB
            dst_format = #SDL_PIXELFORMAT_RGB24
            BPP = 24
          Case #PB_PixelFormat_24Bits_BGR
            dst_format = #SDL_PIXELFORMAT_BGR24 ; not tested
            BPP = 24
          Case #PB_PixelFormat_32Bits_RGB
            dst_format = #SDL_PIXELFORMAT_ABGR8888
            BPP = 32
          Case #PB_PixelFormat_32Bits_BGR
            dst_format = #SDL_PIXELFORMAT_ARGB8888
            BPP = 32
        EndSelect
        
        SDL_ConvertPixels(*surface\w, *surface\h, *surface\format, *surface\pixels, *surface\pitch, dst_format, DrawingBuffer(), DrawingBufferPitch())
        
        ; PB SOFTWARE IMPLEMENTATION of horizontal/vertical image flip!
        ;   Original plan was to use SDL3's SDL_FlipSurface() before SDL_ConvertPixels(),
        ;   but it was failing for "operation not supported",
        ;   I believe because webcam was providing YUY2 pixel data ("FOURCC" formats not flippable, SDL_BITSPERPIXEL reported as 0)
        ;
        CompilerIf (#True)
          Protected i.i, j.i
          Protected *LA.SDLx_LongArray
          Protected *LA2.SDLx_LongArray
          If (_PBWebcamFlipMode Or YFlipped)
            If ((_PBWebcamFlipMode & $02) XOr YFlipped)
              If (BPP > 0)
                Protected RowSize.i = *surface\w * BPP / 8
                Protected *TempBuffer = AllocateMemory(RowSize, #PB_Memory_NoClear)
                *LA = DrawingBuffer()
                *LA2 = DrawingBuffer() + (*surface\h - 1) * DrawingBufferPitch()
                For j = 0 To *surface\h / 2
                  CopyMemory(*LA, *TempBuffer, RowSize)
                  CopyMemory(*LA2, *LA, RowSize)
                  CopyMemory(*TempBuffer, *LA2, RowSize)
                  *LA + DrawingBufferPitch()
                  *LA2 - DrawingBufferPitch()
                Next j
              EndIf
            EndIf
            If (_PBWebcamFlipMode & $01)
              If (BPP = 32)
                *LA = DrawingBuffer()
                For j = 0 To *surface\h - 1
                  For i = 0 To *surface\w / 2
                    Swap *LA\l[i], *LA\l[*surface\w - 1 - i]
                  Next i
                  *LA + DrawingBufferPitch()
                Next j
              EndIf
            EndIf
          EndIf
        CompilerEndIf
        
        Result = #True
        StopDrawing()
      EndIf
      SDL_ReleaseCameraFrame(*_PBWebcamActive, *surface)
    EndIf
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i WaitWebcamFrame(TimeoutMS.i = 15 * 1000)
  Protected Result.i = #False
  
  If (*_PBWebcamActive)
    Protected StartTime.i = ElapsedMilliseconds()
    Repeat
      If (GetWebcamFrame())
        Result = #True
        Break
      Else
        Delay(10)
      EndIf
    Until (ElapsedMilliseconds() - StartTime > TimeoutMS)
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.s WebcamName(index.i)
  If ((index >= 0) And (index < _PBWebcamCount))
    SelectElement(_PBWebcam(), index)
    ProcedureReturn (_PBWebcam()\Name)
  EndIf
  ProcedureReturn ("")
EndProcedure

Procedure.s WebcamFormatName(WebcamIndex.i, FormatIndex.i)
  If ((WebcamIndex >= 0) And (WebcamIndex < _PBWebcamCount))
    SelectElement(_PBWebcam(), WebcamIndex)
    If ((FormatIndex >= 0) And (FormatIndex < ListSize(_PBWebcam()\Spec())))
      SelectElement(_PBWebcam()\Spec(), FormatIndex)
      ProcedureReturn (_PBWebcam()\Spec()\Name)
    EndIf
  EndIf
  ProcedureReturn ("")
EndProcedure

Procedure.i CountWebcamFormats(index.i)
  If ((index >= 0) And (index < _PBWebcamCount))
    SelectElement(_PBWebcam(), index)
    ProcedureReturn (ListSize(_PBWebcam()\Spec()))
  EndIf
  ProcedureReturn (0)
EndProcedure

Procedure.i CountWebcams()
  ProcedureReturn (_PBWebcamCount)
EndProcedure

Procedure FinishWebcams()
  _ClearWebcams()
  
  If (_PBWebcamFullyInitializedSDL)
    SDL_Quit()
  Else
    If (SDLx_LibraryLoaded())
      SDL_QuitSubsystem(#SDL_INIT_VIDEO)
    EndIf
  EndIf
EndProcedure

Procedure.i ExamineWebcams()
  Protected Result.i = #False
  
  _ClearWebcams()
  
  Protected FirstSDLInit.i = #False
  If (SDLx_LibraryLoaded())
    If (SDL_WasInit(0) = 0) ; No SDL subsystems have been initialized yet, so this file will "own" the main SDL_Init and later call SDL_Quit
      FirstSDLInit = #True
    EndIf
  Else
    FirstSDLInit = #True ; SDL Library has not even been loaded yet, so this file will "own" the main SDL_Init and later call SDL_Quit
  EndIf
  
  If (SDL_Init(#SDL_INIT_CAMERA))
    
    Protected *camera_ids.SDLx_LongArray = SDL_GetCameras(@_PBWebcamCount)
    If (*camera_ids)
      If (_PBWebcamCount > 0)
        Protected i.i
        For i = 0 To _PBWebcamCount - 1
          AddElement(_PBWebcam())
          _PBWebcam()\instance_id = *camera_ids\l[i]
          _PBWebcam()\Name = SDLx_GetCameraNameString(_PBWebcam()\instance_id)
          If (_PBWebcam()\Name = "")
            _PBWebcam()\Name = "Unknown Camera"
          EndIf
          
          Protected *spec.SDL_CameraSpec
          Protected MultipleFormats.i = #False
          Protected FirstFormat.SDL_PixelFormat
          
          _PBWebcam()\NumFormats = 0
          _PBWebcam()\formatsPtr = SDL_GetCameraSupportedFormats(_PBWebcam()\instance_id, @_PBWebcam()\NumFormats)
          If (_PBWebcam()\formatsPtr)
            If (_PBWebcam()\NumFormats > 0)
              Protected j.i
              For j = 0 To _PBWebcam()\NumFormats - 1
                *spec = _PBWebcam()\formatsPtr\ptr[j]
                Protected Valid.i = #False
                If (*spec)
                  Select (*spec\format) ; an SDL_PixelFormat
                    Case #SDL_PIXELFORMAT_UNKNOWN
                      Valid = #False
                    Case #SDL_PIXELFORMAT_MJPG
                      Valid = Bool(Not #PBWebcam_ExcludeMJPG)
                    Default
                      Valid = #True
                  EndSelect
                EndIf
                ;
                If (Valid)
                  AddElement(_PBWebcam()\Spec())
                  _PBWebcam()\Spec()\format = *spec
                  _PBWebcam()\Spec()\Framerate = _CalcWebcamFramerate(_PBWebcam()\Spec()\format)
                  _PBWebcam()\Spec()\Pixels = _PBWebcam()\Spec()\format\width * _PBWebcam()\Spec()\format\height
                  _PBWebcam()\Spec()\Megapixels = _PBWebcam()\Spec()\Pixels / 1000000.0
                  _PBWebcam()\Spec()\MegapixelsPerSecond = _PBWebcam()\Spec()\Megapixels * _PBWebcam()\Spec()\Framerate
                  _PBWebcam()\Spec()\AspectRatio = 1.0 * _PBWebcam()\Spec()\format\width / _PBWebcam()\Spec()\format\height
                  _PBWebcam()\Spec()\Name = Str(_PBWebcam()\Spec()\format\width) + "x" + Str(_PBWebcam()\Spec()\format\height) + " @ " + StrD(_PBWebcam()\Spec()\Framerate, 1) + " fps"
                  ;
                  If (ListSize(_PBWebcam()\Spec()) = 1) ; first valid spec
                    FirstFormat = *spec\format
                  Else
                    If (*spec\format <> FirstFormat)
                      MultipleFormats = #True
                    EndIf
                  EndIf
                EndIf
              Next j
              _PBWebcam()\NumFormats = ListSize(_PBWebcam()\Spec())
              
              If (MultipleFormats Or #PBWebcam_AlwaysShowPixelFormat)
                ForEach (_PBWebcam()\Spec())
                  Protected FormatName.s = SDLx_GetPixelFormatNameString(_PBWebcam()\Spec()\format\format)
                  j = Len("SDL_PIXELFORMAT_")
                  If (Left(FormatName, j) = "SDL_PIXELFORMAT_")
                    FormatName = Mid(FormatName, j + 1)
                  EndIf
                  _PBWebcam()\Spec()\Name + " (" + FormatName + ")"
                Next
              EndIf
            Else
              SDL_free(_PBWebcam()\formatsPtr)
              _PBWebcam()\formatsPtr = #Null
            EndIf
          EndIf
          
          CompilerIf (#True) ; Remove Webcams with no valid formats
            If (_PBWebcam()\NumFormats = 0)
              DeleteElement(_PBWebcam())
              _PBWebcamCount - 1
            EndIf
          CompilerEndIf
          
        Next i
        Result = _PBWebcamCount
      EndIf
      SDL_free(*camera_ids)
    EndIf
    
  EndIf
  
  If (Result And FirstSDLInit)
    _PBWebcamFullyInitializedSDL = #True
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

;-
;- Procedures (Private)

Procedure.d _CalcWebcamFramerate(*Spec.SDL_CameraSpec)
  Protected Result.d = 1.0
  If (*Spec)
    If ((*Spec\framerate_numerator > 0) And (*Spec\framerate_denominator > 0))
      Result = 1.0 * *Spec\framerate_numerator / *Spec\framerate_denominator
    EndIf
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure _ClearWebcams()
  CloseWebcam()
  ForEach (_PBWebcam())
    ForEach (_PBWebcam()\Spec())
      _PBWebcam()\Spec()\Name = ""
    Next
    ClearList(_PBWebcam()\Spec())
    If (_PBWebcam()\formatsPtr)
      SDL_free(_PBWebcam()\formatsPtr)
      _PBWebcam()\formatsPtr = #Null
    EndIf
  Next
  ClearList(_PBWebcam())
  _PBWebcamCount = 0
EndProcedure


CompilerIf (#PB_Compiler_IsMainFile)
  MessageRequester(#PB_Compiler_Filename, "This IncludeFile is not intended to be run by itself." + #LF$ + #LF$ + "See the Demo program, or include this in your own project!", #PB_MessageRequester_Warning)
CompilerEndIf

CompilerEndIf
;-
