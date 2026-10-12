-- Authored masked layers live in the model; only the server drives the poses.
-- Bullets run at the weapon's cadence, never catch up a backlog after a hitch.
if SERVER then AddCSLuaFile() end
-- Existing entities retain this controller when included Lua is refreshed.
local W = ZA1.MajorGuns or {}; ZA1.MajorGuns = W
if CLIENT then return end
local M = ZA1.Manager
local function Active(z) return IsValid(z) and z:Alive() and not z.ZADeathHandled and not z.ZADowned end
local function Target(e) return IsValid(e) and (not e.Alive or e:Alive()) end
function W.PoseValue(pose, degrees, limit)
    local phase = math.Clamp(.5 + degrees * pose.PhaseSign / (2 * (limit or pose.Limit)), 0, 1)
    return pose.Min + (pose.Max - pose.Min) * phase
end
local function SetPose(z, pose, value)
    if not pose then return end
    if z.ZAGunPoses[pose.Name] == value then return end
    z.ZAGunPoses[pose.Name] = value; z:SetPoseParameter(pose.Name, value)
end
function W.Initialize(z)
    local data, settings = z.ZASpecialAssets, z.ZASpecialSettings
    z.ZAGunPoses, z.ZAGunRaise = {}, 0
    z.ZAGunAmmo = settings.Gun.InitialAmmo or settings.Gun.Magazine
    z.ZAGunNextShot, z.ZAGunNextThink, z.ZAGunLastThink = CurTime(), CurTime(), CurTime()
    z.ZAGunAimYaw, z.ZAGunAimPitch = 0, 0
    z.ZAGunShotSerial = 0
    z.ZAGunData = data.Gun
    local poses = data.Pose
    SetPose(z, poses.Yaw, W.PoseValue(poses.Yaw, 0))
    SetPose(z, poses.Pitch, W.PoseValue(poses.Pitch, 0))
    SetPose(z, poses.Raise, poses.Raise.Min)
end
function W.Stop(z)
    z.ZAGunTrigger, z.ZAGunTarget, z.ZAGunAimStarted = nil, nil, nil
    z.ZAGunReady, z.ZAGunAimReady, z.ZAGunPolicy = nil, false, nil
    if IsValid(z) then z:SetNW2Bool("za1_sniper_glint", false) end
    if z.ZAGunLoop then z.ZAGunLoop:Stop(); z.ZAGunLoop = nil end
    if z.ZAGunGesture and IsValid(z) then
        z:SetLayerWeight(z.ZAGunGesture, 0); z:SetLayerPlaybackRate(z.ZAGunGesture, 0)
    end
end
function W.Event(z, event, time, cycle, typ, options)
    if event ~= 1101 then return end
    local gun = z.ZAGunData
    if not gun then return end
    local binding = gun.GestureEvents and gun.GestureEvents[options]
    if not binding and z.ZADeathPlaying then
        local pool = z.ZASpecialAssets.Animations[z:GetSequenceName(z:GetSequence())]
        binding = pool and pool[options]
    end
    if not binding then return end
    local name = binding.Name:lower()
    -- The bullet driver owns firing audio. A native death voice is emitted
    -- at its event position so removing the actor cannot cut it short.
    local firing = z.ZASpecialAssets.Roles.fire
    if binding.Loop or firing and binding.Name == firing.Name
        or z.ZADeathPlaying and name:find("breathe", 1, true)
        or #binding.Files == 0 or not M.EventAudible(z) then return true end
    local file, gain = binding.Files[math.random(#binding.Files)], math.Rand(binding.Volume[1], binding.Volume[2])
    if z.ZADeathPlaying and (name:find("vox", 1, true) or name:find("voc_", 1, true)) then
        sound.Play(file, z:WorldSpaceCenter(), 75, 100, gain * z.VocalVolume)
        z.ZADeathVoicePending = nil
    else z:EmitSound(file, 65, 100, gain, CHAN_AUTO) end
    return true
end
local function Sound(z, role)
    local binding = z.ZASpecialAssets.Roles[role]
    if not binding or #binding.Files == 0 then return end
    local file = binding.Files[math.random(#binding.Files)]
    local gain = math.Rand(binding.Volume[1], binding.Volume[2])
    if binding.Loop then
        if not z.ZAGunLoop then
            z.ZAGunLoop = CreateSound(z, file)
            z.ZAGunLoop:SetSoundLevel(95); z.ZAGunLoop:PlayEx(gain, 100)
        end
    else z:EmitSound(file, 95, 100, gain, CHAN_WEAPON) end
end
function W.Fire(z, goal)
    if not Active(z) or z.ZAGunAmmo <= 0 then return false end
    local gun, settings = z.ZAGunData, z.ZASpecialSettings.Gun
    local attachment = z:GetAttachment(z:LookupAttachment(gun.Bullet))
    if not attachment then return false end
    local direction = (goal - attachment.Pos):GetNormalized()
    z:FireBullets({Num = 1, Src = attachment.Pos, Dir = direction,
        Spread = Vector(settings.Spread, settings.Spread, 0), Tracer = 1,
        Force = 3, Damage = settings.Damage, Attacker = z, IgnoreEntity = z,
        Callback = z.ZAGunPolicy and z.ZAGunPolicy.Callback})
    z.ZAGunAmmo = z.ZAGunAmmo - 1
    z.ZAGunShotSerial = (z.ZAGunShotSerial or 0) + 1
    z.ZAGunLastShot = CurTime()
    z.ZAGunNextShot = CurTime() + (gun.NativeShotTime or settings.Interval)
    Sound(z, "fire")
    if gun.FireGesture and z:LookupSequence(gun.FireGesture) >= 0 then
        local id = z:LookupSequence(gun.FireGesture)
        -- Reuse one layer. Removing/reallocating it every shot would overlap
        -- deferred layer removal at the MG's sustained firing cadence.
        local layer = z:FindGestureSequenceLayer(id)
        if layer == -1 then layer = z:AddGestureSequence(id, false) end
        if layer ~= -1 then
            z:SetLayerCycle(layer, 0); z:SetLayerWeight(layer, 1); z:SetLayerPlaybackRate(layer, 1)
            z.ZAGunGesture, z.ZAGunGestureUntil = layer, CurTime() + z:SequenceDuration(id)
        end
    end
    local muzzleID = z:LookupAttachment(gun.Muzzle)
    local muzzle = muzzleID and muzzleID > 0 and z:GetAttachment(muzzleID)
    ZA1.Feedback.Muzzle(z, muzzle and muzzle.Pos or attachment.Pos, muzzle and muzzle.Ang or attachment.Ang,
        muzzle and muzzleID or 0, z.ZASpecial == "mg42" and "mp40" or "luger")
    if settings.ChamberAfterShot then z.ZAGunNeedsChamber = true end
    return true
end
-- Enemy controllers can keep an authored ready stance through a firing wait.
-- Refreshing that wait must not restart its aim clock or create a new burst.
function W.Aim(z, enemy, goal, ready)
    if not ready then W.Stop(z); return end
    if not z.ZAGunReady or z.ZAGunTarget ~= enemy then z.ZAGunAimStarted = CurTime() end
    z.ZAGunReady, z.ZAGunTarget, z.ZAGunGoal = true, enemy, goal
    z.ZAGunReadyUntil = CurTime() + .8
end
function W.Request(z, enemy, goal, policy)
    if not z.ZAGunTrigger then
        local s = z.ZASpecialSettings.Gun
        if policy and policy.Continuous then z.ZAGunBurst = nil
        else z.ZAGunBurst = policy and policy.Burst or math.random(s.BurstMin, s.BurstMax) end
        if not policy then z.ZAGunAimStarted = CurTime() end
    end
    W.Aim(z, enemy, goal, true)
    z.ZAGunPolicy = policy
    z.ZAGunTrigger, z.ZAGunTarget, z.ZAGunGoal = true, enemy, goal
    z.ZAGunTriggerUntil = CurTime() + .8
end
function W.Reload(z)
    if not Active(z) or z.ZAGunReloading then return false end
    local gun = z.ZAGunData
    W.Stop(z); z.ZAGunReloading = true
    for _, clip in ipairs({gun.ReloadInto or false, gun.ReloadLoop or false, gun.ReloadOut or false}) do
        if clip and z:LookupSequence(clip) >= 0 then
            if not ZA1.Elites.Play(z, clip) then z.ZAGunReloading = nil; return true end
        end
    end
    if Active(z) then z.ZAGunAmmo = z.ZASpecialSettings.Gun.Magazine; z.ZAGunNeedsChamber = nil end
    z.ZAGunReloading = nil
    return true
end
function W.Chamber(z)
    if not z.ZAGunNeedsChamber then return false end
    W.Stop(z); z.ZAGunNeedsChamber = nil
    if z.ZAGunAmmo == 0 then return false end
    if z.ZAGunData.Chamber then ZA1.Elites.Play(z, z.ZAGunData.Chamber) end
    return true
end
function W.HitSide(z, info, tr)
    local attacker = info:GetAttacker()
    local origin = tr and tr.StartPos or IsValid(attacker) and attacker:GetPos() or info:GetDamagePosition()
    local from = origin - z:GetPos()
    local front, right = from:Dot(z:GetForward()), from:Dot(z:GetRight())
    return math.abs(front) >= math.abs(right) and (front >= 0 and "Front" or "Back") or (right >= 0 and "Right" or "Left")
end
function W.Flinch(z, info, tr)
    if not Active(z) or z.ZAActing or z:IsAIDisabled() or z:IsPossessed()
        or info:GetDamage() >= z:Health() or info:GetDamage() < ZA1.Config.Flinch.MinDamage
        or CurTime() < (z.ZANextFlinch or 0) then return end
    local bank = z.ZAGunData.Flinch
    if not bank then return end
    local group = tr and tr.HitGroup
    local region = group == HITGROUP_HEAD and "Head" or (group == HITGROUP_LEFTARM or group == HITGROUP_RIGHTARM) and "Arms"
        or (group == HITGROUP_LEFTLEG or group == HITGROUP_RIGHTLEG) and "Legs" or "Torso"
    local sequence = bank[region][W.HitSide(z, info, tr)]
    z.ZANextFlinch = CurTime() + z.ZASpecialSettings.FlinchCooldown
    ZA1.Sniper.Interrupt(z)
    -- These composed RF injuries are standing actions. Use the owned exit
    -- before playing one; its action state/cooldown prevents reentry.
    if not ZA1.Sniper.SetPosture(z, "Standing") then return true end
    if not Active(z) or z.ZADowned then return true end
    ZA1.Elites.Play(z, sequence)
    return true
end
function W.Tick(z)
    local now = CurTime()
    if now < z.ZAGunNextThink then return end
    local settings, poses = z.ZASpecialSettings.Gun, z.ZASpecialAssets.Pose
    local dt = math.min(.1, now - z.ZAGunLastThink)
    z.ZAGunLastThink, z.ZAGunNextThink = now, now + settings.Tick
    if z.ZAGunGesture and now >= (z.ZAGunGestureUntil or 0) then
        z:SetLayerWeight(z.ZAGunGesture, 0); z:SetLayerPlaybackRate(z.ZAGunGesture, 0)
    end
    local controls = z:GetPossessionControls()
    local possessed = IsValid(controls)
    local enabled = Active(z) and not z:IsAIDisabled() and not z.ZAActing and not z.ZAPainPending and not z.ZAGunReloading
        and not z.ZAGunNeedsChamber and z.ZAGunReady and now <= (z.ZAGunReadyUntil or 0)
    local goal, policy = z.ZAGunGoal, z.ZAGunPolicy
    if enabled and possessed then
        enabled = controls:KeyDown(IN_ATTACK)
        if enabled then goal = controls:TraceLine().HitPos end
    elseif enabled then
        local visible = z.ZAEnemyVisible or policy and policy.AllowUnseen and policy.AllowUnseen(z, z.ZAGunTarget)
        enabled = Target(z.ZAGunTarget) and z:GetEnemy() == z.ZAGunTarget and visible
        if enabled then goal = z.ZAGunTarget:WorldSpaceCenter() end
    end
    if enabled and not possessed and policy and policy.AimGoal then goal = policy.AimGoal(z, goal) or goal end
    local yaw, pitch = 0, 0
    if enabled and goal then
        local angles = (goal - z:WorldSpaceCenter()):Angle()
        yaw, pitch = math.AngleDifference(angles.y, z:GetAngles().y), math.NormalizeAngle(angles.p)
    end
    local yawLimit = z:GetVelocity():Length2D() > 2 and poses.WalkYaw and poses.WalkYaw.Limit or poses.Yaw.Limit
    local pitchLimit = poses.Pitch.Limit
    local desiredYaw, desiredPitch = math.Clamp(yaw, -yawLimit, yawLimit), math.Clamp(pitch, -pitchLimit, pitchLimit)
    z.ZAGunAimYaw = possessed and desiredYaw or math.Approach(z.ZAGunAimYaw, desiredYaw, 2 * yawLimit * settings.AimPhaseRate * dt)
    z.ZAGunAimPitch = possessed and desiredPitch or math.Approach(z.ZAGunAimPitch, desiredPitch, 2 * pitchLimit * settings.AimPhaseRate * dt)
    z.ZAGunRaise = math.Approach(z.ZAGunRaise, enabled and 1 or 0, (poses.Raise.NativeRate or settings.RaiseRate) * dt)
    SetPose(z, poses.Yaw, W.PoseValue(poses.Yaw, z.ZAGunAimYaw, yawLimit))
    SetPose(z, poses.Pitch, W.PoseValue(poses.Pitch, z.ZAGunAimPitch))
    SetPose(z, poses.Raise, poses.Raise.Min + (poses.Raise.Max - poses.Raise.Min) * z.ZAGunRaise)
    local aiming = enabled and goal and z.ZAGunRaise >= .95
        and math.abs(yaw) <= yawLimit and math.abs(pitch) <= pitchLimit
        and math.abs(yaw - z.ZAGunAimYaw) <= settings.AimTolerance
        and math.abs(pitch - z.ZAGunAimPitch) <= settings.AimTolerance
    z:SetNW2Bool("za1_sniper_glint", z.ZASpecial == "sniper" and aiming
        and (possessed or now <= (z.ZASniperGlintUntil or 0)) or false)
    local ready = possessed or now - (z.ZAGunAimStarted or now) >= settings.AimTime
    z.ZAGunAimReady = aiming and ready or false
    local firing = z.ZAGunAimReady and z.ZAGunTrigger and now <= (z.ZAGunTriggerUntil or 0)
        and (not policy or policy.FireAllowed ~= false)
    local discharged = false
    if firing and now >= z.ZAGunNextShot then
        local shotGoal = policy and policy.ShotGoal and policy.ShotGoal(z, goal) or goal
        discharged = W.Fire(z, shotGoal)
    end
    if discharged then
        if not possessed and not (policy and policy.Continuous) then
            z.ZAGunBurst = z.ZAGunBurst - 1
            if z.ZAGunBurst <= 0 then
                z.ZAGunNextShot = math.max(z.ZAGunNextShot, now + settings.BurstPause)
                z.ZAGunTrigger = nil
                if not policy then z.ZAGunReady = nil end
            end
        end
    end
    if not firing and z.ZAGunLoop then
        z.ZAGunLoop:Stop(); z.ZAGunLoop = nil; Sound(z, "fire_stop")
    end
    if not enabled then
        W.Stop(z)
    end
end
