-- Use direct DT movement on clear ground. Obstructed approaches fall back
-- to shared nav-area guides and each actor's own native PathFollower.
local N = {Pending = setmetatable({}, {__mode = "k"}), Flows = {}, Nodes = {}, Areas = {}}
ZA1.Navigation = N
local C, M = ZA1.Config.Navigation, ZA1.Manager
N.Stats = {pathBuilds = 0, pathMS = 0, pathFailures = 0, burstTicks = 0, flowNodes = 0, sharedGuides = 0, recoveries = 0, maxQueueAge = 0,
    directChecks = 0, directClear = 0, directBlocked = 0, directTicks = 0,
    boundedSearches = 0, pathCostCalls = 0, routeWaits = 0, failedRouteHits = 0}
include("za1/navigation_search.lua")
local function Push(heap, id, cost)
    local i = #heap + 1
    local item = {id = id, cost = cost}
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].cost <= cost then break end
        heap[i], i = heap[parent], parent
    end
    heap[i] = item
end
local function Pop(heap)
    local result, last = heap[1], table.remove(heap)
    if #heap > 0 then
        local i = 1
        while i * 2 <= #heap do
            local child = i * 2
            if child < #heap and heap[child + 1].cost < heap[child].cost then child = child + 1 end
            if last.cost <= heap[child].cost then break end
            heap[i], i = heap[child], child
        end
        heap[i] = last
    end
    return result
end
function N.Reset()
    N.Nodes, N.Areas, N.Flows, N.Spatial, N.Pending = {}, {}, {}, {}, setmetatable({}, {__mode = "k"})
    N.GraphIndex, N.GraphReady, N.Requested = nil, false, false
    N.Generation = (N.Generation or 0) + 1
    N.ClearFailedRoutes()
end
function N.Begin() N.Requested = true end
function N.Profile(z)
    local step = z and z.loco:GetStepHeight() or C.StepHeight
    local drop = z and z.loco:GetDeathDropHeight() or 74
    local height, width = z and z.Height or 74, z and z.Width or 14
    return {step = step, drop = drop, height = height, width = width, key = step .. ":" .. drop .. ":" .. height .. ":" .. width}
end
function N.Area(pos)
    if not navmesh.IsLoaded() then return end
    local area = navmesh.GetNearestNavArea(pos, false, 256, false, true)
    if IsValid(area) then return area end
end
local function Node(area)
    local id = area:GetID()
    local node = N.Nodes[id]
    if not node then
        node = {area = area, pos = area:GetCenter(), incoming = {}}
        N.Nodes[id] = node
        local x, y = math.floor(node.pos.x / 1024), math.floor(node.pos.y / 1024)
        N.Spatial[x] = N.Spatial[x] or {}
        N.Spatial[x][y] = N.Spatial[x][y] or {}
        local bucket = N.Spatial[x][y]
        bucket[#bucket + 1] = area
    end
    return node
end
function N.LocalAreas(pos, radius)
    local result = {}
    for x = math.floor((pos.x - radius) / 1024), math.floor((pos.x + radius) / 1024) do
        local row = N.Spatial[x]
        if row then
            for y = math.floor((pos.y - radius) / 1024), math.floor((pos.y + radius) / 1024) do
                local bucket = row[y]
                if bucket then for _, area in ipairs(bucket) do
                    if area:GetCenter():DistToSqr(pos) <= radius ^ 2 then result[#result + 1] = area end
                end end
            end
        end
    end
    return result
end
function N.LocalAreaScan(pos, radius)
    return {position = Vector(pos), radiusSquare = radius ^ 2, areas = {}, index = 1,
        x = math.floor((pos.x - radius) / 1024), y = math.floor((pos.y - radius) / 1024),
        firstY = math.floor((pos.y - radius) / 1024), lastY = math.floor((pos.y + radius) / 1024),
        lastX = math.floor((pos.x + radius) / 1024)}
end
function N.ScanLocalAreas(scan, limit, deadline)
    local checked = 0
    while not scan.complete and checked < limit and SysTime() < deadline do
        local row = N.Spatial[scan.x]
        local bucket = row and row[scan.y]
        local area = bucket and bucket[scan.index]
        checked = checked + 1 -- Empty cells consume work too.
        if area then
            scan.index = scan.index + 1
            local node = IsValid(area) and N.Nodes[area:GetID()]
            if node and node.pos:DistToSqr(scan.position) <= scan.radiusSquare then
                scan.areas[#scan.areas + 1] = area
            end
        else
            scan.index, scan.y = 1, scan.y + 1
            if scan.y > scan.lastY then scan.y, scan.x = scan.firstY, scan.x + 1 end
            scan.complete = scan.x > scan.lastX
        end
    end
    return checked
end
function N.BuildGraph(deadline)
    if not navmesh.IsLoaded() then return end
    if not N.GraphIndex then N.Areas, N.GraphIndex = navmesh.GetAllNavAreas(), 1 end
    for i = 1, C.GraphAreasPerTick do
        local area = N.Areas[N.GraphIndex]
        if not area then N.GraphReady = true; return end
        if IsValid(area) then
            local from = Node(area)
            -- Reverse only actual outgoing connections. A drop is not an ascent.
            from.outgoing = from.outgoing or area:GetAdjacentAreaDistances()
            for _, connection in ipairs(from.outgoing) do
                local to = connection.area
                if IsValid(to) then
                    local destination = Node(to)
                    destination.incoming[#destination.incoming + 1] = {
                        id = area:GetID(), height = area:ComputeAdjacentConnectionHeightChange(to),
                        distance = connection.dist or math.sqrt(from.pos:DistToSqr(destination.pos))}
                end
            end
        end
        N.GraphIndex = N.GraphIndex + 1
        if SysTime() >= deadline then return end
    end
end
local function Open(node, profile)
    if not node or not IsValid(node.area) or node.area:IsBlocked() then return false end
    if bit.band(node.area:GetAttributes(), NAV_MESH_CROUCH) ~= 0 then return false end
    return true
end
function N.GetFlow(goal, profile)
    N.Begin()
    if not N.GraphReady then return end
    local area = N.Area(goal)
    if not area then return end
    profile = profile or N.Profile()
    local key = area:GetID() .. "/" .. profile.key
    local flow = N.Flows[key]
    if flow and CurTime() - flow.used >= C.FlowLifetime then N.Flows[key], flow = nil, nil end
    if not flow then
        local count, oldest, oldestKey = 0
        for candidateKey, candidate in pairs(N.Flows) do
            count = count + 1
            if not oldest or candidate.used < oldest then oldest, oldestKey = candidate.used, candidateKey end
        end
        if count >= C.FlowCacheSize then N.Flows[oldestKey] = nil end
        local id = area:GetID()
        flow = {key = key, goal = id, profile = profile, distance = {[id] = 0}, next = {}, settled = {}, heap = {}, used = CurTime(),
            wanted = {[id] = CurTime() + C.FlowDemandLifetime}, waiting = 1, blocked = {}}
        Push(flow.heap, id, 0)
        N.Flows[key] = flow
    end
    flow.used = CurTime()
    return flow
end
function N.RequireArea(flow, area)
    local id = area:GetID()
    if flow.complete or flow.settled[id] then return end
    if not flow.wanted[id] then flow.waiting = flow.waiting + 1 end
    flow.wanted[id] = CurTime() + C.FlowDemandLifetime
end
local function RememberBlocked(flow, node)
    if node and IsValid(node.area) and node.area:IsBlocked() then flow.blocked[node.area:GetID()] = true end
end
function N.Expand(flow)
    local item = Pop(flow.heap)
    if not item then flow.complete = true; return end
    if flow.settled[item.id] or item.cost ~= flow.distance[item.id] then return end
    flow.settled[item.id] = true
    if flow.wanted[item.id] then flow.wanted[item.id], flow.waiting = nil, flow.waiting - 1 end
    local node = N.Nodes[item.id]
    if not Open(node, flow.profile) then RememberBlocked(flow, node); return end
    for _, edge in ipairs(node.incoming) do
        local from = N.Nodes[edge.id]
        if edge.height <= flow.profile.step and -edge.height <= flow.profile.drop then
            if Open(from, flow.profile) then
                local cost = item.cost + math.max(edge.distance, 0.01)
                if not flow.distance[edge.id] or cost < flow.distance[edge.id] then
                    flow.distance[edge.id], flow.next[edge.id] = cost, item.id
                    Push(flow.heap, edge.id, cost)
                end
            else RememberBlocked(flow, from)
            end
        end
    end
    if #flow.heap == 0 then flow.complete = true end
    N.Stats.flowNodes = N.Stats.flowNodes + 1
end
function N.Reachable(area, goal, profile)
    if not IsValid(area) then return false end
    local flow = N.GetFlow(goal, profile)
    if not flow then return nil end
    if area:IsBlocked() then return false end
    N.RequireArea(flow, area)
    if flow.settled[area:GetID()] then
        -- Recheck cached route areas: a newly blocked door invalidates eligibility
        -- immediately, without creating an actor to discover the obstruction.
        local id = area:GetID()
        while id do
            if not Open(N.Nodes[id], flow.profile) then N.Flows[flow.key] = nil; return false end
            if id == flow.goal then return true end
            id = flow.next[id]
        end
        return false
    end
    if flow.complete then return false end
    return nil -- Pending is not an unreachable island.
end
function N.Guide(z, goal)
    if not M.SharedRoutes:GetBool() or z:GetPos():DistToSqr(goal) < C.SharedRouteDistance ^ 2 then return goal end
    local flow = N.GetFlow(goal, z.ZANavProfile or N.Profile(z))
    local area = N.Area(z:GetPos())
    if not flow or not area then return goal end
    N.RequireArea(flow, area)
    if not flow.settled[area:GetID()] then return goal end
    if not Open(N.Nodes[area:GetID()], flow.profile) then N.Flows[flow.key] = nil; return goal end
    local id, total, start = area:GetID(), 0, area:GetID()
    for i = 1, C.SharedRouteHops do
        local nextID = flow.next[id]
        if not nextID then break end
        local node = N.Nodes[nextID]
        if not Open(node, flow.profile) or not z.loco:IsAreaTraversable(node.area) then N.Flows[flow.key] = nil; return goal end
        total, id = total + math.sqrt(N.Nodes[id].pos:DistToSqr(node.pos)), nextID
        if total >= C.SharedRouteDistance or id == flow.goal then break end
    end
    if id == start or id == flow.goal then return goal end
    N.Stats.sharedGuides = N.Stats.sharedGuides + 1
    return N.Nodes[id].pos
end
function N.PauseProgress(z)
    z.ZAProgressPos, z.ZAProgressTime, z.ZAProgressTick = nil, nil, nil
end
function N.Cancel(z)
    N.Pending[z] = nil
    if not IsValid(z) then return end
    z.ZAMoveGoal, z.ZAPathGoal, z.ZAPathRefresh, z.ZAProgressPos = nil, nil, nil, nil
    z.ZACloseGoal, z.ZAFaceGoal = nil, nil
    z.ZADirect, z.ZADirectRetry = nil, nil
    N.PauseProgress(z)
    local path = z:GetFollowPath()
    if IsValid(path) then path:Invalidate() end
end
function N.Face(z, goal)
    if not z.ZAFaceGoal or z.ZAMoveGoal or N.Pending[z] or z.ZADirect then N.Cancel(z) end
    if ZA1.Crowd then ZA1.Crowd.Hold(z) end
    z.ZAFaceGoal = goal
    z.__DT_IsMoving = false
    z.loco:SetVelocity(Vector(0, 0, z:GetVelocity().z))
    N.PauseProgress(z)
end
function N.Request(z, goal, priority, directGoal, routeGoal)
    if not directGoal and CurTime() < (z.ZAPathRetry or 0) then return end
    local old = N.Pending[z]
    local job = old or {queued = CurTime()}
    job.goal, job.priority = Vector(goal), priority or 0
    job.directGoal = directGoal and Vector(directGoal) or nil
    job.routeGoal = Vector(routeGoal or goal)
    N.Pending[z] = job
end
local function Locomoting(z)
    local state = z:GetAnimState()
    return bit.band(state:SelectAnimFlags(z) or 0, DT_Base.ANIM_STATE_LOCOMOTION) ~= 0
end

local function DirectGoal(z, pos)
    local close = z.ZACloseGoal
    if close then
        local range = z.ZASpecial == "suicide" and z.ZASpecialSettings.TriggerRange or ZA1.Config.Melee.StartRange
        if pos:DistToSqr(close) <= (range + C.LookAhead) ^ 2 then return close end
    end
    return z.ZAMoveGoal
end
local function DirectMatches(z, goal)
    local cached = z.ZADirect
    return cached and cached.generation == N.Generation
        and cached.width == z.Width and cached.height == z.Height
        and goal:DistToSqr(cached.goal) <= C.RepathDistance ^ 2
end
function N.DirectUsable(z, goal, pos)
    if not C.DirectMovement or CurTime() < (z.ZADirectRetry or 0) or not DirectMatches(z, goal) then return false end
    local cached = z.ZADirect
    -- Leave time for a whole horde's staggered refresh queue. The collision
    -- hull still stops new obstacles; a stall immediately requests recovery.
    local interval = z.ZASpecialSettings and z.ZASpecialSettings.DirectInterval or C.DirectInterval
    if not cached.clear or CurTime() - cached.checked > C.StuckDelay + interval then return false end
    -- Movement must remain on the checked corridor. A sideways recovery,
    -- shove or teleport cannot keep using another position's clear result.
    local dx, dy = cached.goal.x - cached.from.x, cached.goal.y - cached.from.y
    local px, py = pos.x - cached.from.x, pos.y - cached.from.y
    local length = dx * dx + dy * dy
    local fraction = length > 0 and math.Clamp((px * dx + py * dy) / length, 0, 1) or 0
    return (px - dx * fraction) ^ 2 + (py - dy * fraction) ^ 2 <= 4 ^ 2
        and math.abs(pos.z - cached.from.z - (cached.goal.z - cached.from.z) * fraction) <= cached.step + 2
end

local function AreaInterval(area, start, delta)
    local node = Node(area)
    if not node.bounds then
        local a, b = area:GetCorner(0), area:GetCorner(2)
        node.bounds = {math.min(a.x, b.x), math.min(a.y, b.y), math.max(a.x, b.x), math.max(a.y, b.y)}
    end
    local lo, hi, box = 0, 1, node.bounds
    for axis = 1, 2 do
        if math.abs(delta[axis]) < 0.00001 then
            if start[axis] < box[axis] or start[axis] > box[axis + 2] then return end
        else
            local a, b = (box[axis] - start[axis]) / delta[axis], (box[axis + 2] - start[axis]) / delta[axis]
            lo, hi = math.max(lo, math.min(a, b)), math.min(hi, math.max(a, b))
            if lo > hi then return end
        end
    end
    return lo, hi
end
local function DirectGround(z, start, goal)
    local area, delta, edges = N.Area(start), goal - start, 0
    local profile = N.Profile(z)
    local fraction, tolerance = 0, 0.5 / math.max(delta:Length2D(), 1)
    for i = 1, C.DirectAreasPerCheck do
        if not area or not Open(Node(area), profile) or not z.loco:IsAreaTraversable(area) then return false end
        local enter, leave = AreaInterval(area, start, delta)
        if not enter or enter > fraction + tolerance or leave < fraction then return false end
        local first, last = start + delta * fraction, start + delta * leave
        local firstZ, lastZ = area:GetClosestPointOnArea(first).z, area:GetClosestPointOnArea(last).z
        if math.abs(firstZ - first.z) > profile.step + 2 or math.abs(lastZ - last.z) > profile.step + 2 then return false end
        if leave >= 1 then return true end
        local nextArea, furthest
        local node = Node(area); node.outgoing = node.outgoing or area:GetAdjacentAreaDistances()
        for _, connection in ipairs(node.outgoing) do
            edges = edges + 1
            if edges > C.DirectEdgesPerCheck then return false end
            local other = connection.area
            if IsValid(other) then
                local lo, hi = AreaInterval(other, start, delta)
                if lo and lo <= leave + tolerance and hi > leave + 0.000001
                    and (not furthest or hi > furthest) then
                    local height = area:ComputeAdjacentConnectionHeightChange(other)
                    -- A direct approach cannot perform a path's drop/climb.
                    local portalHeight = other:GetClosestPointOnArea(last).z - lastZ
                    if math.abs(height) <= profile.step and math.abs(portalHeight) <= profile.step
                        and Open(Node(other), profile) and z.loco:IsAreaTraversable(other) then
                        nextArea, furthest = other, hi
                    end
                end
            end
        end
        if not nextArea then return false end
        area, fraction = nextArea, leave
    end
    return false -- Complicated strips use the regular, budgeted route search.
end
local function DirectClear(z, pos, goal)
    local mins, maxs = z:GetCollisionBounds()
    if not z.ZADirectFilter then
        z.ZADirectFilter = function(other)
            return IsValid(other) and other ~= z and other ~= z.ZADirectEnemy and not other.ZA1Zombie
        end
    end
    z.ZADirectEnemy = z:GetEnemy()
    local hull = util.TraceHull({start = pos, endpos = goal, mins = Vector(mins.x, mins.y, mins.z + 2), maxs = maxs,
        mask = MASK_SOLID, collisiongroup = COLLISION_GROUP_NONE, filter = z.ZADirectFilter})
    if hull.Hit and ZA1.Doors then ZA1.Doors.Observe(z, hull.Entity, goal) end
    return not hull.Hit and not hull.StartSolid and not hull.AllSolid and DirectGround(z, pos, goal)
end
function N.CheckDirectPaths()
    local deadline = SysTime() + C.DirectBudgetMS / 1000
    for i = 1, C.DirectChecksPerTick do
        local chosen, job, best
        for z, pending in pairs(N.Pending) do
            if not M.Active(z) or not z.ZAMoveGoal then N.Pending[z] = nil
            elseif pending.directGoal and not z.ZAActing and Locomoting(z) then
                local score = pending.priority + (CurTime() - pending.queued) * 4
                if not best or score > best then chosen, job, best = z, pending, score end
            end
        end
        if not chosen then break end
        local pos, goal = chosen:GetPos(), job.directGoal
        local clear = DirectClear(chosen, pos, goal)
        chosen.ZADirect = {clear = clear, from = Vector(pos), goal = goal, checked = CurTime(), generation = N.Generation,
            step = chosen.loco:GetStepHeight(), width = chosen.Width, height = chosen.Height}
        N.Stats.directChecks = N.Stats.directChecks + 1
        if clear then
            N.Stats.directClear = N.Stats.directClear + 1
            N.Pending[chosen] = nil
            chosen.ZAPathGoal, chosen.ZAPathRefresh, chosen.ZAPathRetry = nil, nil, nil
            local path = chosen:GetFollowPath(); if IsValid(path) then path:Invalidate() end
        else
            N.Stats.directBlocked = N.Stats.directBlocked + 1
            if CurTime() < (chosen.ZAPathRetry or 0) then N.Pending[chosen] = nil
            else
                job.directGoal = nil
                job.goal = job.priority > 0 and N.Guide(chosen, job.goal) or job.goal
            end
        end
        if SysTime() >= deadline then break end
    end
end
function N.BuildPaths()
    if not navmesh.IsLoaded() or DT_Base.ConVar_DebugNextBotsPathfindingDisabled:GetBool() then return end
    if C.DirectMovement then N.CheckDirectPaths() end
    local deadline = SysTime() + C.PathBudgetMS / 1000
    local limit = M.PathBudget:GetInt()
    for i = 1, math.max(limit, M.PathBurst:GetInt()) do
        if i > limit or i > 1 and SysTime() >= deadline then break end
        local chosen, job, best, count, oldest = nil, nil, nil, 0, 0
        for z, pending in pairs(N.Pending) do
            if not M.Active(z) or not z.ZAMoveGoal then N.Pending[z] = nil
            elseif (not C.DirectMovement or not pending.directGoal) and not z.ZAActing and Locomoting(z)
                and CurTime() >= (pending.waitUntil or 0) then
                local age = CurTime() - pending.queued
                count, oldest = count + 1, math.max(oldest, age)
                local score = pending.priority + age * 4
                if not best or score > best then chosen, job, best = z, pending, score end
            end
        end
        if not chosen then break end
        if i == 1 and (count > limit * 2 or oldest >= C.PathBurstQueueAge) then
            limit = math.max(limit, M.PathBurst:GetInt())
            if limit > M.PathBudget:GetInt() then N.Stats.burstTicks = N.Stats.burstTicks + 1 end
        end
        if i > 1 and SysTime() >= deadline then break end
        local ready = N.RouteReady(chosen, job)
        if ready == nil then
            job.waitUntil = CurTime() + 0.05 -- Continue the existing path while the shared search advances.
        elseif ready == false then
            N.Pending[chosen] = nil
            chosen.ZAPathRetry = CurTime() + C.RetryDelay
        else
            N.Pending[chosen] = nil
            local complete, elapsed, bounded = N.Compute(chosen, job, deadline)
            N.Stats.pathBuilds, N.Stats.pathMS = N.Stats.pathBuilds + 1, N.Stats.pathMS + elapsed
            local wait = CurTime() - job.queued
            N.Stats.maxQueueAge = math.max(N.Stats.maxQueueAge, wait)
            if ZA1.Performance and ZA1.Performance.Capture then ZA1.Performance.PathWait(wait) end
            chosen.ZAPathGoal = job.goal
            chosen.ZAPathRefresh = CurTime() + math.Rand(C.RepathMinDelay, C.RepathMaxDelay)
            if not complete then
                local delay = bounded and C.BoundedRetryDelay or C.RetryDelay
                chosen.ZAPathRetry = CurTime() + delay
                N.RememberFailure(chosen, job, bounded and delay or C.FailedRouteLifetime)
                if not bounded then N.Stats.pathFailures = N.Stats.pathFailures + 1 end
            else chosen.ZAPathRetry = nil end
        end
        if SysTime() >= deadline then break end
    end
end
function N.Move(z, goal, priority)
    z.ZAFaceGoal = nil
    z.ZAMoveGoal = goal
    z.ZAMovePriority = priority or 0
    if not navmesh.IsLoaded() or DT_Base.ConVar_DebugNextBotsPathfindingDisabled:GetBool() then return end
    local path = z:GetFollowPath()
    local claim = z.ZAAttackClaim
    local tolerance = claim and claim.position == goal and 8 or C.GoalTolerance
    path:SetGoalTolerance(tolerance)
    if C.DirectMovement and CurTime() >= (z.ZADirectRetry or 0) then
        local pos = z:GetPos(); local target = DirectGoal(z, pos)
        local usable = N.DirectUsable(z, target, pos)
        if not DirectMatches(z, target) or z.ZADirect.clear and not usable
            or CurTime() - z.ZADirect.checked >= (z.ZASpecialSettings and z.ZASpecialSettings.DirectInterval or C.DirectInterval) then
            N.Request(z, goal, priority, target)
            return
        elseif usable then N.Pending[z] = nil; return end
    end
    -- Individual wandering does not evict shared combat/investigation routes.
    local guide = z.ZAMovePriority > 0 and N.Guide(z, goal) or goal
    local reached = not z.ZACloseGoal and z.ZAPathGoal and z:GetPos():DistToSqr(z.ZAPathGoal) <= tolerance ^ 2
    if not IsValid(path) or not z.ZAPathGoal or reached
        or CurTime() >= (z.ZAPathRefresh or 0) and z.ZAPathGoal:DistToSqr(guide) > C.RepathDistance ^ 2 then
    N.Request(z, guide, priority, nil, goal)
    end
end
function N.Follow(z)
    if not IsValid(z) then return end
    if not z.ZAMoveGoal and not z.ZAFaceGoal then N.PauseProgress(z); return end
    if not M.Active(z) or z.ZAActing or not Locomoting(z) then N.PauseProgress(z); return end
    if not z.ZAMoveGoal then
        N.PauseProgress(z)
        if z.ZAFaceGoal then z:FaceTowards(z.ZAFaceGoal) end
        return
    end
    if CurTime() < (z.ZAYieldUntil or 0) then N.PauseProgress(z); return end
    if z.ZARecoveryGoal then
        N.PauseProgress(z)
        if CurTime() < z.ZARecoveryUntil and z:GetPos():DistToSqr(z.ZARecoveryGoal) > 12 ^ 2 then
            z:Approach(z.ZARecoveryGoal); z:FaceTowards(z.ZARecoveryGoal)
            return
        end
        z.ZARecoveryGoal = nil
    end
    if not navmesh.IsLoaded() or DT_Base.ConVar_DebugNextBotsPathfindingDisabled:GetBool() then
        N.PauseProgress(z)
        local goal = z.ZACloseGoal or z.ZAMoveGoal
        z:Approach(goal); z:FaceTowards(goal)
        return -- No native path work or unbounded base Unstuck coroutine.
    end
    local path, pos = z:GetFollowPath(), z:GetPos()
    -- Retargeting queues a new corridor; it does not invalidate movement
    -- toward the old checked endpoint. Keep following it until replaced.
    local cached = z.ZADirect
    local direct = cached and N.DirectUsable(z, cached.goal, pos)
    if not direct and not IsValid(path) then
        if not N.Pending[z] then N.Request(z, (z.ZAMovePriority or 0) > 0 and N.Guide(z, z.ZAMoveGoal) or z.ZAMoveGoal, z.ZAMovePriority, nil, z.ZAMoveGoal) end
        -- DT clears this flag each tick. While a route check waits, animate
        -- any remaining braking velocity without issuing unsafe movement.
        z.__DT_IsMoving = N.Pending[z] ~= nil and z:GetVelocity():Length2D() > 0
        N.PauseProgress(z); return
    end
    local close, goal = z.ZACloseGoal
    if (not C.DirectMovement or not z.ZADirect) and close then
        local range = z.ZASpecial == "suicide" and z.ZASpecialSettings.TriggerRange or ZA1.Config.Melee.StartRange
        if pos:DistToSqr(close) <= (range + C.LookAhead) ^ 2
            and math.abs(close.z - pos.z) <= z.loco:GetStepHeight() then goal = path:GetCurrentGoal() end
    end
    local destination
    if direct then
        destination = z.ZADirect.goal
        N.Stats.directTicks = N.Stats.directTicks + 1
    elseif goal and goal.type == 0 and z.ZAPathGoal and goal.pos:DistToSqr(z.ZAPathGoal) <= 8 ^ 2 then
        -- On the final clear segment, pursue the visible target rather than
        -- braking to a finite crowd-slot/path endpoint before an attack.
        destination = close
    end
    -- Crowd avoidance's checked point also determines facing.
    local steer = ZA1.Crowd and ZA1.Crowd.Steer(z, path, destination)
    local obstacle=ZA1.Obstacles and ZA1.Obstacles.Steer(z,path,steer or destination)
    if CurTime() < (z.ZAYieldUntil or 0) then N.PauseProgress(z); return end
    -- Obstacle routes still advance PathFollower's current segment while
    -- avoiding neighbours; a cached steer point must not freeze its cursor.
    if not destination and not obstacle and IsValid(path) then path:Update(z) end
    destination = obstacle or steer or destination
    if destination then z:Approach(destination); z:FaceTowards(destination) end
    z.__DT_IsMoving, z.__DT_IsTurning = true, true
    if (not direct and not IsValid(path)) or CurTime() < (z.ZAYieldUntil or 0) then N.PauseProgress(z); return end
    -- A finite recovery request replaces the base's four-trace-per-yield loop.
    -- Measure continuous following, not time spent in melee, authored turns,
    -- yielding or a coroutine that was not resumed on intervening ticks.
    local tick = engine.TickCount()
    if z.ZAProgressTick and tick - z.ZAProgressTick > 1 then N.PauseProgress(z) end
    z.ZAProgressTick = tick
    if not z.ZAProgressPos or pos:DistToSqr(z.ZAProgressPos) > 8 ^ 2 then
        z.ZAProgressPos, z.ZAProgressTime = Vector(pos), CurTime()
    elseif CurTime() - (z.ZAProgressTime or CurTime()) > C.StuckDelay then
        z.ZAProgressTime = CurTime()
        if z.loco:IsStuck() then z.loco:ClearStuck() end
        z.ZAPathRefresh, z.ZAPathRetry = 0, nil
        if direct then z.ZADirect = nil; z.ZADirectRetry = CurTime() + C.RetryDelay end
        if ZA1.Crowd then ZA1.Crowd.Recover(z) end
        N.Request(z, (z.ZAMovePriority or 0) > 0 and N.Guide(z, z.ZAMoveGoal) or z.ZAMoveGoal, 2, nil, z.ZAMoveGoal)
        N.Stats.recoveries = N.Stats.recoveries + 1
    end
end
local function RefreshFlow(flow, deadline)
    for id, expires in pairs(flow.wanted) do
        if CurTime() >= expires then flow.wanted[id], flow.waiting = nil, flow.waiting - 1 end
    end
    -- Closed areas were excluded from the search. Check a few per tick so an
    -- opened door refreshes the map without repeatedly flooding the whole map.
    for i = 1, C.FlowBlockedChecksPerTick do
        if SysTime() >= deadline then break end
        local id = next(flow.blocked, flow.blockedCursor)
        flow.blockedCursor = id
        if not id then break end
        if Open(N.Nodes[id], flow.profile) then N.Flows[flow.key] = nil; return false end
        if SysTime() >= deadline then break end
    end
    return true
end
function N.Tick()
    if not N.Requested and M.Count() == 0 and not next(N.Pending) then return end
    local deadline = SysTime() + C.FlowBudgetMS / 1000
    if N.Requested and not N.GraphReady then N.BuildGraph(deadline) end
    if N.GraphReady then
        -- Round-robin maps, so a long route cannot monopolize the graph budget.
        local flows = {}
        for key, flow in pairs(N.Flows) do
            if CurTime() - flow.used >= C.FlowLifetime then N.Flows[key] = nil
            elseif RefreshFlow(flow, deadline) and not flow.complete and flow.waiting > 0 then flows[#flows + 1] = flow end
        end
        local index = 1
        for i = 1, C.FlowNodesPerTick do
            if #flows == 0 or SysTime() >= deadline then break end
            local flow = flows[index]
            N.Expand(flow)
            if flow.complete or flow.waiting == 0 then table.remove(flows, index)
            else index = index + 1 end
            if index > #flows then index = 1 end
            if SysTime() >= deadline then break end
        end
    end
    N.BuildPaths()
end
hook.Add("Think", "ZA1/Navigation", N.Tick)
hook.Add("PostCleanupMap", "ZA1/Navigation", N.Reset)
N.Reset()
