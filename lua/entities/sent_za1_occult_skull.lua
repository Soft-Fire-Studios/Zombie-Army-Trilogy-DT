AddCSLuaFile()
ENT.Type, ENT.Base = "anim", "base_anim"
ENT.PrintName, ENT.Spawnable = "Occult General shield skull", false
ENT.ZASpecial = "general_skull"
if CLIENT then
    function ENT:Think()
        local effects, orbit = ZA1 and ZA1.EnemyVFX, ZA1 and ZA1.GeneralOrbit
        if not effects or not orbit then
            self.ZAOrbitRenderPosition, self.ZAOrbitRenderAngles = nil, nil
            self:SetRenderOrigin(nil); self:SetRenderAngles(nil)
            return
        end
        local owner = self:GetNW2Entity("za1_general")
        local center = effects.Position(owner, self:GetNW2String("za1_skull_anchor", "Core"), "general")
        if center then
            local position, angles = orbit.World(self:GetNW2String("za1_skull_path", ""),
                math.max(0, CurTime() - self:GetNW2Float("za1_orbit_start", CurTime())) * self:GetNW2Float("za1_skull_rate", 1), center,
                owner:GetAngles(), owner:GetModelScale())
            if angles then angles = orbit.ModelAngles(angles) end
            self.ZAOrbitRenderPosition, self.ZAOrbitRenderAngles = position, angles
            self:SetRenderOrigin(position); self:SetRenderAngles(angles)
        else
            self.ZAOrbitRenderPosition, self.ZAOrbitRenderAngles = nil, nil
            self:SetRenderOrigin(nil); self:SetRenderAngles(nil)
        end
        effects.Update(self)
    end
    return
end
function ENT:Initialize()
    if not self.ZAData or not IsValid(self.ZAGeneral) then self:Remove(); return end
    self:SetModel(self.ZAData.Model)
    self:SetMoveType(MOVETYPE_NONE); self:SetSolid(SOLID_NONE); self:SetNoDraw(true)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:SetHealth(self.ZASettings.SkullHealth); self:DrawShadow(false)
    self:SetNW2Entity("za1_general", self.ZAGeneral)
    self:SetNW2String("za1_skull_path", self.ZAPath)
    self:SetNW2String("za1_skull_anchor", self.ZASettings.Anchor)
    self:SetNW2Float("za1_orbit_start", self.ZAGeneral.ZAGeneralOrbitStart)
    self.ZAPlaybackRate = ZA1.GeneralOrbit.Rate(self.ZAPath, self.ZASettings.Scene)
    if not self.ZAPlaybackRate then self:Remove(); return end
    self:SetNW2Float("za1_skull_rate", self.ZAPlaybackRate)
    self:Think()
    if ZA1.EnemyVFX then ZA1.EnemyVFX.SetState(self, "shielded") end
end
function ENT:Think()
    local owner = self.ZAGeneral
    if not IsValid(owner) or not owner:Alive() or not owner.ZAGeneralShield or owner.ZAGeneralEpoch ~= self.ZAEpoch then self:Remove(); return end
    local settings, scale = self.ZASettings, owner:GetModelScale()
    local center = ZA1.EnemyVFX.Position(owner, settings.Anchor, "general")
    if center then
        local position, angles = ZA1.GeneralOrbit.World(self.ZAPath,
            math.max(0, CurTime() - owner.ZAGeneralOrbitStart)*self.ZAPlaybackRate, center, owner:GetAngles(), scale)
        if position then
            angles = ZA1.GeneralOrbit.ModelAngles(angles)
            self:SetPos(position); self:SetAngles(angles)
            if self.ZAOrbitScale ~= scale then
                self.ZAOrbitScale = scale; self:SetModelScale(scale)
                self:SetCollisionBounds(Vector(unpack(self.ZAData.Mins))*scale, Vector(unpack(self.ZAData.Maxs))*scale)
            end
            if not self.ZAOrbitLocated then self.ZAOrbitLocated = true; self:SetSolid(SOLID_BBOX); self:SetNoDraw(false) end
        end
    end
    self:NextThink(CurTime() + settings.Tick); return true
end
function ENT:OnTakeDamage(info)
    if self.ZABroken or not (info:IsBulletDamage() or info:IsExplosionDamage()) or info:GetDamage() <= 0 then return end
    self:SetHealth(self:Health() - info:GetDamage())
    if self:Health() > 0 then return end
    self.ZABroken = true
    local owner = self.ZAGeneral
    if IsValid(owner) then ZA1.Specials.Sound(owner, "shield_hit", 80, false) end
    if ZA1.EnemyVFX then ZA1.EnemyVFX.Pulse(self, "break", self:GetPos(), self:GetAngles()) end
    self:Remove()
end
function ENT:OnRemove()
    if ZA1.EnemyVFX then ZA1.EnemyVFX.SetState(self, "stopped") end
    if not self.ZAQuietRemove and IsValid(self.ZAGeneral) then ZA1.General.SkullLost(self.ZAGeneral, self.ZAEpoch) end
end
