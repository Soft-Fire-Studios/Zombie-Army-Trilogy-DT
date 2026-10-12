AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Fire Demon fireball"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
local C = ZA1.SpecialConfig.Projectiles
if CLIENT then
    function ENT:Initialize()
        ZA1.FireVFX.Projectile(self)
        self:SetRenderBounds(Vector(-96, -96, -96), Vector(96, 96, 96))
    end
    function ENT:Think() ZA1.FireVFX.Projectile(self) end
    function ENT:Draw() end
    function ENT:OnRemove() ZA1.FireVFX.StopProjectile(self.ZAFireVFXProjectile) end
    return
end
function ENT:Initialize()
    if ZA1.Elites.ProjectileCount >= C.Limit then self:Remove(); return end
    ZA1.Elites.ProjectileCount = ZA1.Elites.ProjectileCount + 1; self.ZACounted = true
    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:SetMoveType(MOVETYPE_NONE); self:SetSolid(SOLID_NONE); self:DrawShadow(false)
    self.ZASettings = self.ZASettings or ZA1.SpecialConfig.fire
    self.ZAVelocity = self.ZAVelocity or self:GetForward() * self.ZASettings.FireballSpeed
    self.ZABorn, self.ZALastStep = CurTime(), CurTime()
    local owner = self:GetOwner()
    local sounds = IsValid(owner) and owner.ZASpecialAssets.Roles.fireball_loop
    if sounds and #sounds.Files > 0 then
        self.ZALoop = CreateSound(self, sounds.Files[math.random(#sounds.Files)]); self.ZALoop:PlayEx(.55, 100)
    end
end
function ENT:Impact(tr)
    if self.ZAHit then return end
    self.ZAHit = true
    local pos, settings, owner = tr.HitPos, self.ZASettings, self:GetOwner()
    owner = IsValid(owner) and owner or self
    -- Converted native effect space already uses Source Z-up; no Doom effect tilt.
    net.Start("ZA1/FireballImpact"); net.WriteVector(pos); net.WriteAngle(Angle(0, 0, 0)); net.SendPVS(pos)
    local sounds = owner.ZASpecialAssets and owner.ZASpecialAssets.Roles.fireball_hit
    if sounds and #sounds.Files > 0 then
        sound.Play(sounds.Files[math.random(#sounds.Files)], pos, 85, 100, .85)
    end
    -- Native grenade contact triggers one radial damage record: full strength
    -- within 3m, fading to zero at 9m. Eligible commons hit by that record are
    -- replaced even when they were not the originally selected throw target.
    for _, victim in ipairs(ents.FindInSphere(pos, settings.FireballRadius)) do
        if IsValid(victim) and victim ~= self and victim ~= owner then
            local center = victim:WorldSpaceCenter()
            local sight = util.TraceLine({start = pos + tr.HitNormal * 2, endpos = center,
                mask = MASK_SHOT, filter = {self, owner}})
            local inner = settings.FireballInnerRadius or 0
            local gain = math.Clamp((settings.FireballRadius - pos:Distance(center)) / (settings.FireballRadius - inner), 0, 1)
            -- The original radial policy halves damage/force behind cover.
            if sight.Hit and sight.Entity ~= victim then gain = gain * .5 end
            if gain > 0 then
                if victim.ZA1Zombie then
                    if IsValid(owner) and owner.ZASpecial == "fire" and not owner:IsHatedEntity(victim)
                        and ZA1.Elites.MinionCount(owner) < settings.MinionLimit then
                        ZA1.Elites.Ignite(owner, victim)
                    end
                elseif not owner.IsHatedEntity or owner:IsHatedEntity(victim) then
                    local damage = DamageInfo(); damage:SetAttacker(owner); damage:SetInflictor(self)
                    damage:SetDamageType(DMG_BURN)
                    local strength = self.ZAMode == "damage" and settings.PlayerFireballDamage or settings.FireballDamage
                    damage:SetDamage(strength * gain)
                    damage:SetDamagePosition(pos); damage:SetDamageForce((center - pos):GetNormalized() * settings.FireballForce * gain)
                    victim:TakeDamageInfo(damage)
                end
            end
        end
    end
    self:Remove()
end
function ENT:Think()
    local now = CurTime()
    if now - self.ZABorn >= C.Lifetime then self:Impact({HitPos = self:GetPos(), HitNormal = Vector(0, 0, 1)}); return end
    local start = self:GetPos()
    local dt = math.min(now - self.ZALastStep, .25)
    local gravity = Vector(0, 0, -self.ZASettings.FireballGravity)
    local finish = start + self.ZAVelocity * dt + gravity * (.5 * dt * dt)
    self.ZAVelocity = self.ZAVelocity + gravity * dt
    local owner = self:GetOwner()
    local tr = util.TraceHull({start = start, endpos = finish, mins = Vector(-C.Hull, -C.Hull, -C.Hull),
        maxs = Vector(C.Hull, C.Hull, C.Hull), mask = MASK_SHOT, filter = {self, owner}})
    self.ZALastStep = now
    if tr.Hit or tr.StartSolid then self:Impact(tr); return end
    self:SetPos(finish); self:SetAngles(self.ZAVelocity:Angle()); self:NextThink(now + C.Tick); return true
end
function ENT:OnRemove()
    if self.ZALoop then self.ZALoop:Stop() end
    if self.ZACounted then ZA1.Elites.ProjectileCount = math.max(0, ZA1.Elites.ProjectileCount - 1) end
end
