-- Opt-in measurements. The watch retains a bounded window before a hitch;
-- no timing wrappers or sample collection run outside an admin capture/watch.
local F = {}
ZA1.Performance = F
local M, N, G, P = ZA1.Manager, ZA1.Navigation, ZA1.Crowd, ZA1.Population
local Detail = include("za1/performance_detail.lua")
local Modules = {awareness = M, navigation = N, crowd = G, population = P, obstacles = ZA1.Obstacles, traversal = ZA1.Traversal}
local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function Authorized(ply) return not IsValid(ply) or ply:IsAdmin() end
local function Output(ply, text)
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text .. "\n") else MsgN(text) end
end
local function Counters()
    local result = {}
    for name, module in pairs(Modules) do
        local copy = {}; for key, value in pairs(module.Stats) do copy[key] = value end
        result[name] = copy
    end
    return result
end
local function Delta(before, after)
    local result = {}
    for name, values in pairs(after) do
        result[name] = {}
        for key, value in pairs(values) do
            -- A lifetime maximum is a gauge, never a work counter.
            if key ~= "maxQueueAge" then result[name][key] = value - before[name][key] end
        end
    end
    return result
end
local function Queues()
    local oldest = 0
    for z, pending in pairs(N.Pending) do
        if M.Active(z) then oldest = math.max(oldest, CurTime() - pending.queued) end
    end
    return {path = Count(N.Pending), hearing = Count(M.Hearing), crowd = Count(G.Pending),
        obstacles = ZA1.Obstacles and Count(ZA1.Obstacles.Pending) or 0, oldestPathMS = oldest * 1000}
end
function F.Snapshot(queues, counters)
    queues = queues or Queues()
    return {active = M.Count(), dormant = IsValid(M.Director) and #M.Director.ZADormant or 0,
        pathQueue = queues.path, oldestPathMS = queues.oldestPathMS, hearingQueue = queues.hearing, crowdQueue = queues.crowd,
        flows = Count(N.Flows), graphReady = N.GraphReady, pathBudget = M.PathBudget:GetInt(), pathBurst = M.PathBurst:GetInt(),
        awarenessBuckets = #M.Buckets, crowdBuckets = #G.Buckets, navAreas = #N.Areas,
        sharedRoutes = M.SharedRoutes:GetBool(), crowd = M.Crowd:GetBool(), dormancy = M.Dormancy:GetBool(), counters = counters or Counters()}
end
F.WindowSeconds, F.FrameLimit = 8, 768
local function RingPush(capture, frame)
    local ring = capture.ring
    while ring.count > 0 do
        local oldest = ring.data[ring.head]
        if ring.count < F.FrameLimit and frame.atMS - oldest.atMS <= F.WindowSeconds * 1000 then break end
        -- Keep the preceding tick across a gap longer than the time window,
        -- then preserve the triggering tick until its post-hitch tail is saved.
        if ring.count < F.FrameLimit and (oldest == capture.frame or oldest == capture.triggerFrame) then break end
        ring.data[ring.head] = nil
        ring.head, ring.count = ring.head % F.FrameLimit + 1, ring.count - 1
        capture.discardedFrames = capture.discardedFrames + 1
    end
    ring.data[(ring.head + ring.count - 1) % F.FrameLimit + 1] = frame
    ring.count = ring.count + 1
end
local function Frames(capture)
    if not capture.watch then return capture.frames end
    local result, ring = {}, capture.ring
    for i = 0, ring.count - 1 do result[#result + 1] = ring.data[(ring.head + i - 1) % F.FrameLimit + 1] end
    return result
end
local function Control(capture, action)
    if not capture.watch or not IsValid(capture.player) then return end
    net.Start("ZA1/PerformanceControl")
    net.WriteUInt(capture.session, 32); net.WriteUInt(action, 2); net.WriteFloat(capture.thresholdMS)
    net.Send(capture.player)
end
local function Distribution(samples)
    if #samples == 0 then return {samples = 0, mean = 0, p95 = 0, p99 = 0, max = 0} end
    local sum = 0
    for _, sample in ipairs(samples) do sum = sum + sample end
    table.sort(samples)
    return {samples = #samples, mean = sum / #samples, p95 = samples[math.ceil(#samples * .95)], p99 = samples[math.ceil(#samples * .99)], max = samples[#samples]}
end
local function CloseFrame(capture)
    local frame = capture.frame
    if not frame or frame.work then return end
    frame.work, frame.queuesAfter = Delta(frame.counters, Counters()), Queues()
    frame.counters = nil
    if not capture.watch then capture.queueAges[#capture.queueAges + 1] = frame.queuesAfter.oldestPathMS end
end
local function Frame(capture)
    local tick = engine.TickCount()
    if not capture.frame or capture.frame.tick ~= tick then
        CloseFrame(capture)
        local frame = {tick = tick, atMS = (SysTime() - capture.started) * 1000, partsMS = {}, dtPartsMS = {}, addonMS = 0,
            active = M.Count(), queuesBefore = Queues(), counters = Counters(), luaMemoryKB = collectgarbage("count")}
        if capture.watch then
            frame.initial, frame.pathWaits = F.Snapshot(frame.queuesBefore, frame.counters), {}
            RingPush(capture, frame)
        else capture.frames[#capture.frames + 1] = frame end
        capture.frame = frame
    end
    return capture.frame
end
F.Frame = Frame -- Shared by the opt-in operation timers; never called unarmed.
local function Record(frame, label, elapsed)
    frame.partsMS[label] = (frame.partsMS[label] or 0) + elapsed
    frame.addonMS = frame.addonMS + elapsed
end
function F.PathWait(seconds)
    local capture = F.Capture
    if not capture then return end
    local samples = capture.watch and Frame(capture).pathWaits or capture.pathWaits
    if not capture.watch or #samples < 64 then samples[#samples + 1] = seconds * 1000 end
end
function F.PathSearch(z, job, started, elapsed, complete, valid, calls, bounded)
    local capture = F.Capture
    if not capture or complete and not bounded and elapsed < 2 then return end
    local frame = Frame(capture)
    frame.pathSearches = frame.pathSearches or {}
    if #frame.pathSearches >= 8 then return end
    local from, goal = N.Area(z:GetPos()), N.Area(job.goal)
    local door = z.ZADoorTarget or z.ZABlockedDoor
    frame.pathSearches[#frame.pathSearches + 1] = {atMS = (started - capture.started) * 1000,
        elapsedMS = elapsed, tick = frame.tick, actor = {index = z:EntIndex(), class = z:GetClass()},
        fromArea = from and from:GetID(), goalArea = goal and goal:GetID(),
        from = z:GetPos(), goal = job.goal, routeGoal = job.routeGoal,
        complete = complete, validPartialPath = not complete and valid, bounded = bounded, costCalls = calls,
        blocker = IsValid(door) and {index = door:EntIndex(), class = door:GetClass()} or nil}
end
-- These include nested ZA1 timers. Keep them separate from addonMS to avoid
-- counting Follow/Move/Visible twice. Never time a yielding behavior directly.
function F.ProfileActor(z)
    local capture = F.Capture
    if not capture or not IsValid(z) or not z.GetTable or capture.actors[z] then return end
    local records = {}
    capture.actors[z] = records
    Detail.ProfileActor(capture, z, records)
end
function F.UnprofileActor(z)
    local capture = F.Capture
    local records = capture and capture.actors[z]
    if not records then return end
    if IsValid(z) then
        local overrides = z:GetTable()
        for _, record in ipairs(records) do
            local current = rawget(overrides, record.name)
            if current == record.wrapper then overrides[record.name] = record.override
            else Detail.ActorChanged(capture, z, record, current) end
        end
    end
    capture.actors[z] = nil
end
function F.Trigger(source, intervalMS)
    local capture = F.Capture
    if not capture or not capture.watch or capture.trigger then return end
    capture.trigger = {source = source, intervalMS = intervalMS, atMS = (SysTime() - capture.started) * 1000}
    capture.triggerFrame = capture.lastFrame
    local frames = Frames(capture)
    for i = #frames, math.max(1, #frames - 2), -1 do
        if frames[i].intervalMS and frames[i].intervalMS >= capture.thresholdMS then capture.triggerFrame = frames[i]; break end
    end
    capture.deadline = SysTime() + 3 -- Two-second client tail, plus network delivery time.
    Control(capture, 2)
end
function F.Stop(reason)
    local capture = F.Capture
    if not capture then return end
    local stopped = SysTime()
    CloseFrame(capture)
    for z in pairs(capture.actors) do F.UnprofileActor(z) end
    Detail.Restore(capture)
    F.Capture = nil
    for name, original in pairs(capture.hooks) do
        if hook.GetTable().Think[name] == capture.hookWrappers[name] then hook.Add("Think", name, original) end
    end
    if P.Tick == capture.populationWrapper then P.Tick = capture.population end
    for _, method in ipairs(capture.methods) do
        if method.module[method.name] == method.wrapper then method.module[method.name] = method.original end
    end
    hook.Remove("Tick", "ZA1/PerformanceCapture")
    Control(capture, 0)
    local frames, started, initial, origin = Frames(capture), capture.started, capture.initial, 0
    if capture.watch and #frames > 0 then
        origin = frames[1].atMS
        started, initial = capture.started + origin / 1000, frames[1].initial
        capture.intervals, capture.queueAges, capture.pathWaits, capture.observedSeconds = {}, {}, {}, 0
        for _, frame in ipairs(frames) do
            if frame.intervalMS then
                capture.intervals[#capture.intervals + 1] = frame.intervalMS
                capture.observedSeconds = capture.observedSeconds + frame.intervalMS / 1000
            end
            capture.queueAges[#capture.queueAges + 1] = frame.queuesAfter.oldestPathMS
            for _, wait in ipairs(frame.pathWaits) do capture.pathWaits[#capture.pathWaits + 1] = wait end
            frame.atMS = frame.atMS - origin
        end
    end
    local finish = F.Snapshot()
    local report = {schema = capture.watch and 3 or 2, map = game.GetMap(), started = started, seconds = stopped - started, reason = reason,
        engine = "live Garry's Mod server", expectedTickMS = engine.TickInterval() * 1000,
        firstTickDelayMS = capture.watch and #frames > 0 and (frames[1].tickAtMS and frames[1].tickAtMS - origin or (stopped - started) * 1000)
            or (capture.firstTick and (capture.firstTick - capture.started) * 1000 or (stopped - capture.started) * 1000),
        trailingMS = capture.lastTick and (stopped - capture.lastTick) * 1000 or 0, observedTickSeconds = capture.observedSeconds,
        initial = initial, final = finish, work = Delta(initial.counters, finish.counters),
        serverTickIntervalMS = Distribution(capture.intervals), addonMSPerTick = {}, actorCallMS = {}, measuredAddonMSPerTick = {},
        pathQueueWaitMS = Distribution(capture.pathWaits), oldestPendingPathMSPerTick = Distribution(capture.queueAges),
        lifetimeMaxPathWaitMS = N.Stats.maxQueueAge * 1000, slowTickThresholdMS = math.max(30, engine.TickInterval() * 2000), slowTicks = {}}
    for name, samples in pairs(capture.samples) do report.addonMSPerTick[name] = Distribution(samples) end
    for name, samples in pairs(capture.calls) do report.actorCallMS[name] = Distribution(samples) end
    local totals, parts, dtParts, memories, slow, partial = {}, {}, {}, {}, {}, 0
    for i, frame in ipairs(frames) do
        memories[#memories + 1] = frame.luaMemoryKB
        if frame.intervalMS and frame.tick ~= capture.startTick then
            totals[#totals + 1] = frame.addonMS
            for _, label in ipairs({"awareness", "navigation", "crowd", "population", "Follow", "Move", "Visible"}) do
                parts[label] = parts[label] or {}
                parts[label][#parts[label] + 1] = frame.partsMS[label] or 0
            end
            for _, name in ipairs({"Think", "BehaveUpdate", "BodyUpdate"}) do
                dtParts[name] = dtParts[name] or {}; dtParts[name][#dtParts[name] + 1] = frame.dtPartsMS[name] or 0
            end
        else partial = partial + 1 end
        -- Keep even a first-tick hitch; mark its incomplete cost measurement
        -- rather than hiding the interval because capture began mid-tick.
        if frame.intervalMS and frame.intervalMS >= report.slowTickThresholdMS then
            local following = frames[i + 1]
            slow[#slow + 1] = {tick = frame.tick, atMS = frame.atMS, intervalMS = frame.intervalMS, addonMS = frame.addonMS,
                partial = frame.tick == capture.startTick, partsMS = frame.partsMS, work = frame.work, active = frame.active,
                queuesBefore = frame.queuesBefore, queuesAfter = frame.queuesAfter, luaMemoryKB = frame.luaMemoryKB,
                dtPartsMS = frame.dtPartsMS, followingTickDTMS = following and following.dtPartsMS or {},
                followingTickAddonMS = following and following.addonMS or 0,
                detail = Detail.FrameReport(frame, origin), followingTickDetail = following and Detail.FrameReport(following, origin)}
        end
    end
    report.measuredAddonMSPerTick.total = Distribution(totals)
    for name, samples in pairs(parts) do report.measuredAddonMSPerTick[name] = Distribution(samples) end
    report.dtActorMSPerTick = {}
    for name, samples in pairs(dtParts) do report.dtActorMSPerTick[name] = Distribution(samples) end
    report.luaMemoryKB = {initial = frames[1] and frames[1].luaMemoryKB, final = collectgarbage("count"), distribution = Distribution(memories)}
    report.partialTickRecords, report.slowTickCount = partial, #slow
    local pathSearches = {}
    for _, frame in ipairs(frames) do
        for _, search in ipairs(frame.pathSearches or {}) do
            local row = table.Copy(search); row.atMS = row.atMS - origin
            pathSearches[#pathSearches + 1] = row
        end
    end
    table.sort(pathSearches, function(a, b) return a.elapsedMS > b.elapsedMS end)
    report.recordedPathSearches = #pathSearches
    for i = #pathSearches, 33, -1 do pathSearches[i] = nil end
    report.pathSearches = pathSearches
    report.detail = Detail.Report(capture, frames, origin, Distribution)
    table.sort(slow, function(a, b) return a.intervalMS > b.intervalMS end)
    for i = 1, math.min(16, #slow) do report.slowTicks[i] = slow[i] end
    report.scope = "Tick intervals include scheduling, physics, other addons and client stalls in singleplayer. ZA1 timers exclude rendering and uninstrumented engine work. DT actor callback timings include nested ZA1 timers and must not be added to addonMS. Lua memory is global to the server Lua state. Slow intervals are paired with work in the preceding tick; following-tick addon time is also recorded. Partial ticks are excluded from measuredAddonMSPerTick. Queue waits measure completed builds, including earlier requests."
    if capture.watch then
        report.watch = {captureID = "watch-" .. capture.session, thresholdMS = capture.thresholdMS, armedSeconds = stopped - capture.started,
            windowSeconds = F.WindowSeconds, frameLimit = F.FrameLimit, retainedFrames = #frames, discardedFrames = capture.discardedFrames,
            trigger = capture.trigger, rawCallDistributions = false, clientExpected = IsValid(capture.player), clientReady = capture.clientReady or false}
        if capture.trigger then report.watch.trigger.atMS = capture.trigger.atMS - origin end
        local triggerFrame = capture.triggerFrame
        if triggerFrame then
            report.watch.trigger.tick = triggerFrame.tick
            report.watch.trigger.precedingTick = {addonMS = triggerFrame.addonMS, dtPartsMS = triggerFrame.dtPartsMS,
                luaMemoryKB = triggerFrame.luaMemoryKB, work = triggerFrame.work, detail = Detail.FrameReport(triggerFrame, origin)}
        end
        report.tickHistory = {}
        for _, frame in ipairs(frames) do
            report.tickHistory[#report.tickHistory + 1] = {tick = frame.tick, atMS = frame.atMS, intervalMS = frame.intervalMS,
                addonMS = frame.addonMS, partsMS = frame.partsMS, dtPartsMS = frame.dtPartsMS, luaMemoryKB = frame.luaMemoryKB,
                active = frame.active, work = frame.work, queuesBefore = frame.queuesBefore, queuesAfter = frame.queuesAfter,
                partial = not frame.intervalMS or frame.tick == capture.startTick, detail = Detail.FrameReport(frame, origin)}
        end
        report.client = capture.client
    end
    file.CreateDir("za1")
    local stem = "za1/performance-" .. os.date("%Y%m%d-%H%M%S")
    local path, suffix = stem .. ".json", 0
    while file.Exists(path, "DATA") do suffix = suffix + 1; path = stem .. "-" .. suffix .. ".json" end
    file.Write(path, util.TableToJSON(report, true))
    if capture.watch then F.LastWatch = {session = capture.session, player = capture.player, path = path, report = report} end
    Output(capture.player, "ZA1 capture saved to garrysmod/data/" .. path .. ".")
    return report
end
function F.Start(ply, seconds, thresholdMS)
    if F.Capture then F.Stop("restarted") end
    local capture = {player = ply, started = SysTime(), startTick = engine.TickCount(), initial = F.Snapshot(), intervals = {}, observedSeconds = 0,
        frames = {}, queueAges = {}, pathWaits = {}, samples = {}, calls = {}, methods = {}, hooks = {}, hookWrappers = {}, population = P.Tick,
        actors = setmetatable({}, {__mode = "k"}),
        details = {labels = {}, hooks = {}, methods = {}, skippedHooks = 0, actorChanges = {}, discardedActorChanges = 0}}
    if thresholdMS then
        F.NextSession = (F.NextSession or os.time()) % 4294967295 + 1
        capture.watch, capture.session, capture.thresholdMS = true, F.NextSession, thresholdMS
        capture.ring, capture.discardedFrames = {data = {}, head = 1, count = 0}, 0
        capture.singleplayer = game.SinglePlayer and game.SinglePlayer() or false
        F.LastWatch = nil
    end
    F.Capture = capture
    for name, label in pairs({["ZA1/SharedTick"] = "awareness", ["ZA1/Navigation"] = "navigation", ["ZA1/Crowd"] = "crowd",
        ["ZA1/SpawnCandidates"] = "population", ["ZA1/Obstacles"] = "obstacles"}) do
        local original = hook.GetTable().Think[name]
        if type(original) == "function" then
        capture.hooks[name], capture.samples[label] = original, {}
        local wrapper = function(...)
            local frame, start = Frame(capture), SysTime()
            local result = original(...)
            local elapsed, samples = (SysTime() - start) * 1000, capture.samples[label]
            if not capture.watch then samples[#samples + 1] = elapsed end
            Record(frame, label, elapsed)
            return result
        end
        capture.hookWrappers[name] = wrapper
        hook.Add("Think", name, wrapper)
        end
    end
    capture.samples.population = {}
    capture.populationWrapper = function(...)
        local frame, start = Frame(capture), SysTime()
        local result = capture.population(...)
        local elapsed, samples = (SysTime() - start) * 1000, capture.samples.population
        if not capture.watch then samples[#samples + 1] = elapsed end
        Record(frame, "population", elapsed)
        return result
    end
    P.Tick = capture.populationWrapper
    for _, method in ipairs({{module = N, name = "Follow"}, {module = N, name = "Move"}, {module = M, name = "Visible"}}) do
        method.original = method.module[method.name]
        capture.methods[#capture.methods + 1] = method
        local samples = {}; capture.calls[method.name] = samples
        method.wrapper = function(...)
            local frame, start = Frame(capture), SysTime()
            local result = method.original(...)
            local elapsed = (SysTime() - start) * 1000
            if not capture.watch then samples[#samples + 1] = elapsed end
            Record(frame, method.name, elapsed)
            return result
        end
        method.module[method.name] = method.wrapper
    end
    for z in pairs(M.Zombies) do F.ProfileActor(z) end
    Detail.Start(capture)
    hook.Add("Tick", "ZA1/PerformanceCapture", function()
        local now, frame = SysTime(), Frame(capture)
        if capture.lastFrame ~= frame then
            frame.tickAtMS = (now - capture.started) * 1000
            if capture.lastTick then
                local interval = now - capture.lastTick
                capture.lastFrame.intervalMS = interval * 1000
                if not capture.watch then
                    capture.intervals[#capture.intervals + 1] = interval * 1000
                    capture.observedSeconds = capture.observedSeconds + interval
                elseif interval * 1000 >= capture.thresholdMS and now - capture.started >= 1
                    and not (capture.singleplayer and IsValid(capture.player)) then
                    F.Trigger("server", interval * 1000)
                end
            else capture.firstTick = now end
            capture.lastTick, capture.lastFrame = now, frame
        end
        if capture.watch then
            if capture.deadline and now >= capture.deadline then F.Stop("automatic hitch capture") end
        elseif now - capture.started >= seconds then F.Stop("completed") end
    end)
    if capture.watch then
        Control(capture, 1)
        Output(ply, "ZA1 hitch watch armed at " .. thresholdMS .. " ms. Close the console and play; the next hitch saves automatically after a short tail. The watch stops after saving.")
    else Output(ply, "ZA1 performance capture started for " .. seconds .. " seconds. Exercise the horde normally; no actors are spawned by the capture.") end
end
util.AddNetworkString("ZA1/PerformanceControl")
util.AddNetworkString("ZA1/PerformanceClient")
net.Receive("ZA1/PerformanceClient", function(bits, ply)
    if bits > 196608 or not IsValid(ply) or not ply:IsAdmin() then return end
    local session, action = net.ReadUInt(32), net.ReadUInt(2)
    local capture, saved = F.Capture, F.LastWatch
    if not (capture and capture.watch and capture.session == session and capture.player == ply)
        and not (saved and saved.session == session and saved.player == ply) then return end
    if action == 0 and capture and capture.session == session then capture.clientReady = true
    elseif action == 1 and capture and capture.session == session then
        local interval = net.ReadFloat()
        if interval == interval and interval >= capture.thresholdMS and interval <= 60000 then F.Trigger("client", interval) end
    elseif action == 2 then
        local raw = net.ReadString()
        if #raw > 24000 then return end
        local summary = util.JSONToTable(raw)
        if not istable(summary) or summary.captureID ~= "watch-" .. session or summary.schema ~= 1 then return end
        if capture and capture.session == session then capture.client = summary
        elseif saved and not saved.report.client then
            saved.report.client = summary
            file.Write(saved.path, util.TableToJSON(saved.report, true))
        end
    end
end)
concommand.Add("za1_perf_capture", function(ply, _, args)
    if Authorized(ply) then F.Start(ply, math.Clamp(tonumber(args[1]) or 30, 5, 300)) end
end)
concommand.Add("za1_perf_watch", function(ply, _, args)
    if not Authorized(ply) then return end
    if not IsValid(ply) and game.SinglePlayer and game.SinglePlayer() then
        for _, human in ipairs(player.GetHumans()) do if human:IsAdmin() then ply = human; break end end
    end
    F.Start(ply, nil, math.Clamp(tonumber(args[1]) or 200, 75, 5000))
end)
concommand.Add("za1_perf_stop", function(ply) if Authorized(ply) then F.Stop("stopped") end end)
concommand.Add("za1_perf_report", function(ply)
    if not Authorized(ply) then return end
    local s = F.Snapshot()
    Output(ply, string.format("ZA1: %d active / %d dormant; queues path %d (oldest %.0f ms), hearing %d, crowd %d; %d shared routes. Native paths: %d builds, %.3f ms/build average, %d incomplete; normal/burst limits %d/%d.",
        s.active, s.dormant, s.pathQueue, s.oldestPathMS, s.hearingQueue, s.crowdQueue, s.flows,
        N.Stats.pathBuilds, N.Stats.pathMS / math.max(1, N.Stats.pathBuilds), N.Stats.pathFailures, s.pathBudget, s.pathBurst))
end)
hook.Add("PostCleanupMap", "ZA1/Performance", function() F.Stop("map cleanup") end)
hook.Add("PlayerDisconnected", "ZA1/Performance", function(ply)
    if F.Capture and F.Capture.watch and F.Capture.player == ply then F.Stop("watch owner disconnected") end
end)
