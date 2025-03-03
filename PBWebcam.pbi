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

CompilerIf (Not Defined(PB_PixelFormat_NoAlpha, #PB_Constant))
  #PB_PixelFormat_NoAlpha = 0
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

Structure _PBWebcamGlobalsStruct
  List Webcam._PBWebcamStruct()
  Count.l
  ;
  *Active.SDL_Camera
  ActiveSpec.SDL_CameraSpec
  ;
  FlipMode.i
  Image.i
  FullyInitializedSDL.i
  BPP.i
  YFlipped.i
  DestFormat.i
  Driver.s
EndStructure

;-
;- Globals (Private)

Global _PBWebcam._PBWebcamGlobalsStruct

;-
;- Procedures (Public)

Declare.d _CalcWebcamFramerate(*Spec.SDL_CameraSpec)
Declare   _ClearWebcams()

Procedure CloseWebcam()
  If (_PBWebcam\Active)
    SDL_CloseCamera(_PBWebcam\Active)
    _PBWebcam\Active = #Null
    If (_PBWebcam\Image)
      FreeImage(_PBWebcam\Image)
      _PBWebcam\Image = #Null
    EndIf
  EndIf
  _PBWebcam\BPP = 0
  _PBWebcam\YFlipped = #False
  _PBWebcam\DestFormat = #SDL_PIXELFORMAT_UNKNOWN
EndProcedure

Procedure.i OpenWebcam(WebcamIndex.i = #PB_Default, FormatIndex.i = #PB_Default)
  Protected Result.i = #False
  
  CloseWebcam()
  If (WebcamIndex = #PB_Default)
    WebcamIndex = 0
  EndIf
  If ((WebcamIndex >= 0) And (WebcamIndex < _PBWebcam\Count))
    SelectElement(_PBWebcam\Webcam(), WebcamIndex)
    Protected *TargetSpec.SDL_CameraSpec = #Null
    If (FormatIndex = #PB_Default) Or ((FormatIndex >= 0) And (FormatIndex < ListSize(_PBWebcam\Webcam()\Spec())))
      If (FormatIndex <> #PB_Default)
        SelectElement(_PBWebcam\Webcam()\Spec(), FormatIndex)
        *TargetSpec = _PBWebcam\Webcam()\Spec()\format
      EndIf
      _PBWebcam\Active = SDL_OpenCamera(_PBWebcam\Webcam()\instance_id, *TargetSpec)
      If (_PBWebcam\Active)
        If (SDL_GetCameraFormat(_PBWebcam\Active, @_PBWebcam\ActiveSpec))
          If ((_PBWebcam\ActiveSpec\width > 0) And (_PBWebcam\ActiveSpec\width > 0))
            _PBWebcam\Image = CreateImage(#PB_Any, _PBWebcam\ActiveSpec\width, _PBWebcam\ActiveSpec\height, 32)
            If (_PBWebcam\Image)
              If (StartDrawing(ImageOutput(_PBWebcam\Image)))
                
                CompilerIf (#False) ; never needed?
                  _PBWebcamYFlipped = Bool(DrawingBufferPixelFormat() & #PB_PixelFormat_ReversedY)
                CompilerEndIf
                Select (DrawingBufferPixelFormat() & (~(#PB_PixelFormat_ReversedY | #PB_PixelFormat_NoAlpha)))
                  Case #PB_PixelFormat_24Bits_RGB
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_RGB24
                    _PBWebcam\BPP = 24
                  Case #PB_PixelFormat_24Bits_BGR
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_BGR24 ; not tested
                    _PBWebcam\BPP = 24
                  Case #PB_PixelFormat_32Bits_RGB
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_ABGR8888
                    _PBWebcam\BPP = 32
                  Case #PB_PixelFormat_32Bits_BGR
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_ARGB8888
                    _PBWebcam\BPP = 32
                EndSelect
                
                StopDrawing()
                Result = #True
              Else
                CloseWebcam()
              EndIf
            Else
              CloseWebcam()
            EndIf
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
  ForEach (_PBWebcam\Webcam())
    If ((WebcamIndex < 0) Or (WebcamIndex = ListIndex(_PBWebcam\Webcam())))
      ForEach (_PBWebcam\Webcam()\Spec())
        Protected Valid.i = #False
        If (_PBWebcam\Webcam()\Spec()\format\width >= MinWidth)
          If (_PBWebcam\Webcam()\Spec()\format\height >= MinHeight)
            If (_PBWebcam\Webcam()\Spec()\Framerate >= MinFramerate)
              Valid = #True
            EndIf
          EndIf
        EndIf
        If (Valid)
          If (_PBWebcam\Webcam()\Spec()\Framerate > BestFramerate)
            Valid = #True
          ElseIf ((_PBWebcam\Webcam()\Spec()\Framerate = BestFramerate) And (_PBWebcam\Webcam()\Spec()\Megapixels > BestMegapixels))
            Valid = #True
          Else
            Valid = #False
          EndIf
          If (Valid)
            FoundWebcam = ListIndex(_PBWebcam\Webcam())
            FoundFormat = ListIndex(_PBWebcam\Webcam()\Spec())
            BestFramerate = _PBWebcam\Webcam()\Spec()\Framerate
            BestMegapixels = _PBWebcam\Webcam()\Spec()\Megapixels
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
  ForEach (_PBWebcam\Webcam())
    If ((WebcamIndex < 0) Or (WebcamIndex = ListIndex(_PBWebcam\Webcam())))
      ForEach (_PBWebcam\Webcam()\Spec())
        Protected Valid.i = #False
        If (_PBWebcam\Webcam()\Spec()\format\width >= MinWidth)
          If (_PBWebcam\Webcam()\Spec()\format\height >= MinHeight)
            If (_PBWebcam\Webcam()\Spec()\Framerate >= MinFramerate)
              Valid = #True
            EndIf
          EndIf
        EndIf
        If (Valid)
          If (_PBWebcam\Webcam()\Spec()\Megapixels > BestMegapixels)
            Valid = #True
          ElseIf ((_PBWebcam\Webcam()\Spec()\Megapixels = BestMegapixels) And (_PBWebcam\Webcam()\Spec()\Framerate > BestFramerate))
            Valid = #True
          Else
            Valid = #False
          EndIf
          If (Valid)
            FoundWebcam = ListIndex(_PBWebcam\Webcam())
            FoundFormat = ListIndex(_PBWebcam\Webcam()\Spec())
            BestFramerate = _PBWebcam\Webcam()\Spec()\Framerate
            BestMegapixels = _PBWebcam\Webcam()\Spec()\Megapixels
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
  ForEach (_PBWebcam\Webcam())
    If ((WebcamIndex < 0) Or (WebcamIndex = ListIndex(_PBWebcam\Webcam())))
      ForEach (_PBWebcam\Webcam()\Spec())
        Protected Valid.i = #False
        If (_PBWebcam\Webcam()\Spec()\Framerate >= MinFramerate)
          Valid = #True
        EndIf
        If (Valid)
          Protected Difference.i = Abs(_PBWebcam\Webcam()\Spec()\format\width - TargetWidth) + Abs(_PBWebcam\Webcam()\Spec()\format\height - TargetHeight)
          If ((LeastDifference = -1) Or (Difference < LeastDifference))
            Valid = #True
          ElseIf ((Difference = LeastDifference) And (_PBWebcam\Webcam()\Spec()\Framerate > BestFramerate))
            Valid = #True
          Else
            Valid = #False
          EndIf
          If (Valid)
            FoundWebcam = ListIndex(_PBWebcam\Webcam())
            FoundFormat = ListIndex(_PBWebcam\Webcam()\Spec())
            BestFramerate = _PBWebcam\Webcam()\Spec()\Framerate
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
  ForEach (_PBWebcam\Webcam())
    If (ExactMatch)
      If (_PBWebcam\Webcam()\Name = Name)
        Result = ListIndex(_PBWebcam\Webcam())
        Break
      EndIf
    Else
      If (FindString(_PBWebcam\Webcam()\Name, Name, 1, #PB_String_NoCase))
        Result = ListIndex(_PBWebcam\Webcam())
        Break
      EndIf
    EndIf
  Next
  ProcedureReturn (Result)
EndProcedure

Procedure.i DrawWebcamImage(x.i, y.i, Width.i = #PB_Default, Height.i = #PB_Default)
  Protected Result.i = #False
  If (_PBWebcam\Image)
    If ((Width > 0) And (Height > 0)) ; if either is specified, both must be specified (for now)
      DrawImage(ImageID(_PBWebcam\Image), x, y, Width, Height)
      Result = #True
    Else
      DrawImage(ImageID(_PBWebcam\Image), x, y)
      Result = #True
    EndIf
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure.i DrawWebcamToCanvasGadget(Gadget.i)
  Protected Result.i = #False
  If (_PBWebcam\Image)
    If (StartDrawing(CanvasOutput(Gadget)))
      DrawImage(ImageID(_PBWebcam\Image), 0, 0)
      StopDrawing()
      Result = #True
    EndIf
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure.i SaveWebcamImage(FileName$, Format.i = #PB_ImagePlugin_BMP, Flags.i = #PB_Default, Depth.i = #PB_Default)
  Protected Result.i = #False
  If (_PBWebcam\Image)
    If (Flags = #PB_Default)
      If ((Format = #PB_ImagePlugin_JPEG) Or (Format = #PB_ImagePlugin_JPEG2000))
        Flags = 7
      Else
        Flags = 0
      EndIf
    EndIf
    If (Depth = #PB_Default)
      Depth = ImageDepth(_PBWebcam\Image)
    EndIf
    Result = Bool(SaveImage(_PBWebcam\Image, FileName$, Format, Flags, Depth))
  EndIf
  ProcedureReturn (Result)
EndProcedure

Procedure FlipWebcam(Horizontal.i, Vertical.i)
  _PBWebcam\FlipMode = (Bool(Horizontal) * $01) | (Bool(Vertical) * $02)
EndProcedure

Procedure.i WebcamWidth()
  If (_PBWebcam\Active)
    ProcedureReturn (_PBWebcam\ActiveSpec\width)
  EndIf
  ProcedureReturn (0)
EndProcedure

Procedure.i WebcamHeight()
  If (_PBWebcam\Active)
    ProcedureReturn (_PBWebcam\ActiveSpec\height)
  EndIf
  ProcedureReturn (0)
EndProcedure

Procedure.d WebcamFramerate()
  If (_PBWebcam\Active)
    ProcedureReturn (_CalcWebcamFramerate(@_PBWebcam\ActiveSpec))
  EndIf
  ProcedureReturn (0.0)
EndProcedure

Procedure.s WebcamDriver()
  ProcedureReturn (_PBWebcam\Driver)
EndProcedure

Procedure.i GetWebcamFrame()
  Protected Result.i = #False
  
  CompilerIf (#True)
    Static Event.SDL_Event
    If (_PBWebcam\FullyInitializedSDL)
      ; We fully initialized SDL, so we should process the Event loop...
      While (SDL_PollEvent(@Event))
        ;Delay(0)
      Wend
    EndIf
  CompilerEndIf
  
  If (_PBWebcam\Active)
    Static *surface.SDL_Surface
    *surface = SDL_AcquireCameraFrame(_PBWebcam\Active, #Null)
    If (*surface)
      If (StartDrawing(ImageOutput(_PBWebcam\Image)))
        
        If (SDL_ConvertPixels(*surface\w, *surface\h, *surface\format, *surface\pixels, *surface\pitch, _PBWebcam\DestFormat, DrawingBuffer(), DrawingBufferPitch()))
          
          ; PB SOFTWARE IMPLEMENTATION of horizontal/vertical image flip!
          ;   Original plan was to use SDL3's SDL_FlipSurface() before SDL_ConvertPixels(),
          ;   but it was failing for "operation not supported",
          ;   I believe because webcam was providing YUY2 pixel data ("FOURCC" formats not flippable, SDL_BITSPERPIXEL reported as 0)
          ;
          CompilerIf (#True)
            
            ; "This function should be called as quickly as possible after acquisition, as SDL keeps a small FIFO queue of surfaces for video frames"
            SDL_ReleaseCameraFrame(_PBWebcam\Active, *surface)
            *surface = #Null
            
            ; TODO: On Windows, consider StretchBlt_() for faster hardware-accelerated flipping ?
            
            Static i.i, j.i
            Static *LA.SDLx_LongArray
            Static *LA2.SDLx_LongArray
            If (_PBWebcam\FlipMode Or _PBWebcam\YFlipped)
              If ((_PBWebcam\FlipMode & $02) XOr _PBWebcam\YFlipped)
                If (_PBWebcam\BPP > 0)
                  Static RowSize.i
                  Static *TempBuffer
                  RowSize = _PBWebcam\ActiveSpec\width * _PBWebcam\BPP / 8
                  *TempBuffer = AllocateMemory(RowSize, #PB_Memory_NoClear)
                  If (*TempBuffer)
                    *LA  = DrawingBuffer()
                    *LA2 = DrawingBuffer() + (_PBWebcam\ActiveSpec\height - 1) * DrawingBufferPitch()
                    For j = 0 To _PBWebcam\ActiveSpec\height / 2
                      CopyMemory(*LA, *TempBuffer, RowSize)
                      CopyMemory(*LA2, *LA, RowSize)
                      CopyMemory(*TempBuffer, *LA2, RowSize)
                      *LA + DrawingBufferPitch()
                      *LA2 - DrawingBufferPitch()
                    Next j
                    FreeMemory(*TempBuffer)
                  EndIf
                EndIf
              EndIf
              If (_PBWebcam\FlipMode & $01)
                If (_PBWebcam\BPP = 32)
                  *LA = DrawingBuffer()
                  For j = 0 To _PBWebcam\ActiveSpec\height - 1
                    For i = 0 To _PBWebcam\ActiveSpec\width / 2
                      Swap *LA\l[i], *LA\l[_PBWebcam\ActiveSpec\width - 1 - i]
                    Next i
                    *LA + DrawingBufferPitch()
                  Next j
                EndIf
              EndIf
            EndIf
          CompilerEndIf
          
          Result = #True
        EndIf
        StopDrawing()
      EndIf
      If (*surface)
        SDL_ReleaseCameraFrame(_PBWebcam\Active, *surface)
      EndIf
    EndIf
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

Procedure.i WaitWebcamFrame(TimeoutMS.i = 15 * 1000)
  Protected Result.i = #False
  
  If (_PBWebcam\Active)
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
  If ((index >= 0) And (index < _PBWebcam\Count))
    SelectElement(_PBWebcam\Webcam(), index)
    ProcedureReturn (_PBWebcam\Webcam()\Name)
  EndIf
  ProcedureReturn ("")
EndProcedure

Procedure.s WebcamFormatName(WebcamIndex.i, FormatIndex.i)
  If ((WebcamIndex >= 0) And (WebcamIndex < _PBWebcam\Count))
    SelectElement(_PBWebcam\Webcam(), WebcamIndex)
    If ((FormatIndex >= 0) And (FormatIndex < ListSize(_PBWebcam\Webcam()\Spec())))
      SelectElement(_PBWebcam\Webcam()\Spec(), FormatIndex)
      ProcedureReturn (_PBWebcam\Webcam()\Spec()\Name)
    EndIf
  EndIf
  ProcedureReturn ("")
EndProcedure

Procedure.i CountWebcamFormats(index.i)
  If ((index >= 0) And (index < _PBWebcam\Count))
    SelectElement(_PBWebcam\Webcam(), index)
    ProcedureReturn (ListSize(_PBWebcam\Webcam()\Spec()))
  EndIf
  ProcedureReturn (0)
EndProcedure

Procedure.i CountWebcams()
  ProcedureReturn (_PBWebcam\Count)
EndProcedure

Procedure FinishWebcams()
  _ClearWebcams()
  
  If (_PBWebcam\FullyInitializedSDL)
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
    
    Protected *camera_ids.SDLx_LongArray = SDL_GetCameras(@_PBWebcam\Count)
    _PBWebcam\Driver = SDLx_GetCurrentCameraDriverString()
    If (*camera_ids)
      If (_PBWebcam\Count > 0)
        Protected i.i
        For i = 0 To _PBWebcam\Count - 1
          AddElement(_PBWebcam\Webcam())
          _PBWebcam\Webcam()\instance_id = *camera_ids\l[i]
          _PBWebcam\Webcam()\Name = SDLx_GetCameraNameString(_PBWebcam\Webcam()\instance_id)
          If (_PBWebcam\Webcam()\Name = "")
            _PBWebcam\Webcam()\Name = "Unknown Camera"
          EndIf
          
          Protected *spec.SDL_CameraSpec
          Protected MultipleFormats.i = #False
          Protected FirstFormat.SDL_PixelFormat
          
          _PBWebcam\Webcam()\NumFormats = 0
          _PBWebcam\Webcam()\formatsPtr = SDL_GetCameraSupportedFormats(_PBWebcam\Webcam()\instance_id, @_PBWebcam\Webcam()\NumFormats)
          If (_PBWebcam\Webcam()\formatsPtr)
            If (_PBWebcam\Webcam()\NumFormats > 0)
              Protected j.i
              For j = 0 To _PBWebcam\Webcam()\NumFormats - 1
                *spec = _PBWebcam\Webcam()\formatsPtr\ptr[j]
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
                  AddElement(_PBWebcam\Webcam()\Spec())
                  _PBWebcam\Webcam()\Spec()\format = *spec
                  _PBWebcam\Webcam()\Spec()\Framerate = _CalcWebcamFramerate(_PBWebcam\Webcam()\Spec()\format)
                  _PBWebcam\Webcam()\Spec()\Pixels = _PBWebcam\Webcam()\Spec()\format\width * _PBWebcam\Webcam()\Spec()\format\height
                  _PBWebcam\Webcam()\Spec()\Megapixels = _PBWebcam\Webcam()\Spec()\Pixels / 1000000.0
                  _PBWebcam\Webcam()\Spec()\MegapixelsPerSecond = _PBWebcam\Webcam()\Spec()\Megapixels * _PBWebcam\Webcam()\Spec()\Framerate
                  _PBWebcam\Webcam()\Spec()\AspectRatio = 1.0 * _PBWebcam\Webcam()\Spec()\format\width / _PBWebcam\Webcam()\Spec()\format\height
                  _PBWebcam\Webcam()\Spec()\Name = Str(_PBWebcam\Webcam()\Spec()\format\width) + "x" + Str(_PBWebcam\Webcam()\Spec()\format\height) + " @ " + StrD(_PBWebcam\Webcam()\Spec()\Framerate, 1) + " fps"
                  ;
                  If (ListSize(_PBWebcam\Webcam()\Spec()) = 1) ; first valid spec
                    FirstFormat = *spec\format
                  Else
                    If (*spec\format <> FirstFormat)
                      MultipleFormats = #True
                    EndIf
                  EndIf
                EndIf
              Next j
              _PBWebcam\Webcam()\NumFormats = ListSize(_PBWebcam\Webcam()\Spec())
              
              If (MultipleFormats Or #PBWebcam_AlwaysShowPixelFormat)
                ForEach (_PBWebcam\Webcam()\Spec())
                  Protected FormatName.s = SDLx_GetPixelFormatNameString(_PBWebcam\Webcam()\Spec()\format\format)
                  j = Len("SDL_PIXELFORMAT_")
                  If (Left(FormatName, j) = "SDL_PIXELFORMAT_")
                    FormatName = Mid(FormatName, j + 1)
                  EndIf
                  _PBWebcam\Webcam()\Spec()\Name + " (" + FormatName + ")"
                Next
              EndIf
            Else
              SDL_free(_PBWebcam\Webcam()\formatsPtr)
              _PBWebcam\Webcam()\formatsPtr = #Null
            EndIf
          EndIf
          
          CompilerIf (#True) ; Remove Webcams with no valid formats
            If (_PBWebcam\Webcam()\NumFormats = 0)
              DeleteElement(_PBWebcam\Webcam())
              _PBWebcam\Count - 1
            EndIf
          CompilerEndIf
          
        Next i
        Result = _PBWebcam\Count
      EndIf
      SDL_free(*camera_ids)
    EndIf
    
  EndIf
  
  If (Result And FirstSDLInit)
    _PBWebcam\FullyInitializedSDL = #True
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
  ForEach (_PBWebcam\Webcam())
    ForEach (_PBWebcam\Webcam()\Spec())
      _PBWebcam\Webcam()\Spec()\Name = ""
    Next
    ClearList(_PBWebcam\Webcam()\Spec())
    If (_PBWebcam\Webcam()\formatsPtr)
      SDL_free(_PBWebcam\Webcam()\formatsPtr)
      _PBWebcam\Webcam()\formatsPtr = #Null
    EndIf
  Next
  ClearList(_PBWebcam\Webcam())
  _PBWebcam\Count = 0
  
  _PBWebcam\Driver = ""
EndProcedure


CompilerIf (#PB_Compiler_IsMainFile)
  MessageRequester(#PB_Compiler_Filename, "This IncludeFile is not intended to be run by itself." + #LF$ + #LF$ + "See the Demo program, or include this in your own project!", #PB_MessageRequester_Warning)
CompilerEndIf

CompilerEndIf
;-
