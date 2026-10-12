AddCSLuaFile()
if not DT_Base then return end
ENT.Base, ENT.Type = "npc_dt_za1_elite", "nextbot"
ENT.DT_NextBot, ENT.DT_Version, ENT.Spawnable = true, 1, false
ENT.Category = "Zombie Army Trilogy"
if CLIENT then
    function ENT:OnThink() ZA1.Presentation.Update(self) end
    function ENT:OnDraw()
        self:DrawModel()
        if self.ZASpecial == "sniper" then ZA1.Sniper.Draw(self) end
    end
    return
end
local W, B, J, K = ZA1.MajorGuns, ZA1.General, ZA1.Sniper, ZA1.MG42
local M, N = ZA1.Manager, ZA1.Navigation
function ENT:OnInitialize()
    ZA1.Specials.Initialize(self); ZA1.Elites.Initialize(self)
    if self.ZASpecial == "general" then B.Initialize(self)
    else
        W.Initialize(self)
        if self.ZASpecial == "mg42" then K.Initialize(self) end
        if self.ZASpecial == "sniper" then J.Initialize(self) end
        self.ZAMajorPossessed = self:IsPossessed()
    end
end
function ENT:OnThink()
    ZA1.Specials.Tick(self); ZA1.Elites.Tick(self)
    if self.ZASpecial ~= "general" then
        local possessed = self:IsPossessed()
        if possessed ~= self.ZAMajorPossessed then
            if self.ZASpecial == "mg42" then K.Interrupt(self, "possession_changed")
            else J.Clear(self) end
        end
        self.ZAMajorPossessed = possessed
        W.Tick(self)
        if self.ZASpecial == "mg42" then K.Tick(self) end
        if self.ZASpecial == "sniper" then J.Tick(self) end
    end
end
function ENT:OnRemove()
    if self.ZASpecial == "general" then B.Stop(self)
    elseif self.ZASpecial == "mg42" then K.Interrupt(self, "removed")
    else W.Stop(self); J.Clear(self) end
    return baseclass.Get("npc_dt_za1_elite").OnRemove(self)
end
function ENT:OnError(err)
    if self.ZASpecial == "general" then B.Stop(self)
    elseif self.ZASpecial == "mg42" then K.Interrupt(self, "error")
    else W.Stop(self); J.Clear(self) end
    return baseclass.Get("npc_dt_za1_zombie").OnError(self, err)
end
function ENT:ZACombat(enemy)
    if self.ZASpecial == "general" then B.Decide(self); return true end
    if self.ZASpecial == "mg42" then return K.Combat(self, enemy) end
    return J.Combat(self, enemy)
end
function ENT:ZADecide()
    if self.ZASpecial == "general" then return B.Decide(self) end
    if not self:HasEnemy() then
        if self.ZASpecial == "mg42" then if K.Idle(self) then return end
        elseif J.Idle(self) then return end
    end
    return baseclass.Get("npc_dt_za1_elite").ZADecide(self)
end
function ENT:DoThink()
    if not self:Alive() or self.ZAGeneralDefeated or self.__DT_PhysgunPickup then return end
    local controls = self:GetPossessionControls()
    if self.ZASpecial == "general" then
        if self:IsAIDisabled() then N.Cancel(self); return end
        if self.ZAEmerge then
            local seq = self.ZAEmerge; self.ZAEmerge = nil
            ZA1.ResurrectionFX.Emerge(self, seq)
            ZA1.Elites.Play(self, seq); return
        end
        if CurTime() >= (self.ZANextDecision or 0) then
            self.ZANextDecision = CurTime() + .25
            self:SetAIState(IsValid(controls) and DT_Base.AI_STATE_POSSESSION or self:HasEnemy() and DT_Base.AI_STATE_COMBAT or DT_Base.AI_STATE_REST)
            B.Decide(self, not IsValid(controls) or controls:KeyDown(IN_ATTACK))
        end
        return
    end
    if not IsValid(controls) then return baseclass.Get("npc_dt_za1_zombie").DoThink(self) end
    if not self.ZAWasPossessed then N.Cancel(self); ZA1.Crowd.Release(self); self.ZAWasPossessed = true end
    if self.ZADowned then if self.ZADowned.ready then ZA1.Recovery.GetUp(self) end; return end
    self:SetAIState(DT_Base.AI_STATE_POSSESSION)
    controls:ApproachMoveDirection(); controls:FaceMoveDirection()
    if W.Chamber(self) then return end
    if controls:KeyDown(IN_RELOAD) and self.ZAGunAmmo < self.ZASpecialSettings.Gun.Magazine or self.ZAGunAmmo == 0 then W.Reload(self); return end
    if controls:KeyDown(IN_ATTACK2) then
        W.Stop(self); ZA1.Elites.Attack(self)
    elseif controls:KeyDown(IN_ATTACK) then
        local goal = controls:TraceLine().HitPos
        if self:GetVelocity():Length2D() < 2 then self:FaceTowards(goal) end
        W.Request(self, nil, goal)
    else W.Stop(self) end
end
function ENT:OnWounded(info, tr)
    -- General damage is filtered before health changes by ZA1/GeneralDamage.
    if self.ZASpecial == "general" then return end
    baseclass.Get("npc_dt_za1_elite").OnWounded(self, info, tr)
    if self.ZASpecial == "mg42" then K.Damage(self, info, self.ZADownedHitTrace or tr) end
    if self.ZASpecial == "sniper" then J.Damage(self, info, self.ZADownedHitTrace or tr) end
    if self.ZAPainPending or info:GetDamage() >= self:Health() then
        if self.ZASpecial == "mg42" then K.Interrupt(self, "wounded") else J.Interrupt(self) end
    end
end
function ENT:DoWounded(info, tr)
    if self.ZASpecial == "general" then return end
    if self.ZASpecial == "sniper" then return W.Flinch(self, info, tr) end
    if self.ZASpecial == "mg42" then return K.Flinch(self) end
    return ZA1.Elites.Flinch(self, info, tr)
end
function ENT:HandleAnimEvent(event, time, cycle, typ, options)
    if self.ZASpecial ~= "general" and W.Event(self, event, time, cycle, typ, options) then return true end
    return baseclass.Get("npc_dt_za1_elite").HandleAnimEvent(self, event, time, cycle, typ, options)
end
function ENT:OnIncapacitated(info)
    if self.ZASpecial == "general" then self.ZAGeneralDefeated = true; B.Stop(self)
    elseif self.ZASpecial == "mg42" then K.Interrupt(self, "incapacitated")
    else W.Stop(self); J.Clear(self) end
    return baseclass.Get("npc_dt_za1_elite").OnIncapacitated(self, info)
end
function ENT:RagdollOrRemove(info, tr)
    if self.ZASpecial == "general" then self:Remove(); return end
    return baseclass.Get("npc_dt_za1_special").RagdollOrRemove(self, info, tr)
end
function ENT:DoIncapacitated(info, tr)
    if self.ZASpecial == "general" then return B.Die(self) end
    if self.ZAHeadDestroyed or info:IsExplosionDamage() then return end
    local name = self.ZASpecialSettings.Death
    if self.ZASpecial == "sniper" then
        local bank = self.ZAGunData.Death
        local pool = bank and bank[W.HitSide(self, info, tr)]
        name = pool and pool[math.random(#pool)]
    end
    if not name then return end
    local seq = self:LookupSequence(name)
    if seq < 0 then return end
    self.ZADeathPlaying = true
    local id = self:PlaySequence(seq, {move = true})
    self.__DT_PlaySeq_PreviousSeq, self.__DT_PlaySeq_PreviousCycle = id, 0
    local start = CurTime()
    local flags = DT_Base.ToYieldFlags({doWounded = false, doIncapacitated = false})
    local duration = self.ZASpecialSettings.RagdollTime or self:SequenceDuration(id)
    while IsValid(self) and self:GetSequence() == id and CurTime() - start < duration do coroutine.yield(flags) end
    self.ZADeathPlaying = nil
end
