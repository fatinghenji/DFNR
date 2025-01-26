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
    IniWrite, 0, %configFile%, Settings, SemiAutoMode ; 新增半自动模式开关
}
IniRead, HotkeyCC, %configFile%, Settings, Hotkey, PgDn
IniRead, defaultFireRate, %configFile%, Settings, FireRate, 600
IniRead, defaultRecoil, %configFile%, Settings, RecoilForce, 5
IniRead, breathHold, %configFile%, Settings, BreathHold, 0
IniRead, semiAutoMode, %configFile%, Settings, SemiAutoMode, 0 ; 读取半自动模式状态

; -------------------------------
;          GUI 界面
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
Gui, Add, CheckBox, xm y+15 vSemiAutoMode Checked%semiAutoMode%, 半自动模式
Gui, Add, CheckBox, xm y+20 vED gCheckBox Checked, 启用辅助
Gui, Add, Button, xm y+15 w100 gButtonApplyChanges, 应用设置
Gui, Show, w300 h280, 智能压枪助手
return

; -------------------------------
;        屏息功能模块
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
;        双模式核心逻辑（修复版）
; -------------------------------
#If ED
~RButton & LButton::
    ; 公共参数初始化
    Gui, Submit, NoHide
    FireInterval := 60000 / FireRate
    baseRecoil := RecoilForce
    lastFireTime := A_TickCount - FireInterval
    
    if (SemiAutoMode)
    {
        ; 半自动模式：增加左键状态检测
        While (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED) ; 修改条件
        {
            if (A_TickCount - lastFireTime >= FireInterval)
            {
                ; 智能点击算法
                SendInput {Blind}{LButton Down}
                Sleep % (FireInterval < 50) ? 10 : 20
                SendInput {Blind}{LButton Up}
                
                ; 稳定压枪算法
                Random, randRecoil, -0.5, 0.5
                DllCall("mouse_event", "UInt", 0x01, "UInt", 0, "UInt", baseRecoil*0.9 + randRecoil, "UInt", 0, "UPtr", 0)
                
                lastFireTime := A_TickCount
            }
            Sleep 1
        }
        ; 确保松开时状态重置
        SendInput {Blind}{LButton Up}
    }
    else
    {
        ; 全自动模式保持不变
        SendInput {Blind}{LButton Down}
        While (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED)
        {
            if (A_TickCount - lastFireTime >= FireInterval)
            {
                Random, randRecoil, -1, 1
                DllCall("mouse_event", "UInt", 0x01, "UInt", 0, "UInt", baseRecoil + randRecoil, "UInt", 0, "UPtr", 0)
                lastFireTime := A_TickCount
            }
            Sleep 1
        }
        SendInput {Blind}{LButton Up}
    }
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
    
    ; 参数验证
    FireRate := (FireRate < 100) ? 100 : (FireRate > 2000) ? 2000 : FireRate
    RecoilForce := (RecoilForce < 1) ? 1 : (RecoilForce > 15) ? 15 : RecoilForce
    
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
    IniWrite, %SemiAutoMode%, %configFile%, Settings, SemiAutoMode ; 保存模式状态
}

GuiClose:
ExitApp
