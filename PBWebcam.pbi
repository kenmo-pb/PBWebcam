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

#SDLx_IncludeHelperProcedures = #True
CompilerIf ((Not Defined(SDL_OpenCamera, #PB_Procedure)) And (Not Defined(Proto_SDL_OpenCamera, #PB_Prototype)))
  XIncludeFile "SDL3.pbi"
CompilerEndIf

Structure _PBWebcamSpecStruct
  *format.SDL_CameraSpec
  Name.s
  
  Framerate.d
  Pixels.i
  Megapixels.d
  MegapixelsPerSecond.d
EndStructure

Structure _PBWebcamStruct
  instance_id.SDL_CameraID
  Name.s
  
  NumFormats.l
  *formatsPtr
  
  List Spec._PBWebcamSpecStruct()
EndStructure

Global NewList _PBWebcam._PBWebcamStruct()

Global _PBWebcamCount.l

Global *_PBWebcamActive.SDL_Camera = #Null
Global _PBWebcamActiveSpec.SDL_CameraSpec
Global _PBWebcamImage.i

;-
;- Procedures (Public)

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
            _PBWebcamImage = CreateImage(#PB_Any, _PBWebcamActiveSpec\width, _PBWebcamActiveSpec\height, 24)
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
    ProcedureReturn (1.0 * _PBWebcamActiveSpec\framerate_numerator / _PBWebcamActiveSpec\framerate_denominator)
  EndIf
  ProcedureReturn (0.0)
EndProcedure

Procedure.i GetWebcamFrame()
  Protected Result.i = #False
  
  If (*_PBWebcamActive)
    Protected *surface.SDL_Surface = SDL_AcquireCameraFrame(*_PBWebcamActive, #Null)
    If (*surface)
      If (StartDrawing(ImageOutput(_PBWebcamImage)))
        
        Protected src_pitch.l = *surface\w * 2 ; review this!!!
        Protected dst_pitch.SDL_PixelFormat
        Protected dst_format.SDL_PixelFormat
        Select (DrawingBufferPixelFormat() & (~(#PB_PixelFormat_ReversedY | 0))) ; add #PB_PixelFormat_NoAlpha
          Case #PB_PixelFormat_24Bits_RGB
            dst_format = #SDL_PIXELFORMAT_RGB24
          Case #PB_PixelFormat_24Bits_BGR
            dst_format = #SDL_PIXELFORMAT_BGR24 ; not tested
          Case #PB_PixelFormat_32Bits_RGB
            dst_format = #SDL_PIXELFORMAT_ABGR8888
          Case #PB_PixelFormat_32Bits_BGR
            dst_format = #SDL_PIXELFORMAT_ARGB8888
        EndSelect
        SDL_ConvertPixels(*surface\w, *surface\h, *surface\format, *surface\pixels, src_pitch, dst_format, DrawingBuffer(), DrawingBufferPitch())
        
        Result = #True
        StopDrawing()
      EndIf
      SDL_ReleaseCameraFrame(*_PBWebcamActive, *surface)
    EndIf
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
  CloseWebcam()
  ForEach (_PBWebcam())
    ForEach (_PBWebcam()\Spec())
      ; ...
    Next
    If (_PBWebcam()\formatsPtr)
      SDL_free(_PBWebcam()\formatsPtr)
      _PBWebcam()\formatsPtr = #Null
    EndIf
  Next
  ClearList(_PBWebcam())
  _PBWebcamCount = 0
  SDL_Quit()
EndProcedure

Procedure.i ExamineWebcams()
  Protected Result.i = #False
  
  FinishWebcams()
  
  If (SDL_Init(#SDL_INIT_CAMERA))
    
    Protected *camera_ids = SDL_GetCameras(@_PBWebcamCount)
    If (*camera_ids)
      If (_PBWebcamCount > 0)
        Protected i.i
        For i = 0 To _PBWebcamCount - 1
          AddElement(_PBWebcam())
          _PBWebcam()\instance_id = PeekI(*camera_ids + i * SizeOf(INTEGER))
          _PBWebcam()\Name = SDLx_GetCameraNameString(_PBWebcam()\instance_id)
          
          _PBWebcam()\NumFormats = 0
          _PBWebcam()\formatsPtr = SDL_GetCameraSupportedFormats(_PBWebcam()\instance_id, @_PBWebcam()\NumFormats)
          If (_PBWebcam()\formatsPtr)
            If (_PBWebcam()\NumFormats > 0)
              Protected j.i
              For j = 0 To _PBWebcam()\NumFormats - 1
                AddElement(_PBWebcam()\Spec())
                _PBWebcam()\Spec()\format = PeekI(_PBWebcam()\formatsPtr + j * SizeOf(INTEGER))
                _PBWebcam()\Spec()\Framerate = 1.0 * _PBWebcam()\Spec()\format\framerate_numerator / _PBWebcam()\Spec()\format\framerate_denominator
                _PBWebcam()\Spec()\Pixels = _PBWebcam()\Spec()\format\width * _PBWebcam()\Spec()\format\height
                _PBWebcam()\Spec()\Megapixels = _PBWebcam()\Spec()\Pixels / 1000000.0
                _PBWebcam()\Spec()\MegapixelsPerSecond = _PBWebcam()\Spec()\Megapixels * _PBWebcam()\Spec()\Framerate
                _PBWebcam()\Spec()\Name = Str(_PBWebcam()\Spec()\format\width) + "x" + Str(_PBWebcam()\Spec()\format\height) + " @ " + StrD(_PBWebcam()\Spec()\Framerate, 1) + " fps"
              Next j
            Else
              SDL_free(_PBWebcam()\formatsPtr)
              _PBWebcam()\formatsPtr = #Null
            EndIf
          EndIf
          
        Next i
        Result = _PBWebcamCount
      EndIf
      SDL_free(*camera_ids)
    EndIf
    
  EndIf
  
  ProcedureReturn (Result)
EndProcedure

CompilerEndIf
;-
