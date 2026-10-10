-- Rare, lazy authored gun actions; the animation raises and lowers the arm.
local R={};ZA1.Ranged=R
local A=include("za1/ranged_assets.lua")
local C=ZA1.Config.Ranged
function R.HasWeapon(z) return A.Weapons[z:GetBodygroup(ZA1.Config.Equipment.WeaponBodygroup)]~=nil end
local function FinishSound(z)
    if z.ZAGunSound then z.ZAGunSound:Stop();z.ZAGunSound=nil end
    local gun=z.ZARangedGun
    if z.ZAGunStarted and gun and gun.Stop and #gun.Stop>0 then
        z:EmitSound(gun.Stop[math.random(#gun.Stop)],80,100,C.Volume,CHAN_WEAPON)
    end
    z.ZAGunStarted=nil
end
function R.Stop(z)
    FinishSound(z)
    z.ZAFiring,z.ZARangedTarget,z.ZARangedAction,z.ZARangedGun=nil,nil,nil,nil
    z.ZAGunClosed,z.ZAGunSoundUntil=nil,nil
end
local function Goal(z)
    if z:IsPossessed() then
        local controls=z:GetPossessionControls()
        return IsValid(controls) and controls:TraceLine().HitPos
    end
    local target=z.ZARangedTarget
    if IsValid(target) and (not target.Alive or target:Alive()) then return target:WorldSpaceCenter() end
end
local function Start(z)
    if z.ZAGunStarted or z.ZAGunClosed then return end
    z.ZAGunStarted=true;z.ZANextBullet=CurTime()
    local gun=z.ZARangedGun
    if gun.Loop and #gun.Loop>0 then
        z.ZAGunSound=CreateSound(z,gun.Loop[math.random(#gun.Loop)]);z.ZAGunSound:PlayEx(C.Volume,90)
    end
end
function R.Fire(z)
    local action,gun=z.ZARangedAction,z.ZARangedGun
    if not z.ZAFiring or not z.ZAGunStarted or z.ZAGunClosed or not action or not gun
        or z.ZAGunShots>=action.MaxShots or CurTime()<(z.ZANextBullet or 0) then return end
    local goal=Goal(z);if not goal then return end
    local id=z:LookupAttachment("za1_"..gun.Name.."_fire");local socket=id and id>0 and z:GetAttachment(id)
    if not socket then return end
    z.ZANextBullet=CurTime()+C.FireInterval;z.ZAGunShots=z.ZAGunShots+1
    local direction=(goal-socket.Pos):GetNormalized()
    z:FireBullets({Attacker=z,Num=1,Src=socket.Pos,Dir=direction,Spread=Vector(C.Spread,C.Spread,0),
        Tracer=1,Damage=C.Damage,Force=2,Distance=C.MaxDistance,IgnoreEntity=z})
    if gun.Single then z:EmitSound(gun.Single[math.random(#gun.Single)],80,100,C.Volume,CHAN_WEAPON) end
    local attachment=z:LookupAttachment("za1_"..gun.Name.."_muzzle")
    local muzzle=attachment and attachment>0 and z:GetAttachment(attachment)
    ZA1.Feedback.Muzzle(z,muzzle and muzzle.Pos or socket.Pos,muzzle and muzzle.Ang or socket.Ang,
        muzzle and attachment or id,gun.Name)
    if z.ZAGunShots>=action.MaxShots then z.ZAGunSoundUntil=CurTime()+C.FireInterval end
end
function R.Event(z,event,options)
    if not z.ZAFiring then return false end
    if event==1103 and options=="za1_gun_start" then Start(z);R.Fire(z);return true end
    if event==1104 and options=="za1_gun_stop" then FinishSound(z);z.ZAGunClosed=true;return true end
    return false
end
function R.Attack(z,target)
    local weapon=z:GetBodygroup(ZA1.Config.Equipment.WeaponBodygroup);local gun=A.Weapons[weapon]
    if not gun or z.ZAActing or z.ZACrawling or z:GetBodygroup(3)>0 or CurTime()<(z.ZANextRanged or 0) then return false end
    z.ZANextRanged=CurTime()+math.Rand(C.MinCooldown,C.MaxCooldown)
    local action=A.Actions[math.random(#A.Actions)]
    z.ZAFiring,z.ZARangedTarget,z.ZARangedAction,z.ZARangedGun=true,target,action,gun
    z.ZAGunShots,z.ZAGunClosed=0,false
    z:ZAPlayOnce(action.Sequence,function()
        if z:IsAIDisabled() or not Goal(z) or z:GetBodygroup(ZA1.Config.Equipment.WeaponBodygroup)~=weapon
            or z:GetBodygroup(3)>0 then return false end
        -- Retain the native action: no gun aim layer or body servo.
        local cycle=z:GetCycle()
        if cycle>=action.End then FinishSound(z);z.ZAGunClosed=true
        elseif cycle>=action.Start then Start(z);R.Fire(z) end
        if z.ZAGunSoundUntil and CurTime()>=z.ZAGunSoundUntil then FinishSound(z);z.ZAGunClosed=true end
    end)
    R.Stop(z);return true
end
function R.Try(z,target,visible)
    if not visible or not IsValid(target) or not R.HasWeapon(z) or z.ZACrawling or z:GetBodygroup(3)>0
        or CurTime()<(z.ZANextRanged or 0) then return false end
    local direction=target:GetPos()-z:GetPos();local distance=direction:Length2D()
    if distance<C.MinDistance or distance>C.MaxDistance or math.abs(direction.z)>z.Height*2
        or z:GetForward():Dot(direction:GetNormalized())<math.cos(math.rad(ZA1.Config.Melee.FacingAngle)) then return false end
    if math.Rand(0,1)>=C.Chance then z.ZANextRanged=CurTime()+C.MinCooldown;return false end
    return R.Attack(z,target)
end
