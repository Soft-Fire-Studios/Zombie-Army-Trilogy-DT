if SERVER then AddCSLuaFile() end
local R={active=0};ZA1.Recovery=R
if CLIENT then return end
local C=ZA1.Config.Recovery
local A=ZA1.RevivalAssets
function R.HasHead(z)
    return not z.ZAHeadDestroyed and (z.ZASpecial~=nil or z:GetBodygroup(1)~=9)
end
local function Refresh(z,rag)
    if z.ZASpecial then
        rag.ZASpecial,rag.ZASpecialAssets=z.ZASpecial,z.ZASpecialAssets
        ZA1.Specials.RefreshHitboxes(rag)
    else ZA1.Equipment.Refresh(rag) end
end
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
    if state.resurrection and (not state.gettingUp or not z:Alive() or z.ZAHeadDestroyed) then
        net.Start("ZA1/ResurrectionStop");net.WriteEntity(z);net.Broadcast()
    end
    BodySolid(z,true)
    if IsValid(state.rag) then
        state.rag.ZARecoveryOwner=nil;state.rag.ZARecoveryInternalRemoval=true
        if keepCorpse then
            z:DontDeleteOnRemove(state.rag);state.rag:SetOwner(NULL)
            for group=0,z:GetNumBodyGroups()-1 do state.rag:SetBodygroup(group,z:GetBodygroup(group)) end
            Refresh(z,state.rag)
            ZA1.Gore.Ragdoll(z,state.rag);R.Remember(z,state.rag);ZA1.Manager.Ragdoll(state.rag)
            z.ZAExistingCorpse=state.rag
        else Finish(state.rag) end
    end
end
function R.Request(z,info,resurrection,limbFall,drop)
    local traversal=ZA1.Traversal
    local reserved=drop and traversal and traversal.DropSlots[z]
    local occupied=R.active+(traversal and traversal.DropCount or 0)
    if z.ZADowned or not R.HasHead(z) or z:IsPossessed() and not limbFall and not resurrection
        or z.ZAActing and not limbFall and not drop and not resurrection or z.__DT_PhysgunPickup
        or occupied>=C.MaxActiveRagdolls and not limbFall and not reserved then return false end
    local state={started=CurTime(),resurrection=resurrection,force=Vector(info:GetDamageForce()),velocity=Vector(z:GetVelocity()),
        wait=resurrection and C.ResurrectionDelay or math.Rand(C.MinDownTime,C.MaxDownTime),limbFall=limbFall,
        health=resurrection and math.max(1,math.Round(z:GetMaxHealth()*C.ResurrectionHealth)) or nil}
    z.ZADowned=state;R.active=R.active+1
    if limbFall or drop then
        state.pose={}
        for bone=0,z:GetBoneCount()-1 do
            local matrix=z:GetBoneMatrix(bone)
            if matrix then state.pose[z:GetBoneName(bone)]={pos=matrix:GetTranslation(),angles=matrix:GetAngles()} end
        end
    end
    if z.ZABreathInSound then z:StopSound(z.ZABreathInSound) end
    if z.ZABreathOutSound then z:StopSound(z.ZABreathOutSound) end
    if resurrection then z.ZAResurrections=(z.ZAResurrections or 0)+1 end
    ZA1.Navigation.Cancel(z);ZA1.Crowd.Release(z)
    state.sight=z.EnableSight;z.EnableSight=false
    ZA1.Look.Reset(z)
    z.ZAMoveGoal=nil;z.ZAAttacking=false;z.loco:SetVelocity(vector_origin)
    return true
end
function R.Drop(z,velocity,landing)
    local info=DamageInfo();info:SetDamage(0);info:SetDamageForce(vector_origin)
    if not R.Request(z,info,false,false,true) then return false end
    z.ZADowned.drop=true;z.ZADowned.velocity=Vector(velocity);z.ZADowned.landing=Vector(landing)
    return true
end
function R.Damage(z,info)
    if z.ZADowned or not R.HasHead(z) then return end
    local fatal=info:GetDamage()>=z:Health()
    local manager=ZA1.Manager
    local chance=manager.ResurrectionChance:GetFloat()/100
    if fatal and manager.ResurrectionEnabled:GetBool() and math.Rand(0,1)<chance then
        if R.Request(z,info,true) then info:SetDamage(math.max(0,z:Health()-1)) end
    elseif not fatal and info:IsExplosionDamage() and info:GetDamage()>=C.MinExplosionDamage then
        R.Request(z,info,false)
    end
end
-- Retained headed common corpses can be claimed by a Summoner. No extra
-- corpse scan or Think callback is needed; the director already keeps this list.
function R.Remember(z,rag)
    if z.ZASpecial or not R.HasHead(z) then return end
    local groups={}
    for group=0,z:GetNumBodyGroups()-1 do groups[group]=z:GetBodygroup(group) end
    rag.ZARevive={Class=z:GetClass(),Skin=z:GetSkin(),Scale=z:GetModelScale(),Groups=groups,
        Resurrections=z.ZAResurrections or 0, Helmet=ZA1.Equipment.Capture(z)}
end
function R.Reanimate(z,rag)
    local saved=IsValid(rag) and rag.ZARevive
    if not saved or not R.HasHead(rag) or saved.Groups[1]==9
        or not ZA1.Manager.ResurrectionEnabled:GetBool() then return false end
    local info=DamageInfo();info:SetDamage(0);info:SetDamageForce(vector_origin)
    if not R.Request(z,info,true) then return false end
    z.ZAResurrections=saved.Resurrections+1
    z:SetSkin(saved.Skin);z:SetModelScale(saved.Scale,0)
    for group,value in pairs(saved.Groups) do z:SetBodygroup(group,value) end
    ZA1.Dismemberment.Update(z,true)
    ZA1.Equipment.Restore(z,saved.Helmet)
    ZA1.Equipment.Refresh(z)
    local state=z.ZADowned
    state.rag=rag;state.ragStarted=CurTime();rag.ZARecoveryOwner=z;rag.ZARecoveryInternalRemoval=nil
    rag.ZARevive,rag.ZAReviveClaim=nil,nil
    -- Adopt the existing corpse, so its old expiry cannot remove the live actor.
    for index=#ZA1.Manager.Ragdolls,1,-1 do
        if ZA1.Manager.Ragdolls[index]==rag then table.remove(ZA1.Manager.Ragdolls,index) end
    end
    rag:SetOwner(z);z:DeleteOnRemove(rag)
    z:SetNoDraw(true);z:DrawShadow(false);BodySolid(z,false)
    return true
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
    Refresh(z,rag)
    ZA1.Gore.Ragdoll(z,rag)
    state.rag=rag;state.ragStarted=CurTime();rag.ZARecoveryOwner=z;z:DeleteOnRemove(rag)
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
        local saved=state.pose and bone and bone>=0 and state.pose[z:GetBoneName(bone)]
        local matrix=not saved and bone and bone>=0 and z:GetBoneMatrix(bone)
        if saved then entry.object:SetPos(saved.pos);entry.object:SetAngles(saved.angles)
        elseif matrix then entry.object:SetPos(matrix:GetTranslation());entry.object:SetAngles(matrix:GetAngles()) end
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
end
function R.Tick(z)
    local state=z.ZADowned
    if not state or not z:Alive() or state.gettingUp then return end
    if not state.rag then SpawnRagdoll(z,state);return end
    if not IsValid(state.rag) then z:Remove();return end
    if CurTime()<(state.nextCheck or 0) or state.ready then return end
    state.nextCheck=CurTime()+.2
    z:SetPos(state.rag:GetPos())
    local elapsed=CurTime()-(state.ragStarted or state.started)
    if elapsed<state.wait or z:IsAIDisabled() then return end
    local physics=state.rag:GetPhysicsObject()
    local settled=not IsValid(physics) or physics:GetVelocity():LengthSqr()<C.SettleSpeed^2
    if state.drop then
        local ground=util.TraceLine({start=state.rag:GetPos()+Vector(0,0,8),endpos=state.rag:GetPos()-Vector(0,0,z.Height),
            mask=MASK_SOLID,filter={z,state.rag}})
        -- The ordinary timeout must not get an airborne actor up in midair.
        if not ground.Hit or ground.HitNormal.z<0.65 or not settled then return end
    end
    if not settled and elapsed<C.MaxDownTimeLimit then return end
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
    local model=ZA1.TraversalAssets and ZA1.TraversalAssets.Models[z:GetModel()]
    local placement=model and model.Placement[sequence] or A.placement[sequence]
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
        state.retries=(state.retries or 0)+1;state.ready=false;state.ragStarted=CurTime()-state.wait+1
        if state.retries>=C.GroundRetries then R.Clear(z,true);z:Remove() end
        return
    end
    z:SetPos(ground);z:SetAngles(angles)
    if state.resurrection then
        -- Death impulses can move a corpse far from its creation origin.
        -- Begin the ritual only after the delay/settling and a successful
        -- pelvis-based placement, using this exact get-up location.
        local duration=0
        for _,part in ipairs(A.parts[sequence] or {sequence}) do
            local id=z:LookupSequence(part)
            if id>=0 then duration=duration+z:SequenceDuration(id) end
        end
        ZA1.ResurrectionFX.Spawn(z,ground,Vector(0,0,1),duration)
    end
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
