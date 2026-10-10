-- Physics props hurt actors on impact; ordinary world/navigation contacts do not.
local I = {}; ZA1.Impact = I
local C = ZA1.Config.Impact
function I.Hit(z, data)
    if not IsValid(z) or not z:Alive() or z.ZADowned or z.ZAImpactQueued
        or CurTime() < (z.ZANextImpact or 0) then return end
    local prop = data.HitEntity
    if not IsValid(prop) or prop.ZA1Zombie or prop.ZA1Corpse or IsValid(prop.ZARecoveryOwner)
        or prop:GetMoveType() ~= MOVETYPE_VPHYSICS then return end
    local physics = prop:GetPhysicsObject()
    if not IsValid(physics) or not physics:IsMotionEnabled() then return end
    local incoming = data.TheirOldVelocity or prop:GetVelocity()
    local speed = incoming:Length()
    local mass = physics:GetMass()
    if mass < C.MinMass or speed < C.MinSpeed then return end
    local closing = math.abs((incoming - (data.OurOldVelocity or z:GetVelocity())):Dot(data.HitNormal))
    if closing < C.MinSpeed then return end
    local damage = math.min(C.MaxDamage, mass * (closing - C.MinSpeed) ^ 2 / C.EnergyPerDamage)
    if damage < 1 then return end
    local attacker = prop:GetPhysicsAttacker()
    local info = DamageInfo()
    info:SetDamage(damage); info:SetDamageType(DMG_CRUSH)
    info:SetAttacker(IsValid(attacker) and attacker or prop); info:SetInflictor(prop)
    info:SetDamagePosition(data.HitPos); info:SetDamageForce(incoming * mass)
    z.ZAImpactQueued = true; z.ZANextImpact = CurTime() + C.Cooldown
    -- Death can remove the actor. Leave the physics callback before damaging it.
    timer.Simple(0, function()
        if not IsValid(z) then return end
        z.ZAImpactQueued = nil
        if z:Alive() then z:TakeDamageInfo(info) end
    end)
end
function I.Initialize(z)
    z:AddCallback("PhysicsCollide", function(_, data) I.Hit(z, data) end)
end
