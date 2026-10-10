AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_special"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Suicide Grunt"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "suicide"
ENT.Models = {"models/zombiearmytrilogy/undead_suicide_grunt.mdl"}
ENT.MaxHealth = ZA1.SpecialConfig.suicide.Health
ENT.IdleAnimation = ZA1.SpecialConfig.suicide.Idle[1]
ENT.WalkAnimation = ZA1.SpecialConfig.suicide.Walk[1]
ENT.RunAnimation = ZA1.SpecialConfig.suicide.Run[1]
ENT.FallAnimation = ENT.IdleAnimation
if SERVER then
    function ENT:ShouldRun() return self:HasEnemy() and not self.ZAFuse end
    function ENT:ZAMelee(target) return ZA1.Specials.Arm(self, target) end
    function ENT:ZALunge() return false end
end
DT_Base.AddNextBot(ENT)
