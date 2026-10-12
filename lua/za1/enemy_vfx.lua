if SERVER then AddCSLuaFile() end
-- Original enemy effects share the existing atlas/history renderer. This
-- module only routes appearance states and cosmetic cues; it performs no AI.
AddCSLuaFile("za1/enemy_vfx_data.lua")
AddCSLuaFile("za1/enemy_vfx_bindings.lua")
local data, bindings = include("za1/enemy_vfx_data.lua"), include("za1/enemy_vfx_bindings.lua")
local F = ZA1.FireVFX
game.AddParticles("particles/zat_enemies.pcf")
F.RegisterData(data)
local E = ZA1.EnemyVFX or {}; ZA1.EnemyVFX = E
local function Kind(owner) return owner.ZASpecial or "grunt" end
local function Role(owner, role)
    local roles = bindings.PulseIDs[Kind(owner)]
    local id = roles and roles[role]
    return id, id and bindings.Pulses[id]
end
for _, points in pairs(bindings.Attachments) do
    for _, point in pairs(points) do
        point.Offset, point.Rotation = Vector(unpack(point.Position)), Angle(unpack(point.Angles))
    end
end
local function Position(owner, anchor, kind)
    if not IsValid(owner) then return end
    if not anchor then return owner:GetPos(), owner:GetAngles() end
    local points = bindings.Attachments[kind or Kind(owner)]
    local point = points and points[anchor]
    if not point then return end
    if point.Frame == "Actor" then
        -- CONA owns an actor-space transform. Source has already converted
        -- that frame; an unweighted model root must not add a second basis.
        return owner:GetPos(), owner:GetAngles()
    end
    if (kind or Kind(owner)) == "general_skull" and owner.ZAOrbitRenderPosition then
        return LocalToWorld(point.Offset * owner:GetModelScale(), point.Rotation,
            owner.ZAOrbitRenderPosition, owner.ZAOrbitRenderAngles)
    end
    local model = owner:GetModel()
    if owner.ZAEnemyVFXModel ~= model then owner.ZAEnemyVFXModel, owner.ZAEnemyVFXBones = model, {} end
    local bones = owner.ZAEnemyVFXBones
    local bone = bones[point.Bone]
    if bone == nil then
        bone = owner:LookupBone(point.Bone)
        if bone == nil then return end
        bones[point.Bone] = bone
    end
    local matrix = owner:GetBoneMatrix(bone)
    if not matrix then return end
    return LocalToWorld(point.Offset * owner:GetModelScale(), point.Rotation,
        matrix:GetTranslation(), matrix:GetAngles())
end
E.Position = Position

if SERVER then
    util.AddNetworkString("ZA1/EnemyVFX")
    function E.SetState(owner, state)
        if not IsValid(owner) or owner.ZAEnemyVFXState == state then return end
        owner.ZAEnemyVFXState = state
        owner:SetNW2String("za1_enemy_vfx_state", state)
    end
    function E.Activate(owner, role)
        if not IsValid(owner) or not Role(owner, role) then return false end
        -- Initialize can precede the first client entity snapshot. Persist this
        -- short cue until the actual animated socket can be evaluated there.
        owner:SetNW2String("za1_enemy_vfx_ready", role)
        owner:SetNW2Float("za1_enemy_vfx_ready_until", CurTime() + 2)
        return true
    end
    function E.Pulse(owner, role, position, angles)
        if not IsValid(owner) then return false end
        local id = Role(owner, role)
        if not id then return false end
        position, angles = position or owner:WorldSpaceCenter(), angles or owner:GetAngles()
        if not isvector(position) or not isangle(angles) then return false end
        -- Both impact and activation messages are validated before net.Start,
        -- so malformed data cannot leave another addon with an open message.
        net.Start("ZA1/EnemyVFX"); net.WriteUInt(id, 7); net.WriteEntity(owner)
        net.WriteVector(position); net.WriteAngle(angles); net.WriteBool(false)
        net.SendPVS(position)
        return true
    end
    function E.SpawnTrail(owner, child, role)
        if not IsValid(owner) or not IsValid(child) then return false end
        local id = Role(owner, role or "spawn_trail")
        if not id then return false end
        local start, finish, angles = owner:WorldSpaceCenter(), child:WorldSpaceCenter(), owner:GetAngles()
        if not isvector(start) or not isvector(finish) or not isangle(angles) then return false end
        net.Start("ZA1/EnemyVFX"); net.WriteUInt(id, 7); net.WriteEntity(owner)
        net.WriteVector(start); net.WriteAngle(angles); net.WriteBool(true); net.WriteVector(finish)
        net.SendPVS(finish)
        return true
    end
    function E.Stop(owner) E.SetState(owner, "stopped") end
    return
end

E.Generation = (E.Generation or 0) + 1
local tracked, pending, travelling = {}, {}, {}
local function Definition(value)
    -- Do not mutate shared pulse definitions when adding a per-row resolver.
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    result.Resolver = Position
    return result
end
local function Launch(owner, definition, fallback, angles)
    local position, orientation
    if definition.World then position, orientation = fallback, angles
    else position, orientation = Position(owner, definition.Anchor, definition.Kind) end
    if not position then
        -- Named hardpoints must resolve to their own pose. An entity-origin
        -- fallback would visibly move eyes/hands to the wrong part of the body.
        if definition.Anchor and IsValid(owner) then return end
        position, orientation = fallback, angles
    end
    if not F.IsVisible(position) then return end
    local row = F.StartAt(IsValid(owner) and owner or nil, Definition(definition), position, orientation, false)
    if row and definition.EmissionTime then row.StopAt = CurTime() + definition.EmissionTime end
    return row
end
local function Pulse(owner, entry, fallback, angles)
    for _, definition in ipairs(entry.Layers) do
        if definition.Anchor and IsValid(owner) and not Position(owner, definition.Anchor, definition.Kind) then
            if #pending < 64 then pending[#pending + 1] = {Owner=owner, Definition=definition,
                Position=fallback, Angles=angles, Until=CurTime()+.5} end
        else Launch(owner, definition, fallback, angles) end
    end
end
local function Clear(group, immediate)
    for _, row in pairs(group) do F.StopWorld(row, immediate) end
end
local function SameColorRemap(a, b)
    return a == b or a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
local function Same(a, b)
    return a and b and a.Effect == b.Effect and a.Anchor == b.Anchor
        and a.ModelSurface == b.ModelSurface and a.Detached == b.Detached and a.World == b.World
        and SameColorRemap(a.SourceColorRemap, b.SourceColorRemap)
end
local function Reconcile(owner, group, wanted)
    for role, row in pairs(group) do
        if not wanted or not Same(wanted[role], row.Definition) then F.StopWorld(row, false); group[role] = nil end
    end
    for role, definition in pairs(wanted or {}) do
        local row = group[role]
        if not row or row.Looping and row.Dead then
            local position, angles = Position(owner, definition.Anchor, definition.Kind)
            if position then
                row = F.StartAt(owner, Definition(definition), position, angles, true)
                if row then row.Definition = definition; group[role] = row end
            end
        end
    end
end
function E.Update(owner)
    if not IsValid(owner) then return end
    local kind = Kind(owner)
    if not bindings.Bodies[kind] and not bindings.Phases[kind] and kind ~= "skeleton" and kind ~= "suicide" then return end
    if owner.ZAEnemyVFXFrame == FrameNumber() and owner.ZAEnemyVFXGeneration == E.Generation then return end
    owner.ZAEnemyVFXFrame, owner.ZAEnemyVFXGeneration = FrameNumber(), E.Generation
    if ZA1.EyeGlow then ZA1.EyeGlow.Update(owner) end
    tracked[owner] = true
    local group = owner.ZAEnemyVFXGroup
    if owner:IsDormant() or not F.IsVisible(owner:GetPos()) then
        if group then Clear(group.Body, true); Clear(group.Phase, true); owner.ZAEnemyVFXGroup = nil end
        return
    end
    if not group or group.Generation ~= E.Generation then
        if group then Clear(group.Body, true); Clear(group.Phase, true) end
        group = {Body={}, Phase={}, Generation=E.Generation}; owner.ZAEnemyVFXGroup = group
    end
    tracked[owner] = group
    local state = owner:GetNW2String("za1_enemy_vfx_state", "idle")
    local stopped = state == "stopped" or state == "dead"
    Reconcile(owner, group.Body, not stopped and bindings.Bodies[kind] or nil)
    local phases = bindings.Phases[kind]
    Reconcile(owner, group.Phase, phases and phases[state] or nil)
    local ready = owner:GetNW2String("za1_enemy_vfx_ready", "")
    if ready ~= "" and ready ~= owner.ZAEnemyVFXReady and owner:GetNW2Float("za1_enemy_vfx_ready_until", 0) > CurTime() then
        local _, entry = Role(owner, ready)
        if entry then
            for _, definition in ipairs(entry.Layers) do
                if definition.Anchor and not Position(owner, definition.Anchor, definition.Kind) then return end
            end
            Pulse(owner, entry, owner:WorldSpaceCenter(), owner:GetAngles())
        end
        owner.ZAEnemyVFXReady = ready
    end
end
net.Receive("ZA1/EnemyVFX", function()
    local id, owner, position, angles, travel = net.ReadUInt(7), net.ReadEntity(), net.ReadVector(), net.ReadAngle(), net.ReadBool()
    local finish = travel and net.ReadVector()
    local entry = bindings.Pulses[id]
    if not entry or not F.IsVisible(position) and not (finish and F.IsVisible(finish)) then return end
    if IsValid(owner) and entry.Kind ~= Kind(owner) then return end
    if not travel then Pulse(owner, entry, position, angles); return end
    -- The shared Source spawn presentation transports the authored ordered
    -- trail to an accepted child. It never moves either gameplay entity.
    if #travelling >= 32 then return end
    for _, definition in ipairs(entry.Layers) do
        local adapter = Definition(definition)
        adapter.World, adapter.Detached, adapter.Anchor = true, true, nil
        local row = F.StartAt(nil, adapter, position, angles, false)
        if row then
            local info = data.Effects[definition.Effect]
            travelling[#travelling+1] = {Row=row, Start=position, Finish=finish,
                Position=Vector(position.x, position.y, position.z), Angles=angles,
                Began=CurTime(), Duration=math.max(.01, info.Duration)}
        end
    end
end)
hook.Add("Think", "ZA1/EnemyVFX", function()
    local now = CurTime()
    for owner in pairs(tracked) do if IsValid(owner) then E.Update(owner) else tracked[owner] = nil end end
    for index = #pending, 1, -1 do
        local cue = pending[index]
        if not IsValid(cue.Owner) or now >= cue.Until then table.remove(pending, index)
        elseif Position(cue.Owner, cue.Definition.Anchor, cue.Definition.Kind) then
            Launch(cue.Owner, cue.Definition, cue.Position, cue.Angles); table.remove(pending, index)
        end
    end
    for index = #travelling, 1, -1 do
        local path = travelling[index]
        local phase = math.Clamp((now-path.Began)/path.Duration, 0, 1)
        local p, a, b = path.Position, path.Start, path.Finish
        p.x, p.y, p.z = a.x+(b.x-a.x)*phase, a.y+(b.y-a.y)*phase, a.z+(b.z-a.z)*phase
        path.Row.Position = p
        if path.Row.Effect and path.Row.Effect:IsValid() then path.Row.Effect:SetControlPoint(0, p) end
        if path.Row.Ribbon then ZA1.FireVFXRibbons.Update(path.Row.Ribbon, p, path.Angles) end
        if phase == 1 or path.Row.Dead then F.StopWorld(path.Row, false); table.remove(travelling, index) end
    end
end)
hook.Add("EntityRemoved", "ZA1/EnemyVFX", function(owner)
    local group = tracked[owner]
    tracked[owner] = nil
    if type(group) == "table" then Clear(group.Body, true); Clear(group.Phase, true) end
end)
hook.Add("PostCleanupMap", "ZA1/EnemyVFX", function()
    for owner in pairs(tracked) do
        local group = owner.ZAEnemyVFXGroup
        if group then Clear(group.Body, true); Clear(group.Phase, true) end
        owner.ZAEnemyVFXGroup, owner.ZAEnemyVFXFrame = nil, nil
    end
    table.Empty(tracked); table.Empty(pending); table.Empty(travelling)
end)
