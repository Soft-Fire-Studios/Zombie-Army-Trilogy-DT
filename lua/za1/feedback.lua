if SERVER then AddCSLuaFile();AddCSLuaFile("za1/feedback_assets.lua") end
local F={};ZA1.Feedback=F
local A=include("za1/feedback_assets.lua")
-- SNPC-PRP registers its original PCFs. Reference its systems by name only.
for _,name in ipairs(A.Particles) do PrecacheParticleSystem(name) end
if SERVER then
    util.AddNetworkString("ZA1/Feedback")
    local guns={mp40=1,thompson=2,luger=3}
    function F.Send(kind,pos,angles,entity,attachment,weapon)
        net.Start("ZA1/Feedback");net.WriteUInt(kind,2);net.WriteVector(pos);net.WriteAngle(angles or angle_zero)
        if kind==0 then net.WriteEntity(entity);net.WriteUInt(attachment or 0,8);net.WriteUInt(guns[weapon] or 1,2) end
        net.SendPVS(pos)
    end
    function F.Muzzle(z,pos,angles,attachment,weapon) F.Send(0,pos,angles,z,attachment,weapon) end
    function F.Headshot(pos,angles) F.Send(1,pos,angles) end
    function F.FullGib(z,pos) F.Send(2,pos or z:WorldSpaceCenter(),z:GetAngles()) end
    function F.Explosion(pos)
        F.Send(3,pos,angle_zero)
        for _,layer in ipairs(A.ExplosionSounds) do
            sound.Play(layer.Files[math.random(#layer.Files)],pos,90,100,layer.Volume)
        end
    end
    return
end
local distance=CreateClientConVar("za1_effect_distance","3000",true,false,"Maximum distance for zombie burst particles and lights.",256,8192)
local lights=CreateClientConVar("za1_effect_lights","1",true,false,"Brief lights for zombie guns and explosives.",0,1)
local guns={"mp40","thompson","luger"}
local burstFrame,bursts,lightID=0,0,0
function F.Light(pos,explosion,entity)
    if not lights:GetBool() then return end
    lightID=lightID%12+1
    local id=explosion and 229376+lightID or 196608+(IsValid(entity) and entity:EntIndex() or lightID)
    local light=DynamicLight(id);if not light then return end
    light.pos=pos;light.r=255;light.g=explosion and 145 or 205;light.b=explosion and 65 or 130
    local radius,life=explosion and 450 or 140,explosion and 0.25 or 0.06
    light.brightness=explosion and 3 or 1.5;light.size=radius
    light.decay=radius/life;light.dietime=CurTime()+life
end
net.Receive("ZA1/Feedback",function()
    local kind,pos,angles=net.ReadUInt(2),net.ReadVector(),net.ReadAngle()
    local z,attachment,weapon
    if kind==0 then z,attachment,weapon=net.ReadEntity(),net.ReadUInt(8),guns[net.ReadUInt(2)] end
    local ply=LocalPlayer()
    if not IsValid(ply) or ply:EyePos():DistToSqr(pos)>distance:GetFloat()^2 then return end
    if kind==0 then
        local effect=A.Muzzles[weapon];if not effect then return end
        if IsValid(z) and attachment>0 then ParticleEffectAttach(effect,PATTACH_POINT_FOLLOW,z,attachment)
        else ParticleEffect(effect,pos,angles) end
        F.Light(pos,false,z)
    elseif kind==3 then ParticleEffect(A.Explosion,pos,angles);F.Light(pos,true)
    else
        -- Large death bursts are cosmetic. Do not flood one rendered frame
        -- when a grenade kills a crowded group; retain the nearer hit response.
        local frame=FrameNumber();if frame~=burstFrame then burstFrame,bursts=frame,0 end
        if bursts>=4 then return end
        bursts=bursts+1;ParticleEffect(kind==1 and A.Headshot or A.FullGib,pos,angles)
    end
end)
