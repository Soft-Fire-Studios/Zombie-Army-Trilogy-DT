if SERVER then AddCSLuaFile() end
-- Original named Trilogy systems. Gameplay remains in elites.lua; this module
-- owns their Source attachment, stop/drain, distance and multiplayer lifetime.
AddCSLuaFile("za1/fire_vfx_data.lua")
AddCSLuaFile("za1/fire_vfx_bindings.lua")
AddCSLuaFile("za1/fire_vfx_ribbons.lua")
ZA1.FireVFXData = include("za1/fire_vfx_data.lua")
local bindings = include("za1/fire_vfx_bindings.lua")
game.AddParticles("particles/zat_fire.pcf")
for name in pairs(ZA1.FireVFXData.Systems) do PrecacheParticleSystem(name) end
include("za1/fire_vfx_ribbons.lua")
local F = ZA1.FireVFX or {}; ZA1.FireVFX = F
function F.RegisterData(extra)
    for _, key in ipairs({"Systems", "Effects", "Ribbons", "Sprites"}) do
        local target = ZA1.FireVFXData[key]
        for name, definition in pairs(extra[key] or {}) do
            if target[name] and target[name] ~= definition then error("Duplicate original VFX system: " .. name) end
            target[name] = definition
        end
    end
    for name in pairs(extra.Systems or {}) do PrecacheParticleSystem(name) end
end
local pulses = bindings.Pulses
if SERVER then
    util.AddNetworkString("ZA1/FireVFX")
    function F.Phase(z, phase)
        if not IsValid(z) or z.ZASpecial ~= "fire" then return end
        if z.ZAFireVFXPhase == phase then return end
        z.ZAFireVFXPhase = phase
        z:SetNW2String("za1_fire_vfx_phase", phase)
    end
    function F.Death(z)
        if not IsValid(z) or z.ZASpecial ~= "burning" or z.ZAFireDeathVFX then return end
        z.ZAFireDeathVFX = true
        F.Pulse(z, "ash")
    end
    function F.DemonDeath(z)
        if not IsValid(z) or z.ZASpecial ~= "fire" or z.ZAFireDeathVFX then return false end
        z.ZAFireDeathVFX = true
        return F.Pulse(z, "death")
    end
    function F.Pulse(z, role)
        local id = bindings.PulseIDs[role]
        if not id or not IsValid(z) then return false end
        if pulses[id].Kind ~= z.ZASpecial then return false end
        -- Validate before starting a message, including the fallback used when
        -- a dying/spawning actor has not yet reached the receiving client.
        local position, angles = z:WorldSpaceCenter(), z:GetAngles()
        net.Start("ZA1/FireVFX"); net.WriteEntity(z); net.WriteUInt(id, 3)
        net.WriteVector(position); net.WriteAngle(angles); net.SendPVS(position)
        return true
    end
    function F.Stop(z) F.Phase(z, "") end
    return
end

F.Tracked, F.Rows = F.Tracked or {}, F.Rows or {}
F.Generation = (F.Generation or 0) + 1
local rows, tracked, systems = F.Rows, F.Tracked, ZA1.FireVFXData.Systems
local ribbons, distance = ZA1.FireVFXRibbons, GetConVar("za1_effect_distance")
local lastFrame, observer, limitSquared
local function Visible(position)
    local frame = FrameNumber()
    if frame ~= lastFrame then
        local ply = LocalPlayer()
        observer = IsValid(ply) and ply:EyePos() or nil
        limitSquared = (distance and distance:GetFloat() or 3000) ^ 2
        lastFrame = frame
    end
    return observer and observer:DistToSqr(position) <= limitSquared
end
F.IsVisible = Visible
for _, points in pairs(bindings.Attachments) do
    for _, point in pairs(points) do
        point.Offset = Vector(unpack(point.Position))
        point.Rotation = Angle(unpack(point.Angles))
    end
end
local function Position(owner, anchor, kind)
    if not IsValid(owner) then return end
    if not anchor then return owner:GetPos(), owner:GetAngles() end
    local points = bindings.Attachments[kind or owner.ZASpecial]
    local point = points and points[anchor]
    if not point then return end
    local model = owner:GetModel()
    if owner.ZAFireVFXModel ~= model or not owner.ZAFireVFXAttachments then
        owner.ZAFireVFXModel, owner.ZAFireVFXBones, owner.ZAFireVFXAttachments = model, {}, {}
    end
    if point.Attachment then
        local id = owner.ZAFireVFXAttachments[point.Attachment]
        if not id then
            id = owner:LookupAttachment(point.Attachment)
            if not id or id <= 0 then return end
            owner.ZAFireVFXAttachments[point.Attachment] = id
        end
        local attachment = owner:GetAttachment(id)
        if not attachment then return end
        -- The compiled attachment evaluates the attachment-only weapon bone.
        -- Its fixed adapter reproduces the native HMPT in every exported pose.
        return LocalToWorld(point.Offset * owner:GetModelScale(), point.Rotation,
            attachment.Pos, attachment.Ang)
    end
    local bone = owner.ZAFireVFXBones[point.Bone]
    if bone == nil then
        bone = owner:LookupBone(point.Bone)
        if bone == nil then return end
        owner.ZAFireVFXBones[point.Bone] = bone
    end
    local matrix = owner:GetBoneMatrix(bone)
    if not matrix then return end
    -- SMD bones retain native local axes beneath motion_root. The derived
    -- hardpoint offset is already in Source units; rotate through the bone once.
    return LocalToWorld(point.Offset * owner:GetModelScale(), point.Rotation,
        matrix:GetTranslation(), matrix:GetAngles())
end
F.Position = Position
local function Place(row, position, angles)
    row.Position, row.Angles = position, angles
    if row.Effect and row.Effect:IsValid() then
        row.Effect:SetControlPoint(0, position)
        row.Effect:SetControlPointOrientation(0, angles)
    end
    if row.Ribbon then ribbons.Update(row.Ribbon, position, angles) end
end
local function Stop(row, immediate)
    if immediate then
        if row.Effect and row.Effect:IsValid() then row.Effect:StopEmissionAndDestroyImmediately() end
        if row.Ribbon then ribbons.Stop(row.Ribbon, true) end
        row.Dead = true
    elseif not row.Stopped then
        if row.Effect and row.Effect:IsValid() then row.Effect:StopEmission(false, false, true) end
        if row.Ribbon then ribbons.Stop(row.Ribbon, false) end
        row.Stopped, row.Expires = true, CurTime() + row.Drain + .1
    end
end
local function Start(owner, definition, position, angles, looping)
    local info = systems[definition.Effect]
    if not info then return end
    local cap = ribbons.Limits.Instances
    if #rows >= cap then
        -- A replaced cue has already destroyed its previous handles. Reclaim
        -- those rows before testing the cap, even between two Think hooks.
        for index = #rows, 1, -1 do if rows[index].Dead then table.remove(rows, index) end end
        if #rows >= cap then return end
    end
    if info.HasSourceChildren == nil then
        info.HasSourceChildren = false
        for _, layer in ipairs(info.Layers) do
            if layer.Renderer == "Source_PCF" then info.HasSourceChildren = true; break end
        end
    end
    local effect
    if info.HasSourceChildren then
        effect = IsValid(owner) and not definition.Detached and CreateParticleSystem(owner, definition.Effect, PATTACH_CUSTOMORIGIN, 0)
            or CreateParticleSystemNoEntity(definition.Effect, position, angles)
    end
    local ribbonOwner
    if not definition.Detached and not definition.World then ribbonOwner = owner end
    local rate=math.Clamp(definition.PlaybackRate or 1,.05,1)
    local options = {KeepOnRemove=definition.Detached,PlaybackRate=rate,
        SourceColorRemap=definition.SourceColorRemap}
    if definition.ModelSurface and IsValid(owner) then options.SurfaceOwner = owner end
    local ribbon = ribbons.Start(ribbonOwner, definition.Effect, position, angles, nil, options)
    if not effect and not ribbon then return end
    if effect and definition.ModelSurface and IsValid(owner) then effect:SetControlPointEntity(0, owner) end
    local looping = looping and info.Loop
    local row = {Name = definition.Effect, Owner = owner, Anchor = definition.Anchor, Effect = effect,
        Kind = definition.Kind, KeepOnRemove = definition.Detached,
        Resolver = definition.Resolver,
        MaxLife = info.MaxLife/rate, Drain = (info.MaxParticleLife or info.MaxLife)/rate,
        Looping = looping,
        -- Native FXET expiry keeps updating its independently timed FXSTs.
        -- Explicit cue cancellation stops emission; natural expiry drains it.
        Expires = not looping and CurTime() + math.max(info.Duration, info.MaxLife)/rate + .1 or nil,
        Fixed = definition.World or not IsValid(owner), Position = position, Angles = angles}
    row.Ribbon = ribbon
    rows[#rows + 1] = row
    Place(row, position, angles)
    return row
end
F.StartAt = Start
local function ClearGroup(group, immediate)
    for _, row in pairs(group) do Stop(row, immediate) end
end
local function Reconcile(owner, group, wanted)
    for key, row in pairs(group) do
        if not wanted or not wanted[key] then Stop(row, false); group[key] = nil end
    end
    for key, definition in pairs(wanted or {}) do
        local row = group[key]
        local alive = row and (row.Effect and row.Effect:IsValid() or row.Ribbon and not row.Ribbon.dead)
        if not row or row.Looping and (row.Dead or not alive) then
            if group[key] then Stop(group[key], true) end
            local position, angles = Position(owner, definition.Anchor)
            if position then group[key] = Start(owner, definition, position, angles, true) end
        end
    end
end
local function Update(owner)
    if not IsValid(owner) then return end
    local kind = owner.ZASpecial
    if kind ~= "fire" and kind ~= "burning" then return end
    local frame = FrameNumber()
    if owner.ZAFireVFXFrame == frame and owner.ZAFireVFXGeneration == F.Generation then return end
    owner.ZAFireVFXFrame, owner.ZAFireVFXGeneration = frame, F.Generation
    local group = owner.ZAFireVFXGroup
    if owner:IsDormant() or not Visible(owner:GetPos()) then
        if group then
            ClearGroup(group.Body, true); ClearGroup(group.Phase, true)
            owner.ZAFireVFXGroup = nil
        end
        return
    end
    if not group or group.Generation ~= F.Generation then
        if group then ClearGroup(group.Body, true); ClearGroup(group.Phase, true) end
        group = {Body = {}, Phase = {}, Generation = F.Generation}
        owner.ZAFireVFXGroup = group
    end
    local powered = owner:GetNW2Bool("za1_flames", false)
    Reconcile(owner, group.Body, powered and bindings.Bodies[kind] or nil)
    local phase = owner:GetNW2String("za1_fire_vfx_phase", "")
    Reconcile(owner, group.Phase, kind == "fire" and bindings.Phases[phase] or nil)
end
function F.Update(owner)
    if not IsValid(owner) then return end
    if owner.ZASpecial ~= "fire" and owner.ZASpecial ~= "burning" then return end
    tracked[owner] = true
    Update(owner)
end
function F.Projectile(owner)
    local position, angles = owner:GetPos(), owner:GetAngles()
    local row = owner.ZAFireVFXProjectile
    if owner:IsDormant() or not Visible(position) then
        if row then Stop(row, true); owner.ZAFireVFXProjectile = nil end
        return
    end
    if not row or row.Dead then
        row = Start(owner, {Effect = "Undead_Fire_Demon_Fireball"}, position, angles, true)
        owner.ZAFireVFXProjectile = row
    end
    return row
end
function F.World(name, position, angles, lifetime, playbackRate)
    if not Visible(position) then return end
    local row = Start(nil, {Effect = name,PlaybackRate=playbackRate}, position, angles, false)
    if row and lifetime then
        row.StopAt = CurTime() + math.max(0, lifetime)
        row.Expires = row.StopAt + row.Drain + .1
    end
    return row
end
function F.Impact(position, angles)
    -- Original weapon PFXExplosion and radial-damage PFX are separate bindings.
    -- Both are cosmetic; damage, sound and ignition still execute once.
    F.World("Undead_Fire_Demon_Fireball_Explosion", position, angles)
    F.World("Grenade_BASE_concussion", position, angles)
end
function F.StopProjectile(row) if row then Stop(row, true) end end
function F.StopWorld(row, immediate) if row then Stop(row, immediate) end end
net.Receive("ZA1/FireVFX", function()
    local owner, id, fallback, angles = net.ReadEntity(), net.ReadUInt(3), net.ReadVector(), net.ReadAngle()
    local definition = pulses[id]
    if not definition or not Visible(fallback) then return end
    local position, orientation = Position(owner, definition.Anchor, definition.Kind)
    if id == bindings.PulseIDs.death then
        -- Death removes the actor in the same server tick. Both finite impact
        -- systems must start in world space and retain their delayed emission.
        F.Impact(position or fallback, angles)
        return
    end
    Start(IsValid(owner) and owner or nil, definition, position or fallback, orientation or angles, false)
end)
hook.Add("Think", "ZA1/FireVFX", function()
    for owner in pairs(tracked) do
        if IsValid(owner) then Update(owner) else tracked[owner] = nil end
    end
    local now = CurTime()
    for index = #rows, 1, -1 do
        local row = rows[index]
        if not row.Fixed and not IsValid(row.Owner) and row.KeepOnRemove then
            row.Fixed, row.Owner = true, nil
            if row.Effect and row.Effect:IsValid() then row.Effect:SetControlPointEntity(0, NULL) end
            Stop(row, false)
        end
        if not row.Fixed and not IsValid(row.Owner) or not Visible(row.Fixed and row.Position or row.Owner:GetPos())
            or not row.Fixed and row.Owner:IsDormant() or row.Expires and now >= row.Expires then Stop(row, true) end
        if row.StopAt and now >= row.StopAt then Stop(row, false) end
        if row.Dead then table.remove(rows, index)
        elseif not row.Fixed then
            local position, angles = (row.Resolver or Position)(row.Owner, row.Anchor, row.Kind)
            if position then Place(row, position, angles) end
        end
    end
end)
hook.Add("PostCleanupMap", "ZA1/FireVFX", function()
    for _, row in ipairs(rows) do Stop(row, true) end
    for owner in pairs(tracked) do
        if IsValid(owner) then owner.ZAFireVFXGroup, owner.ZAFireVFXFrame = nil, nil end
    end
    table.Empty(rows); table.Empty(tracked)
end)
