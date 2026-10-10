if SERVER then AddCSLuaFile() end
-- The server selects models and poses. Clients only smooth their presentation.
local P = {}; ZA1.Presentation = P
function P.Setup(z)
    z:NetworkVar("Int", 0, "ZAHurtSet")
    z:NetworkVar("String", 0, "ZAModel")
    z:NetworkVar("String", 1, "ZAServerSequence")
    z:NetworkVar("Float", 0, "ZALookYaw")
    z:NetworkVar("Float", 1, "ZALookPitch")
    z:NetworkVar("Float", 2, "ZAGaitRate")
    z:NetworkVar("Bool", 0, "ZALocomoting")
end
function P.Initialize(z)
    local model = z.ZASpecial and ZA1.SpecialAssets.Enemies[z.ZASpecial].Model or z.Models[1]
    if z:GetModel() ~= model then z:SetModel(model) end
    if z.SetZAModel then z:SetZAModel(model) end
end
function P.Animation(z)
    if not z.SetZALocomoting then return end
    local flags = z:GetAnimState():SelectAnimFlags(z) or 0
    local dynamic = DT_Base.ANIM_STATE_LOCOMOTION_DYNAMIC_RATE
    local moving = not z.ZAActing and bit.band(flags, dynamic) == dynamic
    local sequence = z:GetSequence()
    if sequence ~= z.ZAPublishedSequence then
        z.ZAPublishedSequence = sequence; z:SetZAServerSequence(z:GetSequenceName(sequence))
    end
    if moving then
        if z.ZAPresentationWalk ~= z.WalkAnimation or z.ZAPresentationRun ~= z.RunAnimation then
            z.ZAPresentationWalk, z.ZAPresentationRun = z.WalkAnimation, z.RunAnimation
            z.ZAPresentationWalkID = z:LookupSequence(z.WalkAnimation)
            z.ZAPresentationRunID = z.RunAnimation == z.WalkAnimation and z.ZAPresentationWalkID or z:LookupSequence(z.RunAnimation)
        end
        moving = sequence == z.ZAPresentationWalkID or sequence == z.ZAPresentationRunID
    end
    z:SetZALocomoting(moving)
    if moving then z:SetZAGaitRate(z:GetPlaybackRate()) end
end
if SERVER then return end

function P.Update(z)
    if z:IsDormant() then return end
    if not z.ZASpecial and z:GetHitboxSet()~=z:GetZAHurtSet() then z:SetHitboxSet(z:GetZAHurtSet()) end
    local now = CurTime()
    if now >= (z.ZANextModelCheck or 0) then
        z.ZANextModelCheck = now + 1
        local wanted = z:GetZAModel()
        if wanted ~= "" and wanted ~= z:GetModel() then
            local sequence, cycle, rate = z:GetSequence(), z:GetCycle(), z:GetPlaybackRate()
            z:SetModel(wanted)
            local named = z:LookupSequence(z:GetZAServerSequence())
            if named ~= -1 then sequence = named end
            z:SetSequence(sequence); z:SetCycle(cycle); z:SetPlaybackRate(rate)
        end
    end
    local dt = math.min(FrameTime(), .1)
    local yaw = math.Approach(z.ZAClientLookYaw or 0, z:GetZALookYaw(), ZA1.Config.Look.Speed * dt)
    local pitch = math.Approach(z.ZAClientLookPitch or 0, z:GetZALookPitch(), ZA1.Config.Look.Speed * dt)
    if yaw ~= z.ZAClientLookYaw or pitch ~= z.ZAClientLookPitch then
        z:SetPoseParameter("look_yaw", yaw); z:SetPoseParameter("look_pitch", pitch)
        z.ZAClientLookYaw, z.ZAClientLookPitch = yaw, pitch
        if z.InvalidateBoneCache then z:InvalidateBoneCache() end
    end
    if z:GetZALocomoting() then
        -- A short filter removes snapshot-to-snapshot rate jumps. The engine
        -- still owns sequence/cycle interpolation and one-shot actions.
        local rate = z.ZAClientGaitRate or z:GetZAGaitRate()
        rate = rate + (z:GetZAGaitRate() - rate) * math.min(dt / .1, 1)
        z.ZAClientGaitRate = rate; z:SetPlaybackRate(rate)
    else z.ZAClientGaitRate = nil end
end
concommand.Add("za1_mp_report", function()
    for _, z in ipairs(ents.GetAll()) do
        if z.ZA1Zombie then
            print("ZA1", z:EntIndex(), z:GetClass(), "model=" .. z:GetModel(),
                "server model=" .. z:GetZAModel(), "sequence=" .. z:GetSequenceName(z:GetSequence()),
                "server sequence=" .. z:GetZAServerSequence(),
                "cycle=" .. string.format("%.3f", z:GetCycle()), "rate=" .. string.format("%.3f", z:GetPlaybackRate()))
        end
    end
end)
