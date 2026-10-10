-- Special enemies reuse the horde's staggered senses, routes and movement.
-- Bone tests happen on a bullet hit or death, never in a per-tick collision loop.
local S = {}; ZA1.Specials = S
local M, N, G = ZA1.Manager, ZA1.Navigation, ZA1.Crowd
local A, C = ZA1.SpecialAssets, ZA1.SpecialConfig
local V = ZA1.SkeletonAssets or include("za1/skeleton_assets.lua")
local Armor = ZA1.SkeletonArmor or include("za1/skeleton_armor.lua")
local Heavy = ZA1.HeavyAssets or include("za1/heavy_assets.lua")
local HeavyArmor = ZA1.HeavyArmor or include("za1/heavy_armor.lua")
A.Enemies.heavy = Heavy
for file, duration in pairs(Heavy.Durations) do A.Durations[file] = duration end
local skeletonClasses = {}
for _, variant in ipairs(C.skeleton.Variants) do skeletonClasses[variant.Class] = true end
local function Pick(pool) return pool[math.random(#pool)] end
-- Reuse the common soldier's complete severed limbs, at their attaching joints.
local sever = include("za1/dismemberment_assets.lua").Parts
S.SuicideGibs = {sever[HITGROUP_LEFTARM], sever[HITGROUP_RIGHTARM], sever[HITGROUP_LEFTLEG], sever[HITGROUP_RIGHTLEG]}
for _, piece in ipairs(A.Enemies.suicide.Breakup) do
    if piece.ID ~= 36 and piece.ID ~= 37 then S.SuicideGibs[#S.SuicideGibs + 1] = piece end
end

function S.Emerge(class)
    return skeletonClasses[class] and C.skeleton.Emerge
        or class == "npc_dt_za1_suicide_grunt" and C.suicide.Emerge
        or class == "npc_dt_za1_armored_heavy" and C.heavy.Emerge
        or ZA1.Config.Animations.Emerge[math.random(#ZA1.Config.Animations.Emerge)]
end

function S.SelectClass(director)
    if not M.SpecialsEnabled:GetBool() or math.random(100) > M.SpecialChance:GetInt() then return "npc_dt_za1_zombie" end
    local counts = {skeleton = M.SpecialCounts.skeleton, suicide = M.SpecialCounts.suicide, heavy = M.SpecialCounts.heavy or 0}
    for _, record in ipairs(director.ZADormant) do
        if skeletonClasses[record.class] then counts.skeleton = counts.skeleton + 1
        elseif record.class == "npc_dt_za1_suicide_grunt" then counts.suicide = counts.suicide + 1
        elseif record.class == "npc_dt_za1_armored_heavy" then counts.heavy = counts.heavy + 1 end
    end
    local skeleton, suicide = counts.skeleton < M.SkeletonLimit:GetInt(), counts.suicide < M.SuicideLimit:GetInt()
    local heavy = counts.heavy < M.HeavyLimit:GetInt()
    if heavy and (not skeleton and not suicide or math.random(4) == 1) then return "npc_dt_za1_armored_heavy" end
    if skeleton and (not suicide or math.random(3) <= 2) then
        local total = 0
        for _, variant in ipairs(C.skeleton.Variants) do total = total + variant.Weight end
        local choice = math.random(total)
        for _, variant in ipairs(C.skeleton.Variants) do
            choice = choice - variant.Weight
            if choice <= 0 then return variant.Class end
        end
    end
    if suicide then return "npc_dt_za1_suicide_grunt" end
    return "npc_dt_za1_zombie"
end

local function SkeletonAppearance(z)
    local groups = V.Bodygroups
    z:SetBodygroup(groups.body, z.ZASkeletonVariant == "rotten" and 1 or 0)
    Armor.Initialize(z, z.ZASkeletonVariant == "armored" and Pick(V.Presets) or nil)
end

function S.EquipmentPieces(z)
    local armor = S.Armor(z)
    return armor and armor.EquipmentPieces(z) or {}
end

function S.Armor(z)
    return z.ZASpecial == "skeleton" and Armor or z.ZASpecial == "heavy" and HeavyArmor or nil
end

function S.Sound(z, role, level, voice)
    local binding = z.ZASpecialAssets.Roles[role]
    if not binding or #binding.Files == 0 then return end
    local file = Pick(binding.Files)
    local gain = math.Rand(binding.Volume[1], binding.Volume[2])
    z:EmitSound(file, level or 75, 100, gain * (voice and z.VocalVolume or 0.85), voice and CHAN_VOICE or CHAN_AUTO)
    if voice then z.ZAVocalUntil, z.ZASpecialVoice = CurTime() + A.Durations[file] + 0.02, file end
end

function S.StopVoice(z)
    if z.ZASpecialVoice then z:StopSound(z.ZASpecialVoice); z.ZASpecialVoice = nil end
    z.ZAVocalUntil = 0
end

function S.DeathVoice(z, rag)
    if not z.ZADeathVoicePending then return end
    z.ZADeathVoicePending = nil
    local binding = z.ZASpecialAssets.Roles.death
    if binding and #binding.Files > 0 then
        -- The live actor is removed after ragdoll creation. Attach the death
        -- voice to its corpse so OnRemove cannot cut it off immediately.
        rag:EmitSound(Pick(binding.Files), 75, 100, math.Rand(binding.Volume[1], binding.Volume[2]) * z.VocalVolume, CHAN_VOICE)
    end
end

function S.RefreshHitboxes(z)
    local armor = S.Armor(z)
    if armor then armor.Refresh(z) else z:SetHitboxSet(0) end
    if z.ZASpecial == "heavy" and z.ZAHeadLayout then
        for _, plate in ipairs(Heavy.Armor) do
            if plate.Name == "helmet" then
                local names = plate.States[z:GetBodygroup(plate.Bodygroup)]
                z.ZAHeadLayout.Hat = names and Heavy.Pieces[names[1]] or nil
                break
            end
        end
    end
    local scale = z:GetModelScale()
    -- Cover authored action poses without rebuilding animated bounds in Think.
    z:SetSurroundingBounds(Vector(-66, -62, -90) * scale, Vector(70, 55, 146) * scale)
    z.ZASpecialScale = scale
end

function S.Initialize(z)
    local settings = C[z.ZASpecial]
    z.ZASpecialSettings, z.ZASpecialAssets = settings, A.Enemies[z.ZASpecial]
    ZA1.Presentation.Initialize(z)
    ZA1.Impact.Initialize(z)
    z.ZAHeadLayout = z.ZASpecialAssets.HeadLayout
    M.InstallSight(); z:AddSharedTagsRelationship(D_LI); z:SetDefaultRelationship(D_HT)
    z.IdleAnimation, z.WalkAnimation = Pick(settings.Idle), Pick(settings.Walk)
    if z.ZASpecial == "skeleton" then
        SkeletonAppearance(z)
        if z.ZASkeletonVariant == "armored" then z.WalkAnimation = Pick(settings.ArmoredWalk) end
    elseif z.ZASpecial == "heavy" then
        for _, plate in ipairs(Heavy.Armor) do
            if plate.Name == "helmet" then
                local state = math.random(#plate.States)
                HeavyArmor.Initialize(z, {Helmet = state, Skin = 0})
                local layout = Heavy.HeadLayout
                z.ZAHeadLayout = {Group = layout.Group, Destroyed = layout.Destroyed,
                    HatGroup = layout.HatGroup, HatHidden = layout.HatHidden, Bodygroups = layout.Bodygroups,
                    Hat = Heavy.Pieces[plate.States[state][1]]}
                break
            end
        end
    end
    z.RunAnimation = settings.Run and Pick(settings.Run) or z.WalkAnimation
    z.FallAnimation, z.MeleeAnimations = z.IdleAnimation, settings.Melee
    z.ZATurnAnimations, z.ZALungeClips = settings.Turn, z.ZASpecialAssets.Lunge
    z.ZAWeakpointShapes = {}
    local weak = z.ZASpecialAssets.Weakpoint
    z.ZAWeakpointBone = weak and z:LookupBone(weak.Bone)
    for _, shape in ipairs(weak and (weak.Shapes or {weak}) or {}) do
        z.ZAWeakpointShapes[#z.ZAWeakpointShapes + 1] = {Name = shape.Name, Bone = z:LookupBone(shape.Bone), Boxes = shape.Boxes}
    end
    z.ZAFootBones = {left = z:LookupBone("Bip01 L Foot"), right = z:LookupBone("Bip01 R Foot")}
    if z.ZASpecialAssets.Breakup then
        local parts = z.ZASpecial == "suicide" and S.SuicideGibs or z.ZASpecialAssets.Breakup
        z.ZABreakupBones = {}
        for index, piece in ipairs(parts) do z.ZABreakupBones[index] = z:LookupBone(piece.Bone) end
    end
    local nav = ZA1.Config.Navigation
    z.loco:SetAcceleration(nav.Acceleration); z.loco:SetDeceleration(nav.Deceleration)
    z.loco:SetMaxYawRate(settings.YawRate or nav.YawRate); z.loco:SetStepHeight(nav.StepHeight)
    z:GetFollowPath():SetMinLookAheadDistance(nav.LookAhead); z:GetFollowPath():SetGoalTolerance(nav.GoalTolerance)
    z.ZANavProfile = N.Profile(z)
    S.RefreshHitboxes(z); z.ZANextSpecialBounds = CurTime() + z:EntIndex() % 16 / 16
    M.Register(z)
end

function S.Tick(z)
    if not z:Alive() then return end
    if CurTime() >= (z.ZANextSpecialBounds or 0) then
        z.ZANextSpecialBounds = CurTime() + 1
        if z:GetModelScale() ~= z.ZASpecialScale then S.RefreshHitboxes(z) end
    end
    if z.ZASpecial ~= "suicide" then return end
    if z.ZAFuse then
        -- The native marker normally detonates it; the same authored time is
        -- also a deadline if the sequence is interrupted or events are skipped.
        if CurTime() >= z.ZAFuse and not z:IsAIDisabled() then S.Detonate(z) end
    elseif z.ZACharging and not z:IsAIDisabled() and not z:IsPossessed() and z:HasEnemy() then
        if CurTime() >= (z.ZAVocalUntil or 0) then S.Sound(z, "run", 80, true) end
    elseif z.ZACharging then z.ZACharging = nil; S.StopVoice(z) end
end

function S.Trace(z, info, dir, tr)
    if not tr or not info:IsBulletDamage() or not tr.StartPos then return end
    if z.ZASpecial == "heavy" then
        local scale = z:GetModelScale()
        local direction = dir:GetNormalized() * ((tr.HitPos - tr.StartPos):Length() + 128 * scale)
        local matrices = {}
        local function Matrix(bone)
            if matrices[bone] == nil then matrices[bone] = z:GetBoneMatrix(bone) or false end
            return matrices[bone] or nil
        end
        tr.ZASourceGroup = tr.ZASourceGroup or tr.HitGroup
        tr.HitGroup, tr.ZAArmorPart, tr.ZAArmorName, tr.ZAArmorMiss = tr.ZASourceGroup, nil, nil, nil
        tr.ZAShotDirection = dir
        local group, body, bodyDistance = HeavyArmor.BodyGroup(z, tr.StartPos, direction, Matrix)
        local pos, distance, part, piece = HeavyArmor.Trace(z, tr.StartPos, direction, Matrix)
        -- Rear flesh can be in front of the chest plate along this shot. Only
        -- the first physical surface absorbs it; armor behind flesh does not.
        if pos and (not bodyDistance or math.sqrt(distance) <= math.sqrt(bodyDistance) + 0.5 * scale) then
            tr.HitGroup, tr.HitPos, tr.ZAArmorPart, tr.ZAArmorName = Heavy.ArmorGroup, pos, part, piece
            info:SetDamagePosition(pos)
        elseif body then
            tr.HitGroup, tr.HitPos = group, body; info:SetDamagePosition(body)
        elseif tr.HitGroup == Heavy.ArmorGroup then
            -- An expanded armor registration box can cover empty space after
            -- its plate is removed. Do not let that turn into a phantom hit.
            tr.ZAArmorMiss = true
        end
        return
    end
    local weak = z.ZASpecialAssets.Weakpoint
    local armored = z.ZASpecial == "skeleton" and Armor.HasArmor(z)
    if tr.HitGroup == weak.Group and not armored and not tr.ZAArmorPart then return end
    -- Anatomy boxes can cover an organ or carried explosive. Recheck the same
    -- shot against the bone-local bounds; world occlusion already chose z.
    local direction = dir:GetNormalized() * ((tr.HitPos - tr.StartPos):Length() + 128 * z:GetModelScale())
    local scale = z:GetModelScale()
    -- Share joint matrices across body, heart and multiple plates on one bone.
    local matrices = {}
    local function Matrix(bone)
        if matrices[bone] == nil then matrices[bone] = z:GetBoneMatrix(bone) or false end
        return matrices[bone] or nil
    end
    tr.ZASourceGroup = tr.ZASourceGroup or tr.HitGroup
    tr.HitGroup = tr.ZASourceGroup
    tr.ZAArmorPart, tr.ZAArmorName = nil, nil
    local closest, nearest, name
    for _, shape in ipairs(z.ZAWeakpointShapes) do
        local matrix = shape.Bone and Matrix(shape.Bone)
        if matrix then for _, box in ipairs(shape.Boxes) do
            local pos = util.IntersectRayWithOBB(tr.StartPos, direction, matrix:GetTranslation(), matrix:GetAngles(),
                Vector(box[1], box[2], box[3]) * scale, Vector(box[4], box[5], box[6]) * scale)
            if pos then
                local square = pos:DistToSqr(tr.StartPos)
                if not nearest or square < nearest then closest, nearest, name = pos, square, shape.Name end
            end
        end end
    end
    if armored then
        local pos, distance, part, piece = Armor.Trace(z, tr.StartPos, direction, Matrix)
        -- The organ's enclosing box and thin plate bounds can overlap slightly.
        -- Resolve that boundary in favor of armor, without treating a plate
        -- behind the heart as cover for a shot from the opposite direction.
        if pos and (not nearest or math.sqrt(distance) <= math.sqrt(nearest) + 0.5 * scale) then
            tr.HitGroup, tr.HitPos = V.ArmorGroup, pos
            tr.ZAArmorPart, tr.ZAArmorName, tr.ZAShotDirection = part, piece, dir
            info:SetDamagePosition(pos)
            return
        end
    end
    if closest then
        tr.HitGroup, tr.HitPos, tr.ZAExplosiveName = weak.Group, closest, name
        info:SetDamagePosition(closest)
    elseif tr.HitGroup == V.ArmorGroup and z.ZASpecial == "skeleton" then
        tr.HitGroup = Armor.BodyGroup(z, tr.StartPos, direction, Matrix)
    end
end

function S.Wounded(z, info, tr)
    if z.ZADeathHandled then info:SetDamage(0); return end
    if info:GetDamage() <= 0 then return end
    z.ZALastDamage = CurTime(); M.Wake(z)
    local attacker = info:GetAttacker()
    if IsValid(attacker) and z:IsHatedEntity(attacker) then
        z:DetectEntity(attacker); M.Investigate(z, attacker:GetPos(), ZA1.Config.Navigation.MemoryDuration); M.Alert(z, attacker:GetPos())
    end
    if z.ZASpecial == "heavy" then
        z.ZAHeavyLastTrace = tr
        if info:IsBulletDamage() and tr then
            if tr.ZAArmorPart and not HeavyArmor.IsWorn(z, tr) and tr.ZAShotDirection then S.Trace(z, info, tr.ZAShotDirection, tr) end
            if tr.ZAArmorMiss then info:SetDamage(0); return end
            if HeavyArmor.Hit(z, info, tr) then return end
            if tr.HitGroup == HITGROUP_HEAD then
                info:ScaleDamage(z.ZASpecialSettings.HeadDamageScale)
                ZA1.Gore.HeadHit(z, info, info:GetDamage() >= z:Health())
            end
        end
    elseif z.ZASpecial == "skeleton" then
        if info:IsBulletDamage() then
            -- A queued trace may refer to a plate removed by an earlier pellet.
            if tr and tr.ZAArmorPart and not Armor.IsWorn(z, tr) and tr.ZAShotDirection then
                S.Trace(z, info, tr.ZAShotDirection, tr)
            end
            if Armor.Hit(z, info, tr) then return end
            if tr and tr.HitGroup == z.ZASpecialAssets.Weakpoint.Group then
                z.ZAHeartPopped = true; info:SetDamage(z:Health())
            else info:SetDamage(0) end
        elseif info:IsDamageType(DMG_CLUB) or info:IsDamageType(DMG_SLASH)
            or info:IsExplosionDamage() and info:GetDamage() >= z.ZASpecialSettings.ExplosionKillDamage then
            info:SetDamage(z:Health())
        end
    elseif z.ZASpecial == "suicide" and tr and tr.HitGroup == z.ZASpecialAssets.Weakpoint.Group and info:IsBulletDamage() then
        -- Let this shot finish DT's injury/death path. Damaging ourselves here
        -- reenters OnInjured and can create a second death thread/ragdoll.
        z.ZAExplodeOnDeath = true; info:SetDamage(z:Health())
        z.ZAShotExplosionPos = tr.HitPos
    elseif tr and tr.HitGroup == HITGROUP_HEAD then
        info:ScaleDamage(2)
        ZA1.Gore.HeadHit(z, info, info:GetDamage() >= z:Health())
    end
end

function S.Breakup(z, info)
    if z.ZABrokenApart then return end
    z.ZABrokenApart = true
    local pieces = {}
    local upper, lower
    if z.ZASpecial=="suicide" and ZA1.Halves then upper,lower=ZA1.Halves.Pair(z,info) end
    local velocity = z:GetVelocity() + info:GetDamageForce():GetNormalized() * math.min(info:GetDamageForce():Length() / 20, 180)
    local parts = z.ZASpecial == "suicide" and S.SuicideGibs or z.ZASpecialAssets.Breakup
    for index, piece in ipairs(parts) do
        local bone = z.ZABreakupBones[index]
        local matrix = bone and z:GetBoneMatrix(bone)
        local replaced = piece.ID == 38 and IsValid(lower)
        if matrix and not replaced and not (piece.Head and z.ZAHeadDestroyed) then
            local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
            if piece.Offset then
                pos, ang = LocalToWorld(Vector(unpack(piece.Offset)) * z:GetModelScale(), Angle(unpack(piece.Angles)), pos, ang)
            end
            pieces[#pieces + 1] = {ID = piece.ID, Pos = pos, Ang = ang,
                Body = z.ZASpecial == "skeleton" and z:GetBodygroup(V.Bodygroups.body) or 0,
                Velocity = velocity + (pos - z:WorldSpaceCenter()):GetNormalized() * 80 + Vector(0, 0, 100)}
        end
    end
    if z.ZASpecial == "skeleton" then
        for _, name in ipairs(S.EquipmentPieces(z)) do
            local piece = V.Pieces[name]
            local bone = z.ZASkeletonGearBones[piece.Bone]
            local matrix = bone and z:GetBoneMatrix(bone)
            if matrix then
                local pos, ang = LocalToWorld(Vector(unpack(piece.Offset)) * z:GetModelScale(), Angle(unpack(piece.Angles)),
                    matrix:GetTranslation(), matrix:GetAngles())
                pieces[#pieces + 1] = {ID = piece.ID, Pos = pos, Ang = ang,
                    Velocity = velocity + (pos - z:WorldSpaceCenter()):GetNormalized() * 80 + Vector(0, 0, 100)}
            end
        end
    end
    ZA1.Debris.Breakup(pieces, z:GetPos(), z:GetModelScale())
    if z.ZASpecial=="suicide" then ZA1.Feedback.FullGib(z) end
    if z.ZAHeartPopped then
        local data = EffectData(); data:SetOrigin(info:GetDamagePosition()); data:SetScale(0.5)
        util.Effect("cball_explode", data, true, true)
    end
    z:SetNoDraw(true)
end

local function Explosion(z, info)
    if z.ZADetonated then return end
    z.ZADetonated = true; S.StopVoice(z); N.Cancel(z); G.Release(z)
    local pos = z.ZAShotExplosionPos or z:WorldSpaceCenter()
    if not z.ZAShotExplosionPos then
        local bone = z.ZAWeakpointBone and z:GetBoneMatrix(z.ZAWeakpointBone)
        if bone then pos = bone:GetTranslation() end
    end
    local attacker, inflictor = info:GetAttacker(), info:GetInflictor()
    attacker = IsValid(attacker) and attacker or z
    inflictor = IsValid(inflictor) and inflictor or z
    ZA1.Feedback.Explosion(pos)
    local settings = z.ZASpecialSettings
    if ZA1.Doors then ZA1.Doors.Blast(z, pos, settings.BlastRadius * z:GetModelScale(), settings.BlastDamage) end
    util.BlastDamage(inflictor, attacker, pos, settings.BlastRadius * z:GetModelScale(), settings.BlastDamage)
end

function S.Detonate(z, attacker, inflictor)
    if not IsValid(z) or not z:Alive() or z.ZADeathHandled or z.ZAExplodeOnDeath or z.ZADetonated then return false end
    z.ZAExplodeOnDeath = true
    local damage = DamageInfo(); damage:SetDamage(z:Health()); damage:SetDamageType(DMG_BLAST)
    damage:SetAttacker(IsValid(attacker) and attacker or z)
    damage:SetInflictor(IsValid(inflictor) and inflictor or z)
    damage:SetDamagePosition(z:WorldSpaceCenter())
    -- Only death emits the blast. It cannot hit an owner still inside its
    -- grenade-shot injury callback, and chained explosions keep their credit.
    z:TakeDamageInfo(damage)
    return true
end

function S.Arm(z, target)
    if z.ZAFuse or z.ZADetonated or not z:Alive() then return false end
    if target and (not IsValid(target) or not z:IsHatedEntity(target)
        or z:GetPos():DistToSqr(target:GetPos()) > z.ZASpecialSettings.TriggerRange ^ 2) then return false end
    local sequence = z.ZASpecialSettings.Detonate
    local direction = target and target:GetPos() - z:GetPos() or z:GetForward()
    direction.z = 0
    if z:GetVelocity():Dot(z:GetForward()) > ZA1.Config.Turning.StationarySpeed
        and (direction:LengthSqr() == 0 or z:GetForward():Dot(direction:GetNormalized())
            >= math.cos(math.rad(ZA1.Config.Melee.FacingAngle))) then
        sequence = z.ZASpecialSettings.DetonateMoving
    end
    local marker = z.ZASpecialAssets.Explosion[sequence]
    if not marker then return false end
    S.StopVoice(z); z.ZAFuse = CurTime() + marker.Time; z.ZACharging = nil
    G.ReleaseClaim(z)
    z:ZAPlayOnce(sequence, function()
        if z:IsAIDisabled() then return false end
        if CurTime() >= z.ZAFuse then S.Detonate(z); return false end
    end)
    return true
end

function S.Combat(z, enemy)
    if z.ZASpecial ~= "suicide" then return baseclass.Get("npc_dt_za1_zombie").ZACombat(z, enemy) end
    local goal, visible = z:ZAEnemyGoal(enemy)
    if CurTime() - (z:LastTimeDetected(enemy) or 0) > ZA1.Config.Navigation.MemoryDuration then z:LoseEntity(enemy); return false end
    z:SetAIState(DT_Base.AI_STATE_COMBAT)
    if not goal then return true end
    if not z.ZACharging then z.ZACharging = true; S.Sound(z, "start", 80, true) end
    z.ZACloseGoal = visible and goal or nil
    if visible and z:GetPos():DistToSqr(enemy:GetPos()) <= z.ZASpecialSettings.TriggerRange ^ 2
        and z:Visible(enemy) then
        z:FaceTowards(goal); S.Arm(z, enemy)
    elseif z:GetPos():DistToSqr(goal) > ZA1.Config.Navigation.ArrivalDistance ^ 2 then z:ZAMove(goal, enemy)
    else z.ZAFaceGoal = goal; z:FaceTowards(goal) end
    return true
end

function S.Event(z, event, time, cycle, typ, options)
    if not z:Alive() then return end
    if event == 1102 and z.ZAFuse then
        local marker = z.ZASpecialAssets.Explosion[z:GetSequenceName(z:GetSequence())]
        if marker and marker.Option == options then S.Detonate(z); return true end
    end
    if event == 1101 then
        if not M.EventAudible(z) then return true end
        local bindings = z.ZASpecialAssets.Animations[z:GetSequenceName(z:GetSequence())]
        local binding = bindings and bindings[options]
        if not binding or #binding.Files == 0 then return true end
        local name, file = binding.Name, Pick(binding.Files)
        local gain = math.Rand(binding.Volume[1], binding.Volume[2])
        if name:find("Breathe", 1, true) then
            local exhale = name:find("Breathe_Out", 1, true) ~= nil
            local finish = exhale and "ZABreathOutUntil" or "ZABreathInUntil"
            if CurTime() < (z[finish] or 0) then return true end
            z:EmitSound(file, 60, 100, gain * z.BreathVolume, exhale and CHAN_ITEM or CHAN_BODY)
            z[finish] = CurTime() + A.Durations[file]; z[exhale and "ZABreathOutSound" or "ZABreathInSound"] = file
        elseif name:find("Vox", 1, true) then
            local final = name == "Suicide_Vox_Final_Scream"
            if not final and CurTime() < (z.ZAVocalUntil or 0) then return true end
            local policy = ZA1.Config.Audio.VocalEvents[name]
            if policy then
                if CurTime() < (z.ZANextEventVocal or 0) or math.Rand(0, 1) >= policy.Chance then return true end
                z.ZANextEventVocal = CurTime() + math.Rand(policy.MinDelay, policy.MaxDelay)
            end
            z:EmitSound(file, final and 85 or 70, 100, gain * z.VocalVolume, CHAN_VOICE)
            z.ZAVocalUntil, z.ZASpecialVoice = CurTime() + A.Durations[file] + 0.02, file
        else z:EmitSound(file, 65, 100, gain, CHAN_AUTO) end
        return true
    end
    local label = util.GetAnimEventNameByID(event)
    if label == "AE_NPC_LEFTFOOT" or label == "AE_NPC_RIGHTFOOT" then
        return baseclass.Get("npc_dt_za1_zombie").HandleAnimEvent(z, event, time, cycle, typ, options)
    end
    if event ~= 1100 or options ~= "za1_melee" or not z.ZAAttacking
        or z.ZALastMeleeEvent and cycle <= z.ZALastMeleeEvent then return end
    z.ZALastMeleeEvent = cycle
    local melee = ZA1.Config.Melee
    local tr = util.TraceHull({start = z:WorldSpaceCenter(), endpos = z:WorldSpaceCenter() + z:GetForward() * melee.Range,
        mins = Vector(-melee.HullWidth, -melee.HullWidth, -melee.HullHeight),
        maxs = Vector(melee.HullWidth, melee.HullWidth, melee.HullHeight), mask = MASK_SHOT_HULL, filter = z})
    local victim = tr.Entity
    if ZA1.Doors and ZA1.Doors.Hit(z, victim, tr.HitPos) then return true end
    if IsValid(victim) and victim.GetActor then
        local actor = victim:GetActor()
        if IsValid(actor) then victim = actor end
    end
    if z:ZACanMelee(victim) then
        local damage = DamageInfo(); damage:SetAttacker(z); damage:SetInflictor(z)
        damage:SetDamage(z.ZASpecialSettings.MeleeDamage); damage:SetDamageType(DMG_SLASH)
        damage:SetDamagePosition(tr.HitPos); damage:SetDamageForce(z:GetForward() * 3000); victim:TakeDamageInfo(damage)
    end
end

function S.Died(z, info)
    if z.ZADeathHandled then return end
    z.ZADeathHandled = true; S.StopVoice(z)
    if z.ZABreathInSound then z:StopSound(z.ZABreathInSound) end
    if z.ZABreathOutSound then z:StopSound(z.ZABreathOutSound) end
    if z.ZASpecial == "skeleton" then S.Sound(z, "death", 80, true); S.Breakup(z, info)
    elseif z.ZASpecial == "heavy" then z.ZADeathVoicePending = true
    elseif z.ZAFuse or z.ZAExplodeOnDeath then S.Breakup(z, info); Explosion(z, info)
    elseif info:IsExplosionDamage() then S.Breakup(z, info) end
    M.Killed(z)
end
