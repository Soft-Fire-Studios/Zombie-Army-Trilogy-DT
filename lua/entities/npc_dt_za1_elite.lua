AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_special"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.Category = "Zombie Army Trilogy"
if SERVER then
    function ENT:OnInitialize() ZA1.Specials.Initialize(self); ZA1.Elites.Initialize(self) end
    function ENT:OnThink() ZA1.Specials.Tick(self); ZA1.Elites.Tick(self) end
    function ENT:OnEntityDetected(ent)
        baseclass.Get("npc_dt_za1_special").OnEntityDetected(self, ent)
        if self.ZASpecial == "fire" and IsValid(ent) and ent:IsPlayer() and self:IsHatedEntity(ent)
            and CurTime() >= (self.ZAVocalUntil or 0) then
            ZA1.Specials.Sound(self, "alert", 80, true)
        end
    end
    function ENT:OnRemove()
        ZA1.Elites.Stop(self); ZA1.Specials.StopVoice(self)
        ZA1.Recovery.Clear(self); ZA1.Manager.Unregister(self)
    end
    function ENT:ZACombat(enemy) return ZA1.Elites.Combat(self, enemy) end
    function ENT:ZADecide()
        if self.ZAPainPending and ZA1.Elites.Flinch(self) then return end
        if self.ZASpecial == "fire" and not self:HasEnemy() and ZA1.Elites.FireIdle(self) then return end
        if self.ZASpecial == "summoner" then
            local enemy = self:GetEnemy()
            if IsValid(enemy) and ZA1.Elites.Combat(self, enemy) then return end
            ZA1.Navigation.Cancel(self); ZA1.Crowd.Release(self)
            self:SetAIState(DT_Base.AI_STATE_REST)
            self.IdleAnimation = self.ZASupportIdle
            local task = self.ZAInvestigation
            if task and CurTime() <= task.expires and not self:ZATurnTowards(task.position) then self:FaceTowards(task.position) end
            return
        end
        return baseclass.Get("npc_dt_za1_zombie").ZADecide(self)
    end
    function ENT:ZAMelee(target) return ZA1.Elites.Attack(self, target) end
    function ENT:ZAPlayAttack(sequence, target) return ZA1.Elites.Melee(self, sequence, target) end
    function ENT:ZALunge(target) return ZA1.Elites.Secondary(self, target) end
    function ENT:DoWounded(info, tr) return ZA1.Elites.Flinch(self, info, tr) end
    function ENT:OnWounded(info, tr)
        tr = self.ZADownedHitTrace or tr
        if ZA1.Elites.Damage(self, info, tr) then return end
        ZA1.Specials.Wounded(self, info, tr)
        ZA1.Elites.PainHit(self, info)
        ZA1.Elites.RecoveryHit(self, info, tr)
    end
    function ENT:HandleAnimEvent(event, time, cycle, typ, options)
        if ZA1.Elites.Event(self, event, time, cycle, typ, options) then return true end
        return ZA1.Specials.Event(self, event, time, cycle, typ, options)
    end
    function ENT:OnIncapacitated(info)
        ZA1.FireVFX.Death(self)
        ZA1.Elites.Stop(self); self.ZADeathVoicePending = true
        return ZA1.Specials.Died(self, info)
    end
    function ENT:DoIncapacitated(info, tr)
        if self.ZASpecial == "fire" then return ZA1.Elites.Die(self, info) end
        return baseclass.Get("base_dt_nextbot").DoIncapacitated(self, info, tr)
    end
    function ENT:RagdollOrRemove(info, tr)
        -- DT also reaches cleanup when a death clip is absent or interrupted.
        -- The burst's one-shot guard keeps the normal completion path single.
        if self.ZASpecial == "fire" then ZA1.Elites.DeathBurst(self) end
        if self.ZAFireDeathExploded then self:Remove(); return end
        return baseclass.Get("npc_dt_za1_special").RagdollOrRemove(self, info, tr)
    end
    function ENT:OnRagdoll(rag)
        for group = 0, self:GetNumBodyGroups() - 1 do rag:SetBodygroup(group, self:GetBodygroup(group)) end
        rag.ZAHeadLayout = self.ZAHeadLayout
        ZA1.Gore.Ragdoll(self, rag); ZA1.Specials.DeathVoice(self, rag); ZA1.Manager.Ragdoll(rag)
    end
else
    function ENT:OnThink() ZA1.Presentation.Update(self); ZA1.Elites.Presentation(self) end
end
