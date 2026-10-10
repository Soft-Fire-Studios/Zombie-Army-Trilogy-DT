if SERVER then AddCSLuaFile(); AddCSLuaFile("za1/half_assets.lua") end
local H = {}; ZA1.Halves = H
local models = include("za1/half_assets.lua")
function H.Model(z, half)
    local family = models[z.ZASpecial or "common"]
    return family and family[half]
end
if CLIENT then return end

-- Called on a waist sever or death, never from Think. Both halves share the
-- normal corpse cap/lifetime; neither carries the other half's invisible mass.
function H.Create(z, half, info, source, headless, recovering, upwardSpeed)
    local model = H.Model(z, half)
    local manager = ZA1.Manager
    if not model or not recovering and manager.RagdollCap:GetInt() <= 0 then return end
    source = IsValid(source) and source or z
    local rag = ents.Create("prop_ragdoll")
    if not IsValid(rag) then return end
    rag.ZAHalf = half
    rag:SetModel(model); rag:SetPos(source:GetPos()); rag:SetAngles(source:GetAngles())
    rag:SetSkin(z:GetSkin()); rag:SetColor(z:GetColor()); rag:SetModelScale(z:GetModelScale(), 0)
    rag:SetBloodColor(z:GetBloodColor()); rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    for group = 0, z:GetNumBodyGroups()-1 do rag:SetBodygroup(group, z:GetBodygroup(group)) end
    if not z.ZASpecial then
        rag:SetBodygroup(0, 1)
        if half == "upper" then rag:SetBodygroup(6, 2); rag:SetBodygroup(7, 2); rag:SetBodygroup(8, 1) end
        if headless then rag:SetBodygroup(1, 9); rag:SetBodygroup(4, 0) end
    elseif headless then rag:SetBodygroup(1, 1); rag:SetBodygroup(3, 1) end
    rag:Spawn(); rag:Activate()
    local objects, mass = {}, 0
    for index = 0, rag:GetPhysicsObjectCount()-1 do
        local object = rag:GetPhysicsObjectNum(index)
        if IsValid(object) then
            object:EnableMotion(false)
            objects[#objects+1] = {object = object, index = index}; mass = mass + object:GetMass()
        end
    end
    for _, entry in ipairs(objects) do
        -- The smaller rigs have different indices: map the joint by name.
        local bone = rag:TranslatePhysBoneToBone(entry.index)
        local sourceBone = bone >= 0 and source:LookupBone(rag:GetBoneName(bone))
        local matrix = sourceBone and source:GetBoneMatrix(sourceBone)
        if matrix then entry.object:SetPos(matrix:GetTranslation()); entry.object:SetAngles(matrix:GetAngles()) end
    end
    if half == "upper" then
        if z.ZAHeadLayout then rag.ZAHeadLayout = z.ZAHeadLayout else ZA1.Equipment.Refresh(rag) end
        ZA1.Gore.Ragdoll(z, rag)
        if headless then rag.ZAHeadDestroyed=true end
    else ZA1.Dismemberment.Ragdoll(z, rag) end
    local impulse = info and info:GetDamageForce() or vector_origin
    local limit = mass * ZA1.Config.Recovery.MaxKnockdownSpeed
    if impulse:LengthSqr() > limit*limit then impulse = impulse:GetNormalized()*limit end
    local velocity = source:GetVelocity() + Vector(0, 0, upwardSpeed or 0)
    for _, entry in ipairs(objects) do
        local object = entry.object
        object:EnableMotion(true); object:SetVelocity(velocity)
        if mass > 0 then object:ApplyForceCenter(impulse*(object:GetMass()/mass)) end
        object:Wake()
    end
    if info and info:IsDamageType(DMG_BURN) then rag:Ignite(10) end
    if info and info:IsDamageType(DMG_DISSOLVE) then rag:Dissolve() end
    if not recovering then manager.Ragdoll(rag) end
    return rag
end

function H.ReplaceDowned(z)
    local state = z.ZADowned
    if not state or not IsValid(state.rag) or state.rag.ZAHalf=="upper" then return end
    local previous = state.rag
    local rag = H.Create(z, "upper", nil, previous, nil, true)
    if not IsValid(rag) then return end
    state.rag = rag; rag.ZARecoveryOwner = z; rag:SetOwner(z); z:DeleteOnRemove(rag)
    previous.ZARecoveryInternalRemoval = true; previous.ZARecoveryOwner = nil
    z:DontDeleteOnRemove(previous); previous:Remove()
    return rag
end

function H.Pair(z, info)
    local settings = z.ZASpecialSettings or ZA1.SpecialConfig[z.ZASpecial]
    return H.Create(z, "upper", info, nil, true, nil, settings and settings.UpperLaunchSpeed), H.Create(z, "lower", info)
end

function H.Corpse(z, info)
    if not ZA1.Dismemberment.IsWaist(z) then return false end
    if info and info:IsDamageType(DMG_REMOVENORAGDOLL) then z:Remove(); return true end
    local rag = H.Create(z, "upper", info)
    if IsValid(rag) then cleanup.ReplaceEntity(z, rag); undo.ReplaceEntity(z, rag) end
    z:Remove()
    return true
end
