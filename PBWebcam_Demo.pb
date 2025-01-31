; +---------------+
; | PBWebcam Demo |
; +---------------+
; | 2025-01-30 : Creation (PureBasic 6.12)

;-
;- - Examine Webcams

XIncludeFile "PBWebcam.pbi"

N = ExamineWebcams()
If (N <= 0)
  MessageRequester(#PB_Compiler_Filename, "Could not examine webcams, or none found!", #PB_MessageRequester_Error)
  End
EndIf

Global IsWebcamOpen.i = #False
Global IsWebcamWindowOpen.i = #False


;-
;- - Procedures

Procedure UpdateSpecsComboBox()
  PrevPos.i = GetGadgetState(1)
  ClearGadgetItems(1)
  AddGadgetItem(1, 0, "Default Specs")
  AddGadgetItem(1, 1, "Best Framerate")
  AddGadgetItem(1, 2, "Best Resolution")
  AddGadgetItem(1, 3, "Closest to 640x480")
  Protected i.i = GetGadgetState(0)
  Protected N.i = CountWebcamFormats(i)
  If (N > 0)
    Protected j.i
    For j = 0 To N-1
      AddGadgetItem(1, j+4, WebcamFormatName(i, j))
    Next j
  EndIf
  If ((PrevPos >= 0) And (PrevPos <= 3))
    SetGadgetState(1, PrevPos)
  Else
    SetGadgetState(1, 1)
  EndIf
EndProcedure

Procedure TryOpen()
  Protected Opened.i
  If (GetGadgetState(1) = 0)
    Opened = OpenWebcam(GetGadgetState(0))
  ElseIf (GetGadgetState(1) = 1)
    Opened = OpenWebcamBestFramerate(0, 0, 0, GetGadgetState(0))
  ElseIf (GetGadgetState(1) = 2)
    Opened = OpenWebcamBestResolution(0, 0, 0, GetGadgetState(0))
  ElseIf (GetGadgetState(1) = 3)
    Opened = OpenWebcamClosestResolution(640, 480, 0.0, GetGadgetState(0))
  Else
    Opened = OpenWebcam(GetGadgetState(0), GetGadgetState(1)-4)
  EndIf
  If (Opened)
    IsWebcamOpen = #True
    DisableGadget(0, #True)
    DisableGadget(1, #True)
    DisableGadget(3, #True)
    DisableGadget(4, #True)
    FlipWebcam(GetGadgetState(3), GetGadgetState(4))
    SetGadgetText(2, "Close Webcam")
    AddWindowTimer(0, 0, Int(1000 / WebcamFramerate()))
  Else
    MessageRequester(#PB_Compiler_Filename, "Could not open the specified webcam!", #PB_MessageRequester_Error)
  EndIf
EndProcedure

Procedure TryClose()
  If (IsWebcamOpen)
    RemoveWindowTimer(0, 0)
    CloseWebcam()
    If (IsWebcamWindowOpen)
      CloseWindow(1)
      IsWebcamWindowOpen = #False
    EndIf
    IsWebcamOpen = #False
    DisableGadget(0, #False)
    DisableGadget(1, #False)
    DisableGadget(3, #False)
    DisableGadget(4, #False)
    SetGadgetText(2, "Open Webcam")
    SetActiveWindow(0)
    SetActiveGadget(1)
  EndIf
EndProcedure

Procedure Redraw()
  w = WebcamWidth()
  h = WebcamHeight()
  If (w > 0) And (h > 0)
    If (Not IsWebcamWindowOpen)
      If OpenWindow(1, 0, 0, w, h, "Webcam  -  Ctrl+S to Save Image", #PB_Window_ScreenCentered | #PB_Window_MinimizeGadget, WindowID(0))
        AddKeyboardShortcut(1, #PB_Shortcut_Escape, 0)
        AddKeyboardShortcut(1, #PB_Shortcut_S | #PB_Shortcut_Control, 2)
        If CanvasGadget(10, 0, 0, w, h)
          IsWebcamWindowOpen = #True
        EndIf
      EndIf
    EndIf
    If (IsWebcamWindowOpen)
      If StartDrawing(CanvasOutput(10))
        ;Box(0, 0, OutputWidth(), OutputHeight(), $444444)
        DrawWebcamImage(0, 0)
        
        If (#True) ; just demonstrate that we can custom draw on top of webcame frame!
          DrawingMode(#PB_2DDrawing_Outlined)
          Circle(WindowMouseX(1), WindowMouseY(1), 30, #Red)
        EndIf
        
        StopDrawing()
      EndIf
    EndIf
  EndIf
EndProcedure


;-
;- - Window Setup

WinW = 640
BoxH = 30
Padding = 10
OpenWindow(0, 0, 0, WinW, 4*BoxH + 5*Padding, #PB_Compiler_Filename, #PB_Window_ScreenCentered | #PB_Window_MinimizeGadget | #PB_Window_Invisible)
ComboBoxGadget(0, Padding, Padding, WindowWidth(0) - 2*Padding, BoxH)
For i = 0 To N-1
  AddGadgetItem(0, i, "[" + Str(i) + "] " + WebcamName(i))
Next i
SetGadgetState(0, 0)

ComboBoxGadget(1, Padding, 1*BoxH + 2*Padding, WinW - 2*Padding, BoxH)
UpdateSpecsComboBox()

CheckBoxGadget(3, WinW*1/6, 2*BoxH + 3*Padding, WinW/3, BoxH, "Mirror horizontally")
  SetGadgetState(3, #True)
CheckBoxGadget(4, WinW*4/6, 2*BoxH + 3*Padding, WinW/3, BoxH, "Flip vertically")

ButtonGadget(2, WinW/3, 3*BoxH + 4*Padding, WinW/3, BoxH, "Open Webcam", #PB_Button_Default)

AddKeyboardShortcut(0, #PB_Shortcut_Escape, 0)
AddKeyboardShortcut(0, #PB_Shortcut_Return, 1)
HideWindow(0, #False)
SetActiveWindow(0)
SetActiveGadget(1)



;-
;- - Main Loop

IsWebcamOpen.i = #False

Repeat
  Event = WaitWindowEvent(DelayMS)
  
  ; Close webcam window, or exit program
  If (Event = #PB_Event_CloseWindow) Or ((Event = #PB_Event_Menu) And (EventMenu() = 0))
    If (EventWindow() = 0)
      ExitFlag = #True
    ElseIf (EventWindow() = 1)
      TryClose()
    EndIf
    
  ; Update specs combo box if selected webcam changed
  ElseIf ((Event = #PB_Event_Gadget) And (EventGadget() = 0) And (EventType() = #PB_EventType_Change))
    UpdateSpecsComboBox()
    
  ; Open or Close selected webcam!
  ElseIf ((Event = #PB_Event_Gadget) And (EventGadget() = 2)) Or ((Event = #PB_Event_Menu) And (EventMenu() = 1))
    If (IsWebcamOpen)
      TryClose()
    Else
      TryOpen()
    EndIf
  
  ; Save (and open) webcam image
  ElseIf ((Event = #PB_Event_Menu) And (EventMenu() = 2))
    If (IsWebcamOpen)
      TempFile.s = GetTemporaryDirectory() + GetFilePart(#PB_Compiler_Filename, #PB_FileSystem_NoExtension) + FormatDate("_%yyyy%mm%dd_%hh%ii%ss", Date()) + ".bmp"
      If (SaveWebcamImage(TempFile))
        CompilerIf (#PB_Compiler_OS = #PB_OS_Windows)
          RunProgram(TempFile)
        CompilerElse
          RunProgram("open", #DQUOTE$ + TempFile + #DQUOTE$, "")
        CompilerEndIf
      Else
        MessageRequester(#PB_Compiler_Filename, "Failed to save webcame image!", #PB_MessageRequester_Warning)
      EndIf
    EndIf
  
  ; Draw new webcam frame at a regular interval  
  ElseIf (Event = #PB_Event_Timer)
    If (GetWebcamFrame())
      Redraw()
    EndIf
  EndIf
  
Until (ExitFlag)

;-
;- - Exit

FinishWebcams()

;-
