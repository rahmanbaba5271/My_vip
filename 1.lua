-- =====================================================================
--  ابو علي — FLOATING MENU EDITION 
--  Features: ESP Box · Black Sky · Remove Fog · iPad View
--  No License | No Screenshots
--  @h_AbuAli | @h113lh
-- =====================================================================

local BRPlayerCharacterBase = { ServerRPC = {}, ClientRPC = {}, MulticastRPC = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = { Reliable = true, Params = { UEnums.EPropertyClass.UInt32, UEnums.EPropertyClass.UInt32 } }

local KismetSystemLibrary = import("KismetSystemLibrary")
local packageName = KismetSystemLibrary.GetGameBundleId()
local isValidPackage = false
if packageName == "com.tencent.ig" then isValidPackage = true
elseif packageName == "com.pubg.krmobile" then isValidPackage = true
elseif packageName == "com.tencent.igvng" then isValidPackage = true
elseif string.find(packageName or "", "pubg", 1, true) then isValidPackage = true
elseif string.find(packageName or "", "tencent", 1, true) then isValidPackage = true end
if not isValidPackage then return end

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

-- =====================================================================
-- HELPERS
-- =====================================================================
local _slua = rawget(_G, "slua")
local function Valid(obj)
    if not obj then return false end
    if _slua and _slua.isValid then
        local ok, v = pcall(_slua.isValid, obj)
        return ok and v or false
    end
    return true
end

local function Notify(msg)
    local s = "[AbuAli] " .. tostring(msg)
    pcall(function()
        local sh = import("ScriptHelperClient")
        if sh and sh.AddOnScreenDebugMessage then
            sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1, G=0.85, B=0, A=1}, {X=1.2, Y=1.2})
        end
    end)
    print(s)
end
_G.MON5LANotiff = Notify

local function Later(sec, fn)
    pcall(function() require("common.time_ticker").AddTimerOnce(sec, fn) end)
end

local function GetCanvas()
    local canvas = nil
    pcall(function()
        local UIT = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if UIT and UIT.GetMainControlBaseUI then
            local m = UIT.GetMainControlBaseUI()
            if m and Valid(m) then
                if m.CanvasPanel_42 and Valid(m.CanvasPanel_42) then canvas = m.CanvasPanel_42
                elseif m.CanvasPanel_0 and Valid(m.CanvasPanel_0) then canvas = m.CanvasPanel_0 end
            end
        end
    end)
    return canvas
end

-- =====================================================================
-- CONFIG
-- =====================================================================
_G.GTLMODConfig = _G.GTLMODConfig or {
    EspBox = false,
    BlackSky = false,
    RemoveFog = false,
    IpadView = false,
    Btn5 = false,
    Btn6 = false,
}
_G.GTLMODState = _G.GTLMODState or {
    EspLoop = 0,
    GfxLoop = 0,
    PrevGraphicsState = {},
    CustomTextData = { IpadViewFOV = 120 },
}
if not _G.GTLMODState.PrevGraphicsState then _G.GTLMODState.PrevGraphicsState = {} end
if not _G.GTLMODState.CustomTextData then _G.GTLMODState.CustomTextData = { IpadViewFOV = 120 } end

-- =====================================================================
-- PROTECTION
-- =====================================================================
local function InstallProtection()
    pcall(function()
        local TssSdk = _G.TssSdk or package.loaded["TssSdk"]
        if TssSdk then
            TssSdk.OnRecvData = function() end
            TssSdk.SendReportInfo = function() end
            TssSdk.ScanMemory = function() return true end
            TssSdk.IsEmulator = function() return false end
            TssSdk.GetTssSdkReportInfo = function() return "" end
            TssSdk.ReportException = function() end
            TssSdk.ReportData = function() end
            TssSdk.CheckIntegrity = function() return true end
            TssSdk.VerifySignature = function() return true end
            TssSdk.CollectEvidence = function() return nil end
            TssSdk.UploadLog = function() end
            TssSdk.SendAntiData = function() end
            TssSdk.ReportViolation = function() end
        end
    end)
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1,["ReportSecAttackFlow"]=1,["ReportFireArms"]=1,
                ["ReportVerifyInfoFlow"]=1,["ReportMrpcsFlow"]=1,["ReportPlayerBehavior"]=1,
                ["ReportTeammatHurt"]=1,["ReportForbitPick"]=1,["ReportPlayerMoveRoute"]=1,
                ["ReportPlayerPosition"]=1,["ReportVehicleMoveFlow"]=1,["ReportSecTgameMovingFlow"]=1,
                ["report_parachute_data"]=1,["on_tss_sdk_anti_data"]=1,["ReportAimFlow"]=1,
                ["ReportHitFlow"]=1,["ReportCircleFlow"]=1,["report_players_ping"]=1,
                ["report_player_ip"]=1,["report_net_saturate"]=1,["report_speed_hack"]=1,
                ["report_wall_hack"]=1,["report_aim_bot"]=1,["report_esp_usage"]=1,
                ["report_modded_files"]=1,["detect_cheat"]=1,["ban_player"]=1,
                ["client_anti_cheat_report"]=1,["ClientSecMrpcsFlow"]=1,["MrpcsData"]=1,
                ["AntiCheatReport"]=1,["CheatDetection"]=1,["ViolationReport"]=1,
                ["SecurityViolation"]=1,["IntegrityCheck"]=1,["SignatureVerify"]=1,
                ["tss_sdk_report"]=1,["SwiftHawk"]=1,["ClientSwiftHawk"]=1,
                ["ClientSwiftHawkWithParams"]=1,["CoronaLabReport"]=1,
                ["ClientCircleFlow"]=1,["ReportModifierException"]=1,
                ["ShootVerifyFailed"]=1,["BulletHitInfoUploadData"]=1,
            }
            NetUtil.SendPacket = function(name, ...)
                if type(name) == "string" and blocked[name] then return nil end
                return orig(name, ...)
            end
            NetUtil.IsBypassed = true
        end
    end)
    pcall(function()
        local function disableHiggs()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if Valid(pc) then
                if pc.HiggsBoson then
                    pcall(function() pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end)
                end
                if pc.HiggsBosonComponent then
                    pcall(function() pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end)
                end
            end
        end
        local function loop() pcall(disableHiggs); Later(0.6, loop) end
        loop()
    end)
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        local noop = function() end
        for _, n in ipairs({
            "ReportAttackFlow","ReportSecAttackFlow","ReportFireArms","ReportVerifyInfoFlow",
            "ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt","ReportForbitPick",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportVehicleMoveFlow",
            "ReportSecTgameMovingFlow","ReportParachuteData","ReportAimFlow","ReportHitFlow",
            "ReportCircleFlow","SendTssSdkAntiDataToLobby","ClientSecMrpcsFlow",
            "SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams",
        }) do GC[n] = noop end
    end)
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then
            SMTD.MTDePicture = function() return "" end
            SMTD.ReMTDePicture = function() return "" end
            SMTD.HasCaptured = function() return true end
        end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then
            TLog.Info = function() end; TLog.Warning = function() end
            TLog.Error = function() end; TLog.Debug = function() end
        end
    end)
end

-- =====================================================================
-- FLOATING MENU
-- =====================================================================
local Menu = {
    built = false, icon = nil, panel = nil, rows = {},
    isOpen = false, refresh = nil, _iconBtn = nil,
}

local ROWS_DEF = {
    { key = "EspBox",    label = "📦  كشف البوكس",     real = true  },
    { key = "BlackSky",  label = "🌑  سماء سوداء",      real = true  },
    { key = "RemoveFog", label = "🌫️  إزالة الضباب",    real = true  },
    { key = "IpadView",  label = "📱  منظور ايباد",     real = true  },
    { key = "Btn5",      label = "🔒  ميزة 5",          real = false, divider = true },
    { key = "Btn6",      label = "🔒  ميزة 6",          real = false },
}

local function BuildFloatingMenu()
    if Menu.built and Valid(Menu.panel) and Valid(Menu.icon) then return true end
    Menu.built = false
    Menu.rows = {}

    local canvas = GetCanvas()
    if not canvas then return false end

    local FLinearColor = import("LinearColor")
    local FSlateColor  = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    local function Lin(r,g,b,a) return FLinearColor(r or 0, g or 0, b or 0, a or 1) end
    local function Slate(t) local ok, c = pcall(FSlateColor, t); return ok and c or t end
    local function Border(parent, r,g,b,a)
        local bd = CGame:NewObjectFromPath("/Script/UMG.Border", parent)
        if not bd or not Valid(bd) then return nil end
        pcall(function() bd:SetBrushColor(Lin(r,g,b,a)) end)
        return bd
    end
    local function Text(parent, str, size, color, bold)
        local t = CGame:NewObjectFromPath("/Script/UMG.TextBlock", parent)
        if not t or not Valid(t) then return nil end
        pcall(function() t:SetText(str) end)
        pcall(function()
            local f = t.Font
            f.Size = size or 16
            if bold then pcall(function() f.TypefaceFontName = "Bold" end) end
            t.Font = f
        end)
        if color then pcall(function() t:SetColorAndOpacity(Slate(color)) end) end
        pcall(function() t:SetJustification(1) end)
        return t
    end
    local function VSpacer(parent, h)
        local s = CGame:NewObjectFromPath("/Script/UMG.Spacer", parent)
        if not s or not Valid(s) then return end
        local slot = parent:AddChildToVerticalBox(s)
        if slot then pcall(function() slot:SetSize({X=0, Y=h or 4}); slot:SetAutoSize(false) end) end
    end
    local function HSpacer(parent, w)
        local s = CGame:NewObjectFromPath("/Script/UMG.Spacer", parent)
        if not s or not Valid(s) then return end
        local slot = parent:AddChildToHorizontalBox(s)
        if slot then pcall(function() slot:SetSize({X=w or 8, Y=0}) end) end
    end

    -- =============== ICON ===============
    local ICON = 56
    local iconBox = CGame:NewObjectFromPath("/Script/UMG.SizeBox", canvas)
    if not iconBox or not Valid(iconBox) then return false end
    pcall(function() iconBox:SetWidthOverride(ICON) end)
    pcall(function() iconBox:SetHeightOverride(ICON) end)
    Menu.icon = iconBox

    local iconOuter = Border(iconBox, 0.85, 0.65, 0.20, 1.0)
    if iconOuter then
        pcall(function() iconOuter:SetPadding({Left=2, Top=2, Right=2, Bottom=2}) end)
        pcall(function() iconBox:AddChild(iconOuter) end)
        local iconMid = Border(iconOuter, 0.05, 0.08, 0.18, 1.0)
        if iconMid then
            pcall(function() iconMid:SetPadding({Left=1, Top=1, Right=1, Bottom=1}) end)
            pcall(function() iconOuter:AddChild(iconMid) end)
            local iconBg = Border(iconMid, 0.02, 0.02, 0.05, 1.0)
            if iconBg then
                pcall(function() iconMid:AddChild(iconBg) end)
                local iconBtn = CGame:NewObjectFromPath("/Script/UMG.Button", iconBg)
                if iconBtn and Valid(iconBtn) then
                    pcall(function() iconBtn:SetBackgroundColor(Lin(0,0,0,0.01)) end)
                    local iconTxt = Text(iconBtn, "V", 30, Lin(0.95, 0.80, 0.25, 1.0), true)
                    if iconTxt then pcall(function() iconBtn:AddChild(iconTxt) end) end
                    pcall(function() iconBg:AddChild(iconBtn) end)
                    Menu._iconBtn = iconBtn
                end
            end
        end
    end

    local iconSlot = canvas:AddChildToCanvas(iconBox)
    if iconSlot then
        pcall(function()
            iconSlot:SetAutoSize(false)
            iconSlot:SetAnchors({Minimum={X=0, Y=0.42}, Maximum={X=0, Y=0.42}})
            iconSlot:SetAlignment({X=0, Y=0})
            iconSlot:SetPosition({X=18, Y=0})
            iconSlot:SetSize({X=ICON, Y=ICON})
            iconSlot:SetZOrder(99998)
        end)
    end

    -- =============== PANEL ===============
    local PW, PH = 360, 470
    local panelBox = CGame:NewObjectFromPath("/Script/UMG.SizeBox", canvas)
    if not panelBox or not Valid(panelBox) then return false end
    pcall(function() panelBox:SetWidthOverride(PW) end)
    pcall(function() panelBox:SetHeightOverride(PH) end)
    Menu.panel = panelBox

    local pOuter = Border(panelBox, 0.85, 0.65, 0.20, 1.0)
    if not pOuter then return false end
    pcall(function() pOuter:SetPadding({Left=2, Top=2, Right=2, Bottom=2}) end)
    pcall(function() panelBox:AddChild(pOuter) end)
    local pInner = Border(pOuter, 0.10, 0.18, 0.40, 1.0)
    if not pInner then return false end
    pcall(function() pInner:SetPadding({Left=1, Top=1, Right=1, Bottom=1}) end)
    pcall(function() pOuter:AddChild(pInner) end)
    local pBg = Border(pInner, 0.006, 0.010, 0.025, 0.99)
    if not pBg then return false end
    pcall(function() pInner:AddChild(pBg) end)

    local vbox = CGame:NewObjectFromPath("/Script/UMG.VerticalBox", pBg)
    if not vbox or not Valid(vbox) then return false end
    pcall(function() pBg:AddChild(vbox) end)

    -- Header
    local headerB = Border(vbox, 0.90, 0.70, 0.22, 1.0)
    if headerB then
        local hSlot = vbox:AddChildToVerticalBox(headerB)
        if hSlot then pcall(function() hSlot:SetSize({X=0, Y=58}); hSlot:SetAutoSize(false) end) end
        local hTxt = Text(headerB, "『 ابو علي 』", 24, Lin(0.03, 0.03, 0.08, 1.0), true)
        if hTxt then pcall(function() headerB:AddChild(hTxt) end) end
    end

    VSpacer(vbox, 8)

    -- Row builder
    local function BuildRow(def)
        local H = 50
        local rowSize = CGame:NewObjectFromPath("/Script/UMG.SizeBox", vbox)
        if not rowSize or not Valid(rowSize) then return end
        pcall(function() rowSize:SetHeightOverride(H) end)
        local rSlot = vbox:AddChildToVerticalBox(rowSize)
        if rSlot then pcall(function() rSlot:SetSize({X=0, Y=H}); rSlot:SetAutoSize(false) end) end

        local frame = Border(rowSize, 0.10, 0.20, 0.45, 1.0)
        if not frame then return end
        pcall(function() frame:SetPadding({Left=1, Top=1, Right=1, Bottom=1}) end)
        pcall(function() rowSize:AddChild(frame) end)

        local bg = Border(frame, 0.015, 0.025, 0.055, 1.0)
        if not bg then return end
        pcall(function() frame:AddChild(bg) end)

        local btn = CGame:NewObjectFromPath("/Script/UMG.Button", bg)
        if not btn or not Valid(btn) then return end
        pcall(function() btn:SetBackgroundColor(Lin(0, 0, 0, 0.01)) end)
        pcall(function() bg:AddChild(btn) end)

        local hbox = CGame:NewObjectFromPath("/Script/UMG.HorizontalBox", btn)
        if not hbox or not Valid(hbox) then return end
        pcall(function() btn:AddChild(hbox) end)

        HSpacer(hbox, 10)

        local accent = Border(hbox, 0.30, 0.30, 0.30, 1.0)
        if accent then
            local aSlot = hbox:AddChildToHorizontalBox(accent)
            if aSlot then pcall(function() aSlot:SetSize({X=4, Y=46}) end) end
        end

        HSpacer(hbox, 8)

        local labelT = Text(hbox, def.label, 15, Lin(0.88, 0.92, 1.0, 1.0), true)
        if labelT then
            local lSlot = hbox:AddChildToHorizontalBox(labelT)
            if lSlot then pcall(function() lSlot:SetSize({X=224, Y=46}) end) end
        end

        HSpacer(hbox, 8)

        local pillFrame = Border(hbox, 0.90, 0.35, 0.35, 1.0)
        if not pillFrame then return end
        local pSlot = hbox:AddChildToHorizontalBox(pillFrame)
        if pSlot then pcall(function() pSlot:SetSize({X=80, Y=34}) end) end
        pcall(function() pillFrame:SetPadding({Left=2, Top=2, Right=2, Bottom=2}) end)

        local pillBg = Border(pillFrame, 0.10, 0.02, 0.02, 1.0)
        if not pillBg then return end
        pcall(function() pillFrame:AddChild(pillBg) end)

        local stateT = Text(pillBg, "OFF", 14, Lin(1, 0.55, 0.55, 1), true)
        if stateT then pcall(function() pillBg:AddChild(stateT) end) end

        local cKey, cReal = def.key, def.real
        pcall(function()
            btn.OnClicked:Add(function()
                if cReal then
                    _G.GTLMODConfig[cKey] = not _G.GTLMODConfig[cKey]
                    if Menu.refresh then Menu.refresh() end
                else
                    Notify("هذه الميزة غير متوفرة")
                end
            end)
        end)

        table.insert(Menu.rows, {
            key = cKey, real = cReal,
            frame = frame, accent = accent,
            pillFrame = pillFrame, pillBg = pillBg, stateT = stateT,
        })
    end

    for i, def in ipairs(ROWS_DEF) do
        if def.divider then
            VSpacer(vbox, 8)
            local div = Border(vbox, 0.85, 0.65, 0.20, 0.55)
            if div then
                local dSlot = vbox:AddChildToVerticalBox(div)
                if dSlot then pcall(function() dSlot:SetSize({X=0, Y=1}); dSlot:SetAutoSize(false) end) end
            end
            VSpacer(vbox, 8)
        end
        BuildRow(def)
        if i < #ROWS_DEF and not ROWS_DEF[i+1].divider then
            VSpacer(vbox, 4)
        end
    end

    VSpacer(vbox, 6)

    -- Footer
    local footerT = Text(vbox, "@h_AbuAli  ·  @h113lh", 11, Lin(0.55, 0.65, 0.85, 1.0), false)
    if footerT then
        local fSlot = vbox:AddChildToVerticalBox(footerT)
        if fSlot then pcall(function() fSlot:SetSize({X=0, Y=22}); fSlot:SetAutoSize(false) end) end
    end

    -- Refresh
    local Refresh
    Refresh = function()
        for _, r in ipairs(Menu.rows) do
            local on = _G.GTLMODConfig[r.key] == true
            if Valid(r.frame) then
                if on then
                    pcall(function() r.frame:SetBrushColor(Lin(0.22, 0.70, 0.35, 1.0)) end)
                else
                    pcall(function() r.frame:SetBrushColor(Lin(0.10, 0.20, 0.45, 1.0)) end)
                end
            end
            if Valid(r.accent) then
                if on then
                    pcall(function() r.accent:SetBrushColor(Lin(0.20, 0.90, 0.45, 1.0)) end)
                else
                    pcall(function() r.accent:SetBrushColor(Lin(0.25, 0.30, 0.40, 1.0)) end)
                end
            end
            if Valid(r.pillFrame) and Valid(r.pillBg) and Valid(r.stateT) then
                if on then
                    pcall(function() r.pillFrame:SetBrushColor(Lin(0.20, 0.90, 0.45, 1.0)) end)
                    pcall(function() r.pillBg:SetBrushColor(Lin(0.02, 0.15, 0.06, 1.0)) end)
                    pcall(function() r.stateT:SetText("ON") end)
                    pcall(function() r.stateT:SetColorAndOpacity(Slate(Lin(0.85, 1.0, 0.85, 1.0))) end)
                else
                    pcall(function() r.pillFrame:SetBrushColor(Lin(0.95, 0.35, 0.35, 1.0)) end)
                    pcall(function() r.pillBg:SetBrushColor(Lin(0.15, 0.02, 0.02, 1.0)) end)
                    pcall(function() r.stateT:SetText("OFF") end)
                    pcall(function() r.stateT:SetColorAndOpacity(Slate(Lin(1.0, 0.55, 0.55, 1.0))) end)
                end
            end
        end
    end
    Menu.refresh = Refresh
    Refresh()

    local pSlot = canvas:AddChildToCanvas(panelBox)
    if pSlot then
        pcall(function()
            pSlot:SetAutoSize(false)
            pSlot:SetAnchors({Minimum={X=0.5, Y=0.5}, Maximum={X=0.5, Y=0.5}})
            pSlot:SetAlignment({X=0.5, Y=0.5})
            pSlot:SetPosition({X=0, Y=0})
            pSlot:SetSize({X=PW, Y=PH})
            pSlot:SetZOrder(99999)
        end)
    end
    pcall(function() panelBox:SetVisibility(Menu.isOpen and 0 or 2) end)

    if Menu._iconBtn and Valid(Menu._iconBtn) then
        pcall(function()
            Menu._iconBtn.OnClicked:Add(function()
                Menu.isOpen = not Menu.isOpen
                if Valid(Menu.panel) then
                    Menu.panel:SetVisibility(Menu.isOpen and 0 or 2)
                end
            end)
        end)
    end

    Menu.built = true
    return true
end

local function MenuWatchdog()
    if not Valid(Menu.panel) or not Valid(Menu.icon) then
        Menu.built = false
        Menu.isOpen = false
        BuildFloatingMenu()
    end
    Later(2.0, MenuWatchdog)
end

-- =====================================================================
-- ESP BOX LOOP (0.15s)
-- =====================================================================
local function ESPBoxLoop()
    if not _G.GTLMODConfig.EspBox then
        Later(0.35, ESPBoxLoop)
        return
    end

    pcall(function()
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not Valid(lp) then return end

        local allChars = {}
        if GameplayData.GetAllPlayerCharacters then
            allChars = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then
            for _, c in pairs(GameplayData.GameCharacters) do table.insert(allChars, c) end
        end

        local myTeam = lp.TeamID or 0
        pcall(function() myTeam = lp:GetTeamID() or myTeam end)

        for _, enemy in pairs(allChars) do
            if Valid(enemy) and enemy ~= lp then
                local eTeam = enemy.TeamID or 0
                pcall(function() eTeam = enemy:GetTeamID() or eTeam end)
                if eTeam ~= myTeam then
                    local dead = false
                    pcall(function()
                        if type(enemy.IsDead) == "function" then dead = enemy:IsDead()
                        elseif enemy.bIsDead ~= nil then dead = enemy.bIsDead end
                        if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then dead = true end
                    end)
                    if not dead then
                        pcall(function()
                            local hp, maxHp = 100, 100
                            if enemy.Health then hp = enemy.Health
                            elseif type(enemy.GetHealth) == "function" then hp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax
                            elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                            if not maxHp or maxHp <= 0 then maxHp = 100 end
                            local ratio = hp / maxHp
                            if ratio < 0 then ratio = 0 end
                            if ratio > 1 then ratio = 1 end

                            if enemy.Replay_IsEnemyFrameUIExisted
                               and not enemy:Replay_IsEnemyFrameUIExisted() then
                                enemy:Replay_CreateEnemyFrameUI(true, true)
                            end
                            if enemy.Replay_SetVisiableOfFrameUI then
                                enemy:Replay_SetVisiableOfFrameUI(true)
                            end
                            if enemy.Replay_UpdateEnemyFrameUI then
                                enemy:Replay_UpdateEnemyFrameUI(ratio)
                            end

                            local uiComp = enemy.EnemyFrameUI
                                or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if type(uiComp.SetVisibility) == "function" then
                                    uiComp:SetVisibility(0)
                                end
                                if type(uiComp.SetHiddenInGame) == "function" then
                                    uiComp:SetHiddenInGame(false)
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)

    Later(0.15, ESPBoxLoop)
end

-- =====================================================================
-- GRAPHICS + CAMERA LOOP (0.35s)
-- iPad View · Black Sky · Remove Fog
-- =====================================================================
local function GfxCamLoop()
    -- iPad View (FOV)
    pcall(function()
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not Valid(lp) then return end
        if lp.bIsWeaponAiming then return end

        local cam = lp.ThirdPersonCameraComponent
        if not Valid(cam) then pcall(function() cam = lp.TPPCameraComponent end) end
        if not Valid(cam) then pcall(function() cam = lp.TPCameraComponent end) end
        if not Valid(cam) then return end

        local target
        if _G.GTLMODConfig.IpadView then
            target = _G.GTLMODState.CustomTextData.IpadViewFOV or 120
        else
            target = 80
        end
        if cam.FieldOfView ~= target then
            cam.FieldOfView = target
        end
    end)

    -- Graphics commands
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg and lsg.GetGameInstance and lsg.GetGameInstance()
        if not gi then return end
        local P = _G.GTLMODState.PrevGraphicsState

        if _G.GTLMODConfig.BlackSky and not P.BlackSky then
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
            P.BlackSky = true
        elseif not _G.GTLMODConfig.BlackSky and P.BlackSky then
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
            P.BlackSky = false
        end

        if _G.GTLMODConfig.RemoveFog and not P.RemoveFog then
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "0")
            gi:ExecuteCMD("r.VolumetricFog", "0")
            P.RemoveFog = true
        elseif not _G.GTLMODConfig.RemoveFog and P.RemoveFog then
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "1")
            gi:ExecuteCMD("r.VolumetricFog", "1")
            P.RemoveFog = false
        end
    end)

    Later(0.35, GfxCamLoop)
end

-- =====================================================================
-- CHARACTER CLASS METHODS
-- =====================================================================
function BRPlayerCharacterBase:ctor() end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CFDC = import("CheckFallingDistanceComponent")
    if slua.isValid(CFDC) and not slua.isValid(self:GetComponentByClass(CFDC)) then
      Game:AddComponent(CFDC, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then self.STCharacterMovement.bPositiveBlowUp = true end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate",
      { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE,
      { [1] = "FinishedState" }, self.HandleFinishedState, self)
  end
end
--لا تحاول تسرق منشور مجاني
function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then return end
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then self:UpdatePlayerAttachToVehicle(uVehicle) end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then self:FixMeshContainerOffsetIfNeeded(uVehicle) end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then return end
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then return end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then return end
  if not slua.isValid(self:GetCurrentVehicle()) then return end
  if Game:IsDriver(self.Object) then return end
  if not self.nUpdatePlayerAttachToVehicleCount then self.nUpdatePlayerAttachToVehicleCount = 0 end
  local EPS = import("ESTEPoseState")
  local bStand = self.PoseState == EPS.Stand
  local aRL = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local mRL = self.Mesh:GetRelativeTransform():GetLocation()
  local mcRLZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local cR = self.CapsuleComponent:GetScaledCapsuleRadius()
  local cHH = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local mcEZ = -1 * self.StandHalfHeight
  local eR = self.StandRadius
  local eHH = self.StandHalfHeight
  local eMRL = FVector(0, 0, 0)
  local eARL = FVector(0, 0, self.StandHalfHeight)
  local tol = 1.0
  local cRLok = aRL:Equals(eARL, tol)
  local mRLok = mRL:Equals(eMRL, tol)
  local mcRLok = tol > math.abs(mcRLZ - mcEZ)
  local cRok = tol > math.abs(cR - eR)
  local cHHok = tol > math.abs(cHH - eHH)
  local allOk = bStand and cRLok and mRLok and mcRLok and cRok and cHHok
  if not allOk then self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else self.nUpdatePlayerAttachToVehicleCount = 0 end
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not allOk then
    local GD = require("GameLua.GameCore.Data.GameplayData")
    local uPC = GD.GetPlayerController()
    if uPC.ReportCrashKitFeature and uPC.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local s = string.format("VehicleShapeType:%s PlayerKey:%s",
        tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey))
      uPC.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(s)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end
--منشور بقتاة سجاد
function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then return end
  if not slua.isValid(self.MeshContainer) then return end
  if not slua.isValid(self:GetCurrentVehicle()) then return end
  if Game:IsDriver(self.Object) then return end
  local tol = 1.0
  local eZ = -1 * self.StandHalfHeight
  local cZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if tol <= math.abs(cZ - eZ) then self:SetMeshContainerOffsetZ(eZ) end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  local EPS_ = import("EPawnState")
  if PawnState == EPS_.SwitchPP then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) then uPC:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGT = import("EGameModeType")
    local MMIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local gt = CGameMode.GameModeType
    local gid = tonumber(CGameState.GameModeID)
    local tOk = gt == EGT.ETypicalGameMode or gt == EGT.EFourInOneGameMode or gt == EGT.EHeavyWeaponGameMode
    return tOk and not MMIds[gid]
  end
  return false
end
--اثبات حقوق h113lh 
function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(Last, New)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, Last, New)
  local EPS = import("EParachuteState")
  if not Client then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then
      if New == EPS.PS_Opening then
        if uPC.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uPC.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif New == EPS.PS_None then
        if uPC.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uPC.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uPC.CheckParachuteOpenFeature.ClearTimerAndState then
          uPC.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
  if not Client then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) and uPC.CheckParachuteOpenFeature then
      if uPC.CheckParachuteOpenFeature.ClearTimerAndState then uPC.CheckParachuteOpenFeature:ClearTimerAndState() end
      if uPC.CheckParachuteOpenFeature.ResetCheckShowUI then uPC.CheckParachuteOpenFeature:ResetCheckShowUI() end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGS = GameplayData:GetGameState()
  local STEGS = import("STExtraGameStateBase")
  if slua.isValid(uGS) and Game:IsClassOf(uGS, STEGS) then
    local EGT = import("EGameModeType")
    return uGS.GameModeType == EGT.EWarGameMode
  end
  return false
end

function BRPlayerCharacterBase:BPOnRecycled() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:BPOnRespawned() if Client then self:ResetMeshRelativeLocationAndRotation() end end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local dRot = FRotator(0, -90, 0)
    local dLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(dRot, false, nil, false) end
    self:CacheInitialMeshOffset(dLoc, dRot)
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  local EMM = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMM.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement)
     and self.STCharacterMovement.MovementMode == EMM.MOVE_Walking
     and UIManager and UIManager.UI_Config_InGame and UIManager.UI_Config_InGame.ParachuteOpenUI then
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPC = self:GetControllerSafety()
  if slua.isValid(uPC) then
    if not self:GetEnsure() then
      local EST = import("EStateType")
      if uPC:GetCurrentStateType() ~= EST.State_ParachuteJump and uPC:GetCurrentStateType() ~= EST.State_ParachuteOpen then
        local EPS = import("ESTEPoseState")
        self:SwitchPoseState(EPS.Stand, true, true, true, false)
        uPC:ReInitParachuteItem()
        uPC:ServerChangeStatePC(EST.State_ParachuteJump)
      end
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
    end
  end
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPS = self:GetPlayerStateSafety()
  if not slua.isValid(uPS) then return false end
  if uPS.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPC = self:GetPlayerControllerSafety()
    if slua.isValid(uPC) then uPC:DisplayGameTipWithMsgID(48532) end
  end
  return not uPS.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local c = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(c) and self.bCanNearDeathGiveup == true then
    local uPS = self:GetPlayerStateSafety()
    if slua.isValid(uPS) then uPS:AddGeneralCount(1613, 1, false) end
    c:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  local STExtra = import("STExtraBlueprintFunctionLibrary")
  if STExtra.IsDevelopment() then self:MulticastRPC_GmPlayAction(actionId) end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then return end
  local c = self:GetPlayEmoteComponent()
  if not slua.isValid(c) then return end
  local LF = require("common.log_filter")
  LF.SetLogTreeEnable(true)
  local cfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not cfg then return end
  local handlePath = cfg.Path
  local EH = slua.loadObject(handlePath)
  local arr = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EH()
  c:OnLoadEmoteAssetBegin(handle, actionId, arr, "")
  local tb = FuncUtil.LuaArrayToTable(arr)
  local AU = require("common.asset_util")
  local loadLater = function() c:OnLoadEmoteAssetEnd(handle, actionId, 0) end
  AU.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(b)
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = b
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox)
     and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox"))
     and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(A) self:SetAttrValue("AreaID", A, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end

function BRPlayerCharacterBase:DoModChangeToBT()
  if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera
     and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera
     and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local W = self:GetWeaponBySlot(Slot)
    if slua.isValid(W) then
      local wID = W:GetWeaponID()
      local ATC = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if ATC and ATC.CheckIsWeaponInBlackList and ATC.CheckIsWeaponInBlackList(wID) then
        local uPC = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPC) and uPC.Role == ENetRole.ROLE_AutonomousProxy then
          uPC:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- =====================================================================
-- بو علي
-- =====================================================================
pcall(InstallProtection)

pcall(function()
    Later(2.0, function()
        local tries = 0
        local function tryBuild()
            tries = tries + 1
            if BuildFloatingMenu() then
                Notify("القائمة العائمة جاهزة")
                MenuWatchdog()
                return
            end
            if tries < 90 then Later(1.0, tryBuild) end
        end
        tryBuild()
    end)
end)

pcall(function()
    Later(3.0, function()
        _G.GTLMODState.EspLoop = (_G.GTLMODState.EspLoop or 0) + 1
        ESPBoxLoop()
    end)
end)

pcall(function()
    Later(3.0, function()
        _G.GTLMODState.GfxLoop = (_G.GTLMODState.GfxLoop or 0) + 1
        GfxCamLoop()
    end)
end)

-- =====================================================================
-- CLASS RETURN
-- =====================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)

return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
    { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
    { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
    { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
    { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
    { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
    { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
    { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
    { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
    { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
    { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" }
}, "BRPlayerCharacterBase")
