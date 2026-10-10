-- Only owned, unseen actors outside every living player's radius are recycled.
local P = {}
ZA1.Population = P
local C, M, N = ZA1.Config.Population, ZA1.Manager, ZA1.Navigation
local visibilityHeights = {10, 40, 72}
P.Stats = {retired = 0, restored = 0, spawnChecks = 0, spawnRejects = 0}
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
function P.ClearGround(pos, filter)
    local ground = util.TraceLine({start = pos + Vector(0, 0, 24), endpos = pos - Vector(0, 0, 96), mask = MASK_NPCSOLID_BRUSHONLY, filter = filter})
    if not ground.Hit or ground.StartSolid or ground.HitNormal.z < 0.6 then return end
    pos = ground.HitPos + Vector(0, 0, 2)
    local hull = util.TraceHull({start = pos, endpos = pos, mins = Vector(-16, -16, 2), maxs = Vector(16, 16, 74), mask = MASK_NPCSOLID, filter = filter, collisiongroup = COLLISION_GROUP_NPC})
    if not hull.Hit and not hull.StartSolid then return pos end
end
function P.FindSpawn(director, players)
    N.Begin()
    if not N.GraphReady or #players == 0 then return end
    local viewers = player.GetHumans()
    local radius = math.Clamp(M.Radius:GetFloat(), 960, 8192)
    local positions = {}; for _, ply in ipairs(players) do positions[ply] = ply:GetPos() end
    local deadline = SysTime() + C.WorkBudgetMS / 1000
    -- Cache local candidates and shared reachability, never final LOS/occupancy.
    for attempt = 1, C.SpawnCandidates do
        if SysTime() >= deadline then break end
        director.ZASpawnCursor = (director.ZASpawnCursor or 0) % #players + 1
        local target = players[director.ZASpawnCursor]
        local center = positions[target]
        local cached = director.ZASpawnCache[target]
        if not cached or cached.radius ~= radius or CurTime() >= cached.expires or center:DistToSqr(cached.position) > 512 ^ 2 then
            cached = {position = Vector(center), radius = radius, areas = N.LocalAreas(center, radius), expires = CurTime() + C.CandidateLifetime}
            director.ZASpawnCache[target] = cached
        end
        local areas = cached.areas
        N.GetFlow(center)
        if #areas > 0 then
            local area = areas[math.random(#areas)]
            if not area:IsBlocked() and not area:IsUnderwater() and N.Reachable(area, center) == true then
                local pos = area:GetRandomPoint()
                local nearest, distance = Nearest(pos, players, positions)
                P.Stats.spawnChecks = P.Stats.spawnChecks + 1
                if distance >= C.SpawnMinDistance ^ 2 and distance <= radius ^ 2 then
                    local ground = P.ClearGround(pos)
                    if ground then
                        nearest, distance = Nearest(ground, players, positions)
                        if distance >= C.SpawnMinDistance ^ 2 and distance <= radius ^ 2 and P.Hidden(ground, viewers)
                            and N.Reachable(N.Area(ground), positions[nearest]) == true then return ground, nearest end
                    end
                end
            end
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
    local pos, target
    if record.relocate then pos, target = P.FindSpawn(director, players)
    else
        target = Nearest(record.position, players)
        local area = N.Area(record.position)
        if not target or not area or area:IsBlocked() or N.Reachable(area, target:GetPos(), record.navProfile) ~= true then return false end
        pos = P.ClearGround(record.position)
        if pos and not P.Hidden(pos, player.GetHumans()) then pos = nil end
    end
    if not pos or not IsValid(target) then return false end
    local z = ents.Create(record.class)
    if not IsValid(z) then return false end
    z.ZAWeapon = record.groups[ZA1.Config.Equipment.WeaponBodygroup] or 0
    if record.relocate then z.ZAEmerge = ZA1.Specials and ZA1.Specials.Emerge(record.class) or ZA1.Config.Animations.Emerge[math.random(#ZA1.Config.Animations.Emerge)] end
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
function P.Tick(director, players)
    if #players == 0 then return end
    local changes, actors, records = 0, director.ZAActors, director.ZADormant
    local now, deadline = CurTime(), SysTime() + C.WorkBudgetMS / 1000
    local viewers, positions = player.GetHumans(), {}
    for _, ply in ipairs(players) do positions[ply] = ply:GetPos() end
    -- Restore pending replacements first; retirement reserves a future slot.
    for i = 1, math.min(C.ChecksPerTick, #records) do
        if #records == 0 or changes >= C.ChangesPerTick or M.Count() >= M.PopulationLimit() or SysTime() >= deadline then break end
        local index = (director.ZADormantCursor - 1) % #records + 1
        local record = records[index]
        local _, distance = Nearest(record.position, players, positions)
        if (record.relocate or not M.Dormancy:GetBool() or distance < C.WakeDistance ^ 2) and P.Restore(director, record, players) then
            table.remove(records, index); changes = changes + 1
        else director.ZADormantCursor = index + 1; break end
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
