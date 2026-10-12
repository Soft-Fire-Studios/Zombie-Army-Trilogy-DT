-- Scoped FireWeapon and Sniper_Default policy. Scene-authored sniper points
-- and special jump links are translated to bounded, collision-tested nav areas.
-- Native consumers/resources and the remaining limits are recorded in audit/
-- sniper-controller-report.json. Geometry budgets are Source adaptations.
if SERVER then AddCSLuaFile() end
local J = ZA1.Sniper or {}; ZA1.Sniper = J
J.Try = nil -- The controller now owns relocation and firing as one decision.
function J.GlintAlpha(dot)
    local angle = math.deg(math.acos(math.Clamp(dot, -1, 1)))
    if angle > 20 then return 0 end
    if angle > 5 then return .25 + .35 * (20 - angle) / 15 end
    return math.min(.83, .6 + .4 * (5 - angle) / 5)
end
if CLIENT then
    local glow = Material("sprites/light_glow02_add")
    function J.Draw(z)
        if not z:GetNW2Bool("za1_sniper_glint", false) then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:EyePos():DistToSqr(z:GetPos()) > ZA1.SpecialConfig.sniper.SightRange ^ 2 then return end
        local gun = ZA1.MajorAssets.Enemies.sniper.Gun
        local attachment = z:GetAttachment(z:LookupAttachment(gun.Muzzle))
        if not attachment then return end
        local dot = attachment.Ang:Forward():Dot((ply:EyePos() - attachment.Pos):GetNormalized())
        -- Native glint: 20-degree outside cone, 5-degree inner cone. Its
        -- brightness curve is retained; sprite size/range are Source choices.
        local alpha = J.GlintAlpha(dot)
        if alpha <= 0 then return end
        render.SetMaterial(glow)
        render.DrawSprite(attachment.Pos, 9, 9, Color(255, 230, 170, math.floor(alpha * 255)))
    end
    return
end
local N, O, P, W = ZA1.Navigation, ZA1.Obstacles, ZA1.Population, ZA1.MajorGuns
local metre = 39.37007874
local voices = include("za1/sniper_voice_assets.lua")
-- Actor-owned dialogue roles are separate from HCAN foley/voice events.
-- Contact, warning and bullet results provide Source cues. Shared dialogue
-- deadlines prevent them from interrupting either those events or one another.
function J.PlayVoice(z, role, corpse)
    if not IsValid(z) or z.ZASpecial ~= "sniper" or z.ZAHeadDestroyed then return false end
    if corpse then
        if not IsValid(corpse) or z.ZASniperDeathVoice then return false end
    elseif not z:Alive() or z.ZADeathHandled or z:IsAIDisabled() or z:IsPossessed() then return false end
    local now = CurTime()
    if not corpse and now < math.max(z.ZADialogueUntil or 0, z.ZAVocalUntil or 0) then return false end
    local binding = voices.Roles[role]
    if not binding or #binding.Files == 0 then return false end
    local file = binding.Files[math.random(#binding.Files)]
    local emitter = corpse or z
    emitter:EmitSound(file, 75, 100, z.VocalVolume, CHAN_VOICE)
    if corpse then z.ZASniperDeathVoice = true
    else
        z.ZADialogueSound = file
        z.ZADialogueUntil = now + voices.Durations[file] + .02
    end
    return true
end
function J.ShotResult(z, trace, info)
    local s = IsValid(z) and z.ZASniperState
    if not s or z.ZAGunPolicy ~= s.policy then return end
    s.shotHit = IsValid(s.enemy) and trace.Entity == s.enemy and info:GetDamage() > 0
end
-- Preserve reservations through a Lua refresh, but never hold a removed actor.
J.PointOwners = J.PointOwners or setmetatable({}, {__mode = "v"})
J.Grenades = J.Grenades or setmetatable({}, {__mode = "k"})
if J.JumpActors and J.Clear then
    for z in pairs(J.JumpActors) do if IsValid(z) then J.Clear(z) end end
end
-- Private point planning never creates a shared horde goal flow. One queue
-- advances all Deadeyes within a single work/deadline budget.
J.Plans, J.PlanOrder, J.PlanCursor = setmetatable({}, {__mode = "k"}), {}, 1
J.PlanQueued = setmetatable({}, {__mode = "k"})
J.JumpActors = setmetatable({}, {__mode = "k"})
J.Stats = {plannerMS = 0, scanWork = 0, nodes = 0, edges = 0, candidates = 0,
    jumpSegments = 0, pointFailures = 0, landed = 0, blocked = 0, cancelled = 0}
local grenadeClasses = {npc_grenade_frag = true, grenade_ar2 = true}
function J.ObserveGrenade(entity)
    -- Other weapon packs can register a live grenade without adding per-actor
    -- entity searches. These two automatic classes are Source equivalents.
    if IsValid(entity) then J.Grenades[entity] = true end
end
hook.Add("OnEntityCreated", "ZA1.Sniper.Grenades", function(entity)
    if IsValid(entity) and grenadeClasses[entity:GetClass()] then J.ObserveGrenade(entity) end
end)
local function Active(z)
    return IsValid(z) and z:Alive() and not z.ZADeathHandled and not z.ZADowned
        and not z:IsAIDisabled() and not z:IsPossessed()
end
function J.SetPosture(z, name, immediate)
    if not IsValid(z) or not z.ZAGunData then return false end
    local s, base = z.ZASniperState or J.Initialize(z), z.ZASpecialAssets.Gun
    local postures = base.Postures
    if not postures or not postures[name] then return name == "Standing" end
    if immediate then s.postureSerial = (s.postureSerial or 0) + 1; s.postureChanging = nil end
    if s.postureChanging then return false end
    if s.posture == name and z.ZAGunBase == base then return true end
    local previous = s.posture or "Standing"
    if not immediate and previous ~= name then
        J.Interrupt(z)
        local transition = name == "Kneeling" and postures.Kneeling.Enter or previous == "Kneeling" and postures.Kneeling.Exit
        if transition then
            if z:LookupSequence(transition) < 0 then return false end
            s.postureChanging = true
            local serial = (s.postureSerial or 0) + 1; s.postureSerial = serial
            local completed = ZA1.Elites.Play(z, transition)
            if serial ~= s.postureSerial then return false end
            s.postureChanging = nil
            if not completed then return false end
        end
        if not Active(z) then return false end
    end
    local stance = postures[name]
    local cached = z.ZAGunStances
    if not cached or cached.base ~= base then cached = {base = base}; z.ZAGunStances = cached end
    if not cached[name] then
        local gun = {}; for key, value in pairs(base) do gun[key] = value end
        for _, key in ipairs({"FireGesture", "Chamber"}) do if stance[key] then gun[key] = stance[key] end end
        if stance.Reload then gun.ReloadInto = stance.Reload end
        cached[name] = {gun = gun, turns = name == "Kneeling" and stance.TurnLeft and stance.TurnRight
            and {Left = {[90] = {stance.TurnLeft}}, Right = {[90] = {stance.TurnRight}}} or z.ZASpecialSettings.Turn}
    end
    z.ZAGunData = cached[name].gun
    z.ZAGunBase = base
    z.IdleAnimation = stance.Idle or postures.Standing.Idle
    z.WalkAnimation = postures.Standing.Walk or z.WalkAnimation
    z.RunAnimation = z.WalkAnimation
    z.ZATurnAnimations = cached[name].turns
    s.posture = name
    return true
end
local function Enemy(e) return IsValid(e) and (not e.Alive or e:Alive()) end
local function ReleasePoint(z)
    local s = z.ZASniperState
    if not s or not s.point then return end
    if J.PointOwners[s.point.id] == z then J.PointOwners[s.point.id] = nil end
    s.point, s.pointActive, s.pointShots = nil, false, nil
end
local function CaptureShot(z, s)
    local serial = z.ZAGunShotSerial or 0
    if serial == s.serial then return end
    local settings = z.ZASpecialSettings.Gun
    s.serial, s.pendingShot = serial, nil
    -- FireBullets completes its callback before the shot serial advances.
    -- Keep one latest result while an existing vocal finishes; never replay
    -- missed Think ticks or queue a taunt for every frame of the firing wait.
    if not z:IsPossessed() then s.shotVoice = s.shotHit and "target_hit" or "target_miss" end
    s.shotHit = nil
    if s.consumeMiss and s.initialMisses > 0 then s.initialMisses = s.initialMisses - 1 end
    s.consumeMiss = nil
    if s.pointActive and s.pointShots then s.pointShots = math.max(0, s.pointShots - 1) end
    -- The original waits for weapon state Ready. Completion of the exported
    -- firing layer is the Source equivalent, rather than an extra chamber clip.
    s.readyAt = math.max(z.ZAGunLastShot or CurTime(), z.ZAGunGestureUntil or 0)
    s.waitUntil = s.readyAt + settings.PostShotWait
    z.ZAGunNextShot = math.max(z.ZAGunNextShot or 0, s.waitUntil)
    s.policy.FireAllowed = false
    s.mode = "shot_wait"
    z.ZASniperGlintUntil = nil
end
function J.Initialize(z)
    -- Existing actors keep their shot progress on include refresh while using
    -- the current settings and callback functions.
    if ZA1.SpecialConfig and ZA1.SpecialConfig.sniper then z.ZASpecialSettings = ZA1.SpecialConfig.sniper end
    local sightRange = z.ZASpecialSettings.SightRange
    if z.ZASniperSightRange ~= sightRange then
        z.SightRange, z.ZASniperSightRange = sightRange, sightRange
        z:SetMaxVisionRange(sightRange)
        z.ZANextSight = 0
    end
    local s = z.ZASniperState or {serial = z.ZAGunShotSerial or 0, waitUntil = 0,
        initialMisses = z.ZASpecialSettings.Gun.InitialMisses, mode = "idle"}
    s.nextGlint = s.nextGlint or CurTime() + math.Rand(.3, 1) * z.ZASpecialSettings.Gun.GlintInterval
    s.policy = s.policy or {Burst = 1, FireAllowed = false}
    s.policy.Callback = J.ShotResult
    s.policy.ShotGoal, s.policy.AimGoal, s.policy.AllowUnseen = J.ShotGoal, J.AimGoal, J.AllowUnseen
    z.ZASniperState = s
    if not J.GrenadesSeeded then
        J.GrenadesSeeded = true
        for class in pairs(grenadeClasses) do
            for _, entity in ipairs(ents.FindByClass(class)) do J.ObserveGrenade(entity) end
        end
    end
    return s
end
function J.Interrupt(z)
    local s = z.ZASniperState
    if s then
        CaptureShot(z, s)
        s.enemy, s.goal, s.refreshed, s.warningUntil = nil, nil, nil, nil
        s.qualified, s.pendingShot, s.consumeMiss = nil, nil, nil
        s.hidden = nil; s.policy.AllowUnseen = J.AllowUnseen
        s.policy.FireAllowed = false; s.mode = "idle"
    end
    z.ZASniperGlintUntil = nil
    W.Stop(z)
end
local function RestoreJump(z)
    if z.ZASniperGravity ~= nil and IsValid(z) then z.loco:SetGravity(z.ZASniperGravity) end
    if z.ZASniperJump then
        z.ZAActing = false
        if IsValid(z) and z:Alive() and not z.ZADowned then z:ResetAnimState() end
    end
    z.ZASniperGravity, z.ZASniperJump = nil, nil
    J.JumpActors[z] = nil
end
function J.Clear(z)
    J.Interrupt(z); ReleasePoint(z)
    J.Plans[z] = nil
    RestoreJump(z); z.ZAPerchScan = nil
    local s = z.ZASniperState
    if s then
        s.grenade, s.grenadeGoal, s.evading, s.postureChanging = nil, nil, nil, nil
        s.shotVoice, s.shotHit, s.voiceTarget = nil, nil, nil
        s.postureSerial = (s.postureSerial or 0) + 1
    end
    if J.SetPosture then J.SetPosture(z, "Standing", true) end
end
function J.Damage(z, info)
    local attacker = info:GetAttacker()
    if Active(z) and info:GetDamage() > 0 and info:GetDamage() < z:Health() then J.PlayVoice(z, "pain") end
    if Active(z) and info:GetDamage() > 0 and IsValid(attacker) and attacker:IsPlayer() then
        -- Original scoped player-damage flag forces a point change, even if
        -- damage did not select a flinch. Source damage templates differ.
        J.Initialize(z).forceRelocate = true
    end
end
function J.HitChance(settings, distance)
    local samples = settings.AccuracyCurve
    local index = math.Clamp(distance / settings.AccuracyDistance, 0, 1) * (#samples - 1)
    local lower = math.floor(index) + 1
    local weight = index - math.floor(index)
    local value = samples[lower] * (1 - weight) + samples[math.min(#samples, lower + 1)] * weight
    return math.Clamp(settings.HitChance * value, 0, 100)
end
function J.AimGoal(z, goal)
    local s = z.ZASniperState
    local enemy = s and s.enemy
    -- Native 7CD640/7BBD90 uses the authored "eyes" role, with actor-height
    -- fallback. EyePos is the Source entity's equivalent target anchor.
    if s and s.hidden then
        if s.lastSeenEnemy == enemy then return s.lastSeenEye or s.goal or goal end
        return goal
    end
    return Enemy(enemy) and enemy.EyePos and enemy:EyePos() or goal
end
function J.AllowUnseen(z, enemy)
    local s = z.ZASniperState
    return Active(z) and s and s.enemy == enemy and s.lastSeenEnemy == enemy and s.hidden and s.pointActive
        and CurTime() - (s.lastSeen or -math.huge) <= z.ZASpecialSettings.LostSightGrace
        and not s.evading or false
end
local function MissGoal(z, enemy, goal, s)
    local g, now = z.ZASpecialSettings.Gun, CurTime()
    local attachment = z:GetAttachment(z:LookupAttachment(z.ZAGunData.Bullet))
    if not attachment then return goal end -- Failure must not spend the pending miss.
    local radius, muzzle = g.MissRadius, attachment.Pos
    local propChance = s.hidden and g.UnseenMissPropChance or g.MissPropChance
    local propCooldown = s.hidden and g.UnseenMissPropCooldown or g.MissPropCooldown
    if now >= (s.nextPropMiss or 0) and math.Rand(0, 100) < propChance then
        -- Native destructible-prop search is capped at six candidates. Source
        -- physics props provide the corresponding nearby environmental targets.
        local extent = Vector(radius, radius, radius)
        local props = ents.FindInBox(goal - extent, goal + extent)
        local checked = 0
        for _, prop in ipairs(props) do
            if IsValid(prop) and prop ~= z and prop ~= enemy and prop:GetClass():sub(1, 5) == "prop_" then
                checked = checked + 1
                local point = prop:WorldSpaceCenter()
                local tr = util.TraceLine({start = muzzle, endpos = point, mask = MASK_SHOT, filter = z})
                if not tr.Hit or tr.Entity == prop then s.nextPropMiss = now + propCooldown; return point end
                if checked == 6 then break end
            end
        end
    end
    if math.Rand(0, 100) < g.MissWorldChance then
        for _ = 1, 10 do
            local point = goal + Vector(math.Rand(-radius, radius), math.Rand(-radius, radius), math.Rand(-radius, radius))
            local tr = util.TraceLine({start = muzzle, endpos = point, mask = MASK_SHOT, filter = z})
            if tr.HitWorld and not tr.StartSolid and not tr.AllSolid then return tr.HitPos end
        end
    end
    if enemy:IsPlayer() then
        -- Original human miss fallback: down .8m and each horizontal axis
        -- within .4m. This is a miss selection, not a promise of zero injury.
        return goal + Vector(math.Rand(-.4, .4) * metre, math.Rand(-.4, .4) * metre, -.8 * metre)
    end
    local angle = math.Rand(0, math.pi * 2)
    return goal + Vector(math.cos(angle) * metre, math.sin(angle) * metre, 0)
end
function J.ShotGoal(z, goal)
    local s = z.ZASniperState
    if not s or not Enemy(s.enemy) then return goal end
    if s.hidden and s.lastSeenEnemy ~= s.enemy then return goal end
    -- A missing attachment can cancel W.Fire. Reuse the chosen shot until the
    -- actual successful serial changes, rather than rerolling its probability.
    if s.pendingShot then return s.pendingShot end
    if not z:GetAttachment(z:LookupAttachment(z.ZAGunData.Bullet)) then return goal end
    local location = s.hidden and (s.lastSeenGoal or goal) or s.enemy:GetPos()
    local g, distance = z.ZASpecialSettings.Gun, z:GetPos():Distance(location)
    local forced = distance >= g.InitialMissRange and s.initialMisses > 0
    if distance < g.InitialMissRange then s.initialMisses = 0 end
    local miss = s.hidden or forced or math.Rand(0, 100) >= J.HitChance(g, distance)
    s.consumeMiss = forced
    s.pendingShot = miss and MissGoal(z, s.enemy, goal, s) or goal
    return s.pendingShot
end
function J.GlintEligible(z)
    local muzzle = z:GetAttachment(z:LookupAttachment(z.ZAGunData.Muzzle))
    if not muzzle then return false end
    for _, observer in ipairs(player.GetAll()) do
        if IsValid(observer) and observer:Alive() then
            local direction = (observer:EyePos() - muzzle.Pos):GetNormalized()
            -- Native qualification uses both observer and weapon view cones.
            if observer:EyeAngles():Forward():Dot(-direction) >= .906307787
                and muzzle.Ang:Forward():Dot(direction) >= .939692974 then return true end
        end
    end
    return false
end
local function Glint(z, s, now)
    local gun = z.ZASpecialSettings.Gun
    z.ZASniperGlintUntil = now + gun.GlintDuration
    s.nextGlint = now + gun.GlintInterval
end
function J.CheckGrenade(z, s)
    local now, settings = CurTime(), z.ZASpecialSettings
    -- Native core407 retains its selected grenade until that projectile ends;
    -- moving behind cover after perception must not cancel the reaction.
    if IsValid(s.grenade) and J.Grenades[s.grenade] then s.evading = true; return true end
    if now < (s.grenadeCheck or 0) then return s.evading and IsValid(s.grenade) end
    s.grenadeCheck = now + settings.GrenadeScanInterval
    local nearest, distance = nil, settings.GrenadeRange ^ 2
    local origin, checked = z:GetPos(), 0
    for grenade in pairs(J.Grenades) do
        if IsValid(grenade) then
            local square = origin:DistToSqr(grenade:GetPos())
            if square < distance then
                checked = checked + 1
                local trace = util.TraceLine({start = z:WorldSpaceCenter(), endpos = grenade:WorldSpaceCenter(),
                    mask = MASK_SHOT, filter = {z, grenade}})
                if not trace.Hit and not trace.StartSolid and not trace.AllSolid then nearest, distance = grenade, square end
                if checked >= 12 then break end -- Source perception budget, not an original AI value.
            end
        else J.Grenades[grenade] = nil end
    end
    if nearest ~= s.grenade then
        if s.evading or nearest then J.Interrupt(z); N.Cancel(z) end
        if nearest then ReleasePoint(z) end
        s.grenade, s.grenadeGoal, s.grenadeOrigin, s.grenadeHolding = nearest, nil, nil, nil
    end
    s.evading = nearest ~= nil
    return s.evading
end
function J.GrenadeEscape(z, grenade)
    local origin, danger = z:GetPos(), grenade:GetPos()
    local away = origin - danger; away.z = 0
    if away:Length2D() < 1 then away = -z:GetForward() end
    away = away:GetNormalized()
    local distance = math.max(z.Width * 2, z.ZASpecialSettings.GrenadeRange - origin:Distance(danger) + z.Width * 2)
    for _, angle in ipairs({0, -45, 45, -90, 90, 180}) do
        local direction = Vector(away); direction:Rotate(Angle(0, angle, 0))
        local point = P.ClearGround(origin + direction * distance, z, z.ZANavProfile)
        if point and point:DistToSqr(danger) > origin:DistToSqr(danger) + z.Width ^ 2 then
            if navmesh.IsLoaded() then
                local area = N.Area(point)
                if IsValid(area) and area:Contains(point) and N.Reachable(N.Area(origin), point, z.ZANavProfile) ~= false then return point end
            else
                local trace = O.Sweep(z, origin, point)
                if not trace.Hit and not trace.StartSolid and not trace.AllSolid then return point end
            end
        end
    end
end
function J.ReactGrenade(z)
    local s = z.ZASniperState or J.Initialize(z)
    if not J.CheckGrenade(z, s) then return false end
    J.Plans[z] = nil
    if not J.SetPosture(z, "Standing") then return true end
    J.Interrupt(z); s.mode = "grenade_avoid"
    -- Native core407 inserts a constrained Move action within15m. Source
    -- uses the existing nav/obstacle mover and does not borrow a human panic clip.
    local origin = s.grenade:GetPos()
    if z:GetPos():DistToSqr(origin) >= z.ZASpecialSettings.GrenadeRange ^ 2
        and (not s.grenadeGoal or z:GetPos():DistToSqr(s.grenadeGoal) < z.Width ^ 2) then
        if not s.grenadeHolding then N.Cancel(z); s.grenadeHolding = true end
        s.mode = "grenade_hold"; N.Face(z, origin); return true
    end
    s.grenadeHolding = nil
    if not s.grenadeGoal or not s.grenadeOrigin or origin:DistToSqr(s.grenadeOrigin) > z.Width ^ 2
        or z:GetPos():DistToSqr(s.grenadeGoal) < z.Width ^ 2 then
        s.grenadeGoal, s.grenadeOrigin = J.GrenadeEscape(z, s.grenade), Vector(origin)
    end
    if s.grenadeGoal then z:ZAMove(s.grenadeGoal) else N.Face(z, origin) end
    return true
end
function J.Tick(z)
    local s = J.Initialize(z)
    CaptureShot(z, s)
    if z:IsPossessed() then
        -- Release AI planning without touching the player's trigger policy.
        J.Plans[z] = nil; ReleasePoint(z)
        RestoreJump(z)
        J.SetPosture(z, "Standing", true)
        s.shotVoice, s.shotHit = nil, nil
        return
    end
    if not Active(z) then J.Clear(z); return end
    if not z.ZAActing then
        if s.shotVoice and J.PlayVoice(z, s.shotVoice) then s.shotVoice = nil end
        local contact = z:GetEnemy()
        if Enemy(contact) and z.ZAEnemyVisible and s.voiceTarget ~= contact
            and J.PlayVoice(z, "alert") then s.voiceTarget = contact end
    end
    if s.fallbackStanding and s.posture == "Kneeling" then
        s.policy.FireAllowed = false; W.Stop(z); return
    end
    local now = CurTime()
    if Active(z) and not z.ZAActing and not z.ZAPainPending and J.CheckGrenade(z, s) then
        J.Interrupt(z); s.mode = "grenade_avoid"; return
    end
    local valid = Active(z) and not z.ZAActing and not z.ZAPainPending and not z.ZAGunReloading
        and Enemy(s.enemy) and z:GetEnemy() == s.enemy and (z.ZAEnemyVisible or J.AllowUnseen(z, s.enemy))
        and s.refreshed and now - s.refreshed <= .8
    if not valid then
        if s.enemy then J.Interrupt(z) else z:SetNW2Bool("za1_sniper_glint", false) end
        return
    end
    if z.ZAGunAimReady and now >= s.waitUntil and not s.qualified and not s.warningUntil then
        s.warningUntil = now + z.ZASpecialSettings.Gun.Telegraph
        J.PlayVoice(z, "target_in_sights")
        Glint(z, s, now)
        s.mode = "warning"
    end
    if s.warningUntil and now >= s.warningUntil then s.warningUntil, s.qualified = nil, true end
    local permitted = s.qualified and now >= s.waitUntil and z.ZAGunAmmo > 0
        and (not s.pointActive or not s.pointShots or s.pointShots > 0)
    s.policy.FireAllowed = permitted and true or false
    if z.ZAGunAimReady and now >= s.nextGlint and J.GlintEligible(z) then Glint(z, s, now) end
    z:SetNW2Bool("za1_sniper_glint", z.ZAGunAimReady and now <= (z.ZASniperGlintUntil or 0) or false)
    if permitted then
        s.mode = "firing"
        W.Request(z, s.enemy, s.goal, s.policy)
    elseif s.mode ~= "warning" then s.mode = s.qualified and "shot_wait" or "aiming" end
end
function J.Position(plan, time)
    local settle = plan.clip.Duration * plan.clip.SettleFraction
    local u = math.Clamp(time / settle, 0, 1)
    if u == 1 then return plan.landing end
    local motion = ZA1.Traversal.Sample(plan.clip, time)
    local endMotion = ZA1.Traversal.Sample(plan.clip, settle)
    local residual = (motion - endMotion * u) * plan.scale
    residual:Rotate(plan.angles)
    return plan.start + (plan.landing - plan.start) * u + residual
end
function J.Corridor(z, plan)
    local previous, segments = plan.start, z.ZASpecialSettings.Jump.Segments
    for i = 1, segments do
        local point = J.Position(plan, plan.clip.Duration * plan.clip.SettleFraction * i / segments)
        local tr = O.Sweep(z, previous, point)
        if tr.Hit or tr.StartSolid or tr.AllSolid then return false end
        previous = point
    end
    return true
end
local function Sight(z, point, enemy, eye, height)
    if not enemy then return true end
    local tr = util.TraceLine({start = point + Vector(0, 0, height or 1.6 * metre), endpos = eye,
        mask = MASK_SHOT, filter = {z, enemy}})
    return not tr.Hit and not tr.StartSolid and not tr.AllSolid
end
local function FiringPosture(z, point, enemy, eye)
    -- Original point poses test prone(.5m), kneeling(1.3m), then standing
    -- (1.6m). This Source pack implements the latter two owned stances.
    local postures = z.ZASpecialAssets.Gun.Postures
    if postures and postures.Kneeling and Sight(z, point, enemy, eye, 1.3 * metre) then return "Kneeling" end
    if Sight(z, point, enemy, eye, 1.6 * metre) then return "Standing" end
end
local refreshedSettings
local function PointSettings(z)
    if not z.ZASpecialSettings.Point.TargetHeightMin then
        -- Migrate live actors when the old walk-to-launch planner is refreshed.
        refreshedSettings = refreshedSettings or include("za1/major_settings.lua").sniper
        z.ZASpecialSettings.Point = table.Copy(refreshedSettings.Point)
        z.ZASpecialSettings.Jump = table.Copy(refreshedSettings.Jump)
    end
    return z.ZASpecialSettings.Point
end
local function SettingsKey(settings, jump)
    return settings.SearchRadius .. "/" .. settings.TargetMinDistance .. "/" .. settings.TargetPreferredDistance
        .. "/" .. settings.TargetMaxDistance .. "/" .. tostring(settings.PreferHigherThanTarget)
        .. "/" .. settings.TargetHeightMin .. "/" .. settings.TargetHeightMax
        .. "/" .. jump.SearchRadius .. "/" .. jump.MinDistance .. "/" .. jump.MaxRise .. "/" .. jump.MaxDrop
end
local function Open(z, area)
    return IsValid(area) and not area:IsBlocked() and not area:IsUnderwater()
        and bit.band(area:GetAttributes(), NAV_MESH_CROUCH) == 0 and z.loco:IsAreaTraversable(area)
end
local function KnownTarget(z, enemy)
    if not Enemy(enemy) then return end
    local s, goal, visible = z.ZASniperState, z:ZAEnemyGoal(enemy)
    if not goal then return end
    -- The selector must not learn a hidden target's current location or eyes.
    if visible then return Vector(goal), enemy.EyePos and enemy:EyePos() or enemy:WorldSpaceCenter() end
    if s.lastSeenEnemy == enemy then return Vector(goal), s.lastSeenEye or goal + Vector(0, 0, 68) end
end
local function FailPoint(z, id)
    if not id then return end
    local s, settings = z.ZASniperState, PointSettings(z)
    s.failures, s.failureOrder = s.failures or {}, s.failureOrder or {}
    if not s.failures[id] then
        if #s.failureOrder >= settings.FailureLimit then s.failures[table.remove(s.failureOrder, 1)] = nil end
        s.failureOrder[#s.failureOrder + 1] = id
    end
    s.failures[id] = {untilTime = CurTime() + settings.FailureCooldown, generation = N.Generation}
    J.Stats.pointFailures = J.Stats.pointFailures + 1
end
local function Failed(z, id)
    local row = z.ZASniperState.failures and z.ZASniperState.failures[id]
    return row and row.generation == N.Generation and CurTime() < row.untilTime
end
local function Better(a, b)
    if not b then return true end
    if a.high ~= b.high then return a.high end
    if a.preferred ~= b.preferred then return a.preferred end
    if a.travel ~= b.travel then return a.travel < b.travel end
    return a.id < b.id
end
local function Insert(job, row, limit)
    -- Keep a floor fallback even when the nearest high areas cannot be
    -- reached. A full high shortlist must not discard every walking point.
    local list, at = row.high and job.highCandidates or job.lowCandidates, 1
    while list[at] and not Better(row, list[at]) do at = at + 1 end
    if at <= limit then table.insert(list, at, row); if #list > limit then table.remove(list) end end
end
local function InsetPoint(z, area, point)
    local closest, center = area:GetClosestPointOnArea(point), area:GetCenter()
    local inward = center - closest; inward.z = 0
    local length = inward:Length2D()
    if length > 0 then
        inward = inward / length
        local margin = z.Width * (math.abs(inward.x) + math.abs(inward.y)) + 4
        closest = area:GetClosestPointOnArea(closest + inward * math.min(margin, length))
    end
    return closest
end
local function JumpBounds(z, start, landing)
    PointSettings(z)
    if not z.ZASpecialAssets.Jump then return false, "missing_animation" end
    local delta, settings = landing - start, z.ZASpecialSettings.Jump
    local distance = delta:Length2D()
    if distance < settings.MinDistance then return false, "too_close" end
    if distance > settings.SearchRadius then return false, "too_far" end
    if delta.z > settings.MaxRise then return false, "too_high" end
    if delta.z < -settings.MaxDrop then return false, "too_low" end
    return true
end
local function PerchTier(z, origin, point, target)
    local settings = PointSettings(z)
    local height = target and point.z - target.z
    if height and height > settings.TargetHeightMax then return end
    if height and settings.PreferHigherThanTarget
        and height >= settings.TargetHeightMin and height <= settings.TargetHeightMax then return "high" end
    if math.abs(point.z - origin.z) <= z.loco:GetStepHeight() + 2 then return "level" end
end
local function PointCandidate(z, job, area, pos, slot)
    local settings, id, owner = PointSettings(z), area:GetID(), J.PointOwners[area:GetID()]
    local previous = z.ZASniperState.point
    local key = id .. "/" .. slot
    if IsValid(owner) and owner ~= z or Failed(z, key) or Failed(z, id)
        or previous and previous.position:DistToSqr(pos) <= (z.Width * 6) ^ 2
        or not area:Contains(pos) or pos:DistToSqr(job.origin) > settings.SearchRadius ^ 2 then return end
    local target = job.target
    if target then
        local distance = pos:DistToSqr(target)
        if distance < settings.TargetMinDistance ^ 2 or distance > math.min(settings.TargetMaxDistance, z.ZASpecialSettings.Gun.Range) ^ 2 then return end
    end
    local tier = PerchTier(z, job.origin, pos, target)
    if not tier or not JumpBounds(z, job.origin, pos) then return end
    Insert(job, {id = id, key = key, slot = slot, area = area, position = pos, travel = pos:DistToSqr(job.origin),
        high = tier == "high",
        preferred = target and pos:DistToSqr(target) >= settings.TargetPreferredDistance ^ 2 or false}, settings.Candidates)
    return true
end
local sampleAngles = {0, 90, -90, 180}
local function AreaPoints(z, job, area)
    if not Open(z, area) or job.rankedAreas[area:GetID()] then return end
    job.rankedAreas[area:GetID()] = true
    local center = PointCandidate(z, job, area, area:GetCenter(), "center")
    local near = PointCandidate(z, job, area, InsetPoint(z, area, job.origin), "near")
    if not job.target then return end
    local edge = PointCandidate(z, job, area, InsetPoint(z, area, job.target), "edge")
    if center or near or edge then return end
    -- Nav areas are surfaces, not single authored points. Try a few positions
    -- in the actual firing-distance band when their center is too close or
    -- too far away. Projection and every ground/LOS proof stay bounded.
    local away = job.origin - job.target; away.z = 0
    if away:Length2D() < 1 then away = -z:GetForward() end
    away = away:GetNormalized()
    local distance = PointSettings(z).TargetPreferredDistance + z.Width * 2 + 8
    for slot, angle in ipairs(sampleAngles) do
        local direction = Vector(away); direction:Rotate(Angle(0, angle, 0))
        local point = InsetPoint(z, area, job.target + direction * distance)
        PointCandidate(z, job, area, point, "range" .. slot)
    end
end
local function Band(z, point, target)
    if not target then return true end
    local settings = PointSettings(z)
    local distance = point:DistToSqr(target)
    return distance >= settings.TargetMinDistance ^ 2
        and distance <= math.min(settings.TargetMaxDistance, z.ZASpecialSettings.Gun.Range) ^ 2
end
function J.JumpPlan(z, start, landing, area)
    local ready, reason = JumpBounds(z, start, landing)
    if not ready then return nil, reason end
    local delta = landing - start
    return {start = Vector(start), landing = Vector(landing), area = area, clip = z.ZASpecialAssets.Jump,
        scale = z:GetModelScale(), angles = Angle(0, delta:Angle().y, 0), generation = N.Generation}
end
local function HoldCurrentPoint(z, job)
    local s, area = z.ZASniperState, job.startArea
    if s.point or s.forceRelocate or s.fallbackStanding or not job.target or not Open(z, area) then return end
    local pos = area:GetClosestPointOnArea(job.origin)
    if not Band(z, pos, job.target) then return end
    local owner = J.PointOwners[area:GetID()]
    if IsValid(owner) and owner ~= z then return end
    local ground = P.ClearGround(pos, z, job.profile)
    if not ground or not area:Contains(ground) or not Band(z, ground, job.target)
        or ground:DistToSqr(job.origin) > (z.Width * 2) ^ 2
        or not FiringPosture(z, ground, job.enemy, job.eye) then return end
    -- This already occupied, proved position is a temporary firing point,
    -- while the complete search still gets to choose a better elevated one.
    s.point = {id = area:GetID(), key = area:GetID() .. "/current", area = area,
        position = ground, generation = N.Generation, access = "walk", provisional = true}
    J.PointOwners[s.point.id] = z
    s.pointActive, s.pointTravelStarted = false, CurTime()
    J.Stats.currentPoints = (J.Stats.currentPoints or 0) + 1
end
local function Commit(z, job, candidate)
    local target, eye = KnownTarget(z, job.enemy)
    if J.Plans[z] ~= job or not Open(z, candidate.area)
        or not JumpBounds(z, z:GetPos(), candidate.position)
        or job.enemy and (not target or not Band(z, candidate.position, target)
            or not PerchTier(z, job.origin, candidate.position, target)
            or not FiringPosture(z, candidate.position, job.enemy, eye)) then return false end
    local owner = J.PointOwners[candidate.id]
    if IsValid(owner) and owner ~= z then return false end
    local s = z.ZASniperState
    ReleasePoint(z); s.point = candidate; s.point.generation = N.Generation
    J.PointOwners[candidate.id] = z; s.pointCheck = CurTime() + z.ZASpecialSettings.Jump.SearchInterval
    s.pointActive, s.pointTravelStarted = false, CurTime()
    J.Plans[z] = nil; z.ZANextPerchScan = CurTime() + z.ZASpecialSettings.Jump.SearchInterval
    return true
end
local function NoPoint(z)
    local s = z.ZASniperState
    -- A completed unsuccessful point query enters the original standing
    -- shooting fallback. An exhausted lease must not disable firing forever.
    if s.point and (s.pointShots == 0 or s.forceRelocate) then
        ReleasePoint(z); s.forceRelocate, s.fallbackStanding = nil, true
    end
    J.Plans[z] = nil; z.ZANextPerchScan = CurTime() + z.ZASpecialSettings.Jump.SearchInterval
end
local function PlanStep(z, job, deadline)
    local settings = PointSettings(z)
    if not job.anchorChecked then
        job.anchorChecked = true; HoldCurrentPoint(z, job)
        if SysTime() >= deadline then return end
    end
    if not job.scan.complete then
        J.Stats.scanWork = J.Stats.scanWork + N.ScanLocalAreas(job.scan, settings.AreasPerTick, deadline)
        if job.scan.complete and not N.GraphReady then job.partialGraph = true end
        return
    end
    if not N.GraphReady then return end
    if job.partialGraph then job.scan = N.LocalAreaScan(job.origin, job.radius); job.partialGraph = nil; return end
    if not job.startRanked then
        job.startRanked = true; AreaPoints(z, job, job.startArea)
        if SysTime() >= deadline then return end
    end
    if job.rankCursor <= #job.scan.areas then
        for _ = 1, settings.AreasPerTick do
            if SysTime() >= deadline then return end
            local area = job.scan.areas[job.rankCursor]
            if not area then break end
            job.rankCursor = job.rankCursor + 1
            AreaPoints(z, job, area)
        end
        return
    end
    if not job.ranked then
        job.ranked = true
        local target = KnownTarget(z, job.enemy)
        for _, list in ipairs({job.highCandidates, job.lowCandidates}) do
            for _, candidate in ipairs(list) do
                local tier = PerchTier(z, job.origin, candidate.position, target)
                candidate.high, candidate.rejected = tier == "high", tier == nil
                candidate.preferred = target and candidate.position:DistToSqr(target) >= settings.TargetPreferredDistance ^ 2 or false
                job.candidates[#job.candidates + 1] = candidate
            end
        end
        table.sort(job.candidates, Better)
    end
    local proofs = 0
    while proofs < settings.CandidateChecksPerTick and SysTime() < deadline do
        local candidate = job.candidates[job.proofCursor]
        if not candidate then NoPoint(z); return end
        if not candidate.groundChecked and not candidate.rejected then
            proofs = proofs + 1; J.Stats.candidates = J.Stats.candidates + 1
            local ground = P.ClearGround(candidate.position, z, job.profile)
            local target, eye = KnownTarget(z, job.enemy)
            if not Open(z, candidate.area) or not ground or not candidate.area:Contains(ground)
                or job.enemy and not target or not Band(z, ground, target)
                or not PerchTier(z, job.origin, ground, target)
                or not FiringPosture(z, ground, job.enemy, eye) then candidate.rejected = true
            else
                candidate.position, candidate.groundChecked = ground, true
                -- Relocation is one jump from the actor's occupied surface.
                -- Nav connectivity never introduces a walk to another launch.
                candidate.jump = J.JumpPlan(z, job.origin, ground, candidate.area)
                if not candidate.jump then candidate.rejected = true end
            end
        end
        if not candidate.rejected then
            local plan = candidate.jump
            if not plan.launchChecked then
                proofs = proofs + 1
                local ground = P.ClearGround(plan.start, z, job.profile)
                if not ground or not J.JumpPlan(z, ground, candidate.position, candidate.area) then candidate.rejected = true
                else plan.start, plan.launchChecked, plan.segment, plan.previous = ground, true, 1, ground end
            end
            if not candidate.rejected then
                for _ = 1, z.ZASpecialSettings.Jump.SegmentsPerTick do
                    if SysTime() >= deadline then return end
                    local point = J.Position(plan, plan.clip.Duration * plan.clip.SettleFraction * plan.segment / z.ZASpecialSettings.Jump.Segments)
                    local tr = O.Sweep(z, plan.previous, point); J.Stats.jumpSegments = J.Stats.jumpSegments + 1
                    if tr.Hit or tr.StartSolid or tr.AllSolid then candidate.rejected = true; break end
                    plan.previous, plan.segment = point, plan.segment + 1
                    if plan.segment > z.ZASpecialSettings.Jump.Segments then
                        candidate.access, plan.provedAt = "jump", CurTime()
                        if Commit(z, job, candidate) then return end
                        candidate.rejected, candidate.temporary = true, true; break
                    end
                end
                if not candidate.rejected then return end
            end
        end
        if candidate.rejected then
            if not candidate.temporary then FailPoint(z, candidate.key) end
            job.proofCursor = job.proofCursor + 1
        end
    end
end
function J.PlannerTick()
    if #J.PlanOrder == 0 then return end
    local began, settings = SysTime(), ZA1.SpecialConfig.sniper.Point
    local deadline, count = began + settings.BudgetMS / 1000, #J.PlanOrder
    for _ = 1, count do
        if SysTime() >= deadline or #J.PlanOrder == 0 then break end
        local index = J.PlanCursor
        if index > #J.PlanOrder then index = 1 end
        local z, job = J.PlanOrder[index], J.Plans[J.PlanOrder[index]]
        if not job or not Active(z) or job.generation ~= N.Generation
            or job.origin:DistToSqr(z:GetPos()) > 128 ^ 2 or job.settings ~= PointSettings(z)
            or job.settingsKey ~= SettingsKey(PointSettings(z), z.ZASpecialSettings.Jump)
            or job.enemy and z:GetEnemy() ~= job.enemy then
            if job then J.Plans[z] = nil end
            table.remove(J.PlanOrder, index); J.PlanQueued[z] = nil; J.PlanCursor = index
        else
            J.PlanCursor = index % #J.PlanOrder + 1
            PlanStep(z, job, deadline)
        end
    end
    J.Stats.plannerMS = J.Stats.plannerMS + (SysTime() - began) * 1000
end
hook.Add("Think", "ZA1/SniperPoints", J.PlannerTick)
hook.Add("PostCleanupMap", "ZA1/SniperPoints", function()
    for z in pairs(J.Plans) do if IsValid(z) then J.Clear(z) end end
    for z in pairs(J.JumpActors) do if IsValid(z) then J.Clear(z) end end
    J.Plans, J.PlanOrder, J.PlanCursor = setmetatable({}, {__mode = "k"}), {}, 1
    J.PlanQueued = setmetatable({}, {__mode = "k"})
    J.PointOwners = setmetatable({}, {__mode = "v"})
end)
function J.Select(z, enemy)
    local s = z.ZASniperState or J.Initialize(z)
    if not Active(z) or not navmesh.IsLoaded() then return end
    local settings, target, eye = PointSettings(z), KnownTarget(z, enemy)
    if enemy and not target then return s.point end
    local job = J.Plans[z]
    if job then
        if job.enemy ~= enemy or job.settings ~= settings or job.settingsKey ~= SettingsKey(settings, z.ZASpecialSettings.Jump) then J.Plans[z] = nil
        else
            -- Finish this bounded query against its ranking snapshot.
            -- Ground/LOS/range and final commitment use the current known
            -- target; restarting thousands of areas on each strafe starves
            -- the search before it ever gets to test a jump.
            return s.point
        end
    end
    if CurTime() < (z.ZANextPerchScan or 0) then return s.point end
    local start, area, profile = Vector(z:GetPos()), N.Area(z:GetPos()), z.ZANavProfile or N.Profile(z)
    N.Begin()
    local jump = z.ZASpecialSettings.Jump
    local radius = math.min(settings.SearchRadius, math.ceil(math.sqrt(jump.SearchRadius ^ 2 + math.max(jump.MaxRise, jump.MaxDrop) ^ 2)))
    job = {origin = start, startArea = area, radius = radius, scan = N.LocalAreaScan(start, radius), enemy = enemy, target = target, eye = eye,
        generation = N.Generation, settings = settings, settingsKey = SettingsKey(settings, jump), profile = profile, rankCursor = 1, proofCursor = 1, candidates = {},
        highCandidates = {}, lowCandidates = {}, rankedAreas = {}}
    J.Plans[z] = job
    if not J.PlanQueued[z] then J.PlanOrder[#J.PlanOrder + 1] = z; J.PlanQueued[z] = true end
    z.ZAPerchScan = job.scan; z.ZANextPerchScan = CurTime() + z.ZASpecialSettings.Jump.SearchInterval
    return s.point
end
local function Place(z, pos)
    -- Same DT multiplayer shadow handling as the existing authored mantles.
    local multiplayer = not game.SinglePlayer()
    if multiplayer then z:PhysicsDestroy() end
    z:SetPos(pos)
    if multiplayer then z:PhysicsInitShadow() end
end
function J.Run(z, plan)
    if not Active(z) then return false, "cancelled" end
    local area, settings = plan.area or N.Area(plan.landing), PointSettings(z)
    local function Landing()
        local ground = P.ClearGround(plan.landing, z, z.ZANavProfile or N.Profile(z))
        return Open(z, area) and ground and area:Contains(ground)
            and ground:DistToSqr(plan.landing) <= z.Width ^ 2 and ground or nil
    end
    local function Reject(reason)
        local point = z.ZASniperState.point
        if reason ~= "cancelled" then FailPoint(z, point and point.key or area and area:GetID()) end
        ReleasePoint(z); J.Plans[z] = nil
        return false, reason
    end
    if plan.generation ~= N.Generation or not Landing() then return Reject("invalid_landing") end
    if not J.SetPosture(z, "Standing") then return Reject("cancelled") end
    J.Interrupt(z); N.Cancel(z); ZA1.Crowd.Release(z)
    z:SetAngles(plan.angles)
    if plan.clip.Intro and not ZA1.Elites.Play(z, plan.clip.Intro) then return Reject("cancelled") end
    if not Active(z) then return Reject("cancelled") end
    local oldStart = plan.start
    plan.start = Vector(z:GetPos()); plan.angles = Angle(0, (plan.landing - plan.start):Angle().y, 0)
    if not JumpBounds(z, plan.start, plan.landing) then return Reject("out_of_range") end
    -- A cached preflight belongs to its exact launch and nav generation.
    -- Recheck once at takeoff if the walk/Intro changed that proof, then only
    -- sweep each actual movement delta during playback.
    if not plan.provedAt or CurTime() - plan.provedAt > settings.ProofLifetime
        or oldStart:DistToSqr(plan.start) > 1 or plan.generation ~= N.Generation then
        if not J.Corridor(z, plan) then return Reject("blocked") end
    end
    if not Landing() or J.PointOwners[area:GetID()] ~= z then return Reject("invalid_landing") end
    z.ZASniperJump, z.ZAActing = true, true
    J.JumpActors[z] = true
    local gravity = z.loco:GetGravity()
    z.ZASniperGravity = gravity; z.loco:SetGravity(0); z.loco:SetVelocity(vector_origin)
    z:SetAngles(plan.angles)
    local id = z:PlaySequence(plan.clip.Sequence, {move = false})
    local finish = CurTime() + plan.clip.Duration + 1
    local flags = DT_Base.ToYieldFlags({doWounded = false, doIncapacitated = true})
    local landed, status = false, "cancelled"
    while Active(z) and z:GetSequence() == id and CurTime() < finish and plan.generation == N.Generation do
        if not Open(z, area) or J.PointOwners[area:GetID()] ~= z then status = "invalid_landing"; break end
        local desired = J.Position(plan, z:GetCycle() * plan.clip.Duration)
        local trace = O.Sweep(z, z:GetPos(), desired)
        if trace.Hit or trace.StartSolid or trace.AllSolid then status = "blocked"; break end
        z.loco:SetVelocity(vector_origin); Place(z, desired)
        if z:GetCycle() >= plan.clip.SettleFraction and not landed then
            if not Landing() or J.PointOwners[area:GetID()] ~= z then status = "invalid_landing"; break end
            landed = z:GetPos():DistToSqr(plan.landing) <= z.Width ^ 2
        end
        if z:GetCycle() >= 1 then status = landed and "landed" or "invalid_landing"; break end
        if coroutine.yield(flags) then break end
    end
    if CurTime() >= finish then status = "timeout" end
    if landed and status == "cancelled" and Active(z) and plan.generation == N.Generation
        and z:GetPos():DistToSqr(plan.landing) <= z.Width ^ 2 then status = "landed" end
    if IsValid(z) then z.loco:SetGravity(gravity); z.loco:SetVelocity(Vector(0, 0, z:GetVelocity().z)) end
    z.ZASniperGravity, z.ZASniperJump, z.ZAActing = nil, nil, false
    J.JumpActors[z] = nil
    if IsValid(z) then
        z.ZANextSniperJump = CurTime() + z.ZASpecialSettings.Jump.Cooldown
        N.PauseProgress(z)
        if z:Alive() and not z.ZADowned then z:ResetAnimState(); ZA1.Manager.Wake(z) end
        if status ~= "landed" then Reject(status) end
    end
    J.Stats[status == "landed" and "landed" or status == "blocked" and "blocked" or "cancelled"] =
        J.Stats[status == "landed" and "landed" or status == "blocked" and "blocked" or "cancelled"] + 1
    return status == "landed", status, landed
end
local function GoToPoint(z, point, enemy)
    if z:GetPos():DistToSqr(point.position) <= (z.Width * 2) ^ 2 then
        local s, settings = z.ZASniperState, z.ZASpecialSettings
        if not s.pointActive then
            s.pointShots = math.random(settings.PointShotsMin, settings.PointShotsMax)
            s.idleRemaining = math.Rand(settings.IdleRelocateMin, settings.IdleRelocateMax)
            s.forceRelocate, s.pointActive, s.pointClock = nil, true, CurTime()
        end
        return false
    end
    z.ZASniperState.pointActive = false
    if not J.SetPosture(z, "Standing") then return true end
    local destination = point.jump and point.jump.start or point.position
    if point.jump and z:GetPos():DistToSqr(destination) <= (z.Width * 2) ^ 2 then
        if CurTime() >= (z.ZANextSniperJump or 0) then J.Run(z, point.jump)
        else N.Face(z, point.position) end
        return true
    end
    -- A moved actor or an old pre-refresh walk-to-launch point needs a fresh
    -- query. Relocation must never path to a distant takeoff or landing.
    J.Interrupt(z); ReleasePoint(z); N.Cancel(z)
    z.ZANextPerchScan = nil
    return true
end
local function MoveStanding(z, point, enemy)
    if not J.SetPosture(z, "Standing") then return false end
    z:ZAMove(point, enemy)
    return true
end
local function PointValid(z, s, enemy, goal, visible)
    local point = s.point
    if not point then return false end
    if not IsValid(point.area) or point.generation ~= N.Generation or J.PointOwners[point.id] ~= z
        or point.area:IsBlocked() or point.area:IsUnderwater() then ReleasePoint(z); return false end
    if enemy and not visible and s.lastSeenEnemy ~= enemy then ReleasePoint(z); return false end
    if enemy and CurTime() >= (s.pointCheck or 0) then
        s.pointCheck = CurTime() + z.ZASpecialSettings.Jump.SearchInterval
        local _, eye = KnownTarget(z, enemy)
        if not Band(z, point.position, goal)
            or visible and not FiringPosture(z, point.position, enemy, eye)
            or not visible and CurTime() - (s.lastSeen or -math.huge) > z.ZASpecialSettings.LostSightGrace then
            ReleasePoint(z); return false
        end
    end
    return true
end
function J.Combat(z, enemy)
    local s = J.Initialize(z)
    local goal, visible = z:ZAEnemyGoal(enemy)
    local now, settings = CurTime(), z.ZASpecialSettings
    if not Enemy(enemy) or not goal or now - (z:LastTimeDetected(enemy) or 0) > ZA1.Config.Navigation.MemoryDuration then
        J.Interrupt(z); ReleasePoint(z); J.Plans[z] = nil
        J.SetPosture(z, "Standing"); z:LoseEntity(enemy); return false
    end
    z:SetAIState(DT_Base.AI_STATE_COMBAT)
    if not Active(z) or z.ZAActing then J.Interrupt(z); return true end
    if J.ReactGrenade(z) then return true end
    if s.enemy and s.enemy ~= enemy then
        J.Interrupt(z)
    end
    if s.lastSeenEnemy ~= enemy then
        s.lastSeen, s.lastSeenEye, s.lastSeenGoal, s.lastSeenEnemy = nil, nil, nil, nil
        if not visible then
            J.Interrupt(z); ReleasePoint(z); J.Plans[z] = nil; MoveStanding(z, goal, enemy); return true
        end
    end
    -- Relocation returns before firing setup. Remember the visible contact
    -- first, so looking towards a perch does not discard the point as soon
    -- as DT's sight check loses the target behind the actor.
    if visible then
        s.lastSeen, s.lastSeenEye, s.lastSeenGoal, s.lastSeenEnemy = now,
            enemy.EyePos and enemy:EyePos() or enemy:WorldSpaceCenter(), Vector(goal), enemy
        if s.pointActive then s.idleRemaining = math.Rand(settings.IdleRelocateMin, settings.IdleRelocateMax) end
    end
    CaptureShot(z, s)
    if z.ZAGunAmmo == 0 then
        if now < (s.readyAt or 0) then return true end
        J.Interrupt(z); s.mode = "reloading"
        if not J.SetPosture(z, "Standing") then return true end
        W.Reload(z)
        if Active(z) then
            s.waitUntil = math.max(s.waitUntil, CurTime() + settings.ReloadReentryWait)
            z.ZAGunNextShot = math.max(z.ZAGunNextShot or 0, s.waitUntil)
        end
        return true
    end
    local close = now - (z:LastTimeDetected(enemy) or 0) <= settings.ThreatMemory
        and z:GetPos():DistToSqr(goal) < settings.CloseThreatRange ^ 2
    if not close then
        if s.pointActive and (s.forceRelocate or s.pointShots == 0) then J.Select(z, enemy) end
        local point = PointValid(z, s, enemy, goal, visible) and s.point or J.Select(z, enemy)
        if point and GoToPoint(z, point, enemy) then return true end
    end
    if not visible and not (s.pointActive and s.lastSeenEnemy == enemy
        and now - (s.lastSeen or -math.huge) <= settings.LostSightGrace) then
        J.Interrupt(z); MoveStanding(z, goal, enemy); return true
    end
    s.hidden = not visible
    s.pointClock = now
    if z:GetPos():DistToSqr(goal) > settings.Gun.Range ^ 2 then
        J.Interrupt(z); MoveStanding(z, goal, enemy); return true
    end
    -- Authored close-threat branch backs away whilst shooting. No native
    -- Deadeye melee clip was established, so it does not borrow a human punch.
    if close then
        if not J.SetPosture(z, "Standing") then return true end
        local away = (z:GetPos() - goal):GetNormalized()
        local retreat = P.ClearGround(z:GetPos() + away * settings.MinThreatRange, z, z.ZANavProfile)
        if retreat then z:ZAMove(retreat, enemy) else N.Face(z, goal) end
    else
        local yaw = math.AngleDifference((goal - z:GetPos()):Angle().y, z:GetAngles().y)
        local kneelingTurns = s.posture == "Kneeling" and z.ZASpecialAssets.Gun.Postures
            and z.ZASpecialAssets.Gun.Postures.Kneeling.TurnLeft and z.ZASpecialAssets.Gun.Postures.Kneeling.TurnRight
        if not kneelingTurns and math.abs(yaw) > ZA1.Config.Turning.StartAngle and CurTime() >= (z.ZANextTurn or 0)
            and not J.SetPosture(z, "Standing") then return true end
        if z:GetVelocity():Length2D() <= ZA1.Config.Turning.StationarySpeed and z:ZATurnTowards(goal, enemy) then
            J.Interrupt(z); return true
        end
        N.Face(z, goal)
        local _, eye = KnownTarget(z, enemy)
        local desired = s.pointActive and FiringPosture(z, s.point.position, enemy, eye) or "Standing"
        if not desired then s.forceRelocate = true; J.Select(z, enemy); J.Interrupt(z); return true end
        if not J.SetPosture(z, desired) then return true end
        s.fallbackStanding = nil
    end
    s.enemy, s.goal, s.refreshed = enemy, goal, now
    s.policy.ShotGoal, s.policy.AimGoal, s.policy.AllowUnseen = J.ShotGoal, J.AimGoal, J.AllowUnseen -- Include refresh.
    W.Aim(z, enemy, goal, true)
    W.Request(z, enemy, goal, s.policy)
    J.Tick(z)
    return true
end
function J.Idle(z)
    local s = J.Initialize(z)
    J.Interrupt(z)
    if not Active(z) then return false end
    if J.ReactGrenade(z) then return true end
    if z.ZAInvestigation then J.SetPosture(z, "Standing"); return false end -- Shared hearing/investigation work remains active.
    local now = CurTime()
    if s.pointActive then
        s.idleRemaining = (s.idleRemaining or 0) - math.max(0, now - (s.pointClock or now))
        if s.forceRelocate or s.pointShots == 0 or s.idleRemaining <= 0 then J.Select(z) end
    end
    s.pointClock = now
    local point = PointValid(z, s) and s.point or J.Select(z)
    if point then
        if GoToPoint(z, point) then return true end
        N.Face(z, point.position + z:GetForward() * 32)
        J.SetPosture(z, FiringPosture(z, point.position) or "Standing")
        s.pointClock = CurTime() -- The owned entry/exit is action time, not idle time.
        return true -- Hold the sniper point; inherited wandering must not evict it.
    end
    J.SetPosture(z, "Standing")
    return false -- Existing hearing/investigation/idle manager keeps its work.
end
