if SERVER then AddCSLuaFile();AddCSLuaFile("za1/ritual_assets.lua") end
-- Keep the original one-burst glyph and its appearance curves. A slower
-- playback clock holds it through Source emergence without looping/restarts.
local S = {}; ZA1.ResurrectionFX = S
local A=include("za1/ritual_assets.lua")
local symbol, embers = "Demonic_Resurection", "Embers_Resurection"
if SERVER then
    function S.Spawn(actor, position, normal, lifetime)
        if not IsValid(actor) then return end
        lifetime = math.Clamp(math.max(lifetime or 1,ZA1.Config.Recovery.ResurrectionEffectTime), .05, 14)
        actor.ZAResurrectionFXUntil = CurTime() + lifetime
        net.Start("ZA1/Resurrection"); net.WriteEntity(actor)
        net.WriteVector(position + normal * .4); net.WriteVector(normal)
        net.WriteFloat(lifetime); net.SendPVS(position)
    end
    function S.Emerge(actor, sequence)
        if not IsValid(actor) or actor.ZAEmergenceVFXPlayed
            or not IsValid(actor.ZADirector) then return false end
        -- A summoned child can already own this same cue when its coroutine
        -- reaches emergence. Do not reset its finite authored ground burst.
        actor.ZAEmergenceVFXPlayed = true
        if (actor.ZAResurrectionFXUntil or 0) > CurTime() then return false end
        local id = actor:LookupSequence(sequence)
        if not id or id < 0 then return false end
        local position, normal = actor:GetPos(), Vector(0, 0, 1)
        local ground = util.TraceLine({start = position + Vector(0, 0, 12),
            endpos = position - Vector(0, 0, 24), mask = MASK_SOLID, filter = actor})
        if ground.Hit and not ground.StartSolid and ground.HitNormal.z > .5 then
            position, normal = ground.HitPos, ground.HitNormal
        end
        S.Spawn(actor, position, normal, actor:SequenceDuration(id))
        return true
    end
    return
end
local effects = {}
local function Stop(row)
    ZA1.FireVFX.StopWorld(row.symbol, true)
    ZA1.FireVFX.StopWorld(row.embers, false)
    if row.sound then row.sound:Stop();row.sound=nil end
end
local function Audio(row)
    local listener=LocalPlayer()
    if not IsValid(listener) or listener:EyePos():DistToSqr(row.position)>GetConVar("za1_event_sound_distance"):GetFloat()^2 then return end
    local ring=A.Pentagram
    sound.Play(ring.Files[math.random(#ring.Files)],row.position,75,
        math.Round(math.Rand(ring.Pitch[1],ring.Pitch[2])*100),math.Rand(ring.Volume[1],ring.Volume[2]))
    -- The native ember binding loops. Give that loop the cue's lifetime and
    -- owner, so cancellation/removal cannot leave an environmental sound.
    if IsValid(row.actor) then
        local binding=A.Embers
        row.sound=CreateSound(row.actor,binding.Files[math.random(#binding.Files)])
        if row.sound then row.sound:PlayEx(math.Rand(binding.Volume[1],binding.Volume[2]),
            math.Round(math.Rand(binding.Pitch[1],binding.Pitch[2])*100)) end
    end
end
local function Remove(actor)
    for index = #effects, 1, -1 do
        if effects[index].actor == actor then Stop(effects[index]); table.remove(effects, index) end
    end
end
net.Receive("ZA1/ResurrectionStop", function() Remove(net.ReadEntity()) end)
net.Receive("ZA1/Resurrection", function()
    local actor, position, normal, life = net.ReadEntity(), net.ReadVector(), net.ReadVector(), net.ReadFloat()
    life = math.Clamp(life, .05, 14)
    if IsValid(actor) then Remove(actor) end
    if #effects >= 100 then return end
    local angles = normal:Angle()
    angles:RotateAroundAxis(angles:Right(), -90)
    local now, vfx = CurTime(), ZA1.FireVFX
    local glow = vfx.World(symbol, position, angles,life,math.min(1,A.Glyph.NativeParticleLife/life))
    local sparks = vfx.World(embers, position, angles, math.min(life, 10))
    if not glow and not sparks then return end
    local row = {actor = actor, hadActor = IsValid(actor), position = position, angles = angles,
        symbol = glow, embers = sparks, expires = now + life}
    effects[#effects+1]=row
    Audio(row)
end)
hook.Add("Think", "ZA1/ResurrectionFX", function()
    local now = CurTime()
    for index = #effects, 1, -1 do
        local row = effects[index]
        if now >= row.expires or row.hadActor and not IsValid(row.actor) then
            Stop(row); table.remove(effects, index)
        end
    end
end)
local function Cleanup()
    for _, row in ipairs(effects) do
        ZA1.FireVFX.StopWorld(row.symbol, true); ZA1.FireVFX.StopWorld(row.embers, true)
        if row.sound then row.sound:Stop();row.sound=nil end
    end
    table.Empty(effects)
end
hook.Add("PostCleanupMap", "ZA1/ResurrectionFX", Cleanup)
hook.Add("ShutDown", "ZA1/ResurrectionFX", Cleanup)
