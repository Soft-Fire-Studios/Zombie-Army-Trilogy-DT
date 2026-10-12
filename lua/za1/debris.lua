if SERVER then AddCSLuaFile() end
local D={};ZA1.Debris=D
local A=include("za1/equipment_assets.lua")
local B=include("za1/special_assets.lua")
for id,model in pairs(B.Models) do A.Models[id]=model end
local skeleton=ZA1.SkeletonAssets or include("za1/skeleton_assets.lua")
local heavy=ZA1.HeavyAssets or include("za1/heavy_assets.lua")
local skins=ZA1.SkinAssets or include("za1/skin_assets.lua")
local defaults={}
for id,model in pairs(skeleton.Models) do A.Models[id]=model end
for id,model in pairs(heavy.Models) do A.Models[id]=model end
for id,model in pairs(ZA1.MajorAssets and ZA1.MajorAssets.Models or {}) do A.Models[id]=model end
for id,model in pairs(A.Models) do
    local variant=skins[model]
    if variant then A.Models[id],defaults[id]=variant.Model,variant.Skin end
end
if SERVER then
    util.AddNetworkString("ZA1/Debris")
    util.AddNetworkString("ZA1/Breakup")
    function D.Send(id,pos,angles,scale,velocity,skin,body)
        net.Start("ZA1/Debris")
        net.WriteUInt(id,8);net.WriteVector(pos);net.WriteAngle(angles)
        net.WriteFloat(scale);net.WriteVector(velocity)
        net.WriteUInt(skin or defaults[id] or 0,8);net.WriteUInt(body or 0,8)
        net.SendPVS(pos)
    end
    function D.Breakup(pieces,pos,scale)
        if #pieces==0 then return end
        -- Armored skeletons have more than fifteen pieces. Send complete small
        -- batches; client distance, lifetime and prop limits still bound them.
        for first=1,#pieces,15 do
            local last=math.min(first+14,#pieces)
            net.Start("ZA1/Breakup");net.WriteUInt(last-first+1,4);net.WriteFloat(scale)
            for index=first,last do
                local piece=pieces[index]
                net.WriteUInt(piece.ID,8);net.WriteVector(piece.Pos);net.WriteAngle(piece.Ang);net.WriteVector(piece.Velocity)
                net.WriteUInt(piece.Skin or defaults[piece.ID] or 0,8);net.WriteUInt(piece.Body or 0,8)
            end
            net.SendPVS(pos)
        end
    end
    return
end

local enabled=CreateClientConVar("za1_debris","1",true,false,"Head, limb and equipment debris")
local cap=CreateClientConVar("za1_debris_cap","48",true,false,"Maximum local debris props",0,96)
local lifetime=CreateClientConVar("za1_debris_lifetime","20",true,false,"Equipment debris lifetime",2,60)
local distance=CreateClientConVar("za1_debris_distance","1800",true,false,"Maximum debris spawn distance",128,4096)
local props={}
local doors={}
D.Stats={relocated=0,blocked=0}
local function ClearBirth(entity,physics,pos,velocity)
    -- Detached parts can be born inside the floor or a nearby wall. Waking a
    -- light collider there lets penetration correction impart extreme torque.
    -- WorldSpaceAABB includes the model's actual rotation and scale (TraceEntity
    -- traces an unrotated model). Normal clear spawns need just one hull check.
    physics:EnableMotion(false)
    -- Client prop physics can still hold its creation pose after the render
    -- entity moves. Align the collider while frozen, before testing clearance.
    physics:SetPos(pos, true)
    physics:SetAngles(entity:GetAngles())
    local lo,hi=entity:WorldSpaceAABB()
    local mins,maxs=lo-pos,hi-pos
    local trace={start=pos,endpos=pos,mins=mins,maxs=maxs,filter=entity,
        mask=MASK_SOLID,collisiongroup=COLLISION_GROUP_DEBRIS}
    local function Clear(point)
        trace.start,trace.endpos=point,point
        local tr=util.TraceHull(trace)
        return not tr.StartSolid and not tr.AllSolid and not tr.Hit
    end
    if not Clear(pos) then
        local step=math.max(4,math.min(48,(maxs-mins):Length()*.5))
        local forward=velocity:GetNormalized()
        local offsets={forward*step,Vector(0,0,step),forward*step*2,
            Vector(0,0,step*2),Vector(-forward.y,forward.x,0)*step,
            Vector(forward.y,-forward.x,0)*step}
        local free
        for _,offset in ipairs(offsets) do
            local point=pos+offset
            if Clear(point) then free=point;break end
        end
        if not free then
            D.Stats.blocked=D.Stats.blocked+1
            entity:Remove();return false
        end
        entity:SetPos(free);physics:SetPos(free, true)
        D.Stats.relocated=D.Stats.relocated+1
    end
    physics:EnableMotion(true)
    return true
end
function D.Door(model,pos,angles,skin,groups,velocity,mins,maxs)
    local config=ZA1.Config.Doors
    if not enabled:GetBool() or cap:GetInt()<=0 then return end
    local viewer=LocalPlayer()
    if not IsValid(viewer) or viewer:EyePos():DistToSqr(pos)>distance:GetFloat()^2 then return end
    for i=#doors,1,-1 do
        if not IsValid(doors[i].entity) or CurTime()>=doors[i].expires then
            if IsValid(doors[i].entity) then doors[i].entity:Remove() end
            table.remove(doors,i)
        end
    end
    while #doors>=config.DebrisCap do
        if IsValid(doors[1].entity) then doors[1].entity:Remove() end
        table.remove(doors,1)
    end
    local entity=ents.CreateClientProp(model)
    if not IsValid(entity) then return end
    entity:SetPos(pos);entity:SetAngles(angles);entity:SetSkin(skin)
    for group,value in pairs(groups) do entity:SetBodygroup(group,value) end
    entity:SetCollisionGroup(COLLISION_GROUP_DEBRIS);entity:Spawn();entity:Activate()
    local phys=entity:GetPhysicsObject()
    if not IsValid(phys) and model:sub(1,1)=="*" then
        entity:PhysicsInitBox(mins,maxs);phys=entity:GetPhysicsObject()
    end
    if not IsValid(phys) then entity:Remove();return end
    if not ClearBirth(entity,phys,pos,velocity) then return end
    phys:SetVelocity(velocity);phys:AddAngleVelocity(VectorRand()*120);phys:Wake()
    doors[#doors+1]={entity=entity,expires=CurTime()+config.DebrisLifetime}
end
local function Remove(index)
    local entry=table.remove(props,index)
    if IsValid(entry.entity) then entry.entity:Remove() end
end
local function Clean()
    local now=CurTime()
    for index=#props,1,-1 do
        if not IsValid(props[index].entity) or now>=props[index].expires then Remove(index) end
    end
    local limit=enabled:GetBool() and math.Clamp(cap:GetInt(),0,96) or 0
    while #props>limit do Remove(1) end
    for i=#doors,1,-1 do
        if not enabled:GetBool() or cap:GetInt()<=0 or not IsValid(doors[i].entity) or now>=doors[i].expires then
            if IsValid(doors[i].entity) then doors[i].entity:Remove() end
            table.remove(doors,i)
        end
    end
end
function D.Spawn(id,pos,angles,scale,velocity,skin,body)
    local model=A.Models[id]
    if not model or not enabled:GetBool() or cap:GetInt()<=0 then return end
    local viewer=LocalPlayer()
    if not IsValid(viewer) or viewer:EyePos():DistToSqr(pos)>distance:GetFloat()^2 then return end
    Clean()
    while #props>=math.Clamp(cap:GetInt(),1,96) do Remove(1) end
    local entity=ents.CreateClientProp(model)
    if not IsValid(entity) then return end
    entity:SetPos(pos);entity:SetAngles(angles);entity:SetModelScale(scale,0)
    entity:SetSkin(skin or defaults[id] or 0);entity:SetBodygroup(0,body or 0)
    entity:SetCollisionGroup(COLLISION_GROUP_DEBRIS);entity:Spawn();entity:Activate()
    local physics=entity:GetPhysicsObject()
    if not IsValid(physics) then entity:Remove();return end
    local properties=skeleton.Physics[id] or heavy.Physics[id] or B.Physics and B.Physics[id]
    if properties then physics:SetMaterial(properties.Material);physics:SetMass(properties.Mass) end
    if not ClearBirth(entity,physics,pos,velocity) then return end
    physics:SetVelocity(velocity);physics:AddAngleVelocity(VectorRand()*180);physics:Wake()
    local duration=math.Clamp(lifetime:GetFloat(),2,60)
    props[#props+1]={entity=entity,expires=CurTime()+((id<=3 or B.ShortLived[id] or skeleton.ShortLived[id] or heavy.ShortLived[id]) and math.min(duration,8) or duration)}
end
net.Receive("ZA1/Debris",function()
    local id,pos,angles,scale,velocity=net.ReadUInt(8),net.ReadVector(),net.ReadAngle(),net.ReadFloat(),net.ReadVector()
    local skin,body=net.ReadUInt(8),net.ReadUInt(8)
    scale=math.Clamp(scale,0.1,8)
    if id==0 then
        for _,gib in ipairs(A.Gibs) do D.Spawn(gib.ID,pos,angles,scale,velocity+VectorRand()*70+Vector(0,0,90)) end
    else D.Spawn(id,pos,angles,scale,velocity,skin,body) end
end)
net.Receive("ZA1/Breakup",function()
    local count,scale=net.ReadUInt(4),math.Clamp(net.ReadFloat(),0.1,8)
    for index=1,count do
        local id,pos,angles,velocity=net.ReadUInt(8),net.ReadVector(),net.ReadAngle(),net.ReadVector()
        local skin,body=net.ReadUInt(8),net.ReadUInt(8)
        D.Spawn(id,pos,angles,scale,velocity,skin,body)
    end
end)
timer.Create("ZA1/DebrisCleanup",0.5,0,Clean)
hook.Add("PostCleanupMap","ZA1/Debris",function()
    while #props>0 do Remove(#props) end
    for _,door in ipairs(doors) do if IsValid(door.entity) then door.entity:Remove() end end
    doors={}
end)
