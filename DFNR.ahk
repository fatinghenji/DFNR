; -------------------------------
;          配置初始化
; -------------------------------
#KeyHistory 0
SetBatchLines -1
Process, Priority,, High

configFile := A_ScriptDir "\AutoFire.ini"  ; 使用脚本目录路径

; 检查是否以管理员身份运行
if not A_IsAdmin {
    MsgBox, 需要以管理员身份运行以启用完整功能。
    ExitApp
}

; 读取或创建配置文件
IfNotExist, %configFile%
{
    CreateDefaultConfig()
}
LoadConfigFromFile()

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

Gui, Add, Text, xm y+15 w80, 已存配置：
Gui, Add, DropDownList, x+5 yp-3 vConfigList gLoadSelectedConfig w120
Gui, Add, Button, x+5 yp w70 gRefreshConfigs, 刷新列表

Gui, Add, Text, xm y+15 w80, 配置名称：
Gui, Add, Edit, x+5 yp-3 vConfigName w120
Gui, Add, Button, x+5 yp w70 gSaveConfig, 保存配置
Gui, Add, Button, x+5 yp w70 gDeleteConfig, 删除配置

Gui, Add, Button, xm y+15 w100 gButtonApplyChanges, 应用设置
Gui, Add, Button, x+5 yp w100 gRestoreDefaults, 恢复默认设置 ; 新增恢复默认按钮
Gui, Show, w300 h400, 智能压枪助手

; 初始化时刷新配置列表
GoSub, RefreshConfigs
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
    FireInterval := CalcFireInterval(FireRate)
    baseRecoil := RecoilForce
    lastFireTime := A_TickCount - FireInterval
    
    if (SemiAutoMode)
    {
        ; 半自动模式：增加左键状态检测
        While (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED)
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

CreateDefaultConfig() {
    global
    IniWrite, PgDn, %configFile%, Settings, Hotkey
    IniWrite, 600, %configFile%, Settings, FireRate
    IniWrite, 5, %configFile%, Settings, RecoilForce
    IniWrite, 0, %configFile%, Settings, BreathHold
    IniWrite, 0, %configFile%, Settings, SemiAutoMode ; 新增半自动模式开关
}

LoadConfigFromFile() {
    global
    IniRead, HotkeyCC, %configFile%, Settings, Hotkey, PgDn
    IniRead, defaultFireRate, %configFile%, Settings, FireRate, 600
    IniRead, defaultRecoil, %configFile%, Settings, RecoilForce, 5
    IniRead, breathHold, %configFile%, Settings, BreathHold, 0
    IniRead, semiAutoMode, %configFile%, Settings, SemiAutoMode, 0 ; 读取半自动模式状态
}

; 配置保存函数
SaveConfig:
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 请输入配置名称！
        return
    }
    
    IniWrite, %FireRate%, %configFile%, Config_%ConfigName%, FireRate
    IniWrite, %RecoilForce%, %configFile%, Config_%ConfigName%, RecoilForce
    IniWrite, %HotkeyCC%, %configFile%, Config_%ConfigName%, Hotkey
    IniWrite, %BreathHold%, %configFile%, Config_%ConfigName%, BreathHold
    IniWrite, %SemiAutoMode%, %configFile%, Config_%ConfigName%, SemiAutoMode
    
    GoSub, RefreshConfigs
    MsgBox, 配置 %ConfigName% 已保存！
return

; 配置加载函数
LoadConfig:
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 请输入配置名称！
        return
    }
    
    IniRead, tempFireRate, %configFile%, Config_%ConfigName%, FireRate, %defaultFireRate%
    IniRead, tempRecoil, %configFile%, Config_%ConfigName%, RecoilForce, %defaultRecoil%
    IniRead, tempHotkey, %configFile%, Config_%ConfigName%, Hotkey, %HotkeyCC%
    IniRead, tempBreathHold, %configFile%, Config_%ConfigName%, BreathHold, 0
    IniRead, tempSemiAutoMode, %configFile%, Config_%ConfigName%, SemiAutoMode, 0
    
    if (tempFireRate = "ERROR") {
        MsgBox, 未找到配置 %ConfigName%！
        return
    }
    
    GuiControl,, FireRate, %tempFireRate%
    GuiControl,, RecoilForce, %tempRecoil%
    GuiControl,, HotkeyC, %tempHotkey%
    GuiControl,, BreathHold, %tempBreathHold%
    GuiControl,, SemiAutoMode, %tempSemiAutoMode%
    
    ; 更新热键
    if (tempHotkey != HotkeyCC) {
        Hotkey, %HotkeyCC%, CheckBox, Off
        Hotkey, % (HotkeyCC := tempHotkey), CheckBox, On
    }
    
    ; 加载成功后更新下拉列表的选择
    GuiControl, Choose, ConfigList, %ConfigName%
    
    MsgBox, 配置 %ConfigName% 已加载！
return

; 刷新配置列表函数
RefreshConfigs:
    configs := ""
    IniRead, sections, %configFile%
    Loop, Parse, sections, `n
    {
        if (InStr(A_LoopField, "Config_") = 1) {
            configName := SubStr(A_LoopField, 8)
            configs .= configName . "|"
        }
    }
    GuiControl,, ConfigList, |%configs%
return

; 从下拉列表加载配置函数
LoadSelectedConfig:
    Gui, Submit, NoHide
    if (ConfigList != "") {
        GuiControl,, ConfigName, %ConfigList%
        GoSub, LoadConfig
    }
return

; 删除配置函数
DeleteConfig:
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 请输入要删除的配置名称！
        return
    }
    
    MsgBox, 4, 确认删除, 是否确定删除配置 %ConfigName%？
    IfMsgBox Yes 
    {
        IniDelete, %configFile%, Config_%ConfigName%
        GuiControl,, ConfigName, 
        GoSub, RefreshConfigs
        MsgBox, 配置 %ConfigName% 已删除！
    }
return

; 恢复默认设置按钮
RestoreDefaults:
    CreateDefaultConfig()
    LoadConfigFromFile()
    MsgBox, 默认设置已恢复！
return

GuiClose:
ExitApp

; -------------------------------
;          函数部分
; -------------------------------
CalcFireInterval(rpm) {
    return 60000 / rpm
}
