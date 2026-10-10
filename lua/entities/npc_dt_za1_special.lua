AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_zombie"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.Category = "Zombie Army Trilogy"
ENT.ZA1Zombie = true
if SERVER then
    local S = ZA1.Specials
    function ENT:OnInitialize() S.Initialize(self) end
    function ENT:OnThink() S.Tick(self) end
    function ENT:OnRemove() S.StopVoice(self); ZA1.Recovery.Clear(self); ZA1.Manager.Unregister(self) end
    function ENT:OnEntityDetected(ent)
        if not self:IsHatedEntity(ent) then return end
        ZA1.Manager.Wake(self); ZA1.Manager.Alert(self, ent:GetPos())
    end
    function ENT:ZARefreshHitboxes() S.RefreshHitboxes(self) end
    function ENT:OnTraceAttack(info, dir, tr)
        S.Trace(self, info, dir, tr)
        return baseclass.Get("base_dt_nextbot").OnTraceAttack(self, info, dir, tr)
    end
    function ENT:OnWounded(info, tr) S.Wounded(self, info, self.ZADownedHitTrace or tr) end
    function ENT:DoWounded(info)
        if self.ZASpecial ~= "suicide" and self.ZASpecial ~= "heavy" or self.ZAFuse or self.ZAActing or self.ZADowned or not self:Alive()
            or self:IsPossessed() or self:IsAIDisabled() or info:GetDamage() >= self:Health()
            or info:GetDamage() < ZA1.Config.Flinch.MinDamage or CurTime() < (self.ZANextFlinch or 0) then return end
        self.ZANextFlinch = CurTime() + 10
        local settings, sequence = self.ZASpecialSettings, self.ZASpecialSettings.Flinch
        if self.ZASpecial == "heavy" then
            local tr = self.ZAHeavyLastTrace
            if tr and tr.HitGroup == HITGROUP_HEAD then sequence = settings.FlinchHead
            elseif tr and tr.ZAShotDirection and tr.ZAShotDirection:Dot(self:GetForward()) > 0 then sequence = settings.FlinchBack end
        end
        self:ZAPlayOnce(sequence)
        self.ZANextFlinch = CurTime() + (settings.FlinchCooldown or ZA1.Config.Flinch.Cooldown)
    end
    function ENT:HandleAnimEvent(...) return S.Event(self, ...) end
    function ENT:OnKilled(info)
        if self.ZADeathHandled then return end
        return baseclass.Get("base_dt_nextbot").OnKilled(self, info)
    end
    function ENT:OnIncapacitated(info) S.Died(self, info) end
    function ENT:RagdollOrRemove(info, tr)
        if IsValid(self.ZAExistingCorpse) then self:Remove(); return end
        if self.ZABrokenApart then self:Remove(); return end
        return baseclass.Get("base_dt_nextbot").RagdollOrRemove(self, info, tr)
    end
    function ENT:OnRagdoll(rag)
        if self.ZAHeadLayout then
            rag.ZAHeadLayout = self.ZAHeadLayout
            for group = 0, self.ZAHeadLayout.Bodygroups - 1 do rag:SetBodygroup(group, self:GetBodygroup(group)) end
            ZA1.Gore.Ragdoll(self, rag)
        end
        if self.ZASpecial == "heavy" then S.DeathVoice(self, rag) end
        if self.ZASpecial == "suicide" then ZA1.CorpseCharges.Register(self,rag) end
        ZA1.Manager.Ragdoll(rag)
    end
    function ENT:ZACombat(enemy) return S.Combat(self, enemy) end
end
