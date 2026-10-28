-- Lunar V9.6: original game code preserved; ESP V2 retained, V1 and wall removed
-- Native settings revision, welcome only, Hack menu last (2026-10-08)
-- Fresh camera projections; retained feature switches, range and render limits.
-- Actor-free widget pools flush on canvas/world reset; optional total callback profiling.
-- Title: New hud based smooth ESP by @UXOfficial
-- BRPlayerCharacterBase NEW ESP made by @UXOfficial

_G.g_UXOfficial = _G.g_UXOfficial or "@VIP FILE"
local g_UXOfficial_credit = _G.g_UXOfficial

local g_UXOfficial_StartSettingsMaintenance

-- ============================================================================
-- ORIGINAL GAME CODE START | BRPlayerCharacterBase
-- Native RPCs, imports, lifecycle, movement, parachute, vehicle and emote logic.
-- The supplied original game code below is preserved verbatim.
-- ============================================================================
local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ECharacterHideMovementAcive = import("ECharacterHideMovementAcive")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
    self:AddControlEvent(self, "OnPawnRespawnDelegate", self.OnRespawnRehideCheck, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:OnRespawnRehideCheck()
  if not self:GetEnsure() then
    return
  end
  self:AddGameTimer(0.5, false, function()
    if not slua.isValid(self.Object) then
      return
    end
    if self:HasState(EPawnState.InPlane) then
      self:SetCharacterHideInGame(true, true, true, 1, ECharacterHideMovementAcive.Normal)
      print(bWriteLog and "BRPlayerCharacterBase:OnRespawnRehideCheck re-hide AI on plane, PlayerKey:", self.PlayerKey)
    end
  end)
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")

  local function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end

  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

local VICTORY_DANCE_FX_MAP = {
  [12219601] = 22010089
}
local PublishRegionMacros = require("client.slua.config.ClientMacros.PublishRegionMacros")
local isFitVersion = PublishRegionMacros.IsFITVersion()

local function ResolveEmoteResID(ItemID)
  local FxID = VICTORY_DANCE_FX_MAP[ItemID]
  if not FxID or FxID == ItemID then
    return ItemID
  end
  local model_util = require("client.common.model_util")
  local FxBPID = model_util.GetBPID(FxID)
  local ResID = ItemID
  if FxBPID and 0 < FxBPID and model_util.IsBattleItemHandleExist("Emote", FxBPID, false, false) then
    ResID = FxID
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase 11 ResolveEmoteResID ItemID:%s, FxID:%s, FxBPID:%s, ResID:%s", tostring(ItemID), tostring(FxID), tostring(FxBPID), tostring(ResID)))
  if isFitVersion and ResID == 12219601 then
    print(bWriteLog and "BRPlayerCharacterBase ResolveEmoteResID 12219601 to 12222069")
    return 12222069
  end
  return ResID
end

function BRPlayerCharacterBase:GetEmoteHandlePath(ItemID)
  local ResID = ResolveEmoteResID(ItemID)
  if self.Super then
    return self.Super:GetEmoteHandlePath(ResID)
  end
  local model_util = require("client.common.model_util")
  local BPID = model_util.GetBPID(ResID)
  if not BPID or BPID <= 0 then
    return ""
  end
  return model_util.GetPath("Emote", BPID, false, false) or ""
end

function BRPlayerCharacterBase:GetEmoteHandle(ItemID)
  local ResID = ResolveEmoteResID(ItemID)
  if self.Super then
    return self.Super:GetEmoteHandle(ResID)
  end
  local model_util = require("client.common.model_util")
  local BPID = model_util.GetBPID(ResID)
  if not BPID or BPID <= 0 then
    return nil
  end
  local HandleClass = model_util.GetClass("Emote", BPID, false, false)
  if not HandleClass then
    return nil
  end
  local Handle = HandleClass()
  if not slua.isValid(Handle) then
    return nil
  end
  return Handle
end

-- ORIGINAL GAME CODE END | BRPlayerCharacterBase

-- ============================================================================
-- ============================================================================
-- BYPASS START
-- ============================================================================
-- ============================================================================
-- ESP reporting and detection hooks
-- Source: BRPlayerCharacterBase.lua (118 KB script) — Bypass.lua integrated
-- Auto-runs on pawn spawn and respawn.
-- Wrapped with BYPASS START / BYPASS END markers for later separation.
-- ============================================================================

do -- V9.5 integration: scope helper locals below the Lua chunk limit.
local function _BYPASS_InstallESPHandlers()
    if _G.__UXOfficial_ESP_BYPASS_LOADED then return end

    local nop = function() end

    local function isBypassActive()
        return _G._ESP_BYPASS_ACTIVE == true
    end

    -- Non-wall ESP/reporting hooks retained from the supplied integration.
    ---------- LAYER 8: Kernel & memory spoof ----------
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

    ---------- LAYER 9: MARK SYSTEM SPOOF ----------
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        local MarkMgr = InGameMarkTools and InGameMarkTools.ScreenMarkManager
        if MarkMgr then
            local ourMarkGroups = {1006, 9999}
            if MarkMgr.GetAllActiveMarks then
                local orig = MarkMgr.GetAllActiveMarks
                MarkMgr.GetAllActiveMarks = function(self, ...)
                    local marks = orig(self, ...)
                    if not isBypassActive() or not marks or type(marks) ~= "table" then return marks end
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
                    if isBypassActive() then count = math.max(0, count - 2) end
                    return count
                end
            end
            if MarkMgr.GetMarksByGroup then
                local orig = MarkMgr.GetMarksByGroup
                MarkMgr.GetMarksByGroup = function(self, groupId)
                    if isBypassActive() and (groupId == 1006 or groupId == 9999) then return {} end
                    return orig(self, groupId)
                end
            end
            if MarkMgr.OnAddMark then MarkMgr.OnAddMark = nop end
            if MarkMgr.OnRemoveMark then MarkMgr.OnRemoveMark = nop end
        end
    end)

    ---------- LAYER 10: REPLAY UI DETECTION KILL ----------
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

    ---------- LAYER 13: ESP-RELATED REPORT FUNCTIONS KILL ----------
    pcall(function()
        local espReports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "SendESPData","UploadESPInfo"
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

    ---------- LAYER 14: NETWORK ESP PACKET BLOCK ----------
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

    _G.__UXOfficial_ESP_BYPASS_LOADED = true
    print("[ok] ESP reporting handlers installed")
end

-- ========================================================================
-- ESP REPORT HANDLERS + DETECTION SUBSYSTEM HOOKS
-- ========================================================================
local function _BYPASS_SetupESPBypassTable()
    local bypass = {}
    local function nop() end
    local function returnTrue() return true end
    local function returnFalse() return false end
    local function safe_require(mod)
        local ok, res = pcall(require, mod)
        return ok and res or nil
    end
    local function tryImport(name)
        local ok, lib = pcall(import, name)
        return ok and lib or nil
    end

    local function blockScreenshots()
        pcall(function()
            local SS = tryImport("ScreenshotMaker") or tryImport("ScreenshotMTDer")
            if SS then
                SS.MakePicture = function() return "" end
                SS.ReMakePicture = function() return "" end
                SS.HasCaptured = returnTrue
            end
        end)
    end

    local function blockGameplayCallbacks()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        if GC._ESPReportHooksApplied then return end

        local reportFuncs = {
            "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
            "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportAimFlow","ReportHitFlow",
            "ReportAimbot","ReportSpeedHack","ReportMagicBullet",
            "ReportAbnormalMaterial","ReportDepthTestChange","ReportMemoryException",
            "ReportMaterialScan","ReportShaderOverride","ReportCircleFlow",
            "OnPlayerRPCValidateFailed","OnPlayerActorChannelError",
            "OnPlayerSpectateException","OnShutdownAfterError"
        }
        for _, fn in ipairs(reportFuncs) do GC[fn] = nop end

        local oldStateChanged = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, state, ...)
            if state and type(state) == "string" then
                local s = state:lower()
                if s:find("cheat") or s:find("ban") or s:find("integrity") then return end
            end
            if oldStateChanged then return oldStateChanged(UID, state, ...) end
        end

        GC._ESPReportHooksApplied = true
    end

    local function spoofTssSdk()
        pcall(function()
            local t = _G.TssSdk
            if t then
                t.GetFileMD5 = function() return "" end
                t.VerifyFileSignature = returnTrue
                t.CheckIntegrity = returnTrue
                t.ScanMemory = function() return true, {} end
                t.IsEmulator = returnFalse
                t.OnRecvData = nop
            end
        end)
    end

    local function disableDetectionSubsystems()
        local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not sm then return end

        local targetSubs = {
            "ClientESPDetectionSubsystem",
            "ClientAimTrackingSubsystem", "ShootVerifySubSystemClient",
            "ClientRenderCheckSubsystem", "ClientMemoryGuardSubsystem",
            "ClientKernelCheckSubsystem", "ClientHawkEyePatrolSubsystem",
            "ClientAntiCheatSubsystem", "IntegrityCheckSubsystem",
            "FileCheckSubsystem", "AvatarExceptionSubsystem"
        }
        for _, sn in ipairs(targetSubs) do
            local sub = sm:Get(sn)
            if sub and type(sub) == "table" then
                for k, v in pairs(sub) do
                    if type(v) == "function" then
                        if k:find("Report") or k:find("Send") or k:find("Verify") or
                           k:find("Check") or k:find("Detect") or k:find("Scan") then
                            sub[k] = nop
                        end
                    end
                end

                if sn == "ClientESPDetectionSubsystem" then                elseif sn == "ClientESPDetectionSubsystem" then
                    sub.HasESP = returnFalse
                    sub.CheckOverlay = function() return "clean" end
                elseif sn == "ClientAimTrackingSubsystem" then
                    sub.GetAimData = function()
                        return { accuracy = math.random(45,65), headshotRate = math.random(15,35) }
                    end
                    sub.IsAimNormal = returnTrue
                elseif sn == "ClientMemoryGuardSubsystem" then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult = function() return "clean" end
                elseif sn == "ShootVerifySubSystemClient" then
                    sub.OnShootVerifyFailed = nop
                    sub.VerifyShot = returnTrue
                end
            end
        end
    end

    local function disableHiggsBoson()
        pcall(function()
            local hbc = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if hbc then
                hbc.bMHActive = false
                hbc.bCallPreReplication = false
                if hbc.ControlMHActive then hbc.ControlMHActive = nop end
                if hbc.StartAvatarCheck then hbc.StartAvatarCheck = nop end
                if hbc.BlackList then
                    for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end
                end
            end
            if _G.AvatarCheckCallback then
                _G.AvatarCheckCallback.StartAvatarCheck = nop
                _G.AvatarCheckCallback.OnReportItemID = nop
            end
            _G.BlackList = {}
        end)
    end

    function bypass.Init()
        blockScreenshots()
        blockGameplayCallbacks()
        spoofTssSdk()
        disableDetectionSubsystems()
        disableHiggsBoson()
    end

    _G.ESPBypass = bypass
end

-- ========================================================================
-- BYPASS EXECUTION
-- ========================================================================
local function _BYPASS_Execute()
    if _G._BYPASS_DONE then return end
    local ok, err = pcall(function()
        _G._ESP_BYPASS_ACTIVE = true
        _BYPASS_InstallESPHandlers()
        _BYPASS_SetupESPBypassTable()
        if _G.ESPBypass and _G.ESPBypass.Init then
            _G.ESPBypass.Init()
        end
        _G._BYPASS_DONE = true
        print("[ORDER] All bypasses executed")
    end)
    if not ok then
        print("[ORDER] Bypass failed, will retry:", tostring(err))
        _G._BYPASS_DONE = false
    end
end

-- Expose globally so callback bridge / any other scope can trigger it.
_G._BYPASS_Execute = _BYPASS_Execute
end -- V9.5 integration: exported callback retains the scoped helpers.

-- ============================================================================
-- ============================================================================
-- BYPASS END
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- MAIN SCRIPT CALLBACK BRIDGE | tracking and settings maintenance
-- Each adapter runs the original game callback once, then its existing addition.
-- ============================================================================
do
    local additions={
        ReceiveBeginPlay=function(self)
            _G.g_UXOfficial_TrackedCharacters=_G.g_UXOfficial_TrackedCharacters or {}
            if self.Object then _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=self.Object end
            if g_UXOfficial_StartSettingsMaintenance then pcall(g_UXOfficial_StartSettingsMaintenance,self) end
            -- AUTO BYPASS TRIGGER: runs on pawn spawn.
            if _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
        end,
        ReceiveEndPlay=function(self)
            if _G.g_UXOfficial_TrackedCharacters and self.Object then
                _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=nil
            end
        end,
        BPOnRespawned=function(self)
            _G.g_UXOfficial_TrackedCharacters=_G.g_UXOfficial_TrackedCharacters or {}
            if self.Object then _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=self.Object end
            -- AUTO BYPASS TRIGGER on respawn as well.
            if _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
        end,
        ReceiveOnRecycle=function(self)
            if _G.g_UXOfficial_TrackedCharacters and self.Object then
                _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=nil
            end
        end,
        ReceiveOnSpawn=function(self)
            _G.g_UXOfficial_TrackedCharacters=_G.g_UXOfficial_TrackedCharacters or {}
            if self.Object then _G.g_UXOfficial_TrackedCharacters[tostring(self.Object)]=self.Object end
            -- AUTO BYPASS TRIGGER on spawn.
            if _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end
        end,
    }
    for name,addition in pairs(additions) do
        local originalCallback=BRPlayerCharacterBase[name]
        local afterCallback=addition
        BRPlayerCharacterBase[name]=function(self,...)
            originalCallback(self,...)
            if Client then afterCallback(self) end
        end
    end
end
-- MAIN SCRIPT CALLBACK BRIDGE END

-- Immediate bypass attempt on script load (in case a pawn is already present).
if Client and _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end

_G.LexusConfig = _G.LexusConfig or {}
_G.LexusConfig.IpadView = _G.LexusConfig.IpadView or false
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
_G.LexusState.CustomTextData.IpadViewFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120

-- g_UXOfficial_GetLocalPlayer made by @UXOfficial
local function g_UXOfficial_GetLocalPlayer()
    local ok, GDP = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GDP then return nil end
    local player = GDP.GetPlayerCharacter()
    if player and slua.isValid(player) then return player end
    return nil
end

-- g_UXOfficial_ApplyiPadView made by @UXOfficial
local function g_UXOfficial_ApplyiPadView()
    local player = g_UXOfficial_GetLocalPlayer()
    if not player then return end
    local cam = player.ThirdPersonCameraComponent
    if not cam or not slua.isValid(cam) then return end
    if player.bIsWeaponAiming then return end

    if _G.LexusConfig.IpadView then
        local targetFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120
        if cam.FieldOfView ~= targetFOV then
            cam.FieldOfView = targetFOV
        end
    else
        if cam.FieldOfView ~= 90 then
            cam.FieldOfView = 90
        end
    end
end

-- Persistent ESP feature settings.
local g_UXOfficial_ESPOptionDefaults = {
    Name=false, Line=false, Box=false, Health=false, Distance=false, Skeleton=false, Counter=false, Radar=false
}
_G.g_UXOfficial_ESPOptions = _G.g_UXOfficial_ESPOptions or {}
for k,v in pairs(g_UXOfficial_ESPOptionDefaults) do
    if _G.g_UXOfficial_ESPOptions[k] == nil then _G.g_UXOfficial_ESPOptions[k] = v end
end
local g_UXOfficial_ESPSettingsFile = "UXOfficial_UMG_ESP_settings.lua"
local function g_UXOfficial_ESPSettingsPaths()
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        "ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile,
        g_UXOfficial_ESPSettingsFile
    }
    local home=nil
    pcall(function() if os and os.getenv then home=os.getenv("HOME") end end)
    if type(home)=="string" and home~="" then
        table.insert(paths,1,home.."/Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_UXOfficial_ESPSettingsFile)
    end
    return paths
end
-- Replace the SaveGames file only after write/flush/close succeed where Lua
-- exposes rename. A failed temporary write keeps the last saved file intact.
local function g_UXOfficial_ESPWriteSettings(path,payload)
    local atomic=os and type(os.rename)=="function"
    local target=atomic and path..".tmp" or path
    local opened,file=pcall(io.open,target,"w")
    if not opened or not file then return false,"Open failed: "..target end
    local closed=false
    local ok,err=pcall(function()
        local result,reason=file:write(payload)
        assert(result,reason or "Settings write failed")
        if file.flush then local flushed,why=file:flush();assert(flushed,why or "Settings flush failed") end
        local result,reason=file:close();closed=true
        assert(result,reason or "Settings close failed")
    end)
    if not closed then pcall(function() file:close() end) end
    if ok and atomic then
        local called,result,reason=pcall(os.rename,target,path)
        ok=called and result~=nil and result~=false
        err=ok and nil or (reason or result or "Settings rename failed")
    end
    if not ok and atomic and os.remove then pcall(os.remove,target) end
    return ok,err,atomic
end

local g_UXOfficial_ESPLoadedSettingsPath=nil

local function g_UXOfficial_ESPLoadSettings()
    if not io or type(io.open) ~= "function" then return false end
    local paths = g_UXOfficial_ESPSettingsPaths()
    local content=nil
    for _,path in ipairs(paths) do
        local ok,f=pcall(io.open,path,"r")
        if ok and f then
            local rok,text=pcall(function() return f:read("*a") end)
            pcall(function() f:close() end)
            if rok and type(text)=="string" and text~="" then content=text;g_UXOfficial_ESPLoadedSettingsPath=path;break end
        end
    end
    if not content then return false end
    for k in pairs(g_UXOfficial_ESPOptionDefaults) do
        local v=content:match(k.."%s*=%s*(true)") or content:match(k.."%s*=%s*(false)")
        if v then _G.g_UXOfficial_ESPOptions[k]=(v=="true") end
    end
    return true
end
g_UXOfficial_ESPLoadSettings()

-- Welcome-only UI, no login form, license requests or key handling.
do
    local UI={Version="LunarUI.V9.WelcomeOnly.1"}
    local function member(o,k)
        if o==nil then return nil end
        local ok,v=pcall(function() return o[k] end);if ok then return v end
    end
    local function valid(o)
        if o==nil then return false end
        local ok,v=pcall(slua.isValid,o);return ok and v==true
    end
    local vectorClass=rawget(_G,"FVector2D") or import("Vector2D")
    local colorClass=rawget(_G,"FLinearColor") or import("LinearColor")
    local function vector(x,y) return vectorClass(x,y) end
    local function color(r,g,b,a)
        local function linear(v) v=v/255;if v<=0.04045 then return v/12.92 end;return ((v+0.055)/1.055)^2.4 end
        return colorClass(linear(r),linear(g),linear(b),a or 1)
    end
    local function visibility(w,v)
        local fn=member(w,"SetWidgetVisibility") or member(w,"SetVisibility")
        assert(type(fn)=="function","UI_VISIBILITY_UNAVAILABLE");fn(w,v)
    end
    local function parent()
        local ok,t=pcall(require,"GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(member(t,"GetMainControlBaseUI"))~="function" then return end
        local found,root=pcall(t.GetMainControlBaseUI);if not found or not valid(root) then return end
        local p=member(root,"CanvasPanel_0");if not valid(p) then p=member(root,"CanvasPanel_42") end
        if valid(p) then return p end
    end
    local function destroy(d)
        if not d then return end
        d.Visible=false
        if d.Event and d.Handle~=nil then pcall(function() d.Event:Remove(d.Handle) end) end
        if valid(d.Container) then pcall(function() d.Container:RemoveFromParent() end) end
        d.Event=nil;d.Handle=nil;d.Container=nil;d.Parent=nil
        d.Button=nil;d.Title=nil;d.Detail=nil;d.Hint=nil;d.Design=nil;d.Cache=nil
    end
    -- Premium black-and-gold frame, dark heading, warm gold accents.
    -- All gradient/angle/brush work happens at construction. No animation,
    -- background asset, network dependency, text outline or external backdrop.
    function UI.Build()
        local p=parent();if not p then return nil,"UI_NOT_READY" end
        local enums=UEnums.ESlateVisibility
        local passive=enums.SelfHitTestInvisible
        if enums.Visible==nil or passive==nil then return nil,"UI_ENUM_UNAVAILABLE" end
        local W,H=600,276
        local scale=0.8
        pcall(function()
            local v=p:GetCachedGeometry():GetLocalSize()
            if v.X>24 and v.Y>24 then scale=math.min(scale,(v.X-24)/W,(v.Y-24)/H) end
        end)
        local d={Parent=p,Visible=false,Scale=scale}
        local ok,buildError=pcall(function()
            local function make(class,outer)
                local w=CGame:NewObjectFromPath("/Script/UMG."..class,outer)
                assert(valid(w),"UI_WIDGET_UNAVAILABLE");return w
            end
            d.Container=make("CanvasPanel",p)
            local design=make("CanvasPanel",d.Container);d.Design=design
            local artRoot=design
            local canCache,cache=pcall(make,"InvalidationBox",d.Container)
            if canCache and valid(cache) and type(member(cache,"SetCanCache"))=="function" then
                local attached=pcall(function()cache:AddChild(design);cache:SetCanCache(true);visibility(cache,passive)end)
                if attached then artRoot=cache;d.Cache=cache end
            end
            local artSlot=d.Container:AddChildToCanvas(artRoot)
            artSlot:SetAutoSize(false);artSlot:SetPosition(vector(0,0));artSlot:SetSize(vector(W,H));artSlot:SetZOrder(1)
            visibility(design,passive)
            local function add(w,x,y,ww,hh,z,dynamic)
                local slot=(dynamic and d.Container or design):AddChildToCanvas(w)
                slot:SetAutoSize(false);slot:SetPosition(vector(x,y));slot:SetSize(vector(ww,hh));slot:SetZOrder(z)
                return slot
            end
            local function rect(x,y,ww,hh,c,z)
                local w=make("Border",d.Container);w:SetBrushColor(c);visibility(w,passive)
                add(w,x,y,ww,hh,z);return w
            end
            local function sample(stops,t,opacity)
                t=math.max(0,math.min(1,t));local a,b,u
                if t<=.5 then a,b,u=stops[1],stops[2],t*2 else a,b,u=stops[2],stops[3],(t-.5)*2 end
                return color(a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u,a[3]+(b[3]-a[3])*u,opacity)
            end
            local function panel(x,y,ww,hh,cut,stops,z,columns,opacity)
                columns=math.min(columns,12) -- Static cached gradient geometry.
                for i=0,columns-1 do
                    local a=ww*i/columns;local b=ww*(i+1)/columns
                    local inset=math.max(0,cut-math.min(a,ww-b))
                    rect(x+a,y+inset,b-a,hh-inset*2,sample(stops,(i+.5)/columns,opacity),z)
                end
            end
            local function rail(x,y,ww,hh,stops,z,columns)
                columns=math.min(columns,12)
                for i=0,columns-1 do
                    rect(x+ww*i/columns,y,ww/columns,hh,sample(stops,(i+.5)/columns),z)
                end
            end
            local function line(ax,ay,bx,by,th,c,z)
                local dx,dy=bx-ax,by-ay
                local len=math.sqrt(dx*dx+dy*dy)
                if len<=0 then return end
                local angle
                if dx==0 then angle=dy>=0 and 90 or -90
                else angle=math.atan(dy/dx)*180/math.pi;if dx<0 then angle=angle+180 end end
                local w=rect((ax+bx-len)/2,(ay+by-th)/2,len,th,c,z)
                w:SetRenderTransformPivot(vector(.5,.5));w:SetRenderAngle(angle)
            end
            local slate=import("SlateColor")
            local fontObject
            if slua and type(slua.loadObject)=="function" then
                local loaded,obj=pcall(slua.loadObject,"/Engine/EngineFonts/Roboto.Roboto")
                if loaded and valid(obj) then fontObject=obj end
            end
            local function style(w,size,c,bold)
                local font=member(w,"Font")
                if font then
                    if type(font)=="table" then local copy={};for k,v in pairs(font) do copy[k]=v end;font=copy end
                    font.Size=size
                    if fontObject then font.FontObject=fontObject;font.TypefaceFontName=bold and "Bold" or "Regular" end
                    if font.OutlineSettings then
                        local outline=font.OutlineSettings
                        if type(outline)=="table" then local copy={};for k,v in pairs(outline) do copy[k]=v end;outline=copy end
                        outline.OutlineSize=0;font.OutlineSettings=outline
                    end
                    w:SetFont(font)
                end
                w:SetColorAndOpacity(slate(c))
                pcall(function()w:SetShadowOffset(vector(0,0));w:SetShadowColorAndOpacity(color(0,0,0,0))end)
                pcall(function() w:SetAutoWrapText(true) end)
            end
            local function text(value,x,y,ww,hh,size,c,z,bold,center,dynamic)
                local w=make("TextBlock",d.Container);w:SetText(value);style(w,size,c,bold)
                visibility(w,passive);add(w,x,y,ww,hh,z,dynamic)
                if center then pcall(function() w:SetJustification(1) end) end
                return w
            end
            local frame={{92,65,25},{212,175,55},{255,226,140}}
            local bright={{128,94,31},{255,225,130},{255,245,200}}
            local edge={{20,16,8},{91,68,22},{20,16,8}}
            local body={{12,12,14},{24,21,15},{12,12,14}}
            local header={{8,8,10},{28,23,12},{8,8,10}}
            local gold={{110,78,20},{230,190,70},{255,232,150}}
            local white=color(255,255,255)
            local forest=color(238,202,105)
            -- Perimeter only: an opaque full-panel backing would destroy
            -- the requested body transparency even with alpha on the body.
            panel(6,6,W-12,H-12,10,body,2,24,.76)
            rail(13,0,W-26,6,frame,3,24)
            rail(13,H-6,W-26,6,frame,3,24)
            rect(0,13,6,H-26,color(212,175,55),3)
            rect(W-6,13,6,H-26,color(255,226,140),3)
            rail(13,1,W-26,1.5,bright,3,24)
            rail(13,H-3,W-26,1.5,edge,3,24)
            rect(1,13,1.5,H-26,color(128,94,31),3)
            rect(W-3,13,1.5,H-26,color(255,245,200),3)
            for _,s in ipairs({{1,13,13,1},{1,H-13,13,H-1}}) do line(s[1],s[2],s[3],s[4],2,color(230,190,70),3) end
            for _,s in ipairs({{W-13,1,W-1,13},{W-13,H-1,W-1,H-13}}) do line(s[1],s[2],s[3],s[4],2,color(255,232,150),3) end
            panel(10,10,W-20,65,16,gold,4,24)
            panel(13,13,W-26,59,14,header,5,32)
            d.Title=text("Welcome to @diablomodshacks Lua mod",24,22,W-48,42,19,white,7,true,true)
            local pw=math.min(340,W-72);local px=(W-pw)/2
            panel(px,99,pw,51,12,gold,4,16)
            panel(px+3,102,pw-6,45,10,{{28,23,12},{64,48,16},{28,23,12}},5,20)
            d.Detail=text("Kill limit 8-10",px+16,109,pw-32,34,23,white,7,true,true)
            d.Hint=text("Play smart and avoid report",30,165,W-60,32,17,forest,7,true,true)
            local button=make("Button",d.Container);d.Button=button
            local by,bh,bw=212,42,202;local bx=(W-bw)/2
            panel(bx-4,by-3,bw+8,bh+6,9,gold,4,16)
            panel(bx,by,bw,bh,8,{{91,65,18},{190,145,35},{110,78,20}},5,16)
            pcall(function() button:SetBackgroundColor(color(255,255,255,0)) end)
            visibility(button,enums.Visible)
            local label=make("TextBlock",button);label:SetText("OK");style(label,17,white,true);visibility(label,passive)
            local labelSlot=button:AddChild(label)
            pcall(function() labelSlot:SetHorizontalAlignment(2);labelSlot:SetVerticalAlignment(2) end)
            add(button,bx,by,bw,bh,9,true)
            d.Event=button.OnClicked
            d.Handle=d.Event:Add(function()
                if not d.Visible or d.Busy then return end
                destroy(d);d.Dismissed=true
                local welcome=_G.LunarWelcomeRuntime
                if welcome and welcome.WelcomeUI==d then welcome.WelcomeUI=nil end
            end)
            local slot=p:AddChildToCanvas(d.Container);slot:SetAutoSize(false);slot:SetSize(vector(W,H));slot:SetZOrder(9200)
            local anchors=slot:GetAnchors();anchors.Minimum=vector(.5,.5);anchors.Maximum=vector(.5,.5)
            slot:SetAnchors(anchors);slot:SetAlignment(vector(.5,.5));slot:SetPosition(vector(0,0))
            d.Container:SetRenderTransformPivot(vector(.5,.5));d.Container:SetRenderScale(vector(scale,scale))
            visibility(d.Container,passive)
        end)
        if not ok then UI.LastBuildError=tostring(buildError);destroy(d);return nil,"UI_BUILD_UNAVAILABLE" end
        UI.LastBuildError=nil
        d.Visible=true;return d
    end
    _G.LunarUIAssetCache=nil
    -- Existing welcome widgets are retired cleanly on hot reload.
    local previous=_G.LunarWelcomeRuntime or _G.LunarLoginRuntime
    if previous and type(previous.DestroyUI)=="function" then pcall(previous.DestroyUI) end
    _G.LunarLoginRuntime=nil -- Remove the old login runtime, including any visible panel.
    local L={NeedsUpdate=true,WelcomeShown=true,UIFactory=UI}
    _G.LunarWelcomeRuntime=L
    L.DestroyUI=function()
        destroy(L.WelcomeUI)
        L.WelcomeUI=nil
    end
    L.Update=function()
        if L.WelcomeShown then L.NeedsUpdate=false;return end
        local d=UI.Build()
        if d then L.WelcomeUI=d;L.WelcomeShown=true;L.NeedsUpdate=false end
    end
    -- Delete legacy login entry points; the UI no longer collects credentials.
    _G.UXOfficialLicenseLogin=nil
    _G.UXOfficialLicenseLogout=nil
    _G.UXOfficialLicenseStatus=nil
end

-- Settings registration follows the supplied working native-page reference.
-- Feature rows and option values remain owned by this script.
local g_UXOfficial_EnsureHackMenu
do
    local VERSION = "LunarSettings.V9.6.LastPage.NoV1NoWall"
    local function runtime()
        local state = _G.LunarNativeSettingsRuntime
        if type(state) ~= "table" then state = {}; _G.LunarNativeSettingsRuntime = state end
        return state
    end
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function loadTable(name)
        local ok, value = pcall(require, name)
        if not ok then
            if package and package.loaded and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = nil
            end
            error(name .. ": " .. tostring(value), 0)
        end
        assert(type(value) == "table", name .. ": SETTINGS_MODULE_NOT_READY")
        return value
    end
    local function register(catalog, page)
        if type(catalog) ~= "table" or type(page) ~= "table" then return false end
        -- A live page already occupying the last slot needs no mutation.
        if catalog[#catalog] == page then
            local duplicate = false
            for i = 1, #catalog - 1 do
                if type(catalog[i]) == "table" and catalog[i].Key == "HackMenu" then
                    duplicate = true
                    break
                end
            end
            if not duplicate then return true end
        end
        for i = #catalog, 1, -1 do
            local entry = catalog[i]
            if type(entry) == "table" and entry.Key == "HackMenu" then
                table.remove(catalog, i)
            end
        end
        catalog[#catalog+1] = page
        return true
    end
    local function looksLikeCatalog(value, allowEmpty)
        if type(value) ~= "table" then return false end
        local first = value[1]
        if type(first) == "table" and first.Key ~= nil then return true end
        return allowEmpty and next(value) == nil
    end
    local function isMainSettings(config)
        local key
        if type(config) == "string" then key = config
        else
            key = member(config, "keyName") or member(config, "KeyName")
                or member(config, "key") or member(config, "Key")
        end
        if key == nil then return false end
        local lower = string.lower(tostring(key))
        return lower:find("setting_main", 1, true) ~= nil
            and lower:find("custom", 1, true) == nil
    end
    local function injectShowCatalog(manager, config, args, count)
        local actual, first = config, 1
        if config == manager then actual, first = args[1], 2 end
        if not isMainSettings(actual) then return end
        local state = runtime()
        if not state.Page then return end
        state.LastShowUIInjected = false
        for i = first, count do
            if looksLikeCatalog(args[i], false) then
                state.LastShowUIInjected = register(args[i], state.Page)
                state.LastShowUICatalogIndex = i
                break
            end
        end
        if not state.LastShowUIInjected and looksLikeCatalog(args[first], true) then
            state.LastShowUIInjected = register(args[first], state.Page)
            state.LastShowUICatalogIndex = first
        end
    end
    local function installManagers(state)
        local managers = {}
        local function add(manager)
            if manager == nil then return end
            for _, current in ipairs(managers) do if current == manager then return end end
            managers[#managers + 1] = manager
        end
        add(_G.UIManager)
        local ok, loaded = pcall(loadTable, "client.slua_ui_framework.manager")
        if ok then add(loaded); state.ManagerModuleError = nil
        else state.ManagerModuleError = tostring(loaded) end
        local count = 0
        for _, manager in ipairs(managers) do
            local show = member(manager, "ShowUI")
            if type(show) == "function" then
                local record = member(manager, "__LunarSettingsUIHook")
                if type(record) ~= "table" or record.Version ~= VERSION or record.Wrapper ~= show then
                    -- Unwrap our previous version instead of nesting its older
                    -- ShowUI handler, which could reinsert this tab at the top.
                    local baseShow = show
                    if type(record) == "table" and record.Wrapper == show and
                        type(record.Original) == "function" then
                        baseShow = record.Original
                    end
                    record = {Version = VERSION, Original = baseShow}
                    record.Wrapper = function(config, ...)
                        local current = runtime()
                        -- Register again before opening, including rebuilt mode catalogs.
                        if not current.Initializing and type(current.Ensure) == "function" then
                            pcall(current.Ensure)
                        end
                        local args, n = {...}, select('#', ...)
                        injectShowCatalog(manager, config, args, n)
                        return record.Original(config, (table.unpack or unpack)(args, 1, n))
                    end
                    manager.ShowUI = record.Wrapper
                    manager.__LunarSettingsUIHook = record
                end
                count = count + 1
            end
        end
        state.Managers = managers
        state.HookCount = count
        state.HookInstalled = count > 0
        return state.HookInstalled
    end
    local function restoreAliases(state, aliases)
        for _, manager in ipairs(state.Managers or {}) do
            local config = member(manager, "UI_Config")
            if config then
                for _, key in ipairs({"Switcher", "Slider"}) do
                    if type(aliases[key]) ~= "table" then
                        local value = member(config, "Setting_Option_" .. key)
                        if type(value) == "table" then aliases[key] = value end
                    end
                end
            end
        end
    end
    local function syncModeCatalogs(state)
        local names = {"GameLua.Mod.BaseMod.Client.Config.SettingCatalog",
            "GameLua.Mod.D350.Client.Config.SettingCatalog",
            "GameLua.Mod.PlanPH.Client.Config.SettingCatalog"}
        for i, name in ipairs(names) do
            local catalog = package and package.loaded and package.loaded[name]
            if type(catalog) ~= "table" and i == 1 then
                local ok, value = pcall(loadTable, name)
                if ok then catalog = value; state.ModeCatalogError = nil
                else state.ModeCatalogError = tostring(value) end
            end
            if type(catalog) == "table" then register(catalog, state.Page) end
        end
    end
    local function buildPage(F, AliasMap, sliderReady)
    local function featureState() return _G.LunarFeatures end
    local function value(c,v) if v==nil then return c end return v end
    local function espAll()
        return {Key="LunarV2_All",UI=AliasMap.Switcher,Text="All ESP",
            LunarBulk=true,
            SwitcherText={"All On","All Off"},
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function() return featureState().GetESPAll(2) end,
            SetFunc=function(c,v) return featureState().SetESPAll(2,value(c,v)) end}
    end
    local function espSwitch(key,label)
        return {Key="UXOfficialESP_"..key,
            UI=AliasMap.Switcher,Text=label,
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function() return _G.g_UXOfficial_ESPOptions[key]==true end,
            SetFunc=function(c,v) return featureState().SetESP(2,key,value(c,v)) end}
    end
    local V2={espAll(),
        espSwitch("Name","ESP NAME"),espSwitch("Line","ESP LINE"),espSwitch("Box","ESP BOX"),
        espSwitch("Health","ESP HEALTH"),espSwitch("Distance","ESP DISTANCE"),
        espSwitch("Skeleton","ESP SKELETON"),espSwitch("Counter","ESP COUNTER"),espSwitch("Radar","RADAR MAP")}
    local Other={
        {Key="LunarIpad",UI=AliasMap.Switcher,Text="iPad View",ExpandIndex=0,
            GetFunc=function() return _G.LexusConfig.IpadView end,
            SetFunc=function(c,v) featureState().SetIpad(value(c,v));return true end},
        {Key="LunarAim",UI=AliasMap.Switcher,Text="Aimbot V1",ExpandIndex=0,
            EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
            GetFunc=function() return featureState().Settings.AimEnabled end,
            SetFunc=function(c,v) featureState().SetAim(value(c,v));return true end}
    }
    -- Verified native settings item contract: absolute Min/Max values, native
    -- key/value callbacks, and expansion events owned by the game's page.
    local function rangeItem(key,label,lo,hi,parent,get,set)
        return {Key=key,UI=AliasMap.Slider,Text=label,Min=lo,Max=hi,ExpandHandle=parent,
            GetFunc=function() return get() end,
            SetFunc=function(c,v)
                featureState()[set](value(c,v))
                featureState().Save(true)
                return true
            end}
    end
    if sliderReady then
        table.insert(Other,2,rangeItem("LunarIpadFOV","iPad FOV",90,120,"LunarIpad",
            function() return featureState().Settings.IpadFOV end,"SetIpadFOV"))
    end
    if sliderReady then
        Other[#Other+1]=rangeItem("LunarAimSpeed","Aim speed",100,120,"LunarAim",
            function() return featureState().Settings.AimSpeed end,"SetAimSpeed")
    end
    Other[#Other+1]={Key="LunarAimTarget",UI=AliasMap.Switcher,Text="Aim target",ExpandHandle="LunarAim",
        SwitcherText={"Head","Body","Leg"},SwitcherValue={1,2,3},
        GetFunc=function() return featureState().Settings.AimTarget end,
        SetFunc=function(c,v) featureState().SetAimTarget(value(c,v));return true end}
    Other[#Other+1]={Key="LunarAim2",UI=AliasMap.Switcher,Text="Aimbot V2",
        EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
        GetFunc=function() return featureState().Settings.Aim2Enabled end,
        SetFunc=function(c,v) featureState().SetAim2(value(c,v));return true end}
    Other[#Other+1]={Key="LunarMortarAim",UI=AliasMap.Switcher,Text="Mortar aim",
        GetFunc=function() return featureState().Settings.MortarEnabled end,
        SetFunc=function(c,v) featureState().SetMortar(value(c,v));return true end}
    local page={Key="HackMenu",Text="✦ VIP GOLD ✦",UIKey="Setting_Page_Privacy",Category={
        {Key="Lunar_ESP_V2",Text="✦ ESP V2 ✦",Stack=V2},
        {Key="Lunar_Other",Text="✦ GOLD FEATURES ✦",Stack=Other}
    }}

        return page
    end
    local function initialize(state)
        local F = _G.LunarFeatures
        assert(type(F) == "table", "FEATURE_RUNTIME_NOT_READY")
        local pages = loadTable("client.logic.NewSetting.SettingPageDefine")
        local catalog = loadTable("client.logic.NewSetting.SettingCatalog")
        local aliases = loadTable("client.slua.umg.NewSetting.Item.AliasMap")
        restoreAliases(state, aliases)
        assert(type(aliases.Switcher) == "table", "AliasMap.Switcher_not_ready")

        -- Missing optional sliders must not hide the entire settings tab.
        -- Rebuild with both original slider rows as soon as their UI is available.
        local sliderReady = type(aliases.Slider) == "table"
        local compact = aliases.CompactSwitcher or aliases.Switcher
        local rebuild = state.Version ~= VERSION or not state.Page
            or state.Features ~= F or state.Alias ~= aliases
            or state.Switcher ~= aliases.Switcher or state.Slider ~= aliases.Slider
            or state.CompactSwitcher ~= compact
        if rebuild then
            state.Page = buildPage(F, aliases, sliderReady)
            state.PageBuilds = (state.PageBuilds or 0) + 1
        end
        state.Version, state.Features, state.PageDefine, state.Catalog = VERSION, F, pages, catalog
        state.Alias, state.Switcher, state.Slider = aliases, aliases.Switcher, aliases.Slider
        state.CompactSwitcher = compact
        state.SliderReady = sliderReady
        state.DeferredSliderRows = sliderReady and 0 or 2
        pages.HackMenu = state.Page
        state.Registered = register(catalog, state.Page)
        syncModeCatalogs(state)

        -- Bulk selector enhancement is optional; its failure cannot block the page.
        local okClass, switchClass = pcall(loadTable, "client.slua.umg.NewSetting.Item.Setting_Option_Switcher")
        if okClass and type(F.InstallNativeBulkSwitch) == "function" then
            local okBulk, result = pcall(F.InstallNativeBulkSwitch, switchClass)
            state.BulkSwitchReady = okBulk and result == true
            state.BulkSwitchError = not okBulk and tostring(result) or nil
        else
            state.BulkSwitchReady = false
            state.BulkSwitchError = not okClass and tostring(switchClass) or "BULK_SWITCH_HELPER_UNAVAILABLE"
        end
        state.Ready = state.Registered and state.HookInstalled == true
        if state.Ready then
            state.LastError = nil
            _G.HackMenuInitialized = "UXOfficial_NATIVE_SETTINGS_V9_2"
        else state.LastError = "SETTINGS_UI_MANAGER_NOT_READY" end
        return state.Ready
    end
    g_UXOfficial_EnsureHackMenu = function()
        local state = runtime()
        state.Ensure = g_UXOfficial_EnsureHackMenu
        if state.Initializing then return false end
        state.Initializing = true
        state.Attempts = (state.Attempts or 0) + 1
        -- Install early even when page/alias modules are still loading.
        local okHook, hookError = pcall(installManagers, state)
        if not okHook then state.HookInstalled = false; state.HookError = tostring(hookError)
        else state.HookError = nil end
        local ok, result = pcall(initialize, state)
        state.Initializing = false
        if not ok then state.Ready = false; state.LastError = tostring(result) end
        return ok and result == true
    end
    _G.LunarSettingsDiagnostics = function()
        local state = runtime()
        local timer = _G.__UXOfficialShotFastRunner
        return {version = state.Version, ready = state.Ready == true,
            registered = state.Registered == true, attempts = state.Attempts or 0,
            lastError = state.LastError, hookInstalled = state.HookInstalled == true,
            hookCount = state.HookCount or 0, hookError = state.HookError,
            managerModuleError = state.ManagerModuleError,
            pageBuilt = state.Page ~= nil, pageBuilds = state.PageBuilds or 0,
            pageUIKey = state.Page and state.Page.UIKey or nil,
            sliderReady = state.SliderReady == true, deferredSliderRows = state.DeferredSliderRows,
            lastShowUIInjected = state.LastShowUIInjected,
            lastShowUICatalogIndex = state.LastShowUICatalogIndex,
            maintenanceProvider = type(timer) == "table" and timer.Provider or nil,
            maintenanceError = type(timer) == "table" and timer.LastError or nil}
    end
end

-- ESP configuration made by @UXOfficial
_G.g_UXOfficial_UXOfficialShotESP = _G.g_UXOfficial_UXOfficialShotESP or {

    Enabled = true,
    MaxRangeMeters = 450.0,

    -- Target 60 updates/sec when the engine timer permits. No skeleton decimation.
    -- Discovery is separate from rendering; every rendered pose uses fresh projections.
    ScanInterval = 0.35,
    UpdateInterval = 1.0 / 60.0,
    WidgetBuildBudget = 96, -- New line widgets per update; existing widgets stay live.
    Profile = false,       -- Optional CPU timing in _G.g_UXOfficial_ESPDiagnostics.
    TransformInterval = 0.60,
    MaxRendered = 8,

    CounterY = 36.0,
    CounterWidth = 400.0,
    CounterHeight = 58.0,
    CounterDiamondSize = 0.0,

    TracerThickness = 1.80,
    NameGap = 2.0,
    NameFontSize = 14,
    DistanceFontSize = 20,
    DistanceBelowFeet = 8.0,
}
if (tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRendered) or 0) < 1 then
    _G.g_UXOfficial_UXOfficialShotESP.MaxRendered = 8
end
if (tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters) or 0) < 400.0 then
    _G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters = 450.0
end
-- Upgrade a table retained by an earlier hot-reload to the new readable marker size.
if (tonumber(_G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize) or 0) < 20 then
    _G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize = 20
end
-- Premium enemy/bot counter dimensions.
_G.g_UXOfficial_UXOfficialShotESP.CounterWidth=400.0
_G.g_UXOfficial_UXOfficialShotESP.CounterHeight=58.0
_G.g_UXOfficial_UXOfficialShotESP.CounterDiamondSize=0.0

-- Upgrade only the shipped 30 Hz default on the first performance revision.
if not _G.g_UXOfficial_UXOfficialShotESP.PerformanceRevision then
    if _G.g_UXOfficial_UXOfficialShotESP.UpdateInterval == 0.033 then
        _G.g_UXOfficial_UXOfficialShotESP.UpdateInterval = 1.0 / 60.0
    end
    _G.g_UXOfficial_UXOfficialShotESP.PerformanceRevision = 1
end
_G.UXOfficialShotESP = _G.g_UXOfficial_UXOfficialShotESP

-- ESP runtime state made by @UXOfficial
local g_UXOfficial_ShotESP = {
    Canvas = nil,
    RootUI = nil,
    Counter = nil,
    Enemies = {},
    Lines = {},
    Names = {},
    Boxes = {},
    HealthBars = {},
    Skeletons = {},
    Headers = {},
    Footers = {},
    BuildStage = {},
    BoneNameCache = {},
    Decorations = {},
    TemplateFont = nil,
    TemplateFontObject = nil,
    TemplateTypeface = nil,
    TemplateColorAndOpacity = nil,
    LastScanClock = -999.0,
    LastTransformClock = -999.0,
    LastWorld = nil,
    TracerOrigin = nil,

    CanvasScaleX = 1.0,
    CanvasScaleY = 1.0,
    CanvasOffsetX = 0.0,
    CanvasOffsetY = 0.0,
    ViewportW = nil,
    ViewportH = nil,
    RawViewportW = nil,
    RawViewportH = nil,
    HeaderRoots = {},
    Active = {},
    Alive = {},
    BoneMeshes = {},
    BonePoints = {},
    TimerClock = 0.0,
    Now = 0.0,
    Disabled = false,
    -- Bot detection result cache (avoids repeated IsAI calls every frame)
    _BotCache = {},
    RealCount = 0,
    BotCount = 0,
    RadarLines = {},
    RadarLastCanvas = nil,
    RadarUI = nil,
    RadarOpen = false,
    RadarCanvas = nil,
}

local V2 = _G.FVector2D
if not V2 then pcall(function() V2 = import("Vector2D") end) end
local V3 = _G.FVector
if not V3 then pcall(function() V3 = import("Vector") end) end
local LinearColor = _G.FLinearColor
if not LinearColor then pcall(function() LinearColor = import("LinearColor") end) end
local Anchors = _G.FAnchors
if not Anchors then pcall(function() Anchors = import("Anchors") or import("/Script/Slate.Anchors") end) end
local SlateBlueprintLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
local WidgetLayoutLibrary = nil
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
local SlateColor = nil
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
local KismetTextLibrary = nil
pcall(function() KismetTextLibrary = import("KismetTextLibrary") or import("/Script/Engine.KismetTextLibrary") end)
local GameplayStaticsESP = nil
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local ESPGameplayData=nil
pcall(function() ESPGameplayData=require("GameLua.GameCore.Data.GameplayData") end)

-- g_UXOfficial_ESPV2 made by @UXOfficial
local function g_UXOfficial_ESPV2(x, y)
    if V2 then return V2(x, y) end
    return {X = x, Y = y}
end

local function g_UXOfficial_ESPV3(x, y, z)
    if V3 then
        local ok, v = pcall(V3, x, y, z)
        if ok and v then return v end
    end
    return {X = x, Y = y, Z = z}
end

-- ESP color made by @UXOfficial
local function g_UXOfficial_ESPColor(r, g, b, a)
    if LinearColor then return LinearColor(r, g, b, a or 1.0) end
    return {R=r, G=g, B=b, A=a or 1.0}
end

-- ESP color theme made by @UXOfficial
local ESP_REAL = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0) -- visible target: yellow
local ESP_BOT  = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0) -- visible target: yellow
local ESP_COVER_RED = g_UXOfficial_ESPColor(1.0, 0.02, 0.02, 1.0) -- target behind cover: red
local ESP_WHITE = g_UXOfficial_ESPColor(1.0, 1.0, 1.0, 1.0)
local ESP_NAME_YELLOW = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0)
local ESP_SKELETON_YELLOW = g_UXOfficial_ESPColor(1.0, 0.92, 0.05, 1.0)
local ESP_BLACK = g_UXOfficial_ESPColor(0.0, 0.0, 0.0, 1.0)
local ESP_TEXT_CLEAR = g_UXOfficial_ESPColor(0.0,0.0,0.0,0.0)
local ESP_HEADER_BG = g_UXOfficial_ESPColor(0.0, 0.0, 0.0, 0.78)
local ESP_COUNTER_RED = g_UXOfficial_ESPColor(1.0, 0.72, 0.16, 1.0) -- premium gold
local ESP_COUNTER_RED_DARK = g_UXOfficial_ESPColor(0.045, 0.028, 0.008, 1.0) -- black-gold panel
local ESP_COUNTER_BLUE = g_UXOfficial_ESPColor(1.0, 0.84, 0.32, 1.0) -- bright gold
local ESP_COUNTER_BLUE_DARK = g_UXOfficial_ESPColor(0.075, 0.048, 0.012, 1.0) -- deep gold shadow
local ESP_COUNTER_CENTER = g_UXOfficial_ESPColor(0.035, 0.025, 0.008, 1.0)

-- ESP gradient color made by @UXOfficial
local function g_UXOfficial_ESPScaleColor(color, factor, alphaMul)
    if not color then return g_UXOfficial_ESPColor(1, 1, 1, 1) end
    local r = math.max(0.0, math.min(1.0, (tonumber(color.R) or 1.0) * (factor or 1.0)))
    local g = math.max(0.0, math.min(1.0, (tonumber(color.G) or 1.0) * (factor or 1.0)))
    local b = math.max(0.0, math.min(1.0, (tonumber(color.B) or 1.0) * (factor or 1.0)))
    local a = math.max(0.0, math.min(1.0, (tonumber(color.A) or 1.0) * (alphaMul or 1.0)))
    return g_UXOfficial_ESPColor(r, g, b, a)
end

local ESP_REAL_DARK  = g_UXOfficial_ESPScaleColor(ESP_REAL, 0.68, 1.0)
local ESP_REAL_LIGHT = g_UXOfficial_ESPScaleColor(ESP_REAL, 1.12, 0.82)
local ESP_BOT_DARK   = g_UXOfficial_ESPScaleColor(ESP_BOT, 0.68, 1.0)
local ESP_BOT_LIGHT  = g_UXOfficial_ESPScaleColor(ESP_BOT, 1.10, 0.82)
local ESP_WHITE_SOFT = g_UXOfficial_ESPColor(0.94, 0.94, 0.94, 0.98)
local ESP_WHITE_GLOSS = g_UXOfficial_ESPColor(1.0, 1.0, 1.0, 0.34)

local g_UXOfficial_ESPTheme
do
local ESP_REAL_THEME = {Key="REAL_WHITE_BOX",Main=ESP_WHITE,Light=ESP_WHITE,
    Text=ESP_NAME_YELLOW,
    Background=g_UXOfficial_ESPColor(0.05,0.005,0.005,0.97),
    Empty=g_UXOfficial_ESPColor(0.055,0.008,0.008,1.0)}
local ESP_BOT_THEME = {Key="BOT_WHITE_BOX",Main=ESP_WHITE,Light=ESP_WHITE,
    Text=ESP_NAME_YELLOW,
    Background=g_UXOfficial_ESPColor(0.005,0.05,0.015,0.97),
    Empty=g_UXOfficial_ESPColor(0.008,0.055,0.018,1.0)}
g_UXOfficial_ESPTheme=function(isBot)
    return isBot and ESP_BOT_THEME or ESP_REAL_THEME
end
end
-- ESP object validation made by @UXOfficial
local function g_UXOfficial_ESPValid(obj)
    if not obj then return false end
    if not slua or not slua.isValid then return false end
    local ok, valid = pcall(slua.isValid, obj)
    return ok and valid == true
end

local ESPShared={}
function ESPShared.Finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
function ESPShared.SafeNumber(value,fallback,lo,hi)
    local n=tonumber(value)
    if not ESPShared.Finite(n) then n=fallback end
    return math.max(lo,math.min(hi,n))
end
function ESPShared.VectorComponents(v) return tonumber(v.X),tonumber(v.Y),tonumber(v.Z) end
function ESPShared.VectorValues(v)
    if v==nil then return nil end
    local ok,x,y,z=pcall(ESPShared.VectorComponents,v)
    if ok and ESPShared.Finite(x) and ESPShared.Finite(y) and ESPShared.Finite(z)
        and math.abs(x)<1e12 and math.abs(y)<1e12 and math.abs(z)<1e12 then return x,y,z end
end

-- ESP timing made by @UXOfficial
local function g_UXOfficial_ESPNow()
    local t = nil
    pcall(function()
        local w = (slua and slua.getWorld and slua.getWorld()) or nil
        if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
            t = GameplayStaticsESP.GetRealTimeSeconds(w)
        end
    end)
    t=tonumber(t)
    if ESPShared.Finite(t) and t>=0 then return t end
    -- os.clock measures CPU time on some platforms, not elapsed frame time.
    -- If the engine clock is unavailable, advance by executed timer delays.
    return ESPShared.SafeNumber(g_UXOfficial_ShotESP.TimerClock,0.0,0.0,1e12)
end

-- ESP world access made by @UXOfficial
local function g_UXOfficial_ESPWorld()
    local w = nil
    pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
    return w
end

-- ESP player controller made by @UXOfficial
local function g_UXOfficial_ESPGetController()
    local pc = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
    end)
    if not g_UXOfficial_ESPValid(pc) then
        pcall(function()
            if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
        end)
    end
    return g_UXOfficial_ESPValid(pc) and pc or nil
end

-- ESP local player made by @UXOfficial
local function g_UXOfficial_ESPGetLocalCharacter()
    local c = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP then
            if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
            if not g_UXOfficial_ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
        end
    end)
    if not g_UXOfficial_ESPValid(c) then
        local pc = g_UXOfficial_ESPGetController()
        pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
    end
    return g_UXOfficial_ESPValid(c) and c or nil
end

-- g_UXOfficial_ESPGetPlayerState made by @UXOfficial
local function g_UXOfficial_ESPGetPlayerState(character)
    if not g_UXOfficial_ESPValid(character) then return nil end
    local ps = nil
    pcall(function()
        if character.GetPlayerStateSafety then ps = character:GetPlayerStateSafety() end
    end)
    if not g_UXOfficial_ESPValid(ps) then
        pcall(function() if character.GetPlayerState then ps = character:GetPlayerState() end end)
    end
    if not g_UXOfficial_ESPValid(ps) then
        pcall(function() ps = character.PlayerState end)
    end
    return g_UXOfficial_ESPValid(ps) and ps or nil
end

-- g_UXOfficial_ESPNormalizeName made by @UXOfficial
local function g_UXOfficial_ESPNormalizeName(value)
    if value == nil or value == false then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or not text then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" or text == "UNKNOWN" then return nil end
    if text:find("^userdata:") or text:find("^table:") then return nil end
    return text
end

-- ESP player name made by @UXOfficial
local function g_UXOfficial_ESPResolvePlayerName(character)
    if not g_UXOfficial_ESPValid(character) then return nil end
    local name = nil

-- take made by @UXOfficial
    local function take(value)
        if not name then name = g_UXOfficial_ESPNormalizeName(value) end
    end

    pcall(function() if character.GetPlayerNameSafety then take(character:GetPlayerNameSafety()) end end)
    pcall(function() if not name and character.GetPlayerName then take(character:GetPlayerName()) end end)
    pcall(function() if not name then take(character.PlayerName) end end)
    pcall(function() if not name then take(character.NickName) end end)
    pcall(function() if not name then take(character.AIPlayerName) end end)
    pcall(function() if not name then take(character.BotName) end end)

    if not name then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
            pcall(function() if not name then take(ps.PlayerName) end end)
            pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
            pcall(function() if not name then take(ps.NickName) end end)
            pcall(function() if not name then take(ps.AccountName) end end)
            pcall(function() if not name then take(ps.AIPlayerName) end end)
        end
    end
    return name
end

-- g_UXOfficial_ESPGetPlayerKey made by @UXOfficial
local function g_UXOfficial_ESPGetPlayerKey(character)
    local key = nil
    pcall(function() if character.GetPlayerKey then key = character:GetPlayerKey() end end)
    if key == nil then pcall(function() key = character.PlayerKey end) end
    if key == nil then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then pcall(function() key = ps.PlayerKey end) end
    end
    if key == nil or tostring(key) == "" or tostring(key) == "0" or tostring(key) == "-1" then
        return tostring(character)
    end
    return tostring(key) .. "_" .. tostring(character)
end

-- ESP team detection made by @UXOfficial
local function g_UXOfficial_ESPGetTeamID(character)
    if not g_UXOfficial_ESPValid(character) then return nil end
    local id = nil
    pcall(function() if character.GetTeamID then id = character:GetTeamID() end end)
    if id == nil then pcall(function() id = character.TeamID end) end
    if id == nil then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
            if id == nil then pcall(function() id = ps.TeamID end) end
        end
    end
    return id
end

-- ESP alive detection made by @UXOfficial
local ESPFinishedLastBreath,ESPDeadPawnState
pcall(function() ESPFinishedLastBreath=import("ECharacterHealthStatus").FinishedLastBreath end)
pcall(function() ESPDeadPawnState=EPawnState and EPawnState.Dead end)
local function ESPActorField(actor,key) return actor[key] end
local function ESPReadActorField(actor,key)
    local ok,value=pcall(ESPActorField,actor,key)
    if ok then return value end
end
local function ESPReadActorMethod(actor,key,...)
    local method=ESPReadActorField(actor,key)
    if type(method)=="function" then
        local ok,value=pcall(method,actor,...)
        if ok then return value end
    end
end
local function ESPActorDeadFlag(actor,key)
    local value=ESPReadActorField(actor,key)
    return value==true or value==1
end
local function g_UXOfficial_ESPIsAlive(character)
    if not g_UXOfficial_ESPValid(character) then return false end
    if ESPActorDeadFlag(character,"bDead") or ESPActorDeadFlag(character,"bIsDead")
        or ESPActorDeadFlag(character,"bIsDeadFlag") then return false end
    if ESPFinishedLastBreath~=nil
        and ESPReadActorField(character,"HealthStatus")==ESPFinishedLastBreath then return false end
    if ESPDeadPawnState~=nil
        and ESPReadActorMethod(character,"HasPawnState",ESPDeadPawnState)==true then return false end
    if ESPReadActorMethod(character,"IsDead")==true then return false end
    local alive=ESPReadActorMethod(character,"IsAlive")
    -- A native alive result retains knocked players; terminal death above wins.
    if type(alive)=="boolean" then return alive end
    local hp=ESPReadActorField(character,"Health")
    if type(hp)~="number" then hp=ESPReadActorField(character,"HP") end
    if type(hp)~="number" then hp=ESPReadActorMethod(character,"GetHealth") end
    if type(hp)=="number" then return hp==hp and hp>0 end
    return true
end

-- Bot cache uses the same actor/player key as pruning, with replication retries.
local function g_UXOfficial_ESPIsBot(character, key, providedCache, providedNow)
    if not g_UXOfficial_ESPValid(character) then return false end
    key = key or g_UXOfficial_ESPGetPlayerKey(character)
    local cache = providedCache or g_UXOfficial_ShotESP._BotCache
    local now = providedNow or g_UXOfficial_ShotESP.Now
    local entry = cache[key]
    if entry and now >= entry.Clock and now - entry.Clock < 2.0 then return entry.Value end
    local result = nil
    local function take(v)
        if result == nil and (v == true or v == false or v == 1 or v == 0) then
            result = (v == true or v == 1)
        end
    end
    pcall(function() if Game and Game.IsAI then take(Game:IsAI(character)) end end)
    if result == nil then pcall(function() take(character.bIsAI) end) end
    if result == nil then pcall(function() if character.IsBot then take(character:IsBot()) end end) end
    if result == nil then
        local ps = g_UXOfficial_ESPGetPlayerState(character)
        if ps then
            pcall(function() take(ps.bIsABot) end)
            pcall(function() take(ps.bIsBot) end)
            pcall(function() take(ps.bIsAI) end)
            if result == nil then pcall(function() if ps.IsBot then take(ps:IsBot()) end end) end
        end
    end
    -- Unresolved replication data is never cached as a permanent false.
    cache[key] = result ~= nil and {Value=result, Clock=now} or nil
    return result == true
end

-- ESP actor position made by @UXOfficial
local function g_UXOfficial_ESPActorLocation(character)
    local loc = nil
    if not g_UXOfficial_ESPValid(character) then return nil end
    pcall(function()
        if character.K2_GetActorLocation then loc = character:K2_GetActorLocation()
        elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(character) end
    end)
    return loc
end

-- ESP distance calculation made by @UXOfficial
local function g_UXOfficial_ESPDistanceMeters(a,b)
    local ax,ay,az=ESPShared.VectorValues(a)
    local bx,by,bz=ESPShared.VectorValues(b)
    if not ax or not bx then return math.huge end
    local dx,dy,dz=ax-bx,ay-by,az-bz
    return math.sqrt(dx*dx+dy*dy+dz*dz)/100.0
end


-- A memo lives for one scheduler callback only.
-- Callback-local values never retain actors, controllers or native locations
-- after Finish. The bounded pool keeps only reusable vector buffers.
ESPShared.Frame={Active=false,Entries={},Pool={},PoolLimit=256,Now=0,ViewAt=-999,Controllers={},Transforms={},TransformPool={}}
function ESPShared.Frame.Finish()
    local frame=ESPShared.Frame
    for actor,entry in pairs(frame.Entries) do
        frame.Entries[actor]=nil
        entry.Location=nil;entry.LocationX=nil;entry.LocationY=nil;entry.LocationZ=nil
        entry.DistanceOrigin=nil;entry.DistanceSquared=nil;entry.DistanceMeters=nil
        entry.Alive=false;entry.Projected=false;entry.OnScreen=false
        entry.HasHead=false;entry.HasFeet=false;entry.PC=nil
        if #frame.Pool<frame.PoolLimit then frame.Pool[#frame.Pool+1]=entry end
    end
    for pc in pairs(frame.Controllers) do frame.Controllers[pc]=nil end
    for state,value in pairs(frame.Transforms) do
        frame.Transforms[state]=nil
        if #frame.TransformPool<4 then frame.TransformPool[#frame.TransformPool+1]=value end
    end
    frame.DistanceOrigin=nil;frame.OriginX=nil;frame.OriginY=nil;frame.OriginZ=nil
    frame.Pawns=nil;frame.Active=false
end
function ESPShared.Frame.Begin(now)
    ESPShared.Frame.Finish()
    ESPShared.Frame.Now=now;ESPShared.Frame.Active=true
end
function ESPShared.GetFrameRecord(actor)
    local frame=ESPShared.Frame
    local entry=frame.Active and frame.Entries[actor]
    if entry then return entry end
    entry=frame.Active and table.remove(frame.Pool) or nil
    if not entry then entry={} end
    entry.Alive=g_UXOfficial_ESPIsAlive(actor)
    entry.Projected=false;entry.OnScreen=false;entry.HasHead=false;entry.HasFeet=false
    entry.Location=entry.Alive and g_UXOfficial_ESPActorLocation(actor) or nil
    entry.LocationX,entry.LocationY,entry.LocationZ=ESPShared.VectorValues(entry.Location)
    if not entry.LocationX then entry.Location=nil end
    if frame.Active and actor~=nil then frame.Entries[actor]=entry end
    return entry
end
function ESPShared.GetFramePawns()
    if ESPShared.Frame.Active and ESPShared.Frame.Pawns then return ESPShared.Frame.Pawns end
    local pawns
    pcall(function() if Game and Game.GetAllPlayerPawns then pawns=Game:GetAllPlayerPawns() end end)
    if ESPShared.Frame.Active then ESPShared.Frame.Pawns=pawns end
    return pawns
end
function ESPShared.DistanceSquaredFrom(entry,origin)
    if not entry or not entry.LocationX then return math.huge end
    local frame=ESPShared.Frame
    if frame.Active and entry.DistanceOrigin==origin and entry.DistanceSquared~=nil then return entry.DistanceSquared end
    local x,y,z
    if frame.Active and frame.DistanceOrigin==origin then
        x,y,z=frame.OriginX,frame.OriginY,frame.OriginZ
    else
        x,y,z=ESPShared.VectorValues(origin)
        if frame.Active then frame.DistanceOrigin=origin;frame.OriginX=x;frame.OriginY=y;frame.OriginZ=z end
    end
    if not x then
        if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=math.huge;entry.DistanceMeters=nil end
        return math.huge
    end
    local dx,dy,dz=x-entry.LocationX,y-entry.LocationY,z-entry.LocationZ
    local squared=dx*dx+dy*dy+dz*dz
    if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=squared;entry.DistanceMeters=nil end
    return squared
end
function ESPShared.DistanceMetersFrom(entry,origin)
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if ESPShared.Frame.Active and entry.DistanceMeters~=nil then return entry.DistanceMeters end
    local distance=math.sqrt(squared)/100.0
    if ESPShared.Frame.Active then entry.DistanceMeters=distance end
    return distance
end
function ESPShared.InRange(entry,origin,maxRange)
    if not ESPShared.Finite(maxRange) or maxRange<=0 then return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange end
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if squared==math.huge then return false end
    local limit=maxRange*100.0;limit=limit*limit
    -- Preserve the original sqrt/division decision at floating-point boundaries.
    if math.abs(squared-limit)<=math.max(1,limit)*1e-12 then
        return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange
    end
    return squared<limit
end
function ESPShared.ProjectionControllerValid(pc)
    if pc==nil then return false end
    local frame=ESPShared.Frame
    if frame.Active then
        local cached=frame.Controllers[pc]
        if cached~=nil then return cached end
        local valid=g_UXOfficial_ESPValid(pc);frame.Controllers[pc]=valid;return valid
    end
    return g_UXOfficial_ESPValid(pc)
end
function ESPShared.CanvasTransform(state)
    local frame=ESPShared.Frame
    local value=frame.Active and frame.Transforms[state]
    local rx,ry,rox,roy=state.CanvasScaleX,state.CanvasScaleY,state.CanvasOffsetX,state.CanvasOffsetY
    if not value or value.RX~=rx or value.RY~=ry or value.ROX~=rox or value.ROY~=roy then
        value=value or (frame.Active and table.remove(frame.TransformPool)) or {}
        value.RX=rx;value.RY=ry;value.ROX=rox;value.ROY=roy
        value.SX=ESPShared.SafeNumber(rx,1,0.00001,100)
        value.SY=ESPShared.SafeNumber(ry,1,0.00001,100)
        value.OX=ESPShared.SafeNumber(rox,0,-1e7,1e7)
        value.OY=ESPShared.SafeNumber(roy,0,-1e7,1e7)
        if frame.Active then frame.Transforms[state]=value end
    end
    return value.SX,value.SY,value.OX,value.OY
end
function ESPShared.AssignProbeVector(vector,x,y,z)
    vector.X=x;vector.Y=y;vector.Z=z
end
function ESPShared.UpdateProbeVector(vector,x,y,z)
    if vector and pcall(ESPShared.AssignProbeVector,vector,x,y,z) then return vector end
    return g_UXOfficial_ESPV3(x,y,z)
end

-- Validate all cached candidates before display caps. Reuse the list and alive
-- map, so dead/out-of-range actors are pruned on the next scheduled HUD update.
local function g_UXOfficial_ESPFilterEnemies(list, myLocation, maxRange, alive)
    for key in pairs(alive) do alive[key]=nil end
    local count,kept,realCount,botCount=#list,0,0,0
    maxRange=tonumber(maxRange) or 450.0
    if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
    for i=1,count do
        local item=list[i]
        local character=item and item.Character
        local snapshot=item and item.Key and ESPShared.GetFrameRecord(character)
        if snapshot and snapshot.Alive then
            local location=snapshot.Location
            local distance=ESPShared.DistanceMetersFrom(snapshot,myLocation)
            if distance<=maxRange then
                item.Distance=distance
                kept=kept+1;list[kept]=item;alive[item.Key]=true
                if item.IsBot then botCount=botCount+1 else realCount=realCount+1 end
            end
        end
    end
    for i=kept+1,count do list[i]=nil end
    return realCount,botCount
end

-- ESP character vertical bounds made by @UXOfficial
local function g_UXOfficial_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not g_UXOfficial_ESPValid(character) then return nil, nil end

    local center, halfHeight = nil, nil
    local capsule = nil

    pcall(function()
        if character.GetCapsuleComponent then
            capsule = character:GetCapsuleComponent()
        elseif character.CapsuleComponent then
            capsule = character.CapsuleComponent
        end
    end)

    if capsule and g_UXOfficial_ESPValid(capsule) then
        pcall(function()
            if capsule.K2_GetComponentLocation then
                center = capsule:K2_GetComponentLocation()
            elseif capsule.GetComponentLocation then
                center = capsule:GetComponentLocation()
            end

            if capsule.GetScaledCapsuleHalfHeight then
                halfHeight = capsule:GetScaledCapsuleHalfHeight()
            elseif capsule.GetUnscaledCapsuleHalfHeight then
                halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
            elseif capsule.CapsuleHalfHeight then
                halfHeight = capsule.CapsuleHalfHeight
            end
        end)
    end

    local cx,cy,cz=ESPShared.VectorValues(center)
    if center and not cx then center=nil end
    if not center then center=cachedLocation end
    if not center then
        pcall(function()
            if character.K2_GetActorLocation then
                center = character:K2_GetActorLocation()
            end
        end)
    end

    if not center then
        pcall(function()
            if Game and Game.GetActorLocation then
                center = Game:GetActorLocation(character)
            end
        end)
    end

    if not cx then cx,cy,cz=ESPShared.VectorValues(center) end
    if not cx then return nil,nil end

    halfHeight=tonumber(halfHeight)
    if not ESPShared.Finite(halfHeight) or halfHeight<10 or halfHeight>200 then
        halfHeight = 85
        pcall(function()
            if character.bIsCrouched then halfHeight = 60 end
            if character.IsProne and character:IsProne() then halfHeight = 25 end
        end)
    end

    return center, halfHeight, cx, cy, cz
end

-- ESP head and feet position made by @UXOfficial
local function g_UXOfficial_ESPGetCharacterBoxLocs(character,cachedLocation)
    local center, halfHeight, x, y, z = g_UXOfficial_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not x or not halfHeight then return nil,nil end

    local headLoc = g_UXOfficial_ESPV3(
        x,
        y,
        z + halfHeight
    )

    local feetLoc = g_UXOfficial_ESPV3(
        x,
        y,
        z - halfHeight
    )

    return headLoc, feetLoc, center
end

-- ESP head position made by @UXOfficial

-- ESP feet position made by @UXOfficial

-- Bounded inactive HUD widgets. Records retain native widget/slot structure,
-- never an enemy key, actor, name, delegate, bone mesh or controller. Collapsed
-- widgets stay under the same canvas so reuse does not allocate CanvasSlots.
local ESPWidgetPool={}
do
local shapes={
    Line={Fields={"Widget","Slot","PosVec","SizeVec","VectorReuseDisabled"},Check={"Widget","Slot"},Limit=256},
    NameV2={Fields={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},
        Check={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},Limit=16},
    Decor={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
    Header={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
}
local function remove(widget)
    if widget then pcall(function() widget:RemoveFromParent() end) end
end
local function weight(data)
    local count=1
    if data.Groups then
        for _,group in pairs(data.Groups) do count=count+#group end
    elseif data.Text then count=data.BottomLine and 6 or 3 end
    return count
end
local function resetGroups(groups)
    if not groups then return end
    for _,group in pairs(groups) do
        for field in pairs(group) do if type(field)~="number" then group[field]=nil end end
        for _,piece in ipairs(group) do
            local w,s,pv,sv,disabled=piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled
            for field in pairs(piece) do piece[field]=nil end
            piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled=w,s,pv,sv,disabled
            piece.Visible=false
        end
    end
end
function ESPWidgetPool.New(capacity)
    return {Bins={},Canvas=nil,Enabled=true,Weight=0,Capacity=capacity,
        Reused=0,Released=0,Created=0,Discarded=0}
end
ESPWidgetPool.V2=ESPWidgetPool.New(1024)
function ESPWidgetPool.Flush(pool)
    for kind,bin in pairs(pool.Bins) do
        for i=#bin,1,-1 do
            local item=bin[i];bin[i]=nil;remove(item.Widget)
            for key in pairs(item) do item[key]=nil end
        end
        pool.Bins[kind]=nil
    end
    pool.Canvas=nil;pool.Weight=0
end
function ESPWidgetPool.Tag(pool,kind,canvas,data)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    data.PoolOwner=pool;data.PoolKind=kind;data.PoolCanvas=canvas
    pool.Created=pool.Created+1
    return data
end
function ESPWidgetPool.Release(data)
    if data.PoolReleased then return true end
    local pool,kind,canvas=data.PoolOwner,data.PoolKind,data.PoolCanvas
    if not pool or not pool.Enabled or pool.Canvas~=canvas or data.Broken
        or not g_UXOfficial_ESPValid(data.Widget) then return false end
    local shape=shapes[kind]
    if not shape then return false end
    local bin=pool.Bins[kind]
    if not bin then bin={};pool.Bins[kind]=bin end
    local cost=weight(data)
    if #bin>=shape.Limit or pool.Weight+cost>pool.Capacity then return false end
    local ok=pcall(function()
        data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        if data.Text then data.Text:SetText("") end
        if data.DistanceText then data.DistanceText:SetText("") end
        if data.Groups then
            for _,group in pairs(data.Groups) do
                for _,piece in ipairs(group) do
                    if piece.Broken then error("POOL_BROKEN_PIECE") end
                    if piece.Visible~=false then
                        piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end
        end
    end)
    if not ok then return false end
    resetGroups(data.Groups)
    local item={Weight=cost}
    for _,field in ipairs(shape.Fields) do item[field]=data[field] end
    -- Clear even caller-added fields so a reference never follows another enemy.
    for field in pairs(data) do data[field]=nil end
    data.PoolReleased=true
    bin[#bin+1]=item;pool.Weight=pool.Weight+cost;pool.Released=pool.Released+1
    return true
end
function ESPWidgetPool.Take(pool,kind,canvas)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    if not pool.Enabled then return nil end
    local shape,bin=shapes[kind],pool.Bins[kind]
    if not shape or not bin then return nil end
    while #bin>0 do
        local item=bin[#bin];bin[#bin]=nil;pool.Weight=pool.Weight-item.Weight
        local valid=true
        for _,field in ipairs(shape.Check) do
            if not g_UXOfficial_ESPValid(item[field]) then valid=false;break end
        end
        if valid and item.Groups then
            for _,group in pairs(item.Groups) do
                for _,piece in ipairs(group) do
                    if not g_UXOfficial_ESPValid(piece.Widget) or not g_UXOfficial_ESPValid(piece.Slot) then
                        valid=false;break
                    end
                end
                if not valid then break end
            end
        end
        -- Missing bindings or externally detached/reparented widgets fall back
        -- to normal construction, rather than assuming their CanvasSlot works.
        if valid then
            local ok,parent=pcall(function() return item.Widget:GetParent() end)
            valid=ok and parent==canvas
        end
        if valid then
            local data={PoolOwner=pool,PoolKind=kind,PoolCanvas=canvas}
            for _,field in ipairs(shape.Fields) do data[field]=item[field] end
            resetGroups(data.Groups)
            pool.Reused=pool.Reused+1
            return data
        end
        remove(item.Widget);pool.Discarded=pool.Discarded+1
        for key in pairs(item) do item[key]=nil end
    end
    return nil
end
end

-- ESP widget destroy made by @UXOfficial
local function g_UXOfficial_ESPDestroyWidgetData(data)
    if not data then return end
    if ESPWidgetPool.Release(data) then return end
    for _, field in ipairs({"Widget", "Container", "Text", "DistanceText"}) do
        local widget=data[field]
        if g_UXOfficial_ESPValid(widget) then
            pcall(function() widget:RemoveFromParent() end)
        end
    end
end

-- ESP widget cleanup made by @UXOfficial
local function g_UXOfficial_ESPResetWidgets()
    local radarUI=g_UXOfficial_ShotESP.RadarUI
    if radarUI then
        for _,eventName in ipairs({"ToggleEvent","CloseEvent"}) do
            local event=radarUI[eventName]
            local handle=radarUI[eventName.."Handle"]
            if event and handle~=nil then pcall(function() event:Remove(handle) end) end
        end
        for _,widgetName in ipairs({"ToggleLabel","ToggleButton","CloseLabel","CloseButton"}) do
            local widget=radarUI[widgetName]
            if widget and g_UXOfficial_ESPValid(widget) then pcall(function() widget:RemoveFromParent() end) end
        end
    end
    g_UXOfficial_ShotESP.RadarUI=nil
    g_UXOfficial_ShotESP.RadarCanvas=nil
    ESPWidgetPool.V2.Enabled=false
    for _, data in pairs(g_UXOfficial_ShotESP.Lines) do g_UXOfficial_ESPDestroyWidgetData(data) end
    for _, data in pairs(g_UXOfficial_ShotESP.Names) do g_UXOfficial_ESPDestroyWidgetData(data) end
    for _, data in pairs(g_UXOfficial_ShotESP.RadarLines or {}) do g_UXOfficial_ESPDestroyWidgetData(data) end
    for _, group in pairs(g_UXOfficial_ShotESP.Boxes) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.HealthBars) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.Skeletons) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.Headers) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_UXOfficial_ShotESP.Footers) do for _,data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end end
    g_UXOfficial_ShotESP.Lines = {}
    g_UXOfficial_ShotESP.RadarLines = {}
    g_UXOfficial_ShotESP.Names = {}
    g_UXOfficial_ShotESP.Boxes = {}
    g_UXOfficial_ShotESP.HealthBars = {}
    g_UXOfficial_ShotESP.Skeletons = {}
    for _, data in pairs(g_UXOfficial_ShotESP.HeaderRoots) do g_UXOfficial_ESPDestroyWidgetData(data) end
    g_UXOfficial_ShotESP.HeaderRoots = {}
    g_UXOfficial_ShotESP.Headers = {}
    g_UXOfficial_ShotESP.Footers = {}
    g_UXOfficial_ShotESP.BuildStage = {}
    g_UXOfficial_ShotESP.BoneNameCache = {}
    for _,data in pairs(g_UXOfficial_ShotESP.Decorations) do g_UXOfficial_ESPDestroyWidgetData(data) end
    g_UXOfficial_ShotESP.Decorations = {}
    if g_UXOfficial_ShotESP.Counter then g_UXOfficial_ESPDestroyWidgetData(g_UXOfficial_ShotESP.Counter) end
    g_UXOfficial_ShotESP.Counter = nil
    g_UXOfficial_ShotESP.Canvas = nil
    g_UXOfficial_ShotESP.RootUI = nil
    g_UXOfficial_ShotESP.Enemies = {}
    g_UXOfficial_ShotESP.Active = {}
    g_UXOfficial_ShotESP.Alive = {}
    g_UXOfficial_ShotESP.BoneMeshes = {}
    g_UXOfficial_ShotESP.BonePoints = {}
    g_UXOfficial_ShotESP.TemplateFont = nil
    g_UXOfficial_ShotESP.TemplateFontObject = nil
    g_UXOfficial_ShotESP.TemplateTypeface = nil
    g_UXOfficial_ShotESP.TemplateColorAndOpacity = nil
    g_UXOfficial_ShotESP.ViewportW, g_UXOfficial_ShotESP.ViewportH = nil, nil
    g_UXOfficial_ShotESP.RawViewportW, g_UXOfficial_ShotESP.RawViewportH = nil, nil
    g_UXOfficial_ShotESP.TracerOrigin = nil
    g_UXOfficial_ShotESP.LastScanClock = -999.0
    g_UXOfficial_ShotESP.LastTransformClock = -999.0
    g_UXOfficial_ShotESP.LastController = nil
    g_UXOfficial_ShotESP.LastPawn = nil
    g_UXOfficial_ShotESP._BotCache = {}
    g_UXOfficial_ShotESP.RealCount = 0
    g_UXOfficial_ShotESP.BotCount = 0
    ESPWidgetPool.Flush(ESPWidgetPool.V2)
    ESPWidgetPool.V2.Enabled=true
end

-- ESP HUD canvas made by @UXOfficial
local function g_UXOfficial_ESPGetCanvas()
    if g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.Canvas) then return g_UXOfficial_ShotESP.Canvas end
    local root = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
    end)
    if not g_UXOfficial_ESPValid(root) then return nil end
    g_UXOfficial_ShotESP.RootUI = root
    local canvas = nil
    pcall(function()
        if g_UXOfficial_ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
        elseif g_UXOfficial_ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
    end)
    if g_UXOfficial_ESPValid(canvas) then g_UXOfficial_ShotESP.Canvas = canvas return canvas end
    return nil
end

-- Discover a valid FontObject from existing HUD TextBlocks so dynamic TextBlocks always render glyphs
local function g_UXOfficial_ESPGetTemplateTextStyle()
    if g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) then
        return g_UXOfficial_ShotESP.TemplateFont
    end

    local visited = 0
    local function scanWidget(w, depth)
        if not w or depth > 6 or visited > 250 then return false end
        if not g_UXOfficial_ESPValid(w) then return false end
        visited = visited + 1

        local found = false
        pcall(function()
            if w.SetText and w.SetFont and w.Font then
                local f = w.Font
                if f and g_UXOfficial_ESPValid(f.FontObject) then
                    g_UXOfficial_ShotESP.TemplateFont = f
                    g_UXOfficial_ShotESP.TemplateFontObject = f.FontObject
                    pcall(function() g_UXOfficial_ShotESP.TemplateTypeface = f.TypefaceFontName end)
                    pcall(function() g_UXOfficial_ShotESP.TemplateColorAndOpacity = w.ColorAndOpacity end)
                    found = true
                end
            end
        end)
        if found then return true end

        local childCount = 0
        pcall(function() if w.GetChildrenCount then childCount = tonumber(w:GetChildrenCount()) or 0 end end)
        for i = 0, childCount - 1 do
            local child = nil
            pcall(function() child = w:GetChildAt(i) end)
            if child and scanWidget(child, depth + 1) then return true end
        end

        local treeRoot = nil
        pcall(function() if w.WidgetTree and w.WidgetTree.RootWidget then treeRoot = w.WidgetTree.RootWidget end end)
        if treeRoot and treeRoot ~= w and scanWidget(treeRoot, depth + 1) then return true end

        return false
    end

    local canvas = g_UXOfficial_ESPGetCanvas()
    if canvas then scanWidget(canvas, 0) end
    if not g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) and g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.RootUI) then
        scanWidget(g_UXOfficial_ShotESP.RootUI, 0)
    end

    if not g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) and slua and slua.loadObject then
        for _, path in ipairs({
            "/Engine/EngineFonts/Roboto.Roboto",
            "/Engine/EngineFonts/Roboto",
            "/Engine/EngineFonts/DroidSansFallback.DroidSansFallback"
        }) do
            local ok, obj = pcall(slua.loadObject, path)
            if ok and g_UXOfficial_ESPValid(obj) then
                g_UXOfficial_ShotESP.TemplateFontObject = obj
                break
            end
        end
    end

    return g_UXOfficial_ShotESP.TemplateFont
end

-- ESP viewport size made by @UXOfficial
local function g_UXOfficial_ESPViewport(pc)
    local w,h
    local function take(x,y)
        x,y=tonumber(x),tonumber(y)
        if ESPShared.Finite(x) and ESPShared.Finite(y) and x>200 and y>200 and x<1e6 and y<1e6 then w,h=x,y;return true end
    end
    pcall(function()
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
            local v=WidgetLayoutLibrary.GetViewportSize(pc);if v then take(v.X,v.Y) end
        end
    end)
    if not w then pcall(function() local x,y=pc:GetViewportSize();take(x,y) end) end
    if not w then pcall(function() local v=g_UXOfficial_ESPV2(0,0);pc:GetViewportSize(v);take(v.X,v.Y) end) end
    if not w then pcall(function() local x,y=pc:GetViewportSize(0,0);take(x,y) end) end
    return w or 2400.0,h or 1080.0
end

-- ESP HUD canvas made by @UXOfficial
local function g_UXOfficial_ESPGetCanvasLocalSize()
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil, nil end

    local cw, ch = nil, nil
    pcall(function()
        local geo = canvas:GetCachedGeometry()
        if not geo then return end

        local size = nil
        if geo.GetLocalSize then
            size = geo:GetLocalSize()
        elseif SlateBlueprintLibrary and SlateBlueprintLibrary.GetLocalSize then
            size = SlateBlueprintLibrary.GetLocalSize(geo)
        end

        if size and ESPShared.Finite(size.X) and ESPShared.Finite(size.Y) and size.X > 100 and size.Y > 100 then
            cw, ch = tonumber(size.X), tonumber(size.Y)
        end
    end)

    return cw, ch
end

-- ESP canvas transform made by @UXOfficial
local function g_UXOfficial_ESPUpdateCanvasTransform(pc)
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return false end

    local calibrated = false

    pcall(function()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
            local geo = canvas:GetCachedGeometry()
            if geo then
                local p0 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_UXOfficial_ESPV2(0, 0)
                )
                local p1 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_UXOfficial_ESPV2(100, 100)
                )

                if p0 and p1
                    and ESPShared.Finite(p0.X) and ESPShared.Finite(p0.Y)
                    and ESPShared.Finite(p1.X) and ESPShared.Finite(p1.Y)
                    and math.abs(p0.X)<1e7 and math.abs(p0.Y)<1e7
                    and p1.X>p0.X and p1.Y>p0.Y
                    and p1.X-p0.X<10000 and p1.Y-p0.Y<10000 then

                    g_UXOfficial_ShotESP.CanvasScaleX = (p1.X - p0.X) / 100.0
                    g_UXOfficial_ShotESP.CanvasScaleY = (p1.Y - p0.Y) / 100.0
                    g_UXOfficial_ShotESP.CanvasOffsetX = p0.X
                    g_UXOfficial_ShotESP.CanvasOffsetY = p0.Y
                    calibrated = true
                end
            end
        end
    end)

    if not calibrated then
        local scale = 1.0
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s = WidgetLayoutLibrary.GetViewportScale(pc)
                if ESPShared.Finite(s) and s>=0.01 and s<=100 then
                    scale = s
                end
            end
        end)

        g_UXOfficial_ShotESP.CanvasScaleX = 1.0 / scale
        g_UXOfficial_ShotESP.CanvasScaleY = 1.0 / scale
        g_UXOfficial_ShotESP.CanvasOffsetX = 0.0
        g_UXOfficial_ShotESP.CanvasOffsetY = 0.0
    end

    return true
end

-- ESP world to HUD projection made by @UXOfficial
local function g_UXOfficial_ESPProject(pc,worldLoc)
    local frame=ESPShared.Frame
    -- Skeleton results own their output; only the immediate raw scratch is shared.
    if not frame.RawPixel then frame.RawPixel=g_UXOfficial_ESPV2(0,0) end
    local pix=ESPShared.ProjectRaw(pc,worldLoc,frame.Active and frame.RawPixel or nil)
    if not pix then return nil end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(g_UXOfficial_ShotESP)
    return g_UXOfficial_ESPV2(pix.X*sx+ox,pix.Y*sy+oy)
end

-- Fresh projections deliberately avoid screen-space lerp: it adds camera lag
-- and desynchronizes the capsule outline from the independently projected bones.

local function g_UXOfficial_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
    local function usable(p)
        return p and ESPShared.Finite(p.X) and ESPShared.Finite(p.Y)
    end
    head=usable(head) and head or nil;feet=usable(feet) and feet or nil
    if not head and not feet then return false end
    head=head or feet;feet=feet or head
    return math.max(head.X,feet.X)>=minX and math.min(head.X,feet.X)<=maxX
        and math.max(head.Y,feet.Y)>=minY and math.min(head.Y,feet.Y)<=maxY
end

function ESPShared.ViewSize(pc)
    local now=ESPShared.Frame.Active and ESPShared.Frame.Now or g_UXOfficial_ESPNow()
    if not ESPShared.Frame.Active or ESPShared.Frame.ViewPC~=pc or now<ESPShared.Frame.ViewAt or now-ESPShared.Frame.ViewAt>=0.25 then
        ESPShared.Frame.ViewW,ESPShared.Frame.ViewH=g_UXOfficial_ESPViewport(pc)
        ESPShared.Frame.ViewPC=pc;ESPShared.Frame.ViewAt=now
    end
    return ESPShared.Frame.ViewW,ESPShared.Frame.ViewH
end
function ESPShared.NativeProject(pc,location,pix)
    return pc:ProjectWorldLocationToScreen(location,pix,true)
end
function ESPShared.ActorProbeLocations(actor,entry)
    local center,height,x,y,z=g_UXOfficial_ESPGetCharacterVerticalBounds(actor,entry.Location)
    if not x or not height then return nil,nil end
    entry.WorldHead=ESPShared.UpdateProbeVector(entry.WorldHead,x,y,z+height)
    entry.WorldFeet=ESPShared.UpdateProbeVector(entry.WorldFeet,x,y,z-height)
    return entry.WorldHead,entry.WorldFeet
end
function ESPShared.ProjectRaw(pc,location,pix)
    if not ESPShared.VectorValues(location) or not ESPShared.ProjectionControllerValid(pc) then return nil end
    pix=pix or g_UXOfficial_ESPV2(0,0);pix.X=0;pix.Y=0
    local ok,result,out=pcall(ESPShared.NativeProject,pc,location,pix)
    if out then pix=out end
    local good,x,y=pcall(function() return tonumber(pix.X),tonumber(pix.Y) end)
    if not ok or not good or not ESPShared.Finite(x) or not ESPShared.Finite(y) or math.abs(x)>=1e7 or math.abs(y)>=1e7 then return nil end
    if result~=true and result~=1 and not (result==nil and (x~=0 or y~=0)) then return nil end
    return pix
end
function ESPShared.ProbeActor(pc,actor)
    local entry=ESPShared.GetFrameRecord(actor)
    if entry.Projected and entry.PC==pc then return entry end
    entry.Projected=true;entry.PC=pc;entry.OnScreen=false
    if not entry.Alive or not entry.Location then return entry end
    local ok,head,feet=pcall(ESPShared.ActorProbeLocations,actor,entry)
    if not ok then return entry end
    entry.RawHead=entry.RawHead or g_UXOfficial_ESPV2(0,0)
    entry.RawFeet=entry.RawFeet or g_UXOfficial_ESPV2(0,0)
    local hp=ESPShared.ProjectRaw(pc,head,entry.RawHead)
    local fp=ESPShared.ProjectRaw(pc,feet,entry.RawFeet)
    if hp then entry.RawHead=hp end;if fp then entry.RawFeet=fp end
    entry.HasHead=hp~=nil;entry.HasFeet=fp~=nil
    local width,height=ESPShared.ViewSize(pc)
    entry.OnScreen=g_UXOfficial_ESPActorOnScreen(hp,fp,0,0,width,height)
    return entry
end
function ESPShared.CanvasBounds(pc,state)
    local width,height=ESPShared.ViewSize(pc)
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local maxX,maxY=ox+width*sx,oy+height*sy
    if ESPShared.Finite(state.ViewportW) and state.ViewportW>1 then maxX=math.min(maxX,ox+state.ViewportW) end
    if ESPShared.Finite(state.ViewportH) and state.ViewportH>1 then maxY=math.min(maxY,oy+state.ViewportH) end
    return ox,oy,maxX,maxY
end
function ESPShared.ProjectActor(pc,actor,state)
    local entry=ESPShared.ProbeActor(pc,actor)
    if not entry.OnScreen then return nil,nil,false end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local prefix="V2"
    local function convert(raw,field)
        local p=entry[field] or g_UXOfficial_ESPV2(0,0);entry[field]=p
        p.X=raw.X*sx+ox;p.Y=raw.Y*sy+oy;return p
    end
    local head=entry.HasHead and convert(entry.RawHead,prefix.."Head") or nil
    local feet=entry.HasFeet and convert(entry.RawFeet,prefix.."Feet") or nil
    local minX,minY,maxX,maxY=ESPShared.CanvasBounds(pc,state)
    return head,feet,g_UXOfficial_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
end


-- ESP text setter with FText conversion fallback

-- ESP font style made by @UXOfficial
local function g_UXOfficial_ESPSetFont(textWidget, size)
    if not g_UXOfficial_ESPValid(textWidget) then return end
    g_UXOfficial_ESPGetTemplateTextStyle()
    pcall(function()
        local f = textWidget.Font or g_UXOfficial_ShotESP.TemplateFont
        if f then
            if g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.TemplateFontObject) then
                pcall(function() f.FontObject = g_UXOfficial_ShotESP.TemplateFontObject end)
            end
            if g_UXOfficial_ShotESP.TemplateTypeface then
                pcall(function() f.TypefaceFontName = g_UXOfficial_ShotESP.TemplateTypeface end)
            end
            pcall(function() f.Size = size end)
            if f.OutlineSettings then
                pcall(function()
                    local os = f.OutlineSettings
                    os.OutlineSize = 0
                    os.OutlineColor = ESP_TEXT_CLEAR
                    f.OutlineSettings = os
                end)
            end
            pcall(function() textWidget:SetFont(f) end)
            pcall(function() textWidget.Font = f end)
        end
        if textWidget.SetShadowOffset then
            pcall(function() textWidget:SetShadowOffset(g_UXOfficial_ESPV2(0.0,0.0)) end)
        end
        if textWidget.SetShadowColorAndOpacity then
            pcall(function() textWidget:SetShadowColorAndOpacity(ESP_TEXT_CLEAR) end)
        end
    end)
end

-- ESP text color made by @UXOfficial
local function g_UXOfficial_ESPSetTextColor(textWidget, color)
    if not g_UXOfficial_ESPValid(textWidget) or not color then return end
    local applied = false
    pcall(function()
        local sc = textWidget.ColorAndOpacity or g_UXOfficial_ShotESP.TemplateColorAndOpacity or (SlateColor and SlateColor())
        if sc then
            sc.SpecifiedColor = color
            pcall(function() sc.ColorUseRule = 0 end)
            local check = sc.SpecifiedColor
            if check and tonumber(check.A) and tonumber(check.A) > 0 then
                textWidget:SetColorAndOpacity(sc)
                pcall(function() textWidget.ColorAndOpacity = sc end)
                applied = true
            end
        end
    end)
    if not applied then
        pcall(function() textWidget:SetColorAndOpacity(color) end)
    end
    pcall(function() if textWidget.SetOpacity then textWidget:SetOpacity(1.0) end end)
    pcall(function() if textWidget.SetRenderOpacity then textWidget:SetRenderOpacity(1.0) end end)
end

-- ESP line widget made by @UXOfficial
local function g_UXOfficial_ESPCreateLine(color,parent)
    local canvas = parent or g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    local budget = g_UXOfficial_ShotESP.BuildRemaining
    if budget ~= nil then
        if budget <= 0 then return nil end
        g_UXOfficial_ShotESP.BuildRemaining = budget - 1
    end
    local pooled=canvas==g_UXOfficial_ShotESP.Canvas and ESPWidgetPool.Take(ESPWidgetPool.V2,"Line",canvas)
    if pooled then
        local ok=pcall(function() pooled.Widget:SetBrushColor(color) end)
        if ok then pooled.Visible=false;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local border = nil
    pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
    if not g_UXOfficial_ESPValid(border) then return nil end
    pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border:SetRenderTransformPivot(g_UXOfficial_ESPV2(0.0, 0.5))
    end)
    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(border) end)
    if not slot then g_UXOfficial_ESPDestroyWidgetData({Widget=border}) return nil end
    pcall(function() slot:SetAutoSize(false) slot:SetZOrder(30) end)
    local data={Widget=border, Slot=slot}
    if canvas==g_UXOfficial_ShotESP.Canvas then ESPWidgetPool.Tag(ESPWidgetPool.V2,"Line",canvas,data) end
    return data
end

-- ESP line made by @UXOfficial
local function g_UXOfficial_ESPDrawLine(data, x1, y1, x2, y2, thickness)
    if not data or not data.Widget or not data.Slot then return false end
    local dx, dy = x2-x1, y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then
        if data.Visible ~= false then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.Visible = false
        end
        return false
    end
    local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
    local unchanged=data.Visible==true and data.X1 and
        math.abs(data.X1-x1)<0.25 and math.abs(data.Y1-y1)<0.25 and
        math.abs(data.X2-x2)<0.25 and math.abs(data.Y2-y2)<0.25 and
        math.abs((data.Thickness or 0)-thickness)<0.05
    if unchanged then return true end
    -- Reuse native transform values after the first draw. Older bindings
    -- that reject mutable structs fall back once to the original setter path.
    local setterOK=pcall(function()
        if data.VectorReuseDisabled then
            data.Slot:SetPosition(g_UXOfficial_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_UXOfficial_ESPV2(len, thickness))
        else
            data.PosVec=data.PosVec or g_UXOfficial_ESPV2(x1, y1 - thickness*0.5)
            data.SizeVec=data.SizeVec or g_UXOfficial_ESPV2(len, thickness)
            data.PosVec.X=x1;data.PosVec.Y=y1-thickness*0.5
            data.SizeVec.X=len;data.SizeVec.Y=thickness
            data.Slot:SetPosition(data.PosVec)
            data.Slot:SetSize(data.SizeVec)
        end
        data.Widget:SetRenderAngle(angle)
        if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if not setterOK and not data.VectorReuseDisabled then
        data.VectorReuseDisabled=true;data.PosVec=nil;data.SizeVec=nil
        setterOK=pcall(function()
            data.Slot:SetPosition(g_UXOfficial_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_UXOfficial_ESPV2(len, thickness))
            data.Widget:SetRenderAngle(angle)
            if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
        end)
    end
    if not setterOK then data.Broken=true return false end
    data.Broken=false
    data.X1,data.Y1,data.X2,data.Y2,data.Thickness=x1,y1,x2,y2,thickness
    data.Visible=true
    return true
end

-- ESP widget hide made by @UXOfficial
local function g_UXOfficial_ESPHide(data)
    if data and data.Visible~=false and data.Widget then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        if not ok then data.Broken=true end
        data.Visible=false
    end
end

local function g_UXOfficial_ESPDestroyGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_UXOfficial_ESPDestroyWidgetData(data) end
end

-- Check native widget validity at discovery cadence; failed setters mark a
-- piece broken immediately. This avoids an IsValid bridge call per piece/frame.
local function g_UXOfficial_ESPGroupHealthy(group)
    if not group then return false end
    local now = g_UXOfficial_ShotESP.Now
    local validate = not group.ValidatedAt or now < group.ValidatedAt or now-group.ValidatedAt >= 0.35
    for _, data in ipairs(group) do
        if data.Broken or (validate and not g_UXOfficial_ESPValid(data.Widget)) then return false end
    end
    if validate then group.ValidatedAt = now end
    return true
end

-- Keep partial groups across ticks; budgeted creation prevents first-visibility spikes.
local function g_UXOfficial_ESPLineGroup(registry, key, count, color, parent)
    local group = registry[key]
    if group and not g_UXOfficial_ESPGroupHealthy(group) then
        g_UXOfficial_ESPDestroyGroup(group)
        group = nil
    end
    if not group or #group > count then
        g_UXOfficial_ESPDestroyGroup(group)
        group = {}
        registry[key] = group
    end
    while #group < count do
        local data = g_UXOfficial_ESPCreateLine(color, parent)
        if not data then return nil end
        group[#group + 1] = data
        g_UXOfficial_ESPHide(data)
    end
    return group
end

-- Existing geometry and widgets are reused. Stable identity performs no native
-- color setters; failed brush assignments remain eligible for retry.
local function g_UXOfficial_ESPApplyGroupTheme(group,theme,kind)
    if not group or group.ThemeKey==theme.Key then return end
    local ok=pcall(function()
        for i,piece in ipairs(group) do
            local color=theme.Main
            if kind=="Header" then
                if i>=23 then color=theme.Background
                elseif i>=9 and i<=12 then color=theme.Light end
            elseif kind=="Arcs" then
                if i>=11 and i<=20 then color=theme.Light end
            elseif kind=="Footer" then
                if i<=4 then color=theme.Light end
            elseif kind=="Health" then
                if i==1 then color=theme.Background
                elseif i>=10 then color=theme.Light
                else color=theme.Empty end
            end
            piece.Widget:SetBrushColor(color)
        end
    end)
    if ok then group.ThemeKey=theme.Key end
end

local function g_UXOfficial_ESPHideGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_UXOfficial_ESPHide(data) end
end

local function g_UXOfficial_ESPHideDetailedEnemy(key)
    g_UXOfficial_ESPHide(g_UXOfficial_ShotESP.Lines[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.Boxes[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.HealthBars[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.Skeletons[key])
    g_UXOfficial_ESPHideGroup(g_UXOfficial_ShotESP.Headers[key])
    local decor=g_UXOfficial_ShotESP.Decorations[key]
    if decor and decor.Visible~=false then pcall(function() decor.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) decor.Visible=false end
end

local g_UXOfficial_ESPHealthRatio

local function g_UXOfficial_ESPSetGroupVisible(group,visible)
    if not group or group.GroupVisible==visible then return end
    for _,data in ipairs(group) do
        if visible then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            data.Visible=true
        else g_UXOfficial_ESPHide(data) end
    end
    group.GroupVisible=visible
end

local function g_UXOfficial_ESPCreateDecorationRoot(poolKind)
    local canvas=g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    poolKind=poolKind or "Decor"
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,poolKind,canvas)
    if pooled then
        local ok=pcall(function()
            pooled.Slot:SetZOrder(poolKind=="Header" and 30 or 29)
            pooled.Widget:SetRenderScale(g_UXOfficial_ESPV2(1.0,1.0))
            pooled.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        if ok then pooled.Visible=true;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local root=nil
    pcall(function() root=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_UXOfficial_ESPValid(root) then return nil end
    local slot=nil
    pcall(function() slot=canvas:AddChildToCanvas(root) end)
    if not slot then g_UXOfficial_ESPDestroyWidgetData({Widget=root}) return nil end
    pcall(function()
        slot:SetAutoSize(false)
        slot:SetSize(g_UXOfficial_ESPV2(1000.0,1400.0))
        slot:SetZOrder(29)
        root:SetRenderTransformPivot(g_UXOfficial_ESPV2(0.0,0.0))
        root:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,poolKind,canvas,{Widget=root,Slot=slot,Groups={},Visible=true})
end

local function g_UXOfficial_ESPDecorGroup(data,name,count,color)
    return g_UXOfficial_ESPLineGroup(data.Groups,name,count,color,data.Widget)
end


local function g_UXOfficial_ESPBuildArcs(data)
    local group=g_UXOfficial_ESPDecorGroup(data,"Arcs",26,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    local cx,cy,half,ry=500.0,385.0,268.0,180.0
    -- Progressive stroke curve: 2x at both corners, 5x at the center.
    -- Red base thickness is 3.0; white base thickness is 1.5.
    local redThickness={6.0,10.5,15.0,10.5,6.0}
    local whiteThickness={3.0,5.25,7.5,5.25,3.0}
    local index=1
    for _,side in ipairs({-1,1}) do
        local previous=nil
        for step=0,5 do
            local angle=(-70+step*28)*math.pi/180
            local p={X=cx+side*half*math.cos(angle),Y=cy+ry*math.sin(angle)}
            if previous then
                g_UXOfficial_ESPDrawLine(group[index],previous.X,previous.Y,p.X,p.Y,redThickness[step])
                index=index+1
            end
            previous=p
        end
    end
    local tickIndex=21
    for _,side in ipairs({-1,1}) do
        local x=cx+side*half*1.02
        for _,oy in ipairs({-24.0,0.0,24.0}) do
            g_UXOfficial_ESPDrawLine(group[tickIndex],x-side*5.0,cy+oy,x+side*2.0,cy+oy,2.2)
            tickIndex=tickIndex+1
        end
    end
    local ih,ir=half*.82,ry*.76
    for _,side in ipairs({-1,1}) do
        local previous=nil
        for step=0,5 do
            local angle=(-54+step*(108/5))*math.pi/180
            local p={X=cx+side*ih*math.cos(angle),Y=cy+ir*math.sin(angle)}
            if previous then
                pcall(function() group[index].Widget:SetBrushColor(ESP_WHITE) end)
                g_UXOfficial_ESPDrawLine(group[index],previous.X,previous.Y,p.X,p.Y,whiteThickness[step])
                index=index+1
            end
            previous=p
        end
    end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_UXOfficial_ESPBuildHealth(data)
    local group=g_UXOfficial_ESPDecorGroup(data,"Health",11,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    -- Twice the original footprint so distant health remains readable.
    local x,barBottom,barTop,barW=700.0,1120.0,564.0,60.0
    pcall(function()
        for i=1,11 do group[i].Widget:SetBrushColor(ESP_REAL) end
    end)
    g_UXOfficial_ESPDrawLine(group[1],x,barTop,x,barBottom,barW)
    local sh=(barBottom-barTop)/8
    for i=1,8 do
        local y1=barBottom-(i-1)*sh-2
        local y2=barBottom-i*sh+2
        g_UXOfficial_ESPDrawLine(group[i+1],x,y1,x,y2,barW*.64)
    end
    g_UXOfficial_ESPDrawLine(group[10],x-barW*.5,barTop,x+barW*.5,barTop,2.0)
    g_UXOfficial_ESPDrawLine(group[11],x-barW*.5,barBottom,x+barW*.5,barBottom,2.0)
    group.Built=true group.GroupVisible=true group.Filled=-1
    return group
end

local function g_UXOfficial_ESPBuildFooter(data)
    local group=g_UXOfficial_ESPDecorGroup(data,"Footer",6,ESP_WHITE)
    if not group then return nil end
    if group.Built then return group end
    local cx,y,w=500.0,1243.0,394.0
    local s={{cx-w*.5,y,cx-w*.29,y},{cx-w*.5,y,cx-w*.58,y-7},{cx+w*.29,y,cx+w*.5,y},{cx+w*.5,y,cx+w*.58,y-7},{cx-w*.23,y,cx-w*.19,y},{cx+w*.19,y,cx+w*.23,y}}
    for i,v in ipairs(s) do pcall(function() group[i].Widget:SetBrushColor(i>=5 and ESP_REAL or ESP_WHITE) end) g_UXOfficial_ESPDrawLine(group[i],v[1],v[2],v[3],v[4],i>=5 and 2.2 or 1.6) end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_UXOfficial_ESPUpdateDecoration(key,character,head,feet,opt,stage,isBot)
    local enabled=opt.Name or opt.Box or opt.Health or opt.Distance
    local data=g_UXOfficial_ShotESP.Decorations[key]
    if not enabled or not head or not feet then
        if data and data.Visible~=false then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.Visible=false end
        return
    end
    if not data or not g_UXOfficial_ESPValid(data.Widget) then
        g_UXOfficial_ESPDestroyWidgetData(data)
        data=g_UXOfficial_ESPCreateDecorationRoot()
        g_UXOfficial_ShotESP.Decorations[key]=data
    end
    if not data then return end
    local h=math.abs(feet.Y-head.Y)
    if h<8 then return end
    local scale=h/1000.0
    local x,y=head.X-500.0*scale,head.Y-200.0*scale
    local moved=not data.X or math.abs(data.X-x)>=.25 or math.abs(data.Y-y)>=.25
    local scaled=not data.Scale or math.abs(data.Scale-scale)>=.001
    if moved then
        local ok=pcall(function() data.Slot:SetPosition(g_UXOfficial_ESPV2(x,y)) end)
        if ok then data.X,data.Y=x,y end
    end
    if scaled then
        local ok=pcall(function() data.Widget:SetRenderScale(g_UXOfficial_ESPV2(scale,scale)) end)
        if ok then data.Scale=scale else data.Scale=nil end
    end
    if data.Visible~=true then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        if ok then data.Visible=true end
    end
    -- Header: handled by ESPUpdateHeaderFrame (screen-space, dynamic width) — hide DecorationRoot version
    if data.Groups.Header then g_UXOfficial_ESPSetGroupVisible(data.Groups.Header, false) end
    local theme=g_UXOfficial_ESPTheme(isBot)
    local arcs=data.Groups.Arcs
    if opt.Box then arcs=g_UXOfficial_ESPBuildArcs(data) end
    if arcs then g_UXOfficial_ESPApplyGroupTheme(arcs,theme,"Arcs") end
    g_UXOfficial_ESPSetGroupVisible(arcs,opt.Box==true)
    local health=data.Groups.Health
    if opt.Health then health=g_UXOfficial_ESPBuildHealth(data) end
    local healthTypeChanged=health and health.ThemeKey~=theme.Key
    if health then g_UXOfficial_ESPApplyGroupTheme(health,theme,"Health") end
    g_UXOfficial_ESPSetGroupVisible(health,opt.Health==true)
    if health and opt.Health then
        local filled=math.ceil(g_UXOfficial_ESPHealthRatio(character)*8-.001)
        if health.Filled~=filled or healthTypeChanged then
            local ok=pcall(function() for i=1,8 do health[i+1].Widget:SetBrushColor(i<=filled and theme.Main or theme.Empty) end end)
            if ok then health.Filled=filled end
        end
    end
    local footer=data.Groups.Footer
    if opt.Distance then footer=g_UXOfficial_ESPBuildFooter(data) end
    if footer then g_UXOfficial_ESPApplyGroupTheme(footer,theme,"Footer") end
    g_UXOfficial_ESPSetGroupVisible(footer,opt.Distance==true)
end

local function g_UXOfficial_ESPUpdateHeaderFrame(key,head,feet,enabled,isBot)
    local group=g_UXOfficial_ShotESP.Headers[key]
    if not enabled or not head or not feet then g_UXOfficial_ESPHideGroup(group) return end
    local h=math.abs(feet.Y-head.Y)
    -- Compact distance scaling.  The bottom edge stays above the head and all
    -- height growth happens upward, so zooming never pushes the plate onto the body.
    local w=math.max(68.0,math.min(232.0,h*0.315))
    local cached=g_UXOfficial_ShotESP.Names[key] and g_UXOfficial_ShotESP.Names[key].CachedName or ""
    w=math.max(w,math.min(232.0,28.0+#tostring(cached)*6.0))
    local hh=math.max(18.0,math.min(48.0,h*0.070))
    local headGap=math.max(4.0,math.min(10.0,h*0.025))
    local cx=head.X
    local b=head.Y-headGap
    local t=b-hh
    local cy=(t+b)*0.5
    local l,r=cx-w*0.5,cx+w*0.5
    local cut=hh*0.28
    -- 25 frame/background widgets + 8 horizontal fill bands per corner.
    -- The bands approximate true triangles without using rotated rectangles,
    -- which were the source of the original black corner leakage.
    local root = g_UXOfficial_ShotESP.HeaderRoots[key]
    if not root or not g_UXOfficial_ESPValid(root.Widget) then
        g_UXOfficial_ESPDestroyGroup(group)
        g_UXOfficial_ShotESP.Headers[key] = nil
        group = nil
        g_UXOfficial_ESPDestroyWidgetData(root)
        root = g_UXOfficial_ESPCreateDecorationRoot("Header")
        g_UXOfficial_ShotESP.HeaderRoots[key] = root
        if not root then return end
        group=root.Groups.__Header
        root.Groups.__Header=nil
        g_UXOfficial_ShotESP.Headers[key]=group
        pcall(function() root.Slot:SetZOrder(30) end)
    end
    -- Move 57 header pieces with one parent slot. Width/height changes still
    -- rebuild the exact original geometry with constant stroke thickness.
    local rootY = b
    local moved = not root.X or math.abs(root.X-cx) >= 0.25 or math.abs(root.Y-rootY) >= 0.25
    if moved then
        local ok = pcall(function() root.Slot:SetPosition(g_UXOfficial_ESPV2(cx,rootY)) end)
        if ok then root.X,root.Y = cx,rootY end
    end
    local theme=g_UXOfficial_ESPTheme(isBot)
    local ready = group and #group == 57
    if ready then g_UXOfficial_ESPApplyGroupTheme(group,theme,"Header") end
    if ready and group.Width and math.abs(group.Width-w) < 0.25 and math.abs(group.Height-hh) < 0.25 then
        local healthy = g_UXOfficial_ESPGroupHealthy(group)
        if healthy then
            for _, piece in ipairs(group) do
                if piece.Drawn then
                    if piece.Visible ~= true then
                        local ok = pcall(function() piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        if ok then piece.Visible = true end
                    end
                else g_UXOfficial_ESPHide(piece) end
            end
            return
        end
    end
    group=g_UXOfficial_ESPLineGroup(g_UXOfficial_ShotESP.Headers,key,57,ESP_REAL,root.Widget)
    if not group then return end
    cx, b, t, cy = 0.0, 0.0, -hh, -hh*0.5
    l, r = -w*0.5, w*0.5
    local seg={{l+cut,t,r-cut,t},{r-cut,t,r,t+cut},{r,t+cut,r,b-cut},{r,b-cut,r-cut,b},{r-cut,b,l+cut,b},{l+cut,b,l,b-cut},{l,b-cut,l,t+cut},{l,t+cut,l+cut,t}}
    if not group.HeaderStyled then
        local ok=pcall(function() for i=23,57 do group[i].Slot:SetZOrder(0) end end)
        if ok then group.HeaderStyled=true end
    end
    g_UXOfficial_ESPApplyGroupTheme(group,theme,"Header")
    -- octagon border
    for i,s in ipairs(seg) do g_UXOfficial_ESPDrawLine(group[i],s[1],s[2],s[3],s[4],2.0) end
    -- white inner accent lines on top/bottom edges
    g_UXOfficial_ESPDrawLine(group[9],l+cut*1.05,t,l+w*0.16,t,1.25)
    g_UXOfficial_ESPDrawLine(group[10],r-w*0.16,t,r-cut*1.05,t,1.25)
    g_UXOfficial_ESPDrawLine(group[11],l+cut*1.05,b,l+w*0.16,b,1.25)
    g_UXOfficial_ESPDrawLine(group[12],r-w*0.16,b,r-cut*1.05,b,1.25)
    -- bottom spike
    g_UXOfficial_ESPDrawLine(group[13],cx-cut*0.7,b,cx,b+cut,2.0)
    g_UXOfficial_ESPDrawLine(group[14],cx,b+cut,cx+cut*0.7,b,2.0)
    -- chevrons (side arrows)
    local co=cut*0.70
    g_UXOfficial_ESPDrawLine(group[15],l-co*1.9,cy,l-co*1.25,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[16],l-co*1.9,cy,l-co*1.25,cy+co,2.2)
    g_UXOfficial_ESPDrawLine(group[17],r+co*1.9,cy,r+co*1.25,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[18],r+co*1.9,cy,r+co*1.25,cy+co,2.2)
    g_UXOfficial_ESPDrawLine(group[19],l-co*2.8,cy,l-co*2.15,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[20],l-co*2.8,cy,l-co*2.15,cy+co,2.2)
    g_UXOfficial_ESPDrawLine(group[21],r+co*2.8,cy,r+co*2.15,cy-co,2.2)
    g_UXOfficial_ESPDrawLine(group[22],r+co*2.8,cy,r+co*2.15,cy+co,2.2)
    -- background: center + left strip + right strip (3-part fill of octagon interior)
    g_UXOfficial_ESPDrawLine(group[23],l+cut,cy,r-cut,cy,hh)
    g_UXOfficial_ESPDrawLine(group[24],l,cy,l+cut,cy,hh-2*cut)
    g_UXOfficial_ESPDrawLine(group[25],r-cut,cy,r,cy,hh-2*cut)
    -- Fill each missing corner triangle with horizontal stepped bands.  Every
    -- band starts inside the diagonal, so black cannot cross the red border.
    local cornerSteps=8
    local bandH=cut/cornerSteps
    for i=1,cornerSteps do
        local inset=(i-1)*bandH
        local topY=t+(i-0.5)*bandH
        local bottomY=b-(i-0.5)*bandH
        local leftStart=l+cut-inset
        local rightEnd=r-cut+inset

        if inset>0.5 then
            g_UXOfficial_ESPDrawLine(group[25+i],leftStart,topY,l+cut+0.5,topY,bandH)
            g_UXOfficial_ESPDrawLine(group[33+i],r-cut-0.5,topY,rightEnd,topY,bandH)
            g_UXOfficial_ESPDrawLine(group[41+i],leftStart,bottomY,l+cut+0.5,bottomY,bandH)
            g_UXOfficial_ESPDrawLine(group[49+i],r-cut-0.5,bottomY,rightEnd,bottomY,bandH)
        else
            g_UXOfficial_ESPHide(group[25+i])
            g_UXOfficial_ESPHide(group[33+i])
            g_UXOfficial_ESPHide(group[41+i])
            g_UXOfficial_ESPHide(group[49+i])
        end
    end
    group.Width, group.Height = w, hh
    for _, piece in ipairs(group) do piece.Drawn = piece.Visible == true end
end



g_UXOfficial_ESPHealthRatio = function(character)
    local hp, maxHp = nil, nil
    pcall(function()
        hp = character.Health or character.HP or character.CurrentHealth
        maxHp = character.HealthMax or character.MaxHealth or character.MaxHP
        if not tonumber(hp) and character.GetHealth then hp=character:GetHealth() end
        if not tonumber(maxHp) and character.GetMaxHealth then maxHp=character:GetMaxHealth() end
    end)
    hp, maxHp = tonumber(hp), tonumber(maxHp)
    if not hp or not maxHp or maxHp <= 0 then return 1.0 end
    return math.max(0.0,math.min(1.0,hp/maxHp))
end




local g_UXOfficial_ESPBones = {
    head={"Head","head","head_01"}, neck={"neck_01","Neck","neck"},
    chest={"spine_03","Spine3","chest","Chest"}, spine={"spine_02","Spine2","spine"}, pelvis={"pelvis","Pelvis"},
    ls={"clavicle_l","upperarm_l","UpperArm_L"}, le={"lowerarm_l","LowerArm_L"}, lw={"hand_l","Hand_L"},
    rs={"clavicle_r","upperarm_r","UpperArm_R"}, re={"lowerarm_r","LowerArm_R"}, rw={"hand_r","Hand_R"},
    lh={"thigh_l","Thigh_L","hip_l"}, lk={"calf_l","Calf_L","knee_l"}, la={"foot_l","Foot_L"},
    rh={"thigh_r","Thigh_R","hip_r"}, rk={"calf_r","Calf_R","knee_r"}, ra={"foot_r","Foot_R"}
}
-- Full-length articulated skeleton: head, torso, shoulders, arms, pelvis and legs.
local g_UXOfficial_ESPBoneLinks={{"head","neck"},{"neck","chest"},{"chest","spine"},{"spine","pelvis"},{"chest","ls"},{"ls","le"},{"le","lw"},{"chest","rs"},{"rs","re"},{"re","rw"},{"pelvis","lh"},{"lh","lk"},{"lk","la"},{"pelvis","rh"},{"rh","rk"},{"rk","ra"}}

-- Cache only the bone-name lookup; world positions and camera projections remain fresh.
local function g_UXOfficial_ESPBoneScreen(pc, mesh, id, names, cache)
    local cached = cache[id]
    if cached then
        local ok, loc = pcall(function()
            if mesh.GetSocketLocation then return mesh:GetSocketLocation(cached)
            elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(cached) end
        end)
        if ok and loc and tonumber(loc.X) then return g_UXOfficial_ESPProject(pc,loc) end
        cache[id] = nil
    end
    for _, name in ipairs(names) do
        local ok, loc = pcall(function()
            local exists = nil
            if mesh.DoesSocketExist then exists = mesh:DoesSocketExist(name)
            elseif mesh.GetBoneIndex then exists = (tonumber(mesh:GetBoneIndex(name)) or -1) >= 0 end
            if exists ~= false then
                if mesh.GetSocketLocation then return mesh:GetSocketLocation(name)
                elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(name) end
            end
        end)
        if ok and loc and tonumber(loc.X) then
            cache[id] = name
            return g_UXOfficial_ESPProject(pc,loc)
        end
    end
    return nil
end

local function g_UXOfficial_ESPUpdateSkeleton(key, character, pc, enabled, isBot, visibilityColor)
    local group = g_UXOfficial_ShotESP.Skeletons[key]
    if not enabled then g_UXOfficial_ESPHideGroup(group) return end
    local mesh = nil
    pcall(function() mesh=character.Mesh or (character.GetMesh and character:GetMesh()) end)
    if not g_UXOfficial_ESPValid(mesh) then g_UXOfficial_ESPHideGroup(group) return end
    if g_UXOfficial_ShotESP.BoneMeshes[key] ~= mesh then
        g_UXOfficial_ShotESP.BoneMeshes[key] = mesh
        g_UXOfficial_ShotESP.BoneNameCache[key] = {}
        g_UXOfficial_ShotESP.BonePoints[key] = {}
    end
    local points = g_UXOfficial_ShotESP.BonePoints[key]
    local cache = g_UXOfficial_ShotESP.BoneNameCache[key]
    local theme=g_UXOfficial_ESPTheme(isBot)
    group = g_UXOfficial_ESPLineGroup(g_UXOfficial_ShotESP.Skeletons,key,#g_UXOfficial_ESPBoneLinks,ESP_SKELETON_YELLOW)
    if not group then return end
    local skeletonColor = visibilityColor or ESP_SKELETON_YELLOW
    g_UXOfficial_ESPApplyGroupTheme(group,{Key=theme.Key.."_VISIBILITY_SKELETON",Main=skeletonColor,Light=skeletonColor,Background=theme.Background,Empty=theme.Empty},"Skeleton")
    for _, data in ipairs(group) do
        if data and data.Widget then pcall(function() data.Widget:SetBrushColor(skeletonColor) end) end
    end
    for id, names in pairs(g_UXOfficial_ESPBones) do
        points[id] = g_UXOfficial_ESPBoneScreen(pc,mesh,id,names,cache)
    end
    local ankle = points.la or points.ra
    local skeletonH = (points.head and ankle) and math.abs(ankle.Y-points.head.Y) or 360.0
    local thickness = math.max(1.0,math.min(2.8,skeletonH*0.0028))
    for i, link in ipairs(g_UXOfficial_ESPBoneLinks) do
        local a, b = points[link[1]], points[link[2]]
        if a and b then g_UXOfficial_ESPDrawLine(group[i],a.X,a.Y,b.X,b.Y,thickness)
        else g_UXOfficial_ESPHide(group[i]) end
    end
end

-- ESP enemy name widget made by @UXOfficial
local function g_UXOfficial_ESPCreateNameTag(isBot)
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,"NameV2",canvas)
    if pooled then
        local theme=g_UXOfficial_ESPTheme(isBot)
        g_UXOfficial_ESPSetTextColor(pooled.Text,theme.Text)
        g_UXOfficial_ESPSetTextColor(pooled.DistanceText,theme.Text)
        g_UXOfficial_ESPSetFont(pooled.Text,tonumber(_G.g_UXOfficial_UXOfficialShotESP.NameFontSize) or 16,0)
        g_UXOfficial_ESPSetFont(pooled.DistanceText,tonumber(_G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize) or 20,0)
        pooled.IsBot=isBot;pooled.ContainerVisible=false
        if pooled then return pooled end
    end

    local container, nameText, distanceText, namePlate, badgeText = nil, nil, nil, nil, nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not g_UXOfficial_ESPValid(container) then return nil end
    -- Premium model-target plate: dark backing, bright gold rim and a small badge.
    pcall(function() namePlate = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
    pcall(function() badgeText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    pcall(function() nameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    pcall(function() distanceText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    if not g_UXOfficial_ESPValid(nameText) or not g_UXOfficial_ESPValid(distanceText) then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        if g_UXOfficial_ESPValid(namePlate) then
            namePlate:SetBrushColor(g_UXOfficial_ESPColor(0.025,0.018,0.006,0.96))
            namePlate:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
        if g_UXOfficial_ESPValid(badgeText) then
            badgeText:SetText(isBot and "B" or "E")
            badgeText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if badgeText.SetJustification then badgeText:SetJustification(1) end
        end
        nameText:SetText("")
        distanceText:SetText("")
        nameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        distanceText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if nameText.SetJustification then nameText:SetJustification(1) end
        if nameText.SetRenderTransformPivot then nameText:SetRenderTransformPivot(g_UXOfficial_ESPV2(.5,.5)) end
        if distanceText.SetJustification then distanceText:SetJustification(1) end
        if distanceText.SetRenderTransformPivot then distanceText:SetRenderTransformPivot(g_UXOfficial_ESPV2(.5,.5)) end
    end)

    local theme=g_UXOfficial_ESPTheme(isBot)
    g_UXOfficial_ESPSetTextColor(nameText, g_UXOfficial_ESPColor(1.0,0.84,0.24,1.0))
    g_UXOfficial_ESPSetTextColor(distanceText, g_UXOfficial_ESPColor(1.0,0.88,0.42,1.0))
    g_UXOfficial_ESPSetTextColor(badgeText, g_UXOfficial_ESPColor(1.0,0.92,0.58,1.0))
    g_UXOfficial_ESPSetFont(badgeText, 14, 0)
    g_UXOfficial_ESPSetFont(nameText, tonumber(_G.g_UXOfficial_UXOfficialShotESP.NameFontSize) or 16, 0)
    -- Distance labels are intentionally borderless; the larger glyphs provide clarity.
    g_UXOfficial_ESPSetFont(distanceText, tonumber(_G.g_UXOfficial_UXOfficialShotESP.DistanceFontSize) or 20, 0)
    local nameSlot, distanceSlot, mainSlot, plateSlot, badgeSlot = nil, nil, nil, nil, nil
    if g_UXOfficial_ESPValid(namePlate) then pcall(function() plateSlot = container:AddChildToCanvas(namePlate) end) end
    if g_UXOfficial_ESPValid(badgeText) then pcall(function() badgeSlot = container:AddChildToCanvas(badgeText) end) end
    pcall(function() nameSlot = container:AddChildToCanvas(nameText) end)
    pcall(function() distanceSlot = container:AddChildToCanvas(distanceText) end)
    if not nameSlot or not distanceSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)
    if not mainSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetAlignment(g_UXOfficial_ESPV2(0.0, 0.0))
        mainSlot:SetZOrder(65)
        if plateSlot then
            plateSlot:SetAutoSize(false)
            plateSlot:SetPosition(g_UXOfficial_ESPV2(0,0))
            plateSlot:SetSize(g_UXOfficial_ESPV2(180,28))
            plateSlot:SetZOrder(0)
        end
        if badgeSlot then
            badgeSlot:SetAutoSize(false)
            badgeSlot:SetPosition(g_UXOfficial_ESPV2(8,0))
            badgeSlot:SetSize(g_UXOfficial_ESPV2(22,28))
            badgeSlot:SetZOrder(2)
        end
        nameSlot:SetAutoSize(true)
        nameSlot:SetAlignment(g_UXOfficial_ESPV2(0.5, 0.5))
        nameSlot:SetZOrder(1)
        distanceSlot:SetAutoSize(true)
        distanceSlot:SetAlignment(g_UXOfficial_ESPV2(0.5, 0.5))
        distanceSlot:SetZOrder(1)
    end)

    local data={
        Widget = container,
        Text = nameText,
        DistanceText = distanceText,
        Plate = namePlate,
        PlateSlot = plateSlot,
        BadgeText = badgeText,
        BadgeSlot = badgeSlot,
        TextSlot = nameSlot,
        DistanceSlot = distanceSlot,
        Slot = mainSlot,
        IsBot = isBot
    }
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,"NameV2",canvas,data)
end

-- ESP enemy name and distance made by @UXOfficial
local function g_UXOfficial_ESPUpdateNameTag(key, character, headScreen, footScreen, isBot, distance, forceName, forceDistance)
    local showName = _G.g_UXOfficial_ESPOptions.Name == true
    local showDistance = _G.g_UXOfficial_ESPOptions.Distance == true
    if forceName~=nil then showName=forceName==true end
    if forceDistance~=nil then showDistance=forceDistance==true end
    local data = g_UXOfficial_ShotESP.Names[key]
    if not showName and not showDistance then
        if data and data.ContainerVisible~=false and g_UXOfficial_ESPValid(data.Widget) then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.ContainerVisible=false end
        return
    end
    -- Fix: only cache non-empty resolved names; "" is truthy in Lua so never cache it
    local name = nil
    if showName then
        local cached = data and data.CachedName
        if type(cached) == "string" and #cached > 0 then
            name = cached
        else
            name = g_UXOfficial_ESPResolvePlayerName(character)
            if data and type(name) == "string" and #name > 0 then
                data.CachedName = name
            end
        end
        -- Fallback label for display only (not cached, so future frames retry)
        if not (type(name) == "string" and #name > 0) then
            name = isBot and "BOT PLAYER" or "PLAYER"
        end
    else
        name = ""
    end
    if not headScreen then
        if data and g_UXOfficial_ESPValid(data.Widget) then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.ContainerVisible=false
        end
        return
    end

    if not data or not g_UXOfficial_ESPValid(data.Widget) then
        g_UXOfficial_ESPDestroyWidgetData(data)
        data = g_UXOfficial_ESPCreateNameTag(isBot)
        g_UXOfficial_ShotESP.Names[key] = data
        -- Only cache real resolved names on creation, not fallback labels
        if data and type(name)=="string" and #name>0 and name~="BOT" and name~="BOT PLAYER" and name~="PLAYER" then
            data.CachedName = name
        end
    end
    if not data then return end
    if data.IsBot~=isBot then
        local theme=g_UXOfficial_ESPTheme(isBot)
        g_UXOfficial_ESPSetTextColor(data.Text,theme.Text)
        g_UXOfficial_ESPSetTextColor(data.DistanceText,theme.Text)
        data.IsBot=isBot
    end

    local dist = math.max(0, math.floor((tonumber(distance) or 0) + 0.5))
    local distanceLabel = string.format("%dm", dist)

    local bodyH=(footScreen and math.abs(footScreen.Y-headScreen.Y)) or 120.0
    local charCount=#name
    pcall(function() if utf8 and utf8.len then charCount=utf8.len(name) or charCount end end)
    -- Same compact, bottom-anchored geometry as ESPUpdateHeaderFrame.
    local w=math.max(68.0,math.min(232.0,bodyH*0.315))
    w=math.max(w,math.min(232.0,28.0+charCount*6.0))
    local hh=math.max(18.0,math.min(48.0,bodyH*0.070))
    local nameScale=math.max(0.80,math.min(1.18,math.min(bodyH/330.0,(w*0.80)/math.max(1.0,charCount*8.4))))
    local distanceScale=math.max(0.60,math.min(1.30,bodyH/200.0))
    local offscreenDistance = forceDistance==true and forceName==false
    if offscreenDistance then distanceScale=math.max(distanceScale,1.10) end

    -- Anchor the lower edge above the head; only the upper edge expands with scale.
    local cx = headScreen.X
    local headGap=math.max(4.0,math.min(10.0,bodyH*0.025))
    local bottomY=headScreen.Y-headGap
    local x = cx - w*0.5
    local y = bottomY-hh

    -- Distance text: at FEET position (CanvasPanel doesn't clip children outside bounds)
    local footY = footScreen and footScreen.Y or (headScreen.Y + bodyH)
    local distY = (footY - y) + bodyH*0.020   -- relative to container top-left, at feet level
    local distX = footScreen and (footScreen.X - x) or (w*0.5)

    local nameVisibilityChanged=data.ShowName~=showName
    local distanceVisibilityChanged=data.ShowDistance~=showDistance
    local layoutChanged=not data.LayoutX or math.abs(data.LayoutX-x)>=0.25 or math.abs(data.LayoutY-y)>=0.25 or
        math.abs((data.LayoutW or 0)-w)>=0.25 or math.abs((data.LayoutH or 0)-hh)>=0.25

    local applied = pcall(function()
        local targetPrefix = isBot and "BOT  |  " or "ENEMY  |  "
        local shownName = showName and (targetPrefix .. name) or ""
        local shownDistance = showDistance and distanceLabel or ""
        if data.PlateSlot then
            data.PlateSlot:SetSize(g_UXOfficial_ESPV2(math.max(112.0,math.min(250.0,w+22.0)),hh))
        end
        if data.BadgeText and data.LastBadgeType ~= isBot then
            data.BadgeText:SetText(isBot and "B" or "E")
            data.LastBadgeType = isBot
        end
        if data.LastName ~= shownName then
            data.Text:SetText(shownName)
            data.LastName = shownName
        end
        if data.NameScale~=nameScale then data.Text:SetRenderScale(g_UXOfficial_ESPV2(nameScale,nameScale)) end
        if data.DistanceScale~=distanceScale then data.DistanceText:SetRenderScale(g_UXOfficial_ESPV2(distanceScale,distanceScale)) end
        if data.LastDistance ~= shownDistance then
            data.DistanceText:SetText(shownDistance)
            data.LastDistance = shownDistance
        end
        if nameVisibilityChanged then
            data.Text:SetWidgetVisibility(showName and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end
        if distanceVisibilityChanged then
            data.DistanceText:SetWidgetVisibility(showDistance and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end

        -- Move the container to match the header octagon exactly
        if layoutChanged then
            data.Slot:SetPosition(g_UXOfficial_ESPV2(x, y))
            data.Slot:SetSize(g_UXOfficial_ESPV2(w, hh))
        end

        -- Name text centered inside container (matches header box center)
        if data.LayoutW~=w or data.LayoutH~=hh then
            data.TextSlot:SetPosition(g_UXOfficial_ESPV2(w*0.5, hh*0.5))
        end

        -- Distance text below the header box
        local distChanged = not data.DistX or math.abs(data.DistX-distX)>=0.25 or math.abs((data.DistY or 0)-distY)>=0.25
        if distChanged then
            data.DistanceSlot:SetPosition(g_UXOfficial_ESPV2(distX, distY))
        end

        if data.ContainerVisible~=true then
            data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
    end)
    if not applied then return end
    data.ShowName,data.ShowDistance=showName,showDistance
    data.NameScale=nameScale
    data.DistanceScale=distanceScale
    data.LayoutX,data.LayoutY,data.LayoutW,data.LayoutH=x,y,w,hh
    data.DistX,data.DistY=distX,distY
    data.ContainerVisible=true
end

-- Unified premium gold HUD: enemy/bot counter + model-target plates
local function g_UXOfficial_ESPCreateCounter()
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not g_UXOfficial_ESPValid(canvas) then return nil end
    local container=nil
    pcall(function() container=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_UXOfficial_ESPValid(container) then return nil end
    -- Premium frame: multicolor real-enemy side and single-color red bot side.
    local displayW,displayH=400.0,58.0
    local fontSize,fontScale=15,1.05
    local width,height,shieldH=460.0,58.0,68.0
    local sx,sy=displayW/width,displayH/shieldH
    local strokeScale=math.min(sx,sy)
    local half=width*0.5
    local pieces={}

    local function addRect(x,y,w,h,color,z)
        local widget=nil
        pcall(function() widget=CGame:NewObjectFromPath("/Script/UMG.Border",container) end)
        if not g_UXOfficial_ESPValid(widget) then return nil end
        local slot=nil
        pcall(function()
            widget:SetBrushColor(color)
            widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            slot=container:AddChildToCanvas(widget)
            slot:SetAutoSize(false)
            slot:SetPosition(g_UXOfficial_ESPV2(x*sx,y*sy))
            slot:SetSize(g_UXOfficial_ESPV2(math.max(1.0,w*sx),math.max(1.0,h*sy)))
            slot:SetZOrder(z or 1)
        end)
        if not slot then return nil end
        pieces[#pieces+1]={Widget=widget,Slot=slot}
        return pieces[#pieces]
    end

    local function addLine(x1,y1,x2,y2,thickness,color,z)
        local line=g_UXOfficial_ESPCreateLine(color,container)
        if not line then return nil end
        pcall(function() line.Slot:SetZOrder(z or 8) end)
        g_UXOfficial_ESPDrawLine(line,x1*sx,y1*sy,x2*sx,y2*sy,thickness*strokeScale)
        pieces[#pieces+1]=line
        return line
    end

    -- True trapezoid panels: horizontal scanlines keep every sloped edge clean.
    local panelSteps=16
    local bandH=height/panelSteps
    for i=1,panelSteps do
        local y=(i-1)*bandH
        local t=(i-0.5)/panelSteps
        local outerInset=3.0+t*22.0
        local innerInset=49.0-t*34.0
        local leftRight=half-innerInset
        local rightLeft=half+innerInset
        local enemyBase=g_UXOfficial_ESPScaleColor(ESP_COUNTER_CENTER,0.88+t*0.12,1.0)
        local botBase=g_UXOfficial_ESPScaleColor(ESP_COUNTER_RED_DARK,0.88+t*0.12,1.0)
        addRect(outerInset,y,leftRight-outerInset,bandH+0.15,enemyBase,1)
        addRect(rightLeft,y,width-outerInset-rightLeft,bandH+0.15,botBase,1)
    end

    -- Enemy side: segmented multicolor luminous trim. Bot side: one consistent red trim.
    local lp={{3,1},{half-49,1},{half-27,height*0.66},{half-14,height},{26,height},{3,1}}
    local rp={{width-3,1},{half+49,1},{half+27,height*0.66},{half+14,height},{width-26,height},{width-3,1}}
    local enemyGlow={
        g_UXOfficial_ESPColor(1.0,0.08,0.10,1.0),
        g_UXOfficial_ESPColor(1.0,0.34,0.04,1.0),
        g_UXOfficial_ESPColor(1.0,0.82,0.08,1.0),
        g_UXOfficial_ESPColor(0.15,0.90,1.0,1.0),
        g_UXOfficial_ESPColor(0.70,0.22,1.0,1.0),
        g_UXOfficial_ESPColor(1.0,0.08,0.10,1.0)
    }
    local enemyMultiColorPieces={}
    for i=1,#lp-1 do
        -- Gold baseline stays visible; multicolor overlay appears only when real enemies are counted.
        addLine(lp[i][1],lp[i][2],lp[i+1][1],lp[i+1][2],2.1,ESP_COUNTER_RED,6)
        local glowPiece=addLine(lp[i][1],lp[i][2],lp[i+1][1],lp[i+1][2],2.7,enemyGlow[i],7)
        if glowPiece and glowPiece.Widget then
            pcall(function() glowPiece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            enemyMultiColorPieces[#enemyMultiColorPieces+1]=glowPiece
        end
    end
    for i=1,#rp-1 do addLine(rp[i][1],rp[i][2],rp[i+1][1],rp[i+1][2],2.5,ESP_COVER_RED,7) end

    -- Independent downward center shield (not the legacy rotated diamond).
    local shieldSteps=22
    local shieldBand=shieldH/shieldSteps
    for i=1,shieldSteps do
        local y=(i-1)*shieldBand
        local t=(i-0.5)/shieldSteps
        local hw
        if t<0.68 then hw=43.0-t*22.0 else hw=29.0-(t-0.68)*48.0 end
        hw=math.max(11.0,hw)
        addRect(half-hw,y,hw*2.0,shieldBand+0.15,ESP_COUNTER_CENTER,5)
    end

    -- Gold end chevrons and luminous center accents/V.
    addLine(5,5,12,height-5,4.0,ESP_COUNTER_RED,9)
    addLine(12,5,19,height-5,4.0,ESP_COUNTER_RED,9)
    addLine(width-5,5,width-12,height-5,4.0,ESP_COVER_RED,9)
    addLine(width-12,5,width-19,height-5,4.0,ESP_COVER_RED,9)
    addLine(half-16,6,half-9,height*0.58,5.0,ESP_COUNTER_RED,10)
    addLine(half+16,6,half+9,height*0.58,5.0,ESP_COVER_RED,10)
    addLine(half-15,18,half,44,7.0,ESP_WHITE,11)
    addLine(half+15,18,half,44,7.0,ESP_WHITE,11)

    local function addText(initial,x,color)
        local text=nil
        pcall(function() text=CGame:NewObjectFromPath("/Script/UMG.TextBlock",container) end)
        if not g_UXOfficial_ESPValid(text) then return nil,nil end
        local slot=nil
        pcall(function()
            text:SetText(initial)
            text:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if text.SetJustification then text:SetJustification(1) end
            slot=container:AddChildToCanvas(text)
            slot:SetAutoSize(true)
            slot:SetAlignment(g_UXOfficial_ESPV2(0.5,0.5))
            slot:SetPosition(g_UXOfficial_ESPV2(x*sx,displayH*0.5))
            slot:SetZOrder(12)
        end)
        g_UXOfficial_ESPSetTextColor(text,color)
        g_UXOfficial_ESPSetFont(text,fontSize,0)
        pcall(function()
            text:SetRenderTransformPivot(g_UXOfficial_ESPV2(0.5,0.5))
            text:SetRenderScale(g_UXOfficial_ESPV2(fontScale,fontScale))
        end)
        return text,slot
    end

    -- Draw the skull and robot with simple UMG primitives rather than Unicode emoji,
    -- which can render as question-mark diamonds on some mobile game fonts.
    -- Skull badge: cranium, jaw, eyes and nose on the left panel.
    addRect(27,17,25,20,ESP_COUNTER_RED,10)
    addRect(30,36,19,7,ESP_COUNTER_RED,10)
    addRect(31,22,5,5,ESP_COUNTER_RED_DARK,11)
    addRect(43,22,5,5,ESP_COUNTER_RED_DARK,11)
    addRect(37,29,4,4,ESP_COUNTER_RED_DARK,11)
    addRect(32,39,3,4,ESP_COUNTER_RED_DARK,11)
    addRect(38,39,3,4,ESP_COUNTER_RED_DARK,11)
    addRect(44,39,3,4,ESP_COUNTER_RED_DARK,11)
    -- Robot badge: antenna, square head, eyes and mouth on the right panel.
    addLine(width-48,13,width-48,19,2.4,ESP_COVER_RED,10)
    addRect(width-51,9,6,4,ESP_COVER_RED,10)
    addRect(width-63,20,30,25,ESP_COVER_RED,10)
    addRect(width-59,24,22,17,ESP_COUNTER_RED_DARK,11)
    addRect(width-55,28,4,4,ESP_COVER_RED,12)
    addRect(width-43,28,4,4,ESP_COVER_RED,12)
    addRect(width-54,36,14,2,ESP_COVER_RED,12)

    local realText=addText("ENEMIES: 0",half*0.5+16,enemyGlow[3])
    local botText=addText("BOTS: 0",half+half*0.5-16,ESP_COVER_RED)
    if not realText or not botText then
        g_UXOfficial_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    local mainSlot=nil
    pcall(function() mainSlot=canvas:AddChildToCanvas(container) end)
    if not mainSlot then g_UXOfficial_ESPDestroyWidgetData({Widget=container}) return nil end

    local anchored=false
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetSize(g_UXOfficial_ESPV2(displayW,displayH))
        mainSlot:SetZOrder(60)
        -- Viewport-independent top-center anchor: survives aspect ratio, DPI,
        -- notch and safe-zone variations without drifting toward a corner.
        if mainSlot.SetAnchors and Anchors then
            local anchors=nil
            pcall(function()
                anchors=Anchors(
                    g_UXOfficial_ESPV2(0.5,0.0),
                    g_UXOfficial_ESPV2(0.5,0.0)
                )
            end)
            if not anchors then pcall(function() anchors=Anchors() end) end
            if anchors then
                pcall(function() anchors.Minimum=g_UXOfficial_ESPV2(0.5,0.0) end)
                pcall(function() anchors.Maximum=g_UXOfficial_ESPV2(0.5,0.0) end)
                mainSlot:SetAnchors(anchors)
                mainSlot:SetAlignment(g_UXOfficial_ESPV2(0.5,0.0))
                anchored=true
            end
        end
    end)

    return {Widget=container,Slot=mainSlot,RealText=realText,BotText=botText,
        EnemyMultiColorPieces=enemyMultiColorPieces,
        Width=displayW,Height=displayH,FontSize=fontSize,FontScale=fontScale,DiamondSize=0,Pieces=pieces,ViewportAnchored=anchored}
end

-- ESP counter position and tracer origin made by @UXOfficial
local function g_UXOfficial_ESPUpdateCounter(realCount, botCount, pc)

    local data = g_UXOfficial_ShotESP.Counter
    if not data or not g_UXOfficial_ESPValid(data.Widget) then
        -- The static counter is built atomically; the budget applies to enemy
        -- line groups that would otherwise all spawn together.
        local budget = g_UXOfficial_ShotESP.BuildRemaining
        g_UXOfficial_ShotESP.BuildRemaining = nil
        data = g_UXOfficial_ESPCreateCounter()
        g_UXOfficial_ShotESP.BuildRemaining = budget
        g_UXOfficial_ShotESP.Counter = data
    end
    if not data then return nil end

    -- Activate the enemy-side multicolor treatment only while real enemies are present.
    local showEnemyMultiColor=(tonumber(realCount) or 0)>0
    if data.EnemyMultiColorPieces and data.EnemyMultiColorVisible~=showEnemyMultiColor then
        for _,piece in ipairs(data.EnemyMultiColorPieces) do
            if piece and piece.Widget and g_UXOfficial_ESPValid(piece.Widget) then
                pcall(function()
                    piece.Widget:SetWidgetVisibility(showEnemyMultiColor and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
                end)
            end
        end
        data.EnemyMultiColorVisible=showEnemyMultiColor
    end

    local cw = g_UXOfficial_ShotESP.ViewportW
    local centerX = nil

    if tonumber(cw) and cw > 1 then
        centerX = cw * 0.5
    else

        local vw = g_UXOfficial_ESPViewport(pc)
        centerX =
            (vw * 0.5) * (g_UXOfficial_ShotESP.CanvasScaleX or 1.0)
            + (g_UXOfficial_ShotESP.CanvasOffsetX or 0.0)
    end

    if not centerX then return nil end

    local counterY = tonumber(_G.g_UXOfficial_UXOfficialShotESP.CounterY) or 36.0

    if data.LastReal ~= realCount then
        local ok=pcall(function() data.RealText:SetText(string.format("ENEMIES: %d", realCount or 0)) end)
        if ok then data.LastReal = realCount end
    end
    if data.LastBot ~= botCount then
        local ok=pcall(function() data.BotText:SetText(string.format("BOTS: %d", botCount or 0)) end)
        if ok then data.LastBot = botCount end
    end

    local positionChanged = data.CenterX ~= centerX or data.CounterY ~= counterY
    local visibleChanged = data.Visible ~= true
    local applied = pcall(function()
        if positionChanged and data.ViewportAnchored then
            data.Slot:SetPosition(g_UXOfficial_ESPV2(0.0,counterY))
        elseif positionChanged then
            data.Slot:SetAlignment(g_UXOfficial_ESPV2(0.0,0.0))
            data.Slot:SetPosition(g_UXOfficial_ESPV2(centerX-data.Width*0.5,counterY))
        end
        if visibleChanged then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if applied then data.CenterX,data.CounterY,data.Visible = centerX,counterY,true end

    local diamondSize = tonumber(data.DiamondSize) or 20.0
    local anchorX = centerX
    local anchorY = counterY + (data.Height * 0.5) + (diamondSize / math.sqrt(2.0))

    data.AnchorX = anchorX
    data.AnchorY = anchorY

    g_UXOfficial_ShotESP.TracerOrigin = g_UXOfficial_ESPV2(anchorX, anchorY)
    return g_UXOfficial_ShotESP.TracerOrigin
end

-- ESP enemy scan made by @UXOfficial
local function g_UXOfficial_ESPScanEnemies()
    local pc = g_UXOfficial_ESPGetController()
    local me = g_UXOfficial_ESPGetLocalCharacter()
    if not pc or not me then g_UXOfficial_ShotESP.Enemies = {} return nil, 0, 0 end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    if not myLoc then g_UXOfficial_ShotESP.Enemies = {} return pc, 0, 0 end
    local myTeam = g_UXOfficial_ESPGetTeamID(me)

    local list = {}
    local realCount, botCount = 0, 0
    local pawns=ESPShared.GetFramePawns()
    pawns = pawns or _G.g_UXOfficial_TrackedCharacters
    if pawns then
        for _, character in pairs(pawns) do
            if character~=me and ESPShared.GetFrameRecord(character).Alive then
                local team = g_UXOfficial_ESPGetTeamID(character)
                -- Fix: only skip as same-team when both IDs are non-zero and equal
                local sameTeam = false
                if myTeam ~= nil and team ~= nil then
                    local tNum, mNum = tonumber(team), tonumber(myTeam)
                    sameTeam = tNum and mNum and tNum > 0 and mNum > 0 and tNum == mNum
                end
                if not sameTeam then
                    local loc = ESPShared.GetFrameRecord(character).Location
                    local dist = ESPShared.DistanceMetersFrom(ESPShared.GetFrameRecord(character),myLoc)
                    if dist <= (tonumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters) or 400.0) then
                        local key = g_UXOfficial_ESPGetPlayerKey(character)
                        local isBot = g_UXOfficial_ESPIsBot(character,key)
                        if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                        list[#list+1] = {Character=character, Key=key, IsBot=isBot, Distance=dist}
                    end
                end
            end
        end
    end
    table.sort(list, function(a,b)
        if a.Distance == b.Distance then return a.Key < b.Key end
        return (a.Distance or 99999) < (b.Distance or 99999)
    end)
    g_UXOfficial_ShotESP.Enemies = list
    return pc, realCount, botCount
end

-- ESP stale widget cleanup made by @UXOfficial
local function g_UXOfficial_ESPPrune(active,alive)
    -- Visual caches follow the displayed set. Counting metadata follows alive.
    -- Move header children into their actor-free parent bundle before pruning
    -- either registry; no detached child can follow a different enemy.
    for key,root in pairs(g_UXOfficial_ShotESP.HeaderRoots) do
        if not active[key] and root.PoolOwner and root.Groups then
            root.Groups.__Header=g_UXOfficial_ShotESP.Headers[key]
            g_UXOfficial_ShotESP.Headers[key]=nil
        end
    end
    for _,registry in ipairs({g_UXOfficial_ShotESP.Lines,g_UXOfficial_ShotESP.Names,
        g_UXOfficial_ShotESP.Decorations,g_UXOfficial_ShotESP.HeaderRoots}) do
        for key,data in pairs(registry) do
            if not active[key] then g_UXOfficial_ESPDestroyWidgetData(data);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_UXOfficial_ShotESP.Boxes,g_UXOfficial_ShotESP.HealthBars,
        g_UXOfficial_ShotESP.Skeletons,g_UXOfficial_ShotESP.Headers,g_UXOfficial_ShotESP.Footers}) do
        for key,group in pairs(registry) do
            if not active[key] then g_UXOfficial_ESPDestroyGroup(group);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_UXOfficial_ShotESP.BuildStage,g_UXOfficial_ShotESP.BoneNameCache,
        g_UXOfficial_ShotESP.BoneMeshes,g_UXOfficial_ShotESP.BonePoints}) do
        for key in pairs(registry) do if not active[key] then registry[key]=nil end end
    end
    for key in pairs(g_UXOfficial_ShotESP._BotCache) do if not alive[key] then g_UXOfficial_ShotESP._BotCache[key]=nil end end
end

-- Vehicle tracking bridge: the host/game-specific vehicle scanner can register actor references here.
-- Example: g_UXOfficial_TrackRadarVehicle(vehicleActor). The radar validates actors before drawing.
_G.g_UXOfficial_TrackedVehicles = _G.g_UXOfficial_TrackedVehicles or {}
function _G.g_UXOfficial_TrackRadarVehicle(vehicleActor)
    if not vehicleActor then return false end
    local valid=false
    pcall(function() valid=vehicleActor.K2_GetActorLocation~=nil end)
    if not valid then return false end
    local list=_G.g_UXOfficial_TrackedVehicles
    for _,entry in pairs(list) do
        local actor=type(entry)=="table" and (entry.Vehicle or entry.Actor or entry[1]) or entry
        if actor==vehicleActor then return true end
    end
    list[#list+1]=vehicleActor
    return true
end
function _G.g_UXOfficial_ClearRadarVehicles()
    _G.g_UXOfficial_TrackedVehicles = {}
end

-- Compact side radar (green player arrow, red real enemies, yellow bots, pink tracked vehicles).
-- Uses the already-collected target list; optional vehicles can be supplied through
-- _G.g_UXOfficial_TrackedVehicles as an array of actor references or {Vehicle=actor} records.
local function g_UXOfficial_ESPRadarLine(index, color)
    local state=g_UXOfficial_ShotESP
    local line=state.RadarLines[index]
    if line and (line.Broken or not g_UXOfficial_ESPValid(line.Widget)) then
        g_UXOfficial_ESPDestroyWidgetData(line); state.RadarLines[index]=nil; line=nil
    end
    if not line then
        line=g_UXOfficial_ESPCreateLine(color)
        if line then state.RadarLines[index]=line end
    else
        if line.RadarColor~=color then pcall(function() line.Widget:SetBrushColor(color) end); line.RadarColor=color end
    end
    return line
end

-- Track lines drawn in the current frame so stale radar markers are hidden safely.
local g_UXOfficial_RadarActiveLines = {}

local function g_UXOfficial_ESPRadarDraw(index, x1,y1,x2,y2,thick,color)
    local line=g_UXOfficial_ESPRadarLine(index,color)
    if line then
        g_UXOfficial_ESPDrawLine(line,x1,y1,x2,y2,thick)
        g_UXOfficial_RadarActiveLines[index] = true
    end
end

local function g_UXOfficial_ESPRadarHideInactive()
    local state=g_UXOfficial_ShotESP
    if not state or type(state.RadarLines)~="table" then return end
    for i,line in pairs(state.RadarLines) do
        if line and not g_UXOfficial_RadarActiveLines[i] then
            g_UXOfficial_ESPHide(line)
        end
    end
end

local function g_UXOfficial_ESPRadarHideFrom(index)
    local state=g_UXOfficial_ShotESP
    if not state or type(state.RadarLines)~="table" then return end
    for i,line in pairs(state.RadarLines) do
        if i>=index and line then g_UXOfficial_ESPHide(line) end
    end
end

local function g_UXOfficial_ESPRadarEnsureControls(canvas,canvasW,canvasH)
    -- Side radar is automatic: remove the old floating RADAR / close controls.
    -- The existing ESP menu option named RADAR MAP remains the master on/off switch.
    local state=g_UXOfficial_ShotESP
    local ui=state.RadarUI
    if ui then
        for _,name in ipairs({"ToggleEvent","CloseEvent"}) do
            local ev,handle=ui[name],ui[name.."Handle"]
            if ev and handle~=nil then pcall(function() ev:Remove(handle) end) end
        end
        for _,name in ipairs({"ToggleLabel","ToggleButton","CloseLabel","CloseButton"}) do
            if g_UXOfficial_ESPValid(ui[name]) then pcall(function() ui[name]:RemoveFromParent() end) end
        end
        state.RadarUI=nil
        state.RadarCanvas=nil
    end
    state.RadarOpen=true
end

local function g_UXOfficial_ESPUpdateRadar(canvasW,canvasH,me,myLoc,items)
    if not canvasW or not canvasH or not me or not myLoc then return end
    local state=g_UXOfficial_ShotESP
    g_UXOfficial_RadarActiveLines = {}
    local canvas=g_UXOfficial_ESPGetCanvas()
    g_UXOfficial_ESPRadarEnsureControls(canvas,canvasW,canvasH)
    if _G.g_UXOfficial_ESPOptions.Radar~=true then
        g_UXOfficial_ESPRadarHideFrom(1)
        return
    end
    -- Compact always-visible side radar; no floating toggle and no expanded-map mode.
    local radius=math.max(52.0,math.min(88.0,canvasW*0.075,canvasH*0.14))
    local cx=canvasW-radius-34.0
    local cy=canvasH*0.62
    local rangeMeters=200.0
    local yaw=0.0
    pcall(function()
        local rot=me:K2_GetActorRotation()
        yaw=math.rad(tonumber(rot.Yaw) or 0.0)
    end)
    local idx=1
    -- Compact circular radar: premium gold frame with vivid neon range rings.
    local radarRed=g_UXOfficial_ESPColor(1.0,0.68,0.08,1.0)
    local radarGrid=g_UXOfficial_ESPColor(0.78,0.48,0.08,0.92)
    local radarCyan=g_UXOfficial_ESPColor(0.0,0.88,1.0,0.96)
    local radarBlue=g_UXOfficial_ESPColor(0.12,0.36,1.0,0.96)
    local radarPurple=g_UXOfficial_ESPColor(0.78,0.12,1.0,0.96)
    local radarGreen=g_UXOfficial_ESPColor(0.10,1.0,0.25,1.0)
    local radarFillLine=g_UXOfficial_ESPColor(0.025,0.02,0.008,0.96)
    -- Premium tactical HUD frame: keep the original layout and geometry, using gold colors only.
    local box=radius+9.0
    local corner=math.max(16.0,math.min(27.0,radius*0.22))
    -- Top-left / top-right / bottom-right / bottom-left corner brackets.
    g_UXOfficial_ESPRadarDraw(idx,cx-box,cy-box,cx-box+corner,cy-box,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-box,cy-box,cx-box,cy-box+corner,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+box-corner,cy-box,cx+box,cy-box,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+box,cy-box,cx+box,cy-box+corner,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+box,cy+box-corner,cx+box,cy+box,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+box-corner,cy+box,cx+box,cy+box,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-box,cy+box-corner,cx-box,cy+box,3.0,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-box,cy+box,cx-box+corner,cy+box,3.0,radarRed); idx=idx+1
    -- Short technical ticks at the middle of each side.
    local tick=math.max(7.0,math.min(12.0,radius*0.09))
    g_UXOfficial_ESPRadarDraw(idx,cx-tick,cy-box,cx+tick,cy-box,1.7,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-tick,cy+box,cx+tick,cy+box,1.7,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-box,cy-tick,cx-box,cy+tick,1.7,radarRed); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+box,cy-tick,cx+box,cy+tick,1.7,radarRed); idx=idx+1
    -- Thin inner gold frame gives the radar a layered instrument-panel look.
    local innerBox=radius+2.0
    g_UXOfficial_ESPRadarDraw(idx,cx-innerBox,cy-innerBox,cx+innerBox,cy-innerBox,1.0,radarGrid); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+innerBox,cy-innerBox,cx+innerBox,cy+innerBox,1.0,radarGrid); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx+innerBox,cy+innerBox,cx-innerBox,cy+innerBox,1.0,radarGrid); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-innerBox,cy+innerBox,cx-innerBox,cy-innerBox,1.0,radarGrid); idx=idx+1
    -- Circular neon rings: cyan, blue, purple and gold, matching the reference palette.
    for _,rf in ipairs({1.0,0.75,0.50,0.25}) do
        local ring={}
        local ringColor=(rf==1.0 and radarCyan) or (rf==0.75 and radarBlue) or (rf==0.50 and radarPurple) or radarGrid
        for i=0,47 do
            local a=(i/48.0)*math.pi*2.0
            ring[#ring+1]={cx+math.cos(a)*radius*rf,cy+math.sin(a)*radius*rf}
        end
        for i=1,#ring do
            local a=ring[i]; local b=ring[(i%#ring)+1]
            g_UXOfficial_ESPRadarDraw(idx,a[1],a[2],b[1],b[2],rf==1.0 and 1.8 or 1.25,ringColor); idx=idx+1
        end
    end
    g_UXOfficial_ESPRadarDraw(idx,cx-radius,cy,cx+radius,cy,1.2,radarGrid); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx,cy-radius,cx,cy+radius,1.2,radarGrid); idx=idx+1
    -- Player arrow points in the current facing direction (screen-up).
    local green=radarGreen
    g_UXOfficial_ESPRadarDraw(idx,cx,cy-8,cx-6,cy+6,3.0,green); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx,cy-8,cx+6,cy+6,3.0,green); idx=idx+1
    g_UXOfficial_ESPRadarDraw(idx,cx-6,cy+6,cx+6,cy+6,3.0,green); idx=idx+1

    local function drawDot(actor,color,offset)
        local loc=nil
        pcall(function()
            if actor and actor.K2_GetActorLocation then loc=actor:K2_GetActorLocation() end
        end)
        if not loc then
            local rec=nil; pcall(function() rec=ESPShared.GetFrameRecord(actor) end)
            loc=rec and rec.Location or nil
        end
        if not loc then return end
        local dx=(tonumber(loc.X) or 0)-(tonumber(myLoc.X) or 0)
        local dy=(tonumber(loc.Y) or 0)-(tonumber(myLoc.Y) or 0)
        local forward=dx*math.cos(yaw)+dy*math.sin(yaw)
        local right=-dx*math.sin(yaw)+dy*math.cos(yaw)
        local mx,my=right/100.0,forward/100.0
        local dist=math.sqrt(mx*mx+my*my)
        if dist>rangeMeters then return end
        local scale=math.min(1.0,dist/rangeMeters)
        local px=cx+(mx/rangeMeters)*radius
        local py=cy-(my/rangeMeters)*radius
        local sz=dist<25 and 3.4 or 2.5
        g_UXOfficial_ESPRadarDraw(offset,px-sz,py,px+sz,py,2.8,color)
        g_UXOfficial_ESPRadarDraw(offset+1,px,py-sz,px,py+sz,2.8,color)
    end
    -- Keep actor tracking and positions unchanged; distinguish bots from real enemies by color.
    local dotIndex=idx
    local drawn=0
    local enemyRed=g_UXOfficial_ESPColor(1.0,0.035,0.08,1.0)
    local botYellow=g_UXOfficial_ESPColor(1.0,0.82,0.02,1.0)
    for _,item in ipairs(items or {}) do
        if drawn>=12 then break end
        local color=(item and item.IsBot) and botYellow or enemyRed
        drawDot(item.Character,color,dotIndex)
        dotIndex=dotIndex+2; drawn=drawn+1
    end
    -- Tracked vehicles use vivid pink, as in the supplied reference.
    local vehicles=_G.g_UXOfficial_TrackedVehicles
    local pink=g_UXOfficial_ESPColor(1.0,0.08,0.82,1.0)
    if type(vehicles)=="table" then
        local vdrawn=0
        for _,entry in pairs(vehicles) do
            if vdrawn>=12 then break end
            local vehicle=entry
            if type(entry)=="table" then vehicle=entry.Vehicle or entry.Actor or entry.Character or entry.Pawn or entry[1] end
            if vehicle then
                local valid=false
                pcall(function() valid=vehicle.K2_GetActorLocation~=nil end)
                if valid then drawDot(vehicle,pink,dotIndex); dotIndex=dotIndex+2; vdrawn=vdrawn+1 end
            end
        end
    end
    g_UXOfficial_ESPRadarHideInactive()
end

-- ESP main HUD update made by @UXOfficial
local function g_UXOfficial_ESPUpdate()
    local opt = _G.g_UXOfficial_ESPOptions
    local anyEnabled = opt and (opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton or opt.Counter or opt.Radar)
    if not _G.g_UXOfficial_UXOfficialShotESP.Enabled or not anyEnabled then
        if not g_UXOfficial_ShotESP.Disabled then g_UXOfficial_ESPResetWidgets() end
        g_UXOfficial_ShotESP.Disabled = true
        return
    end
    g_UXOfficial_ShotESP.Disabled = false
    local buildBudget = tonumber(_G.g_UXOfficial_UXOfficialShotESP.WidgetBuildBudget) or 96
    if buildBudget ~= buildBudget or buildBudget == math.huge then buildBudget = 96 end
    g_UXOfficial_ShotESP.BuildRemaining = math.max(1, math.floor(buildBudget))

    local world = g_UXOfficial_ESPWorld()
    if world ~= g_UXOfficial_ShotESP.LastWorld then
        g_UXOfficial_ESPResetWidgets()
        g_UXOfficial_ShotESP.LastWorld = world
        g_UXOfficial_ShotESP.LastScanClock = -999.0
        g_UXOfficial_ShotESP.LastTransformClock = -999.0
        g_UXOfficial_ShotESP.TracerOrigin = nil
    end

    if g_UXOfficial_ShotESP.Canvas and not g_UXOfficial_ESPValid(g_UXOfficial_ShotESP.Canvas) then
        g_UXOfficial_ESPResetWidgets()
    end
    local canvas = g_UXOfficial_ESPGetCanvas()
    if not canvas then return end
    local now = g_UXOfficial_ESPNow()
    g_UXOfficial_ShotESP.Now = now
    if now < g_UXOfficial_ShotESP.LastScanClock then
        g_UXOfficial_ShotESP.LastScanClock = -999.0
        g_UXOfficial_ShotESP.LastTransformClock = -999.0
    end
    local pc = g_UXOfficial_ESPGetController()
    local me = g_UXOfficial_ESPGetLocalCharacter()
    if pc ~= g_UXOfficial_ShotESP.LastController or me ~= g_UXOfficial_ShotESP.LastPawn then
        g_UXOfficial_ESPResetWidgets()
        g_UXOfficial_ShotESP.LastController, g_UXOfficial_ShotESP.LastPawn = pc,me
        canvas = g_UXOfficial_ESPGetCanvas()
        if not canvas then return end
    end
    if not pc or not me then return end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    local realCount, botCount = nil, nil
    if (now - g_UXOfficial_ShotESP.LastScanClock) >= (tonumber(_G.g_UXOfficial_UXOfficialShotESP.ScanInterval) or 0.30) then
        pc, realCount, botCount = g_UXOfficial_ESPScanEnemies()
        g_UXOfficial_ShotESP.LastScanClock = now
        g_UXOfficial_ShotESP.RealCount, g_UXOfficial_ShotESP.BotCount = realCount, botCount
    end
    pc = pc or g_UXOfficial_ESPGetController()
    if not pc then return end

    if (now - (g_UXOfficial_ShotESP.LastTransformClock or -999.0))
        >= (tonumber(_G.g_UXOfficial_UXOfficialShotESP.TransformInterval) or 0.50) then
        g_UXOfficial_ESPUpdateCanvasTransform(pc)
        local cw,ch=g_UXOfficial_ESPGetCanvasLocalSize()
        if cw and ch then g_UXOfficial_ShotESP.ViewportW,g_UXOfficial_ShotESP.ViewportH=cw,ch end
        local rw,rh=g_UXOfficial_ESPViewport(pc)
        g_UXOfficial_ShotESP.RawViewportW,g_UXOfficial_ShotESP.RawViewportH=rw,rh
        g_UXOfficial_ShotESP.LastTransformClock = now
    end

    local rawW,rawH=ESPShared.ViewSize(pc)
    -- The tracer uses the physical viewport midpoint in canvas coordinates.
    local canvasScaleX=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasScaleX,1.0,0.00001,100)
    local canvasScaleY=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasScaleY,1.0,0.00001,100)
    local canvasOffsetX=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasOffsetX,0.0,-1e7,1e7)
    local canvasOffsetY=ESPShared.SafeNumber(g_UXOfficial_ShotESP.CanvasOffsetY,0.0,-1e7,1e7)
    local originCenter = g_UXOfficial_ESPV2(
        (rawW*0.5)*canvasScaleX+canvasOffsetX,
        4.0*canvasScaleY+canvasOffsetY
    )
    local active,alive=g_UXOfficial_ShotESP.Active,g_UXOfficial_ShotESP.Alive
    g_UXOfficial_ShotESP.RealCount,g_UXOfficial_ShotESP.BotCount=g_UXOfficial_ESPFilterEnemies(
        g_UXOfficial_ShotESP.Enemies,myLoc,_G.g_UXOfficial_UXOfficialShotESP.MaxRangeMeters,alive)
    local radarW,radarH=g_UXOfficial_ESPGetCanvasLocalSize()
    if radarW and radarH then g_UXOfficial_ESPUpdateRadar(radarW,radarH,me,myLoc,g_UXOfficial_ShotESP.Enemies) end
    if opt.Counter then
        g_UXOfficial_ESPUpdateCounter(
            g_UXOfficial_ShotESP.RealCount or 0,
            g_UXOfficial_ShotESP.BotCount or 0,
            pc
        )
    elseif g_UXOfficial_ShotESP.Counter then
        g_UXOfficial_ESPHide(g_UXOfficial_ShotESP.Counter)
    end

    -- Counter-only mode stops here after validating cached scan candidates, avoiding
    -- projection, skeleton, box and per-enemy widget work entirely.
    local detailedEnabled=opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton
    if not detailedEnabled then
        for key in pairs(active) do active[key]=nil end
        g_UXOfficial_ESPPrune(active,alive)
        return
    end

    for key in pairs(active) do active[key]=nil end
    local configuredMax=math.floor(ESPShared.SafeNumber(_G.g_UXOfficial_UXOfficialShotESP.MaxRendered,8,1,64))
    local maxRendered = configuredMax
    local renderedCount=0
    -- Keep the nearest-candidate budget; counting still validates every actor.
    for index,item in ipairs(g_UXOfficial_ShotESP.Enemies) do
        if index>maxRendered then break end
        local c,key=item.Character,item.Key
        local headScreen,footScreen,onScreen=ESPShared.ProjectActor(pc,c,g_UXOfficial_ShotESP)
        if onScreen then
            if renderedCount<maxRendered then
                renderedCount=renderedCount+1
                active[key] = true
                local buildStage=g_UXOfficial_ShotESP.BuildStage[key] or 1
                -- Use the controller's native line-of-sight test: visible = yellow, blocked by cover = red.
                local isCovered = false
                pcall(function()
                    if pc.LineOfSightTo then isCovered = not pc:LineOfSightTo(c) end
                end)
                local color = isCovered and ESP_COVER_RED or (item.IsBot and ESP_BOT or ESP_REAL)
                local line = g_UXOfficial_ShotESP.Lines[key]

                local colorKey = isCovered and "COVER" or (item.IsBot and "BOT" or "REAL")
                if opt.Line and (not line or not g_UXOfficial_ESPValid(line.Widget)) then
                    g_UXOfficial_ESPDestroyWidgetData(line)
                    line = g_UXOfficial_ESPCreateLine(color)
                    if line then line.ColorKey = colorKey end
                    g_UXOfficial_ShotESP.Lines[key] = line
                elseif opt.Line and line and line.ColorKey ~= colorKey then
                    pcall(function() line.Widget:SetBrushColor(color) end)
                    line.ColorKey = colorKey
                end

                if opt.Line and line then
                    local tracerTarget = headScreen or footScreen
                    if tracerTarget then
                        g_UXOfficial_ESPDrawLine(
                            line,
                            originCenter.X, originCenter.Y,
                            tracerTarget.X, tracerTarget.Y,
                            tonumber(_G.g_UXOfficial_UXOfficialShotESP.TracerThickness) or 1.80
                        )
                    end
                elseif line then g_UXOfficial_ESPHide(line) end

                g_UXOfficial_ESPUpdateDecoration(key,c,headScreen,footScreen,opt,buildStage,item.IsBot)
                g_UXOfficial_ESPUpdateNameTag(key,c,headScreen,footScreen,item.IsBot,item.Distance)
                -- Header frame: dynamic per-frame update (fills, corner fills, scale with name)
                g_UXOfficial_ESPUpdateHeaderFrame(key,headScreen,footScreen,opt.Name==true,item.IsBot)

                -- All visible skeletons refresh with the current camera; no round-robin delay.
                g_UXOfficial_ESPUpdateSkeleton(key, c, pc, opt.Skeleton == true, item.IsBot,
                    isCovered and ESP_COVER_RED or ESP_SKELETON_YELLOW)
                g_UXOfficial_ShotESP.BuildStage[key]=math.min(5,buildStage+1)

            end
        end
    end
    g_UXOfficial_ESPPrune(active,alive)
end

-- One pending render chain. Menu refreshes invalidate/wake it rather than
-- drawing synchronously multiple times in the same frame.
local g_UXOfficial_ESPRunnerToken={}
if type(_G.__UXOfficialShotESPCleanup) == "function" then pcall(_G.__UXOfficialShotESPCleanup) end
_G.__UXOfficialShotESPRunner=g_UXOfficial_ESPRunnerToken
_G.__UXOfficialShotESPCleanup=g_UXOfficial_ESPResetWidgets
local g_UXOfficial_ESPDiagnostics={Updates=0,Errors=0,LastError=nil}
_G.g_UXOfficial_ESPDiagnostics=g_UXOfficial_ESPDiagnostics
local g_UXOfficial_ESPTicker=nil
pcall(function() g_UXOfficial_ESPTicker=require("common.time_ticker") end)
local g_UXOfficial_ESPTick
local function g_UXOfficial_ESPSchedule(delay)
    delay=ESPShared.SafeNumber(delay,0.50,0.001,0.50)
    if _G.__UXOfficialShotESPRunner~=g_UXOfficial_ESPRunnerToken then return end
    if not g_UXOfficial_ESPTicker or not g_UXOfficial_ESPTicker.AddTimerOnce then
        g_UXOfficial_ESPDiagnostics.LastError="common.time_ticker.AddTimerOnce unavailable"
        return
    end
    local serial=(g_UXOfficial_ESPRunnerToken.Serial or 0)+1
    g_UXOfficial_ESPRunnerToken.Serial=serial
    g_UXOfficial_ESPRunnerToken.Due=g_UXOfficial_ESPNow()+delay
    local ok, err=pcall(g_UXOfficial_ESPTicker.AddTimerOnce,delay,function()
        if _G.__UXOfficialShotESPRunner~=g_UXOfficial_ESPRunnerToken
            or g_UXOfficial_ESPRunnerToken.Serial~=serial then return end
        g_UXOfficial_ESPRunnerToken.Due=nil
        g_UXOfficial_ShotESP.TimerClock=g_UXOfficial_ShotESP.TimerClock+delay
        g_UXOfficial_ESPTick()
    end)
    if not ok or err==false then
        g_UXOfficial_ESPRunnerToken.Due=nil
        g_UXOfficial_ESPDiagnostics.Errors=g_UXOfficial_ESPDiagnostics.Errors+1
        g_UXOfficial_ESPDiagnostics.LastError=tostring(err)
    end
end
g_UXOfficial_ESPTick=function()
    local token=g_UXOfficial_ESPRunnerToken
    if _G.__UXOfficialShotESPRunner~=token then return end
    local now=g_UXOfficial_ESPNow()
    local profiling=_G.g_UXOfficial_UXOfficialShotESP.Profile and os and type(os.clock)=="function"
    local callbackStarted=profiling and os.clock() or nil
    ESPShared.Frame.Begin(now)
    local F=_G.LunarFeatures
    if F then F.TimerClock=g_UXOfficial_ShotESP.TimerClock end
    if not token.RenderDue or now>=token.RenderDue-0.000001 or (token.LastRenderClock and now<token.LastRenderClock) then
        local previous=g_UXOfficial_ESPDiagnostics.LastTickSeconds
        if previous and now>previous then g_UXOfficial_ESPDiagnostics.UpdateHz=1/(now-previous) end
        g_UXOfficial_ESPDiagnostics.LastTickSeconds=now
        local started=profiling and os.clock() or nil
        local ok,err=pcall(g_UXOfficial_ESPUpdate)
        g_UXOfficial_ESPDiagnostics.LastUpdateOK=ok
        g_UXOfficial_ESPDiagnostics.Updates=g_UXOfficial_ESPDiagnostics.Updates+1
        if not ok then
            g_UXOfficial_ESPDiagnostics.Errors=g_UXOfficial_ESPDiagnostics.Errors+1
            g_UXOfficial_ESPDiagnostics.LastError=tostring(err)
        end
        if started then
            local elapsed=os.clock()-started
            g_UXOfficial_ESPDiagnostics.LastUpdateCPUSeconds=elapsed
            g_UXOfficial_ESPDiagnostics.MaxUpdateCPUSeconds=math.max(elapsed,g_UXOfficial_ESPDiagnostics.MaxUpdateCPUSeconds or 0)
        end
        local o=_G.g_UXOfficial_ESPOptions or {}
        local enabled=_G.g_UXOfficial_UXOfficialShotESP.Enabled
        local detailed=enabled and (o.Name or o.Line or o.Box or o.Health or o.Distance or o.Skeleton)
        local interval=tonumber(_G.g_UXOfficial_UXOfficialShotESP.UpdateInterval) or 1/60
        if not detailed then interval=enabled and o.Counter and math.max(0.05,tonumber(_G.g_UXOfficial_UXOfficialShotESP.ScanInterval) or 0.35) or 0.50 end
        if interval~=interval or math.abs(interval)==math.huge or interval<=0 then interval=1/60 end
        token.LastRenderClock=now
        token.RenderDue=now+math.max(0.001,interval)
    end
    if profiling then g_UXOfficial_ESPDiagnostics.LastPumpCPUSeconds=0 end
    if F and F.Pump and not F.Token.Stopped then
        local pumpStarted=profiling and os.clock() or nil
        local ok,err=pcall(F.Pump,now)
        if not ok then F.Error("Scheduler",err) end
        if pumpStarted then
            local elapsed=os.clock()-pumpStarted
            g_UXOfficial_ESPDiagnostics.LastPumpCPUSeconds=elapsed
            g_UXOfficial_ESPDiagnostics.MaxPumpCPUSeconds=math.max(elapsed,g_UXOfficial_ESPDiagnostics.MaxPumpCPUSeconds or 0)
        end
    end
    ESPShared.Frame.Finish()
    local after=g_UXOfficial_ESPNow()
    local interval=math.max(0.001,token.RenderDue-after)
    if F and F.NextInterval and not F.Token.Stopped then interval=math.min(interval,F.NextInterval(after)) end
    g_UXOfficial_ESPSchedule(interval)
    if callbackStarted then
        local elapsed=os.clock()-callbackStarted
        g_UXOfficial_ESPDiagnostics.LastCallbackCPUSeconds=elapsed
        g_UXOfficial_ESPDiagnostics.MaxCallbackCPUSeconds=math.max(elapsed,g_UXOfficial_ESPDiagnostics.MaxCallbackCPUSeconds or 0)
        g_UXOfficial_ESPDiagnostics.TotalCallbackCPUSeconds=(g_UXOfficial_ESPDiagnostics.TotalCallbackCPUSeconds or 0)+elapsed
        g_UXOfficial_ESPDiagnostics.CallbackSamples=(g_UXOfficial_ESPDiagnostics.CallbackSamples or 0)+1
    end
end


_G.g_UXOfficial_UXOfficialShotESPForceRefresh = function()
    if _G.__UXOfficialShotESPRunner~=g_UXOfficial_ESPRunnerToken then return end
    g_UXOfficial_ESPRunnerToken.RenderDue=nil
    g_UXOfficial_ShotESP.LastScanClock = -999.0
    g_UXOfficial_ShotESP.LastTransformClock = -999.0
    local due=g_UXOfficial_ESPRunnerToken.Due
    if not due or due-g_UXOfficial_ESPNow()>0.002 then g_UXOfficial_ESPSchedule(0.001) end
end

-- Managed feature state. Source settings are data, never loaded as executable Lua.
do
    if type(_G.__LunarFeaturesCleanup) == "function" then pcall(_G.__LunarFeaturesCleanup) end
    local F = {Token={}, Diagnostics={Errors=0}, TimerClock=0, LastWorld=nil}
    _G.LunarFeatures=F
    local settings = _G.LunarFeatureSettings or {}
    _G.LunarFeatureSettings=settings
    F.Settings=settings
    local function number(value,lo,hi,fallback)
        local v=tonumber(value)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return math.floor(math.max(lo,math.min(hi,v))+0.5)
    end
    F.Clamp=number
    settings.IpadFOV=number(settings.IpadFOV or _G.LexusState.CustomTextData.IpadViewFOV,90,120,120)
    settings.AimSpeed=number(settings.AimSpeed,100,120,100)
    settings.AimTarget=number(settings.AimTarget,1,3,1)
    settings.AimEnabled=settings.AimEnabled==true
    settings.Aim2Enabled=settings.Aim2Enabled==true
    settings.MortarEnabled=settings.MortarEnabled==true
    -- Discard values retained by older hot-reloaded copies.
    settings.WallEnabled=nil;settings.WallVisible=nil;settings.WallOccluded=nil
    _G.g_Botmater_ESPOptions=nil;_G.g_Botmater_UXOfficialShotESP=nil
    local paths=g_UXOfficial_ESPSettingsPaths()
    for i,path in ipairs(paths) do paths[i]=path:gsub("UXOfficial_UMG_ESP_settings.lua$","UXOfficial_FEATURES_V3_settings.lua") end
    if io and io.open then
        for _,path in ipairs(paths) do
            local ok,file=pcall(io.open,path,"r")
            if ok and file then
                local readOK,payload=pcall(function() return file:read("*a") end)
                pcall(function() file:close() end)
                if readOK and type(payload)=="string" then
                    F.SettingsReadPath=path
                    for _,key in ipairs({"AimEnabled","IpadEnabled","Aim2Enabled","MortarEnabled"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then
                            if key=="IpadEnabled" then _G.LexusConfig.IpadView=val=="true" else settings[key]=val=="true" end
                        end
                    end
                    for _,key in ipairs({"IpadFOV","AimSpeed","AimTarget"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,key=="IpadFOV" and 90 or (key=="AimSpeed" and 100 or 1),key=="AimTarget" and 3 or 120,settings[key]) end
                    end
                    for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter"}) do
                        local val=payload:match("%f[%w_]V2_"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then _G.g_UXOfficial_ESPOptions[key]=val=="true" end
                    end
                    break
                end
            end
        end
    end
    if not F.SettingsReadPath and g_UXOfficial_ESPLoadedSettingsPath then
        F.SettingsReadPath=g_UXOfficial_ESPLoadedSettingsPath:gsub("UXOfficial_UMG_ESP_settings%.lua$","UXOfficial_FEATURES_V3_settings.lua")
    end
    if settings.Aim2Enabled then settings.AimEnabled=false end
    _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
    F.Now=function()
        local now=nil
        pcall(function()
            local world=g_UXOfficial_ESPWorld()
            if world and GameplayStaticsESP and GameplayStaticsESP.GetRealTimeSeconds then now=GameplayStaticsESP.GetRealTimeSeconds(world) end
        end)
        return tonumber(now) or F.TimerClock
    end
    F.Save=function(force)
        if not F.Dirty or not io or not io.open then return end
        local lines={"return {", "  IpadEnabled = "..tostring(_G.LexusConfig.IpadView==true)..","}
        for _,key in ipairs({"AimEnabled","Aim2Enabled","MortarEnabled","IpadFOV","AimSpeed","AimTarget"}) do lines[#lines+1]="  "..key.." = "..tostring(settings[key]).."," end
        for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter","Radar"}) do lines[#lines+1]="  V2_"..key.." = "..tostring(_G.g_UXOfficial_ESPOptions[key]==true).."," end
        lines[#lines+1]="}"
        local payload=table.concat(lines,"\n")
        local savePaths=F.SettingsReadPath and {F.SettingsReadPath} or paths
        for _,path in ipairs(savePaths) do
            local wrote,reason,atomic=g_UXOfficial_ESPWriteSettings(path,payload)
            if wrote then
                F.SettingsReadPath=path;F.Dirty=false;F.Diagnostics.LastSaveOK=true;F.Diagnostics.LastSavePath=path;F.Diagnostics.AtomicSave=atomic
                return true
            end
            F.Diagnostics.LastSaveError=reason
        end
        F.Diagnostics.LastSaveOK=false
        return false
    end
    F.MarkDirty=function(immediate) F.Dirty=true;if immediate then F.Save(true) end end
    F.SetIpad=function(enabled)
        _G.LexusConfig.IpadView=enabled==true or enabled==1
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_UXOfficial_ApplyiPadView)
        F.MarkDirty(true)
    end
    F.SetIpadFOV=function(value)
        settings.IpadFOV=number(value,90,120,120)
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_UXOfficial_ApplyiPadView)
        F.MarkDirty()
    end
    F.SetAimSpeed=function(value)
        local previousSpeed=settings.AimSpeed
        settings.AimSpeed=number(value,100,120,100)
        if settings.AimSpeed~=previousSpeed then
            F.AimLastClock=nil;F.AimDue=0
            if _G.XthrlenState then _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0 end
        end
        if _G.XthrlenState and _G.XthrlenState.CustomTextData then
            local data=_G.XthrlenState.CustomTextData
            data.AimTouchHipSpeed=settings.AimSpeed
            data.AimTouchScopeSpeed=settings.AimSpeed
        end
        F.MarkDirty()
    end
    F.SetAimTarget=function(value) settings.AimTarget=number(value,1,3,1);F.MarkDirty(true) end
    -- ItemBase supports caller-owned event keys. Both native switches subscribe
    -- through its normal lifecycle; there are no saved widget references.
    F.AimSettingsEventType=-14050701
    F.AimSettingsEventID=1
    F.SetAimMode=function(value)
        local mode=F.Clamp(value,0,2,0)
        local changed=settings.AimEnabled~=(mode==1) or settings.Aim2Enabled~=(mode==2)
        settings.AimEnabled=mode==1
        settings.Aim2Enabled=mode==2
        _G.XthrlenConfig.AimTouchEnable=settings.AimEnabled
        if not settings.AimEnabled then
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0;F.AimLastClock=nil
        end
        if not settings.Aim2Enabled and F.Aim2 then F.Aim2.Stop() end
        if F.Aim2 then F.Aim2.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
        if changed and EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.AimSettingsEventType,F.AimSettingsEventID)
            if not ok then F.Error("Aim.SettingsRefresh",err) end
        end
    end
    F.SetAim=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 1 or (settings.Aim2Enabled and 2 or 0))
    end
    F.SetAim2=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 2 or (settings.AimEnabled and 1 or 0))
    end
    F.SetMortar=function(enabled)
        settings.MortarEnabled=enabled==true or enabled==1
        if not settings.MortarEnabled and F.Mortar then F.Mortar.Stop() end
        if F.Mortar then F.Mortar.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end

    -- Single, unchanged ESP V2 option group.
    local v2Keys={"Name","Line","Box","Health","Distance","Skeleton","Counter","Radar"}
    local v2Valid={Name=true,Line=true,Box=true,Health=true,Distance=true,Skeleton=true,Counter=true,Radar=true}
    F.ESPSettingsEventType=-14050701
    F.ESPSettingsEventID=2
    local function commitESP(changed)
        if not changed then
            if F.Dirty then return F.Save(true) end
            return true
        end
        F.MarkDirty(true)
        _G.g_UXOfficial_UXOfficialShotESPForceRefresh()
        if EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.ESPSettingsEventType,F.ESPSettingsEventID)
            if not ok then F.Error("ESP.SettingsRefresh",err) end
        end
        return true
    end
    F.SetESP=function(version,key,value)
        if version~=2 or not v2Valid[key] then return false end
        local on=value==true or value==1
        local options=_G.g_UXOfficial_ESPOptions
        local changed=options[key]~=on
        if changed then options[key]=on end
        if key=="Radar" and not on then g_UXOfficial_ShotESP.RadarOpen=false end
        return commitESP(changed)
    end
    F.GetESPAll=function(version)
        if version~=2 then return false end
        local options=_G.g_UXOfficial_ESPOptions
        for _,key in ipairs(v2Keys) do if options[key]~=true then return false end end
        return true
    end
    F.SetESPAll=function(version,value)
        if version~=2 then return false end
        local options=_G.g_UXOfficial_ESPOptions
        local on=value==true or value==1
        local changed=false
        for _,key in ipairs(v2Keys) do
            if options[key]~=on then options[key]=on;changed=true end
        end
        return commitESP(changed)
    end
    -- Native OnSelected skips SetFunc when the same index is selected again.
    -- Bulk command rows must still apply to partial ESP state. Only these marked
    -- rows receive the additional click callback; every other native row is untouched.
    F.InstallNativeBulkSwitch=function(class)
        if type(class)~="table" or type(class.OnSelected)~="function" then return false end
        if class.__LunarBulkSwitchV7 then return true end
        local original=class.OnSelected
        class.OnSelected=function(self,index)
            local data=self.Data
            local repeatBulk=data and data.LunarBulk and self.UIRoot.Selector:GetSelectedIndex()==index
            local result=original(self,index)
            if repeatBulk then return data.SetFunc(data.Key,self:_IndexToValue(index)) end
            return result
        end
        class.__LunarBulkSwitchV7=true
        return true
    end
    F.SetV2=function(key,value) return F.SetESP(2,key,value) end
    F.Error=function(area,err)
        F.Diagnostics.Errors=F.Diagnostics.Errors+1
        F.Diagnostics.LastError=area..": "..tostring(err)
    end
    _G.__LunarFeaturesCleanup=function()
        F.Token.Stopped=true
        if F.Aim2 then F.Aim2.Stop() end
        if F.Mortar then F.Mortar.Stop() end
    end
end

do
local AimV2,AimGameplayStatics,AimMath,AimUI
pcall(function() AimV2=import("Vector2D") end)
pcall(function() AimGameplayStatics=import("GameplayStatics") end)
pcall(function() AimMath=import("KismetMathLibrary") end)
pcall(function() AimUI=require("client.common.ui_util") end)
_G.XthrlenConfig = _G.XthrlenConfig or {}
_G.XthrlenState = _G.XthrlenState or {}
_G.XthrlenState.CustomTextData = _G.XthrlenState.CustomTextData or {}

_G.XthrlenConfig.AimTouchEnable        = _G.LunarFeatures.Settings.AimEnabled
_G.XthrlenConfig.AimTouchHipfire       = true
_G.XthrlenConfig.AimTouchScopeAll      = true
_G.XthrlenConfig.AimTouchHipVisCheck   = true
_G.XthrlenConfig.AimTouchScopeVisCheck = true
_G.XthrlenConfig.AimTouchHipIgKnock    = true
_G.XthrlenConfig.AimTouchScopeIgKnock  = true

_G.XthrlenConfig.AimTouchHipIgBot      = false
_G.XthrlenConfig.AimTouchScopeIgBot    = false
_G.XthrlenConfig.AimTouchSG            = false
_G.XthrlenConfig.AimTouchSGAutoFire    = false
_G.XthrlenConfig.AimTouchScopeSniper   = false
_G.XthrlenConfig.AimTouchMortar        = false
_G.XthrlenConfig.EspFovCircle          = false

_G.XthrlenState.CustomTextData.AimTouchHipPrio    = 1
_G.XthrlenState.CustomTextData.AimTouchHipBone    = 1
_G.XthrlenState.CustomTextData.AimTouchHipCond    = 1
_G.XthrlenState.CustomTextData.AimTouchHipSpeed   = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchHipDist    = 120
_G.XthrlenState.CustomTextData.AimTouchHipFOV     = 30

_G.XthrlenState.CustomTextData.AimTouchScopePrio   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeBone   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeCond   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeSpeed  = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchScopeDist   = 120
_G.XthrlenState.CustomTextData.AimTouchScopeFOV    = 30
_G.XthrlenState.CustomTextData.AimTouchScopePred   = 0

_G.XthrlenState.offPitch = _G.XthrlenState.offPitch or 0
_G.XthrlenState.offYaw   = _G.XthrlenState.offYaw   or 0

local function clampAngles(angles)
    if angles.Pitch > 180 then angles.Pitch = angles.Pitch - 360 end
    if angles.Pitch < -180 then angles.Pitch = angles.Pitch + 360 end

    if angles.Pitch < -75 then
        angles.Pitch = -75
    elseif angles.Pitch > 75 then
        angles.Pitch = 75
    end

    while angles.Yaw < -180 do angles.Yaw = angles.Yaw + 360 end
    while angles.Yaw > 180  do angles.Yaw = angles.Yaw - 360 end

    return angles
end

_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not (slua and slua.isValid and slua.isValid(player)) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()
    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    local ok,err=pcall(function()
        if not _G.XthrlenConfig.AimTouchEnable then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not (slua and slua.isValid and slua.isValid(player)) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not (slua and slua.isValid and slua.isValid(pc)) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        -- Both supplied hip/scope modes require firing. Return before scanning,
        -- weapon classification, visibility checks or imports during idle play.
        if not isFiring then return end
        
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        if _G.LunarFeatures.Settings.MortarEnabled and weapon and weapon.MortarState==2 then return end
        local isShotgun = false
        local isSniper = false
        local isMortar = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            if wName:lower():find("mortar") or wName:lower():find("cối") then
                isMortar = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if _G.XthrlenState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.XthrlenState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 100
        local fovVal = 30
        local maxDistMeters = 100
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        local predVal = 0 

        if isMortar and _G.XthrlenConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then return end

            cond = 2 
            prioMode = 1  
            boneIdx = 4 
            speedVal = 100 
            fovVal = _G.XthrlenState.CustomTextData.AimTouchMortarFOV or 360 
            maxDistMeters = 2000 
            useVisCheck = false 
            igKnock = false
            igBot = false
            predVal = _G.XthrlenState.CustomTextData.AimTouchMortarPred or 0 
            
        elseif isShotgun and _G.XthrlenConfig.AimTouchSG then
            cond = _G.XthrlenState.CustomTextData.AimTouchSGCond or 1
            if _G.XthrlenConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.XthrlenState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.XthrlenState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.XthrlenState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.XthrlenState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.XthrlenConfig.AimTouchSGVisCheck
            igKnock = _G.XthrlenConfig.AimTouchSGIgKnock
            igBot = _G.XthrlenConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.XthrlenConfig.AimTouchScopeSniper then
                cond = _G.XthrlenState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.XthrlenState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.XthrlenState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.XthrlenConfig.AimTouchSniperVisCheck
                igKnock = _G.XthrlenConfig.AimTouchSniperIgKnock
                igBot = _G.XthrlenConfig.AimTouchSniperIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.XthrlenConfig.AimTouchScopeAll then
                cond = _G.XthrlenState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchScopeSpeed or 100
                fovVal = _G.XthrlenState.CustomTextData.AimTouchScopeFOV or 30
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchScopeDist or 100
                useVisCheck = _G.XthrlenConfig.AimTouchScopeVisCheck
                igKnock = _G.XthrlenConfig.AimTouchScopeIgKnock
                igBot = _G.XthrlenConfig.AimTouchScopeIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchScopePred or 0
            else
                return
            end
        else
            if not _G.XthrlenConfig.AimTouchHipfire then return end
            cond = _G.XthrlenState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.XthrlenState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = 1
            speedVal = _G.XthrlenState.CustomTextData.AimTouchHipSpeed or 100
            fovVal = _G.XthrlenState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchHipDist or 100
            useVisCheck = _G.XthrlenConfig.AimTouchHipVisCheck
            igKnock = _G.XthrlenConfig.AimTouchHipIgKnock
            igBot = _G.XthrlenConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = AimV2
        local UGameplayStatics = AimGameplayStatics
        local KismetMathLibrary = AimMath
        if not FVector2D or not UGameplayStatics or not KismetMathLibrary then return end
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = AimUI
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selected=_G.LunarFeatures.Settings.AimTarget
        boneIdx=selected==2 and 2 or (selected==3 and 5 or 1)
        local selBoneName=selected==2 and "spine_03" or (selected==3 and "calf_l" or "head")

        for i, target in ipairs(enemies) do
            repeat
            if not slua.isValid(target) then break end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then break end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then break end
            end
            
            if useVisCheck then
                local curTime = _G.LunarFeatures.Now()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or curTime < _G.AimTouchVisCache[tId].time or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then break end
            end
            
            local tPos = target.GetBonePos and target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20
                        elseif boneIdx == 5 then tPos.Z = tPos.Z - 60 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then break end
            
            local screen = FVector2D()
            local success,outScreen = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if outScreen then screen=outScreen end
            if not success or screen.X <= 0 or screen.Y <= 0 then break end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then break end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            until true
        end
        
        local cache=_G.AimTouchVisCache
        local clock=_G.LunarFeatures.Now()
        if cache and (not _G.LunarFeatures.AimPruneDue or clock>=_G.LunarFeatures.AimPruneDue) then
            for key,entry in pairs(cache) do if clock<entry.time or clock-entry.time>1 then cache[key]=nil end end
            _G.LunarFeatures.AimPruneDue=clock+0.5
        end
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget.GetBonePos and bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20
                    elseif boneIdx == 5 then finalBonePos.Z = finalBonePos.Z - 60 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        if not isMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        if isADS and isFiring then
            local dist = player:GetDistanceTo(bestTarget) / 100.0
            finalBonePos.Z = finalBonePos.Z - (dist * 1.1)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        if not isADS then
            _G.XthrlenState.offPitch = 0
            _G.XthrlenState.offYaw   = 0
        end

        local dPitch = rot.Pitch - currentRot.Pitch
        local dYaw   = rot.Yaw   - currentRot.Yaw

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                dYaw   = dYaw   - (camRot.Yaw   - currentRot.Yaw)
                dPitch = dPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if dPitch~=dPitch or dYaw~=dYaw or math.abs(dPitch)==math.huge or math.abs(dYaw)==math.huge then return end
        dPitch=(dPitch+180)%360-180
        dYaw=(dYaw+180)%360-180

        -- Displayed settings remain 100..120. The requested maximum applies
        -- at most half the previous full correction; low settings are gentler.
        local now=_G.LunarFeatures.Now()
        local previous=_G.LunarFeatures.AimLastClock
        local dt=previous and math.max(0.001,math.min(0.05,now-previous)) or 0.011
        _G.LunarFeatures.AimLastClock=now
        local normalized=(_G.LunarFeatures.Clamp(speedVal,100,120,100)-100)/20.0
        local strength=0.02+0.48*normalized*normalized
        local alpha=math.min(0.5,1.0-(1.0-strength)^(dt/0.011))
        local maxTurnRate=10.0+35.0*normalized

        -- Camera-relative ADS error already accounts for view/controller offset.
        -- Repeatedly accumulating target error causes windup and unwanted swipes.
        _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
        local apply={Pitch=currentRot.Pitch+dPitch,Yaw=currentRot.Yaw+dYaw,Roll=0}

        local pitchDelta=(apply.Pitch-currentRot.Pitch+180)%360-180
        local yawDelta=(apply.Yaw-currentRot.Yaw+180)%360-180
        local pitchStep,yawStep=pitchDelta*alpha,yawDelta*alpha
        local stepLength=math.sqrt(pitchStep*pitchStep+yawStep*yawStep)
        local stepLimit=maxTurnRate*dt
        if stepLength>stepLimit then
            local scale=stepLimit/stepLength
            pitchStep=pitchStep*scale;yawStep=yawStep*scale
        end
        local out={Pitch=currentRot.Pitch+pitchStep,Yaw=currentRot.Yaw+yawStep,Roll=0}

        out = clampAngles(out)
        pc:SetControlRotation(out, "AimTouch")
    end)
    if not ok then _G.LunarFeatures.Error("Aim",err) end
end



_G.LunarFeatures.Aim={Tick=_G.AimTouch}
end

-- Controls live entirely in the native game settings page.

-- Additional aim modes share the managed scheduler. No timer is created here.
do
    local F=_G.LunarFeatures
    local MathLib,Layout,HealthStates,PawnStates
    pcall(function() MathLib=import("KismetMathLibrary") end)
    pcall(function() Layout=import("WidgetLayoutLibrary") end)
    pcall(function() HealthStates=import("ECharacterHealthStatus") end)
    pcall(function() PawnStates=import("EPawnState") end)
    local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
    local function get(obj,key)
        if not obj then return nil end
        local ok,v=pcall(function() return obj[key] end)
        if ok then return v end
    end
    local function call(obj,key,...)
        local method=get(obj,key)
        if type(method)~="function" then return nil end
        local ok,v=pcall(method,obj,...)
        if ok then return v end
    end
    local function valid(obj) return obj and g_UXOfficial_ESPValid(obj) end
    local function pos(v)
        if v and finite(v.X) and finite(v.Y) and finite(v.Z) then return {X=v.X,Y=v.Y,Z=v.Z} end
    end
    local function nativeVector(v) return g_UXOfficial_ESPV3(v.X,v.Y,v.Z) end
    local function team(actor)
        local id=call(actor,"GetTeamID") or get(actor,"TeamID")
        if id==nil then
            local state=call(actor,"GetPlayerStateSafety")
            id=call(state,"GetTeamID") or get(state,"TeamID")
        end
        return id
    end
    local function dead(actor)
        if not valid(actor) then return true end
        local hp=call(actor,"GetHealth") or get(actor,"Health") or get(actor,"HP")
        if finite(hp) and hp<=0 then return true end
        if get(actor,"bIsDead")==true or get(actor,"bDead")==true or get(actor,"bIsDeadFlag")==true then return true end
        if HealthStates and HealthStates.FinishedLastBreath~=nil and get(actor,"HealthStatus")==HealthStates.FinishedLastBreath then return true end
        if PawnStates and PawnStates.Dead~=nil and call(actor,"HasPawnState",PawnStates.Dead)==true then return true end
        return false
    end
    local function weapon(player)
        local w=call(player,"GetCurrentWeapon") or get(player,"CurrentWeapon")
        if not valid(w) then
            local wm=get(player,"WeaponManagerComponent")
            w=get(wm,"CurrentWeaponReplicated") or get(wm,"CurrentWeapon")
        end
        return valid(w) and w or nil
    end
    local function kind(w)
        local name=call(w,"GetWeaponName")
        if type(name)~="string" or not name:find("%S") then return "unknown" end
        name=name:lower()
        if name:find("mortar",1,true) or name:find("cối",1,true) or name:find("cỐi",1,true) then return "mortar" end
        return "other"
    end
    local function context()
        local pc=g_UXOfficial_ESPGetController()
        local player=g_UXOfficial_ESPGetLocalCharacter()
        if valid(pc) and not dead(player) then return g_UXOfficial_ESPWorld(),pc,player,weapon(player) end
    end
    local function pelvis(actor)
        local p=pos(call(actor,"GetBonePos","pelvis",{X=0,Y=0,Z=0}))
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"GetSocketLocation","pelvis")) end
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"K2_GetActorLocation")) end
        return p
    end
    local function allPlayers()
        local list
        pcall(function() if GameplayData.GetAllPlayerCharacters then list=GameplayData.GetAllPlayerCharacters() end end)
        return type(list)=="table" and list or {}
    end
    local function viewport(pc)
        local w,h=g_UXOfficial_ESPViewport(pc)
        if not finite(w) or w<=0 or not finite(h) or h<=0 then return 1920,1080 end
        return w,h
    end
    local function project(pc,p)
        local screen=FVector2D(0,0)
        local ok,yes=pcall(function() return pc:ProjectWorldLocationToScreen(nativeVector(p),screen,false) end)
        if ok and (yes==true or yes==1) and finite(screen.X) and finite(screen.Y) then return screen.X,screen.Y end
    end
    local function camera(pc,player,fallback)
        local cm=call(pc,"GetPlayerCameraManager")
        if not valid(cm) then pcall(function() cm=GameplayStaticsESP.GetPlayerCameraManager(pc,0) end) end
        return pos(call(cm,"GetCameraLocation")) or fallback or pos(call(player,"K2_GetActorLocation"))
    end
    local function rotation(pc,target,source)
        if not target or not finite(target.Pitch) or not finite(target.Yaw) or not finite(target.Roll) then return false end
        local current=call(pc,"GetControlRotation")
        if current and finite(current.Pitch) and finite(current.Yaw) and finite(current.Roll or 0)
            and math.abs((target.Pitch-current.Pitch+180)%360-180)<0.00001
            and math.abs((target.Yaw-current.Yaw+180)%360-180)<0.00001
            and math.abs(target.Roll-(current.Roll or 0))<0.00001 then return true end
        local ok,accepted=pcall(function() return pc:SetControlRotation(target,source) end)
        if not ok then F.Error(source,accepted) end
        return ok and accepted~=false
    end
    -- A failed restore survives a script reload and remains eligible for retry.
    local pending=_G.__LunarAim2RestorePending or {}
    _G.__LunarAim2RestorePending=pending
    local A={Target=nil,Enabled=false,Due=0,LastTime=nil,Records=pending,RestoreErrors={}}
    F.Aim2=A
    local fields={"RecoilKickADS","GameDeviationFactor","GameDeviationAccuracy"}
    local function restore()
        for obj,record in pairs(A.Records) do
            if not valid(obj) then A.Records[obj]=nil;A.RestoreErrors[obj]=nil
            else
                for key,value in pairs(record) do
                    local ok,err=true,nil
                    if get(obj,key)~=value then ok,err=pcall(function() obj[key]=value end) end
                    if ok and get(obj,key)==value then record[key]=nil
                    elseif not A.RestoreErrors[obj] or not A.RestoreErrors[obj][key] then
                        A.RestoreErrors[obj]=A.RestoreErrors[obj] or {};A.RestoreErrors[obj][key]=true
                        F.Error("Aim2.Restore."..key,err or "native field did not accept restoration")
                    end
                end
                if next(record)==nil then A.Records[obj]=nil;A.RestoreErrors[obj]=nil end
            end
        end
    end
    function A.Stop()
        restore();A.Target=nil;A.Enabled=false;A.LastTime=nil;A.World=nil;A.PC=nil;A.Player=nil;A.Weapon=nil;A.Entity=nil;A.Due=0;A.Unsupported=nil;A.ApplyFailed=nil
    end
    function A.NextInterval(now)
        if not F.Settings.Aim2Enabled then return 0.5 end
        return math.max(0.001,A.Due-(finite(now) and now or F.Now()))
    end
    local function hard(entity)
        if not valid(entity) then return end
        local record=A.Records[entity]
        if not record then record={};A.Records[entity]=record end
        for _,key in ipairs(fields) do
            local current=get(entity,key)
            if finite(current) then
                if record[key]==nil then record[key]=current end
                if current~=0.01 then
                    local ok,err=pcall(function() entity[key]=0.01 end)
                    if not ok and (not A.ApplyFailed or not A.ApplyFailed[key]) then
                        A.ApplyFailed=A.ApplyFailed or {};A.ApplyFailed[key]=true;F.Error("Aim2.Apply."..key,err)
                    end
                end
            elseif not A.Unsupported or not A.Unsupported[key] then
                A.Unsupported=A.Unsupported or {};A.Unsupported[key]=true
                F.Error("Aim2.Unsupported",key.." is unreadable; left unchanged")
            end
        end
    end
    function A.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.Aim2Enabled then if A.Player or next(A.Records) then A.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)=="mortar" then A.Stop();A.Due=now+0.5;return false end
        local entity=get(w,"ShootWeaponEntityComp")
        if A.World~=world or A.PC~=pc or A.Player~=player or A.Weapon~=w or A.Entity~=entity then
            A.Stop();A.World=world;A.PC=pc;A.Player=player;A.Weapon=w;A.Entity=entity
        end
        if now<A.Due-0.000001 and (not A.LastTime or now>=A.LastTime) then return false end
        local dt=A.LastTime and now-A.LastTime or 0.5
        if not finite(dt) or dt<=0 then dt=0.5 end
        A.LastTime=now;A.Due=now+0.5;hard(entity)
        if get(player,"bIsWeaponAiming")~=true then A.Target=nil;A.Enabled=false;A.Due=now+0.2;return false end
        if not MathLib or not MathLib.FindLookAtRotation then return false end
        local myTeam=team(player)
        if myTeam==nil then return false end
        local width,height=viewport(pc)
        local scale=1
        pcall(function() if Layout and Layout.GetViewportScale then local s=Layout.GetViewportScale(pc);if finite(s) and s>0 then scale=s end end end)
        -- Reference circle is 150 UI units, with its inner 70% used for selection.
        local rx,ry=105*scale,105*scale
        local best,bestScore=nil,math.huge
        for _,enemy in pairs(allPlayers()) do
            if enemy~=player and not dead(enemy) then
                local enemyTeam=team(enemy)
                if enemyTeam~=nil and tostring(enemyTeam)~=tostring(myTeam) then
                    local p=pelvis(enemy)
                    if p then
                        local x,y=project(pc,p)
                        if x and x>=0 and y>=0 and x<=width and y<=height then
                            local dx,dy=(x-width/2)/rx,(y-height/2)/ry
                            local score=dx*dx+dy*dy
                            if finite(score) and score<=1 and score<bestScore then best,bestScore=enemy,score end
                        end
                    end
                end
            end
        end
        A.Target=best;A.Enabled=best~=nil
        if not best then return false end
        local loc,p=camera(pc,player),pelvis(best)
        if not loc or not p then return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(loc),nativeVector(p))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Pitch) or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local dp,dy=(desired.Pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local dist=math.sqrt(dp*dp+dy*dy)
        local step=90*math.min(dt,0.5)
        local fraction=dist>step and step/dist or 1
        local final={Pitch=current.Pitch+dp*fraction,Yaw=current.Yaw+dy*fraction,Roll=current.Roll or 0}
        local w2,pc2,p2,wCurrent=context()
        if not F.Settings.Aim2Enabled or world~=w2 or pc~=pc2 or player~=p2 or w~=wCurrent or get(player,"bIsWeaponAiming")~=true or dead(best) then A.Stop();return false end
        return rotation(pc,final,"CircleAim")
    end
    local M={Target=nil,Candidates={},ScanDue=0,Due=0,LastTime=nil,Status="inactive",ActivePlaced=false}
    F.Mortar=M
    function M.Stop()
        M.Target=nil;M.Candidates={};M.ScanDue=0;M.Due=0;M.LastTime=nil;M.World=nil;M.PC=nil;M.Player=nil;M.Weapon=nil;M.ActivePlaced=false;M.Status="inactive"
    end
    local function distance(player,target)
        local d=call(player,"GetDistanceTo",target)
        if finite(d) and d>=0 then return d end
        local a,b=pos(call(player,"K2_GetActorLocation")),pos(call(target,"K2_GetActorLocation"))
        if a and b then local dx,dy,dz=a.X-b.X,a.Y-b.Y,a.Z-b.Z;d=math.sqrt(dx*dx+dy*dy+dz*dz);if finite(d) then return d end end
    end
    local function enemy(player,target)
        if target==player or dead(target) then return false end
        local mine,theirs=team(player),team(target)
        if mine~=nil and theirs~=nil and tostring(mine)==tostring(theirs) then return false end
        local d=distance(player,target)
        return finite(d) and d<=200000
    end
    local function trajectory(launch,V,G,target)
        if not pos(launch) or not pos(target) or not finite(V) or V<=0 or not finite(G) or G<=0 then return false,45,0,0 end
        local dx=math.max(500,math.sqrt((target.X-launch.X)^2+(target.Y-launch.Y)^2)-80)
        local dy=target.Z-launch.Z
        local minVSq=G*(dy+math.sqrt(dx*dx+dy*dy))
        if not finite(dx) or not finite(minVSq) then return false,45,0,0 end
        if V*V<minVSq then V=math.sqrt(math.max(0,minVSq))+100 end
        local v2=V*V
        local root=v2*v2-G*(G*dx*dx+2*dy*v2)
        if not finite(root) or root<0 then return false,45,0,dx end
        local rad=math.atan((v2+math.sqrt(root))/(G*dx))
        local deg,tof=math.deg(rad),dx/(V*math.cos(rad))
        if finite(deg) and finite(tof) and tof>0 and deg>=35 and deg<=89.5 then return true,deg,tof,dx end
        return false,45,0,dx
    end
    local function solve(launch,target)
        local okN,aN,tN,dN=trajectory(launch,9070,2744,target)
        local okF,aF,tF,dF=trajectory(launch,12520,3920,target)
        local okU,aU,tU,dU=trajectory(launch,16800,4410,target)
        if okN and dN<=25000 then return true,aN,tN,dN end
        if okF and dF<=40000 then return true,aF,tF,dF end
        if okU then return true,aU,tU,dU end
        if okN then return true,aN,tN,dN end
        return false,45,0,dN
    end
    M.SolveTrajectory=solve
    local function predict(target,base,launch)
        local velocity=call(target,"GetVelocity")
        if not velocity or not finite(velocity.X) or not finite(velocity.Y) or math.abs(velocity.X)+math.abs(velocity.Y)<0.01 then return base end
        local predicted={X=base.X,Y=base.Y,Z=base.Z}
        local fallback
        for _=1,2 do
            local ok,a,tof,d=solve(launch,predicted)
            if not ok then break end
            fallback={ok,a,tof,d}
            if tof<=0 or tof>15 then break end
            predicted.X=base.X+velocity.X*tof;predicted.Y=base.Y+velocity.Y*tof
            if not pos(predicted) then return base end
        end
        return predicted,fallback
    end
    function M.NextInterval(now)
        if not F.Settings.MortarEnabled then return 0.5 end
        return math.max(0.001,M.Due-(finite(now) and now or F.Now()))
    end
    function M.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.MortarEnabled then if M.Player then M.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)~="mortar" or get(w,"MortarState")~=2 then
            M.Stop();M.Status="not_placed_mortar";M.Due=now+0.5;return false
        end
        if M.World~=world or M.PC~=pc or M.Player~=player or M.Weapon~=w then
            M.Stop();M.World=world;M.PC=pc;M.Player=player;M.Weapon=w
        end
        if now<M.Due-0.000001 and (not M.LastTime or now>=M.LastTime) then return false end
        M.LastTime=now;M.Due=now+0.5;M.ActivePlaced=true;M.Status="targeting"
        if not enemy(player,M.Target) then
            M.Target=nil
            if now>=M.ScanDue then M.Candidates=allPlayers();M.ScanDue=now+0.25 end
            local width,height=viewport(pc)
            local best,score=nil,math.huge
            for _,target in pairs(M.Candidates) do
                if enemy(player,target) then
                    local p=pelvis(target)
                    if p then local x,y=project(pc,p)
                        if x and x>0 and y>0 then
                            local dx,dy=x-width/2,y-height/2
                            local d=dx*dx+dy*dy
                            if finite(d) and d<score and d<=(3.6*width/2)^2 then best,score=target,d end
                        end
                    end
                end
            end
            M.Target=best
        end
        local target=M.Target
        if not target then M.Status="no_target";return false end
        local base,launch=pelvis(target),pos(call(player,"K2_GetActorLocation"))
        if not base or not launch then M.Status="position_unavailable";return false end
        launch.Z=launch.Z+50
        local predicted,fallback=predict(target,base,launch)
        local ok,angle,tof=solve(launch,predicted)
        if not ok and fallback then ok,angle,tof=fallback[1],fallback[2],fallback[3] end
        if not ok or not finite(tof) or not finite(angle) then M.Status="unreachable";return false end
        if not MathLib or not MathLib.FindLookAtRotation then M.Status="math_unavailable";return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(camera(pc,player,launch)),nativeVector(predicted))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local pitch=((angle-45)/43)*90-60
        local dp,dy=(pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local final={Pitch=current.Pitch+dp,Yaw=current.Yaw+dy,Roll=0}
        local world2,pc2,player2,w2=context()
        if not F.Settings.MortarEnabled or world2~=world or pc2~=pc or player2~=player or w2~=w or get(w,"MortarState")~=2 or not enemy(player,target) then M.Stop();return false end
        local accepted=rotation(pc,final,"MortarAim")
        M.Status=accepted and "rotation_call_accepted" or "rotation_failed"
        return accepted
    end
end

-- Remaining features share the existing ESP V2 runner; no extra timer is created.
do
    local F=_G.LunarFeatures
    local function checked(fn,area,...)
        local ok,err=pcall(fn,...)
        if not ok then F.Error(area,err) end
    end
    F.AimDue=0;F.IpadDue=0;F.SaveDue=0
    F.Pump=function(now)
        F.TimerClock=g_UXOfficial_ShotESP.TimerClock
        now=now or F.Now()
        local welcome=_G.LunarWelcomeRuntime
        if welcome and welcome.NeedsUpdate and
            (not F.WelcomeDue or now>=F.WelcomeDue or now<(F.WelcomeLastClock or now)) then
            checked(welcome.Update,"Welcome.Update")
            F.WelcomeDue=now+0.5;F.WelcomeLastClock=now
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
        local world=g_UXOfficial_ESPWorld()
        local pc=g_UXOfficial_ESPGetController()
        local pawn=g_UXOfficial_ESPGetLocalCharacter()
        if world~=F.LastWorld or pc~=F.LastPC or pawn~=F.LastPawn then
            checked(F.Aim2.Stop,"Aim2.Reset")
            checked(F.Mortar.Stop,"Mortar.Reset")
            _G.AimTouchVisCache={}
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
            F.AimLastClock=nil
            F.AimDue=0;F.IpadDue=0
            F.LastWorld,F.LastPC,F.LastPawn=world,pc,pawn
        end
        if not pc or not pawn then
            if F.Aim2.Player or next(F.Aim2.Records) then checked(F.Aim2.Stop,"Aim2.NoPlayer") end
            if F.Mortar.Player then checked(F.Mortar.Stop,"Mortar.NoPlayer") end
            return
        end
        if F.Settings.Aim2Enabled and
            (now>=F.Aim2.Due-0.000001 or (F.Aim2.LastTime and now<F.Aim2.LastTime)) then
            checked(F.Aim2.Tick,"Aim2.Tick")
        elseif not F.Settings.Aim2Enabled and next(F.Aim2.Records) and now>=(F.Aim2RestoreDue or 0) then
            checked(F.Aim2.Stop,"Aim2.Restore")
            F.Aim2RestoreDue=now+0.5
        end
        if F.Settings.MortarEnabled and
            (now>=F.Mortar.Due-0.000001 or (F.Mortar.LastTime and now<F.Mortar.LastTime)) then
            checked(F.Mortar.Tick,"Mortar.Tick")
        end
        if F.Settings.AimEnabled then
            if now>=F.AimDue-0.000001 or (F.AimLastTick and now<F.AimLastTick) then
                checked(F.Aim.Tick,"Aim.Render")
                F.AimLastTick=now
                F.AimDue=now+((pawn and pawn.bIsWeaponFiring) and 0.011 or 0.05)
                if not (pawn and pawn.bIsWeaponFiring) then F.AimLastClock=nil end
            end
        end
        if _G.LexusConfig.IpadView and now>=F.IpadDue then
            checked(g_UXOfficial_ApplyiPadView,"Ipad")
            F.IpadDue=now+0.5
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
    end
    F.NextInterval=function(now)
        if not F.LastPC or not F.LastPawn then return 0.50 end
        local nextDelay=0.50
        local function due(deadline) nextDelay=math.min(nextDelay,math.max(0.001,(deadline or now)-now)) end
        if F.Settings.AimEnabled then due(F.AimDue) end
        if F.Settings.Aim2Enabled then nextDelay=math.min(nextDelay,F.Aim2.NextInterval(now))
        elseif next(F.Aim2.Records) then due(F.Aim2RestoreDue) end
        if F.Settings.MortarEnabled then nextDelay=math.min(nextDelay,F.Mortar.NextInterval(now)) end
        if _G.LexusConfig.IpadView then due(F.IpadDue) end
        if F.Dirty then due(F.SaveDue) end
        return nextDelay
    end
    F.Wake=function()
        if F.Token.Stopped then return end
        local welcome=_G.LunarWelcomeRuntime
        if welcome and welcome.NeedsUpdate then F.WelcomeDue=0 end
        F.AimDue=0
        if F.Aim2 then F.Aim2.Due=0 end
        if F.Mortar then F.Mortar.Due=0 end
        local due=g_UXOfficial_ESPRunnerToken.Due
        if not due or due-g_UXOfficial_ESPNow()>0.002 then g_UXOfficial_ESPSchedule(0.001) end
    end
end


-- Settings maintenance uses the working reference's native timer fallbacks.
local g_UXOfficial_FastRunnerToken = {}
local previousSettingsRunner = _G.__UXOfficialShotFastRunner
if type(previousSettingsRunner) == "table" and previousSettingsRunner.Timer and previousSettingsRunner.Owner then
    pcall(function() previousSettingsRunner.Owner:RemoveGameTimer(previousSettingsRunner.Timer) end)
end
_G.__UXOfficialShotFastRunner = g_UXOfficial_FastRunnerToken
local function g_UXOfficial_FastTick()
    if _G.__UXOfficialShotFastRunner ~= g_UXOfficial_FastRunnerToken then return end
    g_UXOfficial_EnsureHackMenu()
    local render=_G.__UXOfficialShotESPRunner
    if not render or not render.Due then pcall(g_UXOfficial_ApplyiPadView) end
end
do
    local token = g_UXOfficial_FastRunnerToken
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function valid(object)
        if object == nil then return false end
        if slua and type(slua.isValid) == "function" then
            local ok, value = pcall(slua.isValid, object)
            return ok and value == true
        end
        return false
    end
    local function timerOwnerReady(owner)
        return owner ~= nil and (owner == Game or valid(owner) or valid(member(owner, "Object")))
    end
    local function callback()
        if _G.__UXOfficialShotFastRunner ~= token then
            if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
            token.Timer = nil
            return
        end
        g_UXOfficial_FastTick()
        g_UXOfficial_StartSettingsMaintenance()
    end
    g_UXOfficial_StartSettingsMaintenance = function(owner)
        if _G.__UXOfficialShotFastRunner ~= token then return false end
        if token.Pending then return true end
        if token.Timer and (token.Provider == "ticker" or timerOwnerReady(token.Owner)) then return true end
        if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
        token.Timer, token.Owner, token.Provider = nil, nil, nil

        local candidates = {}
        local function add(candidate, kind)
            if not timerOwnerReady(candidate) or type(member(candidate, "AddGameTimer")) ~= "function" then return end
            for _, entry in ipairs(candidates) do if entry.Object == candidate then return end end
            candidates[#candidates + 1] = {Object = candidate, Kind = kind}
        end
        local pc
        pcall(function() if GameplayData.GetPlayerController then pc = GameplayData.GetPlayerController() end end)
        if not valid(pc) then pcall(function() if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end end) end
        add(pc, "controller")
        add(owner, "character")
        add(Game, "game")
        for _, entry in ipairs(candidates) do
            local ok, timer = pcall(function() return entry.Object:AddGameTimer(1.0, true, callback) end)
            if ok and timer then
                token.Timer, token.Owner, token.Provider = timer, entry.Object, entry.Kind
                token.LastError = nil
                g_UXOfficial_FastTick()
                return true
            end
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker then
            if type(ticker.AddTimer) == "function" then
                local ok, timer = pcall(ticker.AddTimer, 1.0, true, callback)
                if ok and timer then
                    token.Timer, token.Owner, token.Provider = timer, ticker, "ticker"
                    token.LastError = nil
                    return true
                end
            end
            if type(ticker.AddTimerOnce) == "function" then
                token.Pending, token.Provider = true, "ticker_once"
                local ok, accepted = pcall(ticker.AddTimerOnce, 1.0, function()
                    token.Pending = false
                    callback()
                end)
                if ok and accepted ~= false then token.LastError = nil; return true end
                token.Pending, token.Provider = false, nil
                token.LastError = tostring(accepted)
            else token.LastError = "SETTINGS_TIMER_API_UNAVAILABLE" end
        else
            if package and package.loaded and type(package.loaded["common.time_ticker"]) ~= "table" then
                package.loaded["common.time_ticker"] = nil
            end
            token.LastError = tostring(ticker)
        end
        return false
    end
end

g_UXOfficial_EnsureHackMenu()
if _G.LunarWelcomeRuntime then _G.LunarWelcomeRuntime.NeedsUpdate=true end
g_UXOfficial_FastTick()
g_UXOfficial_StartSettingsMaintenance()
g_UXOfficial_ShotESP.Running = true
g_UXOfficial_ESPTick()

-- ============================================================================
-- ORIGINAL GAME CLASS AND FEATURE REGISTRATION START
-- Supplied native keys and paths appear once; existing unique additions follow.
-- ============================================================================
-- ⚡ EXPIRY SYSTEM (FIXED)
-- ========================================================================
local EXPIRY_TIMESTAMP = os.time({ year = 2027, month = 10, day = 26, hour = 12, min = 0, sec = 0 })

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
            Msg.Show(4, "MOD EXPIRED", "THIS MOD HAS EXPIRED.\n\nEXPIRED ON: " .. expiresAt .. "\n\nTEXT Me to buy @VIP FILE", onClick)
        else
            local remaining = _G._MOD_REMAINING_SECONDS or (EXPIRY_TIMESTAMP - os.time())
            local formatted = FormatTimeRemaining(remaining)
            local expiresAt = os.date("!%Y-%m-%d %H:%M:%S UTC", EXPIRY_TIMESTAMP)
            Msg.Show(4, "NOTIFICATION", "MOD VALIDITY: " .. formatted .. "\nEXPIRES AT: " .. expiresAt .. "\n\nFOR RENEWAL DM @VIP FILE", onClick)
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
-- ========================================== 
-- VIP MENU POPUP – PREMIUM BLACK + GOLD (Welcome + Scam Alert)
-- ==========================================
function ShowLexusVIPMenu()   -- keep same name as your MainLoop call
    if _G.LexusMenuAlreadyShown then return end
    if _G.LexusState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_ScamAlert()
            Msg.Show(1, "✦ VIP FILE | GOLD EDITION ✦", "DON'T PLAY LIKE A ANIMAL \nAVOID REPORTS PLAY SAFE!!\n\nNO FEEDBACK - NO MORE UPDATES", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://wa.me/923060004752") end
                end, 
                function() end, 
                "JOIN", "CLOSE")
            _G.LexusState.MenuStep = 99
            _G.LexusMenuAlreadyShown = true
        end

        local function Step_Welcome()
            Msg.Show(1, "✦ @VIP FILE | PREMIUM ✦", "ACTIVATION SUCCESSFUL!\n\nThis Is Paid Mode Leaked By VIP FILE  MODS DM THE OWNER TO GET YOUR FILE.\nAVOID THE SCAMMERS AND COPY PASTERS, THE REAL OWNER IS @VIP FILE ",
                function() 
                    _G.InitModMenuTab()
                    Notify("VIP MOD MENU BY @VIP FILE  🔥to toggle features!")
                    Step_ScamAlert()
                end, 
                function() end, 
                "OK", "CLOSE")
        end

        _G.LexusState.MenuStep = 1
        Step_Welcome() 
    end)
end

-- Fire expiry/welcome popup 4 seconds after load (same as Z3ROX.lua)
pcall(function()
    local ok, tk = pcall(require, "common.time_ticker")
    if ok and tk and tk.AddTimerOnce then
        tk.AddTimerOnce(3, function() pcall(CheckExpiration) end)
        tk.AddTimerOnce(4, function()
            if not CheckExpiration() then pcall(ShowExpiryPopup, true)
            else pcall(_G.TryShowWelcome) end
        end)
    else
        pcall(_G.TryShowWelcome)
    end
end)

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  },
  {
    FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"
  },
  -- Existing additional game feature retained from the main script.
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
}, "BRPlayerCharacterBase")
-- ORIGINAL GAME CLASS AND FEATURE REGISTRATION END
