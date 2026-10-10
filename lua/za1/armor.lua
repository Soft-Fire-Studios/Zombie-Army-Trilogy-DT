-- Armor is weighted model geometry. Only bullet hits and breakoff read bones;
-- no attached server props, physics constraints or per-frame collision work.
local function Create(V, settings, prefix)
local A = {}
local gearBones, healthKey = prefix .. "GearBones", prefix .. "ArmorHealth"
local scaleKey, shapesKey, bodyKey = prefix .. "ArmorScale", prefix .. "ArmorShapes", prefix .. "BodyShapes"
local plates = {}
for _, plate in ipairs(V.Armor) do plates[plate.Name] = plate end

local function Worn(z, plate)
    local names = plate.States[z:GetBodygroup(plate.Bodygroup)]
    return names and names[z:GetSkin() == 1 and 2 or 1]
end

function A.EquipmentPieces(z)
    local names = {}
    for _, plate in ipairs(V.Armor) do
        local name = Worn(z, plate)
        if name then names[#names + 1] = name end
    end
    return names
end

function A.HasArmor(z)
    for _, plate in ipairs(V.Armor) do
        if Worn(z, plate) then return true end
    end
    return false
end

function A.Initialize(z, preset)
    if V.Bodygroups.sword then z:SetBodygroup(V.Bodygroups.sword, 0) end
    if preset then
        z:SetSkin(preset.Skin or 0)
        for _, plate in ipairs(V.Armor) do
            local state = preset[plate.Name] or (plate.Name == "chest" and preset.Chest or plate.Name == "helmet" and preset.Helmet or 1)
            z:SetBodygroup(plate.Bodygroup, state)
        end
    end
    z[gearBones] = {}
    for name, piece in pairs(V.Pieces) do
        if piece.Boxes and z[gearBones][piece.Bone] == nil then
            z[gearBones][piece.Bone] = z:LookupBone(piece.Bone)
        end
    end
    for _, box in ipairs(V.BodyHitboxes) do
        if z[gearBones][box.Bone] == nil then z[gearBones][box.Bone] = z:LookupBone(box.Bone) end
    end
    A.Restore(z)
end

function A.Capture(z)
    local health = {}
    for name, value in pairs(z[healthKey] or {}) do health[name] = value end
    return health
end

function A.Restore(z, saved)
    local health = {}
    for _, plate in ipairs(V.Armor) do
        local maximum = settings.Health[plate.Name] or settings.DefaultHealth
        health[plate.Name] = Worn(z, plate) and math.Clamp(saved and saved[plate.Name] or maximum, 0, maximum) or 0
    end
    z[healthKey] = health
    if V.Bodygroups.sword then z:SetBodygroup(V.Bodygroups.sword, 0) end
end

function A.Refresh(z)
    if V.Bodygroups.sword then z:SetBodygroup(V.Bodygroups.sword, 0) end
    z:SetHitboxSet(A.HasArmor(z) and V.ArmoredSet or 0)
    local scale = z:GetModelScale()
    if z[scaleKey] == scale then return end
    z[scaleKey], z[shapesKey], z[bodyKey] = scale, {}, {}
    for name, piece in pairs(V.Pieces) do
        if piece.Boxes then
            local b = piece.HitBounds
            local shape = {Bone = z[gearBones][piece.Bone], Boxes = {},
                Bounds = {Vector(b[1], b[2], b[3]) * scale, Vector(b[4], b[5], b[6]) * scale}}
            for _, box in ipairs(piece.Boxes) do
                shape.Boxes[#shape.Boxes + 1] = {Vector(box[1], box[2], box[3]) * scale, Vector(box[4], box[5], box[6]) * scale}
            end
            z[shapesKey][name] = shape
        end
    end
    for _, box in ipairs(V.BodyShapes or V.BodyHitboxes) do
        local weak = z.ZASpecialAssets.Weakpoint
        if not weak or box.Group ~= weak.Group then
            local b = box.Bounds
            local shape = {Bone = z[gearBones][box.Bone], Group = box.Group, Boxes = {},
                Bounds = {Vector(b[1], b[2], b[3]) * scale, Vector(b[4], b[5], b[6]) * scale}}
            for _, bounds in ipairs(box.Boxes or {b}) do
                shape.Boxes[#shape.Boxes + 1] = {Vector(bounds[1], bounds[2], bounds[3]) * scale,
                    Vector(bounds[4], bounds[5], bounds[6]) * scale}
            end
            z[bodyKey][#z[bodyKey] + 1] = shape
        end
    end
end

local function Intersect(start, direction, shape, matrix)
    local transform = shape.Bone and matrix(shape.Bone)
    if not transform then return end
    if shape.Bounds and not util.IntersectRayWithOBB(start, direction, transform:GetTranslation(), transform:GetAngles(), shape.Bounds[1], shape.Bounds[2]) then return end
    local closest, nearest
    for _, bounds in ipairs(shape.Boxes) do
        local pos = util.IntersectRayWithOBB(start, direction, transform:GetTranslation(), transform:GetAngles(), bounds[1], bounds[2])
        if pos then
            local distance = pos:DistToSqr(start)
            if not nearest or distance < nearest then closest, nearest = pos, distance end
        end
    end
    return closest, nearest
end

function A.Trace(z, start, direction, matrix)
    local closest, nearest, part, name
    for _, plate in ipairs(V.Armor) do
        local worn = Worn(z, plate)
        if worn then
            local pos, distance = Intersect(start, direction, z[shapesKey][worn], matrix)
            if pos and (not nearest or distance < nearest) then closest, nearest, part, name = pos, distance, plate.Name, worn end
        end
    end
    return closest, nearest, part, name
end

function A.BodyGroup(z, start, direction, matrix)
    local group, closest, nearest = HITGROUP_GENERIC, nil, nil
    for _, shape in ipairs(z[bodyKey]) do
        local pos, distance = Intersect(start, direction, shape, matrix)
        if pos and (not nearest or distance < nearest) then group, closest, nearest = shape.Group, pos, distance end
    end
    return group, closest, nearest
end

function A.IsWorn(z, tr)
    local plate = tr and plates[tr.ZAArmorPart]
    return plate and Worn(z, plate) == tr.ZAArmorName
end

function A.Hit(z, info, tr)
    if not A.IsWorn(z, tr) then return false end
    local plate, piece = plates[tr.ZAArmorPart], V.Pieces[tr.ZAArmorName]
    local maximum = settings.Health[plate.Name] or settings.DefaultHealth
    local remaining = math.max(0, (z[healthKey][plate.Name] or maximum) - info:GetDamage())
    z[healthKey][plate.Name] = remaining
    -- Breaking shots are completely absorbed; damage never spills through
    -- into the heart in this injury callback or reenters DT's death path.
    info:SetDamage(0)
    z:EmitSound(settings.ImpactSound, 70, 100, 0.7, CHAN_AUTO)
    if remaining > 0 then return true end
    z:SetBodygroup(plate.Bodygroup, 0)
    A.Refresh(z)
    local bone = z[gearBones][piece.Bone]
    local matrix = bone and z:GetBoneMatrix(bone)
    if matrix then
        local scale = z:GetModelScale()
        local pos, ang = LocalToWorld(Vector(unpack(piece.Offset)) * scale, Angle(unpack(piece.Angles)),
            matrix:GetTranslation(), matrix:GetAngles())
        local force = info:GetDamageForce()
        local velocity = z:GetVelocity() + force:GetNormalized() * math.Clamp(force:Length() / 20, 80, 220) + Vector(0, 0, 60)
        ZA1.Debris.Send(piece.ID, pos, ang, scale, velocity)
    end
    return true
end

return A
end

return Create
