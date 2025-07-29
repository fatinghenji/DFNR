; -------------------------------
;          智能压枪助手 v2.0
; -------------------------------
#NoEnv
#KeyHistory 0
#SingleInstance Force
SetBatchLines -1
Process, Priority,, High
SendMode Input

; 全局变量
global configFile := A_ScriptDir "\AutoFire.ini"
global lastFireTime := 0
global isFiring := false
global recoilActive := false
global recoilThread := false
global autoFireActive := false
global assistantEnabled := false  ; 热键控制的启用状态

; -------------------------------
;          权限检查与初始化
; -------------------------------
if not A_IsAdmin {
    try {
        Run *RunAs "%A_ScriptFullPath%"
        ExitApp
    } catch {
        MsgBox, 48, 权限不足, 需要管理员权限才能正常运行此程序。`n请右键以管理员身份运行。
        ExitApp
    }
}

; 初始化配置
InitializeConfig()

; -------------------------------
;          GUI 界面
; -------------------------------
CreateGUI()
GoSub, RefreshConfigs

; 添加系统托盘菜单
Menu, Tray, Add, 显示主界面, ShowMainWindow
Menu, Tray, Add, 退出程序, GuiClose
Menu, Tray, Default, 显示主界面
Menu, Tray, Icon
Menu, Tray, Tip, 智能压枪助手 v2.0

return

; -------------------------------
;          托盘菜单事件
; -------------------------------
ShowMainWindow:
    Gui, Show, , 智能压枪助手 v2.0
return

; -------------------------------
;          启用/禁用辅助热键
; -------------------------------
HotkeyToggle:
    assistantEnabled := !assistantEnabled
    ED := assistantEnabled  ; 同步到界面变量
    GuiControl,, ED, %assistantEnabled%
    UpdateStatusDisplay()
    
    if (assistantEnabled) {
        ToolTip, 辅助功能已启用
    } else {
        ToolTip, 辅助功能已禁用
    }
    SetTimer, RemoveToolTip, 2000
return

RemoveToolTip:
    ToolTip
    SetTimer, RemoveToolTip, Off
return

; -------------------------------
;          屏息功能模块
; -------------------------------
~RButton::
    ; 只有在启用辅助时才执行功能
    if (!ED || !assistantEnabled) {
        KeyWait, RButton
        return
    }
    
    ; 屏息功能
    if (breathHold = 1) {
        Send {Blind}{Shift Down}
    }
    
    ; 等待右键释放
    KeyWait, RButton
    
    ; 释放屏息
    if (breathHold = 1) {
        Send {Blind}{Shift Up}
    }
return

; -------------------------------
;        半自动模式全自动开火（单独左键）
; -------------------------------
~LButton::
    ; 只有在启用辅助且为半自动模式时才执行
    if (!ED || !assistantEnabled || !SemiAutoMode || autoFireActive)
        return
    
    autoFireActive := true
    
    ; 参数计算
    Gui, Submit, NoHide
    fireInterval := Round(60000 / FireRate)
    baseRecoil := RecoilForce
    lastFireTime := A_TickCount - fireInterval
    
    ; 模拟全自动开火直到左键释放
    while (GetKeyState("LButton", "P") && ED && assistantEnabled && SemiAutoMode) {
        if (A_TickCount - lastFireTime >= fireInterval) {
            ; 发送左键点击（模拟真实的点击）
            SendInput {Blind}{LButton Down}
            Sleep, % (fireInterval < 50) ? 5 : 10
            SendInput {Blind}{LButton Up}
            
            ; 压枪处理
            Random, randRecoil, -0.5, 0.5
            mouseXY(0, Round(baseRecoil * 0.9 + randRecoil))
            
            lastFireTime := A_TickCount
        }
        Sleep, 1
    }
    
    autoFireActive := false
return

; -------------------------------
;        双模式核心逻辑（右键+左键）
; -------------------------------
~RButton & LButton::
    ; 只有在启用辅助时才执行功能
    if (!ED || !assistantEnabled || isFiring)
        return
    
    isFiring := true
    
    if (SemiAutoMode) {
        ; 半自动模式 - 右键+左键：全自动开火
        Gui, Submit, NoHide
        fireInterval := Round(60000 / FireRate)
        baseRecoil := RecoilForce
        lastFireTime := A_TickCount - fireInterval
        
        ; 模拟全自动开火直到任意键释放
        SendInput {Blind}{LButton Down}
        while (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED && assistantEnabled && SemiAutoMode) {
            if (A_TickCount - lastFireTime >= fireInterval) {
                ; 发送左键点击（模拟真实的点击）
                SendInput {Blind}{LButton Up}
                Sleep, % (fireInterval < 50) ? 5 : 10
                SendInput {Blind}{LButton Down}
                
                ; 压枪处理
                Random, randRecoil, -0.5, 0.5
                mouseXY(0, Round(baseRecoil * 0.9 + randRecoil))
                
                lastFireTime := A_TickCount
            }
            Sleep, 1
        }
        SendInput {Blind}{LButton Up}
    } else {
        ; 全自动模式 - 右键+左键：持续开火并处理后坐力
        SendInput {Blind}{LButton Down}
        
        Gui, Submit, NoHide
        fireInterval := Round(60000 / FireRate)
        baseRecoil := RecoilForce
        lastFireTime := A_TickCount - fireInterval
        
        while (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED && assistantEnabled && !SemiAutoMode) {
            if (A_TickCount - lastFireTime >= fireInterval) {
                ; 后坐力处理
                Random, randRecoil, -1, 1
                mouseXY(0, Round(baseRecoil + randRecoil))
                lastFireTime := A_TickCount
            }
            Sleep, 1
        }
        
        SendInput {Blind}{LButton Up}
    }
    
    isFiring := false
return

; -------------------------------
;          GUI 事件处理
; -------------------------------
CheckBox:
    Gui, Submit, NoHide
    assistantEnabled := ED  ; 同步界面状态到热键控制变量
    UpdateStatusDisplay()
    
    ; 更新热键状态
    if (ED = 1) {
        ToolTip, 辅助功能已启用
    } else {
        ToolTip, 辅助功能已禁用
    }
    SetTimer, RemoveToolTip, 2000
return

ButtonApplyChanges:
    ApplySettings()
return

RestoreDefaults:
    CreateDefaultConfig()
    LoadSettings()
    UpdateGUIDisplay()
    assistantEnabled := ED  ; 同步默认设置
    UpdateStatusDisplay()
    MsgBox, 64, 提示, 默认设置已恢复！
return

SaveConfig:
    SaveCurrentConfig()
return

LoadSelectedConfig:
    LoadSelectedConfiguration()
return

DeleteConfig:
    DeleteSelectedConfig()
return

RefreshConfigs:
    RefreshConfigList()
return

GuiClose:
    ExitApp

GuiEscape:
    Gui, Hide
return

; -------------------------------
;          核心功能函数
; -------------------------------

InitializeConfig() {
    global
    if (!FileExist(configFile)) {
        CreateDefaultConfig()
    }
    LoadSettings()
    assistantEnabled := ED  ; 初始化热键控制状态
}

CreateGUI() {
    global
    Gui, Font, s10, Microsoft YaHei
    
    ; 不使用AlwaysOnTop，添加最小化按钮
    Gui, +ToolWindow +Resize
    
    ; 热键设置
    Gui, Add, Text, xm ym+5 w80, 热键：
    Gui, Add, Hotkey, x+5 yp-3 vHotkeyC w200, % HotkeyCC
    Hotkey, %HotkeyCC%, HotkeyToggle
    
    ; 射速设置
    Gui, Add, Text, xm y+15 w80, 射速(RPM)：
    Gui, Add, Edit, x+5 yp-3 vFireRate w200 Number, %FireRate%
    
    ; 压枪力度
    Gui, Add, Text, xm y+15 w80, 压枪力度：
    Gui, Add, Edit, x+5 yp-3 vRecoilForce w200 Number, %RecoilForce%
    
    ; 功能选项
    Gui, Add, CheckBox, xm y+15 vBreathHold Checked%breathHold%, 启用屏息
    Gui, Add, CheckBox, xm y+15 vSemiAutoMode Checked%semiAutoMode%, 半自动模式
    Gui, Add, CheckBox, xm y+20 vED gCheckBox Checked%ED%, 启用辅助
    
    ; 状态显示
    Gui, Add, Text, xm y+15 vStatusText, 状态：未启用
    
    ; 配置管理
    Gui, Add, Text, xm y+15 w80, 已存配置：
    Gui, Add, DropDownList, x+5 yp-3 vConfigList w150, 
    Gui, Add, Button, x+5 yp w80 gLoadSelectedConfig, 加载选中
    Gui, Add, Button, x+5 yp w60 gRefreshConfigs, 刷新
    
    Gui, Add, Text, xm y+15 w80, 配置名称：
    Gui, Add, Edit, x+5 yp-3 vConfigName w150
    Gui, Add, Button, x+5 yp w60 gSaveConfig, 保存
    Gui, Add, Button, x+5 yp w60 gDeleteConfig, 删除
    
    ; 操作按钮
    Gui, Add, Button, xm y+15 w100 gButtonApplyChanges, 应用设置
    Gui, Add, Button, x+5 yp w100 gRestoreDefaults, 恢复默认
    
    Gui, Show, w400 h450, 智能压枪助手 v2.0
}

ApplySettings() {
    global
    Gui, Submit, NoHide
    
    ; 参数验证
    ValidateParameter("FireRate", 100, 2000, 600)
    ValidateParameter("RecoilForce", 1, 15, 5)
    
    ; 热键更新
    if (HotkeyC != HotkeyCC) {
        try {
            Hotkey, %HotkeyCC%, HotkeyToggle, Off
            Hotkey, %HotkeyC%, HotkeyToggle, On
            HotkeyCC := HotkeyC
        } catch {
            MsgBox, 16, 错误, 热键设置失败，请检查热键格式！
            return
        }
    }
    
    SaveSettings()
    UpdateGUIDisplay()
    UpdateStatusDisplay()
    MsgBox, 64, 提示, 设置已应用！
}

UpdateGUIDisplay() {
    global
    GuiControl,, FireRate, %FireRate%
    GuiControl,, RecoilForce, %RecoilForce%
    GuiControl,, HotkeyC, %HotkeyCC%
    GuiControl,, BreathHold, %breathHold%
    GuiControl,, SemiAutoMode, %semiAutoMode%
    GuiControl,, ED, %ED%
}

UpdateStatusDisplay() {
    global
    status := (ED = 1 && assistantEnabled) ? "已启用" : "未启用"
    mode := (SemiAutoMode = 1) ? "半自动" : "全自动"
    GuiControl,, StatusText, 状态：%status% (%mode%)
}

ValidateParameter(paramName, min, max, default) {
    global
    paramValue := %paramName%
    if (paramValue < min || paramValue > max || paramValue = "") {
        %paramName% := default
    }
}

mouseXY(x, y) {
    DllCall("mouse_event", "UInt", 0x01, "Int", x, "Int", y, "UInt", 0, "UPtr", 0)
}

; -------------------------------
;          配置管理函数
; -------------------------------

CreateDefaultConfig() {
    global
    IniWrite, PgDn, %configFile%, Settings, Hotkey
    IniWrite, 600, %configFile%, Settings, FireRate
    IniWrite, 5, %configFile%, Settings, RecoilForce
    IniWrite, 0, %configFile%, Settings, BreathHold
    IniWrite, 0, %configFile%, Settings, SemiAutoMode
    IniWrite, 1, %configFile%, Settings, ED
}

LoadSettings() {
    global
    IniRead, HotkeyCC, %configFile%, Settings, Hotkey, PgDn
    IniRead, FireRate, %configFile%, Settings, FireRate, 600
    IniRead, RecoilForce, %configFile%, Settings, RecoilForce, 5
    IniRead, breathHold, %configFile%, Settings, BreathHold, 0
    IniRead, semiAutoMode, %configFile%, Settings, SemiAutoMode, 0
    IniRead, ED, %configFile%, Settings, ED, 1
    
    ; 参数校验
    ValidateParameter("FireRate", 100, 2000, 600)
    ValidateParameter("RecoilForce", 1, 15, 5)
}

SaveSettings() {
    global
    IniWrite, %HotkeyCC%, %configFile%, Settings, Hotkey
    IniWrite, %FireRate%, %configFile%, Settings, FireRate
    IniWrite, %RecoilForce%, %configFile%, Settings, RecoilForce
    IniWrite, %breathHold%, %configFile%, Settings, BreathHold
    IniWrite, %semiAutoMode%, %configFile%, Settings, SemiAutoMode
    IniWrite, %ED%, %configFile%, Settings, ED
}

SaveCurrentConfig() {
    global
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 48, 提示, 请输入配置名称！
        return
    }
    
    IniWrite, %FireRate%, %configFile%, Config_%ConfigName%, FireRate
    IniWrite, %RecoilForce%, %configFile%, Config_%ConfigName%, RecoilForce
    IniWrite, %HotkeyCC%, %configFile%, Config_%ConfigName%, Hotkey
    IniWrite, %breathHold%, %configFile%, Config_%ConfigName%, BreathHold
    IniWrite, %semiAutoMode%, %configFile%, Config_%ConfigName%, SemiAutoMode
    IniWrite, %ED%, %configFile%, Config_%ConfigName%, ED
    
    GoSub, RefreshConfigs
    MsgBox, 64, 提示, 配置 [%ConfigName%] 已保存！
}

LoadSelectedConfiguration() {
    global
    Gui, Submit, NoHide
    if (ConfigList = "") {
        return
    }
    
    configName := ConfigList
    IniRead, tempFireRate, %configFile%, Config_%configName%, FireRate, %FireRate%
    IniRead, tempRecoil, %configFile%, Config_%configName%, RecoilForce, %RecoilForce%
    IniRead, tempHotkey, %configFile%, Config_%configName%, Hotkey, %HotkeyCC%
    IniRead, tempBreathHold, %configFile%, Config_%configName%, BreathHold, %breathHold%
    IniRead, tempSemiAutoMode, %configFile%, Config_%configName%, SemiAutoMode, %semiAutoMode%
    IniRead, tempED, %configFile%, Config_%configName%, ED, %ED%
    
    if (tempFireRate = "ERROR") {
        MsgBox, 16, 错误, 未找到配置 [%configName%]！
        return
    }
    
    ; 更新界面
    GuiControl,, FireRate, %tempFireRate%
    GuiControl,, RecoilForce, %tempRecoil%
    GuiControl,, HotkeyC, %tempHotkey%
    GuiControl,, BreathHold, %tempBreathHold%
    GuiControl,, SemiAutoMode, %tempSemiAutoMode%
    GuiControl,, ED, %tempED%
    
    ; 同步状态
    ED := tempED
    assistantEnabled := tempED
    
    GuiControl,, ConfigName, %configName%
    
    ; 更新热键
    if (tempHotkey != HotkeyCC) {
        try {
            Hotkey, %HotkeyCC%, HotkeyToggle, Off
            Hotkey, %tempHotkey%, HotkeyToggle, On
            HotkeyCC := tempHotkey
        } catch {
            ; 忽略热键错误
        }
    }
    
    ; 更新全局变量
    FireRate := tempFireRate
    RecoilForce := tempRecoil
    breathHold := tempBreathHold
    semiAutoMode := tempSemiAutoMode
    
    UpdateStatusDisplay()
    MsgBox, 64, 提示, 配置 [%configName%] 已加载！
}

DeleteSelectedConfig() {
    global
    Gui, Submit, NoHide
    if (ConfigName = "" && ConfigList = "") {
        MsgBox, 48, 提示, 请选择要删除的配置！
        return
    }
    
    configToDelete := (ConfigName != "") ? ConfigName : ConfigList
    
    MsgBox, 36, 确认删除, 是否确定删除配置 [%configToDelete%]？
    IfMsgBox, Yes
    {
        IniDelete, %configFile%, Config_%configToDelete%
        GuiControl,, ConfigName,
        GoSub, RefreshConfigs
        MsgBox, 64, 提示, 配置 [%configToDelete%] 已删除！
    }
}

RefreshConfigList() {
    global
    local sections, configs =
    IniRead, sections, %configFile%
    
    if (sections != "ERROR") {
        Loop, Parse, sections, `n
        {
            if (InStr(A_LoopField, "Config_") = 1) {
                StringTrimLeft, configName, A_LoopField, 7
                configs .= configName . "|"
            }
        }
    }
    
    GuiControl,, ConfigList, |%configs%
}