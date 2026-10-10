if SERVER then AddCSLuaFile() end
local F={};ZA1.Gore=F
game.AddParticles("particles/za1_headshot.pcf")
PrecacheParticleSystem("za1_headshot_spurt")
PrecacheParticleSystem("blood_impact_red_01")
if CLIENT then return end
local C=ZA1.Config.Gore
local A=include("za1/gore_assets.lua")
local function Impact(entity,binding,scale,level)
    if not binding or #binding.files==0 then return end
    entity:EmitSound(binding.files[math.random(#binding.files)],level or 75,
        math.Round(math.Rand(binding.pitch[1],binding.pitch[2])*100),
        math.Rand(binding.volume[1],binding.volume[2])*scale,CHAN_AUTO)
end
function F.Position(entity)
    local socket=entity:LookupAttachment("za1_headshot")
    local attach=socket and socket>0 and entity:GetAttachment(socket)
    if attach then return attach.Pos,attach.Ang,socket end
    local bone=entity:LookupBone("Bip01 Head")
    local matrix=bone and entity:GetBoneMatrix(bone)
    return matrix and matrix:GetTranslation() or entity:WorldSpaceCenter(),Angle(0,0,0),nil
end
function F.HeadHit(z,info,fatal)
    if z.ZAHeadDestroyed then return end
    if fatal then
        local layout=z.ZAHeadLayout
        if layout then
            if z:GetBodygroup(layout.HatGroup)~=layout.HatHidden then
                local hat=layout.Hat;local bone=z:LookupBone(hat.Bone);local matrix=bone and z:GetBoneMatrix(bone)
                if matrix then
                    local pos,ang=LocalToWorld(Vector(unpack(hat.Offset))*z:GetModelScale(),Angle(unpack(hat.Angles)),matrix:GetTranslation(),matrix:GetAngles())
                    ZA1.Debris.Send(hat.ID,pos,ang,z:GetModelScale(),ZA1.Equipment.Velocity(z,info)+Vector(0,0,45))
                end
            end
        else ZA1.Equipment.Drop(z,"hat",info) end
        local emitter=z.ZADowned and IsValid(z.ZADowned.rag) and z.ZADowned.rag or z
        local pos=F.Position(emitter)
        ZA1.Debris.Send(0,pos,emitter:GetAngles(),z:GetModelScale(),ZA1.Equipment.Velocity(z,info))
        z.ZAHeadDestroyed=true
        if layout then z:SetBodygroup(layout.Group,layout.Destroyed);z:SetBodygroup(layout.HatGroup,layout.HatHidden)
        else z:SetBodygroup(1,9);z:SetBodygroup(4,0);ZA1.Equipment.Refresh(z) end
    elseif CurTime()<(z.ZANextHeadImpact or 0) then return end
    z.ZANextHeadImpact=CurTime()+C.HitCooldown
    local emitter=z.ZADowned and IsValid(z.ZADowned.rag) and z.ZADowned.rag or z
    Impact(emitter,A.headCrunch,C.CrunchVolume,75)
    if fatal then
        Impact(emitter,A.bloodSplat,C.SplatVolume,75)
        local pos,ang=F.Position(emitter)
        for i=1,C.Bursts do ParticleEffect("blood_impact_red_01",pos,ang) end
        if emitter~=z then
            local layout=z.ZAHeadLayout
            if layout then
                emitter.ZAHeadLayout=layout;emitter:SetBodygroup(layout.Group,layout.Destroyed);emitter:SetBodygroup(layout.HatGroup,layout.HatHidden)
            else emitter:SetBodygroup(1,9);emitter:SetBodygroup(4,0);ZA1.Equipment.Refresh(emitter) end
            F.Ragdoll(z,emitter)
        end
    end
end
function F.Ragdoll(z,rag)
    if ZA1.Dismemberment then ZA1.Dismemberment.Ragdoll(z,rag) end
    rag.ZA1Corpse=true;rag.ZAHeadDestroyed=z.ZAHeadDestroyed
    if not z.ZAHeadDestroyed or rag.ZAHeadSpurt then return end
    rag.ZAHeadSpurt=true
    if rag.TranslateBoneToPhysBone then
        local bone=rag:LookupBone("Bip01 Head")
        local phys=bone and rag:TranslateBoneToPhysBone(bone)
        local object=phys and phys>=0 and rag:GetPhysicsObjectNum(phys)
        if IsValid(object) then object:EnableCollisions(false) end
    end
    local _,_,socket=F.Position(rag)
    if socket then ParticleEffectAttach("za1_headshot_spurt",PATTACH_POINT_FOLLOW,rag,socket) end
end
