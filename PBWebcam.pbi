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
;- Constants (Private)

#_PBWebcam_FlipX = $01
#_PBWebcam_FlipY = $02

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
  FullyInitializedSDL.i
  ;
  List Webcam._PBWebcamStruct()
  Count.l
  ;
  *Active.SDL_Camera
  ActiveSpec.SDL_CameraSpec
  Driver.s
  ;
  FlipMode.i
  ;
  *CopyOfAcquired.SDL_Surface
  *Converted.SDL_Surface
  Image.i
  DestFormat.i
  YFlipped.i
EndStructure

;-
;- Globals (Private)

Global _PBWebcam._PBWebcamGlobalsStruct

;-
;- Procedures (Public)

Declare.d _CalcWebcamFramerate(*Spec.SDL_CameraSpec)
Declare   _ClearWebcams()
Declare   _ReleaseWebcamSurfaces()

Procedure CloseWebcam()
  If (_PBWebcam\Active)
    SDL_CloseCamera(_PBWebcam\Active)
    _PBWebcam\Active = #Null
    _ReleaseWebcamSurfaces()
    If (_PBWebcam\Image)
      FreeImage(_PBWebcam\Image)
      _PBWebcam\Image = #Null
    EndIf
  EndIf
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
                
                CompilerIf (#True) ; confirmed, it's sometimes needed!
                  _PBWebcam\YFlipped = Bool(DrawingBufferPixelFormat() & #PB_PixelFormat_ReversedY)
                CompilerEndIf
                Select (DrawingBufferPixelFormat() & (~(#PB_PixelFormat_ReversedY | #PB_PixelFormat_NoAlpha)))
                  Case #PB_PixelFormat_24Bits_RGB
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_RGB24
                  Case #PB_PixelFormat_24Bits_BGR
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_BGR24 ; not tested
                  Case #PB_PixelFormat_32Bits_RGB
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_ABGR8888
                  Case #PB_PixelFormat_32Bits_BGR
                    _PBWebcam\DestFormat = #SDL_PIXELFORMAT_ARGB8888
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
  _PBWebcam\FlipMode = (Bool(Horizontal) * #_PBWebcam_FlipX) | (Bool(Vertical) * #_PBWebcam_FlipY)
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
    _ReleaseWebcamSurfaces()
    
    Static *surface.SDL_Surface
    *surface = SDL_AcquireCameraFrame(_PBWebcam\Active, #Null)
    If (*surface)
      
      ; As of SDL 3.2.6, cannot guarantee DuplicateSurface to convert/flip later, because MJPG format fails CreateSurface/CalculateSurfaceSize
      ;_PBWebcam\CopyOfAcquired = SDL_DuplicateSurface(*surface)
      
      ; Convert immediately to RGB format instead...
      _PBWebcam\Converted = SDL_ConvertSurface(*surface, _PBWebcam\DestFormat)
      
      ; "This function should be called as quickly as possible after acquisition"
      SDL_ReleaseCameraFrame(_PBWebcam\Active, *surface)
      
      If (_PBWebcam\Converted)
        
        ; Once in RGB surface format, can use SDL's FlipSurface function
        If (_PBWebcam\FlipMode & #_PBWebcam_FlipX)
          SDL_FlipSurface(_PBWebcam\Converted, #SDL_FLIP_HORIZONTAL)
        EndIf
        If ((_PBWebcam\FlipMode & #_PBWebcam_FlipY) XOr (_PBWebcam\YFlipped))
          SDL_FlipSurface(_PBWebcam\Converted, #SDL_FLIP_VERTICAL)
        EndIf
        
        ; Cannot save this for "just in time" at DrawWebcamImage call, because we'll already be within a Start/StopDrawing block at that point!
        If (StartDrawing(ImageOutput(_PBWebcam\Image)))
          SDL_ConvertPixels(_PBWebcam\Converted\w, _PBWebcam\Converted\h, _PBWebcam\Converted\format, _PBWebcam\Converted\pixels, _PBWebcam\Converted\pitch, _PBWebcam\DestFormat, DrawingBuffer(), DrawingBufferPitch())
          StopDrawing()
          Result = #True
        EndIf
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

Procedure _ReleaseWebcamSurfaces()
  If (_PBWebcam\Converted)
    If (_PBWebcam\Converted <> _PBWebcam\CopyOfAcquired)
      SDL_DestroySurface(_PBWebcam\Converted)
    EndIf
    _PBWebcam\Converted = #Null
  EndIf
  If (_PBWebcam\CopyOfAcquired)
    SDL_DestroySurface(_PBWebcam\CopyOfAcquired)
    _PBWebcam\CopyOfAcquired = #Null
  EndIf
EndProcedure

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
