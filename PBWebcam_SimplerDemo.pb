; +-----------------------+
; | PBWebcam Simpler Demo |
; +-----------------------+
; | 2025-02-19 : Creation (PureBasic 6.12)

;-
#PBWebcam_ExcludeMJPG = #True
XIncludeFile "PBWebcam.pbi"

Macro Error(_Message)
  MessageRequester(#PB_Compiler_Filename, _Message, #PB_MessageRequester_Error)
  FinishWebcams()
  End
EndMacro

N = ExamineWebcams()
If (N <= 0)
  Error("Could not examine webcams, or none found!")
ElseIf (Not OpenWebcamBestFramerate())
  Error("Could not open the default webcam!")
ElseIf (Not WaitWebcamFrame())
  Error("Timed out without receiving any webcam frame!")
EndIf

If (OpenWindow(0, 0, 0, WebcamWidth(), WebcamHeight(), #PB_Compiler_Filename, #PB_Window_ScreenCentered))
  CanvasGadget(0, 0, 0, WebcamWidth(), WebcamHeight())
  AddKeyboardShortcut(0, #PB_Shortcut_Escape, 0)
  AddWindowTimer(0, 0, 1000 / WebcamFramerate())
  
  FlipWebcam(#True, #False)
  
  Quit = #False
  While (Not Quit)
    Event = WaitWindowEvent()
    If ((Event = #PB_Event_CloseWindow) Or (Event = #PB_Event_Menu))
      Quit = #True
    ElseIf (Event = #PB_Event_Timer)
      If (GetWebcamFrame())
        DrawWebcamToCanvasGadget(0)
      EndIf
    EndIf
  Wend
EndIf

FinishWebcams()
;-
