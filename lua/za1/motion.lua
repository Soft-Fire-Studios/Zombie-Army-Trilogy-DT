-- Read the existing model's extracted motion once, shared by the whole horde.
-- Navigation owns walking/collision at the clip's mean forward speed. Playback
-- follows its gait phases, so those phases cannot accelerate/brake the actor.
local H = {}
ZA1.Motion = H
local walks, lunges = {}, {}
local samples = 32
function H.Walk(z, sequence)
    local model = z:GetModel()
    walks[model] = walks[model] or {}
    local cached = walks[model][sequence]
    if cached then return cached end
    local duration = z:SequenceDuration(sequence)
    cached = {cruise = 0}
    if duration > 0 then
        for i = 1, samples do
            local ok, delta = z:GetSequenceMovement(sequence, (i - 1) / samples, i / samples)
            local speed = ok and delta.x * samples / duration or 0
            cached.cruise = cached.cruise + speed / samples
            cached[i] = math.max(0, speed)
        end
    end
    walks[model][sequence] = cached
    return cached
end
function H.UpdateWalk(z)
    if z.ZAActing or not z:IsOnGround() then return end
    local state = z:GetAnimState()
    local flags = state:SelectAnimFlags(z) or 0
    if bit.band(flags, DT_Base.ANIM_STATE_LOCOMOTION_DYNAMIC_RATE) ~= DT_Base.ANIM_STATE_LOCOMOTION_DYNAMIC_RATE then return end
    local sequence = z:GetSequence()
    -- Do not pace idle, falling, transitions or one-shot actions like a walk.
    if sequence ~= z:LookupSequence(z.WalkAnimation) and sequence ~= z:LookupSequence(z.RunAnimation) then return end
    local speeds = H.Walk(z, sequence)
    if #speeds == 0 then return end
    local phase = (z:GetCycle() % 1) * samples + 0.5
    local index = math.floor(phase)
    local a, b = speeds[(index - 1) % samples + 1], speeds[index % samples + 1]
    local speed = (a + (b - a) * (phase - index)) * z:GetModelScale()
    local rate = state:SelectAnimRate(z) or 1
    local cruise = speeds.cruise * z:GetModelScale() * rate
    z.loco:SetDesiredSpeed(cruise)
    if z.ZACruiseSpeed ~= cruise then
        z.ZACruiseSpeed = cruise
        local nav = ZA1.Config.Navigation
        z.loco:SetAcceleration(cruise / nav.AccelerationTime)
        z.loco:SetDeceleration(cruise / nav.DecelerationTime)
    end
    -- Real velocity accounts for acceleration, braking and obstructions.
    -- A truly stationary part of a clip must advance so it can leave that pose.
    -- Source networks playback in [-4, 12]. Keep server/client gait rates
    -- finite and in the same range, including tiny authored motion phases.
    z:SetPlaybackRate(math.Clamp(speed > 0.01 and z:GetVelocity():Length2D() / speed or rate, 0, 12))
end
function H.Lunges(z)
    local model = z:GetModel()
    local key=model..":"..tostring(z.ZASeverMask or 0)
    if lunges[key] then return lunges[key] end
    local cached = {reach = 0}
    for _, clip in ipairs(z.ZALungeClips or ZA1.Config.Animations.Lunge) do
        local sequence = z:LookupSequence(clip.Sequence)
        if sequence >= 0 then
            local entry = {sequence = clip.Sequence, hits = {}}
            for _, cycle in ipairs(clip.Hits) do
                local ok, delta = z:GetSequenceMovement(sequence, 0, cycle)
                if ok then
                    entry.hits[#entry.hits + 1] = delta
                    cached.reach = math.max(cached.reach, delta:Length2D())
                end
            end
            local ok, delta = z:GetSequenceMovement(sequence, 0, 1)
            if ok and #entry.hits > 0 then entry.travel = delta; cached[#cached + 1] = entry end
        end
    end
    lunges[key] = cached
    return cached
end
