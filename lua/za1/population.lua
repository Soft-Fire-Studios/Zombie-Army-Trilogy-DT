-- Only owned, unseen actors outside every living player's radius are recycled.
local P = {}
ZA1.Population = P
local C, M, N = ZA1.Config.Population, ZA1.Manager, ZA1.Navigation
local visibilityHeights = {10, 40, 72}
P.Stats = {retired = 0, restored = 0, spawnChecks = 0, spawnRejects = 0, candidateChecks = 0, candidateMS = 0}
P.Stats.spawnPending, P.Stats.spawnRadiusRejects, P.Stats.spawnVisibilityRejects = 0, 0, 0
P.Stats.spawnNavRejects, P.Stats.spawnGroundRejects = 0, 0
local commonClasses = {npc_dt_za1_zombie = true, npc_dt_za1_zombie_camo = true, npc_dt_za1_zombie_camo2 = true}
function P.VisibleSpawn(class)
    return M.VisibleCommons:GetBool() and commonClasses[class or "npc_dt_za1_zombie"] == true
end
function P.SpawnRadii()
    local maximum = math.Clamp(M.Radius:GetFloat(), 960, 8192)
    -- Leave at least one full common hull's width inside the spawn ring.
    return math.Clamp(M.SpawnMinRadius:GetFloat(), 128, maximum - 64), maximum
end
function P.SpawnProfile(class)
    local profile = N.Profile()
    local stored = scripted_ents.GetStored(class or "npc_dt_za1_zombie")
    local definition = stored and stored.t
    if definition then profile.height, profile.width = definition.Height or profile.height, definition.Width or profile.width end
    profile.key = profile.step .. ":" .. profile.drop .. ":" .. profile.height .. ":" .. profile.width
    return profile
end
P.CandidateTasks, P.CandidateCursor = {}, 1
local function ValidTask(cache)
    return IsValid(cache.director) and IsValid(cache.player)
        and cache.director.ZASpawnCache[cache.player] == cache and cache.generation == N.Generation
end
function P.ScanCandidates()
    if #P.CandidateTasks == 0 then return end
    local started = SysTime()
    local deadline, checked = started + C.CandidateScanBudgetMS / 1000, 0
    while #P.CandidateTasks > 0 and checked < C.CandidateAreasPerTick and SysTime() < deadline do
        local index = (P.CandidateCursor - 1) % #P.CandidateTasks + 1
        local cache = P.CandidateTasks[index]
        if not ValidTask(cache) or cache.scan.complete then table.remove(P.CandidateTasks, index)
        else
            checked = checked + N.ScanLocalAreas(cache.scan, math.min(32, C.CandidateAreasPerTick - checked), deadline)
            if cache.scan.complete then cache.expires = CurTime() + C.CandidateLifetime end
            P.CandidateCursor = index + 1
        end
    end
    P.Stats.candidateChecks = P.Stats.candidateChecks + checked
    P.Stats.candidateMS = P.Stats.candidateMS + (SysTime() - started) * 1000
end
hook.Add("Think", "ZA1/SpawnCandidates", P.ScanCandidates)
hook.Add("PostCleanupMap", "ZA1/SpawnCandidates", function() P.CandidateTasks, P.CandidateCursor = {}, 1 end)
function P.Setup(director)
    director.ZADormant, director.ZAActors, director.ZASpawnCache = {}, {}, setmetatable({}, {__mode = "k"})
    director.ZAActorCursor, director.ZADormantCursor = 1, 1
    director.ZASpawnCursor = 0
end
function P.Own(director, z)
    if not director.ZAOwned[z] then director.ZAActors[#director.ZAActors + 1] = z end
    director.ZAOwned[z], z.ZADirector = true, director
end
local function Nearest(pos, players, positions)
    local closest, distance = nil, math.huge
    for _, ply in ipairs(players) do
        local square = pos:DistToSqr(positions and positions[ply] or ply:GetPos())
        if square < distance then closest, distance = ply, square end
    end
    return closest, distance
end
function P.Hidden(pos, viewers)
    for _, ply in ipairs(viewers) do
        if IsValid(ply) then
            -- Check feet, torso and head; center-only tests can expose a spawn.
            for _, height in ipairs(visibilityHeights) do
                if ply:VisibleVec(pos + Vector(0, 0, height)) then return false end
            end
        end
    end
    return true
end
function P.ClearGround(pos, filter, profile)
    local ground = util.TraceLine({start = pos + Vector(0, 0, 24), endpos = pos - Vector(0, 0, 96), mask = MASK_NPCSOLID_BRUSHONLY, filter = filter})
    if not ground.Hit or ground.StartSolid or ground.HitNormal.z < 0.6 then return end
    pos = ground.HitPos + Vector(0, 0, 2)
    local width, height = profile and profile.width + 2 or 16, profile and profile.height or 74
    local hull = util.TraceHull({start = pos, endpos = pos, mins = Vector(-width, -width, 2), maxs = Vector(width, width, height), mask = MASK_NPCSOLID, filter = filter, collisiongroup = COLLISION_GROUP_NPC})
    if not hull.Hit and not hull.StartSolid then return pos end
end
local function OnNav(area, pos, profile)
    return IsValid(area) and area:Contains(pos)
        and math.abs(area:GetClosestPointOnArea(pos).z - pos.z) <= profile.step
end
local function RandomCandidate(director,players,positions,radius,deadline)
    director.ZASpawnCursor=(director.ZASpawnCursor or 0)%#players+1
    local target=players[director.ZASpawnCursor];local center=positions[target]
    local cached=director.ZASpawnCache[target]
    if not cached or cached.radius~=radius or cached.generation~=N.Generation
        or cached.scan.complete and CurTime()>=cached.expires or center:DistToSqr(cached.position)>512^2 then
        local scan=N.LocalAreaScan(center,radius)
        cached={position=Vector(center),radius=radius,areas=scan.areas,scan=scan,generation=N.Generation,
            director=director,player=target,expires=math.huge}
        director.ZASpawnCache[target]=cached;P.CandidateTasks[#P.CandidateTasks+1]=cached
        local checked=N.ScanLocalAreas(scan,C.CandidateAreasPerTick,math.min(deadline,SysTime()+C.CandidateScanBudgetMS/1000))
        P.Stats.candidateChecks=P.Stats.candidateChecks+checked
        if scan.complete then cached.expires=CurTime()+C.CandidateLifetime end
    end
    if #cached.areas>0 then
        cached.cursor=cached.cursor or math.random(#cached.areas)
        local area=cached.areas[cached.cursor];cached.cursor=cached.cursor%#cached.areas+1
        if IsValid(area) then
            if area:IsBlocked() or area:IsUnderwater() then return area end
            return area,area:GetRandomPoint()
        end
    elseif not cached.scan.complete then P.Stats.spawnPending=P.Stats.spawnPending+1 end
end
function P.FindSpawn(director, players, class, deadline, profile)
    N.Begin()
    if #players == 0 then return end
    if not N.GraphReady then P.Stats.spawnPending = P.Stats.spawnPending + 1; return end
    local visible = P.VisibleSpawn(class)
    local viewers = not visible and player.GetHumans()
    local minimum, radius = P.SpawnRadii()
    profile = profile or P.SpawnProfile(class)
    local positions = {}; for _, ply in ipairs(players) do positions[ply] = ply:GetPos() end
    deadline = math.min(deadline or math.huge, SysTime() + C.WorkBudgetMS / 1000)
    local mode=M.SpawnMode:GetInt()
    director.ZASpawnMixed=not director.ZASpawnMixed
    local zoneFirst=mode==1 or mode==3 or mode==2 and director.ZASpawnMixed
    -- Cache local candidates and shared reachability, never final LOS/occupancy.
    for attempt = 1, C.SpawnCandidates do
        if SysTime() >= deadline then break end
        local area,pos,zone
        local useZone=mode==3 or zoneFirst and attempt<=math.floor(C.SpawnCandidates/2)
            or mode==2 and not zoneFirst and attempt>math.floor(C.SpawnCandidates/2)
        if useZone and ZA1.SpawnZones then area,pos,zone=ZA1.SpawnZones.Candidate(players,minimum,radius) end
        if not area and mode~=3 then area,pos=RandomCandidate(director,players,positions,radius,deadline) end
        if area then
            if IsValid(area) and not area:IsBlocked() and not area:IsUnderwater() then
                local nearest, distance = Nearest(pos, players, positions)
                P.Stats.spawnChecks = P.Stats.spawnChecks + 1
                if distance >= minimum ^ 2 and distance <= radius ^ 2 then
                    local routeTarget = nearest
                    local reachable = N.Reachable(area, positions[nearest], profile)
                    local ground = reachable == true and P.ClearGround(pos, nil, profile)
                    if ground and OnNav(area, ground, profile) and (not zone or ZA1.SpawnZones.Contains(zone,ground)) then
                        nearest, distance = Nearest(ground, players, positions)
                        if distance >= minimum ^ 2 and distance <= radius ^ 2 then
                            if nearest ~= routeTarget then reachable = N.Reachable(area, positions[nearest], profile) end
                            if reachable == true then
                                if visible or P.Hidden(ground, viewers) then return ground, nearest end
                                P.Stats.spawnVisibilityRejects = P.Stats.spawnVisibilityRejects + 1
                            elseif reachable == nil then P.Stats.spawnPending = P.Stats.spawnPending + 1
                            else P.Stats.spawnNavRejects = P.Stats.spawnNavRejects + 1 end
                        else P.Stats.spawnRadiusRejects = P.Stats.spawnRadiusRejects + 1 end
                    elseif reachable == nil then P.Stats.spawnPending = P.Stats.spawnPending + 1
                    elseif reachable == false then P.Stats.spawnNavRejects = P.Stats.spawnNavRejects + 1
                    else P.Stats.spawnGroundRejects = P.Stats.spawnGroundRejects + 1 end
                else P.Stats.spawnRadiusRejects = P.Stats.spawnRadiusRejects + 1 end
            else P.Stats.spawnNavRejects = P.Stats.spawnNavRejects + 1 end
        end
    end
    P.Stats.spawnRejects = P.Stats.spawnRejects + 1
end
function P.Protected(z)
    if not M.Active(z) or z.ZAActing or CurTime() - (z.ZALastDamage or -math.huge) < C.RecentDamageProtection then return true end
    local enemy = z:GetEnemy()
    return IsValid(enemy) and CurTime() - (z:LastTimeDetected(enemy) or 0) <= ZA1.Config.Navigation.MemoryDuration
end
function P.Capture(z)
    local groups = {}
    local armor = ZA1.Specials and ZA1.Specials.Armor(z)
    for group = 0, z:GetNumBodyGroups()-1 do groups[group] = z:GetBodygroup(group) end
    return {class = z:GetClass(), position = Vector(z:GetPos()), angles = z:GetAngles(), health = z:Health(), maxHealth = z:GetMaxHealth(),
        skin = z:GetSkin(), scale = z:GetModelScale(), groups = groups, idle = z.IdleAnimation, walk = z.WalkAnimation, run = z.RunAnimation,
        baseIdle=z.ZABaseIdle, baseWalk=z.ZABaseWalk, crawling=z.ZACrawling,
        home = z.ZAHome and Vector(z.ZAHome), investigation = z.ZAInvestigation, wander = z.ZAWanderGoal and Vector(z.ZAWanderGoal),
        wanderUntil = z.ZAWanderUntil, nextWander = z.ZANextWander, navProfile = z.ZANavProfile,
        armorHealth = armor and armor.Capture(z) or nil}
end
function P.Retire(director, z)
    if not director.ZAOwned[z] or P.Protected(z) or #director.ZADormant >= C.MaxDormant then return false end
    local record = P.Capture(z); record.relocate = true
    director.ZADormant[#director.ZADormant + 1] = record
    director.ZAOwned[z], z.ZADirector = nil, nil
    z.ZAHibernating = true
    z:Remove() -- No damage/death callback, kill credit, ragdoll or escalation.
    P.Stats.retired = P.Stats.retired + 1
    return true
end
function P.Restore(director, record, players)
    if M.Count() >= M.PopulationLimit() or record.health <= 0 then return false end
    local profile = record.navProfile or P.SpawnProfile(record.class)
    local pos, target
    if record.relocate then pos, target = P.FindSpawn(director, players, record.class, nil, profile)
    else
        target = Nearest(record.position, players)
        local area = N.Area(record.position)
        if not target or not area or area:IsBlocked() or N.Reachable(area, target:GetPos(), profile) ~= true then return false end
        pos = P.ClearGround(record.position, nil, profile)
        local minimum, maximum = P.SpawnRadii()
        local _, distance = Nearest(pos or record.position, players)
        if pos and (not OnNav(area, pos, profile)
            or not distance or distance < minimum ^ 2 or distance > maximum ^ 2
            or not P.VisibleSpawn(record.class) and not P.Hidden(pos, player.GetHumans())) then pos = nil end
    end
    if not pos or not IsValid(target) then return false end
    local z = ents.Create(record.class)
    if not IsValid(z) then return false end
    z.ZAWeapon = record.groups[ZA1.Config.Equipment.WeaponBodygroup] or 0
    if record.relocate or P.VisibleSpawn(record.class) then z.ZAEmerge = ZA1.Specials and ZA1.Specials.Emerge(record.class) or ZA1.Config.Animations.Emerge[math.random(#ZA1.Config.Animations.Emerge)] end
    z:SetPos(pos); z:SetAngles(record.angles); z:Spawn()
    if not IsValid(z) then return false end
    z:SetMaxHealth(record.maxHealth); z:SetHealth(record.health); z:SetSkin(record.skin); z:SetModelScale(record.scale)
    for group = 0, z:GetNumBodyGroups()-1 do z:SetBodygroup(group, record.groups[group] or 0) end
    local armor = ZA1.Specials and ZA1.Specials.Armor(z)
    if armor then armor.Restore(z, record.armorHealth) end
    if z.ZASpecial then z:ZARefreshHitboxes() else ZA1.Equipment.Refresh(z) end
    z.IdleAnimation, z.WalkAnimation, z.RunAnimation, z.FallAnimation = record.idle, record.walk, record.run or record.walk, record.idle
    z.ZABaseIdle,z.ZABaseWalk=record.baseIdle or record.idle,record.baseWalk or record.walk
    z.ZACrawling=record.crawling
    if not z.ZASpecial then z.ZASeverMask=nil;ZA1.Dismemberment.Update(z,true) end
    if record.relocate then
        z.ZAHome, z.ZAWanderGoal = Vector(pos), nil
        M.Investigate(z, target:GetPos(), 20)
    else
        z.ZAHome, z.ZAInvestigation, z.ZAWanderGoal = record.home, record.investigation, record.wander
        z.ZAWanderUntil, z.ZANextWander = record.wanderUntil, record.nextWander
    end
    P.Own(director, z); M.Wake(z)
    P.Stats.restored = P.Stats.restored + 1
    return true
end
function P.Tick(director, players, spawnTarget)
    if #players == 0 then return end
    local changes, actors, records = 0, director.ZAActors, director.ZADormant
    local now, deadline = CurTime(), SysTime() + C.WorkBudgetMS / 1000
    local viewers, positions = player.GetHumans(), {}
    for _, ply in ipairs(players) do positions[ply] = ply:GetPos() end
    -- Restore pending replacements first; retirement reserves a future slot.
    local restoreLimit = math.min(M.PopulationLimit(), spawnTarget or director:GetDensityTarget())
    for i = 1, math.min(C.ChecksPerTick, #records) do
        if #records == 0 or changes >= C.ChangesPerTick or M.Count() >= restoreLimit or SysTime() >= deadline then break end
        local index = (director.ZADormantCursor - 1) % #records + 1
        local record = records[index]
        local _, distance = Nearest(record.position, players, positions)
        if (record.relocate or not M.Dormancy:GetBool() or distance < C.WakeDistance ^ 2) and P.Restore(director, record, players) then
            table.remove(records, index); changes = changes + 1
        else director.ZADormantCursor = index + 1 end
    end
    local radiusSquare = math.Clamp(M.Radius:GetFloat(), 960, 8192) ^ 2
    -- At most 100 owned actors: refresh distances cheaply, sample LOS separately.
    local index = 1
    while index <= #actors do
        local z = actors[index]
        if not IsValid(z) or not director.ZAOwned[z] then table.remove(actors, index)
        else
            local _, distance = Nearest(z:GetPos(), players, positions)
            z.ZAPlayerDistance = distance
            if distance <= radiusSquare or not M.Dormancy:GetBool() or P.Protected(z) then z.ZAFarSince = nil end
            index = index + 1
        end
    end
    if not M.Dormancy:GetBool() then return end
    for i = 1, math.min(C.ChecksPerTick, #actors) do
        if SysTime() >= deadline then break end
        local cursor = (director.ZAActorCursor - 1) % #actors + 1
        director.ZAActorCursor = cursor + 1
        local z = actors[cursor]
        if z.ZAPlayerDistance > radiusSquare and not P.Protected(z) and P.Hidden(z:GetPos(), viewers) then
            z.ZAFarSince = z.ZAFarSince or now
        else z.ZAFarSince = nil end
    end
    -- Furthest eligible actors go first. Recheck visibility before removing.
    for attempt = 1, C.ChecksPerTick do
        if changes >= C.ChangesPerTick or SysTime() >= deadline then break end
        local chosen, farthest
        for _, z in ipairs(actors) do
            if IsValid(z) and director.ZAOwned[z] and z.ZAFarSince and now - z.ZAFarSince >= M.RetireDelay:GetFloat()
                and z.ZAPlayerDistance > radiusSquare and (not farthest or z.ZAPlayerDistance > farthest) then
                chosen, farthest = z, z.ZAPlayerDistance
            end
        end
        if not chosen then break end
        if not P.Protected(chosen) and P.Hidden(chosen:GetPos(), viewers) and P.Retire(director, chosen) then
            changes = changes + 1
        else chosen.ZAFarSince = nil end
    end
end
function P.NearbyDormant(director, players)
    local count = 0
    for _, record in ipairs(director.ZADormant) do
        local _, distance = Nearest(record.position, players)
        if distance < C.WakeDistance ^ 2 then count = count + 1 end
    end
    return count
end
hook.Add("PostCleanupMap", "ZA1/Population", function()
    if IsValid(M.Director) then P.Setup(M.Director) end
end)
