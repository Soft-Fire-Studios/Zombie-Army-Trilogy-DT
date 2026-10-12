if SERVER then AddCSLuaFile() end
local C = {}; ZA1.Combat = C
if CLIENT then return end
local settings = ZA1.Config.Combat
local holds = {pistol = "Pistol", revolver = "Pistol", smg = "MachineGun", ar2 = "Rifle",
    shotgun = "Rifle", crossbow = "Rifle"}

-- No polling or cached weapon classification: a hit resolves the weapon that
-- caused it, so switching weapons cannot leave an old resistance selected.
function C.BulletKind(info)
    local attacker, weapon = info:GetAttacker(), info:GetInflictor()
    if IsValid(attacker) and (attacker.IsNPC and attacker:IsNPC() or attacker.IsNextBot and attacker:IsNextBot()) then return "AIBullet" end
    if not IsValid(weapon) or not weapon.IsWeapon or not weapon:IsWeapon() then
        weapon = IsValid(attacker) and attacker.GetActiveWeapon and attacker:GetActiveWeapon() or nil
    end
    if IsValid(weapon) then
        local named = settings.WeaponTypes[weapon:GetClass()]
        if named then return named end
        if weapon.GetHoldType then return holds[weapon:GetHoldType()] or "Bullet" end
    end
    return "Bullet"
end

function C.Apply(z, info, tr)
    if info:GetDamage() <= 0 then return end
    local profile = z.ZASpecialSettings and z.ZASpecialSettings.Resistance or settings.Resistance
    if info:IsBulletDamage() then
        local group, kind = tr and tr.HitGroup, C.BulletKind(info)
        local weak = z.ZASpecialSettings and z.ZASpecialSettings.WeakpointResistance
        if weak and (group == HITGROUP_HEAD or tr and tr.ZARearWeakpoint) then profile = weak end
        local scale = profile[kind] or profile.Bullet or profile.Default or 1
        if group == HITGROUP_HEAD then scale = scale * (settings.Head[kind] or settings.Head.Bullet)
        elseif group == HITGROUP_LEFTARM or group == HITGROUP_RIGHTARM then scale = scale * settings.Arm
        elseif group == HITGROUP_LEFTLEG or group == HITGROUP_RIGHTLEG then
            scale = scale * (kind == "Rifle" and settings.RifleLeg or settings.Leg)
        end
        info:ScaleDamage(scale)
    elseif info:IsExplosionDamage() then info:ScaleDamage(profile.Explosion or profile.Default or 1)
    elseif info:IsDamageType(DMG_BURN) then info:ScaleDamage(profile.Fire or profile.Default or 1)
    else info:ScaleDamage(profile.Default or 1) end
end
