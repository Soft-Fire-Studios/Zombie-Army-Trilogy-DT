if SERVER then AddCSLuaFile() end
local L={};ZA1.Look=L
if CLIENT then return end
local C=ZA1.Config.Look
function L.Update(z)
    local now=CurTime()
    if now<(z.ZANextLook or 0) then return end
    local dt=math.min(now-(z.ZALastLook or now-C.Interval),.25)
    z.ZALastLook=now;z.ZANextLook=now+C.Interval
    local yaw,pitch=0,0
    local enemy=z:GetEnemy()
    if not z.ZAHeadDestroyed and not z.ZAActing and not z.ZADowned and not z:IsAIDisabled() and IsValid(enemy) then
        local angles=(enemy:WorldSpaceCenter()-z:EyePos()):Angle()
        yaw=math.AngleDifference(angles.y,z:GetAngles().y)
        pitch=math.AngleDifference(angles.p,z:GetAngles().p)
    end
    local limits=ZA1.LookAssets
    yaw=math.Clamp(yaw,limits.yaw[1],limits.yaw[2]);pitch=math.Clamp(pitch,limits.pitch[1],limits.pitch[2])
    local oldYaw,oldPitch=z.ZALookYaw or 0,z.ZALookPitch or 0
    yaw=math.Approach(oldYaw,yaw,C.Speed*dt);pitch=math.Approach(oldPitch,pitch,C.Speed*dt)
    if yaw~=oldYaw then
        z:SetPoseParameter("look_yaw",yaw);z.ZALookYaw=yaw
        if z.SetZALookYaw then z:SetZALookYaw(yaw) end
    end
    if pitch~=oldPitch then
        z:SetPoseParameter("look_pitch",pitch);z.ZALookPitch=pitch
        if z.SetZALookPitch then z:SetZALookPitch(pitch) end
    end
end
function L.Reset(z)
    z.ZALookYaw=0;z.ZALookPitch=0
    z:SetPoseParameter("look_yaw",0);z:SetPoseParameter("look_pitch",0)
    if z.SetZALookYaw then z:SetZALookYaw(0);z:SetZALookPitch(0) end
end
