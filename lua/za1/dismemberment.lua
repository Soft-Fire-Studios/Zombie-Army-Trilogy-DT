if SERVER then AddCSLuaFile() end
local D={};ZA1.Dismemberment=D
local A=include("za1/dismemberment_assets.lua")
local waistTorso = 1
local function Gone(z,group) return z:GetBodygroup(group)>0 end
function D.IsWaist(z) return not z.ZASpecial and z:GetBodygroup(0)==waistTorso end
function D.Mask(z)
    local mask=0
    if Gone(z,2) then mask=mask+1 end
    if Gone(z,3) then mask=mask+2 end
    if Gone(z,6) then mask=mask+4 end
    if Gone(z,7) then mask=mask+8 end
    if z:GetBodygroup(0)==waistTorso then mask=bit.bor(mask,28) end
    if z:GetBodygroup(1)==A.HeadDestroyed then mask=mask+32 end
    return mask
end
if CLIENT then return end
local function Pick(pool) return pool[math.random(#pool)] end
local turns={Left={[90]={"undead_grunt_crawl_turn_left_90"},[180]={"undead_grunt_crawl_turn_left_180"}},
             Right={[90]={"undead_grunt_crawl_turn_right_90"},[180]={"undead_grunt_crawl_turn_right_180"}}}
function D.Update(z,force)
    if z.ZASpecial then return end
    if not force and CurTime()<(z.ZANextSeverCheck or 0) then return end
    z.ZANextSeverCheck=CurTime()+1
    -- Torso 2 is another cut upper-body mesh, not a flesh-wound variant.
    -- Repair actors restored from older builds without hiding attached legs.
    if z:GetBodygroup(0)==2 then z:SetBodygroup(0,0) end
    local mask=D.Mask(z)
    if mask==z.ZASeverMask then return end
    z.ZASeverMask=mask
    local left,right=bit.band(mask,1)~=0,bit.band(mask,2)~=0
    local crawling=bit.band(mask,28)~=0
    local wasCrawling=z.ZACrawling
    z.ZABaseIdle=z.ZABaseIdle or z.IdleAnimation
    z.ZABaseWalk=z.ZABaseWalk or z.WalkAnimation
    if right and z:GetBodygroup(ZA1.Config.Equipment.WeaponBodygroup)~=0 then ZA1.Equipment.Drop(z,"weapon") end
    if right then ZA1.Ranged.Stop(z) end
    if crawling and not wasCrawling then z.ZABaseIdle,z.ZABaseWalk=z.IdleAnimation,z.WalkAnimation end
    z.ZACrawling=crawling
    if crawling then
        z.IdleAnimation="undead_grunt_crawl_idle"
        z.WalkAnimation=left and "undead_grunt_crawl_fwd_rightarm_a" or right and "undead_grunt_crawl_fwd_leftarm_a" or "undead_grunt_crawl_fwd_a"
        z.MeleeAnimations=left and right and {"undead_grunt_melee_na_bite_lunge_a"}
            or left and {"undead_grunt_melee_crawl_ra_swipe_a","undead_grunt_melee_crawl_ra_lunge_a"}
            or right and {"undead_grunt_melee_crawl_la_double_swipe_a"} or {"undead_grunt_melee_crawl_ba_double_swipe_a"}
        z.ZATurnAnimations=turns;z.ZALungeClips={}
    else
        if wasCrawling then z.IdleAnimation,z.WalkAnimation=z.ZABaseIdle,z.ZABaseWalk end
        z.MeleeAnimations=left and right and {"undead_grunt_melee_na_bite_lunge_a"}
            or right and A.LeftAttacks or left and A.RightAttacks or ZA1.Config.Animations.Melee
        z.ZATurnAnimations=nil;z.ZALungeClips=(left or right) and {} or nil
    end
    z.RunAnimation=z.WalkAnimation;z.FallAnimation=z.IdleAnimation
    z.Height=crawling and 36 or 74
    z:SetCollisionBounds(Vector(-z.Width,-z.Width,0),Vector(z.Width,z.Width,z.Height))
    z.ZANavProfile=ZA1.Navigation.Profile(z)
    ZA1.Navigation.Cancel(z)
    if not z.ZAActing and not z.ZADowned and z:Alive() then z:ResetAnimState() end
end
local function Send(z,piece,info)
    local emitter=z.ZADowned and IsValid(z.ZADowned.rag) and z.ZADowned.rag or z
    local bone=emitter:LookupBone(piece.Bone);local matrix=bone and emitter:GetBoneMatrix(bone)
    if not matrix then return end
    ZA1.Debris.Send(piece.ID,matrix:GetTranslation(),matrix:GetAngles(),z:GetModelScale(),ZA1.Equipment.Velocity(z,info)+Vector(0,0,60))
    ParticleEffect("blood_impact_red_01",matrix:GetTranslation(),matrix:GetAngles())
end
local function SyncDowned(z)
    if not z.ZADowned or not IsValid(z.ZADowned.rag) then return end
    if D.IsWaist(z) and ZA1.Halves then ZA1.Halves.ReplaceDowned(z) end
    local rag=z.ZADowned.rag
    for group=0,z:GetNumBodyGroups()-1 do rag:SetBodygroup(group,z:GetBodygroup(group)) end
    ZA1.Equipment.Refresh(rag);D.Ragdoll(z,rag)
end
function D.Sever(z,group,info)
    if z.ZASpecial then return false end
    local part=A.Parts[group]
    if not part or Gone(z,part.Group) then return false end
    if group==HITGROUP_RIGHTARM then ZA1.Equipment.Drop(z,"weapon",info) end
    Send(z,part,info);z:SetBodygroup(part.Group,1)
    for _,g in ipairs(part.ArmorGroups or {}) do z:SetBodygroup(g,0) end
    if (group==HITGROUP_LEFTLEG or group==HITGROUP_RIGHTLEG) and not z.ZACrawling and z:Alive()
        and info and info:GetDamage()<z:Health() and ZA1.Recovery then
        ZA1.Recovery.Request(z,info,false,true)
    end
    D.Update(z,true);ZA1.Equipment.Refresh(z)
    SyncDowned(z)
    if info and info:IsExplosionDamage() then ZA1.Feedback.FullGib(z) end
    return true
end
function D.Waist(z,info)
    if z.ZASpecial or z:GetBodygroup(0)==waistTorso then return false end
    if ZA1.Halves then ZA1.Halves.Create(z,"lower",info,z.ZADowned and z.ZADowned.rag) end
    if not ZA1.Halves then Send(z,A.Waist,info) end
    z:SetBodygroup(0,waistTorso);z:SetBodygroup(8,1)
    z:SetBodygroup(6,2);z:SetBodygroup(7,2)
    for _,g in ipairs(A.LowerArmor) do z:SetBodygroup(g,0) end
    D.Update(z,true);ZA1.Equipment.Refresh(z)
    SyncDowned(z)
    return true
end
function D.Damage(z,info,tr)
    if z.ZASpecial or info:GetDamage()<=0 then return end
    local group=tr and tr.HitGroup
    if info:IsExplosionDamage() and info:GetDamage()>=ZA1.Config.Sever.ExplosionDamage then
        D.Waist(z,info)
        if math.Rand(0,1)<.5 then D.Sever(z,HITGROUP_LEFTARM,info) else D.Sever(z,HITGROUP_RIGHTARM,info) end
    elseif group and A.Parts[group] and (info:IsBulletDamage() or info:IsDamageType(DMG_SLASH)) then
        local damage=z.ZALimbDamage or {};z.ZALimbDamage=damage
        damage[group]=(damage[group] or 0)+info:GetDamage()
        if damage[group]>=ZA1.Config.Sever.LimbDamage then D.Sever(z,group,info) end
    end
end
function D.Ragdoll(z,rag)
    if z.ZASpecial then return end
    for group,part in pairs(A.Parts) do
        local absent = rag.ZAHalf=="upper" and (group==HITGROUP_LEFTLEG or group==HITGROUP_RIGHTLEG)
            or rag.ZAHalf=="lower" and (group==HITGROUP_LEFTARM or group==HITGROUP_RIGHTARM)
        if not absent and Gone(z,part.Group) then
            for _,name in ipairs(part.PhysicsBones) do
                local bone=rag:LookupBone(name);local id=bone and rag:TranslateBoneToPhysBone(bone)
                local object=id and id>=0 and rag:GetPhysicsObjectNum(id)
                if IsValid(object) then
                    object:EnableCollisions(true)
                    -- Hidden constrained joints must still collide with the
                    -- world, but need not collide with their own ragdoll.
                    if rag:TranslatePhysBoneToBone(id)==bone then object:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS) end
                end
            end
        end
    end
    if not rag.ZAHalf and z:GetBodygroup(0)==waistTorso then
        local bone=rag:LookupBone("Bip01 Pelvis");local id=bone and rag:TranslateBoneToPhysBone(bone)
        local object=id and id>=0 and rag:GetPhysicsObjectNum(id)
        if IsValid(object) then object:EnableCollisions(true) end
    end
end
