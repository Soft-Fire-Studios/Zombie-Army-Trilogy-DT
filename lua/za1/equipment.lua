if SERVER then AddCSLuaFile() end
local E={};ZA1.Equipment=E
local A=include("za1/equipment_assets.lua")
if CLIENT then
    -- Corpse sets use an explicit integer too; the original animation send
    -- table has a small hitbox-set field. Track only ragdolls created here.
    local corpses=setmetatable({},{__mode="k"})
    hook.Add("OnEntityCreated","ZA1/CorpseHitboxes",function(entity)
        if entity:GetClass()~="prop_ragdoll" then return end
        entity:SetNWVarProxy("ZA1HurtSet",function(rag,key,old,value) corpses[rag]=value end)
    end)
    hook.Add("Think","ZA1/CorpseHitboxes",function()
        for rag,set in pairs(corpses) do
            if IsValid(rag) then if rag:GetHitboxSet()~=set then rag:SetHitboxSet(set) end
            else corpses[rag]=nil end
        end
    end)
    return
end
local C=ZA1.Config.Equipment
local shots=setmetatable({},{__mode="k"})
local serial=0
hook.Add("EntityFireBullets","ZA1/EquipmentShot",function(entity,data)
    local attacker=data and IsValid(data.Attacker) and data.Attacker or entity
    serial=serial+1;shots[attacker]={ID=serial,Time=CurTime()}
end)

function E.Refresh(entity)
    local hat,weapon=entity:GetBodygroup(C.HeadwearBodygroup),entity:GetBodygroup(C.WeaponBodygroup)
    local mask=ZA1.Dismemberment and ZA1.Dismemberment.Mask(entity) or 0
    local set=(A.MaskIDs[mask] or 0)*A.HeadwearChoices*A.WeaponChoices+hat*A.WeaponChoices+weapon
    entity:SetHitboxSet(set)
    if entity.SetZAHurtSet then entity:SetZAHurtSet(set) else entity:SetNWInt("ZA1HurtSet",set) end
    entity.ZAEquipmentMask=mask
    entity.ZAEquipmentHat,entity.ZAEquipmentWeapon=hat,weapon
    local bounds=A.SurroundingBounds;local scale=entity:GetModelScale()
    entity.ZAEquipmentScale=scale
    entity:SetSurroundingBounds(Vector(unpack(bounds.Min))*scale,Vector(unpack(bounds.Max))*scale)
end
function E.Update(entity)
    -- Property-menu edits need a refresh too. No bone queries or traces here.
    if CurTime()<(entity.ZANextEquipmentCheck or 0) then return end
    entity.ZANextEquipmentCheck=CurTime()+1
    if entity:GetBodygroup(C.HeadwearBodygroup)~=entity.ZAEquipmentHat
        or entity:GetBodygroup(C.WeaponBodygroup)~=entity.ZAEquipmentWeapon
        or ZA1.Dismemberment.Mask(entity)~=entity.ZAEquipmentMask
        or entity:GetModelScale()~=entity.ZAEquipmentScale then E.Refresh(entity) end
end
function E.CaptureTrace(entity,tr)
    if not tr or tr.ZAEquipmentKind then return end
    local set=entity:GetHitboxSet() or 0
    local hat=math.floor(set/A.WeaponChoices)%A.HeadwearChoices;local weapon=set%A.WeaponChoices
    local body=A.BodyHitboxCounts[ZA1.Dismemberment.Mask(entity)] or A.BodyHitboxes
    local boxes=A.Headwear[hat] and A.Headwear[hat].Hitboxes or 0
    -- Overlapping anatomy can win the engine's hitbox order. A helmet in
    -- front of that head hit must still intercept the same shot.
    if tr.HitGroup==HITGROUP_HEAD and A.Headwear[hat] and A.Headwear[hat].Armor and tr.StartPos and tr.HitPos then
        local direction=tr.HitPos-tr.StartPos
        local nearest=direction:LengthSqr()
        local hit,hitbox
        for index=body,body+boxes-1 do
            local bone=entity:GetHitBoxBone(index,set);local matrix=bone and entity:GetBoneMatrix(bone)
            local lo,hi=entity:GetHitBoxBounds(index,set)
            if matrix and lo and hi then
                local pos=util.IntersectRayWithOBB(tr.StartPos,direction,matrix:GetTranslation(),matrix:GetAngles(),
                    lo*entity:GetModelScale(),hi*entity:GetModelScale())
                if pos and pos:DistToSqr(tr.StartPos)<nearest then nearest=pos:DistToSqr(tr.StartPos);hit,hitbox=pos,index end
            end
        end
        if hit then
            tr.ZABodyHitGroup,tr.ZABodyHitBox,tr.ZABodyHitPos=tr.HitGroup,tr.HitBox,tr.HitPos
            tr.HitGroup,tr.HitBox,tr.HitPos=HITGROUP_GEAR,hitbox,hit
        end
    end
    if tr.HitGroup~=HITGROUP_GEAR then return end
    local index=tr.HitBox
    if not index or index<body then return end
    if index<body+boxes then tr.ZAEquipmentKind,tr.ZAEquipmentChoice="hat",hat
    elseif A.Weapons[weapon] and index<body+boxes+A.Weapons[weapon].Hitboxes then
        tr.ZAEquipmentKind,tr.ZAEquipmentChoice="weapon",weapon
    end
end
local function Emitter(z)
    return z.ZADowned and IsValid(z.ZADowned.rag) and z.ZADowned.rag or z
end
function E.Velocity(z,info)
    local force=info and info:GetDamageForce() or vector_origin
    return z:GetVelocity()+force:GetNormalized()*math.min(force:Length()/20,180)
end
function E.Drop(z,kind,info)
    local group=kind=="hat" and C.HeadwearBodygroup or C.WeaponBodygroup
    local value=z:GetBodygroup(group)
    local piece=(kind=="hat" and A.Headwear or A.Weapons)[value]
    if not piece then return false end
    local emitter=Emitter(z);local bone=emitter:LookupBone(piece.Bone)
    local matrix=bone and emitter:GetBoneMatrix(bone)
    if matrix then ZA1.Debris.Send(piece.ID,matrix:GetTranslation(),matrix:GetAngles(),z:GetModelScale(),E.Velocity(z,info)+Vector(0,0,45)) end
    z:SetBodygroup(group,0);E.Refresh(z)
    if emitter~=z then emitter:SetBodygroup(group,0);E.Refresh(emitter) end
    return true
end
local function ContinueToBody(z,info,tr)
    if tr.ZABodyHitGroup then
        tr.HitGroup,tr.HitBox=tr.ZABodyHitGroup,tr.ZABodyHitBox
        if tr.ZABodyHitPos then tr.HitPos=tr.ZABodyHitPos;info:SetDamagePosition(tr.HitPos) end
        tr.ZAEquipmentKind,tr.ZAEquipmentChoice=nil,nil
        return false
    end
    if not tr.StartPos or not tr.Normal or not tr.HitPos then info:SetDamage(0);return true end
    -- Cloth and stale shotgun gear traces do not grant another armour block.
    -- Check anatomy after the item has been removed, within this actor only.
    local emitter=Emitter(z);local set=emitter:GetHitboxSet()
    emitter:SetHitboxSet((A.MaskIDs[ZA1.Dismemberment.Mask(emitter)] or 0)*A.HeadwearChoices*A.WeaponChoices)
    local nextHit=util.TraceLine({start=tr.StartPos,endpos=tr.HitPos+tr.Normal*128,mask=MASK_SHOT,
        filter=function(entity) return entity==emitter end})
    emitter:SetHitboxSet(set)
    if nextHit.Entity~=emitter then info:SetDamage(0);return true end
    tr.HitGroup,tr.HitBox,tr.HitPos=nextHit.HitGroup,nextHit.HitBox,nextHit.HitPos
    tr.ZAEquipmentKind,tr.ZAEquipmentChoice=nil,nil
    info:SetDamagePosition(nextHit.HitPos)
    return false
end
function E.Hit(z,info,tr)
    if not tr or tr.HitGroup~=HITGROUP_GEAR and not z.ZAHelmetShot or not info:IsBulletDamage() then return false end
    local shot=shots[info:GetAttacker()];local blocked=z.ZAHelmetShot
    if blocked and shot and shot.Time==CurTime() and blocked.Shot==shot.ID
        and (tr.HitGroup==HITGROUP_HEAD or tr.ZAEquipmentKind=="hat") then
        info:SetDamage(0);return true
    end
    if tr.HitGroup~=HITGROUP_GEAR then return false end
    if not tr.ZAEquipmentKind then E.CaptureTrace(Emitter(z),tr) end
    local kind,choice=tr.ZAEquipmentKind,tr.ZAEquipmentChoice
    if not kind then return false end
    local group=kind=="hat" and C.HeadwearBodygroup or C.WeaponBodygroup
    if z:GetBodygroup(group)~=choice then return ContinueToBody(z,info,tr) end
    local piece=(kind=="hat" and A.Headwear or A.Weapons)[choice]
    if not piece or not E.Drop(z,kind,info) then return false end
    if kind=="hat" and piece.Armor then
        if shot and shot.Time==CurTime() then z.ZAHelmetShot={Shot=shot.ID} end
        z:EmitSound("physics/metal/metal_solid_impact_bullet2.wav",75,math.random(95,105),0.8)
        info:SetDamage(0);return true
    elseif kind=="weapon" then
        info:SetDamage(0);return true
    end
    return ContinueToBody(z,info,tr)
end
hook.Add("EntityTakeDamage","ZA1/CorpseEquipment",function(entity,info)
    if not entity.ZA1Corpse or IsValid(entity.ZARecoveryOwner) or not info:IsBulletDamage() or info:GetDamage()<=0 then return end
    local tr=ZA1.Recovery.HitTrace(entity,info:GetDamagePosition())
    if E.Hit(entity,info,tr) then return end
    if tr.HitGroup==HITGROUP_HEAD and not entity.ZAHeadDestroyed then
        ZA1.Gore.HeadHit(entity,info,true);ZA1.Gore.Ragdoll(entity,entity)
    end
end)
