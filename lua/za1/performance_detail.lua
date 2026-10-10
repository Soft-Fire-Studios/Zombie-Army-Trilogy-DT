-- Temporary diagnostics around non-yielding operations. DT's registered hook
-- functions run unchanged; only calls concerning registered ZA1 actors count.
local D = {Revision = "bounded-paths-visible-spawns-2026-10-10", SlowMS = 10, SlowLimit = 8, HookLimit = 128}
local F, M, N, G, P = ZA1.Performance, ZA1.Manager, ZA1.Navigation, ZA1.Crowd, ZA1.Population
local actorMethods = {"OnThink", "ZAUpdateSight", "IsAbleToSee", "UpdateRelationship", "UpdateDetection", "UpdateTarget",
    "GetEnemy", "UpdateEnemy", "OnEntityDetected", "HandleAnimEvent", "EmitSound", "EyePosAndAngles",
    "IsYieldFlagSet", "UpdateAnimation", "UpdateMoveParameters", "FrameAdvance"}
local hookEvents = {"DT/TickNextBot", "DT/PostTickNextBot", "DT/UpdateNextBotTarget", "DT/PostUpdateNextBotTarget",
    "DT/SightGained", "DT/SightKept", "DT/SightLost", "DT/EntityDetected", "DT/EntityLost", "DT/RelationshipChanged"}
local modules = {
    {name = "awareness", module = M, methods = {"Rebuild", "ProcessHearing", "Alert", "Noise"}},
    {name = "navigation", module = N, methods = {"BuildGraph", "BuildPaths", "Compute", "Guide", "Expand", "Reachable"}},
    {name = "crowd", module = G, methods = {"Rebuild", "Neighbors", "Process", "Steer", "AttackGoal"}},
    {name = "population", module = P, methods = {"Tick", "FindSpawn", "ScanCandidates"}},
    {name = "doors", module = ZA1.Doors, methods = {"Observe", "Hit", "Break", "Blast"}},
    {name = "recovery", module = ZA1.Recovery, methods = {"Tick"}, actorArgument = 1},
    {name = "look", module = ZA1.Look, methods = {"Update"}, actorArgument = 1}
}
local stageLabels = { ["crowd:AttackGoal.inputs"] = true, ["crowd:AttackGoal.claims"] = true,
    ["crowd:AttackGoal.queue"] = true, ["crowd:AttackGoal.waiting"] = true }
local function Source(func)
    local info = debug.getinfo(func, "S") or {}
    return {source = info.source, firstLine = info.linedefined, lastLine = info.lastlinedefined}
end
local function Label(capture, record)
    local details = capture.details
    local info = details.labels[record.label]
    if not info then
        info = {kind = record.kind, implementations = {}}
        details.labels[record.label] = info
    end
    local source = Source(record.sourceOriginal or record.original)
    -- Variants may inherit different implementations. Describe each source
    -- once, without retaining its function or entity in the saved metadata.
    for _, old in ipairs(info.implementations) do
        if old.source == source.source and old.firstLine == source.firstLine then return end
    end
    if #info.implementations < 8 then info.implementations[#info.implementations + 1] = source end
end
local function Identity(ent)
    if not IsValid(ent) then return end
    return {index = ent.EntIndex and ent:EntIndex(), class = ent.GetClass and ent:GetClass()}
end
local function SlowCall(capture, frame, record, z, started, elapsed, value, options)
    local calls = frame.slowDetailCalls
    if not calls then calls = {}; frame.slowDetailCalls = calls end
    if #calls >= D.SlowLimit and elapsed <= calls[#calls].elapsedMS then return end
    local info = {label = record.label, elapsedMS = elapsed, atMS = (started - capture.started) * 1000,
        actor = Identity(z), luaMemoryKBAfter = collectgarbage("count")}
    if IsValid(z) then
        info.sequence = z.GetSequenceName and z.GetSequence and z:GetSequenceName(z:GetSequence())
        info.acting, info.turning, info.attacking = z.ZAActing or false, z.ZATurning or false, z.ZAAttacking or false
        info.hasMoveGoal = z.ZAMoveGoal ~= nil
    end
    if record.name == "HandleAnimEvent" then info.event, info.options = value, options
    elseif record.name == "EmitSound" then info.sound = type(value) == "string" and value or nil
    elseif type(value) == "number" or type(value) == "string" then info.argument = value
    elseif value ~= nil and type(value) ~= "boolean" and IsValid(value) then info.target = Identity(value) end
    local index = #calls + 1
    while index > 1 and elapsed > calls[index - 1].elapsedMS do
        calls[index] = calls[index - 1]; index = index - 1
    end
    calls[index] = info
    calls[D.SlowLimit + 1] = nil
end
local function Finish(capture, frame, record, z, started, value, options, ...)
    local finished = SysTime()
    if F.Capture ~= capture then return ... end
    local elapsed = (finished - started) * 1000
    if record.kind == "actorCallback" then
        frame.dtPartsMS[record.name] = (frame.dtPartsMS[record.name] or 0) + elapsed
    else
        if not frame.detailMS then frame.detailMS, frame.detailCalls, frame.detailMaxMS = {}, {}, {} end
        local label = record.label
        frame.detailMS[label] = (frame.detailMS[label] or 0) + elapsed
        frame.detailCalls[label] = (frame.detailCalls[label] or 0) + 1
        frame.detailMaxMS[label] = math.max(frame.detailMaxMS[label] or 0, elapsed)
    end
    if elapsed >= D.SlowMS then SlowCall(capture, frame, record, z, started, elapsed, value, options) end
    -- This estimates completion bookkeeping only. Nested wrapper overhead is
    -- included in its parent's wall time; these are not pure CPU samples.
    frame.detailBookkeepingMS = (frame.detailBookkeepingMS or 0) + (SysTime() - finished) * 1000
    return ...
end
local function Invoke(capture, record, z, ...)
    local frame = F.Frame(capture)
    local value, options
    if record.actorArgument then value = select(record.actorArgument + 1, ...) end
    if record.name == "HandleAnimEvent" then options = select(6, ...) end
    local started = SysTime()
    return Finish(capture, frame, record, z, started, value, options, record.original(...))
end
function F.RecordStage(capture, label, z, target, started)
    if F.Capture ~= capture or not stageLabels[label] then return end
    local stages = capture.details.stages
    if not stages then stages = {}; capture.details.stages = stages end
    local record = stages[label]
    if not record then
        -- Internal phase timers are fixed, non-yielding sites inside the
        -- profiled crowd operation. Resolve its original source once.
        for _, parent in ipairs(capture.details.methods) do
            if parent.label == "crowd:AttackGoal" then
                record = {label = label, kind = "addonStage", original = parent.original}
                stages[label] = record
                Label(capture, record)
                capture.details.labels[label].parent = parent.label
                break
            end
        end
        if not record then return end
    end
    return Finish(capture, F.Frame(capture), record, z, started, target)
end
function D.ProfileActor(capture, z, records)
    local overrides = z:GetTable()
    local function Wrap(name, kind)
        local original = z[name]
        if type(original) ~= "function" then return end
        local record = {name = name, label = "actor:" .. name, kind = kind, original = original,
            override = rawget(overrides, name), actorArgument = 1}
        record.wrapper = function(self, ...)
            if F.Capture ~= capture then return original(self, ...) end
            return Invoke(capture, record, self, self, ...)
        end
        overrides[name] = record.wrapper
        if z[name] ~= record.wrapper then
            -- Engine/metatable methods win over the entity's Lua table. Do not
            -- leave ineffective overrides or report zero calls as measurements.
            overrides[name] = record.override
            capture.details.shadowedMethods = capture.details.shadowedMethods or {}
            capture.details.shadowedMethods[name] = Source(original)
            return
        end
        Label(capture, record)
        records[#records + 1] = record
    end
    for _, name in ipairs({"Think", "BehaveUpdate", "BodyUpdate"}) do Wrap(name, "actorCallback") end
    -- DoThink/ZAPlayOnce/combat/turn routines can yield. Timing across a yield
    -- would falsely count animation waiting as a synchronous stall.
    for _, name in ipairs(actorMethods) do Wrap(name, "actorMethod") end
end
function D.Start(capture)
    for _, event in ipairs(hookEvents) do
        for identifier, original in pairs(hook.GetTable()[event] or {}) do
            if type(original) == "function" and #capture.details.hooks < D.HookLimit then
                local record = {event = event, identifier = identifier, label = event .. ":" .. tostring(identifier),
                    original = original, kind = "dtHook", actorArgument = type(identifier) == "string" and 1 or 2}
                Label(capture, record)
                record.wrapper = function(...)
                    local z = select(record.actorArgument, ...)
                    if F.Capture ~= capture or not capture.actors[z] then return original(...) end
                    return Invoke(capture, record, z, ...)
                end
                capture.details.hooks[#capture.details.hooks + 1] = record
                hook.Add(event, identifier, record.wrapper)
            else capture.details.skippedHooks = capture.details.skippedHooks + 1 end
        end
    end
    for _, group in ipairs(modules) do
        for _, name in ipairs(group.methods) do
            local original = group.module and group.module[name]
            if type(original) == "function" then
                local record = {module = group.module, name = name, label = group.name .. ":" .. name,
                    original = original, kind = "addonFunction", actorArgument = group.actorArgument}
                if original == capture.populationWrapper then record.sourceOriginal = capture.population end
                Label(capture, record)
                record.wrapper = function(...)
                    if F.Capture ~= capture then return original(...) end
                    local actor = record.actorArgument and select(record.actorArgument, ...)
                    if record.actorArgument and not (IsValid(actor) and M.Zombies[actor]) then return original(...) end
                    return Invoke(capture, record, actor, ...)
                end
                capture.details.methods[#capture.details.methods + 1] = record
                group.module[name] = record.wrapper
            end
        end
    end
end
function D.Restore(capture)
    local changed = {}
    local known, unmeasured = {}, {}
    for _, record in ipairs(capture.details.hooks) do
        known[record.event] = known[record.event] or {}
        known[record.event][record.identifier] = true
        local current = hook.GetTable()[record.event]
        if current and current[record.identifier] == record.wrapper then
            hook.Add(record.event, record.identifier, record.original)
        else changed[#changed + 1] = record.label end
    end
    for _, event in ipairs(hookEvents) do
        for identifier, callback in pairs(hook.GetTable()[event] or {}) do
            if (not known[event] or not known[event][identifier]) and #unmeasured < 32 and type(callback) == "function" then
                unmeasured[#unmeasured + 1] = {label = event .. ":" .. tostring(identifier), implementation = Source(callback)}
            end
        end
    end
    for _, record in ipairs(capture.details.methods) do
        if record.module[record.name] == record.wrapper then record.module[record.name] = record.original
        else changed[#changed + 1] = record.label end
    end
    capture.details.changedDuringCapture = changed
    capture.details.unmeasuredAtStop = unmeasured
end
function D.ActorChanged(capture, z, record, replacement)
    local changes = capture.details.actorChanges
    if #changes >= 32 then capture.details.discardedActorChanges = capture.details.discardedActorChanges + 1; return end
    changes[#changes + 1] = {actor = Identity(z), label = record.label,
        replacement = type(replacement) == "function" and Source(replacement) or {type = type(replacement)}}
end
function D.FrameReport(frame, origin)
    local calls = {}
    for _, call in ipairs(frame.slowDetailCalls or {}) do
        local copy = {}; for name, value in pairs(call) do copy[name] = value end
        copy.atMS = copy.atMS - (origin or 0)
        calls[#calls + 1] = copy
    end
    return {ms = frame.detailMS or {}, calls = frame.detailCalls or {}, maxCallMS = frame.detailMaxMS or {},
        slowCalls = calls, bookkeepingMS = frame.detailBookkeepingMS or 0}
end
function D.Report(capture, frames, origin, distribution)
    local samples, counts, maxima, slow = {}, {}, {}, {}
    for label, info in pairs(capture.details.labels) do
        if info.kind ~= "actorCallback" then samples[label], counts[label], maxima[label] = {}, 0, 0 end
    end
    for _, frame in ipairs(frames) do
        if frame.intervalMS and frame.tick ~= capture.startTick then
            for label, values in pairs(samples) do
                values[#values + 1] = frame.detailMS and frame.detailMS[label] or 0
                counts[label] = counts[label] + (frame.detailCalls and frame.detailCalls[label] or 0)
                maxima[label] = math.max(maxima[label], frame.detailMaxMS and frame.detailMaxMS[label] or 0)
            end
        end
        for _, call in ipairs(D.FrameReport(frame, origin).slowCalls) do
            call.tick = frame.tick; slow[#slow + 1] = call
        end
    end
    table.sort(slow, function(a, b) return a.elapsedMS > b.elapsedMS end)
    for i = #slow, 33, -1 do slow[i] = nil end
    local result = {revision = D.Revision, labels = capture.details.labels, perTickMS = {}, calls = counts, maxCallMS = maxima,
        slowCalls = slow, slowCallThresholdMS = D.SlowMS, slowCallsPerTickLimit = D.SlowLimit,
        skippedHooks = capture.details.skippedHooks, changedDuringCapture = capture.details.changedDuringCapture,
        unmeasuredAtStop = capture.details.unmeasuredAtStop, actorChanges = capture.details.actorChanges,
        discardedActorChanges = capture.details.discardedActorChanges,
        shadowedMethods = capture.details.shadowedMethods or {},
        scope = "Inclusive wall timings: nested hooks, methods, addon timers and actor callbacks overlap and must not be summed. Bookkeeping is a partial overhead estimate. No yielding behaviors are timed. Global Lua memory after a slow call does not identify a collector phase."}
    for label, values in pairs(samples) do result.perTickMS[label] = distribution(values) end
    return result
end
return D
