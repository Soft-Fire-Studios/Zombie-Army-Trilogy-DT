-- Bound each native search, and share failed start/goal pairs across the horde.
local N, M, C = ZA1.Navigation, ZA1.Manager, ZA1.Config.Navigation
function N.ClearFailedRoutes()
    N.FailedRoutes, N.FailedRouteRing, N.FailedRouteCursor = {}, {}, 0
end
function N.InvalidateRoutes()
    N.Flows = {}
    N.ClearFailedRoutes()
    N.Generation = N.Generation + 1
    for z in pairs(M.Zombies) do
        if M.Active(z) then z.ZAPathRetry, z.ZAPathRefresh, z.ZADirect = nil, 0, nil; M.Wake(z) end
    end
end
local function Route(z, job)
    local from, goal = N.Area(z:GetPos()), N.Area(job.routeGoal or job.goal)
    if not from or not goal then return nil, from, goal end
    local profile = z.ZANavProfile or N.Profile(z)
    return from:GetID() .. "/" .. goal:GetID() .. "/" .. profile.key, from, goal
end
function N.RememberFailure(z, job, lifetime)
    local key = Route(z, job)
    if not key then return end
    local old = N.FailedRoutes[key]
    if not old then
        N.FailedRouteCursor = N.FailedRouteCursor % C.FailedRouteLimit + 1
        local evicted = N.FailedRouteRing[N.FailedRouteCursor]
        if evicted then N.FailedRoutes[evicted] = nil end
        N.FailedRouteRing[N.FailedRouteCursor] = key
    end
    N.FailedRoutes[key] = {expires = CurTime() + lifetime, goal = Vector(job.routeGoal or job.goal)}
end
function N.RouteReady(z, job)
    local key, from = Route(z, job)
    local failure = key and N.FailedRoutes[key]
    if failure and CurTime() < failure.expires
        and failure.goal:DistToSqr(job.routeGoal or job.goal) <= C.RepathDistance ^ 2 then
        N.Stats.failedRouteHits = N.Stats.failedRouteHits + 1
        return false
    end
    -- Short local routes and wandering still work while the shared graph loads.
    if job.priority <= 0 or not from or not N.GraphReady or not M.SharedRoutes:GetBool()
        or z:GetPos():DistToSqr(job.routeGoal or job.goal) < C.SharedRouteDistance ^ 2 then return true end
    local reachable = N.Reachable(from, job.routeGoal or job.goal, z.ZANavProfile or N.Profile(z))
    if reachable == false then N.RememberFailure(z, job, C.FailedRouteLifetime)
    elseif reachable == nil then
        N.Stats.routeWaits = N.Stats.routeWaits + 1
        -- A newly encountered door may separate the reverse shared search
        -- from this actor. One bounded partial search can bring it up to the
        -- blocker; useful existing paths keep moving while reachability waits.
        if IsValid(z.ZABlockedDoor) and not IsValid(z:GetFollowPath()) then return true end
    end
    return reachable
end
function N.Compute(z, job, tickDeadline)
    local search = z.ZAPathSearch
    if not search then
        search = {}
        z.ZAPathSearch = search
        search.cost = function(area, from, ladder, elevator, length)
            search.calls = search.calls + 1
            if search.bounded then return -1 end
            if search.calls > C.PathCostCallsPerBuild or SysTime() >= search.deadline then
                search.bounded = true
                return -1
            end
            return search.generator(area, from, ladder, elevator, length)
        end
    end
    local path, started = z:GetFollowPath(), SysTime()
    search.generator, search.calls, search.bounded = z:PathGenerator(), 0, false
    search.deadline = math.min(tickDeadline, started + C.PathSearchMS / 1000)
    local complete = path:Compute(z, job.goal, search.cost)
    local elapsed = (SysTime() - started) * 1000
    N.Stats.pathCostCalls = N.Stats.pathCostCalls + search.calls
    if search.bounded then N.Stats.boundedSearches = N.Stats.boundedSearches + 1 end
    if ZA1.Performance and ZA1.Performance.Capture then
        ZA1.Performance.PathSearch(z, job, started, elapsed, complete, IsValid(path), search.calls, search.bounded)
    end
    return complete, elapsed, search.bounded
end
