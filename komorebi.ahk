#Requires AutoHotkey v2.0.2
#SingleInstance Force

Komorebic(cmd) {
    RunWait(format("komorebic.exe {}", cmd), , "Hide")
}

; Unbind Windows key alone
; #::return

; Bind Windows + M to open the Start menu
; #m::Send {LWin}

#w::Komorebic("close")
#+w::Komorebic("minimize")

; Focus windows
#Left::Komorebic("focus left")
#Down::Komorebic("focus down")
#Up::Komorebic("focus up")
#Right::Komorebic("focus right")

!+[::Komorebic("cycle-focus previous")
!+]::Komorebic("cycle-focus next")

; Move windows
#+Left::Komorebic("move left")
#+Down::Komorebic("move down")
#+Up::Komorebic("move up")
#+Right::Komorebic("move right")

; Stack windows
!Left::Komorebic("stack left")
!Down::Komorebic("stack down")
!Up::Komorebic("stack up")
!Right::Komorebic("stack right")
!;::Komorebic("unstack")
![::Komorebic("cycle-stack previous")
!]::Komorebic("cycle-stack next")

;; Resize
; Enlarge
#!Right::Komorebic("resize-edge right increase")
#!Left::Komorebic("resize-edge left increase")
#!Up::Komorebic("resize-edge up increase")
#!Down::Komorebic("resize-edge down increase")
; Shrink
#+!Right::Komorebic("resize-edge left decrease")
#+!Left::Komorebic("resize-edge right decrease")
#+!Up::Komorebic("resize-edge down decrease")
#+!Down::Komorebic("resize-edge up decrease")

; Manipulate windows
#f::Komorebic("toggle-float")
#m::Komorebic("toggle-monocle")

; Window manager options
!+r::Komorebic("retile")
!p::Komorebic("toggle-pause")

; Layouts
#x::Komorebic("flip-layout horizontal")
!y::Komorebic("flip-layout vertical")

; Workspaces
#1::Komorebic("focus-workspace 0")
#2::Komorebic("focus-workspace 1")
#3::Komorebic("focus-workspace 2")
#4::Komorebic("focus-workspace 3")
#5::Komorebic("focus-workspace 4")
#6::Komorebic("focus-workspace 5")
#7::Komorebic("focus-workspace 6")
#8::Komorebic("focus-workspace 7")

; send windows across workspaces
#+1::Komorebic("send-to-workspace 0")
#+2::Komorebic("send-to-workspace 1")
#+3::Komorebic("send-to-workspace 2")
#+4::Komorebic("send-to-workspace 3")
#+5::Komorebic("send-to-workspace 4")
#+6::Komorebic("send-to-workspace 5")
#+7::Komorebic("send-to-workspace 6")
#+8::Komorebic("send-to-workspace 7")

; reload configuration
#!r::Komorebic("reload-configuration")

; Run Terminal
#Enter::Run "wt.exe"

; Run Firefox
#I::Run "firefox.exe"
#+I::Run "firefox.exe -private-window"