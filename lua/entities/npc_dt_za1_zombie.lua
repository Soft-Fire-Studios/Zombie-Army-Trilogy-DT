AddCSLuaFile()
AddCSLuaFile("za1/zombie_settings.lua")
if not DT_Base then return end
local C = ZA1.Config or include("za1/zombie_settings.lua")
ENT.Base = "base_dt_nextbot"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.ZA1Zombie = true
ENT.PrintName = "Soldier Zombie"
ENT.Category = "Zombie Army Trilogy"
ENT.Spawnable = false -- DT's registered NPC icons remain; omit the Entities tab.
ENT.Models = {"models/zombiearmytrilogy/zombie_soldier.mdl"}
ENT.MaxHealth = C.Combat.Health
ENT.HealthRegen = 0
ENT.Height = 74
ENT.Width = 14
ENT.BloodColor = BLOOD_COLOR_RED
ENT.Tags = {"zombie", "za1"}
ENT.EnableSight = true
ENT.SightRange = 1800
ENT.SightAngle = 140
ENT.EnableJumping = false
ENT.EnableCrouching = false
ENT.EnablePossession = true
ENT.PossessionViewDistance = 110
ENT.IdleAnimation = C.Animations.Idle[1]
ENT.WalkAnimation = C.Animations.Walk[1]
ENT.RunAnimation = ENT.WalkAnimation
ENT.FallAnimation = ENT.IdleAnimation
ENT.LandAnimation = ACT_INVALID
ENT.MeleeAnimations = C.Animations.Melee
ENT.FlinchAnimations = C.Animations.Flinch
ENT.VocalVolume = C.Audio.VocalVolume
ENT.BreathVolume = C.Audio.BreathVolume
function ENT:SetupDataTables() ZA1.Presentation.Setup(self) end
if CLIENT then
    function ENT:OnThink() ZA1.Presentation.Update(self) end
end
if SERVER then
    local M = ZA1.Manager
    local N, G = ZA1.Navigation, ZA1.Crowd
    local blind, ignorePlayers = GetConVar("nb_blind"), GetConVar("ai_ignoreplayers")
    local meleeDot = math.cos(math.rad(C.Melee.FacingAngle))
    local function Pick(choices) return choices[math.random(#choices)] end
    local durations = {}
    local function Duration(file, pitch)
        if not durations[file] then
            durations[file] = ZA1.Assets.soundDurations and ZA1.Assets.soundDurations[file] or SoundDuration(file)
        end
        return durations[file] * 100 / pitch
    end
    local function Vocal(z, file, level, pitch, volume, passive)
        if passive and CurTime() < (z.ZAVocalUntil or 0) then return end
        z:EmitSound(file, level, pitch, volume, CHAN_VOICE)
        z.ZAVocalUntil = CurTime() + Duration(file, pitch) + 0.02
    end
    local function Sound(z, role, level)
        local choices = ZA1.Assets.sounds[role]
        if not choices or #choices == 0 then return end
        local file, pitch = choices[math.random(#choices)], math.random(95, 105)
        if role == "hit" then z:EmitSound(file, level or 75, pitch, 0.85)
        else Vocal(z, file, level or 75, pitch, z.VocalVolume, role ~= "death") end
    end
    function ENT:Initialize(...)
        -- Reject before DT initializes target tables or calls post-init hooks.
        if M.Count() >= C.Director.MaxCommon then self:Remove(); return end
        return baseclass.Get("base_dt_nextbot").Initialize(self, ...)
    end
    function ENT:AddSharedTagsRelationship(disposition)
        -- DT's KeysIter allocates iterator objects, closures and tuples for
        -- each comparison. Traverse the same live tag table directly, using
        -- DT's mutation-safe Next so runtime tag changes keep their behavior.
        return self:AddRelationship(function(ent)
            local tags = self.__DT_Tags
            if not tags then return end
            for tag in DT_Base.Next, tags do
                if ent:DT_HasTag(tag) then return disposition end
            end
        end)
    end
    function ENT:OnInitialize()
        ZA1.Presentation.Initialize(self)
        ZA1.Impact.Initialize(self)
        M.InstallSight()
        self:AddSharedTagsRelationship(D_LI)
        self:SetDefaultRelationship(D_HT)
        self:SetBodygroup(0,0)
        self:SetBodygroup(1,math.random(0,8))
        self:SetBodygroup(4,math.random(0,8))
        self:SetBodygroup(C.Equipment.WeaponBodygroup,self.ZAWeapon or math.random(#C.Equipment.Weapons))
        ZA1.Equipment.Refresh(self)
        self.ZANextEquipmentCheck=CurTime()+self:EntIndex()%16/16
        self.IdleAnimation = Pick(C.Animations.Idle)
        self.WalkAnimation = Pick(C.Animations.Walk)
        self.RunAnimation = self.WalkAnimation
        self.FallAnimation = self.IdleAnimation
        ZA1.Dismemberment.Update(self)
        self.loco:SetAcceleration(C.Navigation.Acceleration)
        self.loco:SetDeceleration(C.Navigation.Deceleration)
        self.loco:SetMaxYawRate(C.Navigation.YawRate)
        self.loco:SetStepHeight(C.Navigation.StepHeight)
        self.ZANavProfile = N.Profile(self)
        ZA1.Look.Reset(self)
        self.ZAFootBones = {left = self:LookupBone("Bip01 L Foot"), right = self:LookupBone("Bip01 R Foot")}
        self:GetFollowPath():SetMinLookAheadDistance(C.Navigation.LookAhead)
        self:GetFollowPath():SetGoalTolerance(C.Navigation.GoalTolerance)
        M.Register(self)
    end
    function ENT:OnRemove() ZA1.Ranged.Stop(self);ZA1.Recovery.Clear(self);M.Unregister(self) end
    function ENT:OnThink()
        if not self:Alive() then return end
        ZA1.Recovery.Tick(self)
        ZA1.Look.Update(self)
        ZA1.Equipment.Update(self)
        ZA1.Dismemberment.Update(self)
    end
    function ENT:OnEntityDetected(ent)
        if self:IsHatedEntity(ent) then
            M.Wake(self)
            Sound(self, "alert", 80)
            M.Alert(self, ent:GetPos())
        end
    end
    function ENT:ShouldRun() return false end
    function ENT:UpdateAnimation()
        baseclass.Get("base_dt_nextbot").UpdateAnimation(self)
        ZA1.Motion.UpdateWalk(self)
        ZA1.Presentation.Animation(self)
    end
    function ENT:ZAUpdateSight(ent, useFOV)
        -- IsAbleToSee belongs to the NextBot metatable and takes precedence
        -- over ENT overrides. DT's sight hook calls this distinct method.
        -- Reject range/FOV/friends before sharing combat's budgeted LOS cache.
        local data = self.__DT_TargetsData and self.__DT_TargetsData[ent]
        if not data then return false end
        local visible = false
        if IsValid(ent) and self.EnableSight and not blind:GetBool() and not self:IsAIDisabled()
            and self:IsHatedEntity(ent) and (not ent:IsPlayer() or ent:Alive() and not ignorePlayers:GetBool()) then
            local eligible = useFOV == false
            if not eligible then
                local eyePos, eyeAngle = self:EyePosAndAngles()
                eligible = self:IsInFront(ent, self:GetMaxVisionRange(), self:GetFOV(), eyePos, eyeAngle:Forward())
            end
            visible = eligible and M.Visible(self, ent)
        end
        if visible then
            if not data.SightStartTime then data.SightStartTime = CurTime(); hook.Run("DT/SightGained", self, ent, 0) end
            hook.Run("DT/SightKept", self, ent, CurTime() - data.SightStartTime)
            data.LastTimeSeen = CurTime()
        elseif data.SightStartTime then
            hook.Run("DT/SightLost", self, ent, CurTime() - data.SightStartTime)
            data.SightStartTime = nil
        end
        return visible
    end
    function ENT:ZAPlayOnce(sequence, callback)
        -- DT sweeps the collision hull while applying the authored walkframes.
        self.ZAActing = true
        N.Cancel(self)
        local id = self:PlaySequence(sequence, {move = true})
        -- DT consumes movement after resuming this coroutine. Start at zero,
        -- and keep the action state until its last delta has been consumed.
        self.__DT_PlaySeq_PreviousSeq, self.__DT_PlaySeq_PreviousCycle = id, 0
        local finish = CurTime() + self:SequenceDuration(id) + 1
        local flags = DT_Base.ToYieldFlags({doWounded = false, doIncapacitated = true})
        if self.ZAAttackClaim then self.ZAAttackClaim.expires = finish + C.Crowd.SlotLifetime end
        self.loco:SetVelocity(Vector(0, 0, self:GetVelocity().z))
        while self:GetSequence() == id and self:GetCycle() < 1 and CurTime() < finish and self:Alive() do
            if self.ZADowned and not self.ZADowned.gettingUp then break end
            -- Navigation inertia must not add travel to the animation's root.
            self.loco:SetVelocity(Vector(0, 0, self:GetVelocity().z))
            if callback and callback() == false then break end
            if coroutine.yield(flags) then break end
        end
        if self:Alive() and (not self.ZADowned or self.ZADowned.gettingUp) and self:GetSequence() == id and self.__DT_PlaySeq_PreviousCycle < self:GetCycle() then
            self.loco:SetVelocity(Vector(0, 0, self:GetVelocity().z))
            coroutine.yield(flags)
        end
        if self:Alive() then self.loco:SetVelocity(Vector(0, 0, self:GetVelocity().z)) end
        self.ZAActing = false
        N.PauseProgress(self)
        M.Wake(self)
        if self:Alive() and (not self.ZADowned or self.ZADowned.gettingUp) and self:GetSequence() == id then self:ResetAnimState() end
    end
    function ENT:ZACanMelee(target, range, ignoreFacing)
        if not IsValid(target) or target.ZA1Zombie or not self:IsHatedEntity(target) then return false end
        local center = self:WorldSpaceCenter()
        local delta = target:WorldSpaceCenter() - center
        if math.abs(target:NearestPoint(center).z - center.z) > C.Melee.HullHeight then return false end
        delta.z = 0
        range = range or C.Melee.Range
        if delta:LengthSqr() > range * range then return false end
        return ignoreFacing or delta:LengthSqr() == 0 or self:GetForward():Dot(delta:GetNormalized()) >= meleeDot
    end
    function ENT:ZAMelee(target)
        if CurTime() < (self.ZANextMelee or 0) then return end
        if target and not self:ZACanMelee(target, C.Melee.StartRange) then return end
        self:ZAPlayAttack(Pick(self.MeleeAnimations), target)
    end
    function ENT:ZAPlayAttack(sequence, target)
        self.ZALastMeleeEvent = nil
        self.ZAAttacking = true
        self:ZAPlayOnce(sequence, function()
            if self:IsAIDisabled() then return false end
            if target then
                return IsValid(target) and not self:IsPossessed()
                    and (not target.Alive or target:Alive())
            end
        end)
        self.ZAAttacking = false
        self.ZANextMelee = CurTime() + C.Melee.Cooldown
    end
    function ENT:ZALunge(target)
        local now = CurTime()
        if now < (self.ZANextMelee or 0) or now < (self.ZANextLunge or 0) then return false end
        if target and now < (self.ZANextLungeCheck or 0) then return false end
        local clips = ZA1.Motion.Lunges(self)
        local scale = self:GetModelScale()
        if target then
            if not self:ZACanMelee(target, clips.reach * scale + C.Melee.StartRange)
                or self:ZACanMelee(target, C.Melee.Range) then return false end
            self.ZANextLungeCheck = now + C.Lunge.RetryDelay
            if math.Rand(0, 1) >= C.Lunge.Chance then return false end
        end
        local forward = self:GetForward()
        local delta = target and target:WorldSpaceCenter() - self:WorldSpaceCenter()
        local x = delta and forward:Dot(delta)
        local y = delta and (-forward.y * delta.x + forward.x * delta.y)
        local selected, count = nil, 0
        for _, clip in ipairs(clips) do
            local reachable = not target
            for _, hit in ipairs(clip.hits) do
                if target then
                    local dx, dy = x - hit.x * scale, y - hit.y * scale
                    local square = dx * dx + dy * dy
                    if square <= C.Melee.StartRange ^ 2 and (square == 0 or dx / math.sqrt(square) >= meleeDot) then reachable = true; break end
                end
            end
            if reachable then count = count + 1; if math.random(count) == 1 then selected = clip end end
        end
        if not selected then return false end
        local travel = selected.travel * scale
        local start = self:GetPos() + Vector(0, 0, 1)
        local finish = start + Vector(forward.x * travel.x - forward.y * travel.y, forward.y * travel.x + forward.x * travel.y, travel.z)
        local filter = target and {self, target} or self
        local path = util.TraceHull({start = start, endpos = finish, mins = Vector(-self.Width, -self.Width, 0),
            maxs = Vector(self.Width, self.Width, self.Height), mask = MASK_NPCSOLID, filter = filter, collisiongroup = COLLISION_GROUP_NPC})
        if path.Hit or path.StartSolid then return false end
        local step = self.loco:GetStepHeight()
        local floor = util.TraceLine({start = finish + Vector(0, 0, step), endpos = finish - Vector(0, 0, step * 2), mask = MASK_NPCSOLID_BRUSHONLY})
        if not floor.Hit or floor.StartSolid or floor.HitNormal.z < 0.6 then return false end
        self.ZALunging = true
        self:ZAPlayAttack(selected.sequence, target)
        self.ZALunging = false
        self.ZANextLunge = CurTime() + C.Lunge.Cooldown
        return true
    end
    function ENT:HandleAnimEvent(event, time, cycle, typ, options)
        if not self:Alive() then return end
        if ZA1.Ranged.Event(self,event,options) then return true end
        if self.ZADowned and not self.ZADowned.gettingUp then return true end
        if event == 1101 then
            if not M.EventAudible(self) then return true end
            local id = self:GetSequence()
            if self.ZASoundSequence ~= id then
                self.ZASoundSequence = id
                local name=self:GetSequenceName(id)
                local traversal=ZA1.TraversalAssets and ZA1.TraversalAssets.Sounds[self.ZASpecial or "common"]
                self.ZASoundBindings = traversal and traversal[name] or ZA1.Assets.animationSounds[name]
            end
            local bindings = self.ZASoundBindings
            local binding = bindings and bindings[options]
            if binding and #binding.files > 0 then
                local policy = C.Audio.VocalEvents[binding.name]
                if policy then
                    local now = CurTime()
                    if now < (self.ZANextEventVocal or 0) or now < (self.ZAVocalUntil or 0) then return true end
                    if math.Rand(0, 1) >= policy.Chance then return true end
                    self.ZANextEventVocal = now + math.Rand(policy.MinDelay, policy.MaxDelay)
                end
                local file = binding.files[math.random(#binding.files)]
                local gain = binding.volume and math.Rand(binding.volume[1], binding.volume[2]) or 1
                if binding.name:find("Breathe", 1, true) then
                    -- In/out tails overlap in the authored clips. Separate
                    -- channels preserve both; repeated starts wait for EOF.
                    local exhale = binding.name:find("Breathe_Out", 1, true) ~= nil
                    local finish = exhale and "ZABreathOutUntil" or "ZABreathInUntil"
                    if CurTime() < (self[finish] or 0) then return true end
                    self:EmitSound(file, 60, 100, gain * self.BreathVolume, exhale and CHAN_ITEM or CHAN_BODY)
                    self[finish] = CurTime() + Duration(file, 100)
                    self[exhale and "ZABreathOutSound" or "ZABreathInSound"] = file
                elseif binding.name:find("Vox", 1, true) then
                    local passive = binding.name:find("Random_Low", 1, true) or binding.name:find("Turn", 1, true)
                    Vocal(self, file, 70, 100, gain * self.VocalVolume, passive)
                else
                    self:EmitSound(file, 65, 100, gain, CHAN_AUTO)
                end
            end
            return true
        end
        local label = util.GetAnimEventNameByID(event)
        if label == "AE_NPC_LEFTFOOT" or label == "AE_NPC_RIGHTFOOT" then
            if not M.EventAudible(self) then return true end
            self.ZAFootBones = self.ZAFootBones or {left = self:LookupBone("Bip01 L Foot"), right = self:LookupBone("Bip01 R Foot")}
            local bone = self.ZAFootBones[label == "AE_NPC_LEFTFOOT" and "left" or "right"]
            local pos = bone and self:GetBonePosition(bone) or self:GetPos()
            local tr = util.TraceLine({start = pos + Vector(0, 0, 12), endpos = pos - Vector(0, 0, 40), filter = self, mask = MASK_PLAYERSOLID})
            if tr.Hit then
                local surface = util.GetSurfaceData(tr.SurfaceProps)
                local snd = surface and (label == "AE_NPC_LEFTFOOT" and surface.stepLeftSound or surface.stepRightSound)
                if snd and snd ~= "" then self:EmitSound(snd, 65, 100, 0.65) end
            end
            return true
        end
        if event ~= 1100 or options ~= "za1_melee" or not self.ZAAttacking
            or self.ZALastMeleeEvent and cycle <= self.ZALastMeleeEvent then return end
        self.ZALastMeleeEvent = cycle -- Each authored combo marker may strike once.
        local tr = util.TraceHull({start = self:WorldSpaceCenter(), endpos = self:WorldSpaceCenter() + self:GetForward() * C.Melee.Range,
            mins = Vector(-C.Melee.HullWidth, -C.Melee.HullWidth, -C.Melee.HullHeight),
            maxs = Vector(C.Melee.HullWidth, C.Melee.HullWidth, C.Melee.HullHeight), mask = MASK_SHOT_HULL, filter = self})
        local victim = tr.Entity
        if ZA1.Doors and ZA1.Doors.Hit(self, victim, tr.HitPos) then return true end
        -- Other packs may expose an owning actor through a collision helper.
        if IsValid(victim) and victim.GetActor then
            local actor = victim:GetActor()
            if IsValid(actor) then victim = actor end
        end
        -- The sweep includes the victim's hull. Enforce the same actual
        -- reach/cone as attack selection, at the hit event rather than windup.
        if self:ZACanMelee(victim) then
            local info = DamageInfo()
            info:SetAttacker(self); info:SetInflictor(self)
            info:SetDamage(self:GetBodygroup(C.Equipment.WeaponBodygroup)==0 and C.Melee.UnarmedDamage or C.Melee.Damage)
            info:SetDamageType(DMG_SLASH)
            info:SetDamagePosition(tr.HitPos); info:SetDamageForce(self:GetForward() * 3000)
            victim:TakeDamageInfo(info)
            Sound(self, "hit", 75)
        end
    end
    function ENT:OnTraceAttack(info,dir,tr)
        ZA1.Equipment.CaptureTrace(self,tr)
        return baseclass.Get("base_dt_nextbot").OnTraceAttack(self,info,dir,tr)
    end
    function ENT:OnWounded(info, tr)
        if info:GetDamage() <= 0 then return end
        tr = self.ZADownedHitTrace or tr
        self.ZALastDamage = CurTime()
        M.Wake(self)
        local attacker = info:GetAttacker()
        if IsValid(attacker) and self:IsHatedEntity(attacker) then
            self:DetectEntity(attacker)
            M.Investigate(self, attacker:GetPos(), C.Navigation.MemoryDuration)
            M.Alert(self, attacker:GetPos())
        end
        if ZA1.Equipment.Hit(self,info,tr) then return end
        local limbDamage = info:GetDamage()
        ZA1.Combat.Apply(self,info,tr)
        if info:GetDamage() <= 0 then return end
        local group = tr and tr.HitGroup or HITGROUP_GENERIC
        if group == HITGROUP_HEAD then
            ZA1.Gore.HeadHit(self,info,info:GetDamage()>=self:Health())
        end
        ZA1.Dismemberment.Damage(self,info,tr,limbDamage)
        ZA1.Recovery.Damage(self,info)
    end
    function ENT:DoWounded(info, tr)
        if not self:Alive() or self.ZADowned or info:GetDamage() >= self:Health() or self:IsPossessed() or self.ZAActing
            or self:IsAIDisabled() or info:GetDamage() < C.Flinch.MinDamage or CurTime() < (self.ZANextFlinch or 0) then return end
        self.ZANextFlinch = CurTime() + 10
        self:ZAPlayOnce(self.FlinchAnimations[tr and tr.HitGroup or HITGROUP_GENERIC] or self.FlinchAnimations[HITGROUP_CHEST])
        self.ZANextFlinch = CurTime() + C.Flinch.Cooldown
    end
    function ENT:OnIncapacitated(info)
        ZA1.Ranged.Stop(self)
        if self.ZABreathInSound then self:StopSound(self.ZABreathInSound) end
        if self.ZABreathOutSound then self:StopSound(self.ZABreathOutSound) end
        if not self.ZAHeadDestroyed then Sound(self, "death", 75) end
        ZA1.Equipment.Drop(self,"weapon",info)
        ZA1.Recovery.Clear(self,true)
        M.Killed(self)
    end
    function ENT:RagdollOrRemove(info,tr)
        if IsValid(self.ZAExistingCorpse) then self:Remove();return end
        if ZA1.Halves and ZA1.Halves.Corpse(self,info) then return end
        return baseclass.Get("base_dt_nextbot").RagdollOrRemove(self,info,tr)
    end
    function ENT:OnRagdoll(rag)
        for group = 0, self:GetNumBodyGroups()-1 do rag:SetBodygroup(group, self:GetBodygroup(group)) end
        ZA1.Equipment.Refresh(rag)
        ZA1.Gore.Ragdoll(self,rag)
        ZA1.Recovery.Remember(self,rag)
        M.Ragdoll(rag)
    end
    function ENT:ZAEnemyGoal(enemy)
        -- New contacts use DT's FOV. Keep an acquired enemy's position fresh
        -- while it is in line of sight; hidden enemies use remembered positions.
        if self.ZASightEnemy ~= enemy or CurTime() >= (self.ZANextSight or 0) then
            self.ZASightEnemy = enemy
            local _, interval = M.Intervals(self)
            self.ZANextSight = CurTime() + interval
            self.ZAEnemyVisible = self.EnableSight and not blind:GetBool()
                and self:GetPos():DistToSqr(enemy:GetPos()) <= self.SightRange * self.SightRange
                and M.Visible(self, enemy)
            if self.ZAEnemyVisible then self:DetectEntity(enemy) end
        end
        return self.ZAEnemyVisible and enemy:GetPos() or self:LastKnownPos(enemy), self.ZAEnemyVisible
    end
    function ENT:ZATurnTowards(pos, enemy)
        local delta = pos - self:GetPos(); delta.z = 0
        if delta:LengthSqr() == 0 then return false end
        local bearing = delta:Angle().y
        local yaw = math.AngleDifference(bearing, self:GetAngles().y)
        if math.abs(yaw) <= C.Turning.StartAngle or CurTime() < (self.ZANextTurn or 0) then return false end
        local animations = self.ZATurnAnimations or C.Animations.Turn
        local turns = yaw > 0 and animations.Left or animations.Right
        local choices, difference
        for degrees, pool in pairs(turns) do
            local error = math.abs(math.abs(yaw) - degrees)
            if not difference or error < difference then choices, difference = pool, error end
        end
        local near = self:GetPos():DistToSqr(pos) <= C.Melee.Range * C.Melee.Range
        local investigation = self.ZAInvestigation
        self.ZATurning = true
        self:ZAPlayOnce(Pick(choices), function()
            if self:IsAIDisabled() or self:IsPossessed() then return false end
            local goal = pos
            if enemy then
                if not IsValid(enemy) or self:GetEnemy() ~= enemy then return false end
                goal = self:ZAEnemyGoal(enemy)
                if not goal then return false end
                if near and self:GetPos():DistToSqr(goal) > (C.Melee.Range * 2) ^ 2 then return false end
            else
                if self:HasEnemy() then return false end
                if self.ZAInvestigation ~= investigation and self.ZAInvestigation then
                    goal = self.ZAInvestigation.position
                end
            end
            -- Apply only the sequence's authored yaw. Cancel stale turns;
            -- calling FaceTowards here would rotate on top of the animation.
            local direction = goal - self:GetPos()
            if direction:Length2D() > 0 then
                return math.abs(math.AngleDifference(direction:Angle().y, bearing)) < C.Turning.RetargetAngle
            end
        end)
        self.ZATurning = false
        self.ZANextTurn = CurTime() + C.Turning.Cooldown
        return true
    end
    function ENT:ZAMove(pos, enemy)
        local flags = self:GetAnimState():SelectAnimFlags(self) or 0
        local gait = bit.band(flags, DT_Base.ANIM_STATE_DYNAMIC_RATE) ~= 0
        -- A running actor can momentarily brake during a sharp retarget.
        -- Keep locomotion steering rather than starting a stationary turn.
        if not gait and self:GetVelocity():Length2D() <= C.Turning.StationarySpeed and self:ZATurnTowards(pos, enemy) then return end
        N.Move(self, pos, enemy and 2 or self.ZAInvestigation and 1 or 0)
    end
    function ENT:ZACombat(enemy)
        local goal, visible = self:ZAEnemyGoal(enemy)
        if CurTime() - (self:LastTimeDetected(enemy) or 0) > C.Navigation.MemoryDuration then
            self:LoseEntity(enemy)
            return false
        end
        self:SetAIState(DT_Base.AI_STATE_COMBAT)
        if not goal then return true end
        if ZA1.Ranged.Try(self,enemy,visible) then return true end
        local moveGoal, mayAttack = goal, true
        if visible then moveGoal, mayAttack = G.AttackGoal(self, enemy) else G.ReleaseClaim(self) end
        -- A reserved slot already limits the number of attackers. An actor
        -- in contact need not retreat while that slot's ground probe waits.
        local claim = self.ZAAttackClaim
        local contact = visible and self:ZACanMelee(enemy, C.Melee.StartRange, true)
        if contact and (mayAttack or claim and claim.target == enemy) then
            -- Range starts the handoff; facing still gates the swing. Keeping
            -- a pursuit/avoidance command while turning made actors orbit or
            -- overshoot the player, especially while an attack cooled down.
            N.Face(self, goal)
            if not self:ZACanMelee(enemy, C.Melee.StartRange) and self:ZATurnTowards(goal, enemy) then
                if not self:Alive() or self:IsAIDisabled() or self:IsPossessed() or self:GetEnemy() ~= enemy then return true end
                goal, visible = self:ZAEnemyGoal(enemy)
                if not goal or not visible or not self:ZACanMelee(enemy, C.Melee.StartRange, true) then return true end
                N.Face(self, goal)
            end
            self:FaceTowards(goal)
            self:ZAMelee(enemy)
        elseif visible and mayAttack and self:ZALunge(enemy) then
            -- The reserved crowd slot limits who can commit to an attack.
        elseif visible and mayAttack then
            -- Reaching a slot is not the same as reaching melee range. Keep
            -- approaching until the target is in reach.
            self.ZACloseGoal = goal
            self:ZAMove(moveGoal, enemy)
        elseif self:GetPos():DistToSqr(moveGoal) > C.Navigation.ArrivalDistance ^ 2 then
            self:ZAMove(moveGoal, enemy)
        else
            self.ZAFaceGoal = goal
            if not self:ZATurnTowards(goal, enemy) then self:FaceTowards(goal) end
        end
        return true
    end
    function ENT:ZAWander()
        if not M.Wander:GetBool() or not navmesh.IsLoaded() then return end
        if self.ZAWanderGoal and CurTime() < self.ZAWanderUntil then
            if self:GetPos():DistToSqr(self.ZAWanderGoal) > C.Navigation.ArrivalDistance ^ 2 then self:ZAMove(self.ZAWanderGoal)
            else self.ZAWanderGoal = nil end
        elseif CurTime() >= (self.ZANextWander or 0) then
            local w = C.Wander
            self.ZANextWander = CurTime() + math.Rand(w.MinDelay, w.MaxDelay)
            local areas = navmesh.Find(self:GetPos(), w.Radius, self.loco:GetStepHeight(), self.loco:GetDeathDropHeight())
            for i = 1, math.min(w.Tries, #areas) do
                local area = areas[math.random(#areas)]
                if not area:IsBlocked() and not area:IsUnderwater() then
                    self.ZAWanderGoal = area:GetRandomPoint()
                    self.ZAWanderUntil = CurTime() + w.Duration
                    break
                end
            end
        end
    end
    function ENT:DoThink()
        if not self:Alive() then return end
        if self.__DT_PhysgunPickup then return end
        if self.ZADowned then
            if self.ZADowned.ready then ZA1.Recovery.GetUp(self) end
            return
        end
        local controls = self:GetPossessionControls()
        if IsValid(controls) then
            if not self.ZAWasPossessed then N.Cancel(self); G.Release(self); self.ZAWasPossessed = true end
            self:SetAIState(DT_Base.AI_STATE_POSSESSION)
            controls:ApproachMoveDirection(); controls:FaceMoveDirection()
            if controls:KeyDown(IN_ATTACK) then
                if ZA1.Ranged.HasWeapon(self) then ZA1.Ranged.Attack(self)
                else self:ZAMelee() end
            elseif controls:KeyDown(IN_ATTACK2) then self:ZALunge() end
            return
        end
        if self.ZAWasPossessed then self.ZAWasPossessed = nil; M.Wake(self) end
        if self:IsAIDisabled() then N.Cancel(self); G.Release(self); self:SetAIState(DT_Base.AI_STATE_DISABLED); return end
        if self.ZAEmerge then
            local sequence = self.ZAEmerge
            self.ZAEmerge = nil
            ZA1.ResurrectionFX.Emerge(self, sequence)
            self:ZAPlayOnce(sequence)
            return
        end
        if ZA1.Obstacles and ZA1.Obstacles.TryMantle(self) then return end
        if ZA1.Doors and ZA1.Doors.Try(self) then N.Follow(self); return end
        local enemy = self:GetEnemy()
        if self.ZADecisionEnemy ~= enemy then self.ZADecisionEnemy = enemy; M.Wake(self) end
        if CurTime() < (self.ZANextDecision or 0) then N.Follow(self); return end
        local interval = M.Intervals(self)
        self.ZANextDecision = CurTime() + interval
        M.Stats.decisions = M.Stats.decisions + 1
        -- Decision work is staggered; following an existing native path is not.
        self.ZAMoveGoal = nil
        self.ZACloseGoal, self.ZAFaceGoal = nil, nil
        self:ZADecide()
        N.Follow(self)
    end
    function ENT:ZADecide()
        local enemy = self:GetEnemy()
        if IsValid(enemy) and self:ZACombat(enemy) then return end
        G.ReleaseClaim(self)
        self:SetAIState(DT_Base.AI_STATE_REST)
        local task = self.ZAInvestigation
        if task and CurTime() <= task.expires then
            if self:GetPos():DistToSqr(task.position) > C.Navigation.ArrivalDistance ^ 2 then self:ZAMove(task.position)
            elseif not self:ZATurnTowards(task.position) then self:FaceTowards(task.position) end
            return
        end
        self.ZAInvestigation = nil
        self:ZAWander()
    end
    function ENT:OnError(err)
        ZA1.Ranged.Stop(self)
        if ZA1.Obstacles then ZA1.Obstacles.Clear(self) end
        ErrorNoHaltWithStack(err);return true
    end
end
DT_Base.AddNextBot(ENT)
