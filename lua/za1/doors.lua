-- Door damage is shared by all attackers. Detached doors are client debris,
-- so neither their physics nor the removed map door can obstruct the horde.
AddCSLuaFile()
local B = {Stats = {probes = 0, hits = 0, broken = 0}, Tracked = setmetatable({}, {__mode = "k"})}
ZA1.Doors = B
local C = ZA1.Config.Doors
local classes = {prop_door_rotating = true, func_door = true, func_door_rotating = true}
local facing = math.cos(math.rad(C.FacingAngle))
if CLIENT then
    net.Receive("ZA1/DoorDebris", function()
        local model, pos, angles = net.ReadString(), net.ReadVector(), net.ReadAngle()
        local skin, groups = net.ReadUInt(8), {}
        local count = net.ReadUInt(8)
        for group = 0, count - 1 do groups[group] = net.ReadUInt(16) end
        local velocity = net.ReadVector()
        local mins, maxs = net.ReadVector(), net.ReadVector()
        ZA1.Debris.Door(model, pos, angles, skin, groups, velocity, mins, maxs)
    end)
    return
end
util.AddNetworkString("ZA1/DoorDebris")
function B.IsDoor(ent)
    return C.Enabled and IsValid(ent) and ent.GetClass and classes[ent:GetClass()] and not ent.ZABrokenDoor
end
function B.Clear(z) z.ZADoorTarget, z.ZADoorGoal = nil, nil end
function B.Observe(z, door, goal)
    if not B.IsDoor(door) then return end
    local center = z:WorldSpaceCenter()
    local point = door:NearestPoint(center)
    if math.abs(point.z - center.z) > ZA1.Config.Melee.HullHeight then return end
    B.Tracked[door], z.ZABlockedDoor = true, door
    if point:DistToSqr(center) > C.ProbeDistance ^ 2 then return end
    z.ZADoorTarget, z.ZADoorGoal = door, Vector(goal)
end
local function Probe(z, goal, distance)
    local pos = z:GetPos()
    local delta = goal - pos; delta.z = 0
    if delta:LengthSqr() == 0 then return end
    local mins, maxs = z:GetCollisionBounds()
    B.Stats.probes = B.Stats.probes + 1
    return util.TraceHull({start = pos + Vector(0, 0, 2),
        endpos = pos + delta:GetNormalized() * math.min(delta:Length(), distance) + Vector(0, 0, 2),
        mins = mins, maxs = maxs, mask = MASK_NPCSOLID, collisiongroup = z:GetCollisionGroup(), filter = z})
end
function B.Try(z)
    if not C.Enabled or z.ZAActing or z.ZAFuse or z:IsPossessed() or not z:Alive() then return false end
    local goal = z.ZADoorGoal or z.ZAMoveGoal
    if not goal then B.Clear(z); return false end
    if CurTime() >= (z.ZANextDoorProbe or 0) then
        z.ZANextDoorProbe = CurTime() + C.ProbeInterval
        local tr = Probe(z, goal, C.ProbeDistance)
        B.Clear(z)
        if tr and tr.Hit then B.Observe(z, tr.Entity, goal) end
    end
    local door = z.ZADoorTarget
    if not B.IsDoor(door) then B.Clear(z); return false end
    local center, point = z:WorldSpaceCenter(), door:NearestPoint(z:WorldSpaceCenter())
    local delta = point - center; delta.z = 0
    local N = ZA1.Navigation
    if delta:LengthSqr() > C.AttackRange ^ 2 then
        local approach = point - delta:GetNormalized() * (C.AttackRange * 0.6)
        approach.z = z:GetPos().z
        N.Move(z, approach, 2)
        return true
    end
    ZA1.Crowd.ReleaseClaim(z)
    N.Face(z, point)
    if delta:LengthSqr() > 0 and z:GetForward():Dot(delta:GetNormalized()) < facing then
        if not z:ZATurnTowards(point) then z:FaceTowards(point) end
        return true
    end
    if z.ZASpecial == "suicide" then
        ZA1.Specials.Arm(z) -- Its existing authored detonation event breaks the blocker.
    elseif z.MeleeAnimations and #z.MeleeAnimations > 0 and CurTime() >= (z.ZANextMelee or 0) then
        z:ZAPlayAttack(z.MeleeAnimations[math.random(#z.MeleeAnimations)], door)
    end
    return true
end
local function Material(door)
    local phys = door:GetPhysicsObject()
    return IsValid(phys) and phys:GetMaterial() or "wood"
end
local function ClearPassage(z, point)
    local seen, N = {}, ZA1.Navigation
    local mins, maxs = z:GetCollisionBounds()
    local forward = z:GetForward()
    for offset = -1, 1 do
        local sample = point + forward * (offset * 48); sample.z = z:GetPos().z
        local area = N.Area(sample)
        if IsValid(area) and area.MarkAsUnblocked and area:IsBlocked() and not seen[area] then
            seen[area] = true
            local floor = area:GetClosestPointOnArea(sample)
            if math.abs(floor.z - sample.z) <= z.loco:GetStepHeight() then
                local pos = floor + Vector(0, 0, 2)
                local tr = util.TraceHull({start = pos, endpos = pos, mins = mins, maxs = maxs,
                    mask = MASK_NPCSOLID, collisiongroup = z:GetCollisionGroup(),
                    filter = function(ent) return IsValid(ent) and ent ~= z and not ent.ZA1Zombie and not ent:IsPlayer() end})
                if not tr.Hit and not tr.StartSolid and not tr.AllSolid then area:MarkAsUnblocked() end
            end
        end
    end
end
function B.Break(z, door, point)
    if not B.IsDoor(door) then return end
    door.ZABrokenDoor = true -- Several authored attack events can arrive in one tick.
    local material = Material(door)
    local velocity = z:GetForward() * C.KnockSpeed + Vector(0, 0, 80)
    net.Start("ZA1/DoorDebris")
    net.WriteString(door:GetModel()); net.WriteVector(door:GetPos()); net.WriteAngle(door:GetAngles())
    net.WriteUInt(door:GetSkin(), 8)
    local groups = door:GetNumBodyGroups()
    net.WriteUInt(groups, 8)
    for group = 0, groups - 1 do net.WriteUInt(door:GetBodygroup(group), 16) end
    net.WriteVector(velocity)
    local mins, maxs = door:GetCollisionBounds()
    net.WriteVector(mins); net.WriteVector(maxs)
    net.SendPVS(door:GetPos())
    door:EmitSound(material:find("metal", 1, true) and "physics/metal/metal_box_break1.wav" or "physics/wood/wood_crate_break1.wav", 80, 100)
    door:SetNotSolid(true)
    local phys = door:GetPhysicsObject()
    if IsValid(phys) then phys:EnableCollisions(false) end
    door:Remove()
    ClearPassage(z, point)
    B.Stats.broken = B.Stats.broken + 1
    B.Clear(z)
    ZA1.Navigation.InvalidateRoutes()
end
function B.Hit(z, door, point)
    if not B.IsDoor(door) then return false end
    if z.ZADoorTarget ~= door and not z:IsPossessed() then return true end
    local delta = door:NearestPoint(z:WorldSpaceCenter()) - z:WorldSpaceCenter()
    if math.abs(delta.z) > ZA1.Config.Melee.HullHeight then return true end
    delta.z = 0
    if delta:LengthSqr() > C.AttackRange ^ 2 or delta:LengthSqr() > 0 and z:GetForward():Dot(delta:GetNormalized()) < facing then return true end
    door.ZAZombieDoorHealth = (door.ZAZombieDoorHealth or C.Health) - (z.ZASpecialSettings and z.ZASpecialSettings.MeleeDamage or C.Damage)
    B.Stats.hits = B.Stats.hits + 1
    local material = Material(door)
    door:EmitSound(material:find("metal", 1, true) and "physics/metal/metal_box_impact_hard1.wav" or "physics/wood/wood_crate_impact_hard1.wav", 75, math.random(95, 105), 0.8)
    if door.ZAZombieDoorHealth <= 0 then B.Break(z, door, point) end
    return true
end
function B.Blast(z, pos, radius, damage)
    local door = z.ZADoorTarget
    if not B.IsDoor(door) then return end
    local point = door:NearestPoint(pos)
    if point:DistToSqr(pos) > radius ^ 2 then return end
    local tr = util.TraceLine({start = pos, endpos = point, filter = z, mask = MASK_SHOT})
    if tr.Hit and tr.Entity ~= door then return end
    door.ZAZombieDoorHealth = (door.ZAZombieDoorHealth or C.Health) - damage
    if door.ZAZombieDoorHealth <= 0 then B.Break(z, door, point) end
end
-- Map cleanup recreates doors. Opening/closing an existing door invalidates
-- stale reachability and shared failed-route decisions without rebuilding nav.
hook.Add("AcceptInput", "ZA1/Doors", function(ent, input)
    if not B.IsDoor(ent) or not B.Tracked[ent] then return end
    input = input:lower()
    if input == "open" or input == "close" or input == "toggle" or input == "unlock" then
        if not ent.ZADoorRefreshPending then
            ent.ZADoorRefreshPending = true
            timer.Simple(0, function()
                if IsValid(ent) then ent.ZADoorRefreshPending = nil end
                ZA1.Navigation.InvalidateRoutes()
            end)
        end
    end
end)
