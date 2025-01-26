; -------------------------------
;          配置初始化
; -------------------------------
#KeyHistory 0
SetBatchLines -1
Process, Priority,, High

configFile := "AutoFire.ini"

; 读取或创建配置文件
IfNotExist, %configFile%
{
    IniWrite, PgDn, %configFile%, Settings, Hotkey
    IniWrite, 600, %configFile%, Settings, FireRate
    IniWrite, 5, %configFile%, Settings, RecoilForce
    IniWrite, 0, %configFile%, Settings, BreathHold
}
IniRead, HotkeyCC, %configFile%, Settings, Hotkey, PgDn
IniRead, defaultFireRate, %configFile%, Settings, FireRate, 600
IniRead, defaultRecoil, %configFile%, Settings, RecoilForce, 5
IniRead, breathHold, %configFile%, Settings, BreathHold, 0

; -------------------------------
;           GUI 界面
; -------------------------------
Gui, Font, s10
Gui, Add, Text, xm ym+3 w80, 热键：
Gui, Add, Hotkey, x+5 yp-3 vHotkeyC w200, % HotkeyCC
Hotkey, %HotkeyCC%, CheckBox

Gui, Add, Text, xm y+15 w80, 射速(RPM)：
Gui, Add, Edit, x+5 yp-3 vFireRate w200 Number, %defaultFireRate%

Gui, Add, Text, xm y+15 w80, 压枪力度：
Gui, Add, Edit, x+5 yp-3 vRecoilForce w200 Number, %defaultRecoil%

Gui, Add, CheckBox, xm y+15 vBreathHold Checked%breathHold%, 启用屏息
Gui, Add, CheckBox, xm y+20 vED gCheckBox Checked, 启用辅助
Gui, Add, Button, xm y+15 w100 gButtonApplyChanges, 应用设置
Gui, Show, w300 h250, 智能压枪助手
return

; -------------------------------
;        新增屏息功能
; -------------------------------
~RButton::
    if (BreathHold = 1)
    {
        Send {Shift Down}
        KeyWait, RButton
        Send {Shift Up}
    }
    else
    {
        KeyWait, RButton
    }
return

; -------------------------------
;        核心逻辑（全自动模式）
; -------------------------------
#If ED
~RButton & LButton::
    ; 发送真实按下事件
    SendInput {Blind}{LButton Down}
    
    ; 获取配置参数
    Gui, Submit, NoHide
    FireInterval := 60000 / FireRate
    baseRecoil := RecoilForce
    lastFireTime := A_TickCount - FireInterval
    
    ; 主控制循环
    While (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED)
    {
        ; 按射速间隔执行压枪
        if (A_TickCount - lastFireTime >= FireInterval)
        {
            ; 动态压枪（带随机偏移）
            Random, randRecoil, -1, 1
            DllCall("mouse_event", "UInt", 0x01, "UInt", 0, "UInt", baseRecoil + randRecoil, "UInt", 0, "UPtr", 0)
            
            ; 更新计时器
            lastFireTime := A_TickCount
        }
        
        ; 高频检测退出条件
        Sleep 1
    }
    
    ; 释放左键
    SendInput {Blind}{LButton Up}
return
#If

; -------------------------------
;        功能控制模块
; -------------------------------
CheckBox:
    Gui, Submit, NoHide
    SaveSettings()
return

ButtonApplyChanges:
    Gui, Submit, NoHide
    
    ; 输入验证
    FireRate := (FireRate < 100) ? 100 : FireRate
    RecoilForce := (RecoilForce < 1) ? 1 : RecoilForce
    
    ; 更新热键
    if (HotkeyC != HotkeyCC) {
        Hotkey, %HotkeyCC%, CheckBox, Off
        Hotkey, % (HotkeyCC := HotkeyC), CheckBox, On
    }
    
    ; 保存设置并刷新
    SaveSettings()
    GuiControl,, FireRate, %FireRate%
    GuiControl,, RecoilForce, %RecoilForce%
return

SaveSettings()
{
    global
    IniWrite, %FireRate%, %configFile%, Settings, FireRate
    IniWrite, %RecoilForce%, %configFile%, Settings, RecoilForce
    IniWrite, %HotkeyCC%, %configFile%, Settings, Hotkey
    IniWrite, %BreathHold%, %configFile%, Settings, BreathHold
}

GuiClose:
ExitApp