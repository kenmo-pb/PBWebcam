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

;-
;- - Procedures

Global IsWebcamOpen.i = #False
Global IsWebcamWindowOpen.i = #False

Procedure UpdateSpecsComboBox()
  ClearGadgetItems(1)
  AddGadgetItem(1, 0, "Default Specs")
  Protected i.i = GetGadgetState(0)
  Protected N.i = CountWebcamFormats(i)
  If (N > 0)
    Protected j.i
    For j = 0 To N-1
      AddGadgetItem(1, j+1, WebcamFormatName(i, j))
    Next j
  EndIf
  SetGadgetState(1, 0)
EndProcedure

Procedure TryOpen()
  If (OpenWebcam(GetGadgetState(0), GetGadgetState(1)-1))
    IsWebcamOpen = #True
    DisableGadget(0, #True)
    DisableGadget(1, #True)
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
      If OpenWindow(1, 0, 0, w, h, "Webcam", #PB_Window_ScreenCentered | #PB_Window_MinimizeGadget)
        AddKeyboardShortcut(1, #PB_Shortcut_Escape, 0)
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
OpenWindow(0, 0, 0, WinW, 3*BoxH + 4*Padding, #PB_Compiler_Filename, #PB_Window_ScreenCentered | #PB_Window_MinimizeGadget | #PB_Window_Invisible)
ComboBoxGadget(0, Padding, Padding, WindowWidth(0) - 2*Padding, BoxH)
For i = 0 To N-1
  AddGadgetItem(0, i, WebcamName(i))
Next i
SetGadgetState(0, 0)

ComboBoxGadget(1, Padding, 1*BoxH + 2*Padding, WinW - 2*Padding, BoxH)
UpdateSpecsComboBox()

ButtonGadget(2, WinW/3, 2*BoxH + 3*Padding, WinW/3, BoxH, "Open Webcam", #PB_Button_Default)

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
  If (Event = #PB_Event_CloseWindow) Or ((Event = #PB_Event_Menu) And (EventMenu() = 0))
    If (EventWindow() = 0)
      ExitFlag = #True
    ElseIf (EventWindow() = 1)
      TryClose()
    EndIf
  ElseIf (Event = #PB_Event_CloseWindow)
    If ((EventGadget() = 0) And (EventType() = #PB_EventType_Change))
      UpdateSpecsComboBox()
    EndIf
  ElseIf ((Event = #PB_Event_Gadget) And (EventGadget() = 2)) Or ((Event = #PB_Event_Menu) And (EventGadget() = 1))
    If (IsWebcamOpen)
      TryClose()
    Else
      TryOpen()
    EndIf
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
