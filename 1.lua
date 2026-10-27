-- ========================================================================
-- BRPlayerCharacterBase.lua - COMPLETE INTEGRATED VERSION
-- ========================================================================
-- Ready-to-use script with all features and aggressive bypasses (Fully Integrated)
-- Enhanced with Advanced Anti-Ban Bypass System
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local KismetMathLibrary = import("KismetMathLibrary")
local GameplayStatics = import("GameplayStatics")
local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

-- ========================================================================
-- ⚡ EXPIRY SYSTEM (FIXED)
-- ========================================================================
local EXPIRY_TIMESTAMP = os.time({ year = 2027, month = 10, day = 18, hour = 12, min = 0, sec = 0 })

local function FormatTimeRemaining(sec)
    if sec <= 0 then return "0d 0h 0m 0s" end
    local days = math.floor(sec / 86400); sec = sec % 86400
    local hours = math.floor(sec / 3600); sec = sec % 3600
    local minutes = math.floor(sec / 60)
    local seconds = sec % 60
    return string.format("%dd %dh %dm %ds", days, hours, minutes, seconds)
end

function CheckExpiration()
    local now = os.time()
    local remaining = EXPIRY_TIMESTAMP - now
    if remaining <= 0 then
        _G._MOD_EXPIRED = true
        return false
    end
    _G._MOD_EXPIRED = false
    _G._MOD_REMAINING_SECONDS = remaining
    return true
end

local function ShowExpiryPopup(expired)
    pcall(function()
        local Msg = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
        local function onClick() end
        if expired then
            local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
            Msg.Show(4, "MOD EXPIRED", "THIS MOD HAS EXPIRED.\n\nEXPIRED ON: " .. expiresAt .. "\n\nTEXT Me to buy @rolxir", onClick)
        else
            local remaining = _G._MOD_REMAINING_SECONDS or (EXPIRY_TIMESTAMP - os.time())
            local formatted = FormatTimeRemaining(remaining)
            local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
            Msg.Show(4, "NOTIFICATIO", "متبقي:" .. formatted .. "\nEXPIRES AT: " .. expiresAt .. "\n\nراسل للتجديد @rolxir-@a_y_i9", onClick)
        end
    end)
end

function _G.TryShowWelcome()
    if _G.WelcomeShown then return end
    if not CheckExpiration() then
        ShowExpiryPopup(true)
        return
    end
    ShowExpiryPopup(false)
    _G.WelcomeShown = true
end

-- ========================================================================
-- ⚡ 165 FPS ENABLER (FIXED - No Graphics Conflict)
-- ========================================================================
local function Enable165FPS()
    if _G.__FPS165_LOADED then return end
    
    local originalFunctions = {}
    
    pcall(function()
        local logicSettingGraphics = require("client.slua.logic.setting.logic_setting_graphics")
        if logicSettingGraphics then
            originalFunctions.SetFPS = logicSettingGraphics.SetFPS
            
            logicSettingGraphics.SetFPS = function(settings, fpsLevel)
                if originalFunctions.SetFPS then
                    originalFunctions.SetFPS(settings, fpsLevel)
                end
                if fpsLevel == 8 and _G.AK_GetVal("FPS165") == 1 and Game and Game.IsInGame and Game:IsInGame() then
                    pcall(function()
                        settings:ExecuteCMD("t.MaxFPS", "165")
                        settings:ExecuteCMD("r.FrameRateLimit", "165")
                    end)
                end
            end
        end
    end)
    
    pcall(function()
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        if GSC_FPS and GSC_FPS.__inner_impl then
            originalFunctions.GetMaxFPSLevel = GSC_FPS.__inner_impl.GetMaxFPSLevel
            
            GSC_FPS.__inner_impl.GetMaxFPSLevel = function()
                return 8, 8
            end
        end
    end)
    
    pcall(function()
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            originalFunctions.FPSFT_ShowOrHide = GSC_FPSFT.__inner_impl.ShowOrHide
            originalFunctions.FPSFT_Init = GSC_FPSFT.__inner_impl.InitFPSFTSwitch
            originalFunctions.FPSFT_Value = GSC_FPSFT.__inner_impl.InitFPSFTValue165
            
            GSC_FPSFT.__inner_impl.ShowOrHide = function(ui)
                if originalFunctions.FPSFT_ShowOrHide then
                    originalFunctions.FPSFT_ShowOrHide(ui)
                end
                if Game and Game.IsInGame and Game:IsInGame() then
                    ui:SelfHitTestInvisible()
                    if ui.InitFPSFTSwitch then
                        ui:InitFPSFTSwitch()
                    end
                end
            end
            
            GSC_FPSFT.__inner_impl.InitFPSFTSwitch = function(ui)
                if originalFunctions.FPSFT_Init then
                    originalFunctions.FPSFT_Init(ui)
                end
                local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
                if GraphicSettingDB then
                    local isEnabled = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                    if ui.UIRoot and ui.UIRoot.Setting_Switch then
                        ui.UIRoot.Setting_Switch:SetSwitcherEnable2(isEnabled, true)
                    end
                end
            end
            
            GSC_FPSFT.__inner_impl.InitFPSFTValue165 = function(ui)
                if originalFunctions.FPSFT_Value then
                    originalFunctions.FPSFT_Value(ui)
                end
                local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
                if GraphicSettingDB and ui.UIRoot then
                    local isEnabled = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                    local fpsValue = isEnabled and GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    
                    local root = ui.UIRoot
                    if root.Slider_screen3 then
                        if isEnabled then
                            root.Slider_screen3:SetLocked(false)
                            root.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1, 1, 1, 1))
                            root.Slider_screen3:SetSliderHandleColor(FLinearColor(1, 1, 1, 1))
                        else
                            root.Slider_screen3:SetLocked(true)
                            root.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1, 0.625, 0.6, 1))
                            root.Slider_screen3:SetSliderHandleColor(FLinearColor(1, 0.625, 0.6, 1))
                        end
                        
                        local percent = (fpsValue - 90) / (165 - 90)
                        root.Veihclescreen3:SetText(tostring(fpsValue))
                        root.Slider_screen3:SetValue(percent)
                        root.ProgressBar_screen3:SetPercent(percent)
                    end
                end
            end
        end
    end)
    
    _G.__FPS165_APPLIED = false
    _G.__FPS165_LOADED = true
    print("✅ 165 FPS Enabler Loaded (Graphics Compatible)")
end

local function Apply165FPSInGame()
    if _G.AK_GetVal("FPS165") ~= 1 then return end
    if _G.__FPS165_APPLIED then return end
    
    pcall(function()
        local world = slua.getWorld()
        if world then
            local KismetSystemLibrary = import("KismetSystemLibrary")
            if KismetSystemLibrary then
                KismetSystemLibrary.ExecuteConsoleCommand(world, "t.MaxFPS 165")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.FrameRateLimit 165")
                _G.__FPS165_APPLIED = true
                print("✅ 165 FPS Applied In-Game")
            end
        end
    end)
end

-- ========================================================================
-- ⚡ FEATURES CONFIG
-- ========================================================================
_G.AK_Features = {
    { id = "ESP_HP", name = "ESP Health Bar", val = 0, type = "toggle" },
    { id = "ESP_BOX", name = "ESP Box", val = 1, type = "toggle" },
    { id = "ESP_MAP", name = "Mini Map ESP", val = 1, type = "toggle" },
    { id = "AIMBOT", name = "Aimbot", val = 1, type = "toggle" },
    { id = "ENEMY_COUNTER", name = "Enemy Counter", val = 1, type = "toggle" },
    { id = "ESP_V2", name = "ESP V2 Master", val = 1, type = "toggle" },
    { id = "ESP9_Count", name = "ESP9 Count", val = 1, type = "toggle" },
    { id = "ESP9_Name", name = "ESP9 Name", val = 1, type = "toggle" },
    { id = "ESP9_HP", name = "ESP9 HP", val = 1, type = "toggle" },
    { id = "ESP9_Team", name = "ESP9 Team", val = 1, type = "toggle" },
    { id = "ESP9_Weapon", name = "ESP9 Weapon", val = 1, type = "toggle" },
    { id = "ESP9_Distance", name = "ESP9 Distance", val = 1, type = "toggle" },
    { id = "ESP9_Line", name = "ESP9 Line", val = 1, type = "toggle" },
    { id = "ESP9_Skeleton", name = "ESP9 Skeleton", val = 0, type = "toggle" },
    { id = "WALLHACK", name = "Wallhack", val = 1, type = "toggle" },
    { id = "FPS165", name = "165 FPS", val = 1, type = "toggle" },
    -- Enemy Name & Box ESP Features
    { id = "ENEMY_NAME", name = "Enemy Name ESP", val = 1, type = "toggle" },
    { id = "ENEMY_BOX", name = "Enemy Box ESP", val = 1, type = "toggle" },
    { id = "ENEMY_BOX_COLOR", name = "Box Color", val = 0, type = "dropdown", options = {"Red", "Green", "Blue", "Yellow", "Purple", "Cyan"} },
    -- Anti-Ban Features
    { id = "ANTIBAN", name = "Anti-Ban System", val = 1, type = "toggle" },
    { id = "ANTIBAN_DEVICE", name = "Device Spoof", val = 1, type = "toggle" },
    { id = "ANTIBAN_MEMORY", name = "Memory Protection", val = 1, type = "toggle" },
    { id = "ANTIBAN_NETWORK", name = "Network Filter", val = 1, type = "toggle" },
    { id = "ANTIBAN_BEHAVIOR", name = "Behavior Masking", val = 1, type = "toggle" },
}

function _G.AK_GetVal(featureId)
    for _, feature in ipairs(_G.AK_Features) do
        if feature.id == featureId then return feature.val end
    end
    return 0
end

-- ========================================================================
-- ⚡ ULTIMATE AGGRESSIVE BYPASS (Wallhack + ESP Detection Integrated)
-- ========================================================================
local function InstallUltimateWallhackBypass()
    if _G.__ULTIMATE_WH_BYPASS_LOADED then return end

    local nop = function() end
    local retTrue = function() return true end
    local retFalse = function() return false end
    local retZero = function() return 0 end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    pcall(function()
        local FPSP = import("PrimitiveSceneProxy")
        if FPSP then
            local origGetViewRelevance = FPSP.GetViewRelevance
            FPSP.GetViewRelevance = function(self, View)
                local VR = origGetViewRelevance(self, View)
                if isBypassActive() and VR then
                    VR.bRenderCustomDepth = false
                    VR.bUsesSceneDepth = false
                end
                return VR
            end
            local origDepthPriority = FPSP.GetDepthPriorityGroup
            FPSP.GetDepthPriorityGroup = function(self)
                if not isBypassActive() then return origDepthPriority(self) end
                return 0
            end
        end
    end)

    pcall(function()
        local UMesh = import("MeshComponent")
        if UMesh then
            UMesh.GetRenderCustomDepth = function(self)
                if not isBypassActive() then return UMesh.__origGRCD(self) end
                return false
            end
            UMesh.__origGRCD = UMesh.GetRenderCustomDepth
            UMesh.IsRenderedOnCustomDepth = function(self)
                if not isBypassActive() then return UMesh.__origIRCD(self) end
                return false
            end
            UMesh.__origIRCD = UMesh.IsRenderedOnCustomDepth
            UMesh.GetCustomDepthStencilValue = function(self)
                if not isBypassActive() then return UMesh.__origGCDSV(self) end
                return 0
            end
            UMesh.__origGCDSV = UMesh.GetCustomDepthStencilValue
            UMesh.ShouldRender = function(self)
                if not isBypassActive() then return UMesh.__origSR(self) end
                return true
            end
            UMesh.__origSR = UMesh.ShouldRender
            UMesh.IsVisible = function(self)
                if not isBypassActive() then return UMesh.__origIV(self) end
                return true
            end
            UMesh.__origIV = UMesh.IsVisible
        end

        local UPrim = import("PrimitiveComponent")
        if UPrim then
            for _, fn in ipairs({"IsRenderedOnCustomDepth","GetRenderCustomDepth","GetCustomDepthStencilValue","GetCustomDepthStencilWriteMask","GetVisibleFlag"}) do
                local orig = UPrim[fn]
                UPrim["__orig_"..fn] = orig
                UPrim[fn] = function(self, ...)
                    if not isBypassActive() then return orig(self, ...) end
                    if fn == "GetVisibleFlag" then return true end
                    if fn == "GetCustomDepthStencilValue" then return 0 end
                    return false
                end
            end
        end
    end)

    pcall(function()
        local FRHI = import("RHICommandList")
        if FRHI and FRHI.SetDepthState then
            local origSetDepth = FRHI.SetDepthState
            FRHI.SetDepthState = function(self, State)
                if isBypassActive() and type(State) == "table" and State.DepthEnable ~= nil then
                    State.DepthEnable = true
                end
                return origSetDepth(self, State)
            end
        end
    end)

    pcall(function()
        local UGVC = import("GameViewportClient")
        if UGVC and UGVC.Draw then
            local origDraw = UGVC.Draw
            UGVC.Draw = function(self, ...)
                origDraw(self, ...)
                if isBypassActive() and _G.AK_DrawWallhackOverlay then
                    pcall(_G.AK_DrawWallhackOverlay)
                end
            end
        end
    end)

    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        local UMatDyn = import("MaterialInstanceDynamic")
        if UMat then
            UMat.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMat.__origDDT(self) end
                return false
            end
            UMat.__origDDT = UMat.GetDisableDepthTest
            UMat.GetBlendMode = function(self)
                if not isBypassActive() then return UMat.__origBM(self) end
                return 0
            end
            UMat.__origBM = UMat.GetBlendMode
            UMat.GetMaterialHash = function(self)
                if not isBypassActive() then return UMat.__origHash(self) end
                return "FAKE_HASH"
            end
            UMat.__origHash = UMat.GetMaterialHash
            UMat.VerifyMaterial = function(self)
                if not isBypassActive() then return UMat.__origVM(self) end
                return true
            end
            UMat.__origVM = UMat.VerifyMaterial
        end
        if UMatInst then
            UMatInst.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMatInst.__origDDT(self) end
                return false
            end
            UMatInst.__origDDT = UMatInst.GetDisableDepthTest
            UMatInst.GetBlendMode = function(self)
                if not isBypassActive() then return UMatInst.__origBM(self) end
                return 0
            end
            UMatInst.__origBM = UMatInst.GetBlendMode
            UMatInst.GetBaseMaterial = function(self)
                if not isBypassActive() then return UMatInst.__origBM2(self) end
                return nil
            end
            UMatInst.__origBM2 = UMatInst.GetBaseMaterial
        end
        if UMatDyn then
            local oldGetVec = UMatDyn.K2_GetVectorParameterValue
            UMatDyn.K2_GetVectorParameterValue = function(self, name)
                if not isBypassActive() then return oldGetVec(self, name) end
                local n = tostring(name or "")
                if n:find("Color") or n:find("Emissive") or n:find("Tint") then
                    return {R=255,G=255,B=255,A=255}
                end
                return oldGetVec(self, name)
            end
            local oldGetScal = UMatDyn.K2_GetScalarParameterValue
            UMatDyn.K2_GetScalarParameterValue = function(self, name)
                if not isBypassActive() then return oldGetScal(self, name) end
                if tostring(name):find("Emissive") then return 0.0 end
                return oldGetScal(self, name)
            end
        end
    end)

    pcall(function()
        local UObj = import("Object")
        if UObj and UObj.GetObjectsOfClass then
            local oldGet = UObj.GetObjectsOfClass
            UObj.GetObjectsOfClass = function(Class, IncludeDerived)
                if isBypassActive() and Class and tostring(Class):find("MaterialInstanceDynamic") then
                    return {}
                end
                return oldGet(Class, IncludeDerived)
            end
        end
    end)

    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local kc = SubMgr:Get("ClientKernelCheckSubsystem")
            if kc and not kc.__akhooked then
                local origIKC = kc.IsKernelClean
                kc.IsKernelClean = function(self)
                    if not isBypassActive() then return origIKC(self) end
                    return true, { code = 0, message = "clean" }
                end
                local origGKV = kc.GetKernelVersion
                kc.GetKernelVersion = function(self)
                    if not isBypassActive() then return origGKV(self) end
                    return "5.4.0-generic"
                end
                kc.__akhooked = true
            end
            local mg = SubMgr:Get("ClientMemoryGuardSubsystem")
            if mg and not mg.__akhooked then
                local origIMC = mg.IsMemoryClean
                mg.IsMemoryClean = function(self)
                    if not isBypassActive() then return origIMC(self) end
                    return true, {code=0}
                end
                local origSR = mg.ScanResult
                mg.ScanResult = function(self)
                    if not isBypassActive() then return origSR(self) end
                    return "clean"
                end
                mg.__akhooked = true
            end
        end
    end)

    -- Custom mark-manager interception removed for stability.

    pcall(function()
        local MarkMgr = InGameMarkTools and InGameMarkTools.ScreenMarkManager
        if MarkMgr then
            if MarkMgr.GetAllActiveMarks then
                local orig = MarkMgr.GetAllActiveMarks
                MarkMgr.GetAllActiveMarks = function(self, ...)
                    local marks = orig(self, ...)
                    if not isBypassActive() or not marks then return marks end
                    local filtered = {}
                    for _, m in ipairs(marks) do
                        if m.MarkGroupID and not table.contains(ourMarkGroups, m.MarkGroupID) then
                            table.insert(filtered, m)
                        end
                    end
                    return filtered
                end
            end
            if MarkMgr.GetMarkCount then
                local orig = MarkMgr.GetMarkCount
                MarkMgr.GetMarkCount = function(self, ...)
                    local count = orig(self, ...)
                    if isBypassActive() then count = math.max(0, count - #ourMarkGroups) end
                    return count
                end
            end
            if MarkMgr.GetMarksByGroup then
                local orig = MarkMgr.GetMarksByGroup
                MarkMgr.GetMarksByGroup = function(self, groupId)
                    if isBypassActive() and table.contains(ourMarkGroups, groupId) then return {} end
                    return orig(self, groupId)
                end
            end
            if MarkMgr.OnAddMark then MarkMgr.OnAddMark = nop end
            if MarkMgr.OnRemoveMark then MarkMgr.OnRemoveMark = nop end
        end
    end)

    pcall(function()
        if _G.Replay_IsEnemyFrameUIExisted then
            local orig = _G.Replay_IsEnemyFrameUIExisted
            _G.Replay_IsEnemyFrameUIExisted = function(...)
                if isBypassActive() then return false end
                return orig(...)
            end
        end
        if _G.Replay_CreateEnemyFrameUI then
            local orig = _G.Replay_CreateEnemyFrameUI
            _G.Replay_CreateEnemyFrameUI = function(...)
                if isBypassActive() then
                    local backup = _G.ReportEnemyFrameUI or nop
                    _G.ReportEnemyFrameUI = nop
                    local res = orig(...)
                    _G.ReportEnemyFrameUI = backup
                    return res
                end
                return orig(...)
            end
        end
    end)

    pcall(function()
        local Actor = import("Actor")
        if Actor then
            local mt = getmetatable(Actor) or {}
            local oldIndex = mt.__index or function() end
            mt.__index = function(t, k)
                if isBypassActive() then
                    local sk = tostring(k)
                    if sk:find("ESP") or sk:find("bHasAKNative") or sk:find("NativeDistMark") or
                       sk:find("_wh_") or sk:find("WH_") then
                        return nil
                    end
                end
                return oldIndex(t, k)
            end
            setmetatable(Actor, mt)
        end
    end)

    pcall(function()
        local UIHelper = import("UIHelper") or _G.UIHelper
        if UIHelper and UIHelper.GetAllWidgetsOfClass then
            UIHelper.GetAllWidgetsOfClass = function(...) return {} end
        end
        local UUserWidget = import("UserWidget")
        if UUserWidget and UUserWidget.AddToViewport then
            local orig = UUserWidget.AddToViewport
            UUserWidget.AddToViewport = function(self, ...)
                if isBypassActive() and self.ESPWidget then return end
                return orig(self, ...)
            end
        end
    end)

    pcall(function()
        local espReports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "ReportWallhackESP","SendESPData","UploadESPInfo"
        }
        for _, fn in ipairs(espReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname and tostring(pname):lower():match("esp") then return nil end
                return orig(pname, ...)
            end
        end
        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isBypassActive() and rpcName and tostring(rpcName):lower():match("esp") then return end
                return orig(rpcName, ...)
            end
        end
    end)

    _G.__ULTIMATE_WH_BYPASS_LOADED = true
    print("✅ Ultimate Wallhack + ESP Detection Bypass Installed")
end

InstallUltimateWallhackBypass()

-- ========================================================================
-- ⚡ GLOBAL AIMBOT & RECOIL DETECTION BYPASS (Multi-Layer)
-- ========================================================================


-- ========================================================================
-- ⚡ ADVANCED DETECTION BYPASS (Radar, Behavior, DLL, Pak, etc.)
-- ========================================================================
local function InstallAdvancedDetectionBypass()
    if _G.__ADVANCED_BYPASS_LOADED then return end

    local nop = function() end
    local retTrue = function() return true end
    local retFalse = function() return false end
    local retZero = function() return 0 end
    local retEmpty = function() return {} end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    pcall(function()
        local ShootWeaponEntity = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if ShootWeaponEntity and ShootWeaponEntity.Fire then
            local origFire = ShootWeaponEntity.Fire
            ShootWeaponEntity.Fire = function(self, ...)
                if isBypassActive() then
                    -- No spread implementation
                end
                return origFire(self, ...)
            end
        end
        local Actor = import("Actor")
        if Actor and Actor.TakeDamage then
            local origTakeDamage = Actor.TakeDamage
            Actor.TakeDamage = function(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
                if isBypassActive() and DamageEvent and DamageEvent.HitInfo then
                    if DamageEvent.HitInfo.BoneName and tostring(DamageEvent.HitInfo.BoneName):find("head") then
                        if math.random() < 0.3 then
                            DamageEvent.HitInfo.BoneName = "spine_03"
                        end
                    end
                    DamageEvent.HitInfo.Location = {
                        X = DamageEvent.HitInfo.Location.X + (math.random()-0.5)*2,
                        Y = DamageEvent.HitInfo.Location.Y + (math.random()-0.5)*2,
                        Z = DamageEvent.HitInfo.Location.Z + (math.random()-0.5)*2
                    }
                end
                return origTakeDamage(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
            end
        end
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname then
                    local p = tostring(pname):lower()
                    if p:match("position") or p:match("location") or p:match("coord") or
                       p:match("playerpos") or p:match("move") or p:match("teleport") then
                        return nil
                    end
                end
                return orig(pname, ...)
            end
        end
        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isBypassActive() and rpcName then
                    local r = tostring(rpcName):lower()
                    if r:match("position") or r:match("location") or r:match("coord") then
                        return
                    end
                end
                return orig(rpcName, ...)
            end
        end
    end)

    local matchStats = { totalShots = 0, totalHits = 0, headshots = 0, kills = 0 }
    pcall(function()
        local Weapon = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if Weapon and Weapon.Fire then
            local origFire = Weapon.Fire
            Weapon.Fire = function(self, ...)
                if isBypassActive() then matchStats.totalShots = matchStats.totalShots + 1 end
                return origFire(self, ...)
            end
        end
        local Actor = import("Actor")
        if Actor and Actor.TakeDamage then
            local origTakeDamage2 = Actor.TakeDamage
            Actor.TakeDamage = function(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
                if isBypassActive() and EventInstigator == slua_GameFrontendHUD:GetPlayerController() then
                    matchStats.totalHits = matchStats.totalHits + 1
                    if DamageEvent and DamageEvent.HitInfo and DamageEvent.HitInfo.BoneName and
                       tostring(DamageEvent.HitInfo.BoneName):find("head") then
                        matchStats.headshots = matchStats.headshots + 1
                    end
                    if self:IsDead() then matchStats.kills = matchStats.kills + 1 end
                end
                return origTakeDamage2(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
            end
        end
        local GameReportUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GameReportUtils and GameReportUtils.ReportGameResult then
            local origReport = GameReportUtils.ReportGameResult
            GameReportUtils.ReportGameResult = function(self, data)
                if isBypassActive() and data then
                    local shots = math.max(matchStats.totalShots, 1)
                    data.accuracy = math.min(0.65, 0.35 + math.random()*0.15)
                    data.headshotRate = math.min(0.30, 0.10 + math.random()*0.10)
                    data.totalKills = matchStats.kills
                    data.totalShots = shots
                    data.totalHits = math.floor(shots * data.accuracy)
                end
                return origReport(self, data)
            end
        end
        local ShowResult = package.loaded["GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowResultLogic"]
        if ShowResult and ShowResult.ReceiveData then
            local origReceive = ShowResult.ReceiveData
            ShowResult.ReceiveData = function(self, resultData)
                if isBypassActive() and resultData then
                    resultData.Accuracy = math.random(35,50)/100
                    resultData.HeadShotRate = math.random(10,20)/100
                end
                return origReceive(self, resultData)
            end
        end
    end)

    pcall(function()
        if rawget(_G, "IsDebuggerPresent") then _G.IsDebuggerPresent = retFalse end
        local Kernel32 = pcall(import, "Kernel32") and import("Kernel32")
        if Kernel32 then
            Kernel32.IsDebuggerPresent = retFalse
            Kernel32.CheckRemoteDebuggerPresent = retFalse
        end
        if _G.TssSdk then
            _G.TssSdk.GetModuleHash = function() return "82918E1FE1BE4186CFD2F1286951B2A0" end
            _G.TssSdk.VerifyModule = retTrue
            _G.TssSdk.ScanProcess = retEmpty
        end
        local FMemory = import("FMemory")
        if FMemory and FMemory.Memcpy then
            local origMemcpy = FMemory.Memcpy
            FMemory.Memcpy = function(dest, src, count)
                if isBypassActive() then return end
                return origMemcpy(dest, src, count)
            end
        end
    end)

    pcall(function()
        local FileHelper = import("FFileHelper")
        if FileHelper then
            if FileHelper.GetFileSize then
                local orig = FileHelper.GetFileSize
                FileHelper.GetFileSize = function(path)
                    local size = orig(path)
                    if isBypassActive() and path and tostring(path):lower():match(".pak") then
                        return 2000000000
                    end
                    return size
                end
            end
            if FileHelper.SaveStringToFile then
                local origSave = FileHelper.SaveStringToFile
                FileHelper.SaveStringToFile = function(str, path, ...)
                    if isBypassActive() and path and tostring(path):lower():match(".pak") then
                        return true
                    end
                    return origSave(str, path, ...)
                end
            end
        end
        local PakSubsystem = pcall(require, "GameLua.GameCore.Module.Subsystem.PakFileSubsystem") and require("GameLua.GameCore.Module.Subsystem.PakFileSubsystem")
        if PakSubsystem then
            PakSubsystem.CheckPakIntegrity = nop
            PakSubsystem.ReportPakMismatch = nop
        end
    end)

    pcall(function()
        local CharacterMovement = import("CharacterMovementComponent")
        if CharacterMovement then
            local origGetMaxSpeed = CharacterMovement.GetMaxSpeed
            CharacterMovement.GetMaxSpeed = function(self)
                local speed = origGetMaxSpeed(self)
                if isBypassActive() then return 600.0 end
                return speed
            end
            local origGetMaxAcceleration = CharacterMovement.GetMaxAcceleration
            CharacterMovement.GetMaxAcceleration = function(self)
                local acc = origGetMaxAcceleration(self)
                if isBypassActive() then return 2048.0 end
                return acc
            end
        end
    end)

    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        if UMat then
            UMat.GetShaderMap = function(self) return nil end
            UMat.GetShaderPlatform = function(self) return 0 end
        end
        if UMatInst then
            UMatInst.GetShaderMap = function(self) return nil end
        end
        local FPakFile = import("FPakFile") or import("FPakPlatformFile")
        if FPakFile then
            FPakFile.GetPakEntries = function(...) return {} end
            FPakFile.GetPakFolders = function(...) return {} end
            FPakFile.FindFileInPakFiles = function(...) return false end
        end
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isBypassActive() and pname and tostring(pname):lower():match("stat") then return nil end
                return orig(pname, ...)
            end
        end
        local SSMgr = import("ScreenshotManager")
        if SSMgr then
            SSMgr.RequestScreenshot = function(...) return false end
            SSMgr.HasPendingScreenshot = function(...) return false end
        end
    end)

    _G.__ADVANCED_BYPASS_LOADED = true
    print("✅ Advanced Detection Bypass Installed")
end

InstallAdvancedDetectionBypass()

-- ========================================================================
-- ⚡ ENHANCED ANTI-BAN BYPASS SYSTEM (Device ID + Memory + Network + Behavior)
-- ========================================================================
local function InstallEnhancedAntiBanBypass()
    if _G.__ENHANCED_ANTIBAN_LOADED then return end

    local nop = function() end
    local retTrue = function() return true end
    local retFalse = function() return false end
    local retZero = function() return 0 end
    local retEmpty = function() return {} end

    local function isAntiBanActive()
        return _G.AK_GetVal("ANTIBAN") == 1 and not _G._MOD_EXPIRED
    end

    -- ========================================================================
    -- DEVICE ID SPOOFING
    -- ========================================================================
    local function generateFakeId(length)
        local chars = "0123456789ABCDEF"
        local id = ""
        for i = 1, length do
            id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
        end
        return id
    end

    local fakeDeviceID = generateFakeId(32)
    local fakeAndroidID = generateFakeId(16)
    local fakeMac = string.format("%02X:%02X:%02X:%02X:%02X:%02X",
        math.random(0,255), math.random(0,255), math.random(0,255),
        math.random(0,255), math.random(0,255), math.random(0,255))
    local fakeIMEI = "35" .. math.random(100000, 999999) .. math.random(100000, 999999)
    local fakeSerial = generateFakeId(16)

    -- Device ID Override
    pcall(function()
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            if SystemInfo.GetDeviceID or SystemInfo.GetUniqueDeviceId then
                local orig = SystemInfo.GetDeviceID or SystemInfo.GetUniqueDeviceId
                if orig then
                    if SystemInfo.GetDeviceID then
                        SystemInfo.GetDeviceID = function()
                            if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeDeviceID end
                            return orig()
                        end
                    end
                    if SystemInfo.GetUniqueDeviceId then
                        SystemInfo.GetUniqueDeviceId = function()
                            if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeDeviceID end
                            return orig()
                        end
                    end
                end
            end
            if SystemInfo.GetMacAddress then
                local orig = SystemInfo.GetMacAddress
                SystemInfo.GetMacAddress = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeMac end
                    return orig()
                end
            end
            if SystemInfo.GetAndroidId then
                local orig = SystemInfo.GetAndroidId
                SystemInfo.GetAndroidId = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeAndroidID end
                    return orig()
                end
            end
            if SystemInfo.GetIMEI then
                local orig = SystemInfo.GetIMEI
                SystemInfo.GetIMEI = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeIMEI end
                    return orig()
                end
            end
            if SystemInfo.GetDeviceName then
                local orig = SystemInfo.GetDeviceName
                SystemInfo.GetDeviceName = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return "Galaxy S21 Ultra 5G" end
                    return orig()
                end
            end
            if SystemInfo.GetSerial then
                local orig = SystemInfo.GetSerial
                SystemInfo.GetSerial = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeSerial end
                    return orig()
                end
            end
        end
    end)

    -- Android Build Props Spoofing
    pcall(function()
        local Build = import("Build")
        if Build then
            local props = {
                "Fingerprint", "Serial", "Hardware", "Brand", "Model", "Manufacturer", "Product", "Device", "Board"
            }
            for _, prop in ipairs(props) do
                local orig = Build[prop]
                if orig then
                    Build[prop] = function()
                        if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then
                            if prop == "Fingerprint" then return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" end
                            if prop == "Serial" then return fakeSerial end
                            if prop == "Hardware" then return "oriole" end
                            if prop == "Brand" then return "google" end
                            if prop == "Model" then return "Pixel 6" end
                            if prop == "Manufacturer" then return "Google" end
                            if prop == "Product" then return "oriole" end
                            if prop == "Device" then return "oriole" end
                            if prop == "Board" then return "gs101" end
                        end
                        return orig()
                    end
                end
            end
            if Build.VERSION and Build.VERSION.SDK_INT then
                local orig = Build.VERSION.SDK_INT
                Build.VERSION.SDK_INT = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return 33 end
                    return orig()
                end
            end
        end
    end)

    -- TSS SDK Device Info Spoofing
    pcall(function()
        local TssSdk = _G.TssSdk
        if TssSdk then
            if TssSdk.GetDeviceInfo then
                local orig = TssSdk.GetDeviceInfo
                TssSdk.GetDeviceInfo = function()
                    if not (isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1) then return orig() end
                    return {
                        deviceId = fakeDeviceID,
                        androidId = fakeAndroidID,
                        mac = fakeMac,
                        imei = fakeIMEI,
                        serial = fakeSerial,
                        model = "Pixel 6",
                        brand = "google",
                        sdkInt = 33,
                        fingerprint = "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys"
                    }
                end
            end
            if TssSdk.GetFingerprint then
                local orig = TssSdk.GetFingerprint
                TssSdk.GetFingerprint = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then 
                        return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" 
                    end
                    return orig()
                end
            end
            if TssSdk.GetClientID then
                local orig = TssSdk.GetClientID
                TssSdk.GetClientID = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeDeviceID end
                    return orig()
                end
            end
            if TssSdk.GetDeviceId then
                local orig = TssSdk.GetDeviceId
                TssSdk.GetDeviceId = function()
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then return fakeDeviceID end
                    return orig()
                end
            end
        end
    end)

    -- Global Variables Override
    pcall(function()
        if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_DEVICE") == 1 then
            if _G.DeviceID then _G.DeviceID = fakeDeviceID end
            if _G.AndroidID then _G.AndroidID = fakeAndroidID end
            if _G.MacAddress then _G.MacAddress = fakeMac end
            if _G.IMEI then _G.IMEI = fakeIMEI end
            if _G.Serial then _G.Serial = fakeSerial end
        end
    end)

    -- ========================================================================
    -- MEMORY PROTECTION & SCAN EVASION
    -- ========================================================================
    pcall(function()
        -- Memory scan results manipulation
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local memSub = SubMgr:Get("ClientMemoryGuardSubsystem")
            if memSub and not memSub.__antiban_hooked then
                local origScan = memSub.ScanMemory
                if origScan then
                    memSub.ScanMemory = function(self, ...)
                        if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_MEMORY") == 1 then
                            return { result = "clean", violations = {}, threatLevel = 0 }
                        end
                        return origScan(self, ...)
                    end
                end
                local origCheck = memSub.CheckMemoryIntegrity
                if origCheck then
                    memSub.CheckMemoryIntegrity = function(self, ...)
                        if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_MEMORY") == 1 then
                            return true, { status = "clean" }
                        end
                        return origCheck(self, ...)
                    end
                end
                memSub.__antiban_hooked = true
            end

            local kernelSub = SubMgr:Get("ClientKernelCheckSubsystem")
            if kernelSub and not kernelSub.__antiban_hooked then
                local origKernel = kernelSub.CheckKernel
                if origKernel then
                    kernelSub.CheckKernel = function(self, ...)
                        if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_MEMORY") == 1 then
                            return true, { version = "5.4.0-generic", clean = true }
                        end
                        return origKernel(self, ...)
                    end
                end
                kernelSub.__antiban_hooked = true
            end
        end

        -- Memory scanning library overrides
        local MemoryLib = import("Memory")
        if MemoryLib then
            if MemoryLib.Scan then
                local orig = MemoryLib.Scan
                MemoryLib.Scan = function(...)
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_MEMORY") == 1 then return {} end
                    return orig(...)
                end
            end
            if MemoryLib.Read then
                local orig = MemoryLib.Read
                MemoryLib.Read = function(...)
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_MEMORY") == 1 then return nil end
                    return orig(...)
                end
            end
        end

        -- Hook integrity checks
        local IntegrityCheck = import("IntegrityCheck")
        if IntegrityCheck then
            IntegrityCheck.Verify = retTrue
            IntegrityCheck.Check = retTrue
            IntegrityCheck.Validate = retTrue
        end
    end)

    -- ========================================================================
    -- NETWORK FILTERING
    -- ========================================================================
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            NetUtil.SendPacket = function(pname, ...)
                if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_NETWORK") == 1 and pname then
                    local p = tostring(pname):lower()
                    -- Block security-related packets
                    if p:match("security") or p:match("anticheat") or p:match("report") or
                       p:match("violation") or p:match("integrity") or p:match("scan") or
                       p:match("detect") or p:match("ban") or p:match("kick") or
                       p:match("deviceinfo") or p:match("fingerprint") or p:match("hardware") then
                        return nil
                    end
                end
                return orig(pname, ...)
            end
        end

        if _G.SendRPC then
            local orig = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_NETWORK") == 1 and rpcName then
                    local r = tostring(rpcName):lower()
                    if r:match("security") or r:match("anticheat") or r:match("report") or
                       r:match("violation") or r:match("integrity") or r:match("scan") then
                        return
                    end
                end
                return orig(rpcName, ...)
            end
        end

        -- HTTP/WebSocket filtering
        local Http = import("Http")
        if Http then
            if Http.Request then
                local orig = Http.Request
                Http.Request = function(url, ...)
                    if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_NETWORK") == 1 and url then
                        local u = tostring(url):lower()
                        if u:match("security") or u:match("anticheat") or u:match("report") or
                           u:match("tss") or u:match("ban") then
                            return nil
                        end
                    end
                    return orig(url, ...)
                end
            end
        end
    end)

    -- ========================================================================
    -- BEHAVIOR MASKING
    -- ========================================================================
    pcall(function()
        -- Match statistics manipulation
        local matchStats = {
            totalShots = 0,
            totalHits = 0,
            headshots = 0,
            kills = 0,
            deaths = 0,
            damageDealt = 0,
            damageTaken = 0,
            movementDistance = 0,
            aimSnapCount = 0
        }

        local Weapon = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if Weapon and Weapon.Fire then
            local origFire = Weapon.Fire
            Weapon.Fire = function(self, ...)
                if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 then
                    matchStats.totalShots = matchStats.totalShots + 1
                end
                return origFire(self, ...)
            end
        end

        local Actor = import("Actor")
        if Actor and Actor.TakeDamage then
            local origTakeDamage = Actor.TakeDamage
            Actor.TakeDamage = function(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
                if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 then
                    if EventInstigator == slua_GameFrontendHUD:GetPlayerController() then
                        matchStats.totalHits = matchStats.totalHits + 1
                        matchStats.damageDealt = matchStats.damageDealt + (DamageAmount or 0)
                        if DamageEvent and DamageEvent.HitInfo and DamageEvent.HitInfo.BoneName and
                           tostring(DamageEvent.HitInfo.BoneName):find("head") then
                            matchStats.headshots = matchStats.headshots + 1
                        end
                        if self:IsDead() then matchStats.kills = matchStats.kills + 1 end
                    end
                end
                return origTakeDamage(self, DamageAmount, DamageEvent, EventInstigator, DamageCauser)
            end
        end

        -- Report generation with masked statistics
        local GameReportUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GameReportUtils and GameReportUtils.ReportGameResult then
            local origReport = GameReportUtils.ReportGameResult
            GameReportUtils.ReportGameResult = function(self, data)
                if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 and data then
                    local shots = math.max(matchStats.totalShots, 1)
                    -- Mask accuracy to look normal (35-55%)
                    data.accuracy = math.min(0.55, 0.35 + math.random()*0.15)
                    -- Mask headshot rate to look normal (8-20%)
                    data.headshotRate = math.min(0.20, 0.08 + math.random()*0.10)
                    -- Mask K/D ratio
                    local kd = math.min(3.0, 1.0 + math.random()*1.5)
                    data.kdRatio = kd
                    -- Ensure stats look human
                    data.totalKills = math.min(matchStats.kills, math.floor(shots * 0.15))
                    data.totalShots = shots
                    data.totalHits = math.floor(shots * data.accuracy)
                end
                return origReport(self, data)
            end
        end

        -- Battle result manipulation
        local ShowResult = package.loaded["GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowResultLogic"]
        if ShowResult and ShowResult.ReceiveData then
            local origReceive = ShowResult.ReceiveData
            ShowResult.ReceiveData = function(self, resultData)
                if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 and resultData then
                    resultData.Accuracy = math.random(35,50)/100
                    resultData.HeadShotRate = math.random(8,18)/100
                    resultData.KDRatio = math.random(10,25)/10
                end
                return origReceive(self, resultData)
            end
        end

        -- Aim tracking data masking
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local aimSub = SubMgr:Get("ClientAimTrackingSubsystem")
            if aimSub and not aimSub.__antiban_hooked then
                local origGetAimData = aimSub.GetAimData
                if origGetAimData then
                    aimSub.GetAimData = function(self, ...)
                        if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 then
                            return {
                                accuracy = math.random(40, 60),
                                headshotRate = math.random(10, 25),
                                trackingTime = math.random(100, 300),
                                aimLockCount = 0,
                                snapCount = math.random(0, 3)
                            }
                        end
                        return origGetAimData(self, ...)
                    end
                end
                aimSub.__antiban_hooked = true
            end
        end

        -- Block behavior analysis reports
        local behaviorReports = {
            "ReportPlayerBehavior", "ReportBehaviorScore", "UploadBehaviorData",
            "SendBehaviorStats", "ReportMovementPattern", "ReportAimPattern",
            "OnBehaviorAnomalyDetected", "OnSuspiciousActivity", "ReportSuspiciousActivity"
        }
        for _, fn in ipairs(behaviorReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    -- ========================================================================
    -- ADDITIONAL ANTI-BAN PROTECTIONS
    -- ========================================================================
    pcall(function()
        -- Block screenshot/screen capture detection
        local ScreenshotManager = import("ScreenshotManager")
        if ScreenshotManager then
            ScreenshotManager.RequestScreenshot = retFalse
            ScreenshotManager.HasPendingScreenshot = retFalse
            ScreenshotManager.CaptureScreenshot = retFalse
            ScreenshotManager.SaveScreenshot = retFalse
        end

        -- Block file integrity checks
        local FileCheck = import("FileCheck")
        if FileCheck then
            FileCheck.VerifyFile = retTrue
            FileCheck.CheckHash = retTrue
            FileCheck.ValidatePak = retTrue
        end

        -- Block debug detection
        if rawget(_G, "IsDebuggerPresent") then _G.IsDebuggerPresent = retFalse end
        if rawget(_G, "CheckRemoteDebugger") then _G.CheckRemoteDebugger = retFalse end

        -- Block process scanning
        local Process = import("Process")
        if Process then
            Process.GetProcessList = retEmpty
            Process.ScanProcess = retEmpty
            Process.FindProcess = retFalse
        end

        -- Block DLL/module enumeration
        local ModuleManager = import("ModuleManager")
        if ModuleManager then
            ModuleManager.GetLoadedModules = retEmpty
            ModuleManager.GetModuleInfo = retFalse
            ModuleManager.EnumModules = retEmpty
        end

        -- Block registry checks (Windows)
        local Registry = import("Registry")
        if Registry then
            Registry.GetValue = retFalse
            Registry.EnumKeys = retEmpty
        end

        -- Block timing analysis
        local origClock = os.clock
        os.clock = function()
            local t = origClock()
            if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 then
                -- Add tiny random jitter to timing to avoid pattern detection
                return t + (math.random() - 0.5) * 0.001
            end
            return t
        end

        local origTime = os.time
        os.time = function(t)
            local tm = origTime(t)
            if isAntiBanActive() and _G.AK_GetVal("ANTIBAN_BEHAVIOR") == 1 then
                -- Slight time jitter
                return tm + math.random(-1, 1)
            end
            return tm
        end
    end)

    _G.__ENHANCED_ANTIBAN_LOADED = true
    print("✅ Enhanced Anti-Ban Bypass System Installed (Device + Memory + Network + Behavior)")
end

InstallEnhancedAntiBanBypass()

-- ========================================================================
-- ⚡ DEVICE ID / BAN BYPASS (Legacy - Keep for compatibility)
-- ========================================================================
local function InstallDeviceBanBypass()
    if _G.__DEVICE_BAN_BYPASS_LOADED then return end

    local nop = function() end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    local function generateFakeId(length)
        local chars = "0123456789ABCDEF"
        local id = ""
        for i = 1, length do
            id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
        end
        return id
    end

    local fakeDeviceID = generateFakeId(32)
    local fakeAndroidID = generateFakeId(16)
    local fakeMac = string.format("%02X:%02X:%02X:%02X:%02X:%02X",
        math.random(0,255), math.random(0,255), math.random(0,255),
        math.random(0,255), math.random(0,255), math.random(0,255))
    local fakeIMEI = "35" .. math.random(100000, 999999) .. math.random(100000, 999999)

    pcall(function()
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            if SystemInfo.GetDeviceID or SystemInfo.GetUniqueDeviceId then
                local orig = SystemInfo.GetDeviceID or SystemInfo.GetUniqueDeviceId
                if orig then
                    if SystemInfo.GetDeviceID then
                        SystemInfo.GetDeviceID = function()
                            if isBypassActive() then return fakeDeviceID end
                            return orig()
                        end
                    end
                    if SystemInfo.GetUniqueDeviceId then
                        SystemInfo.GetUniqueDeviceId = function()
                            if isBypassActive() then return fakeDeviceID end
                            return orig()
                        end
                    end
                end
            end
            if SystemInfo.GetMacAddress then
                local orig = SystemInfo.GetMacAddress
                SystemInfo.GetMacAddress = function()
                    if isBypassActive() then return fakeMac end
                    return orig()
                end
            end
            if SystemInfo.GetAndroidId then
                local orig = SystemInfo.GetAndroidId
                SystemInfo.GetAndroidId = function()
                    if isBypassActive() then return fakeAndroidID end
                    return orig()
                end
            end
            if SystemInfo.GetIMEI then
                local orig = SystemInfo.GetIMEI
                SystemInfo.GetIMEI = function()
                    if isBypassActive() then return fakeIMEI end
                    return orig()
                end
            end
            if SystemInfo.GetDeviceName then
                local orig = SystemInfo.GetDeviceName
                SystemInfo.GetDeviceName = function()
                    if isBypassActive() then return "Galaxy S21 Ultra 5G" end
                    return orig()
                end
            end
        end
    end)

    pcall(function()
        local Build = import("Build")
        if Build then
            local props = {
                "Fingerprint", "Serial", "Hardware", "Brand", "Model", "Manufacturer", "Product", "Device", "Board"
            }
            for _, prop in ipairs(props) do
                local orig = Build[prop]
                if orig then
                    Build[prop] = function()
                        if isBypassActive() then
                            if prop == "Fingerprint" then return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" end
                            if prop == "Serial" then return "R5CT1234567" end
                            if prop == "Hardware" then return "oriole" end
                            if prop == "Brand" then return "google" end
                            if prop == "Model" then return "Pixel 6" end
                            if prop == "Manufacturer" then return "Google" end
                            if prop == "Product" then return "oriole" end
                            if prop == "Device" then return "oriole" end
                            if prop == "Board" then return "gs101" end
                        end
                        return orig()
                    end
                end
            end
            if Build.VERSION and Build.VERSION.SDK_INT then
                local orig = Build.VERSION.SDK_INT
                Build.VERSION.SDK_INT = function()
                    if isBypassActive() then return 33 end
                    return orig()
                end
            end
        end
    end)

    pcall(function()
        local TssSdk = _G.TssSdk
        if TssSdk then
            if TssSdk.GetDeviceInfo then
                local orig = TssSdk.GetDeviceInfo
                TssSdk.GetDeviceInfo = function()
                    if not isBypassActive() then return orig() end
                    return {
                        deviceId = fakeDeviceID,
                        androidId = fakeAndroidID,
                        mac = fakeMac,
                        imei = fakeIMEI,
                        model = "Pixel 6",
                        brand = "google",
                        sdkInt = 33,
                        fingerprint = "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys"
                    }
                end
            end
            if TssSdk.GetFingerprint then
                local orig = TssSdk.GetFingerprint
                TssSdk.GetFingerprint = function()
                    if isBypassActive() then return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" end
                    return orig()
                end
            end
            if TssSdk.GetClientID then
                local orig = TssSdk.GetClientID
                TssSdk.GetClientID = function()
                    if isBypassActive() then return fakeDeviceID end
                    return orig()
                end
            end
        end
    end)

    pcall(function()
        if _G.DeviceID then _G.DeviceID = fakeDeviceID end
        if _G.AndroidID then _G.AndroidID = fakeAndroidID end
        if _G.MacAddress then _G.MacAddress = fakeMac end
        if _G.IMEI then _G.IMEI = fakeIMEI end
    end)

    _G.__DEVICE_BAN_BYPASS_LOADED = true
    print("✅ Device ID / Ban Bypass Installed (Legacy)")
end

InstallDeviceBanBypass()

-- ========================================================================
-- ⚡ ENEMY COUNTER (Distance-based enemy detection with bot/real breakdown)
-- ========================================================================
_G.ENEMY_COUNTER_TIMER = nil

function _G.EnemyCounterLoop()
    if _G.AK_GetVal("ENEMY_COUNTER") ~= 1 then return end

    local player = GameplayData and GameplayData.GetPlayerCharacter()
    if not slua.isValid(player) then return end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not slua.isValid(pc) then return end

    local hud = pc:GetHUD()
    if not slua.isValid(hud) then return end

    local myTeamId = player.TeamID or 0
    local myPos = player:K2_GetActorLocation()
    if not myPos then return end

    local totalEnemies = 0
    local botCount = 0
    local realCount = 0
    local MAX_DIST_SQ = 900000000

    local allPawns = Game:GetAllPlayerPawns() or {}
    for _, pawn in pairs(allPawns) do
        if slua.isValid(pawn) and pawn ~= player then
            local pawnTeam = pawn.TeamID or 0
            if pawnTeam ~= myTeamId then
                local pos = pawn:K2_GetActorLocation()
                if pos then
                    local dx = pos.X - myPos.X
                    local dy = pos.Y - myPos.Y
                    local dz = pos.Z - myPos.Z
                    if dx*dx + dy*dy + dz*dz <= MAX_DIST_SQ then
                        totalEnemies = totalEnemies + 1
                        local isBot = false
                        pcall(function()
                            isBot = Game:IsAI(pawn)
                        end)
                        if isBot then
                            botCount = botCount + 1
                        else
                            realCount = realCount + 1
                        end
                    end
                end
            end
        end
    end

    -- Center enemy-counter text removed; counting logic is kept intact.
end

function _G.StartEnemyCounter()
    if _G.ENEMY_COUNTER_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(_G.ENEMY_COUNTER_TIMER) end
        end)
        _G.ENEMY_COUNTER_TIMER = nil
    end

    if _G.AK_GetVal("ENEMY_COUNTER") ~= 1 then return false end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        _G.ENEMY_COUNTER_TIMER = pc:AddGameTimer(1.0, true, function()
            pcall(_G.EnemyCounterLoop)
        end)
        print("[ENEMY COUNTER] ✅ Started")
        return true
    end
    return false
end

function _G.StopEnemyCounter()
    if _G.ENEMY_COUNTER_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(_G.ENEMY_COUNTER_TIMER) end
        end)
        _G.ENEMY_COUNTER_TIMER = nil
        print("[ENEMY COUNTER] Stopped")
    end
end

-- ========================================================================
-- ORIGINAL DISTANCE MARKER & ESP SYSTEM
-- ========================================================================
-- ========================================================================
-- DISTANCE MARKER SYSTEM DISABLED
-- ========================================================================
-- The custom 9999 QuickSign marker system created extra map/UI marks and
-- could overload the in-game mark manager. Keep the ESP pipeline alive,
-- but never create a custom marker.
local distanceMarkerConfig = nil

local function InitDistanceMarkerSystem()
    return
end

local function createDistanceMarker(enemy)
    return
end

local function removeDistanceMarker(enemy)
    if enemy then
        enemy.NativeDistMark = nil
        enemy.bHasAKNativeMapMarker = false
    end
end

local function cleanupDeadEnemyMarks()
    return
end

local function processEnemyMapESP(enemy, localPlayer, isMapESPEnabled)
    if _G._MOD_EXPIRED then return end
    if not slua.isValid(enemy) or enemy == localPlayer or enemy.TeamID == localPlayer.TeamID then return end

    local isDead = false
    pcall(function()
        if type(enemy.IsDead) == "function" then isDead = enemy:IsDead()
        elseif enemy.bIsDead then isDead = true end
        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isDead = true end
    end)

    if not isDead then
        if isMapESPEnabled == 1 then
            if not enemy.bHasAKNativeMapMarker then
                createDistanceMarker(enemy)
                enemy.bHasAKNativeMapMarker = true
            end
        else
            if enemy.bHasAKNativeMapMarker then
                removeDistanceMarker(enemy)
                enemy.bHasAKNativeMapMarker = false
            end
        end
    else
        if enemy.bHasAKNativeMapMarker then
            removeDistanceMarker(enemy)
            enemy.bHasAKNativeMapMarker = false
        end
    end
end

function ApplyHardAimbot()
    if not CheckExpiration() then return end
    pcall(function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end

        local char = pc:GetPlayerCharacterSafety()
        if not slua.isValid(char) then return end

        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end

        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end

        local entity = weapon.ShootWeaponEntityComp
        if not slua.isValid(entity) then return end

        entity.RecoilKickADS = 0.0
        entity.GameDeviationFactor = 0.001
        entity.GameDeviationAccuracy = 0.001

        if entity.AutoAimingConfig then
            for _, range in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[range]
                if cfg then
                    cfg.Speed = 8.0
                    cfg.RangeRate = 8.0
                    cfg.SpeedRate = 8.0
                    cfg.RangeRateSight = 6.0
                    cfg.SpeedRateSight = 6.0
                    cfg.CrouchRate = 7.0
                    cfg.ProneRate = 7.0
                    cfg.DyingRate = 0
                    cfg.adsorbMaxRange = 300
                    cfg.adsorbMinRange = 10
                    cfg.adsorbMinAttenuationDis = 50
                    cfg.adsorbMaxAttenuationDis = 10000
                    cfg.adsorbActiveMinRange = 10
                end
            end
            entity.AutoAimingConfig = entity.AutoAimingConfig
        end

        pcall(function()
            local aimComp = char.BP_AutoAimingComponent_C or char.BP_AutoAimingComponent or char.AutoAimingComponent
            if slua.isValid(aimComp) and aimComp.Bones then
                pcall(function() aimComp.Bones[0] = "spine_03" end)
                pcall(function() aimComp.Bones[1] = "spine_03" end)
                pcall(function() aimComp.Bones[2] = "spine_03" end)
                pcall(function() aimComp.Bones:Set(0, "spine_03") end)
                pcall(function() aimComp.Bones:Set(1, "spine_03") end)
                pcall(function() aimComp.Bones:Set(2, "spine_03") end)
            end
        end)
    end)
end

-- ========================================================================
-- CHEST AIMBOT: moving enemies within 100m, ignores knocked/downed targets
-- ========================================================================
local CHEST_AIM_MAX_DISTANCE = 10000.0 -- 100 meters in UE centimeters
local CHEST_AIM_MIN_SPEED = 60.0       -- moving target threshold (cm/s)
local CHEST_AIM_INTERVAL = 0.025        -- 20 updates/sec (stability)
local CHEST_AIM_LEAD_MAX = 0.24        -- seconds of movement prediction

-- Prefer actual upper-torso bones; never use the head/neck here.
local CHEST_AIM_BONES = {
    "spine_03",
    "spine_02",
    "upper_chest",
    "chest",
    "spine_01"
}

local function GetChestAimLocation(character)
    if not character or not slua.isValid(character) then return nil end

    local mesh = nil
    pcall(function()
        mesh = PlayerMapMarker.GetCharacterMesh(character)
    end)
    if not mesh or not slua.isValid(mesh) then return nil end

    for _, boneName in ipairs(CHEST_AIM_BONES) do
        local loc = nil
        pcall(function()
            if mesh.GetSocketLocation then
                loc = mesh:GetSocketLocation(boneName)
            elseif mesh.GetBoneLocation then
                loc = mesh:GetBoneLocation(boneName)
            end
        end)
        if loc then return loc end
    end

    return nil
end

local function GetCharacterVelocity(character)
    local v = nil
    pcall(function()
        if character.GetVelocity then
            v = character:GetVelocity()
        elseif character.Velocity then
            v = character.Velocity
        end
    end)
    if not v then return {X=0, Y=0, Z=0} end
    return {X=v.X or 0, Y=v.Y or 0, Z=v.Z or 0}
end

local function GetCharacterSpeed(character)
    local v = GetCharacterVelocity(character)
    return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
end

local function IsKnockedOrDowned(character)
    if not character or not slua.isValid(character) then return true end

    local knocked = false
    pcall(function()
        if type(character.IsKnocked) == "function" then
            knocked = character:IsKnocked()
        elseif type(character.IsDowned) == "function" then
            knocked = character:IsDowned()
        elseif character.bIsKnocked ~= nil then
            knocked = character.bIsKnocked
        elseif character.bIsDowned ~= nil then
            knocked = character.bIsDowned
        elseif character.bKnocked ~= nil then
            knocked = character.bKnocked
        end

        if character.bIsDead then knocked = true end
        if type(character.IsDead) == "function" and character:IsDead() then
            knocked = true
        end
    end)

    return knocked == true
end

local function GetAimOrigin(pc, localPlayer)
    local origin = nil

    -- Camera position prevents the pitch from being calculated from the
    -- character's feet/body, which can make the aim appear above the target.
    pcall(function()
        local cam = pc.PlayerCameraManager
        if cam and cam.GetCameraLocation then
            origin = cam:GetCameraLocation()
        end
    end)

    if not origin then
        pcall(function()
            origin = localPlayer:K2_GetActorLocation()
        end)
    end

    return origin
end

local function GetProjectileSpeed(pc)
    local speed = 90000.0 -- safe fallback: 900 m/s in UE cm/s

    pcall(function()
        local char = pc:GetPlayerCharacterSafety()
        if not char then return end
        local wm = char.WeaponManagerComponent
        if not wm then return end
        local weapon = wm.CurrentWeaponReplicated
        if not weapon then return end
        local entity = weapon.ShootWeaponEntityComp
        if not entity then return end

        local candidates = {
            entity.BulletFireSpeed,
            entity.BulletSpeed,
            entity.ProjectileSpeed,
            entity.MuzzleVelocity
        }

        for _, v in ipairs(candidates) do
            if type(v) == "number" and v > 1000 then
                speed = v
                break
            end
        end
    end)

    return speed
end

local function ChestAimbotTick()
    if not CheckExpiration() then return end
    if _G.AK_GetVal("AIMBOT") ~= 1 then return end

    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end

        local localPlayer = GameplayData and GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPlayer) then return end

        local myPos = GetAimOrigin(pc, localPlayer)
        if not myPos then return end

        local enemies = GameplayData.GetAllPlayerCharacters and
                        GameplayData.GetAllPlayerCharacters() or {}

        local bestTarget = nil
        local bestChest = nil
        local bestDistSq = CHEST_AIM_MAX_DISTANCE * CHEST_AIM_MAX_DISTANCE

        for _, enemy in pairs(enemies) do
            if slua.isValid(enemy) and enemy ~= localPlayer and
               not IsKnockedOrDowned(enemy) then

                local sameTeam = false
                pcall(function()
                    sameTeam = (enemy.TeamID ~= nil and localPlayer.TeamID ~= nil and
                                enemy.TeamID == localPlayer.TeamID)
                end)

                if not sameTeam then
                    local speed = GetCharacterSpeed(enemy)

                    -- Moving/running targets only.
                    if speed >= CHEST_AIM_MIN_SPEED then
                        local enemyPos = nil
                        pcall(function()
                            enemyPos = enemy:K2_GetActorLocation()
                        end)

                        local chest = GetChestAimLocation(enemy)

                        if enemyPos and chest then
                            local dx = (enemyPos.X or 0) - (myPos.X or 0)
                            local dy = (enemyPos.Y or 0) - (myPos.Y or 0)
                            local dz = (enemyPos.Z or 0) - (myPos.Z or 0)
                            local distSq = dx*dx + dy*dy + dz*dz

                            if distSq <= bestDistSq then
                                bestTarget = enemy
                                bestChest = chest
                                bestDistSq = distSq
                            end
                        end
                    end
                end
            end
        end

        if not bestTarget or not bestChest then return end

        local distance = math.sqrt(bestDistSq)
        local projectileSpeed = GetProjectileSpeed(pc)

        -- Lead only the target's current movement. This compensates for
        -- travel time so a running target is not left behind.
        local leadTime = distance / math.max(projectileSpeed, 1.0)
        if leadTime > CHEST_AIM_LEAD_MAX then
            leadTime = CHEST_AIM_LEAD_MAX
        elseif leadTime < 0 then
            leadTime = 0
        end

        local vel = GetCharacterVelocity(bestTarget)
        local aimX = (bestChest.X or 0) + vel.X * leadTime
        local aimY = (bestChest.Y or 0) + vel.Y * leadTime
        local verticalLead = math.max(-35.0, math.min(35.0, vel.Z * leadTime))
        local aimZ = (bestChest.Z or 0) + verticalLead

        -- Keep the aim on the torso plane; do not raise it toward the head.
        local dx = aimX - (myPos.X or 0)
        local dy = aimY - (myPos.Y or 0)
        local dz = aimZ - (myPos.Z or 0)

        local horizontal = math.sqrt(dx*dx + dy*dy)
        if horizontal < 0.001 then return end

        local yaw = math.deg(math.atan2(dy, dx))
        local pitch = math.deg(math.atan2(dz, horizontal))
        -- Hard cap the upward pitch adjustment to avoid snapping over the head.
        if pitch > 55.0 then pitch = 55.0 end

        pcall(function()
            if pc.SetControlRotation then
                pc:SetControlRotation({Pitch=pitch, Yaw=yaw, Roll=0})
            end
        end)
    end)
end

local CHEST_AIM_TIMER = nil
local function StartChestAimbot()
    if CHEST_AIM_TIMER then return end

    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) and pc.AddGameTimer then
            CHEST_AIM_TIMER = pc:AddGameTimer(
                CHEST_AIM_INTERVAL,
                true,
                function()
                    pcall(ChestAimbotTick)
                end
            )
        end
    end)
end

-- ========================================================================
-- MATERIAL EVASION BYPASS
-- ========================================================================
local function activate_material_evasion()
    if _G._MATERIAL_GETTERS_HOOKED then return end
    pcall(function()
        local UMaterial = import("Material")
        local UMaterialInstance = import("MaterialInstance")
        local UMaterialInstanceDynamic = import("MaterialInstanceDynamic")
        local UPrimitiveComponent = import("PrimitiveComponent")
        local UMeshComponent = import("MeshComponent")

        if UMaterial then
            UMaterial.GetDisableDepthTest = function() return false end
            UMaterial.GetBlendMode = function() return 0 end
            UMaterial.GetMaterialHash = function() return "FAKE_HASH" end
            UMaterial.VerifyMaterial = function() return true end
        end
        if UMaterialInstance then
            UMaterialInstance.GetDisableDepthTest = function() return false end
            UMaterialInstance.GetBlendMode = function() return 0 end
            UMaterialInstance.GetBaseMaterial = function() return nil end
        end
        if UMaterialInstanceDynamic then
            local oldVec = UMaterialInstanceDynamic.K2_GetVectorParameterValue
            UMaterialInstanceDynamic.K2_GetVectorParameterValue = function(self, name)
                local n = tostring(name)
                if n:find("Color") or n:find("Emissive") then return {R=0,G=255,B=255,A=255} end
                return oldVec(self, name)
            end
            local oldScal = UMaterialInstanceDynamic.K2_GetScalarParameterValue
            UMaterialInstanceDynamic.K2_GetScalarParameterValue = function(self, name)
                if tostring(name):find("Emissive") then return 0.0 end
                return oldScal(self, name)
            end
            UMaterialInstanceDynamic.GetFullName = function() return "DefaultMaterial" end
        end
        if UPrimitiveComponent then
            UPrimitiveComponent.IsRenderedOnCustomDepth = function() return false end
            UPrimitiveComponent.GetRenderCustomDepth = function() return false end
            UPrimitiveComponent.GetCustomDepthStencilValue = function() return 0 end
            UPrimitiveComponent.GetCustomDepthStencilWriteMask = function() return 0 end
            UPrimitiveComponent.GetVisibleFlag = function() return true end
        end
        if UMeshComponent then
            UMeshComponent.ShouldRender = function() return true end
            UMeshComponent.GetShouldRender = function() return true end
            UMeshComponent.IsVisible = function() return true end
        end
        local UObject = import("Object")
        if UObject and UObject.GetObjectsOfClass then
            local oldGet = UObject.GetObjectsOfClass
            UObject.GetObjectsOfClass = function(Class, IncludeDerived)
                if Class and tostring(Class):find("MaterialInstanceDynamic") then return {} end
                return oldGet(Class, IncludeDerived)
            end
        end
    end)
    _G._MATERIAL_GETTERS_HOOKED = true
end

activate_material_evasion()

-- ========================================================================
-- ⚡ ESP V2 SYSTEM (RedBoxOverlay + PlayerMapMarker)
-- ========================================================================
local PlayerMapMarker = {}
local RedBoxOverlay = {
    bActive = false, MainContainer = nil, WidgetSlot = nil,
    TextBlockPlayer = nil, TextBlockBot = nil,
    Width = 260, Height = 25, OffsetY = 10,
    PlayerCount = 0, BotCount = 0, FontSize = 14, TextScaleValue = 1.0,
    NumLayers = 50, Red = 1.0, Green = 1.0, Blue = 1.0, LayerAlpha = 0.06,
    _CachedTextPlayer = "", _CachedTextBot = "", _CachedPosVec = nil
}

function RedBoxOverlay.Create()
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return true end

    local ParentCanvas = PlayerMapMarker.ESPCanvas
    if not ParentCanvas or not slua.isValid(ParentCanvas) then
        if not PlayerMapMarker.InitESPCanvas() then return false end
        ParentCanvas = PlayerMapMarker.ESPCanvas
    end
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end

    local Container = nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
    if not Container or not slua.isValid(Container) then return false end

    local FLinearColor = import("LinearColor") or FLinearColor
    local FVector2D = import("Vector2D") or FVector2D
    local color = FLinearColor(RedBoxOverlay.Red, RedBoxOverlay.Green, RedBoxOverlay.Blue, RedBoxOverlay.LayerAlpha)
    local numLayers = RedBoxOverlay.NumLayers
    local totalWidth = RedBoxOverlay.Width

    for i = 1, numLayers do
        local progress = (i / numLayers) ^ 1.15
        local layerWidth = progress * totalWidth
        local layerX = (totalWidth - layerWidth) / 2.0
        local border = nil
        pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
        if border and slua.isValid(border) then
            pcall(function()
                border:SetBrushColor(color)
                border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local slot = Container:AddChildToCanvas(border)
            if slot then
                slot:SetPosition(FVector2D(layerX, 0))
                slot:SetSize(FVector2D(layerWidth, RedBoxOverlay.Height))
            end
        end
    end

    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    local txtPlayer = nil
    pcall(function() txtPlayer = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtPlayer and slua.isValid(txtPlayer) then
        pcall(function()
            local strText = string.format("Player: %d", RedBoxOverlay.PlayerCount)
            txtPlayer:SetText(strText)
            RedBoxOverlay._CachedTextPlayer = strText
            local redLinear = FLinearColor(1.0, 0.0, 0.0, 1.0)
            if FSlateColor then txtPlayer:SetColorAndOpacity(FSlateColor(redLinear)) else txtPlayer:SetColorAndOpacity(redLinear) end
            if txtPlayer.Font then
                local font = txtPlayer.Font
                font.Size = RedBoxOverlay.FontSize
                txtPlayer.Font = font
            end
            txtPlayer:SetRenderScale(FVector2D(RedBoxOverlay.TextScaleValue, RedBoxOverlay.TextScaleValue))
            txtPlayer:SetRenderTransformPivot(FVector2D(0.5, 0.5))
            txtPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local txtSlot1 = Container:AddChildToCanvas(txtPlayer)
        if txtSlot1 then
            pcall(function()
                txtSlot1:SetAutoSize(true)
                txtSlot1:SetAlignment(FVector2D(0.5, 0.5))
                txtSlot1:SetPosition(FVector2D(totalWidth * 0.35, RedBoxOverlay.Height * 0.5))
                txtSlot1:SetZOrder(1000)
            end)
        end
        RedBoxOverlay.TextBlockPlayer = txtPlayer
    end

    local txtBot = nil
    pcall(function() txtBot = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtBot and slua.isValid(txtBot) then
        pcall(function()
            local strText = string.format("Bot: %d", RedBoxOverlay.BotCount)
            txtBot:SetText(strText)
            RedBoxOverlay._CachedTextBot = strText
            local greenLinear = FLinearColor(1.0, 0.0, 1.0, 1.0)
            if FSlateColor then txtBot:SetColorAndOpacity(FSlateColor(greenLinear)) else txtBot:SetColorAndOpacity(greenLinear) end
            if txtBot.Font then
                local font = txtBot.Font
                font.Size = RedBoxOverlay.FontSize
                txtBot.Font = font
            end
            txtBot:SetRenderScale(FVector2D(RedBoxOverlay.TextScaleValue, RedBoxOverlay.TextScaleValue))
            txtBot:SetRenderTransformPivot(FVector2D(0.5, 0.5))
            txtBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local txtSlot2 = Container:AddChildToCanvas(txtBot)
        if txtSlot2 then
            pcall(function()
                txtSlot2:SetAutoSize(true)
                txtSlot2:SetAlignment(FVector2D(0.5, 0.5))
                txtSlot2:SetPosition(FVector2D(totalWidth * 0.65, RedBoxOverlay.Height * 0.5))
                txtSlot2:SetZOrder(1000)
            end)
        end
        RedBoxOverlay.TextBlockBot = txtBot
    end

    local MainSlot = nil
    pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
    if not MainSlot then return false end

    RedBoxOverlay.MainContainer = Container
    RedBoxOverlay.WidgetSlot = MainSlot
    pcall(function()
        MainSlot:SetAutoSize(false)
        MainSlot:SetZOrder(999)
        MainSlot:SetAlignment(FVector2D(0.5, 0.0))
        MainSlot:SetSize(FVector2D(RedBoxOverlay.Width, RedBoxOverlay.Height))
    end)
    RedBoxOverlay.UpdatePosition()
    return true
end

function RedBoxOverlay.SetCounts(players, bots)
    if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then return end
    RedBoxOverlay.PlayerCount = players or 0
    RedBoxOverlay.BotCount = bots or 0

    if RedBoxOverlay.TextBlockPlayer and slua.isValid(RedBoxOverlay.TextBlockPlayer) then
        pcall(function()
            local strP = string.format("Player: %d", RedBoxOverlay.PlayerCount)
            if RedBoxOverlay._CachedTextPlayer ~= strP then
                RedBoxOverlay.TextBlockPlayer:SetText(strP)
                RedBoxOverlay._CachedTextPlayer = strP
            end
        end)
    end
    if RedBoxOverlay.TextBlockBot and slua.isValid(RedBoxOverlay.TextBlockBot) then
        pcall(function()
            local strB = string.format("Bot: %d", RedBoxOverlay.BotCount)
            if RedBoxOverlay._CachedTextBot ~= strB then
                RedBoxOverlay.TextBlockBot:SetText(strB)
                RedBoxOverlay._CachedTextBot = strB
            end
        end)
    end
end

function RedBoxOverlay.UpdatePosition()
    local Slot = RedBoxOverlay.WidgetSlot
    if not Slot or not slua.isValid(Slot) then return end

    local PC = PlayerMapMarker.GetMyPlayerController()
    if not slua.isValid(PC) then return end

    local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
    local FVector2D = import("Vector2D") or FVector2D

    pcall(function()
        if not RedBoxOverlay._CachedPosVec then
            RedBoxOverlay._CachedPosVec = FVector2D(fromX, fromY)
        else
            RedBoxOverlay._CachedPosVec.X = fromX
            RedBoxOverlay._CachedPosVec.Y = fromY
        end
        Slot:SetPosition(RedBoxOverlay._CachedPosVec)
    end)
end

function RedBoxOverlay.Start()
    if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return end
    if RedBoxOverlay.Create() then
        RedBoxOverlay.bActive = true
        pcall(function() RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end
end

function RedBoxOverlay.Stop()
    RedBoxOverlay.bActive = false
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
        pcall(function()
            RedBoxOverlay.MainContainer:RemoveFromParent()
            RedBoxOverlay.MainContainer:ConditionalBeginDestroy()
        end)
    end
    RedBoxOverlay.MainContainer = nil
    RedBoxOverlay.WidgetSlot = nil
    RedBoxOverlay.TextBlockPlayer = nil
    RedBoxOverlay.TextBlockBot = nil
    RedBoxOverlay._CachedPosVec = nil
end

_G.RedBoxOverlay = RedBoxOverlay

-- ========================================================================
-- ⚡ ESP V2 SYSTEM (Continued)
-- ========================================================================
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local KismetMathLibrary_ESP9 = nil
local KismetSystemLibrary_ESP9 = nil

pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)
pcall(function() KismetMathLibrary_ESP9 = import("KismetMathLibrary") end)
pcall(function() KismetSystemLibrary_ESP9 = import("KismetSystemLibrary") end)

local FVector2D_ESP9 = _G.FVector2D or import("Vector2D")
local FLinearColor_ESP9 = _G.FLinearColor or import("LinearColor")
local FVector_ESP9 = _G.FVector or import("Vector")

PlayerMapMarker.MarkTypeID = 1007
PlayerMapMarker.bUseScreenESP = true
PlayerMapMarker.bUseScreenMark = false
PlayerMapMarker.bUseQuickSign = false
PlayerMapMarker.bUseNavigator = false
PlayerMapMarker.bUseWidgetComponent = false
PlayerMapMarker.ESPBoneName = "head"
PlayerMapMarker.ESPWorldOffsetZ = 0
PlayerMapMarker.ESPAnchorOffsetX = 35
PlayerMapMarker.ESPAnchorOffsetY = 0
PlayerMapMarker.ESPTextOffsetX = 0
PlayerMapMarker.ESPTextOffsetY = 0
PlayerMapMarker.ESPWidgetAlignment = FVector2D_ESP9 and FVector2D_ESP9(0.5, 1.0) or {X=0.5, Y=1.0}
PlayerMapMarker.ESPWidgetSize = FVector2D_ESP9 and FVector2D_ESP9(70, 21) or {X=70, Y=21}
PlayerMapMarker.ESPWidgetAutoSize = true
PlayerMapMarker.ESPWidgetZOrder = 2
PlayerMapMarker.bShowDistance = true
PlayerMapMarker.DistanceUnit = "m"
PlayerMapMarker.WeaponIconBrushW = 96
PlayerMapMarker.WeaponIconBrushH = 48
PlayerMapMarker.HPWidgetSwitcherTypeIndex = 0
PlayerMapMarker.HPWidgetSwitcherType2Index = 0
PlayerMapMarker.bForceSwitcherIndexEveryUpdate = true
PlayerMapMarker.bUseSnapLines = true
PlayerMapMarker.SnapLineThickness = 3.0
PlayerMapMarker.SnapLineOriginY = 50
PlayerMapMarker.SnapLineOriginOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetY = -14
PlayerMapMarker.SnapLineColor = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 1.0, 0.0, 1.0) or {R=255, G=255, B=0, A=255}
PlayerMapMarker.SnapLineOpacity = 0.7
PlayerMapMarker.bUseSkeleton = false
PlayerMapMarker.SkeletonThickness = 0.8
PlayerMapMarker.SkeletonColor = nil
PlayerMapMarker.SkeletonOpacity = 0.8
PlayerMapMarker.SkeletonMaxDistance = 100000
PlayerMapMarker.bUseVisibilityColor = true
PlayerMapMarker.SkeletonVisibleColor = FLinearColor_ESP9 and FLinearColor_ESP9(0.0, 1.0, 0.0, 0.8) or {R=0,G=255,B=0,A=200}
PlayerMapMarker.SkeletonCoverColor = FLinearColor_ESP9 and FLinearColor_ESP9(0.9, 0.0, 0.0, 0.6) or {R=230,G=0,B=0,A=150}
PlayerMapMarker.SkeletonWidgets = {}
PlayerMapMarker._StaticBoneLocCache = {}
PlayerMapMarker.SkeletonChains = {
    {"neck_01", "lowerarm_r", "hand_r"},
    {"neck_01", "lowerarm_l", "hand_l"},
    {"head", "neck_01", "pelvis"},
    {"pelvis", "calf_r", "foot_r"},
    {"pelvis", "calf_l", "foot_l"}
}
PlayerMapMarker.BoneNameFallbacks = {
    ["head"] = {"head", "Head", "head_socket"},
    ["neck_01"] = {"neck_01", "Neck_01", "neck", "Neck"},
    ["clavicle_r"] = {"clavicle_r", "Clavicle_R", "clavicle_R"},
    ["upperarm_r"] = {"upperarm_r", "UpperArm_R", "arm_r", "arm_r_01"},
    ["lowerarm_r"] = {"lowerarm_r", "LowerArm_R", "forearm_r"},
    ["hand_r"] = {"hand_r", "Hand_R", "hand_r_socket"},
    ["clavicle_l"] = {"clavicle_l", "Clavicle_L", "clavicle_L"},
    ["upperarm_l"] = {"upperarm_l", "UpperArm_L", "arm_l", "arm_l_01"},
    ["lowerarm_l"] = {"lowerarm_l", "LowerArm_L", "forearm_l"},
    ["hand_l"] = {"hand_l", "Hand_L", "hand_l_socket"},
    ["spine_03"] = {"spine_03", "Spine_03", "spine_02", "spine"},
    ["spine_02"] = {"spine_02", "Spine_02", "spine_01"},
    ["pelvis"] = {"pelvis", "Pelvis", "hip"},
    ["thigh_r"] = {"thigh_r", "Thigh_R", "leg_r"},
    ["calf_r"] = {"calf_r", "Calf_R", "shin_r"},
    ["foot_r"] = {"foot_r", "Foot_R", "foot_r_socket"},
    ["thigh_l"] = {"thigh_l", "Thigh_L", "leg_l"},
    ["calf_l"] = {"calf_l", "Calf_L", "shin_l"},
    ["foot_l"] = {"foot_l", "Foot_L", "foot_l_socket"},
}

PlayerMapMarker.MapAddedFlag = 4
PlayerMapMarker.nUpdateInterval = 0.5
PlayerMapMarker.bUseFrameTick = false
PlayerMapMarker.nHeavyScanFrameInterval = 15
PlayerMapMarker.nDistanceUpdateFrameInterval = 5
PlayerMapMarker.bIncludeMe = false
PlayerMapMarker.bIncludeAI = true
PlayerMapMarker.bUseServerMarks = false
PlayerMapMarker.bActive = false
PlayerMapMarker.MarkMap = {}
PlayerMapMarker.PlayerInfo = {}
PlayerMapMarker.ESPCanvas = nil
PlayerMapMarker.ESPWidgets = {}
PlayerMapMarker.ESPWidgetPtrs = {}
PlayerMapMarker.SnapLineWidgets = {}
PlayerMapMarker._cachedViewportW = 1920
PlayerMapMarker._cachedViewportH = 1080
PlayerMapMarker._FrameCount = 0
PlayerMapMarker._bTickRegistered = false
PlayerMapMarker._CachedAllChars = nil
PlayerMapMarker._CachedMyLoc = nil
PlayerMapMarker._CachedMyKey = nil
PlayerMapMarker.WidgetComps = {}
PlayerMapMarker._bAllPathsFailed = false
PlayerMapMarker._bLightUpdateScheduled = false
PlayerMapMarker._LightUpdateInterval = 0.02
PlayerMapMarker._bDistanceUpdateScheduled = false
PlayerMapMarker._DistanceUpdateInterval = 0.1
PlayerMapMarker._bScreenMarkConfigSetup = false

-- ========================================================================
-- ⚡ ENEMY NAME & BOX ESP SYSTEM
-- ========================================================================
local EnemyESPWidgets = {}
local EnemyBoxWidgets = {}
local EnemyNameWidgets = {}

local function GetBoxColor()
    local colorIndex = _G.AK_GetVal("ENEMY_BOX_COLOR") or 0
    local colors = {
        {R=1.0, G=0.0, B=0.0, A=1.0},     -- Red
        {R=0.0, G=1.0, B=0.0, A=1.0},     -- Green
        {R=0.0, G=0.0, B=1.0, A=1.0},     -- Blue
        {R=1.0, G=1.0, B=0.0, A=1.0},     -- Yellow
        {R=0.5, G=0.0, B=1.0, A=1.0},     -- Purple
        {R=0.0, G=1.0, B=1.0, A=1.0}      -- Cyan
    }
    return colors[colorIndex + 1] or colors[1]
end

function PlayerMapMarker:CreateEnemyBoxWidget(Character)
    local key = tostring(Character)
    if EnemyBoxWidgets[key] then return EnemyBoxWidgets[key] end
    
    local canvas = PlayerMapMarker.ESPCanvas
    if not canvas or not slua.isValid(canvas) then return nil end
    
    local border = nil
    pcall(function()
        border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas)
    end)
    if not border or not slua.isValid(border) then return nil end
    
    local color = GetBoxColor()
    pcall(function()
        border:SetBrushColor(FLinearColor(color.R, color.G, color.B, color.A))
        border:SetRenderTransformPivot(FVector2D(0.5, 0.5))
        border:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    end)
    
    local slot = canvas:AddChildToCanvas(border)
    if not slot or not slua.isValid(slot) then return nil end
    
    pcall(function()
        slot:SetAutoSize(false)
        slot:SetZOrder(15)
        slot:SetAlignment(FVector2D(0.5, 0.5))
    end)
    
    local widgetData = {
        border = border,
        slot = slot,
        pos = FVector2D(0, 0),
        size = FVector2D(0, 0),
        lastPos = nil,
        lastSize = nil
    }
    
    EnemyBoxWidgets[key] = widgetData
    return widgetData
end

function PlayerMapMarker:CreateEnemyNameWidget(Character)
    local key = tostring(Character)
    if EnemyNameWidgets[key] then return EnemyNameWidgets[key] end
    
    local canvas = PlayerMapMarker.ESPCanvas
    if not canvas or not slua.isValid(canvas) then return nil end
    
    local textBlock = nil
    pcall(function()
        textBlock = CGame:NewObjectFromPath("/Script/UMG.TextBlock", canvas)
    end)
    if not textBlock or not slua.isValid(textBlock) then return nil end
    
    local color = GetBoxColor()
    pcall(function()
        textBlock:SetColorAndOpacity(FSlateColor(FLinearColor(color.R, color.G, color.B, 1.0)))
        textBlock:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        if textBlock.Font then
            local font = textBlock.Font
            font.Size = 12
            textBlock:SetFont(font)
        end
    end)
    
    local slot = canvas:AddChildToCanvas(textBlock)
    if not slot or not slua.isValid(slot) then return nil end
    
    pcall(function()
        slot:SetAutoSize(true)
        slot:SetZOrder(16)
        slot:SetAlignment(FVector2D(0.5, 0.0))
    end)
    
    local widgetData = {
        text = textBlock,
        slot = slot,
        pos = FVector2D(0, 0),
        lastText = "",
        lastPos = nil
    }
    
    EnemyNameWidgets[key] = widgetData
    return widgetData
end

function PlayerMapMarker:UpdateEnemyBoxAndName(Character, PC, Loc)
    if not PlayerMapMarker.bUseScreenESP then return end
    if not _G.AK_GetVal("ENEMY_NAME") == 1 and not _G.AK_GetVal("ENEMY_BOX") == 1 then return end
    
    local key = tostring(Character)
    local bShowName = _G.AK_GetVal("ENEMY_NAME") == 1
    local bShowBox = _G.AK_GetVal("ENEMY_BOX") == 1
    
    if not bShowName and not bShowBox then
        if EnemyNameWidgets[key] then
            pcall(function() EnemyNameWidgets[key].text:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        if EnemyBoxWidgets[key] then
            pcall(function() EnemyBoxWidgets[key].border:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end
    
    local bonePoints = {}
    local boneNames = {
        "head", "neck_01", "spine_03", "spine_01", "pelvis",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
        "hand_l", "hand_r", "calf_l", "calf_r", "foot_l", "foot_r"
    }
    
    for _, boneName in ipairs(boneNames) do
        local boneWorldLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, boneName)
        if boneWorldLoc then
            local bOnScreen, canvasX, canvasY = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, boneWorldLoc)
            if bOnScreen then
                table.insert(bonePoints, {X = canvasX, Y = canvasY})
            end
        end
    end
    
    if #bonePoints < 2 then
        local loc = PlayerMapMarker.GetESPLocation(Character)
        if loc then
            local bOnScreen, canvasX, canvasY = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, loc)
            if bOnScreen then
                table.insert(bonePoints, {X = canvasX - 30, Y = canvasY - 80})
                table.insert(bonePoints, {X = canvasX + 30, Y = canvasY + 10})
            end
        end
    end
    
    if #bonePoints < 2 then return end
    
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    
    for _, point in ipairs(bonePoints) do
        if point.X < minX then minX = point.X end
        if point.Y < minY then minY = point.Y end
        if point.X > maxX then maxX = point.X end
        if point.Y > maxY then maxY = point.Y end
    end
    
    local padding = 10
    local boxWidth = (maxX - minX) + (padding * 2)
    local boxHeight = (maxY - minY) + (padding * 2)
    local centerX = (minX + maxX) / 2
    local centerY = (minY + maxY) / 2
    
    if bShowBox then
        local boxWidget = PlayerMapMarker:CreateEnemyBoxWidget(Character)
        if boxWidget and boxWidget.border and boxWidget.slot then
            local color = GetBoxColor()
            pcall(function()
                boxWidget.border:SetBrushColor(FLinearColor(color.R, color.G, color.B, 0.6))
                boxWidget.border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                boxWidget.pos.X = centerX - (boxWidth / 2)
                boxWidget.pos.Y = centerY - (boxHeight / 2)
                boxWidget.slot:SetPosition(boxWidget.pos)
                boxWidget.size.X = boxWidth
                boxWidget.size.Y = boxHeight
                boxWidget.slot:SetSize(boxWidget.size)
                boxWidget.lastPos = boxWidget.pos
                boxWidget.lastSize = boxWidget.size
            end)
        end
    elseif EnemyBoxWidgets[key] then
        pcall(function() EnemyBoxWidgets[key].border:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    end
    
    if bShowName then
        local nameWidget = PlayerMapMarker:CreateEnemyNameWidget(Character)
        if nameWidget and nameWidget.text and nameWidget.slot then
            local playerName = PlayerMapMarker.GetPlayerName(Character)
            local color = GetBoxColor()
            pcall(function()
                nameWidget.text:SetText(playerName)
                nameWidget.text:SetColorAndOpacity(FSlateColor(FLinearColor(color.R, color.G, color.B, 1.0)))
                nameWidget.text:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                nameWidget.pos.X = centerX
                nameWidget.pos.Y = minY - padding - 20
                nameWidget.slot:SetPosition(nameWidget.pos)
                nameWidget.lastPos = nameWidget.pos
                nameWidget.lastText = playerName
            end)
        end
    elseif EnemyNameWidgets[key] then
        pcall(function() EnemyNameWidgets[key].text:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    end
end

function PlayerMapMarker:ClearEnemyNameAndBoxes()
    for key, widget in pairs(EnemyBoxWidgets) do
        if widget and widget.border and slua.isValid(widget.border) then
            pcall(function()
                widget.border:RemoveFromParent()
                widget.border:ConditionalBeginDestroy()
            end)
        end
    end
    EnemyBoxWidgets = {}
    
    for key, widget in pairs(EnemyNameWidgets) do
        if widget and widget.text and slua.isValid(widget.text) then
            pcall(function()
                widget.text:RemoveFromParent()
                widget.text:ConditionalBeginDestroy()
            end)
        end
    end
    EnemyNameWidgets = {}
end

-- ========================================================================
-- PATCH: INTEGRATE ENEMY NAME & BOX INTO EXISTING UPDATE LOOP
-- ========================================================================

local originalUpdateESP = PlayerMapMarker.UpdateESP
PlayerMapMarker.UpdateESP = function(AllPlayers, MyLoc)
    originalUpdateESP(AllPlayers, MyLoc)
    
    if not PlayerMapMarker.bUseScreenESP then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid_ESP9(PC) then return end
    
    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter() end
    end)
    
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)
    local activeKeys = {}
    
    for PlayerKey, Character in pairs(AllPlayers) do
        if IsValid_ESP9(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local KeyStr = tostring(PlayerKey)
            
            local bSkip = false
            if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
            if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
            
            local TeamID = PlayerMapMarker.GetTeamID(Character)
            if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then bSkip = true end
            
            local bIsAlive = PlayerMapMarker.IsAlive(Character)
            
            if not bSkip and bIsAlive then
                local Loc = PlayerMapMarker.GetESPLocation(Character)
                if Loc then
                    activeKeys[KeyStr] = true
                    PlayerMapMarker:UpdateEnemyBoxAndName(Character, PC, Loc)
                end
            end
        end
    end
    
    for key, widget in pairs(EnemyBoxWidgets) do
        if not activeKeys[key] then
            if widget and widget.border and slua.isValid(widget.border) then
                pcall(function()
                    widget.border:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end)
            end
        end
    end
    
    for key, widget in pairs(EnemyNameWidgets) do
        if not activeKeys[key] then
            if widget and widget.text and slua.isValid(widget.text) then
                pcall(function()
                    widget.text:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end)
            end
        end
    end
end

local originalStop = PlayerMapMarker.Stop
PlayerMapMarker.Stop = function()
    originalStop()
    PlayerMapMarker:ClearEnemyNameAndBoxes()
end

local function IsValid_ESP9(obj)
    if obj == nil then return false end
    if slua and slua.isValid then return slua.isValid(obj) end
    return obj ~= nil
end

function PlayerMapMarker.GetGameplayData()
    if PlayerMapMarker._CachedGameplayData then return PlayerMapMarker._CachedGameplayData end
    local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
    if ok and GDP then PlayerMapMarker._CachedGameplayData = GDP return GDP end
    return nil
end

function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid_ESP9(PC) then return PC end
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
    if PC and IsValid_ESP9(PC) then PlayerMapMarker._CachedPC = PC return PC end
    return nil
end

function PlayerMapMarker.GetCGameState()
    if CGameState and IsValid_ESP9(CGameState) then return CGameState end
    if PlayerMapMarker._CachedCGameState and IsValid_ESP9(PlayerMapMarker._CachedCGameState) then return PlayerMapMarker._CachedCGameState end
    local ok, GS = pcall(function() return require("GameLua.GameCore.Data.CGameState") end)
    if ok and GS then PlayerMapMarker._CachedCGameState = GS return GS end
    return nil
end

function PlayerMapMarker.GetAllCharacters()
    local AllChars = {}
    pcall(function()
        local Pawns = Game:GetAllPlayerPawns()
        if Pawns then
            for _, Pawn in pairs(Pawns) do
                if Pawn and slua.isValid(Pawn) then
                    local pKey = nil
                    if Pawn.GetPlayerKey then pKey = Pawn:GetPlayerKey() end
                    if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
                    if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
                    if pKey then AllChars[pKey] = Pawn end
                end
            end
        end
    end)
    if not next(AllChars) then
        local GS = PlayerMapMarker.GetCGameState()
        if GS and GS.GetAllCharacters then pcall(function() AllChars = GS:GetAllCharacters() end) end
    end
    return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid_ESP9(PC) then return nil end
    local MyKey = nil
    pcall(function()
        if PC.GetPlayerKey then MyKey = PC:GetPlayerKey()
        elseif PC.PlayerState and PC.PlayerState.PlayerKey then MyKey = PC.PlayerState.PlayerKey end
    end)
    return MyKey
end

function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
    local bIsMe = false
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then
            local MyChar = GDP.GetLocalCharacter()
            if MyChar and Character == MyChar then bIsMe = true return end
        end
        local PC = PlayerMapMarker.GetMyPlayerController()
        if PC and PC.GetPawn then
            local Pawn = PC:GetPawn()
            if Pawn and Character == Pawn then bIsMe = true return end
        end
    end)
    if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then bIsMe = (tostring(PlayerKey) == tostring(MyKey)) end
    return bIsMe
end

function PlayerMapMarker.GetCharacterLocation(Character)
    if not IsValid_ESP9(Character) then return nil end
    local Loc = nil
    pcall(function() if Character.K2_GetActorLocation then Loc = Character:K2_GetActorLocation() end end)
    if not Loc then pcall(function() if Game and Game.GetActorLocation then Loc = Game:GetActorLocation(Character) end end) end
    return Loc
end

function PlayerMapMarker.CalcDistance(Loc1, Loc2)
    if not Loc1 or not Loc2 then return nil end
    local Dist = nil
    pcall(function() if FVector_ESP9 and FVector_ESP9.Dist2D then Dist = FVector_ESP9.Dist2D(Loc1, Loc2) end end)
    if not Dist then
        pcall(function()
            local DX = (Loc1.X or 0) - (Loc2.X or 0)
            local DY = (Loc1.Y or 0) - (Loc2.Y or 0)
            Dist = math.sqrt(DX * DX + DY * DY)
        end)
    end
    return Dist
end

function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
    if not PlayerMapMarker.bShowDistance then return "" end
    if not MyLoc or not TargetLoc then return "" end
    local Dist = PlayerMapMarker.CalcDistance(MyLoc, TargetLoc)
    if not Dist then return "" end
    local Meters = Dist / 100
    if Meters < 1000 then return string.format("%dm", math.floor(Meters))
    else return string.format("%.1fkm", Meters / 1000) end
end

function PlayerMapMarker.GetMyLocation()
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    local MyChar = nil
    pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
    if not IsValid_ESP9(MyChar) then return nil end
    return PlayerMapMarker.GetCharacterLocation(MyChar)
end

function PlayerMapMarker.GetPlayerName(Character)
    if not IsValid_ESP9(Character) then return "Unknown" end
    local Name = nil
    pcall(function() if Character.GetPlayerNameSafety then Name = Character:GetPlayerNameSafety() end end)
    if not Name then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid_ESP9(PS) and PS.GetPlayerName then Name = PS:GetPlayerName() end
        end)
    end
    return Name or "Unknown"
end

function PlayerMapMarker.IsAI(Character)
    local bAI = false
    pcall(function() if Game and Game.IsAI then bAI = Game:IsAI(Character) end end)
    return bAI
end

function PlayerMapMarker.IsAlive(Character)
    local bAlive = true
    pcall(function() if Character.IsAlive then bAlive = Character:IsAlive() end end)
    return bAlive
end

function PlayerMapMarker.GetTeamID(Character)
    if not IsValid_ESP9(Character) then return nil end
    local TeamID = nil
    pcall(function() if Character.GetTeamID then TeamID = Character:GetTeamID() end end)
    if not TeamID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid_ESP9(PS) and PS.GetTeamID then TeamID = PS:GetTeamID()
            elseif IsValid_ESP9(PS) and PS.TeamID then TeamID = PS.TeamID end
        end)
    end
    if not TeamID then pcall(function() if Character.TeamID then TeamID = Character.TeamID end end) end
    return TeamID
end

function PlayerMapMarker.GetTeamColor(TeamID)
    if TeamID == nil or TeamID == 0 then
        return FLinearColor_ESP9 and FLinearColor_ESP9(0.2, 0.4, 1.0, 1.0) or {R=50,G=100,B=255,A=255}
    end
    local TeamColors = {
        [1]={R=255,G=50,B=50,A=255,fR=1.0,fG=0.2,fB=0.2},
        [2]={R=50,G=255,B=50,A=255,fR=0.2,fG=1.0,fB=0.2},
        [3]={R=50,G=100,B=255,A=255,fR=0.2,fG=0.4,fB=1.0},
        [4]={R=255,G=255,B=50,A=255,fR=1.0,fG=1.0,fB=0.2},
        [5]={R=255,G=50,B=255,A=255,fR=1.0,fG=0.2,fB=1.0},
        [6]={R=50,G=255,B=255,A=255,fR=0.2,fG=1.0,fB=1.0},
        [7]={R=255,G=150,B=50,A=255,fR=1.0,fG=0.6,fB=0.2},
        [8]={R=150,G=50,B=255,A=255,fR=0.6,fG=0.2,fB=1.0},
        [9]={R=200,G=255,B=50,A=255,fR=0.8,fG=1.0,fB=0.2},
        [10]={R=50,G=150,B=255,A=255,fR=0.2,fG=0.6,fB=1.0},
        [11]={R=255,G=100,B=150,A=255,fR=1.0,fG=0.4,fB=0.6},
        [12]={R=100,G=255,B=150,A=255,fR=0.4,fG=1.0,fB=0.6},
        [13]={R=150,G=150,B=50,A=255,fR=0.6,fG=0.6,fB=0.2},
        [14]={R=50,G=200,B=150,A=255,fR=0.2,fG=0.8,fB=0.6},
        [15]={R=255,G=200,B=50,A=255,fR=1.0,fG=0.8,fB=0.2}
    }
    local colorIndex = (TeamID % 15)
    if colorIndex == 0 then colorIndex = 15 end
    local c = TeamColors[colorIndex]
    return FLinearColor_ESP9 and FLinearColor_ESP9(c.fR, c.fG, c.fB, 1.0) or {R=c.R, G=c.G, B=c.B, A=c.A}
end

function PlayerMapMarker.InitESPCanvas()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
    local InGameUITools = nil
    pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not InGameUITools then return false end
    local MainControlBaseUI = nil
    pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
    if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then return false end
    local ParentCanvas = nil
    pcall(function()
        if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then ParentCanvas = MainControlBaseUI.CanvasPanel_0
        elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then ParentCanvas = MainControlBaseUI.CanvasPanel_42 end
    end)
    if not ParentCanvas then return false end
    PlayerMapMarker.ESPCanvas = ParentCanvas
    return true
end

function PlayerMapMarker.GetESPLocation(Character)
    if not IsValid_ESP9(Character) then return nil end
    local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
    if BoneLoc then
        local heightOffset = 85
        pcall(function()
            if Character.bIsCrouched then heightOffset = 60 end
            if Character.IsProne and Character:IsProne() then heightOffset = 30 end
        end)
        pcall(function() BoneLoc.Z = BoneLoc.Z + heightOffset + (PlayerMapMarker.ESPWorldOffsetZ or 0) end)
    end
    return BoneLoc
end

function PlayerMapMarker.GetCharacterWeaponInfo(Character)
    if not IsValid_ESP9(Character) then return nil end
    local WeaponID, WeaponName, WeaponIconPath, WeaponIconTexture, CurrentWeapon = nil, nil, nil, nil, nil
    pcall(function() if Character.GetCurrentWeapon then CurrentWeapon = Character:GetCurrentWeapon() end end)
    if not CurrentWeapon then pcall(function() CurrentWeapon = Character.CurrentWeapon end) end
    if not CurrentWeapon then pcall(function() if Character.GetWeaponManager then local WM = Character:GetWeaponManager() if WM and WM.GetCurrentWeapon then CurrentWeapon = WM:GetCurrentWeapon() end end end) end
    if CurrentWeapon and IsValid_ESP9(CurrentWeapon) then
        pcall(function() if CurrentWeapon.GetWeaponID then WeaponID = CurrentWeapon:GetWeaponID() end end)
        if not WeaponID then pcall(function() WeaponID = CurrentWeapon.WeaponID end) end
        if not WeaponID then pcall(function() if CurrentWeapon.GetItemID then WeaponID = CurrentWeapon:GetItemID() end end) end
        pcall(function() if CurrentWeapon.GetWeaponName then WeaponName = CurrentWeapon:GetWeaponName() end end)
        pcall(function() if CurrentWeapon.GetWeaponIconPath then WeaponIconPath = CurrentWeapon:GetWeaponIconPath() end end)
        pcall(function() if CurrentWeapon.GetWeaponIcon then WeaponIconTexture = CurrentWeapon:GetWeaponIcon() end end)
    end
    if not WeaponID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety() elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if PS and IsValid_ESP9(PS) then
                if PS.GetCurrentWeaponID then WeaponID = PS:GetCurrentWeaponID() end
                if not WeaponID and PS.CurWeaponID then WeaponID = PS.CurWeaponID end
            end
        end)
    end
    return { WeaponID = WeaponID, WeaponName = WeaponName, WeaponIconPath = WeaponIconPath, WeaponIconTexture = WeaponIconTexture, CurrentWeapon = CurrentWeapon }
end

PlayerMapMarker._OBHeadWidgetClass = nil
PlayerMapMarker._OBHeadWidgetLoadFailed = false

function PlayerMapMarker.CreateESPWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    if PlayerMapMarker._OBHeadWidgetLoadFailed then return nil end

    if not PlayerMapMarker._OBHeadWidgetClass then
        pcall(function()
            local Path = "/Game/BluePrints/UI/OBUI/Item/OB_PlayerHeadHPItem_UIBP.OB_PlayerHeadHPItem_UIBP"
            local uClass = slua.loadClass(Path)
            if uClass then PlayerMapMarker._OBHeadWidgetClass = uClass end
        end)
        if not PlayerMapMarker._OBHeadWidgetClass then
            PlayerMapMarker._OBHeadWidgetLoadFailed = true
            return nil
        end
    end

    local Widget = nil
    pcall(function()
        local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
        local PC = PlayerMapMarker.GetMyPlayerController()
        local OuterObj = IsValid_ESP9(PC) and PC.Object or PlayerMapMarker.ESPCanvas
        Widget = STExtraBlueprintFunctionLibrary.CreateWidgetByClass(PlayerMapMarker._OBHeadWidgetClass, OuterObj)
    end)
    if not Widget then return nil end

    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Widget:SetRenderOpacity(1.0) end)

    -- Apply YELLOW text color and DARK background to the widget
    local TEXT_COLOR = FSlateColor(FLinearColor(1.0, 1.0, 0.0, 1.0)) -- YELLOW
    local BG_COLOR = FLinearColor(0.0, 0.0, 0.0, 0.8) -- DARK with 80% opacity

    if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then
        pcall(function()
            Widget.TextBlock_PlayerName:SetColorAndOpacity(TEXT_COLOR)
            Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end
    
    if Widget.Text_PlayerName and slua.isValid(Widget.Text_PlayerName) then
        pcall(function()
            Widget.Text_PlayerName:SetColorAndOpacity(TEXT_COLOR)
            Widget.Text_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end
    
    if Widget.TextBlock_TeamName and slua.isValid(Widget.TextBlock_TeamName) then
        pcall(function()
            Widget.TextBlock_TeamName:SetColorAndOpacity(TEXT_COLOR)
            Widget.TextBlock_TeamName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end
    
    if Widget.Image_Name_BG and slua.isValid(Widget.Image_Name_BG) then
        pcall(function()
            Widget.Image_Name_BG:SetColorAndOpacity(BG_COLOR)
            Widget.Image_Name_BG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end
    
    if Widget.Image_TeamBG and slua.isValid(Widget.Image_TeamBG) then
        pcall(function()
            Widget.Image_TeamBG:SetColorAndOpacity(BG_COLOR)
            Widget.Image_TeamBG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
    end

    local NameText = nil
    local HealthFill = nil
    pcall(function()
        NameText = Widget.TextBlock_TeamName
        if NameText and slua.isValid(NameText) then pcall(function() NameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end) end
        if Widget.TextBlock_PlayerName and slua.isValid(Widget.TextBlock_PlayerName) then pcall(function() Widget.TextBlock_PlayerName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end) end
        local SizeBox_HP = Widget.SizeBox_HP
        if SizeBox_HP and slua.isValid(SizeBox_HP) then
            pcall(function() SizeBox_HP:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            local ExistingChild = nil
            pcall(function() if SizeBox_HP.GetContent then ExistingChild = SizeBox_HP:GetContent() end end)
            if ExistingChild and slua.isValid(ExistingChild) then
                local FoundPB = PlayerMapMarker.FindProgressBarInWidget(ExistingChild, 0, 5)
                if FoundPB and slua.isValid(FoundPB) then HealthFill = FoundPB end
            end
        end
    end)

    local WidgetData = {
        Container = Widget,
        NameText = NameText,
        HealthFill = HealthFill,
        IsGameWidget = true,
        HasChildren = (NameText ~= nil)
    }
    return WidgetData
end

function PlayerMapMarker.FindProgressBarInWidget(WidgetObj, Depth, MaxDepth)
    if not WidgetObj or not slua.isValid(WidgetObj) then return nil end
    Depth = Depth or 0
    MaxDepth = MaxDepth or 5
    if Depth > MaxDepth then return nil end

    local bIsPB = false
    pcall(function() if WidgetObj.SetPercent and WidgetObj.SetFillColorAndOpacity then bIsPB = true end end)
    if bIsPB then return WidgetObj end

    local nChildren = 0
    pcall(function() if WidgetObj.GetChildrenCount then nChildren = WidgetObj:GetChildrenCount() end end)
    for i = 0, math.max(nChildren - 1, 0) do
        local child = nil
        pcall(function() child = WidgetObj:GetChildAt(i) end)
        if child and slua.isValid(child) then
            local result = PlayerMapMarker.FindProgressBarInWidget(child, Depth + 1, MaxDepth)
            if result then return result end
        end
    end
    return nil
end

function PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
    if not Widget or not Widget.Container then return end
    if not _G.AK_GetVal("ESP9_Team") == 1 then return end
    local color = PlayerMapMarker.GetTeamColor(TeamID)
    if not color then return end
    pcall(function()
        local W = Widget.Container
        if not W or not slua.isValid(W) then return end
        if W.SetTeamColor then pcall(function() W:SetTeamColor(TeamID) end) end
    end)
end

function PlayerMapMarker.UpdateESPText(Widget, Text)
    if not Widget then return end
    if Widget._LastESPText == Text then return end
    Widget._LastESPText = Text

    -- YELLOW text color (R=1.0, G=1.0, B=0.0)
    local YELLOW = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 1.0, 0.0, 1.0) or {R=255, G=255, B=0, A=255}

    local function applyText(w, txt)
        if not w or not slua.isValid(w) then return end
        if txt == "" then
            pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            return
        else
            pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        end
        pcall(function() w:SetText(txt) end)
        -- Set text color to YELLOW
        pcall(function()
            if w.SetColorAndOpacity then
                w:SetColorAndOpacity(YELLOW)
            end
        end)
    end

    if Widget.NameText and slua.isValid(Widget.NameText) then 
        applyText(Widget.NameText, Text) 
    end
    
    if Widget.IsGameWidget and Widget.Container then
        pcall(function()
            local W = Widget.Container
            if W and slua.isValid(W) then
                applyText(W.TextBlock_TeamName, Text)
                applyText(W.TextBlock_PlayerName, Text)
            end
        end)
    end
end

function PlayerMapMarker.UpdateESPHealth(Widget, pct)
    if not Widget then return end
    Widget.LastPct = pct
    local bShowHP = _G.AK_GetVal("ESP9_HP") == 1
    if not bShowHP then return end

    if PlayerMapMarker.bForceSwitcherIndexEveryUpdate and Widget.Container then
        pcall(function()
            local W = Widget.Container
            if W and slua.isValid(W) then
                if W.WidgetSwitcher_Type and slua.isValid(W.WidgetSwitcher_Type) then pcall(function() if W.WidgetSwitcher_Type.SetActiveWidgetIndex then W.WidgetSwitcher_Type:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherTypeIndex) end end) end
                if W.WidgetSwitcher_Type2 and slua.isValid(W.WidgetSwitcher_Type2) then pcall(function() if W.WidgetSwitcher_Type2.SetActiveWidgetIndex then W.WidgetSwitcher_Type2:SetActiveWidgetIndex(PlayerMapMarker.HPWidgetSwitcherType2Index) end end) end
            end
        end)
    end

    if Widget.HealthFill then
        local bValid = false
        pcall(function() bValid = slua.isValid(Widget.HealthFill) end)
        if bValid then
            pcall(function()
                if Widget.HealthFill.SetPercent then
                    Widget.HealthFill:SetPercent(pct)
                    local color
                    if pct > 0.5 then color = FLinearColor_ESP9 and FLinearColor_ESP9(0.0, 1.0, 0.0, 1.0) or {R=0,G=255,B=0,A=255}
                    elseif pct > 0.25 then color = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 0.5, 0.0, 1.0) or {R=255,G=128,B=0,A=255}
                    else color = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 0.0, 0.0, 1.0) or {R=255,G=0,B=0,A=255} end
                    if Widget.HealthFill.SetFillColorAndOpacity then Widget.HealthFill:SetFillColorAndOpacity(color) end
                end
            end)
        end
    end
end

function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
    if not Widget or not IsValid_ESP9(PC) then return false end

    local Container = Widget.Container or Widget
    local bOnScreen = true

    if not CanvasPos then
        if not WorldLoc then return false end
        bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    end

    if not bOnScreen then pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) return false end

    pcall(function()
        local bShowAnyUI = _G.AK_GetVal("ESP9_Name") == 1 or _G.AK_GetVal("ESP9_Distance") == 1 or _G.AK_GetVal("ESP9_HP") == 1 or _G.AK_GetVal("ESP9_Team") == 1 or _G.AK_GetVal("ESP9_Weapon") == 1
        if bShowAnyUI then Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        else Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end

        if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then
            local ptr = tostring(Container)
            local Slot = PlayerMapMarker.ESPWidgetPtrs[ptr]
            if not Slot or not slua.isValid(Slot) then
                local addedSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Container)
                if addedSlot and slua.isValid(addedSlot) then
                    Slot = addedSlot
                    PlayerMapMarker.ESPWidgetPtrs[ptr] = addedSlot
                    pcall(function() Slot:SetAutoSize(true) end)
                    pcall(function() Slot:SetAlignment(FVector2D_ESP9 and FVector2D_ESP9(0.5, 1.0) or {X=0.5, Y=1.0}) end)
                    pcall(function() Slot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20) end)
                end
            end
            if Slot and slua.isValid(Slot) then
                local finalX = CanvasPos.X + (PlayerMapMarker.ESPAnchorOffsetX or 0)
                local finalY = CanvasPos.Y + (PlayerMapMarker.ESPAnchorOffsetY or 0)
                if not Widget._CachedPosVec then Widget._CachedPosVec = FVector2D_ESP9 and FVector2D_ESP9(finalX, finalY) or {X=finalX, Y=finalY}
                else Widget._CachedPosVec.X = finalX; Widget._CachedPosVec.Y = finalY end
                pcall(function() Slot:SetPosition(Widget._CachedPosVec) end)
            end
        end
    end)
    return true
end

PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0

function PlayerMapMarker.UpdateCanvasTransform(PC)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

    local success = false
    pcall(function()
        local SBL = SlateBlueprintLibrary
        if SBL and SBL.AbsoluteToLocal then
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg then
                local pt0 = SBL.AbsoluteToLocal(cg, FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0})
                local pt1 = SBL.AbsoluteToLocal(cg, FVector2D_ESP9 and FVector2D_ESP9(100, 100) or {X=100, Y=100})
                if pt0 and pt1 then
                    PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                    PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    PlayerMapMarker._CanvasOffsetX = pt0.X
                    PlayerMapMarker._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end
    end)

    if not success then
        local scale = 1.0
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then scale = WidgetLayoutLibrary.GetViewportScale(PC) or 1.0 end
        PlayerMapMarker._CanvasScaleX = 1.0 / scale
        PlayerMapMarker._CanvasScaleY = 1.0 / scale
        PlayerMapMarker._CanvasOffsetX = 0
        PlayerMapMarker._CanvasOffsetY = 0
    end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
    if not ScreenPixelPos then return FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0} end
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return (FVector2D_ESP9 and FVector2D_ESP9(ScreenPixelPos.X * scaleX + offsetX, ScreenPixelPos.Y * scaleY + offsetY)) or {X = ScreenPixelPos.X * scaleX + offsetX, Y = ScreenPixelPos.Y * scaleY + offsetY}
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValid_ESP9(PC) or not WorldLoc then return false, (FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}) end

    local ScreenPixelPos = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, ScreenPixelPos, true)
        if res == true or res == 1 or (ScreenPixelPos and (ScreenPixelPos.X ~= 0 or ScreenPixelPos.Y ~= 0)) then bOK = true end
    end)

    if not bOK or not ScreenPixelPos or (ScreenPixelPos.X == 0 and ScreenPixelPos.Y == 0) then return false, (FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}) end

    local CanvasLocalPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
    return true, CanvasLocalPos
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
    local screenPixelW, screenPixelH = 0, 0
    local scale = 1.0

    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0,Y=0}
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
        end
    end)

    if screenPixelW <= 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
            end
        end)
    end

    pcall(function()
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then
            local s = WLL.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)

    if screenPixelW <= 200 then
        screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
        screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
    end

    if not PlayerMapMarker._CachedTopCenterPixel then PlayerMapMarker._CachedTopCenterPixel = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0,Y=0} end
    PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
    PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale

    local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
    return fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0), fromCanvasPos.Y
end

function PlayerMapMarker.CreateSnapLine()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end

    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end

    local color = PlayerMapMarker.SnapLineColor or (FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 1.0, 1.0, PlayerMapMarker.SnapLineOpacity or 0.7) or {R=1,G=1,B=1,A=PlayerMapMarker.SnapLineOpacity or 0.7})
    pcall(function() Border:SetBrushColor(color) end)
    pcall(function() Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Border.RenderTransformPivot = FVector2D_ESP9 and FVector2D_ESP9(0.0, 0.5) or {X=0,Y=0.5} end)
    pcall(function() Border:SetRenderTransformPivot(FVector2D_ESP9 and FVector2D_ESP9(0.0, 0.5) or {X=0,Y=0.5}) end)

    local Slot = nil
    pcall(function()
        Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
        if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(1) end
    end)
    return { Widget = Border, Slot = Slot }
end

-- ========================================================================
-- ⚡ UPDATED SNAP LINE FUNCTION WITH VISIBILITY CHECK (Green/Red)
-- ========================================================================
function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
    if not PlayerMapMarker.bUseSnapLines then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end

    if not LineData then
        LineData = PlayerMapMarker.CreateSnapLine()
        if not LineData or not LineData.Widget or not LineData.Slot then return end
        PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
    end

    local Widget = LineData.Widget
    local Slot = LineData.Slot

    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)

    local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]
    local Character = ESPData and ESPData.Character
    local PC = PlayerMapMarker.GetMyPlayerController()
    
    local bIsVisible = false
    if Character and slua.isValid(Character) and PC and slua.isValid(PC) then
        pcall(function()
            if PC.LineOfSightTo then
                local zeroVec = FVector_ESP9 and FVector_ESP9(0, 0, 0) or {X=0, Y=0, Z=0}
                bIsVisible = PC:LineOfSightTo(Character, zeroVec, false)
            end
        end)
    end

    local lineColor
    if bIsVisible then
        lineColor = FLinearColor_ESP9 and FLinearColor_ESP9(0.0, 1.0, 0.0, PlayerMapMarker.SnapLineOpacity or 0.7) 
            or {R=0, G=255, B=0, A=math.floor((PlayerMapMarker.SnapLineOpacity or 0.7) * 255)}
    else
        lineColor = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 0.0, 0.0, PlayerMapMarker.SnapLineOpacity or 0.7) 
            or {R=255, G=0, B=0, A=math.floor((PlayerMapMarker.SnapLineOpacity or 0.7) * 255)}
    end
    
    pcall(function() Widget:SetBrushColor(lineColor) end)

    local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
    local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)

    local dx = toX - fromX
    local dy = toY - fromY
    local length = math.sqrt(dx * dx + dy * dy)
    local thickness = PlayerMapMarker.SnapLineThickness or 3.0
    local angle_rad = 0
    if math.atan2 then angle_rad = math.atan2(dy, dx) else angle_rad = math.atan(dy, dx) end
    local angle = angle_rad * (180.0 / math.pi)

    if not LineData._CachedPosVec then
        LineData._CachedPosVec = FVector2D_ESP9 and FVector2D_ESP9(fromX, fromY - thickness / 2.0) or {X=fromX, Y=fromY - thickness / 2.0}
        LineData._CachedSizeVec = FVector2D_ESP9 and FVector2D_ESP9(length, thickness) or {X=length, Y=thickness}
    else
        LineData._CachedPosVec.X = fromX; LineData._CachedPosVec.Y = fromY - thickness / 2.0
        LineData._CachedSizeVec.X = length; LineData._CachedSizeVec.Y = thickness
    end

    pcall(function()
        Slot:SetPosition(LineData._CachedPosVec)
        Slot:SetSize(LineData._CachedSizeVec)
    end)
    pcall(function() Widget:SetRenderAngle(angle) end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
        pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.RemoveESPWidget(Widget, KeyStr)
    if not Widget then return end
    local Container = Widget.Container or Widget
    pcall(function()
        local ptr = tostring(Container)
        PlayerMapMarker.ESPWidgetPtrs[ptr] = nil
        Container:RemoveFromParent()
        Container:ConditionalBeginDestroy()
    end)
    if KeyStr then
        PlayerMapMarker.RemoveSnapLine(KeyStr)
        if PlayerMapMarker.RemoveSkeletonLines then
            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
        end
    end
end

function PlayerMapMarker.ClearAllSnapLines()
    for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        end
    end
    PlayerMapMarker.SnapLineWidgets = {}
end

function PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, screenX, screenY)
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return screenX * scaleX + offsetX, screenY * scaleY + offsetY
end

function PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, WorldLoc)
    if not IsValid_ESP9(PC) or not WorldLoc then return false, 0, 0 end

    if not PlayerMapMarker._tempScreenPixelPos then
        PlayerMapMarker._tempScreenPixelPos = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0}
    end
    local tempPos = PlayerMapMarker._tempScreenPixelPos
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, tempPos, true)
        if res == true or res == 1 then bOK = true end
    end)

    if not bOK or (tempPos.X == 0 and tempPos.Y == 0) then return false, 0, 0 end

    local canvasX, canvasY = PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, tempPos.X, tempPos.Y)
    return true, canvasX, canvasY
end

function PlayerMapMarker.GetBoneLocationWithFallback(Character, PrimaryBoneName)
    if not IsValid_ESP9(Character) or not PrimaryBoneName then return nil end

    if Character._cachedBoneNames and Character._cachedBoneNames[PrimaryBoneName] then
        local cachedName = Character._cachedBoneNames[PrimaryBoneName]
        local loc = nil
        pcall(function()
            local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
            if Mesh and Game:IsValid(Mesh) then
                if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(cachedName)
                elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(cachedName) end
            end
        end)
        if loc then return loc end
    end

    local fallbacks = PlayerMapMarker.BoneNameFallbacks[PrimaryBoneName] or {PrimaryBoneName}
    for _, bname in ipairs(fallbacks) do
        local loc = nil
        pcall(function()
            local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
            if Mesh and Game:IsValid(Mesh) then
                if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(bname)
                elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(bname) end
            end
        end)
        if loc then
            if not Character._cachedBoneNames then Character._cachedBoneNames = {} end
            Character._cachedBoneNames[PrimaryBoneName] = bname
            return loc
        end
    end
    return nil
end

function PlayerMapMarker.GetCharacterMesh(Character)
    if not IsValid_ESP9(Character) then return nil end
    local Mesh = nil
    pcall(function() if Character.Mesh and Game:IsValid(Character.Mesh) then Mesh = Character.Mesh end end)
    if not Mesh then pcall(function() local SkeletalMeshCompClass = import("/Script/Engine.SkeletalMeshComponent") Mesh = Character:GetComponentByClass(SkeletalMeshCompClass) end) end
    return Mesh
end

function PlayerMapMarker.IsPlayerVisible(PC, Character)
    if not IsValid_ESP9(PC) or not IsValid_ESP9(Character) then return false end
    local now = os.clock()
    if Character._lastVisTime and (now - Character._lastVisTime) < 0.15 then
        return Character._cachedIsVisible or false
    end
    Character._lastVisTime = now

    local bVis = false
    pcall(function()
        if PC.LineOfSightTo then
            if not PlayerMapMarker._ZeroVector then
                local VT = FVector_ESP9 or import("/Script/CoreUObject.Vector")
                if VT then PlayerMapMarker._ZeroVector = VT(0, 0, 0) end
            end
            bVis = PC:LineOfSightTo(Character, PlayerMapMarker._ZeroVector, false)
        end
    end)
    Character._cachedIsVisible = bVis
    return bVis
end

function PlayerMapMarker.CreateSkeletonLineWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end

    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end

    pcall(function() Border.RenderTransformPivot = FVector2D_ESP9 and FVector2D_ESP9(0.0, 0.5) or {X=0, Y=0.5} end)
    pcall(function() Border:SetRenderTransformPivot(FVector2D_ESP9 and FVector2D_ESP9(0.0, 0.5) or {X=0, Y=0.5}) end)

    local Slot = nil
    pcall(function()
        Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border)
        if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(5) end
    end)

    return {
        Widget = Border, Slot = Slot,
        posVec = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0},
        sizeVec = FVector2D_ESP9 and FVector2D_ESP9(0, 0) or {X=0, Y=0},
        lastFromX = -99999, lastFromY = -99999,
        lastToX = -99999, lastToY = -99999
    }
end

function PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, bVisible, TeamColor, bPlayerOnScreen, charLoc)
    if not PlayerMapMarker.bUseSkeleton then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

    local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]

    if not bVisible or not IsValid_ESP9(Character) or not IsValid_ESP9(PC) then
        if PlayerBones then
            for _, LineData in ipairs(PlayerBones) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                    LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    LineData.Widget._isSelfHitTestVisible = false
                end
            end
        end
        return
    end

    if not charLoc then charLoc = PlayerMapMarker.GetESPLocation(Character) end
    if not charLoc then return end

    if bPlayerOnScreen == nil then
        local bOnScreen, _, _ = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, charLoc)
        bPlayerOnScreen = bOnScreen
    end

    if not bPlayerOnScreen then
        if PlayerBones then
            for _, LineData in ipairs(PlayerBones) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                    LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    LineData.Widget._isSelfHitTestVisible = false
                end
            end
        end
        return
    end

    local dist = 0
    local myLoc = PlayerMapMarker._CachedMyLoc or PlayerMapMarker.GetMyLocation()
    if myLoc and charLoc then
        local dx = (charLoc.X or 0) - (myLoc.X or 0)
        local dy = (charLoc.Y or 0) - (myLoc.Y or 0)
        local dz = (charLoc.Z or 0) - (myLoc.Z or 0)
        dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    if PlayerMapMarker.SkeletonMaxDistance and PlayerMapMarker.SkeletonMaxDistance > 0 then
        if dist > PlayerMapMarker.SkeletonMaxDistance then
            if PlayerBones then
                for _, LineData in ipairs(PlayerBones) do
                    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                        LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        LineData.Widget._isSelfHitTestVisible = false
                    end
                end
            end
            return
        end
    end

    if not PlayerBones then
        PlayerBones = {}
        PlayerMapMarker.SkeletonWidgets[KeyStr] = PlayerBones
    end

    local lineColor = nil
    if PlayerMapMarker.bUseVisibilityColor then
        local bTargetVisible = PlayerMapMarker.IsPlayerVisible(PC, Character)
        if bTargetVisible then lineColor = PlayerMapMarker.SkeletonVisibleColor or FLinearColor_ESP9(0.0, 1.0, 0.0, 0.8)
        else lineColor = PlayerMapMarker.SkeletonCoverColor or FLinearColor_ESP9(0.9, 0.0, 0.0, 0.6) end
    else
        lineColor = PlayerMapMarker.SkeletonColor or TeamColor or FLinearColor_ESP9(1.0, 1.0, 1.0, PlayerMapMarker.SkeletonOpacity or 0.8)
    end

    local cache = PlayerMapMarker._StaticBoneLocCache
    for k in pairs(cache) do cache[k] = nil end

    local lineIndex = 0
    local thickness = PlayerMapMarker.SkeletonThickness or 0.8

    for _, chain in ipairs(PlayerMapMarker.SkeletonChains) do
        local lastCanvasX, lastCanvasY = nil, nil
        for _, boneName in ipairs(chain) do
            local boneWorldLoc = cache[boneName]
            if boneWorldLoc == nil then
                boneWorldLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, boneName) or false
                cache[boneName] = boneWorldLoc
            end
            if boneWorldLoc == false then boneWorldLoc = nil end

            local currentCanvasX, currentCanvasY = nil, nil
            if boneWorldLoc then
                local bOnScreen, cX, cY = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, boneWorldLoc)
                if bOnScreen then
                    currentCanvasX = cX
                    currentCanvasY = cY
                end
            end

            if lastCanvasX and currentCanvasX then
                lineIndex = lineIndex + 1
                local LineData = PlayerBones[lineIndex]
                if not LineData or not LineData.Widget or not slua.isValid(LineData.Widget) then
                    LineData = PlayerMapMarker.CreateSkeletonLineWidget()
                    if LineData then PlayerBones[lineIndex] = LineData end
                end

                if LineData and LineData.Widget and LineData.Slot then
                    local Widget = LineData.Widget
                    local Slot = LineData.Slot

                    if Widget._cachedColor ~= lineColor then
                        Widget:SetBrushColor(lineColor)
                        Widget._cachedColor = lineColor
                    end

                    if not Widget._isSelfHitTestVisible then
                        Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                        Widget._isSelfHitTestVisible = true
                    end

                    local fromX = lastCanvasX
                    local fromY = lastCanvasY
                    local toX = currentCanvasX
                    local toY = currentCanvasY

                    local threshold = 0.15
                    if dist > 8000 then threshold = 0.8 elseif dist > 4000 then threshold = 0.4 end

                    if math.abs(fromX - LineData.lastFromX) > threshold or
                       math.abs(fromY - LineData.lastFromY) > threshold or
                       math.abs(toX - LineData.lastToX) > threshold or
                       math.abs(toY - LineData.lastToY) > threshold then

                        LineData.lastFromX = fromX
                        LineData.lastFromY = fromY
                        LineData.lastToX = toX
                        LineData.lastToY = toY

                        local dx = toX - fromX
                        local dy = toY - fromY
                        local length = math.sqrt(dx * dx + dy * dy)
                        local angle_rad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
                        local angle = angle_rad * 57.29577951308232

                        local pVec = LineData.posVec
                        pVec.X = fromX; pVec.Y = fromY - thickness / 2.0
                        Slot:SetPosition(pVec)

                        local sVec = LineData.sizeVec
                        sVec.X = length; sVec.Y = thickness
                        Slot:SetSize(sVec)

                        Widget:SetRenderAngle(angle)
                    end
                end
            end
            lastCanvasX = currentCanvasX
            lastCanvasY = currentCanvasY
        end
    end

    for i = lineIndex + 1, #PlayerBones do
        local LineData = PlayerBones[i]
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            LineData.Widget._isSelfHitTestVisible = false
        end
    end
end

function PlayerMapMarker.RemoveSkeletonLines(KeyStr)
    local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if PlayerBones then
        for _, LineData in ipairs(PlayerBones) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function()
                    LineData.Widget:RemoveFromParent()
                    LineData.Widget:ConditionalBeginDestroy()
                end)
            end
        end
        PlayerMapMarker.SkeletonWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllSkeletonLines()
    for KeyStr, PlayerBones in pairs(PlayerMapMarker.SkeletonWidgets) do
        for _, LineData in ipairs(PlayerBones) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function()
                    LineData.Widget:RemoveFromParent()
                    LineData.Widget:ConditionalBeginDestroy()
                end)
            end
        end
    end
    PlayerMapMarker.SkeletonWidgets = {}
end

function PlayerMapMarker.ClearAllESP()
    RedBoxOverlay.Stop()
    for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
        PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr)
    end
    PlayerMapMarker.ESPWidgets = {}
    PlayerMapMarker.ESPWidgetPtrs = {}
    PlayerMapMarker.ClearAllSnapLines()
    PlayerMapMarker.ClearAllSkeletonLines()
    PlayerMapMarker:ClearEnemyNameAndBoxes()
    PlayerMapMarker.ESPCanvas = nil
    PlayerMapMarker._OBHeadWidgetClass = nil
    PlayerMapMarker._OBHeadWidgetLoadFailed = false
    PlayerMapMarker._cachedViewportW = 1920
    PlayerMapMarker._cachedViewportH = 1080
end

function PlayerMapMarker.UpdateESP(AllPlayers, MyLoc)
    if not PlayerMapMarker.bUseScreenESP then return end

    PlayerMapMarker.bUseSnapLines = _G.AK_GetVal("ESP9_Line") == 1
    PlayerMapMarker.bUseSkeleton = _G.AK_GetVal("ESP9_Skeleton") == 1

    if not PlayerMapMarker.InitESPCanvas() then return end
    if PlayerMapMarker._OBHeadWidgetLoadFailed then return end

    local PC = PlayerMapMarker.GetMyPlayerController()
    if IsValid_ESP9(PC) then PlayerMapMarker.UpdateCanvasTransform(PC) end

    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines and IsValid_ESP9(PC) then
        fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
    end

    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local SeenKeys = {}
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
        else if PC and PC.GetPawn then MyChar = PC:GetPawn() end end
    end)

    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)

    for PlayerKey, Character in pairs(AllPlayers) do
        if IsValid_ESP9(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local KeyStr = tostring(PlayerKey)
            local Name = PlayerMapMarker.GetPlayerName(Character)
            local Loc = PlayerMapMarker.GetESPLocation(Character)
            local DistStr = ""
            if MyLoc and Loc then DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc) end

            local bSkip = false
            if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
            if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end

            local TeamID = PlayerMapMarker.GetTeamID(Character)
            if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then bSkip = true end

            local bIsAlive = PlayerMapMarker.IsAlive(Character)

            if not bSkip and Loc then
                SeenKeys[KeyStr] = true
                local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]

                local Text = ""
                if _G.AK_GetVal("ESP9_Name") == 1 then Text = Name end
                if _G.AK_GetVal("ESP9_Distance") == 1 and DistStr ~= "" then
                    if Text ~= "" then Text = string.format("%s [%s]", Text, DistStr) else Text = string.format("[%s]", DistStr) end
                end

                local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)

                if not ESPData then
                    local Widget = PlayerMapMarker.CreateESPWidget()
                    if Widget then
                        PlayerMapMarker.ESPWidgets[KeyStr] = { Widget = Widget, Character = Character, Name = Name, LastDistStr = DistStr, TeamID = TeamID }
                        PlayerMapMarker.UpdateESPText(Widget, Text)
                        if bIsAlive then
                            PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                            PlayerMapMarker.ApplyTeamColor(Widget, TeamID)
                            local HP = Character.Health or 0
                            local MaxHP = Character.MaxHealth or 120
                            local pct = 0
                            if HP > 0 and MaxHP > 0 then pct = HP / MaxHP; if pct > 1 then pct = 1 end; if pct < 0 then pct = 0 end end
                            PlayerMapMarker.UpdateESPHealth(Widget, pct)
                            PlayerMapMarker.AddWeaponIconToESP(Widget, Character)
                            if PlayerMapMarker.bUseSnapLines then
                                PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                            else
                                PlayerMapMarker.RemoveSnapLine(KeyStr)
                            end
                            if PlayerMapMarker.bUseSkeleton then
                                PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(TeamID), bOnScreen, Loc)
                            else
                                PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                            end
                        else
                            local Container = Widget.Container or Widget
                            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                            PlayerMapMarker.UpdateESPHealth(Widget, 0)
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                        end
                    end
                else
                    ESPData.Character = Character
                    ESPData.Name = Name
                    ESPData.LastDistStr = DistStr
                    ESPData.TeamID = TeamID
                    PlayerMapMarker.ApplyTeamColor(ESPData.Widget, TeamID)
                    ESPData.Widget._LastESPText = nil
                    PlayerMapMarker.UpdateESPText(ESPData.Widget, Text)
                    PlayerMapMarker.UpdateESPPositionWithPC(ESPData.Widget, Loc, PC, CanvasPos)

                    local HP = Character.Health or 0
                    local MaxHP = Character.MaxHealth or 120
                    local pct = 0
                    if HP > 0 and MaxHP > 0 then pct = HP / MaxHP; if pct > 1 then pct = 1 end; if pct < 0 then pct = 0 end end
                    PlayerMapMarker.UpdateESPHealth(ESPData.Widget, pct)
                    PlayerMapMarker.AddWeaponIconToESP(ESPData.Widget, Character)

                    if PlayerMapMarker.bUseSnapLines then
                        PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                    else
                        PlayerMapMarker.RemoveSnapLine(KeyStr)
                    end
                    if PlayerMapMarker.bUseSkeleton then
                        PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(TeamID), bOnScreen, Loc)
                    else
                        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                    end
                end
            end
        end
    end

    for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
        if not SeenKeys[KeyStr] then
            PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr)
            PlayerMapMarker.ESPWidgets[KeyStr] = nil
        end
    end

    -- Apply enemy name and box
    if _G.AK_GetVal("ENEMY_NAME") == 1 or _G.AK_GetVal("ENEMY_BOX") == 1 then
        local activeKeys = {}
        for PlayerKey, Character in pairs(AllPlayers) do
            if IsValid_ESP9(Character) then
                local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
                local bIsAI = PlayerMapMarker.IsAI(Character)
                local KeyStr = tostring(PlayerKey)
                local bSkip = false
                if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
                if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
                local TeamID = PlayerMapMarker.GetTeamID(Character)
                if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then bSkip = true end
                local bIsAlive = PlayerMapMarker.IsAlive(Character)
                if not bSkip and bIsAlive then
                    local Loc = PlayerMapMarker.GetESPLocation(Character)
                    if Loc then
                        activeKeys[KeyStr] = true
                        PlayerMapMarker:UpdateEnemyBoxAndName(Character, PC, Loc)
                    end
                end
            end
        end
        for key, widget in pairs(EnemyBoxWidgets) do
            if not activeKeys[key] and widget and widget.border and slua.isValid(widget.border) then
                pcall(function() widget.border:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end
        for key, widget in pairs(EnemyNameWidgets) do
            if not activeKeys[key] and widget and widget.text and slua.isValid(widget.text) then
                pcall(function() widget.text:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end
    else
        for key, widget in pairs(EnemyBoxWidgets) do
            if widget and widget.border and slua.isValid(widget.border) then
                pcall(function() widget.border:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end
        for key, widget in pairs(EnemyNameWidgets) do
            if widget and widget.text and slua.isValid(widget.text) then
                pcall(function() widget.text:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end
    end
end

function PlayerMapMarker.UpdateESPLight()
    if RedBoxOverlay and RedBoxOverlay.bActive then RedBoxOverlay.UpdatePosition() end
    if not PlayerMapMarker.bUseScreenESP then return end

    PlayerMapMarker.bUseSnapLines = _G.AK_GetVal("ESP9_Line") == 1
    PlayerMapMarker.bUseSkeleton = _G.AK_GetVal("ESP9_Skeleton") == 1

    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end

    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid_ESP9(PC) then return end

    PlayerMapMarker.UpdateCanvasTransform(PC)

    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end

    for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
        local Widget = ESPData.Widget
        local Character = ESPData.Character
        local Container = Widget and (Widget.Container or Widget)
        local bWidgetValid = false
        pcall(function() bWidgetValid = Container and slua.isValid(Container) end)

        if Widget and bWidgetValid and Character and IsValid_ESP9(Character) then
            local bIsAlive = PlayerMapMarker.IsAlive(Character)
            if not bIsAlive then
                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                PlayerMapMarker.RemoveSnapLine(KeyStr)
                PlayerMapMarker.RemoveSkeletonLines(KeyStr)
            else
                local bShowAnyUI = _G.AK_GetVal("ESP9_Name") == 1 or _G.AK_GetVal("ESP9_Distance") == 1 or _G.AK_GetVal("ESP9_HP") == 1 or _G.AK_GetVal("ESP9_Team") == 1 or _G.AK_GetVal("ESP9_Weapon") == 1
                if bShowAnyUI then
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                else
                    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                end

                local Loc = PlayerMapMarker.GetESPLocation(Character)
                if Loc then
                    local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                    PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)

                    if PlayerMapMarker.bUseSnapLines then 
                        PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
                    else 
                        PlayerMapMarker.RemoveSnapLine(KeyStr) 
                    end

                    if PlayerMapMarker.bUseSkeleton then
                        PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, PlayerMapMarker.GetTeamColor(ESPData.TeamID), bOnScreen, Loc)
                    else
                        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                    end
                else
                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                    PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                end
            end
        end
    end
end

function PlayerMapMarker.UpdateESPDistances()
    if not PlayerMapMarker.bUseScreenESP then return end

    local MyLoc = PlayerMapMarker.GetMyLocation()
    if not MyLoc then return end

    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid_ESP9(PC) then return end

    PlayerMapMarker.UpdateCanvasTransform(PC)

    for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
        local Character = ESPData.Character
        local Widget = ESPData.Widget
        local Container = Widget and (Widget.Container or Widget)
        local bWidgetValid = false
        pcall(function() bWidgetValid = Container and slua.isValid(Container) end)

        if Character and IsValid_ESP9(Character) and Widget and bWidgetValid then
            local Loc = PlayerMapMarker.GetESPLocation(Character)
            if Loc then
                local Dist = PlayerMapMarker.CalcDistance(MyLoc, Loc)
                ESPData.LastDistance = Dist

                if PlayerMapMarker.bShowDistance then
                    local DistStr = ""
                    local Meters = 0
                    if Dist then
                        Meters = Dist / 100
                        if Meters < 1000 then DistStr = string.format("%dm", math.floor(Meters))
                        else DistStr = string.format("%.1fkm", Meters / 1000) end
                    end

                    local Name = ESPData.Name or "Unknown"
                    local Text = ""
                    if _G.AK_GetVal("ESP9_Name") == 1 then Text = Name end
                    if _G.AK_GetVal("ESP9_Distance") == 1 and DistStr ~= "" then
                        if Text ~= "" then Text = string.format("%s [%s]", Text, DistStr) else Text = string.format("[%s]", DistStr) end
                    end

                    ESPData.LastDistStr = DistStr
                    Widget._LastESPText = nil
                    PlayerMapMarker.UpdateESPText(Widget, Text)
                end
            end
        end
    end
end

function PlayerMapMarker.AddWeaponIconToESP(WidgetData, Character)
    if not WidgetData or not WidgetData.Container then return end
    if not _G.AK_GetVal("ESP9_Weapon") == 1 then return end

    pcall(function()
        local Container = WidgetData.Container
        if not Container or not slua.isValid(Container) then return end

        local winfo = Character and PlayerMapMarker.GetCharacterWeaponInfo(Character) or nil
        if not winfo or not winfo.WeaponID or winfo.WeaponID == 0 then return end

        if WidgetData._LastWeaponID == winfo.WeaponID and WidgetData._WeaponIconApplied then return end
        WidgetData._LastWeaponID = winfo.WeaponID
        WidgetData._WeaponIconApplied = true
    end)
end

function PlayerMapMarker.ScanAndUpdate()
    local AllChars = PlayerMapMarker.GetAllCharacters()
    if not AllChars then RedBoxOverlay.SetCounts(0, 0) return 0 end

    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local MyLoc = PlayerMapMarker.GetMyLocation()
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
        else local PC = PlayerMapMarker.GetMyPlayerController() if PC and PC.GetPawn then MyChar = PC:GetPawn() end end
    end)

    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)
    local realPlayers = 0
    local botPlayers = 0

    for PlayerKey, Character in pairs(AllChars) do
        if IsValid_ESP9(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local bIsAlive = PlayerMapMarker.IsAlive(Character)

            if bIsAlive and not bIsMe then
                local bIsMyTeam = false
                if MyTeamID ~= nil then
                    local targetTeamID = PlayerMapMarker.GetTeamID(Character)
                    if targetTeamID == MyTeamID then bIsMyTeam = true end
                end
                if not bIsMyTeam then
                    if bIsAI then botPlayers = botPlayers + 1
                    else realPlayers = realPlayers + 1 end
                end
            end
        end
    end

    if _G.AK_GetVal("ESP9_Count") == 1 then
        if RedBoxOverlay.bActive then RedBoxOverlay.SetCounts(realPlayers, botPlayers)
        else RedBoxOverlay.Start() end
    else
        if RedBoxOverlay.bActive then RedBoxOverlay.Stop() end
    end

    if PlayerMapMarker.bUseScreenESP then
        PlayerMapMarker.UpdateESP(AllChars, MyLoc)
    end

    return 0
end

function PlayerMapMarker.AttachTimers()
    pcall(function()
        local pc = PlayerMapMarker.GetMyPlayerController()
        if not slua.isValid(pc) or not pc.AddGameTimer then return end

        pcall(function() pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function() if PlayerMapMarker.bActive then pcall(function() PlayerMapMarker.ScanAndUpdate() end) end end) end)
        pcall(function() pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.02, true, function() if PlayerMapMarker.bActive then pcall(function() PlayerMapMarker.UpdateESPLight() end) end end) end)
        pcall(function() pc:AddGameTimer(PlayerMapMarker._DistanceUpdateInterval or 0.1, true, function() if PlayerMapMarker.bActive and PlayerMapMarker.bUseScreenESP and PlayerMapMarker.bShowDistance then pcall(function() PlayerMapMarker.UpdateESPDistances() end) end end) end)
    end)
end

function PlayerMapMarker.Start()
    if PlayerMapMarker.bActive then return end
    PlayerMapMarker.bActive = true
    PlayerMapMarker._FrameCount = 0
    PlayerMapMarker.ScanAndUpdate()
    PlayerMapMarker.AttachTimers()
end

function PlayerMapMarker.Stop()
    PlayerMapMarker.bActive = false
    PlayerMapMarker._FrameCount = 0
    PlayerMapMarker.ClearAllESP()
end

_G.PlayerMapMarker = PlayerMapMarker

print("✅ Enemy Name & Box ESP System Loaded!")

-- ========================================================================
-- ⚡ NEW WALLHACK SYSTEM (DrawDyeing + IdeaOutline)
-- ========================================================================
local LinearColor = import("LinearColor")
local CONSOLE_READY = false
local PROCESSED_PAWNS = {}
local TICK_COUNT = 0
local WH_TIMER = nil
local TICK_INTERVAL = 0.3
local MAX_PAWNS_PER_TICK = 20
local RESET_PROCESSED_EVERY = 6
local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}

local colors = {
    vis  = LinearColor(255, 255, 0, 100),
    occ  = LinearColor(0, 255, 255, 100),
    bVis = LinearColor(255, 255, 0, 100),
    bOcc = LinearColor(0, 255, 255, 100)
}

local function SetupConsole()
    if CONSOLE_READY then return end
    pcall(function()
        local KismetSystemLibrary = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KismetSystemLibrary or not world then return end

        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")

        CONSOLE_READY = true
        print("[PBC] Console ready")
    end)
end

local function ApplyToMesh(mesh, visColor, occColor)
    if not mesh or not slua.isValid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function IsPawnAlive(pawn)
    if not slua.isValid(pawn) then return false end
    if pawn.Health and pawn.Health > 0 then return true end
    return false
end

local function PBCtick()
    pcall(function()
        local localPawn = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPawn) then return end

        SetupConsole()
        if not colors then return end

        TICK_COUNT = TICK_COUNT + 1
        if TICK_COUNT % RESET_PROCESSED_EVERY == 0 then
            PROCESSED_PAWNS = {}
        end

        local myTeamId = localPawn.TeamID or 0
        local allPawns = Game:GetAllPlayerPawns() or {}
        local processedCount = 0

        for _, pawn in pairs(allPawns) do
            if processedCount >= MAX_PAWNS_PER_TICK then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end

            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = pcall(Game.IsAI, pawn) and true or false
                local vis = isAI and colors.bVis or colors.vis
                local occ = isAI and colors.bOcc or colors.occ

                pcall(function()
                    if slua.isValid(pawn.Mesh) then
                        ApplyToMesh(pawn.Mesh, vis, occ)
                    end

                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then
                                ApplyToMesh(mesh, vis, occ)
                            end
                        end
                    end

                    pcall(function()
                        local SkeletalMeshComponent = import("SkeletalMeshComponent")
                        if SkeletalMeshComponent then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) and comp ~= pawn.Mesh then
                                        ApplyToMesh(comp, vis, occ)
                                    end
                                end
                            end
                        end
                    end)

                    pcall(function()
                        local StaticMeshComponent = import("StaticMeshComponent")
                        if StaticMeshComponent then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then
                                        ApplyToMesh(comp, vis, occ)
                                    end
                                end
                            end
                        end
                    end)

                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        ApplyToMesh(weapon.Mesh, vis, occ)
                    end
                end)

                if pawn.PlayerKey then PROCESSED_PAWNS[pawn.PlayerKey] = true end
                processedCount = processedCount + 1
            end
            ::continue::
        end
    end)
end

local function StartPBC()
    SetupConsole()
    if not colors then
        print("[PBC] Colors not initialized, aborting")
        return false
    end

    if WH_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end
        end)
        WH_TIMER = nil
    end

    if _G.Game and _G.Game.AddGameTimer then
        WH_TIMER = _G.Game:AddGameTimer(TICK_INTERVAL, true, PBCtick)
        print("[PBC] ✅ Active (Game timer)")
        return true
    end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        WH_TIMER = pc:AddGameTimer(TICK_INTERVAL, true, PBCtick)
        print("[PBC] ✅ Active (PC timer)")
        return true
    end

    print("[PBC] ❌ Could not start timer")
    return false
end

local retryCount = 0
local function RetryStart()
    if retryCount >= 30 then
        print("[PBC] ❌ Failed to start after 30 retries")
        return
    end
    retryCount = retryCount + 1

    if StartPBC() then
        print("[PBC] ✅ Module ready!")
    else
        if _G.Game and _G.Game.AddGameTimer then
            _G.Game:AddGameTimer(1.0, false, RetryStart)
        end
    end
end

function _pbc_Cleanup()
    if WH_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end
        end)
        WH_TIMER = nil
    end
    PROCESSED_PAWNS = {}
    CONSOLE_READY = false
    print("[PBC] 🧹 Cleanup done")
end

function _G.StartNewWallhack()
    if WH_TIMER then return end
    if _G.AK_GetVal("WALLHACK") == 1 then
        RetryStart()
    end
end

-- ========================================================================
-- STRONG BYPASS SYSTEM (Security Module Neutralization)
-- ========================================================================
local nop = function() end
local returnTrue = function() return true end
local returnFalse = function() return false end
local returnZero = function() return 0 end
local returnEmptyTable = function() return {} end

local blockedFuncNames = {
    "reportattackflow", "reportsecattackflow", "reporthurtflow", "reportfirearms",
    "reportverifyinfoflow", "reportmrpcsflow", "reportplayerbehavior", "reportteammathurt",
    "reportmiskillbyteammate", "reportforbitpick", "reportplayermoveroute", "reportplayerposition",
    "reportvehiclemoveflow", "reportsecregamemovingflow", "reportparachutedata",
    "sendtsssdkantidatatolobby", "senddserrorlogtolobby", "senddshawkeyepatrollogtolobby",
    "sendsectlog", "senddataminingtlog", "sendactivitytlog", "sendclientmemusage", "sendclientfps",
    "onclientcrashreport", "onnetworklossdetected", "reportmatchroomdata", "reportplayersping",
    "sendclientstats", "sendserveravgtickdelta", "reporthitflow", "onplayeractorchannelerror",
    "onplayerrpcvalidatefailed", "reportequipmentflow", "reportaimflow",
    "getweaponreport", "getoneweaponreport", "reportheavyweaponboxspawnflow",
    "reportheavyweaponboxactivationflow", "reportheavyweaponboxopenplayerflow",
    "reportheavyweaponboxitemflow", "reportplayersping", "reportplayerip",
    "reportplayerframepingrecord", "ondsconnectionsaturated", "reportdsnetsaturation",
    "reportnetcontinuoussaturate", "reportdsnetrate",
    "reportcircleflow", "reportdscircleflow", "reportjumpflow", "reportaistrategyinfo",
    "sendaideliveryinfo", "reportdailytaskinfo", "reportmatchroomdata", "sendplayerspectatinglog",
    "reportidcardproduceflow", "reportidcardpickupflow", "reportidcarddestroyflow",
    "reportrevivalflow", "reportgamesetting", "reportgamesettingnew", "reportantsvoiceteamcreate",
    "reportantsvoiceteamquit", "reportcommoninfo", "reportlightweightstat", "sendsectlog",
    "senddataminingtlog", "sendactivitytlog", "getgeneraltlogdata",
    "reportwallhack", "reportaimbot", "reportspeedhack",
    "reportplayercontrollerstatechanged", "reportavatarflow", "reportabnormalmaterial",
    "reportdepthtestchange", "reportwallhack", "reportmemoryexception", "reportmaterialscan",
    "reportshaderoverride", "sendsectlog", "senddataminingtlog",
    "reportplayerkillflow", "clientsecplayerkillflow", "checkreportsecattackflow",
    "checkreportsecattackflowwithattackflow", "isenablereportplayerkillflow",
    "isenablereportmrpcsincircleflow", "isenablereportmrpcsintpartcircleflow",
    "isenablereportmrpcsflow", "isenablereporthitflow", "isenablereportcircleflow",
    "onplayernetconnectionclosed", "onplayeractorchannelerror",
    "onplayerrpcvalidatefailed", "onplayerspectateexception", "onshutdownaftererror",
    "heartbeat", "sendheartbeat", "clientheartbeat", "serverheartbeat",
    "swifthawk", "clientswifthawk", "clientswifthawkwithparams", "swifthawkreport", "swifthawkdata",
    "anticheatreport", "cheatdetection", "violationreport", "securityviolation",
    "integritycheck", "signatureverify", "md5", "hash", "filecheck", "pakcheck"
}

local origRequire = require
local securityPathPatterns = {"Security", "AntiCheat", "Integrity", "ReportPlayer", "HawkEye", "SwiftHawk", "Ban", "TssSdk", "ShootVerify", "CoronaLab", "HiggsBoson"}

local function isSecurityModule(name)
    for _, p in ipairs(securityPathPatterns) do
        if name:find(p, 1, true) then return true end
    end
    return false
end

local dummyModules = {
    ["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"] = true,
    ["GameLua.Mod.BaseMod.Common.Security.AvatarCheckCallback"] = true,
    ["GameLua.Mod.BaseMod.Common.Security.GameSafeCallbacks"] = true,
}

_G.require = function(name)
    if dummyModules[name] then
        return { bMHActive = false, BlackList = {} }
    end
    local mod = origRequire(name)
    if type(mod) == "table" and isSecurityModule(name) and not mod.__ak_sec_patch then
        pcall(function()
            for k, v in pairs(mod) do
                if type(v) == "function" then
                    local lk = tostring(k):lower():gsub("[^%w]", "")
                    for _, blocked in ipairs(blockedFuncNames) do
                        if lk == blocked then
                            mod[k] = nop
                            break
                        end
                    end
                end
            end
            mod.__ak_sec_patch = true
        end)
    end
    return mod
end

local securitySubsystemNames = {
    "FileCheckSubsystem", "IntegrityCheckSubsystem", "PakCheckSubsystem",
    "ClientWallhackDetectionSubsystem", "ClientESPDetectionSubsystem",
    "ClientAimTrackingSubsystem", "ClientAntiCheatSubsystem",
    "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem",
    "CoronaLabSubsystem", "PlayerSecurityInfoSubsystem",
    "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem",
    "ShootVerifySubSystemClient", "MemoryCheckSubsystem",
    "SpeedCheckSubsystem", "WallCheckSubsystem",
    "BehaviorScoreSubsystem", "AFKReportorSubsystem",
    "AvatarExceptionSubsystem", "GameReportSubsystem",
    "SwiftHawkSubsystem", "HeartbeatSubsystem",
    "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem",
    "ModifierExceptionSubsystem", "SimulateCharacterSubsystem",
    "ClientRenderCheckSubsystem", "ClientMemoryGuardSubsystem",
    "ClientKernelCheckSubsystem"
}

local SubsystemMgr_inst = nil
pcall(function() SubsystemMgr_inst = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr") end)

if SubsystemMgr_inst and not SubsystemMgr_inst.__ak_intercept then
    local realGet = SubsystemMgr_inst.Get
    SubsystemMgr_inst.Get = function(self, name)
        local sub = realGet(self, name)
        if type(sub) == "table" and not sub.__ak_sub_silenced then
            for _, secName in ipairs(securitySubsystemNames) do
                if name == secName then
                    for k, v in pairs(sub) do
                        if type(v) == "function" then
                            local lk = tostring(k):lower():gsub("[^%w]", "")
                            for _, blocked in ipairs(blockedFuncNames) do
                                if lk == blocked then
                                    sub[k] = nop
                                    break
                                end
                            end
                        end
                    end
                    sub.__ak_sub_silenced = true
                    break
                end
            end
        end
        return sub
    end
    SubsystemMgr_inst.__ak_intercept = true
end

-- ========================================================================
-- BRPlayerCharacterBase CLASS
-- ========================================================================
local BRPlayerCharacterBase = {
    ServerRPC = {},
    ClientRPC = {},
    MulticastRPC = {}
}

BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = { Reliable = true, Params = { UEnums.EPropertyClass.UInt32, UEnums.EPropertyClass.UInt32 } }

function BRPlayerCharacterBase:ctor()
    self.bHasShownDevNotice = false
    self.AK_NativeESP_Ready = false
    self.bHiggsTimerSet = false
    self._newWallhackStarted = false
    self._lastAimbotTime = 0
    self._monitorsSetup = false
    self._bypassActive = false
end

function BRPlayerCharacterBase:_PostConstruct()
    BRPlayerCharacterBase.__super._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
    self:StartAdvancedSystems()
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
    BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
    self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)

    if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
        if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
            Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
        end
    end

    if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
    end

    if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
    end

    if Client then
        GameplayData.AddCharacter(self.Object)
    else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
    end

    EventSystem:postEvent(EVENTTYPE_SINGLETRAINING, EVENTID_CHARACTER_BEGINPLAY, self.Object)
end

function BRPlayerCharacterBase:ReceiveEndPlay(endPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, endPlayReason)
    if Client and GameplayData.RemoveCharacter then GameplayData.RemoveCharacter(self.Object) end
end

-- ========================================================================
-- STARTADVANCEDSYSTEMS - ALL LOGIC IN TIMER
-- ========================================================================
function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end
    if not CheckExpiration() then ShowExpiryPopup(true); return end

    if not self.bHiggsTimerSet then
        self.bHiggsTimerSet = true
        self:AddGameTimer(0.1, true, function()
            if not slua.isValid(self.Object) then return end
            pcall(function()
                local lpc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if slua.isValid(lpc) and lpc.HiggsBosonComponent then
                    lpc.HiggsBosonComponent.bMHActive = false
                end
            end)
        end)
    end

    self:AddGameTimer(0.4, true, function()
        if not slua.isValid(self.Object) then return end
        if not CheckExpiration() then ShowExpiryPopup(true); return end

        local localPlayer = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPlayer) then return end

        if self.Object == localPlayer then
            if not localPlayer._bypassActive then
                localPlayer._bypassActive = true
                pcall(function()
                    if _G.WHABypass and _G.WHABypass.Init then
                        _G.WHABypass.Init()
                        _G._WHA_BYPASS_ACTIVE = true
                    end
                end)

            end

            if not localPlayer._monitorsSetup then
                localPlayer._monitorsSetup = true

                localPlayer:AddGameTimer(0.5, true, function()
                    if not _G._WHA_BYPASS_ACTIVE then
                        pcall(function()
                            if _G.WHABypass and _G.WHABypass.Init then
                                _G.WHABypass.Init()
                                _G._WHA_BYPASS_ACTIVE = true
                            end
                        end)
                    end
                end)

                localPlayer:AddGameTimer(10.0, true, function()
                    pcall(function()
                        if _G.WHABypass and _G.WHABypass.Init then
                            _G.WHABypass.Init()
                            _G._WHA_BYPASS_ACTIVE = true
                        end
                    end)
                end)
            end

            if not self._newWallhackStarted then
                self._newWallhackStarted = true
                pcall(function()
                    if _G.StartNewWallhack then _G.StartNewWallhack() end
                end)
            end

            local enemyCounterEnabled = (_G.AK_GetVal("ENEMY_COUNTER") == 1)
            if enemyCounterEnabled and not _G.ENEMY_COUNTER_TIMER then
                _G.StartEnemyCounter()
            elseif not enemyCounterEnabled and _G.ENEMY_COUNTER_TIMER then
                _G.StopEnemyCounter()
            end

            if _G.AK_GetVal("ESP_V2") == 1 then
                if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
                    _G.PlayerMapMarker.Start()
                end
            else
                if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then
                    _G.PlayerMapMarker.Stop()
                end
            end

            _G.AKModTickCount = (_G.AKModTickCount or 0) + 1
            if _G.AKModTickCount % 6 == 0 then cleanupDeadEnemyMarks() end

            -- Do not mutate the global ScreenMarkConfig; this avoids
            -- creating/overloading custom map-mark widgets.
            self.AK_NativeESP_Ready = true

            local enemyCharacters = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
            local isMapESP = _G.AK_GetVal("ESP_MAP")
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()

            for _, enemy in pairs(enemyCharacters) do
                if slua.isValid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                    local isDead = false
                    pcall(function()
                        if type(enemy.IsDead)=="function" then isDead = enemy:IsDead()
                        elseif enemy.bIsDead then isDead = true end
                        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then isDead = true end
                    end)

                    if isDead then goto skip_enemy end

                    processEnemyMapESP(enemy, localPlayer, isMapESP)

                    -- Native HP map mark disabled to prevent extra mark/UI objects.
                    if enemy.bHasAKNativeHPBar then
                        pcall(function()
                            if InGameMarkTools and InGameMarkTools.ClientRemoveMapMark then
                                InGameMarkTools.ClientRemoveMapMark(enemy.NativeHPBarMark)
                            end
                        end)
                        enemy.NativeHPBarMark = nil
                        enemy.bHasAKNativeHPBar = false
                    end

                    if _G.AK_GetVal("ESP_BOX") == 1 then
                        pcall(function()
                            if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then
                                enemy:Replay_CreateEnemyFrameUI(true, true)
                            end
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                        end)
                    end

                    ::skip_enemy::
                end
            end

            if _G.AK_GetVal("AIMBOT") == 1 then
                ApplyHardAimbot()
                StartChestAimbot()
            end
        end
    end)
end

-- ========================================================================
-- INITIALIZATION
-- ========================================================================
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(3, function() if CheckExpiration() then end end)
        ticker.AddTimerOnce(4, function()
            if not CheckExpiration() then ShowExpiryPopup(true) else _G.TryShowWelcome() end
        end)
    else
        _G.TryShowWelcome()
    end
end)

function _G.InitializeAllSystems()
    if not CheckExpiration() then ShowExpiryPopup(true); return end
    local gameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if gameplayData then
        pcall(function()
            local pc = gameplayData.GetPlayerCharacter and gameplayData.GetPlayerCharacter()
            if slua.isValid(pc) then pc.StartAdvancedSystems = BRPlayerCharacterBase.StartAdvancedSystems end
        end)
    end
end

_G.InitializeAllSystems()

-- ========================================================================
-- CLASS DECLARATION
-- ========================================================================
local class = require("class")
local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local BRCharacterClass = class(CharacterBase, nil, BRPlayerCharacterBase)

return require("combine_class").DeclareFeature(BRCharacterClass, {
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
