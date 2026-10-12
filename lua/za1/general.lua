-- Undead_ArchType: authored waves, skull shield, timed recharge and three
-- full health depletions. Native data/provenance live in general_assets.
if SERVER then AddCSLuaFile() end
local B = ZA1.General or {}; ZA1.General = B
if CLIENT then return end
local E, M, N, native = ZA1.Elites, ZA1.Manager, ZA1.Navigation, ZA1.GeneralAssets
local function Alive(z) return IsValid(z) and z:Alive() and not z.ZADeathHandled and not z.ZAGeneralDefeated end
local function Able(z) return Alive(z) and not z:IsAIDisabled() and not z.ZADowned end
local function Stage(z) return native.Stages[z.ZAGeneralPhase] end
local function Pulse(z, role, position, angles)
    if ZA1.EnemyVFX then return ZA1.EnemyVFX.Pulse(z, role, position, angles) end
end
function B.SyncVFX(z)
    if not ZA1.EnemyVFX or not IsValid(z) then return end
    local state = not Alive(z) and "stopped" or z.ZAEmerge and "emerging"
        or z.ZAGeneralInjured and (z.ZAGeneralPhase == #native.Stages
            and (z.ZAGeneralSinkRing and "sinking" or "injured_final") or "injured") or z.ZAGeneralRecharging and "recharging"
        or z.ZAGeneralCasting and "casting" or z.ZAGeneralVisualShield and "shielded" or "exposed"
    return ZA1.EnemyVFX.SetState(z, state)
end
local function Appearance(z, transparent)
    for _, variant in pairs(z.ZASpecialAssets.Variants or {}) do
        z:SetBodygroup(variant.Group, transparent and variant.Shielded or variant.Normal)
    end
    z.ZAGeneralVisualShield = transparent
    z:SetNW2Bool("za1_occult_shield", transparent)
    B.SyncVFX(z)
end
function B.ClearSkulls(z)
    local pool = z.ZAGeneralSkulls or {}
    z.ZAGeneralSkulls, z.ZAGeneralSkullCount = {}, 0
    for _, skull in ipairs(pool) do if IsValid(skull) then skull.ZAQuietRemove = true; skull:Remove() end end
end
function B.ClearWave(z)
    E.CancelJobs(z)
    for _, child in ipairs(z.ZAMinions or {}) do
        if IsValid(child) and child.ZASummonedBy == z then
            if ZA1.EnemyVFX then ZA1.EnemyVFX.Pulse(child, "dissolve") end
            child:Remove()
        end
    end
    z.ZAMinions, z.ZAGeneralWave = {}, nil
end
function B.RestoreShield(z, transparent)
    if not Alive(z) then return end
    B.ClearSkulls(z)
    z.ZAGeneralShield, z.ZAGeneralVulnerable = true, false
    z.ZAGeneralExposure, z.ZAGeneralBreak = nil, nil
    z.ZAGeneralEpoch = (z.ZAGeneralEpoch or 0) + 1
    z.ZAGeneralOrbitStart = CurTime()
    local settings, data = z.ZASpecialSettings.Shield, z.ZASpecialAssets.Skull
    for _, path in ipairs(settings.Paths) do
        local skull = ents.Create("sent_za1_occult_skull")
        if IsValid(skull) then
            skull.ZAGeneral, skull.ZAEpoch, skull.ZAPath = z, z.ZAGeneralEpoch, path
            skull.ZAData, skull.ZASettings = data, settings
            skull:SetPos(z:GetPos()); skull:Spawn(); skull:Activate()
            if IsValid(skull) then
                z.ZAGeneralSkulls[#z.ZAGeneralSkulls + 1] = skull
                z.ZAGeneralSkullCount = z.ZAGeneralSkullCount + 1
            end
        end
    end
    if transparent ~= false then Appearance(z, true) end
    -- A failed Source entity allocation must not leave an unbeatable shield.
    if z.ZAGeneralSkullCount == 0 then B.SkullLost(z, z.ZAGeneralEpoch) end
end
function B.Initialize(z)
    z.ZAGeneralPlayers = math.Clamp(#player.GetHumans(), 1, 4)
    local health = native.CoopHealth[z.ZAGeneralPlayers]
    z:SetMaxHealth(health); z:SetHealth(health)
    z.ZAGeneralPhase, z.ZAGeneralArrival, z.ZAGeneralEpoch, z.ZAGeneralSkulls = 1, 1, 0, {}
    z.ZAGeneralWave, z.ZAGeneralReadyAt, z.ZANextSummon = nil, nil, nil
    z.ZAGeneralRestoring, z.ZAGeneralRestoreStep, z.ZAGeneralFlashUntil, z.ZAGeneralInjuryPlayed = nil, nil, nil, nil
    z.ZAGeneralTerminal, z.ZAGeneralFinalActionPlayed, z.ZAGeneralSinkRing = nil, nil, nil
    z.ZAEmerge = z.ZASpecialSettings.Sequences.Enter
    B.RestoreShield(z)
end
function B.Restore(z, record)
    z.ZAGeneralPhase = math.Clamp(record.generalPhase, 1, #native.Stages)
    z.ZAGeneralArrival, z.ZAGeneralPlayers = record.generalArrival or 2, record.generalPlayers or z.ZAGeneralPlayers
    z.ZAGeneralAdvance, z.ZAGeneralInjured = record.generalInjured, record.generalInjured
    if record.generalShield then
        B.RestoreShield(z)
        for i = #z.ZAGeneralSkulls, (record.generalSkulls or #z.ZAGeneralSkulls) + 1, -1 do
            local skull = table.remove(z.ZAGeneralSkulls, i)
            if IsValid(skull) then skull.ZAQuietRemove = true; skull:Remove() end
        end
        z.ZAGeneralSkullCount = #z.ZAGeneralSkulls
        if z.ZAGeneralSkullCount == 0 then B.SkullLost(z, z.ZAGeneralEpoch) end
    else
        B.ClearSkulls(z); z.ZAGeneralShield = false
        z.ZAGeneralBreak = record.generalBreak or record.generalExposure == nil
        z.ZAGeneralVulnerable = not z.ZAGeneralBreak and not z.ZAGeneralAdvance
        z.ZAGeneralRecharging = z.ZAGeneralVulnerable or nil
        z.ZAGeneralExposure = record.generalExposure and CurTime() + record.generalExposure
        Appearance(z, false)
    end
end
function B.Stop(z)
    B.ClearSkulls(z); B.ClearWave(z)
    z.ZAGeneralShield, z.ZAGeneralBreak, z.ZAGeneralAdvance, z.ZAGeneralHit = nil, nil, nil, nil
    z.ZAGeneralCasting, z.ZAGeneralSpawning, z.ZAGeneralRecharging, z.ZAGeneralCastVFX = nil, nil, nil, nil
    z.ZAGeneralInjured, z.ZAGeneralVulnerable, z.ZAGeneralExposure, z.ZAGeneralReadyAt = nil, nil, nil, nil
    z.ZAGeneralRestoring, z.ZAGeneralRestoreStep, z.ZAGeneralFlashUntil, z.ZAGeneralInjuryPlayed = nil, nil, nil, nil
    z.ZAGeneralSinkRing = nil
    if ZA1.EnemyVFX and IsValid(z) then ZA1.EnemyVFX.SetState(z, "stopped") end
end
function B.SkullLost(z, epoch)
    if not Alive(z) or z.ZAGeneralEpoch ~= epoch or not z.ZAGeneralShield then return end
    z.ZAGeneralSkullCount = math.max(0, z.ZAGeneralSkullCount - 1)
    if z.ZAGeneralSkullCount > 0 then return end
    z.ZAGeneralShield, z.ZAGeneralBreak = false, true
    -- The native tree defers this branch while a wave is still being cast.
    M.Wake(z)
end
function B.Damage(z, info, tr)
    if z.ZAGeneralTerminal and info:GetInflictor() == z then return true end
    if z.ZAGeneralDefeated or z.ZADeathHandled then info:SetDamage(0); return true end
    local attacker = info:GetAttacker()
    if IsValid(attacker) and z:IsHatedEntity(attacker) then z:DetectEntity(attacker); M.Alert(z, attacker:GetPos()) end
    z.ZALastDamage = CurTime()
    local factor = info:IsBulletDamage() and .7 or info:IsExplosionDamage() and .5 or 0
    -- The native TYPE3 callback applies damage-type resistance and contains
    -- no head-only gate. Source model traces supply the admitted hit region;
    -- original mission collision routing is not reconstructed here.
    if not z.ZAGeneralVulnerable or z.ZAGeneralAdvance or factor == 0 then
        info:SetDamage(0)
        if info:IsBulletDamage() and CurTime() >= (z.ZANextGeneralHitVFX or 0) then
            z.ZANextGeneralHitVFX = CurTime() + .08
            Pulse(z, "shield_hit", tr and isvector(tr.HitPos) and tr.HitPos or info:GetDamagePosition())
        end
        return true
    end
    local damage = math.max(0, info:GetDamage() * factor)
    if damage > 0 then
        Pulse(z, tr and tr.HitGroup == HITGROUP_HEAD and "head_hit" or "shield_hit",
            tr and isvector(tr.HitPos) and tr.HitPos or info:GetDamagePosition())
    end
    -- Source stores health as an integer: a fractional remainder below one
    -- can still become a killing hit. Protect that boundary before dispatch.
    if math.ceil(damage) >= z:Health() then
        -- FUN79B210 refills TYPE3 health, marks Injured/Invincible and cancels
        -- ordinary killing damage. The Stage3 action later uses a death bypass.
        z:SetHealth(z:GetMaxHealth()); info:SetDamage(0)
        z.ZAGeneralAdvance, z.ZAGeneralInjured, z.ZAGeneralVulnerable = true, true, false
        z.ZAGeneralKiller = attacker
        B.SyncVFX(z); M.Wake(z)
    else
        info:SetDamage(damage)
        if damage > 0 then
            local sequences = z.ZASpecialSettings.Sequences
            z.ZAGeneralHit = math.random(2) == 1 and sequences.HitLeft or sequences.HitRight
        end
    end
    return true
end
-- A killing hit can dispatch OnKilled without OnInjured. Handle the shield
-- and TYPE3 refill before the engine subtracts health, including burst pellets.
hook.Add("EntityTakeDamage", "ZA1/GeneralDamage", function(z, info)
    if z.ZASpecial ~= "general" or not z.DT_NextBot or not z.ZASpecialSettings then return end
    B.Damage(z, info, z.__DT_TraceAttack)
    z.__DT_TraceAttack = nil
    if info:GetDamage() <= 0 then return true end
end)
local function CastCues(z)
    local cast = z.ZAGeneralCastVFX
    if not cast then return end
    local age = CurTime() - cast.Start
    if not cast.AOE and age >= 3.75 then cast.AOE = true; Pulse(z, "cast_aoe") end
    if not cast.Impact and age >= 3.95 then cast.Impact = true; Pulse(z, "cast_impact") end
end
local function Play(z, sequence, callback)
    return E.Play(z, sequence, function()
        if not Able(z) then return false end
        CastCues(z)
        if callback then return callback() end
    end)
end
local function Hold(z, sequence, deadline, callback)
    local id = z:PlaySequence(sequence, {move = false})
    z.ZAActing = true
    local flags = DT_Base.ToYieldFlags({doWounded = false, doIncapacitated = true})
    while Able(z) and z:GetSequence() == id and CurTime() < deadline do
        if callback and callback() == false then break end
        if z:GetCycle() >= 1 then z:SetCycle(0) end
        if coroutine.yield(flags) then break end
    end
    z.ZAActing = nil
    return Able(z) and CurTime() >= deadline
end
function B.Roster(z)
    return Stage(z).Arrivals[z.ZAGeneralArrival].Rosters[z.ZAGeneralPlayers]
end
function B.WavePercent(z)
    local wave = z.ZAGeneralWave
    if not wave or wave.Size == 0 then return 0, 0 end
    local live = wave.Queued
    for i = #wave.Actors, 1, -1 do
        if Alive(wave.Actors[i]) then live = live + 1 else table.remove(wave.Actors, i) end
    end
    return math.ceil(live / wave.Size * 100), live
end
function B.WaveReady(z)
    if z.ZAGeneralArrival == 1 then return true end
    local percent, live = B.WavePercent(z)
    local minimum = native.MinimumActive[z.ZAGeneralPhase]
    local limit = z.ZAGeneralWave and z.ZAGeneralWave.RemainingPercent or B.Roster(z).RemainingPercent
    return percent <= limit or minimum >= 0 and live + B.Roster(z).Count < minimum
end
function B.Wave(z)
    local roster, arrival = B.Roster(z), Stage(z).Arrivals[z.ZAGeneralArrival]
    local wave = arrival.Append and z.ZAGeneralWave or nil
    wave = wave or {Actors = {}, Queued = 0, Size = 0}
    z.ZAGeneralWave, wave.RemainingPercent = wave, roster.RemainingPercent
    local rings = {Inner = {}, Outer = {}}
    for _, member in ipairs(roster.Members) do
        local ring = member.Inner and rings.Inner or rings.Outer
        for _ = 1, member.Count do ring[#ring+1] = member.Class end
    end
    local phase, count = math.Rand(0, math.pi * 2), 0
    for _, name in ipairs({"Inner", "Outer"}) do
        local ring = rings[name]
        for index, class in ipairs(ring) do
            local placement = {Angle = phase + (index-1+(name == "Outer" and .5 or 0))*math.pi*2/#ring,
                Radii = native.WaveRadii[name], RandomFacing = native.RandomFacing}
            if E.QueueMinion(z, class, nil, wave, placement) then count = count + 1 else return count end
        end
    end
    return count
end
function B.Cast(z)
    if not Able(z) or z.ZAGeneralAdvance or z.ZAGeneralVulnerable or z.ZAGeneralSpawning
        or not B.WaveReady(z) or E.MinionCount(z) >= z.ZASpecialSettings.MinionLimit then return false end
    z.ZAGeneralReadyAt = z.ZAGeneralReadyAt or CurTime() + native.PrespawnTime
    if CurTime() < z.ZAGeneralReadyAt then return false end
    z.ZAGeneralReadyAt, z.ZAGeneralSpawning = nil, true
    if B.Wave(z) == 0 then z.ZAGeneralSpawning = nil; z.ZAGeneralReadyAt = CurTime() + native.PollInterval; return false end
    z.ZAGeneralCastVFX = {Start = CurTime()}
    local sequences = z.ZASpecialSettings.Sequences
    local completed = Play(z, sequences.CastInto)
    if completed then
        z.ZAGeneralCasting = true; B.SyncVFX(z)
        completed = Play(z, sequences.CastLoop)
        while completed and z.ZAGeneralWave and z.ZAGeneralWave.Queued > 0 do
            completed = Play(z, sequences.CastLoop)
        end
    end
    if completed then completed = Play(z, sequences.CastOut) end
    z.ZAGeneralCasting, z.ZAGeneralSpawning, z.ZAGeneralCastVFX = nil, nil, nil
    if completed then z.ZAGeneralArrival = 2 else E.CancelJobs(z) end
    B.SyncVFX(z)
    return true
end
local function Rebuild(z, flashTime)
    local seq = z.ZASpecialSettings.Sequences
    if not z.ZAGeneralRestoring then
        z.ZAGeneralRestoring, z.ZAGeneralRestoreStep = flashTime, "animation"
        z.ZAGeneralVulnerable, z.ZAGeneralRecharging = false, nil
        B.SyncVFX(z); B.RestoreShield(z, false); Pulse(z, "shield_regeneration")
    end
    if z.ZAGeneralRestoreStep == "animation" then
        if not Play(z, seq.Restored) then return false end
        z.ZAGeneralInjured = nil; Appearance(z, true); Pulse(z, "shield_recharged")
        z.ZAGeneralRestoreStep, z.ZAGeneralFlashUntil = "flash", CurTime() + z.ZAGeneralRestoring
    end
    if not Hold(z, seq.RestoredFlash, z.ZAGeneralFlashUntil) then return false end
    z.ZAGeneralRestoring, z.ZAGeneralRestoreStep, z.ZAGeneralFlashUntil = nil, nil, nil
    return true
end
local function Injury(z)
    local stage, seq = Stage(z), z.ZASpecialSettings.Sequences
    if not z.ZAGeneralInjuryPlayed then
        B.ClearSkulls(z); E.CancelJobs(z)
        z.ZAGeneralRecharging, z.ZAGeneralExposure, z.ZAGeneralBreak = nil, nil, nil
        z.ZAGeneralVulnerable, z.ZAGeneralInjured = false, true
        Appearance(z, false)
    end
    if z.ZAGeneralPhase == #native.Stages then
        -- Both native Stage3 Teleport1042 nodes play F38CC27B:
        -- Arch_Resurrect_Interrupted. Health415 follows its completion.
        local began = CurTime()
        z.ZAGeneralSinkRing = nil; B.SyncVFX(z)
        if not Play(z, seq.Interrupted, function()
            if not z.ZAGeneralSinkRing and CurTime() - began >= z.ZASpecialSettings.RetreatRingDelay then
                z.ZAGeneralSinkRing = true; B.SyncVFX(z)
            end
        end) then return end
        z.ZAGeneralFinalActionPlayed, z.ZAGeneralTerminal = true, true
        z.ZAGeneralInjured, z.ZAGeneralSinkRing, z.ZAGeneralVulnerable = nil, nil, true
        if ZA1.EnemyVFX then ZA1.EnemyVFX.SetState(z, "stopped") end
        local info = DamageInfo()
        info:SetAttacker(IsValid(z.ZAGeneralKiller) and z.ZAGeneralKiller or z)
        info:SetInflictor(z); info:SetDamage(z:Health()); info:SetDamageType(DMG_GENERIC)
        z:TakeDamageInfo(info)
        return
    end
    if not z.ZAGeneralInjuryPlayed then
        if not Play(z, seq.RechargeInto) then return end
        z.ZAGeneralInjuryPlayed = true
    end
    if not Rebuild(z, stage.InjuryFlashTime) then return end
    z.ZAGeneralInjuryPlayed = nil
    z.ZAGeneralAdvance, z.ZAGeneralHit = nil, nil
    z.ZAGeneralPhase, z.ZAGeneralArrival = z.ZAGeneralPhase + 1, 1
    -- Native append=false replaces only roster tracking, preserving survivors.
    z.ZAGeneralWave, z.ZAGeneralReadyAt = nil, nil
end
local function Recharge(z)
    local seq = z.ZASpecialSettings.Sequences
    if z.ZAGeneralBreak then
        Appearance(z, false); Pulse(z, "shield_break")
        if not Play(z, seq.BreakInto) or not Play(z, seq.BreakLoop) then return end
        z.ZAGeneralBreak = nil
        z.ZAGeneralVulnerable, z.ZAGeneralRecharging = true, true
        z.ZAGeneralExposure = CurTime() + Stage(z).RestoreTime
        B.SyncVFX(z)
    end
    while Able(z) and not z.ZAGeneralAdvance and CurTime() < z.ZAGeneralExposure do
        if z.ZAGeneralHit then
            local hit = z.ZAGeneralHit; z.ZAGeneralHit = nil
            Play(z, hit, function() return not z.ZAGeneralAdvance and CurTime() < z.ZAGeneralExposure end)
        else
            Hold(z, seq.Recharge, z.ZAGeneralExposure,
                function() return not z.ZAGeneralAdvance and not z.ZAGeneralHit end)
        end
    end
    if Able(z) and not z.ZAGeneralAdvance then Rebuild(z, Stage(z).RestoreFlashTime) end
end
function B.Decide(z, mayCast)
    N.Cancel(z); ZA1.Crowd.Release(z)
    B.SyncVFX(z)
    if not Able(z) then return end
    if z.ZAGeneralAdvance and not z.ZAGeneralSpawning then Injury(z); return end
    if z.ZAGeneralRestoring then Rebuild(z, z.ZAGeneralRestoring); return end
    if z.ZAGeneralArrival == 2 and not z.ZAGeneralSpawning and (z.ZAGeneralBreak or z.ZAGeneralExposure) then Recharge(z); return end
    if mayCast ~= false and (z:HasEnemy() or z:IsPossessed()) then
        z:SetAIState(z:IsPossessed() and DT_Base.AI_STATE_POSSESSION or DT_Base.AI_STATE_COMBAT); B.Cast(z)
    else z:SetAIState(DT_Base.AI_STATE_REST) end
end
function B.Die(z)
    B.Stop(z)
    -- The final action runs while alive, before terminal damage. Death cleanup
    -- must not replace it with a second animation or reverse emergence.
    z.ZAGeneralDefeated = true
    z.ZAActing, z.ZADeathPlaying = nil, nil
end
