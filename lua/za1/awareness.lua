-- One registry, spatial grid and hearing queue for the entire addon.
local M = {}
ZA1.Manager = M
local C = ZA1.Config.Performance
local CELL = 512
local IgnorePlayers, Disabled = GetConVar("ai_ignoreplayers"), GetConVar("ai_disabled")
local function Weak() return setmetatable({}, {__mode = "k"}) end
M.Zombies, M.Emitters, M.Hearing, M.Music = Weak(), Weak(), Weak(), Weak()
M.Grid, M.Buckets, M.Noises, M.Ragdolls, M.Players = {}, {}, {}, {}, {}
M.Total = 0
M.SpecialCounts = {skeleton = 0, suicide = 0, heavy = 0, fire = 0, burning = 0, chainsaw = 0, summoner = 0, sniper = 0, mg42 = 0, general = 0}
M.Stats = {hearingTraces = 0, decisions = 0, sightChecks = 0, musicPackets = 0}
local flags = FCVAR_ARCHIVE + FCVAR_REPLICATED
M.Wander = CreateConVar("za1_wander", "1", flags, "Allow idle zombie wandering.", 0, 1)
M.AlertRange = CreateConVar("za1_alert_range", "600", flags, "Nearby zombie alert distance.", 128, 1500)
M.Cap = CreateConVar("za1_population_cap", "100", flags, "Director common population limit; never exceeds 100 living zombies.", 8, 100)
M.InitialDensity = CreateConVar("za1_director_initial_density", tostring(ZA1.Config.Director.InitialDensity), flags, "Starting director target; limited by the common zombie cap.", 0, 100)
M.DensityPerMinute = CreateConVar("za1_director_density_per_minute", tostring(ZA1.Config.Director.DensityPerMinute), flags, "Additional target zombies per active minute; 0 keeps density constant.", 0, 100)
M.Radius = CreateConVar("za1_director_radius", tostring(ZA1.Config.Population.SpawnMaxDistance), flags, "Director radius around each living player.", 960, 8192)
M.SpawnMinRadius = CreateConVar("za1_director_spawn_min_radius", tostring(ZA1.Config.Population.SpawnMinDistance), flags, "Minimum spawn distance from every living player; kept below the maximum radius.", 128, 8192)
M.VisibleCommons = CreateConVar("za1_director_visible_commons", ZA1.Config.Population.VisibleCommonSpawns and "1" or "0", flags, "Allow common zombies to emerge in view; specials still spawn unseen.", 0, 1)
M.SpawnMode = CreateConVar("za1_director_spawn_mode", "0", flags, "Spawn source: 0 random navmesh, 1 prefer zones with fallback, 2 both, 3 zones only.", 0, 3)
M.ResurrectionEnabled = CreateConVar("za1_resurrection", "1", flags, "Allow common zombie resurrection; destroyed heads cannot resurrect.", 0, 1)
M.ResurrectionChance = CreateConVar("za1_resurrection_chance", tostring(ZA1.Config.Recovery.ResurrectionChance*100), flags, "Resurrection chance per fatal common body hit; destroyed heads never revive.", 0, 100)
M.MantleEnabled = CreateConVar("za1_mantle", "1", flags, "Allow standing zombies to mantle supported obstacles.", 0, 1)
M.MantleHeight = CreateConVar("za1_mantle_height", tostring(ZA1.Config.Obstacles.MantleMaxHeight), flags, "Maximum mantle height in Source units.", 32, 160)
M.DropEnabled = CreateConVar("za1_drop", "1", flags, "Allow soldiers and Suicide Grunts to jump into a controlled ragdoll drop.", 0, 1)
M.DropHeight = CreateConVar("za1_drop_height", tostring(ZA1.Config.Obstacles.DropMaxHeight), flags, "Maximum intentional drop height in Source units; capped at the authored 3.5 m jump.", 32, 138)
M.RetireDelay = CreateConVar("za1_recycle_delay", tostring(ZA1.Config.Population.SleepDelay), flags, "Seconds outside player radii and unseen before recycling.", 3, 60)
M.EventDistance = CreateConVar("za1_event_sound_distance", tostring(ZA1.Config.Audio.EventDistance), flags, "Maximum player distance for animation sounds; 0 disables culling.", 0, 4096)
M.DirectorEnabled = CreateConVar("za1_director_running", "1", flags, "Allow the Zombie Army director to populate the map.", 0, 1)
M.RagdollLife = CreateConVar("za1_ragdoll_lifetime", "45", flags, "Zombie ragdoll lifetime in seconds.", 10, 180)
M.RagdollCap = CreateConVar("za1_ragdoll_cap", "24", flags, "Maximum retained zombie ragdolls.", 0, 64)
M.Crowd = CreateConVar("za1_crowd", "1", flags, "Crowd spacing and stable attack positions.", 0, 1)
M.SharedRoutes = CreateConVar("za1_shared_routes", "1", flags, "Share coarse horde routes; keep individual native paths.", 0, 1)
M.Dormancy = CreateConVar("za1_dormancy", "1", flags, "Recycle unseen director zombies outside player radii.", 0, 1)
M.PathBudget = CreateConVar("za1_path_budget", tostring(ZA1.Config.Navigation.PathBuildsPerTick), flags, "Normal native path builds per server tick, within the time budget.", 1, 8)
M.PathBurst = CreateConVar("za1_path_burst", tostring(ZA1.Config.Navigation.PathBurstBuildsPerTick), flags, "Maximum native path builds when requests back up, within the same time budget.", 1, 16)
local specials = ZA1.SpecialConfig and ZA1.SpecialConfig.Director or {Chance = 15, SkeletonLimit = 4, SuicideLimit = 2, HeavyLimit = 2}
M.SpecialsEnabled = CreateConVar("za1_specials", "1", flags, "Allow director special enemies.", 0, 1)
M.SpecialChance = CreateConVar("za1_special_chance", tostring(specials.Chance), flags, "Percent of new director spawns selected as specials, within type limits.", 0, 50)
M.SkeletonLimit = CreateConVar("za1_skeleton_limit", tostring(specials.SkeletonLimit), flags, "Maximum director Skeletons, including reserved recycled actors.", 0, 12)
M.SuicideLimit = CreateConVar("za1_suicide_limit", tostring(specials.SuicideLimit), flags, "Maximum director Suicide Grunts, including reserved recycled actors.", 0, 6)
M.HeavyLimit = CreateConVar("za1_heavy_limit", tostring(specials.HeavyLimit), flags, "Maximum director Armored Heavies, including reserved recycled actors.", 0, 6)
M.FireLimit = CreateConVar("za1_fire_limit", tostring(specials.FireLimit or 1), flags, "Maximum director Fire Demons, including reserved actors.", 0, 6)
M.BurningLimit = CreateConVar("za1_burning_limit", tostring(specials.BurningLimit or 6), flags, "Maximum director Ignited Zombies; Fire Demon summons use its own minion limit.", 0, 20)
M.ChainsawLimit = CreateConVar("za1_chainsaw_limit", tostring(specials.ChainsawLimit or 1), flags, "Maximum director Chainsaw Elites, including reserved actors.", 0, 6)
M.SummonerLimit = CreateConVar("za1_summoner_limit", tostring(specials.SummonerLimit or 1), flags, "Maximum director Summoners, including reserved actors.", 0, 6)
M.SniperLimit = CreateConVar("za1_sniper_limit", tostring(specials.SniperLimit or 2), flags, "Maximum director Deadeye Snipers, including reserved actors.", 0, 6)
M.MG42Limit = CreateConVar("za1_mg42_limit", tostring(specials.MG42Limit or 2), flags, "Maximum director MG42 Elites, including reserved actors.", 0, 6)
M.GeneralLimit = CreateConVar("za1_general_limit", tostring(specials.GeneralLimit or 1), flags, "Maximum director Occult Generals, including reserved actors.", 0, 2)
util.AddNetworkString("ZA1/Music")
util.AddNetworkString("ZA1/Setting")
local settings = {za1_wander={0,1},za1_alert_range={128,1500},za1_population_cap={8,100},za1_director_initial_density={0,100},za1_director_density_per_minute={0,100},za1_director_running={0,1},za1_director_radius={960,8192},za1_recycle_delay={3,60},za1_event_sound_distance={0,4096},za1_ragdoll_lifetime={10,180},za1_ragdoll_cap={0,64},
    za1_director_spawn_min_radius={128,8192},za1_director_visible_commons={0,1},
    za1_director_spawn_mode={0,3},za1_resurrection={0,1},za1_resurrection_chance={0,100},za1_mantle={0,1},za1_mantle_height={32,160},
    za1_drop={0,1},za1_drop_height={32,138},
    za1_crowd={0,1},za1_shared_routes={0,1},za1_dormancy={0,1},za1_path_budget={1,8},za1_path_burst={1,16},
    za1_specials={0,1},za1_special_chance={0,50},za1_skeleton_limit={0,12},za1_suicide_limit={0,6},za1_heavy_limit={0,6},
    za1_fire_limit={0,6},za1_burning_limit={0,20},za1_chainsaw_limit={0,6},za1_summoner_limit={0,6},
    za1_sniper_limit={0,6},za1_mg42_limit={0,6},za1_general_limit={0,2}}
net.Receive("ZA1/Setting", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    local name, value = net.ReadString(), net.ReadFloat()
    local limits = settings[name]
    if limits and value == value then
        value = math.Clamp(math.Round(value), limits[1], limits[2])
        if name == "za1_director_spawn_min_radius" then value = math.min(value, math.Clamp(M.Radius:GetFloat(), 960, 8192) - 64) end
        GetConVar(name):SetFloat(value)
        if name == "za1_director_radius" and M.SpawnMinRadius:GetFloat() >= value - 64 then M.SpawnMinRadius:SetFloat(value - 64) end
        if name == "za1_director_running" and IsValid(M.Director) then M.Director:SetRunning(M.DirectorEnabled:GetBool()) end
    end
end)
function M.Active(z)
    return IsValid(z) and z:Alive() and not z.ZADowned and not z.__DT_PhysgunPickup and not z:IsPossessed() and not z:IsAIDisabled()
end
function M.InstallSight()
    if M.SightHook then return true end
    -- Install after map initialization, with first-spawn fallback for late loads.
    -- Keep the same hook slot and its original callback for every other bot;
    -- a second sight hook would still run DT's unbudgeted visibility checks.
    local callbacks = hook.GetTable()["DT/UpdateNextBotTarget"]
    local original = callbacks and callbacks["DT/UpdateSight"]
    if type(original) ~= "function" then return false end
    M.SightHook = function(nb, ent, ...)
        if nb.ZA1Zombie then
            nb:ZAUpdateSight(ent)
            -- This hook must not return the sight boolean and stop DT's other
            -- relationship/detection callbacks in hook.Run.
        else return original(nb, ent, ...) end
    end
    hook.Add("DT/UpdateNextBotTarget", "DT/UpdateSight", M.SightHook)
    return true
end
hook.Add("InitPostEntity", "ZA1/Sight", function() M.InstallSight() end)
function M.Register(z)
    if not M.Zombies[z] then
        M.Total = M.Total + 1
        if z.ZASpecial then M.SpecialCounts[z.ZASpecial] = (M.SpecialCounts[z.ZASpecial] or 0) + 1 end
    end
    M.Zombies[z] = z.ZASpecial or true
    z.ZAHome = z.ZAHome or Vector(z:GetPos())
    z.ZADecisionEnemy = z:GetEnemy()
    z.ZANextDecision = CurTime() + math.Rand(0, C.MediumDecisionInterval)
    if ZA1.Performance then ZA1.Performance.ProfileActor(z) end
end
function M.Unregister(z)
    if ZA1.Performance then ZA1.Performance.UnprofileActor(z) end
    if M.Zombies[z] then
        M.Total = math.max(0, M.Total - 1)
        local kind = M.Zombies[z]
        if type(kind) == "string" then M.SpecialCounts[kind] = math.max(0, (M.SpecialCounts[kind] or 0) - 1) end
    end
    M.Zombies[z], M.Hearing[z] = nil, nil
    if ZA1.Obstacles then ZA1.Obstacles.Clear(z) end
    if ZA1.Navigation then ZA1.Navigation.Cancel(z) end
    if ZA1.Crowd then ZA1.Crowd.Release(z) end
    if not IsValid(z) then return end
    if IsValid(z.ZADirector) then z.ZADirector.ZAOwned[z] = nil end
end
hook.Add("DT/CleanupNextBot", "ZA1/Unregister", function(z)
    if M.Zombies[z] or IsValid(z) and z.ZA1Zombie then M.Unregister(z) end
end)
function M.Wake(z)
    z.ZANextDecision, z.ZANextSight = 0, 0
    z.ZASenseCache = nil
end
function M.Investigate(z, pos, duration)
    z.ZAInvestigation = {position = Vector(pos), expires = CurTime() + duration}
    M.Wake(z)
end
function M.Rebuild()
    for _, bucket in ipairs(M.Buckets) do for i = #bucket, 1, -1 do bucket[i] = nil end end
    M.Players = player.GetHumans()
    for z in pairs(M.Zombies) do
        if IsValid(z) and z:Alive() then
            local pos = z:GetPos()
            z.ZASnapshot = Vector(pos)
            local x, y = math.floor(pos.x / CELL), math.floor(pos.y / CELL)
            local row = M.Grid[x]
            if not row then row = {}; M.Grid[x] = row end
            local bucket = row[y]
            if not bucket then bucket = {}; row[y] = bucket; M.Buckets[#M.Buckets + 1] = bucket end
            bucket[#bucket + 1] = z
            local distance = math.huge
            for _, ply in ipairs(M.Players) do
                if IsValid(ply) and ply:Alive() then distance = math.min(distance, pos:DistToSqr(ply:GetPos())) end
            end
            z.ZAPlayerDistance = distance
        else M.Unregister(z) end
    end
end
function M.Near(pos, radius, func)
    local square = radius * radius
    for x = math.floor((pos.x - radius) / CELL), math.floor((pos.x + radius) / CELL) do
        local row = M.Grid[x]
        if row then
            for y = math.floor((pos.y - radius) / CELL), math.floor((pos.y + radius) / CELL) do
                local bucket = row[y]
                if bucket then
                    for _, z in ipairs(bucket) do
                        if M.Active(z) and (z.ZASnapshot or z:GetPos()):DistToSqr(pos) <= square then func(z) end
                    end
                end
            end
        end
    end
end
function M.Intervals(z)
    local distance = z.ZAPlayerDistance or math.huge
    local enemy = z:GetEnemy()
    if IsValid(enemy) then distance = math.min(distance, z:GetPos():DistToSqr(enemy:GetPos())) end
    if distance < C.NearDistance ^ 2 then return C.NearDecisionInterval, ZA1.Config.Navigation.SightInterval end
    if distance < C.FarDistance ^ 2 then return C.MediumDecisionInterval, C.MediumSightInterval end
    return C.FarDecisionInterval, C.FarSightInterval
end
function M.Visible(z, target)
    z.ZASenseCache = z.ZASenseCache or Weak()
    local cached = z.ZASenseCache[target]
    if cached and CurTime() < cached.expires then return cached.visible end
    local tick = engine.TickCount()
    if M.SightTick ~= tick then M.SightTick, M.SightLeft = tick, C.SightTracesPerTick end
    if M.SightLeft <= 0 then return cached and cached.visible or false end
    M.SightLeft = M.SightLeft - 1
    local visible = z:Visible(target)
    local _, interval = M.Intervals(z)
    z.ZASenseCache[target] = {visible = visible, expires = CurTime() + interval}
    M.Stats.sightChecks = M.Stats.sightChecks + 1
    return visible
end
function M.Alert(source, pos)
    if not M.Active(source) or CurTime() < (source.ZANextAlert or 0) then return end
    source.ZANextAlert = CurTime() + 3
    M.Near(source:GetPos(), M.AlertRange:GetFloat(), function(z)
        if z ~= source and not z:HasEnemy() then M.Investigate(z, pos, 9) end
    end)
end
function M.Noise(emitter, pos, range)
    if M.Total == 0 or Disabled:GetBool() or not isvector(pos) then return end
    if IsValid(emitter) then
        if emitter.ZA1Zombie or IsValid(emitter.ZARecoveryOwner) and emitter.ZARecoveryOwner.ZA1Zombie
            or emitter:IsPlayer() and (IgnorePlayers:GetBool() or not emitter:Alive()) then return end
        local previous = M.Emitters[emitter]
        if previous and CurTime() < previous.time + 0.2 then
            previous.range, previous.position = math.max(previous.range, range), Vector(pos)
            return
        end
    end
    if #M.Noises >= 32 then return end
    local event = {position = Vector(pos), range = math.Clamp(range, 0, 2400), emitter = emitter, time = CurTime()}
    M.Noises[#M.Noises + 1] = event
    if IsValid(emitter) then M.Emitters[emitter] = event end
end
local function QueueHearing(event)
    M.Near(event.position, event.range, function(z)
        if z:HasEnemy() then return end
        local distance = (z.ZASnapshot or z:GetPos()):DistToSqr(event.position)
        local score = event.range * event.range / math.max(distance, 1)
        local previous = M.Hearing[z]
        if not previous or score >= previous.score or CurTime() - previous.event.time > C.HearingLifetime then
            M.Hearing[z] = {event = event, score = score, queued = previous and previous.queued or CurTime()}
        end
    end)
end
function M.ProcessHearing()
    local deadline = SysTime() + C.HearingBudgetMS / 1000
    for i = 1, C.HearingTracesPerTick do
        local chosen, job, oldest
        for z, pending in pairs(M.Hearing) do
            if not M.Active(z) or z:HasEnemy() or CurTime() - pending.event.time > C.HearingLifetime then M.Hearing[z] = nil
            elseif not oldest or pending.queued < oldest then chosen, job, oldest = z, pending, pending.queued end
        end
        if not chosen then break end
        M.Hearing[chosen] = nil
        local event = job.event
        local trace = util.TraceLine({start = chosen:WorldSpaceCenter(), endpos = event.position, mask = MASK_SOLID_BRUSHONLY, filter = chosen})
        M.Stats.hearingTraces = M.Stats.hearingTraces + 1
        local radius = trace.Hit and event.range * 0.4 or event.range
        if chosen:GetPos():DistToSqr(event.position) <= radius * radius then M.Investigate(chosen, event.position, 8) end
        if SysTime() >= deadline then break end
    end
end
hook.Add("EntityEmitSound", "ZA1/Hearing", function(data)
    if M.Total == 0 then return end
    local emitter = data.Entity
    if IsValid(emitter) and emitter:IsWeapon() and IsValid(emitter:GetOwner()) then emitter = emitter:GetOwner() end
    local level = data.SoundLevel or 75
    if level >= 65 then
        local pos = data.Pos or (IsValid(emitter) and emitter:GetPos())
        if pos then M.Noise(emitter, pos, (level - 50) * 35 * (data.Volume or 1)) end
    end
end)
hook.Add("PlayerFootstep", "ZA1/FootstepHearing", function(ply, pos)
    M.Noise(ply, pos, ply:Crouching() and 180 or ply:GetVelocity():Length2D() > 180 and 650 or 400)
end)
hook.Add("PostEntityFireBullets", "ZA1/GunshotHearing", function(ent, data)
    M.Noise(ent:IsWeapon() and ent:GetOwner() or ent, data.Src or ent:GetPos(), 2200)
end)
function M.Count() return M.Total end
function M.PopulationLimit() return math.Clamp(M.Cap:GetInt(), 1, ZA1.Config.Director.MaxCommon) end
-- Sandbox activates after Spawn even if Initialize removes an entity. Reject
-- menu requests first; Initialize also guards scripted/duplicator creation.
local commonClasses = {npc_dt_za1_zombie = true, npc_dt_za1_zombie_camo = true, npc_dt_za1_zombie_camo2 = true,
    npc_dt_za1_skeleton = true, npc_dt_za1_armored_skeleton = true, npc_dt_za1_rotten_skeleton = true,
    npc_dt_za1_suicide_grunt = true, npc_dt_za1_armored_heavy = true,
    npc_dt_za1_fire_demon = true, npc_dt_za1_burning_zombie = true,
    npc_dt_za1_chainsaw_elite = true, npc_dt_za1_summoner = true}
hook.Add("PlayerSpawnNPC", "ZA1/SpawnLimit", function(_, class)
    if commonClasses[class] and M.Count() >= ZA1.Config.Director.MaxCommon then return false end
    if class == "sent_za1_director" and IsValid(M.Director) then return false end
end)
function M.EventAudible(z)
    local range, now = M.EventDistance:GetFloat(), CurTime()
    if range <= 0 then return true end
    if z.ZAEventRange == range and now < (z.ZANextEventDistance or 0) then return z.ZAEventAudible end
    local pos, audible = z:GetPos(), false
    for _, ply in ipairs(M.Players) do
        if IsValid(ply) and pos:DistToSqr(ply:GetPos()) <= range * range then audible = true; break end
    end
    z.ZAEventRange, z.ZAEventAudible = range, audible
    z.ZANextEventDistance = now + ZA1.Config.Audio.EventDistanceInterval
    return audible
end
function M.Killed(z)
    if IsValid(z.ZADirector) then z.ZADirector:RecordKill(z)
    elseif IsValid(M.Director) then M.Director:RecordKill(z) end
    M.Unregister(z)
end
function M.Ragdoll(rag)
    if not IsValid(rag) then return end
    rag.ZAExpires = CurTime() + M.RagdollLife:GetFloat()
    M.Ragdolls[#M.Ragdolls + 1] = rag
    while #M.Ragdolls > M.RagdollCap:GetInt() do
        local oldest = table.remove(M.Ragdolls, 1)
        if IsValid(oldest) then oldest:Remove() end
    end
end
local function MusicState(ply)
    local count, fighting, close, pos = 0, 0, 0, ply:GetPos()
    M.Near(pos, 2200, function(z)
        count = count + 1
        if z:GetEnemy() == ply then fighting = fighting + 1 end
        if (z.ZASnapshot or z:GetPos()):DistToSqr(pos) < 350 ^ 2 then close = close + 1 end
    end)
    local injury = math.max(0, (ply.ZALastHurt or 0) + 5 - CurTime()) / 5
    return math.Clamp(math.Clamp(fighting / 12 + close / 16 + injury * 0.35, 0, 1) * 0.7 + math.Clamp(count / 32, 0, 1) * 0.3, 0, 1), count
end
hook.Add("EntityTakeDamage", "ZA1/DirectorPressure", function(ent, info)
    local attacker = info:GetAttacker()
    if ent:IsPlayer() and IsValid(attacker) and attacker.ZA1Zombie and info:GetDamage() > 0 then
        ent.ZALastHurt = CurTime()
        if IsValid(M.Director) then M.Director.ZAPlayerPressure = math.min(1, (M.Director.ZAPlayerPressure or 0) + 0.2) end
    end
end)
local nextGrid, nextMusic, nextCleanup = 0, 0, 0
hook.Add("Think", "ZA1/SharedTick", function()
    local now = CurTime()
    if now >= nextGrid then
        nextGrid = now + C.GridInterval
        M.Rebuild()
        local noises = M.Noises; M.Noises = {}
        for _, event in ipairs(noises) do if now - event.time <= C.HearingLifetime then QueueHearing(event) end end
    end
    M.ProcessHearing()
    if now >= nextCleanup then
        nextCleanup = now + 1
        for i = #M.Ragdolls, 1, -1 do
            local rag = M.Ragdolls[i]
            if not IsValid(rag) or now >= rag.ZAExpires then
                if IsValid(rag) then rag:Remove() end
                table.remove(M.Ragdolls, i)
            end
        end
    end
    if now >= nextMusic then
        nextMusic = now + 1
        for _, ply in ipairs(player.GetHumans()) do
            local intensity, count = MusicState(ply)
            local active = ply:Alive() and not IgnorePlayers:GetBool() and not Disabled:GetBool() and (count > 0 or IsValid(M.Director) and M.Director:GetRunning())
            local previous = M.Music[ply]
            if not previous or previous.active ~= active or previous.count ~= count or math.abs(previous.intensity - intensity) >= 0.015 or now - previous.time >= 2 then
                net.Start("ZA1/Music"); net.WriteBool(active); net.WriteFloat(intensity); net.WriteUInt(count, 16); net.Send(ply)
                M.Music[ply] = {active = active, count = count, intensity = intensity, time = now}
                M.Stats.musicPackets = M.Stats.musicPackets + 1
            end
        end
    end
end)
hook.Add("PostCleanupMap", "ZA1/Cleanup", function()
    M.Noises, M.Grid, M.Buckets, M.Emitters, M.Hearing, M.Music = {}, {}, {}, Weak(), Weak(), Weak()
    M.Rebuild()
end)
