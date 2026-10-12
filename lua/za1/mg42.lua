-- Undead_Super_Elite: melee nearby, otherwise follow and fire in parallel.
-- Its linked LookAtAndFire task selects native counted bursts (mode 3).
if SERVER then AddCSLuaFile() end
local K = ZA1.MG42 or {}; ZA1.MG42 = K
if CLIENT then return end
local W, E, N = ZA1.MajorGuns, ZA1.Elites, ZA1.Navigation
local function Active(z)
    return IsValid(z) and z:Alive() and not z.ZADeathHandled and not z.ZADowned
end
local function Target(enemy) return IsValid(enemy) and (not enemy.Alive or enemy:Alive()) end
local function PainStage(z, health)
    return math.Clamp(math.floor((z:GetMaxHealth() - health) / (z:GetMaxHealth() * .2) + .000001), 0, 4)
end
local function ClearPain(z)
    if z.ZAMG42 then z.ZAMG42.PendingPain = nil end
    z.ZAPainPending = nil
end
local clearReasons = {inactive = true, incapacitated = true, removed = true, error = true,
    possession_changed = true, possessed = true}
function K.Initialize(z)
    z.ZAMG42 = {State = "idle", NextBurst = CurTime(), ShotSerial = z.ZAGunShotSerial or 0,
        PainStage = PainStage(z, z:Health()), Policy = {Continuous = false, FireAllowed = true}}
end
function K.Interrupt(z, reason)
    local state = z.ZAMG42
    if state then
        state.State, state.Target, state.BurstStarted = reason or "interrupted", nil, nil
        state.ShotSerial = z.ZAGunShotSerial or 0
    end
    if clearReasons[reason] then
        ClearPain(z)
        if state then state.ReactionActive = nil end
    end
    W.Stop(z)
end
function K.Damage(z, info, tr)
    if not info or info:GetDamage() <= 0 then return end
    local state = z.ZAMG42
    if not state then K.Initialize(z); state = z.ZAMG42 end
    local health = math.max(0, z:Health() - info:GetDamage())
    local previous = math.max(state.PainStage or 0, PainStage(z, z:Health()))
    local stage = PainStage(z, health)
    state.PainStage = math.max(previous, stage)
    if not Active(z) or health <= 0 or z:IsAIDisabled() or z:IsPossessed() then ClearPain(z); return end
    -- Native Type4 forces a reaction at each 20% health crossing, or on its
    -- first positive head hit before any reaction. Other native force flags
    -- have no established Source equivalent and are not guessed here.
    if stage > previous or not state.Reacted and tr and tr.HitGroup == HITGROUP_HEAD then
        state.PendingPain, state.Reacted = stage == 0 and 100 or 100 - stage * 20, true
        z.ZAPainPending = true
        K.Interrupt(z, "wounded")
    end
end
function K.Flinch(z)
    if not Active(z) or z:IsAIDisabled() or z:IsPossessed() then ClearPain(z); return false end
    if z.ZAActing then return false end
    local state = z.ZAMG42
    if not state then return false end
    local band = state.PendingPain
    if not band then z.ZAPainPending = nil; return false end
    -- Consume before yielding. A later health crossing may replace the one
    -- pending slot while this clip plays; repeated hits cannot restart it.
    ClearPain(z)
    local flinches = z.ZASpecialSettings.Flinches
    local sequence = flinches and flinches[band]
    if not sequence or z:LookupSequence(sequence) < 0 then return false end
    K.Interrupt(z, "reaction")
    -- Native uses named Arms/Torso layers with .1/.3 blending. Their exact
    -- bone masks are not recovered; these absolute clips include root/legs.
    -- Full-body authored playback is the safe Source adapter, without a
    -- guessed bone mask or a cooldown that suppresses later milestones.
    state.ReactionActive = true
    E.Play(z, sequence)
    state.ReactionActive = nil
    return true
end
function K.Tick(z)
    local state = z.ZAMG42
    if not state then return end
    if not Active(z) or z:IsAIDisabled() then K.Interrupt(z, "inactive"); return end
    if z:IsPossessed() then
        -- Clear an AI request once at handover. Subsequent possession fire
        -- belongs to the shared gun driver and must not be stopped each tick.
        if state.Target or state.BurstStarted then K.Interrupt(z, "possessed") end
        return
    end
    if z.ZAActing or z.ZAPainPending then K.Interrupt(z, "reaction"); return end
    if state.Target and (not Target(state.Target) or z:GetEnemy() ~= state.Target) then
        K.Interrupt(z, "target_changed"); return
    end
    -- Only a completed, actually discharged burst starts the native wait.
    -- A blocked muzzle or a cancelled request cannot consume that interval.
    local serial = z.ZAGunShotSerial or 0
    if state.BurstStarted and not z.ZAGunTrigger and (z.ZAGunBurst or 1) <= 0
        and serial > state.ShotSerial then
        local gun = z.ZASpecialSettings.Gun
        state.NextBurst = (z.ZAGunLastShot or CurTime()) + math.Rand(gun.BurstPauseMin, gun.BurstPauseMax)
        state.BurstStarted, state.State = nil, "burst_wait"
    end
    state.ShotSerial = serial
end
function K.Combat(z, enemy)
    if not Active(z) or z:IsAIDisabled() or z:IsPossessed() then K.Interrupt(z, "inactive"); return false end
    local state = z.ZAMG42
    if not state then K.Initialize(z); state = z.ZAMG42 end
    K.Tick(z)
    if K.Flinch(z) then return true end
    if z.ZAActing or z.ZAGunReloading then return true end
    if not Target(enemy) then K.Interrupt(z, "target_lost"); return false end
    local goal, visible = z:ZAEnemyGoal(enemy)
    if not goal or CurTime() - (z:LastTimeDetected(enemy) or 0) > ZA1.Config.Navigation.MemoryDuration then
        K.Interrupt(z, "target_lost"); z:LoseEntity(enemy); return false
    end
    z:SetAIState(DT_Base.AI_STATE_COMBAT)
    if state.Target and state.Target ~= enemy then K.Interrupt(z, "target_changed") end
    state.Target = enemy
    local settings, distance = z.ZASpecialSettings, z:GetPos():DistToSqr(goal)
    if visible and distance < settings.MeleeRange ^ 2 and z:ZACanMelee(enemy, settings.MeleeRange, true) then
        K.Interrupt(z, "melee"); N.Face(z, goal)
        if not z:ZACanMelee(enemy, settings.MeleeRange) and z:ZATurnTowards(goal, enemy) then return true end
        z:FaceTowards(goal)
        if CurTime() >= (z.ZANextMelee or 0) and z:ZACanMelee(enemy, settings.MeleeRange) then
            E.Melee(z, settings.Melee[1], enemy)
        end
        return true
    end
    if z.ZAGunAmmo == 0 then
        K.Interrupt(z, "reload")
        W.Reload(z)
        return true
    end
    local gun = settings.Gun
    if visible and distance >= settings.FollowFireMinRange ^ 2 and distance <= gun.Range ^ 2 then
        W.Aim(z, enemy, goal, true)
        if z.ZAGunTrigger or CurTime() >= state.NextBurst then
            state.Policy.FireAllowed = true
            if not z.ZAGunTrigger then state.BurstStarted, state.ShotSerial = true, z.ZAGunShotSerial or 0 end
            W.Request(z, enemy, goal, state.Policy)
            state.State = "follow_fire"
        else state.State = "burst_wait" end
        -- The authored armed gait and aim layers share one locomotion loop.
        -- Face() would cancel that route and restart walking on each decision.
        z:ZAMove(goal, enemy)
    else
        K.Interrupt(z, visible and "follow" or "investigate")
        z:ZAMove(goal, enemy)
    end
    return true
end
function K.Idle(z)
    if K.Flinch(z) then return true end
    K.Interrupt(z, "idle")
    -- Shared DT wandering/hearing continues below the elite decision hook.
    return false
end
