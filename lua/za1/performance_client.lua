-- Armed only by the server for the requesting administrator. Use unclamped
-- SysTime intervals: RealFrameTime caps long gaps at 100 ms.
local C = {}
ZA1.PerformanceClient = C
C.WindowSeconds, C.FrameLimit = 8, 2048
local function Blocked()
    return gui.IsGameUIVisible() or gui.IsConsoleVisible() or not system.HasFocus()
end
local function Send(capture, action, value)
    net.Start("ZA1/PerformanceClient")
    net.WriteUInt(capture.session, 32); net.WriteUInt(action, 2)
    if action == 1 then net.WriteFloat(value) elseif action == 2 then net.WriteString(value) end
    net.SendToServer()
end
local function Push(capture, frame)
    while capture.count > 0 do
        local oldest = capture.frames[capture.head]
        if capture.count < C.FrameLimit and frame.atMS - oldest.atMS <= C.WindowSeconds * 1000 then break end
        if capture.count < C.FrameLimit and oldest == capture.triggerFrame then break end
        capture.frames[capture.head] = nil
        capture.head, capture.count = capture.head % C.FrameLimit + 1, capture.count - 1
        capture.discarded = capture.discarded + 1
    end
    capture.frames[(capture.head + capture.count - 1) % C.FrameLimit + 1] = frame
    capture.count = capture.count + 1
end
local function Distribution(values)
    if #values == 0 then return {samples = 0, mean = 0, p95 = 0, p99 = 0, max = 0} end
    local sum = 0; for _, v in ipairs(values) do sum = sum + v end
    table.sort(values)
    return {samples = #values, mean = sum / #values, p95 = values[math.ceil(#values * .95)], p99 = values[math.ceil(#values * .99)], max = values[#values]}
end
function C.Stop(reason)
    local capture = C.Capture
    if not capture then return end
    C.Capture = nil
    hook.Remove("PreRender", "ZA1/PerformanceClient")
    hook.Remove("PostRender", "ZA1/PerformanceClient")
    hook.Remove("Think", "ZA1/PerformanceClientUI")
    local frames, intervals, activeIntervals, render, slow = {}, {}, {}, {}, {}
    for i = 0, capture.count - 1 do
        local frame = capture.frames[(capture.head + i - 1) % C.FrameLimit + 1]
        frames[#frames + 1] = frame
        if frame.intervalMS then
            intervals[#intervals + 1] = frame.intervalMS
            if not frame.blockedGap then activeIntervals[#activeIntervals + 1] = frame.intervalMS end
            slow[#slow + 1] = frame
        end
        if frame.renderMS then render[#render + 1] = frame.renderMS end
    end
    local origin = frames[1] and frames[1].atMS or 0
    for _, frame in ipairs(frames) do frame.atMS = frame.atMS - origin end
    local summary = {schema = 1, captureID = "watch-" .. capture.session, reason = reason, map = game.GetMap(),
        armedSeconds = SysTime() - capture.started, seconds = SysTime() - capture.started - origin / 1000,
        thresholdMS = capture.thresholdMS, retainedFrames = #frames, discardedFrames = capture.discarded,
        firstRetainedMSAfterArm = origin, suppressedHitches = capture.suppressed, frameIntervalMS = Distribution(intervals),
        activeFrameIntervalMS = Distribution(activeIntervals), renderPhaseMS = Distribution(render), slowFrames = {},
        luaMemoryKB = {initial = frames[1] and frames[1].luaMemoryKB, final = collectgarbage("count")},
        scope = "PreRender-to-PreRender wall intervals include client simulation, rendering, scheduling and singleplayer server work. renderPhaseMS covers PreRender through PostRender, not GPU execution time. Console/menu/focus gaps and the one-second resume grace are marked blockedGap and excluded from active intervals and automatic triggers. Client and server clocks are independent; captureID links their files."}
    table.sort(slow, function(a, b) return a.intervalMS > b.intervalMS end)
    for i = 1, math.min(16, #slow) do summary.slowFrames[i] = slow[i] end
    if capture.trigger then
        summary.trigger = {source = capture.trigger.source, intervalMS = capture.trigger.intervalMS, atMS = capture.trigger.atMS - origin}
        if capture.triggerFrame then
            local frame = capture.triggerFrame
            summary.trigger.precedingFrame = {intervalMS = frame.intervalMS, renderMS = frame.renderMS,
                luaMemoryKB = frame.luaMemoryKB, blockedGap = frame.blockedGap}
        end
    end
    file.CreateDir("za1")
    local stem = "za1/performance-client-" .. os.date("%Y%m%d-%H%M%S")
    local path, suffix = stem .. ".json", 0
    while file.Exists(path, "DATA") do suffix = suffix + 1; path = stem .. "-" .. suffix .. ".json" end
    summary.path = path
    local report = {}; for key, value in pairs(summary) do report[key] = value end
    report.frames = frames
    file.Write(path, util.TableToJSON(report, false))
    local raw = util.TableToJSON(summary, false)
    if #raw <= 24000 then Send(capture, 2, raw) end
    MsgN("ZA1 client frame capture saved to garrysmod/data/" .. path .. ".")
    return report
end
function C.Trigger(source, intervalMS)
    local capture = C.Capture
    if not capture or capture.trigger then return end
    local now = SysTime()
    capture.trigger = {source = source, intervalMS = intervalMS, atMS = (now - capture.started) * 1000}
    capture.triggerFrame = capture.last
    capture.deadline = now + 2
    if source == "client" then Send(capture, 1, intervalMS) end
end
function C.Start(session, thresholdMS)
    if C.Capture then C.Stop("restarted") end
    local capture = {session = session, thresholdMS = thresholdMS, started = SysTime(), lastBlocked = SysTime(),
        frames = {}, head = 1, count = 0, discarded = 0, suppressed = 0}
    C.Capture = capture
    -- UI still updates when gameplay/rendering is paused. Remember observed
    -- console/menu/focus changes even when PreRender stops running.
    hook.Add("Think", "ZA1/PerformanceClientUI", function()
        if Blocked() then capture.lastBlocked = SysTime() end
    end)
    hook.Add("PreRender", "ZA1/PerformanceClient", function()
        local now, blocked = SysTime(), Blocked()
        if blocked then capture.lastBlocked = now end
        local ready = not blocked and now - capture.lastBlocked >= 1
        local frame = {atMS = (now - capture.started) * 1000, blocked = blocked, luaMemoryKB = collectgarbage("count")}
        if capture.last then
            local previous = capture.last
            previous.intervalMS, previous.blockedGap = (now - capture.lastAt) * 1000, not ready or not capture.lastReady
            if previous.intervalMS >= thresholdMS then
                if previous.blockedGap then capture.suppressed = capture.suppressed + 1
                else C.Trigger("client", previous.intervalMS) end
            end
        end
        Push(capture, frame)
        capture.last, capture.lastAt, capture.lastReady = frame, now, ready
        if ready and not capture.readySent then capture.readySent = true; Send(capture, 0) end
        if capture.deadline and now >= capture.deadline then C.Stop("automatic hitch capture") end
    end)
    hook.Add("PostRender", "ZA1/PerformanceClient", function()
        if C.Capture == capture and capture.last then capture.last.renderMS = (SysTime() - capture.lastAt) * 1000 end
    end)
end
net.Receive("ZA1/PerformanceControl", function()
    local session, action, threshold = net.ReadUInt(32), net.ReadUInt(2), net.ReadFloat()
    if action == 1 then C.Start(session, threshold)
    elseif C.Capture and C.Capture.session == session then
        if action == 2 then C.Trigger("server") elseif action == 0 then C.Stop("server stopped") end
    end
end)
hook.Add("ShutDown", "ZA1/PerformanceClient", function() C.Stop("shutdown") end)
