if SERVER then AddCSLuaFile() end
local R={active=0};ZA1.Recovery=R
if CLIENT then return end
local C=ZA1.Config.Recovery
local A=ZA1.RevivalAssets
local function BodySolid(z,enabled)
    z:SetNotSolid(not enabled)
    local physics=z:GetPhysicsObject()
    if IsValid(physics) then physics:EnableCollisions(enabled) end
end
local function Finish(rag)
    if not IsValid(rag) then return end
    rag.ZARecoveryInternalRemoval=true;rag.ZARecoveryOwner=nil;rag:Remove()
end
function R.Clear(z,keepCorpse)
    local state=z.ZADowned
    if not state then return end
    z.ZADowned=nil;R.active=math.max(0,R.active-1)
    if state.resurrection then
        net.Start("ZA1/ResurrectionStop");net.WriteEntity(z);net.Broadcast()
    end
    BodySolid(z,true)
    if IsValid(state.rag) then
        state.rag.ZARecoveryOwner=nil;state.rag.ZARecoveryInternalRemoval=true
        if keepCorpse then
            z:DontDeleteOnRemove(state.rag);state.rag:SetOwner(NULL)
            for group=0,z:GetNumBodyGroups()-1 do state.rag:SetBodygroup(group,z:GetBodygroup(group)) end
            ZA1.Equipment.Refresh(state.rag)
            ZA1.Gore.Ragdoll(z,state.rag);ZA1.Manager.Ragdoll(state.rag)
            z.ZAExistingCorpse=state.rag
        else Finish(state.rag) end
    end
end
function R.Request(z,info,resurrection)
    if z.ZADowned or z.ZAHeadDestroyed or z:IsPossessed() or z.ZAActing or z.__DT_PhysgunPickup
        or R.active>=C.MaxActiveRagdolls then return false end
    local state={started=CurTime(),resurrection=resurrection,force=Vector(info:GetDamageForce()),velocity=Vector(z:GetVelocity()),
        wait=resurrection and C.ResurrectionDelay or math.Rand(C.MinDownTime,C.MaxDownTime),
        health=resurrection and math.max(1,math.Round(z:GetMaxHealth()*C.ResurrectionHealth)) or nil}
    z.ZADowned=state;R.active=R.active+1
    if z.ZABreathInSound then z:StopSound(z.ZABreathInSound) end
    if z.ZABreathOutSound then z:StopSound(z.ZABreathOutSound) end
    if resurrection then z.ZAResurrections=(z.ZAResurrections or 0)+1 end
    ZA1.Navigation.Cancel(z);ZA1.Crowd.Release(z)
    state.sight=z.EnableSight;z.EnableSight=false
    ZA1.Look.Reset(z)
    z.ZAMoveGoal=nil;z.ZAAttacking=false;z.loco:SetVelocity(vector_origin)
    return true
end
function R.Damage(z,info)
    if z.ZADowned or z.ZAHeadDestroyed then return end
    local fatal=info:GetDamage()>=z:Health()
    if fatal and (z.ZAResurrections or 0)<C.MaxResurrections and math.Rand(0,1)<C.ResurrectionChance then
        if R.Request(z,info,true) then info:SetDamage(math.max(0,z:Health()-1)) end
    elseif not fatal and info:IsExplosionDamage() and info:GetDamage()>=C.MinExplosionDamage then
        R.Request(z,info,false)
    end
end
local function SpawnRagdoll(z,state)
    local rag=ents.Create("prop_ragdoll")
    if not IsValid(rag) then R.Clear(z);z.EnableSight=state.sight;return end
    local upper = ZA1.Halves and ZA1.Dismemberment.IsWaist(z)
    rag.ZAHalf=upper and "upper" or nil
    rag:SetModel(upper and ZA1.Halves.Model(z,"upper") or z:GetModel());rag:SetPos(z:GetPos());rag:SetAngles(z:GetAngles())
    rag:SetSkin(z:GetSkin());rag:SetModelScale(z:GetModelScale(),0)
    for group=0,z:GetNumBodyGroups()-1 do rag:SetBodygroup(group,z:GetBodygroup(group)) end
    rag:SetOwner(z);rag:Spawn();rag:Activate();rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    ZA1.Equipment.Refresh(rag)
    ZA1.Gore.Ragdoll(z,rag)
    state.rag=rag;rag.ZARecoveryOwner=z;z:DeleteOnRemove(rag)
    local objects,totalMass={},0
    -- Place every joint before releasing the ragdoll to the physics solver.
    for index=0,rag:GetPhysicsObjectCount()-1 do
        local object=rag:GetPhysicsObjectNum(index)
        if IsValid(object) then
            object:EnableMotion(false)
            objects[#objects+1]={object=object,index=index}
            totalMass=totalMass+object:GetMass()
        end
    end
    for _,entry in ipairs(objects) do
        local bone=rag:TranslatePhysBoneToBone(entry.index)
        if upper and bone>=0 then bone=z:LookupBone(rag:GetBoneName(bone)) end
        local matrix=bone and bone>=0 and z:GetBoneMatrix(bone)
        if matrix then entry.object:SetPos(matrix:GetTranslation());entry.object:SetAngles(matrix:GetAngles()) end
    end
    -- Share the impulse by mass rather than launching a light hand/head while
    -- the rest of its constrained body starts at rest.
    local impulse=state.force
    local limit=totalMass*C.MaxKnockdownSpeed
    if impulse:LengthSqr()>limit*limit then impulse=impulse:GetNormalized()*limit end
    for _,entry in ipairs(objects) do
        local object=entry.object
        object:EnableMotion(true)
        object:SetVelocity(state.velocity)
        if totalMass>0 then object:ApplyForceCenter(impulse*(object:GetMass()/totalMass)) end
        object:Wake()
    end
    z:SetNoDraw(true);z:DrawShadow(false)
    BodySolid(z,false)
    if state.resurrection then
        local ground=util.TraceLine({start=rag:GetPos()+Vector(0,0,24),endpos=rag:GetPos()-Vector(0,0,96),filter={z,rag},mask=MASK_SOLID_BRUSHONLY})
        if ground.Hit then
            net.Start("ZA1/Resurrection");net.WriteEntity(z);net.WriteVector(ground.HitPos+ground.HitNormal*.4);net.WriteVector(ground.HitNormal);net.WriteFloat(state.wait+C.MaxDownTimeLimit);net.Broadcast()
        end
    end
end
function R.Tick(z)
    local state=z.ZADowned
    if not state or not z:Alive() or state.gettingUp then return end
    if not state.rag then SpawnRagdoll(z,state);return end
    if not IsValid(state.rag) then z:Remove();return end
    if CurTime()<(state.nextCheck or 0) or state.ready then return end
    state.nextCheck=CurTime()+.2
    z:SetPos(state.rag:GetPos())
    if CurTime()-state.started<state.wait or z:IsAIDisabled() then return end
    local physics=state.rag:GetPhysicsObject()
    local settled=not IsValid(physics) or physics:GetVelocity():LengthSqr()<C.SettleSpeed^2
    if not settled and CurTime()-state.started<C.MaxDownTimeLimit then return end
    state.ready=true
end
function R.GetUp(z)
    local state=z.ZADowned
    if not state or not state.ready or not IsValid(state.rag) then return end
    local rag=state.rag
    local bone=rag:LookupBone("Bip01 Pelvis");local matrix=bone and rag:GetBoneMatrix(bone)
    if not matrix then z:Remove();return end
    local localFacing=A.pelvisForward or {0,0,1}
    local facing=matrix*Vector(unpack(localFacing))-matrix:GetTranslation()
    local side=facing.z>0 and "back" or "front"
    local pool=z.ZACrawling and A.crawl[side] or (state.resurrection and A.revive or A.getup)[side]
    local sequence=pool[math.random(#pool)]
    local placement=A.placement[sequence]
    local _,rotation=LocalToWorld(vector_origin,Angle(unpack(placement.angles)),vector_origin,angle_zero)
    -- Match the authored first-frame pelvis to the physical pelvis, then
    -- keep only world yaw: locomotion must remain upright on the navmesh.
    local pose=Matrix();pose:SetAngles(rotation)
    local relative=matrix*pose:GetInverse()
    local angles=Angle(0,relative:GetAngles().y,0)
    local offset=Vector(unpack(placement.pelvis));offset:Rotate(angles)
    local start=matrix:GetTranslation()-offset
    local ground=ZA1.Population.ClearGround(start,{z,rag})
    if not ground then
        state.retries=(state.retries or 0)+1;state.ready=false;state.started=CurTime()-state.wait+1
        if state.retries>=C.GroundRetries then R.Clear(z,true);z:Remove() end
        return
    end
    z:SetPos(ground);z:SetAngles(angles)
    z:SetNoDraw(false);z:DrawShadow(true)
    BodySolid(z,true)
    Finish(rag);state.rag=nil;state.gettingUp=true
    if state.resurrection then
        z:SetHealth(state.health)
        local voice=A.resurrectionVoice
        if voice and #voice.files>0 then z:EmitSound(voice.files[math.random(#voice.files)],75,100,math.Rand(voice.volume[1],voice.volume[2])*z.VocalVolume,CHAN_VOICE) end
    end
    for _,part in ipairs(A.parts[sequence] or {sequence}) do
        if not IsValid(z) or not z:Alive() then return end
        z:ZAPlayOnce(part)
    end
    if not IsValid(z) or not z:Alive() then return end
    local sight=state.sight;R.Clear(z);z.EnableSight=sight
    ZA1.Manager.Wake(z)
end
util.AddNetworkString("ZA1/Resurrection")
util.AddNetworkString("ZA1/ResurrectionStop")
-- Ragdoll damage has no NextBot trace callback. Read the struck model's
-- authored hitboxes at the damage point, only when the ragdoll is actually hit.
-- Standing zombies receive the engine's HitGroup through DT OnTraceAttack.
function R.HitTrace(rag,position)
    local nearest,distance={HitGroup=HITGROUP_GENERIC,HitPos=position},math.huge
    local bodyDistance,bodyGroup,bodyIndex=math.huge,HITGROUP_GENERIC,0
    local set=rag:GetHitboxSet() or 0
    for index=0,(rag:GetHitBoxCount(set) or 0)-1 do
        local bone=rag:GetHitBoxBone(index,set)
        local matrix=bone and rag:GetBoneMatrix(bone)
        local lo,hi=rag:GetHitBoxBounds(index,set)
        local inverse=matrix and matrix:GetInverse()
        if inverse and lo and hi then
            local p=inverse*position
            local dx=math.max(lo.x-p.x,0,p.x-hi.x)
            local dy=math.max(lo.y-p.y,0,p.y-hi.y)
            local dz=math.max(lo.z-p.z,0,p.z-hi.z)
            local squared=dx*dx+dy*dy+dz*dz
            local group=rag:GetHitBoxHitGroup(index,set)
            if group~=HITGROUP_GEAR and squared<bodyDistance then
                bodyDistance,bodyGroup,bodyIndex=squared,group,index
            end
            if squared<distance or group==HITGROUP_GEAR and squared==distance then
                distance=squared;nearest.HitGroup=group;nearest.HitBox=index
            end
        end
    end
    nearest.ZABodyHitGroup,nearest.ZABodyHitBox=bodyGroup,bodyIndex
    ZA1.Equipment.CaptureTrace(rag,nearest)
    return nearest
end
function R.HitGroup(rag,position) return R.HitTrace(rag,position).HitGroup end
hook.Add("EntityTakeDamage","ZA1/DownedDamage",function(entity,info)
    local owner=entity.ZARecoveryOwner
    if not IsValid(owner) or not owner.ZADowned then return end
    -- Radius damage also visits the owning NextBot; direct hits are routed once.
    -- A living downed zombie remains shootable. Contact with the floor/walls
    -- produces crush damage on prop_ragdoll, which must not kill its owner.
    if not info:IsExplosionDamage() and not info:IsDamageType(DMG_CRUSH) then
        local previous=owner.ZADownedHitTrace
        owner.ZADownedHitTrace=R.HitTrace(entity,info:GetDamagePosition())
        local ok,err=pcall(owner.TakeDamageInfo,owner,info)
        if IsValid(owner) then owner.ZADownedHitTrace=previous end
        if not ok then error(err,0) end
    end
    return true
end)
hook.Add("EntityRemoved","ZA1/DownedRemoval",function(entity)
    if entity.ZARecoveryInternalRemoval then return end
    local owner=entity.ZARecoveryOwner
    if IsValid(owner) and owner.ZADowned then owner:Remove() end
end)
