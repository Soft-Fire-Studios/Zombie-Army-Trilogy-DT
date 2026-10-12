if SERVER then AddCSLuaFile() end
-- New enemies retain the existing staggered senses, routes and crowd handling.
local E = {}; ZA1.Elites = E
local effects = ZA1.SpecialConfig.Effects
for _, effect in pairs(effects) do PrecacheParticleSystem(effect) end
if CLIENT then
    function E.Presentation(z)
        ZA1.FireVFX.Update(z)
    end
    net.Receive("ZA1/FireballImpact", function()
        local pos, angles = net.ReadVector(), net.ReadAngle()
        local ply = LocalPlayer()
        local limit = GetConVar("za1_effect_distance")
        if not IsValid(ply) or ply:EyePos():DistToSqr(pos) > (limit and limit:GetFloat() or 3000) ^ 2 then return end
        ZA1.FireVFX.Impact(pos, angles); ZA1.Feedback.Light(pos, true)
    end)
    return
end
local M, N, P = ZA1.Manager, ZA1.Navigation, ZA1.Population
local C = ZA1.SpecialConfig
local classes = {fire = "npc_dt_za1_fire_demon", burning = "npc_dt_za1_burning_zombie",
    chainsaw = "npc_dt_za1_chainsaw_elite", summoner = "npc_dt_za1_summoner"}
E.Classes, E.Jobs = classes, {}
E.ProjectileCount = 0
util.AddNetworkString("ZA1/FireballImpact")
E.Stats = {queued = 0, spawned = 0, ignited = 0, revived = 0, rejected = 0}
local function Pick(pool) return pool[math.random(#pool)] end
local function Active(z) return IsValid(z) and z:Alive() and not z.ZADeathHandled end
local function Target(z) return IsValid(z) and (not z.Alive or z:Alive()) end
local function Able(z) return Active(z) and not z:IsAIDisabled() and not z.ZADowned end
local function VisualState(z, state)
    if ZA1.EnemyVFX then ZA1.EnemyVFX.SetState(z, state) end
end
function E.IsElite(z) return classes[z.ZASpecial] ~= nil or z.ZASpecial == "sniper" or z.ZASpecial == "mg42" or z.ZASpecial == "general" end
local function Flames(z, enabled)
    z.ZAFlameShield = z.ZASpecial == "fire" and enabled or false
    z:SetNW2Bool("za1_flames", enabled)
end
local function StopLoops(z)
    for _, loop in pairs(z.ZAEventLoops or {}) do loop.Sound:Stop() end
    z.ZAEventLoops = nil
    -- Retire a loop retained by a live entity from the previous Lua version.
    if z.ZAEventLoop then z.ZAEventLoop:Stop(); z.ZAEventLoop = nil end
    z.ZAEventLoopName, z.ZAEventLoopSequence = nil, nil
end
function E.Stop(z)
    StopLoops(z)
    ZA1.FireVFX.Stop(z)
    z.ZARecoveryHit, z.ZAFireRestState, z.ZARestUntil = nil, nil, nil
    z.ZAFireKneeling, z.ZAFireKneelPending = nil, nil
    z.ZAPainPending = nil
    z.ZAConversionTargets, z.ZANextZombieSearch = nil, nil
    z.ZAFireNearZombie, z.ZAFireZombie, z.ZAFireFarZombie = nil, nil, nil
    z.ZAFireAction, z.ZAFireTimerAt = nil, nil
    z.ZAFireballTarget, z.ZAFireballMode = nil, nil
    if IsValid(z) and (z.ZASpecial == "chainsaw" or z.ZASpecial == "summoner") then VisualState(z, "dead") end
    if IsValid(z) then Flames(z, false) end
end
function E.DeathBurst(z)
    if not IsValid(z) or z.ZASpecial ~= "fire" or z.ZABrokenApart then return false end
    if z.ZAFireDeathExploded then return true end
    z.ZAFireDeathExploded = ZA1.FireVFX.DemonDeath(z)
    if z.ZAFireDeathExploded then ZA1.Specials.Sound(z, "fireball_hit", 85) end
    return z.ZAFireDeathExploded
end
function E.Die(z, info)
    if not IsValid(z) or z.ZASpecial ~= "fire" or z.ZABrokenApart or z.ZAFireDeathExploded then return end
    local sequence = z:LookupSequence(z.ZASpecialSettings.Death)
    if sequence < 0 then return end
    N.Cancel(z); ZA1.Crowd.Release(z)
    ZA1.Specials.DeathVoice(z, z)
    z.ZADeathPlaying = true
    local id = z:PlaySequence(sequence, {move = true})
    z.__DT_PlaySeq_PreviousSeq, z.__DT_PlaySeq_PreviousCycle = id, 0
    local finish = CurTime() + z:SequenceDuration(id)
    local flags = DT_Base.ToYieldFlags({doWounded = false, doIncapacitated = false})
    while IsValid(z) and z:GetSequence() == id and CurTime() < finish do coroutine.yield(flags) end
    if not IsValid(z) then return end
    z.ZADeathPlaying = nil
    if z:GetSequence() ~= id then return end
    -- The death clip has no authored PFX marker. Completion is the Source
    -- presentation cue, using the original fire burst and impact sound once.
    E.DeathBurst(z)
end
function E.Initialize(z)
    z.ZAMinions, z.ZAQueuedChildren = {}, 0
    if z.ZASpecialAssets.Hat and z.ZASpecial ~= "chainsaw" then z:SetBodygroup(2, 1) end
    z.ZASupportIdle = z.IdleAnimation
    z.ZASawPainStage = 0
    Flames(z, z.ZASpecial == "fire" or z.ZASpecial == "burning")
    if z.ZASpecial == "burning" then ZA1.FireVFX.Pulse(z, "burning_activate") end
    z.ZANextSummon, z.ZANextFireball = CurTime() + 2, CurTime() + 2
    if z.ZASpecial == "fire" then
        z.ZANextSummon = CurTime() + z.ZASpecialSettings.SummonCooldown
        z.ZANextConversion = CurTime() + z.ZASpecialSettings.ConversionCooldown
        z.ZAFireTimerAt = CurTime()
        local follow = z.ZASpecialSettings.Follow
        z.ZAFireFollowDistance = math.Rand(follow.DesiredMin, follow.DesiredMax)
    end
end
local function Members(z)
    local pool = z.ZAMinions
    for i = #pool, 1, -1 do if not Active(pool[i]) then table.remove(pool, i) end end
    return #pool + (z.ZAQueuedChildren or 0)
end
local function Inherit(z, child, job)
    z.ZAMinions[#z.ZAMinions + 1] = child
    child.ZASummonedBy = z
    if job and job.fireWave then job.fireWave.Actors[#job.fireWave.Actors + 1] = child end
    if not IsValid(child.ZADirector) and IsValid(z.ZADirector) then P.Own(z.ZADirector, child) end
    local enemy = z:GetEnemy()
    if IsValid(enemy) and child:IsHatedEntity(enemy) then
        local goal = z:LastKnownPos(enemy)
        if goal then child:DetectEntity(enemy); M.Investigate(child, goal, ZA1.Config.Navigation.MemoryDuration) end
    end
    M.Wake(child)
end
local function Common(z)
    return Active(z) and z.ZA1Zombie and not z.ZASpecial and not z.ZAHeadDestroyed
        and not z.ZACrawling and not z.ZADowned and not z:IsPossessed()
end
function E.FireRoster(z)
    local waves = z.ZASpecialSettings.Waves
    return waves[math.Clamp(#player.GetHumans(), 1, #waves)]
end
local function WaveThreshold(z)
    local wave = z.ZAFireWave
    return wave and wave.AlivePercent or E.FireRoster(z).AlivePercent
end
function E.FindFireZombies(z)
    if CurTime() >= (z.ZANextZombieSearch or 0) then
        local settings, origin = z.ZASpecialSettings, z:GetPos()
        local distances, targets = {math.huge, math.huge, math.huge}, {}
        local inner, outer = settings.ZombieFireballInner ^ 2, settings.ZombieFireballOuter ^ 2
        M.Near(origin, settings.ZombieSearchRadius, function(target)
            if target ~= z and Common(target) and not z:IsHatedEntity(target) then
                local distance = target:GetPos():DistToSqr(origin)
                local band = distance < inner and 1 or distance < outer and 2 or 3
                if distance < distances[band] then distances[band], targets[band] = distance, target end
            end
        end)
        z.ZAFireNearZombie, z.ZAFireZombie, z.ZAFireFarZombie = targets[1], targets[2], targets[3]
        z.ZANextZombieSearch = CurTime() + settings.FindZombiesInterval
    end
    return Common(z.ZAFireZombie) and z.ZAFireZombie or nil
end
local function Convertible(z) return E.FindFireZombies(z) ~= nil end
function E.FireWavePercent(z)
    local wave = z.ZAFireWave
    if not wave or wave.Size == 0 then return 0 end
    local live = wave.Queued
    for i = #wave.Actors, 1, -1 do
        if Active(wave.Actors[i]) then live = live + 1 else table.remove(wave.Actors, i) end
    end
    return math.ceil(live / wave.Size * 100)
end
function E.FireTimerTick(z)
    if z.ZASpecial ~= "fire" then return end
    local now, settings = CurTime(), z.ZASpecialSettings
    local elapsed = math.max(0, now - (z.ZAFireTimerAt or now))
    z.ZAFireTimerAt = now
    if not Able(z) then
        z.ZANextConversion = (z.ZANextConversion or now) + elapsed
        z.ZANextSummon = (z.ZANextSummon or now) + elapsed
        return
    end
    -- Native FUN_0072C380 counts charged, free time. A melee preserves the
    -- partial wave recharge; only a wave action resets that timer outright.
    if z.ZAFireAction then
        z.ZANextConversion = now + settings.ConversionCooldown
        if z.ZAFireAction == "wave" then z.ZANextSummon = now + settings.SummonCooldown
        else z.ZANextSummon = (z.ZANextSummon or now) + elapsed end
    else
        if not z.ZAFlameShield then
            z.ZANextConversion = (z.ZANextConversion or now) + elapsed
            z.ZANextSummon = (z.ZANextSummon or now) + elapsed
        end
        if Convertible(z) or E.FireWavePercent(z) > WaveThreshold(z) then
            z.ZANextSummon = now + settings.SummonCooldown
        end
    end
end
function E.FireWaveReady(z)
    E.FireTimerTick(z)
    local settings = z.ZASpecialSettings
    if not z.ZAFlameShield or z.ZAFireRestState or z.ZAActing then return false end
    if Convertible(z) or E.FireWavePercent(z) > WaveThreshold(z) then
        z.ZANextSummon = CurTime() + settings.SummonCooldown
        return false
    end
    return CurTime() >= z.ZANextSummon and Members(z) < settings.MinionLimit
        and M.Count() + #E.Jobs < math.min(100, M.Cap:GetInt())
end
function E.Ignite(z, target)
    if not Common(target) then return false end
    local child = ents.Create(classes.burning)
    if not IsValid(child) then return false end
    local director, position, angles = target.ZADirector, target:GetPos(), target:GetAngles()
    child:SetPos(position); child:SetAngles(angles)
    -- Free the registry slot before initializing the replacement. The living
    -- horde still observes its 100-actor limit, even during a conversion.
    M.Unregister(target); child:Spawn(); child:Activate()
    if not Active(child) then
        if IsValid(child) then child:Remove() end
        M.Register(target); return false
    end
    if IsValid(director) then P.Own(director, child) end
    -- Preserve a tracked handle if a custom wave supplied a convertible actor;
    -- converting an ambient zombie does not enlarge the native wave capacity.
    local wave = z.ZAFireWave
    if wave then
        for index, actor in ipairs(wave.Actors) do if actor == target then wave.Actors[index] = child; break end end
    end
    target:Remove(); Inherit(z, child)
    E.Stats.ignited = E.Stats.ignited + 1
    return true
end
local function Queue(z, class, corpse, fireWave, placement)
    if Members(z) >= z.ZASpecialSettings.MinionLimit then return false end
    if M.Count() + #E.Jobs >= math.min(100, M.Cap:GetInt()) then return false end
    z.ZAQueuedChildren = z.ZAQueuedChildren + 1
    if fireWave then
        fireWave.Queued = fireWave.Queued + 1
        fireWave.Size = math.max(fireWave.Size, #fireWave.Actors + fireWave.Queued)
    end
    if corpse then corpse.ZAReviveClaim = z end
    E.Jobs[#E.Jobs + 1] = {owner = z, class = class, corpse = corpse, fireWave = fireWave, attempts = 0,
        angle = placement and placement.Angle or math.Rand(0, math.pi * 2),
        radii = placement and placement.Radii, randomFacing = placement and placement.RandomFacing ~= false,
        expires = CurTime() + 10}
    E.Stats.queued = E.Stats.queued + 1
    return true
end
E.MinionCount, E.QueueMinion = Members, Queue
function E.QueueWave(z)
    local settings, count = z.ZASpecialSettings, 0
    if z.ZASpecial == "fire" then
        local roster = E.FireRoster(z)
        -- The game's append flag retains surviving actors and a buffer capacity
        -- which grows to fit old survivors plus the new wave, without shrinking.
        local wave = z.ZAFireWave or {Actors = {}, Queued = 0, Size = 0}
        z.ZAFireWave, wave.AlivePercent = wave, roster.AlivePercent
        E.FireWavePercent(z)
        for _, ring in ipairs({"Inner", "Outer"}) do
            local phase, size = math.Rand(0, math.pi * 2), roster[ring]
            for index = 1, size do
                local placement = {Angle = phase + (index - 1) * math.pi * 2 / size,
                    Radii = settings.WaveRadii[ring]}
                if Queue(z, classes.burning, nil, wave, placement) then count = count + 1 else return count end
            end
        end
        return count
    elseif M.ResurrectionEnabled:GetBool() then
        -- Only the retained corpse list is searched, once per summon.
        for _, rag in ipairs(M.Ragdolls) do
            if count >= settings.SummonCount then break end
            if IsValid(rag) and rag.ZARevive and not rag.ZAHeadDestroyed and not IsValid(rag.ZAReviveClaim)
                and rag:GetPos():DistToSqr(z:GetPos()) <= settings.ReviveRadius ^ 2 and z:Visible(rag)
                and Queue(z, rag.ZARevive.Class, rag) then count = count + 1 end
        end
    end
    for _ = count + 1, settings.SummonCount do
        if Queue(z, Pick(settings.SpawnPool)) then count = count + 1 else break end
    end
    return count
end
local function Release(job)
    local z = job.owner
    if job.fireWave then job.fireWave.Queued = math.max(0, job.fireWave.Queued - 1) end
    if IsValid(z) then z.ZAQueuedChildren = math.max(0, (z.ZAQueuedChildren or 0) - 1) end
    if IsValid(job.corpse) and job.corpse.ZAReviveClaim == z then job.corpse.ZAReviveClaim = nil end
end
function E.CancelJobs(z)
    for i = #E.Jobs, 1, -1 do
        if E.Jobs[i].owner == z then Release(E.Jobs[i]); table.remove(E.Jobs, i) end
    end
end
function E.Process()
    if #E.Jobs == 0 then return end
    local deadline, work = SysTime() + C.Summoning.BudgetMS / 1000, 0
    while #E.Jobs > 0 and work < C.Summoning.PerTick and SysTime() < deadline do
        local job = table.remove(E.Jobs, 1); local z = job.owner
        work = work + 1
        if not Able(z) or CurTime() >= job.expires or M.Count() >= math.min(100, M.Cap:GetInt()) then
            Release(job); E.Stats.rejected = E.Stats.rejected + 1
        else
            local profile = P.SpawnProfile(job.class)
            local rag, position = job.corpse
            if rag then
                if IsValid(rag) and rag.ZARevive and not rag.ZAHeadDestroyed then position = rag:GetPos() end
            else
                if not job.radii or job.attempts > 0 then job.angle = job.angle + 2.3999632297287 end
                local radii = job.radii
                local radius = radii and math.Rand(radii[1], radii[2]) or math.Rand(C.Summoning.MinRadius, C.Summoning.MaxRadius)
                position = z:GetPos() + Vector(math.cos(job.angle) * radius, math.sin(job.angle) * radius, 0)
            end
            local area = position and N.Area(position)
            local ground = IsValid(area) and not area:IsBlocked() and not area:IsUnderwater()
                and math.abs(area:GetClosestPointOnArea(position).z - position.z) <= profile.step
                and P.ClearGround(position, {z, rag}, profile)
            local reachable = ground and N.Reachable(area, z:GetPos(), profile)
            if ground and reachable then
                local child = ents.Create(job.class)
                if IsValid(child) then
                    child:SetPos(ground); child:SetAngles(Angle(0, job.randomFacing and math.Rand(0, 360) or z:GetAngles().y, 0))
                    if not rag then child.ZAEmerge = ZA1.Specials.Emerge(job.class) end
                    child:Spawn(); child:Activate()
                    if Active(child) and (not rag or ZA1.Recovery.Reanimate(child, rag)) then
                        Inherit(z, child, job); E.Stats.spawned = E.Stats.spawned + 1
                        if z.ZASpecial == "summoner" and ZA1.EnemyVFX then
                            -- The appearance resource is level-authored in the
                            -- original game. Accepted child creation is this
                            -- port's cosmetic cue; no extra spawn or damage.
                            ZA1.EnemyVFX.Pulse(z, "summon_appear", ground, child:GetAngles())
                            ZA1.EnemyVFX.SpawnTrail(z, child, "spawn_trail")
                        end
                        if not rag then
                            local sequence = child.ZAEmerge and child:LookupSequence(child.ZAEmerge)
                            local duration = sequence and sequence >= 0 and child:SequenceDuration(sequence) or 1
                            ZA1.ResurrectionFX.Spawn(child, ground, Vector(0, 0, 1), duration)
                        end
                        if rag then E.Stats.revived = E.Stats.revived + 1 end
                    elseif IsValid(child) then child:Remove() end
                end
                Release(job)
            elseif reachable == nil and ground and CurTime() < job.expires then E.Jobs[#E.Jobs + 1] = job
            else
                job.attempts = job.attempts + 1
                if job.attempts < C.Summoning.Attempts and not rag then E.Jobs[#E.Jobs + 1] = job
                else Release(job); E.Stats.rejected = E.Stats.rejected + 1 end
            end
        end
    end
end
hook.Add("Think", "ZA1/Summoning", E.Process)
hook.Add("PostCleanupMap", "ZA1/Summoning", function()
    for _, job in ipairs(E.Jobs) do Release(job) end
    E.Jobs = {}
end)
local function Play(z, sequence, callback)
    local cancelled = false
    for _, part in ipairs(z.ZASpecialAssets.Parts[sequence] or {sequence}) do
        if not Able(z) then return false end
        z:ZAPlayOnce(part, function()
            if not Able(z) or callback and callback() == false then cancelled = true; return false end
        end)
        if cancelled then return false end
        if not Able(z) then return false end
    end
    return true
end
E.Play = Play
function E.Rest(z)
    if not Able(z) or z.ZAFireRestState then return end
    Flames(z, false)
    ZA1.FireVFX.Phase(z, "recharge")
    local settings = z.ZASpecialSettings
    z.ZARecoveryHit, z.ZAFireRestState = nil, "enter"
    z.ZAFireKneeling, z.ZAFireKneelPending = nil, nil
    if not settings.RecoverInto or Play(z, settings.RecoverInto) then
        z.ZARestUntil = CurTime() + settings.RestTime
        z.ZAFireRestState = "idle"
        while Able(z) and CurTime() < z.ZARestUntil do
            local hit = z.ZARecoveryHit
            if z.ZAFireKneelPending then
                z.ZAFireKneelPending, z.ZARecoveryHit = nil, nil
                z.ZAFireKneeling, z.ZAFireRestState = true, "kneel"
                if not Play(z, settings.KneelingRecovery.Into, function() return CurTime() < z.ZARestUntil end) then break end
                z.ZAFireRestState = "idle"
            elseif hit then
                z.ZARecoveryHit, z.ZAFireRestState = nil, "hit"
                if not Play(z, hit, function() return CurTime() < z.ZARestUntil end) then break end
                z.ZAFireRestState = "idle"
            else
                Play(z, z.ZAFireKneeling and settings.KneelingRecovery.Idle or settings.Recover, function()
                    return not z.ZARecoveryHit and not z.ZAFireKneelPending and CurTime() < z.ZARestUntil
                end)
            end
        end
        if Able(z) then
            z.ZAFireRestState = "exit"
            ZA1.FireVFX.Phase(z, "")
            ZA1.FireVFX.Pulse(z, "reactivate")
            Play(z, z.ZAFireKneeling and settings.KneelingRecovery.Out or settings.RecoverOut)
            z.ZAFireRestState = "settle"
            local finish = CurTime() + (settings.PowerSettle or 0)
            local flags = DT_Base.ToYieldFlags({doWounded = false})
            while Able(z) and CurTime() < finish do coroutine.yield(flags) end
        end
    end
    ZA1.FireVFX.Phase(z, "")
    if Active(z) then Flames(z, true) end
    z.ZARecoveryHit, z.ZAFireRestState, z.ZARestUntil = nil, nil, nil
    z.ZAFireKneeling, z.ZAFireKneelPending = nil, nil
end
function E.RecoveryHit(z, info, tr)
    -- OnWounded still runs while DT suppresses generic flinch-thread reentry.
    -- One accepted hit interrupts the downed idle; further hits deal damage
    -- without interrupting the reaction or changing the get-up deadline.
    if z.ZASpecial ~= "fire" or not z.ZAFireRestState or z.ZAFireRestState == "exit"
        or z.ZAFireRestState == "settle" or not Able(z) then return end
    local damage = info:GetDamage()
    if damage <= 0 or damage >= z:Health() then return end
    if not z.ZAFireKneeling and info:IsDamageType(DMG_BLAST) then
        z.ZAFireKneelPending, z.ZARecoveryHit = true, nil
        return
    end
    if z.ZAFireRestState ~= "idle" or z.ZAFireKneelPending or z.ZARecoveryHit
        or CurTime() >= z.ZARestUntil or damage < ZA1.Config.Flinch.MinDamage
        or CurTime() < (z.ZANextFlinch or 0) then return end
    local attacker, direction = info:GetAttacker()
    if tr and tr.StartPos then direction = tr.StartPos - z:WorldSpaceCenter()
    elseif IsValid(attacker) then direction = attacker:WorldSpaceCenter() - z:WorldSpaceCenter()
    else direction = -info:GetDamageForce() end
    local front, right = z:GetForward():Dot(direction), z:GetRight():Dot(direction)
    local side = math.abs(front) >= math.abs(right) and (front >= 0 and "Front" or "Back")
        or (right >= 0 and "Right" or "Left")
    local hits = z.ZAFireKneeling and z.ZASpecialSettings.KneelingRecovery.Hits or z.ZASpecialSettings.RecoveryHits
    z.ZARecoveryHit = hits[side]
    z.ZANextFlinch = CurTime() + z.ZASpecialSettings.FlinchCooldown
end
local function FireAction(z, action)
    local now, settings = CurTime(), z.ZASpecialSettings
    z.ZAFireAction = action
    z.ZANextConversion = now + settings.ConversionCooldown
    if action == "wave" then z.ZANextSummon = now + settings.SummonCooldown end
end
local function Recharge(z)
    z.ZAFireAction = nil
    if Able(z) then E.Rest(z) end
    z.ZANextFireball = CurTime() + z.ZASpecialSettings.FireballCooldown
end
function E.Convert(z)
    if not Able(z) or z.ZAActing or z.ZAFireRestState or not z.ZAFlameShield
        or CurTime() < (z.ZANextConversion or 0) or Members(z) >= z.ZASpecialSettings.MinionLimit
        then return false end
    -- Keep the game's retained radial Blast conversion distinct from Summon.
    -- The authored 2014 tree comments mark this branch as replaced by melee;
    -- retaining it here is an explicit Source adaptation for igniting commons.
    local targets, settings = {}, z.ZASpecialSettings
    M.Near(z:GetPos(), settings.IgniteRadius, function(target)
        if Common(target) and M.Visible(z, target) then targets[#targets + 1] = target end
    end)
    if #targets == 0 then return false end
    FireAction(z, "ignite")
    if Play(z, z.ZASpecialSettings.Ignite) then
        for _, target in ipairs(targets) do
            if Members(z) >= z.ZASpecialSettings.MinionLimit then break end
            if Common(target) and target:GetPos():DistToSqr(z:GetPos()) <= z.ZASpecialSettings.IgniteRadius ^ 2
                and z:Visible(target) then E.Ignite(z, target) end
        end
    end
    z.ZAConversionTargets, z.ZANextZombieSearch = nil, nil
    Recharge(z)
    return true
end
function E.Summon(z)
    if not Able(z) or z.ZAActing or CurTime() < (z.ZANextSummon or 0) then return false end
    local settings = z.ZASpecialSettings
    if Members(z) >= settings.MinionLimit then return false end
    if z.ZASpecial == "fire" then
        if not E.FireWaveReady(z) then return false end
        FireAction(z, "wave")
        if Play(z, settings.Summon) then E.QueueWave(z) end
        Recharge(z)
    else
        z.ZANextSummon = math.huge
        -- Native idle/cast states are retained. The game's specific summon
        -- resource lacks a direct scoped BLUE hook, so this existing cast owns
        -- its explicitly cosmetic Source presentation.
        VisualState(z, "summon")
        if Play(z, settings.SummonInto) then
            E.QueueWave(z); Play(z, settings.SummonLoop); Play(z, settings.SummonOut)
        end
        if Active(z) then VisualState(z, "idle") end
        z.ZANextSummon = CurTime() + settings.SummonCooldown
    end
    return true
end
function E.FireballVelocity(position, goal, anchor, settings)
    local metre = 39.37007874
    local apex = (anchor + goal) * .5
    apex.z = goal.z < anchor.z - metre and anchor.z + metre or math.max(anchor.z, goal.z) + 2.5 * metre
    local q = (apex - position):GetNormalized()
    local theta = math.acos(math.Clamp(q.x * q.x + q.y * q.y, -1, 1))
    local tangent, sine = math.tan(theta), math.sin(2 * theta)
    if tangent <= 0 or sine <= .000001 then return (goal - position):GetNormalized() * settings.FireballSpeed end
    local delta = goal - position
    local distance = math.max(2 * metre, delta:Length2D() + delta.z / tangent)
    local direction = Vector(delta.x, delta.y, tangent * distance):GetNormalized()
    return direction * math.sqrt(settings.FireballSolveGravity * distance / sine)
end
function E.Fireball(z, target)
    if z.ZAFireballLaunched or not Able(z) then return false end
    local attachment = z:GetAttachment(z:LookupAttachment(z.ZASpecialAssets.Fireball.Socket))
    if not attachment then return false end
    local position = attachment.Pos
    local goal = Target(target) and target:WorldSpaceCenter()
    if not goal and z:IsPossessed() then
        local controls = z:GetPossessionControls()
        if IsValid(controls) then goal = controls:TraceLine().HitPos end
    end
    if not goal then return false end
    local anchorSocket = z:GetAttachment(z:LookupAttachment(z.ZASpecialAssets.Fireball.Anchor))
    if not anchorSocket then return false end
    local projectile = ents.Create("sent_za1_fireball")
    if not IsValid(projectile) then return false end
    z.ZAFireballLaunched = true
    local settings = z.ZASpecialSettings
    local anchor = anchorSocket.Pos - Vector(0, 0, .5 * 39.37007874) + z:GetRight() * (.5 * 39.37007874)
    projectile.ZASettings, projectile.ZAVelocity = settings, E.FireballVelocity(position, goal, anchor, settings)
    projectile:SetPos(position); projectile:SetAngles(projectile.ZAVelocity:Angle()); projectile:SetOwner(z)
    projectile.ZAMode = z.ZAFireballMode or "damage"
    projectile:Spawn(); projectile:Activate()
    return true
end
function E.Ranged(z, target, mode)
    mode = mode or "damage"
    local conversion = mode == "conversion"
    local nextCast = conversion and z.ZANextConversion or z.ZANextFireball
    if not Able(z) or z.ZAActing or z.ZAFireRestState or not z.ZAFlameShield
        or CurTime() < (nextCast or 0) then return false end
    if conversion and (not Common(target) or Members(z) >= z.ZASpecialSettings.MinionLimit) then return false end
    if not conversion and not z.ZASpecialSettings.PlayerFireballEnabled then return false end
    z.ZANextFireball = math.huge
    FireAction(z, "fireball")
    z.ZAFireballLaunched, z.ZAFireballTarget, z.ZAFireballMode = nil, target, mode
    ZA1.FireVFX.Phase(z, "charge")
    local start, marker = CurTime(), z.ZASpecialAssets.Fireball
    Play(z, z.ZASpecialSettings.Fireball, function()
        if not z:IsPossessed() and not Target(target) then return false end
        if CurTime() - start >= marker.Time then E.Fireball(z, target) end
    end)
    z.ZAFireballTarget, z.ZAFireballMode = nil, nil
    ZA1.FireVFX.Phase(z, "")
    Recharge(z)
    return true
end
function E.Charge(z, target)
    local settings, scale = z.ZASpecialSettings, z:GetModelScale()
    local sequence = z:LookupSequence(settings.DashLoop)
    if sequence < 0 then return false end
    local ok, travel = z:GetSequenceMovement(sequence, 0, 1)
    if not ok or travel:Length2D() <= 0 then return false end
    local start, limit = Vector(z:GetPos()), settings.DashMaxRange * scale
    -- Bound a blocked or missed charge by its authored travel and cycle time.
    local deadline = CurTime() + math.ceil(settings.DashMaxRange / travel:Length2D()) * z:SequenceDuration(sequence)
    local reached, stopped = false, false
    while Able(z) and not stopped do
        z:ZAPlayOnce(settings.DashLoop, function()
            if not Able(z) or target and not Target(target) then stopped = true; return false end
            if target and z:ZACanMelee(target, ZA1.Config.Melee.StartRange * scale) then
                reached, stopped = true, true; return false
            end
            if z:GetPos():DistToSqr(start) >= limit * limit or CurTime() >= deadline then
                reached, stopped = not target, true; return false
            end
        end)
    end
    return reached and Able(z)
end
function E.Dash(z, target)
    if not Able(z) or CurTime() < (z.ZANextDash or 0) then return false end
    z.ZANextDash = CurTime() + z.ZASpecialSettings.DashCooldown
    VisualState(z, "attack")
    if Play(z, z.ZASpecialSettings.DashTelegraph, function()
        if target and not Target(target) then return false end
    end) and (not target or Target(target)) then
        if target then z:FaceTowards(target:GetPos()) end
        if E.Charge(z, target) then
            z.ZAAttacking, z.ZANextSawHit = true, 0
            Play(z, z.ZASpecialSettings.DashAttack, function()
                if target and not Target(target) then return false end
            end)
            z.ZAAttacking = false
        end
    end
    if Active(z) then VisualState(z, "idle") end
    return true
end
function E.Attack(z, target)
    if z.ZASpecial == "summoner" then return E.Summon(z) end
    if z.ZASpecial == "fire" and not target then return E.Ranged(z) end
    if CurTime() < (z.ZANextMelee or 0) then return false end
    local settings = z.ZASpecialSettings
    if target and not z:ZACanMelee(target, settings.MeleeStartRange or ZA1.Config.Melee.StartRange) then return false end
    local sequence = Pick(z.MeleeAnimations)
    if settings.MeleeWeights then
        local choice, total = math.Rand(0, 1), 0
        for index, weight in ipairs(settings.MeleeWeights) do
            total = total + weight
            if choice <= total then sequence = z.MeleeAnimations[index]; break end
        end
    end
    return E.Melee(z, sequence, target)
end
function E.Melee(z, sequence, target)
    if z.ZASpecial == "fire" then FireAction(z, "melee") end
    z.ZAAttacking, z.ZANextSawHit, z.ZALastMeleeEvent = true, 0, nil
    -- The original Chainsaw tree turns the wearable trail on around each
    -- attack, then off. Its blade particles and exhaust remain appearance-owned.
    if z.ZASpecial == "chainsaw" then VisualState(z, "attack") end
    Play(z, sequence, function() if target and not Target(target) then return false end end)
    z.ZAAttacking = false
    if z.ZASpecial == "chainsaw" and Active(z) then VisualState(z, "idle") end
    z.ZANextMelee = CurTime() + (z.ZASpecialSettings.MeleeCooldown or ZA1.Config.Melee.Cooldown)
    if z.ZASpecial == "fire" then z.ZAFireAction = nil end
    return true
end
function E.Secondary(z, target)
    if z.ZASpecial == "fire" then
        local common = E.FindFireZombies(z)
        if common and E.Ranged(z, common, "conversion") then return true end
        return z.ZASpecialSettings.RadialIgniteEnabled and E.Convert(z) or E.Summon(z)
    end
    if z.ZASpecial == "summoner" then return E.Summon(z) end
    if z.ZASpecial == "chainsaw" then return E.Dash(z, target) end
    return false
end
function E.FireSupport(z, enemy, goal)
    if enemy and z:GetPos():DistToSqr(goal) <= z.ZASpecialSettings.MeleeEncounterRange ^ 2 then return false end
    local waveReady = E.FireWaveReady(z)
    if waveReady and E.Summon(z) then return true end
    if z.ZASpecialSettings.RadialIgniteEnabled and E.Convert(z) then return true end
    local common = E.FindFireZombies(z)
    if common and CurTime() >= (z.ZANextConversion or 0) then
        if z:ZATurnTowards(common:GetPos(), common) then return true end
        N.Face(z, common:GetPos())
        return E.Ranged(z, common, "conversion")
    end
    return false
end
function E.FireIdle(z)
    if not Able(z) or z:IsPossessed() then return false end
    return E.FireSupport(z)
end
function E.Combat(z, enemy)
    if z.ZAPainPending and E.Flinch(z) then return true end
    local goal, visible = z:ZAEnemyGoal(enemy)
    if not goal or CurTime() - (z:LastTimeDetected(enemy) or 0) > ZA1.Config.Navigation.MemoryDuration then
        z:LoseEntity(enemy); return false
    end
    z:SetAIState(DT_Base.AI_STATE_COMBAT)
    local settings, distance = z.ZASpecialSettings, z:GetPos():DistToSqr(goal)
    if z.ZASpecial == "summoner" then
        -- Its original graph owns casting/idle states and has no chase or LOS
        -- movement rule. Remembered enemies keep it in the same support state.
        if E.Summon(z) then return true end
        z.IdleAnimation = Members(z) >= settings.MinionLimit and settings.Patient or z.ZASupportIdle
        if not z:ZATurnTowards(goal, enemy) then N.Face(z, goal) end
        return true
    end
    if z.ZASpecial == "fire" then
        if E.FireSupport(z, enemy, goal) then return true end
        if visible then
            if settings.PlayerFireballEnabled and CurTime() >= (z.ZANextFireball or 0)
                and distance >= settings.FireballMinRange ^ 2 and distance <= settings.FireballRange ^ 2 then
                if z:ZATurnTowards(goal, enemy) then return true end
                N.Face(z, goal)
                if E.Ranged(z, enemy) then return true end
            end
        end
        local range = settings.MeleeStartRange * z:GetModelScale()
        if distance < range ^ 2 and z:ZACanMelee(enemy, range, true) then
            if z:ZATurnTowards(goal, enemy) then return true end
            N.Face(z, goal)
            if z:ZACanMelee(enemy, range) then E.Attack(z, enemy) end
        else
            local follow = settings.Follow
            local direction = goal - z:GetPos(); direction.z = 0
            -- A standoff point is only useful outside the authored follow band.
            -- Inside it, pursue the target until the melee/contact check succeeds.
            -- Subtracting the desired spacing here put the goal behind the actor
            -- and made him retreat/turn repeatedly when a player stood nearby.
            if not visible or direction:LengthSqr() <= (follow.Outer * z:GetModelScale()) ^ 2 then
                z.ZACloseGoal = visible and goal or nil
                z:ZAMove(goal, enemy)
            else
                z.ZACloseGoal = nil
                direction:Normalize()
                local spacing = z.ZAFireFollowDistance or (follow.DesiredMin + follow.DesiredMax) * .5
                local position = goal - direction * (spacing * z:GetModelScale())
                z:ZAMove(position, enemy)
            end
        end
        return true
    end
    if z.ZASpecial == "chainsaw" and visible and CurTime() >= (z.ZANextDash or 0)
        and distance >= settings.DashMinRange ^ 2 and distance <= settings.DashMaxRange ^ 2 then
        if z:ZATurnTowards(goal, enemy) then return true end
        N.Face(z, goal)
        if E.Dash(z, enemy) then return true end
    end
    return baseclass.Get("npc_dt_za1_zombie").ZACombat(z, enemy)
end
function E.Damage(z, info, tr)
    if info:IsDamageType(DMG_BURN) and (z.ZASpecial == "fire" or z.ZASpecial == "burning") then info:SetDamage(0); return true end
    if z.ZASpecial == "fire" and z.ZAFlameShield then
        info:SetDamage(0); M.Wake(z)
        local attacker = info:GetAttacker()
        if IsValid(attacker) and z:IsHatedEntity(attacker) then z:DetectEntity(attacker); M.Alert(z, attacker:GetPos()) end
        return true
    end
end
function E.PainHit(z, info)
    if z.ZASpecial ~= "chainsaw" and z.ZASpecial ~= "mg42" or info:GetDamage() <= 0 then return end
    local step = z:GetMaxHealth() * z.ZASpecialSettings.PainStep
    local stage = math.min(4, math.floor((z:GetMaxHealth() - math.max(0, z:Health() - info:GetDamage())) / step + .000001))
    local previous = z.ZASawPainStage or math.min(4, math.floor((z:GetMaxHealth() - z:Health()) / step + .000001))
    if stage > previous then
        z.ZASawPainStage = stage
        if info:GetDamage() < z:Health() and not z:IsPossessed() then
            z.ZAPainPending = true
            if z.ZASpecial == "mg42" then ZA1.Specials.Sound(z, "pain_" .. (100 - stage * 20), 80, true) end
        end
    end
end
function E.Flinch(z, info, tr)
    if not Able(z) or z.ZAActing or z:IsPossessed() or CurTime() < (z.ZANextFlinch or 0) then return end
    if z.ZASpecial == "chainsaw" or z.ZASpecial == "mg42" then
        if not z.ZAPainPending then return end
    elseif not info or info:GetDamage() >= z:Health() or info:GetDamage() < ZA1.Config.Flinch.MinDamage then return end
    local sequence = z.ZASpecialSettings.Flinch
    if not sequence then return end
    z.ZAPainPending = nil
    z.ZANextFlinch = CurTime() + z.ZASpecialSettings.FlinchCooldown
    Play(z, sequence)
    return true
end
function E.Event(z, event, time, cycle, typ, options)
    if not Active(z) then return true end
    if z.ZASpecial == "fire" and z.ZAAttacking then
        if event == 1100 and options == "za1_melee" then return true end
        if event == 1102 then
            local markers = z.ZASpecialAssets.Events[z:GetSequenceName(z:GetSequence())]
            if markers and markers[options] and markers[options].code == 2 then
                ZA1.Specials.Event(z, 1100, time, cycle, typ, "za1_melee"); return true
            end
        end
    end
    if z.ZASpecial == "fire" and z.ZAFireballTarget and event == 1102 then
        local marker = z.ZASpecialAssets.Events[z:GetSequenceName(z:GetSequence())]
        if marker and marker[options] and marker[options].code == 134217728 then E.Fireball(z, z.ZAFireballTarget); return true end
    end
    if z.ZASpecial == "chainsaw" and event == 1100 and options == "za1_melee" then return true end
    if event ~= 1101 then return end
    local sequence = z:GetSequenceName(z:GetSequence())
    local pool = z.ZASpecialAssets.Animations[sequence]; local binding = pool and pool[options]
    if not binding or not binding.Loop then return end
    if #binding.Files == 0 or not M.EventAudible(z) then return true end
    z.ZAEventLoops = z.ZAEventLoops or {}
    local key = sequence .. "/" .. options
    if not z.ZAEventLoops[key] then
        local sound = CreateSound(z, Pick(binding.Files))
        local vocal = ZA1.Specials.IsVocal(binding.Name) or binding.Voice
        sound:PlayEx(math.Rand(binding.Volume[1], binding.Volume[2]) * (vocal and z.VocalVolume or .55), 100)
        z.ZAEventLoops[key] = {Sound = sound, Sequence = sequence, End = binding.CycleEnd}
    end
    return true
end
function E.Tick(z)
    E.FireTimerTick(z)
    if not Able(z) then
        StopLoops(z)
        ZA1.FireVFX.Phase(z, "")
        if z.ZASpecial == "chainsaw" and IsValid(z) then VisualState(z, Active(z) and "idle" or "dead") end
        return
    end
    local blade = z.ZASpecial == "chainsaw" and z.ZAAttacking
    if not z.ZAEventLoops and not blade then return end
    local sequence = z:GetSequenceName(z:GetSequence())
    for key, loop in pairs(z.ZAEventLoops or {}) do
        if sequence ~= loop.Sequence or z:GetCycle() > loop.End or not M.EventAudible(z) then
            loop.Sound:Stop(); z.ZAEventLoops[key] = nil
        end
    end
    if z.ZAEventLoops and not next(z.ZAEventLoops) then z.ZAEventLoops = nil end
    if not blade or CurTime() < (z.ZANextSawHit or 0) then return end
    local windows, cycle = z.ZASpecialAssets.HitWindows[sequence], z:GetCycle()
    for _, window in ipairs(windows or {}) do
        if cycle >= window[1] and cycle <= window[2] then
            z.ZANextSawHit = CurTime() + z.ZASpecialSettings.HitInterval
            -- Reuse the checked melee hull/door hit and damage path. Repeated
            -- contact is limited to the native blade-active interval.
            z.ZALastMeleeEvent = nil
            ZA1.Specials.Event(z, 1100, 0, cycle, 0, "za1_melee")
            break
        end
    end
end
