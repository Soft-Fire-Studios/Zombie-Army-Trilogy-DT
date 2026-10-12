AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_elite"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Fire Demon"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "fire"
ENT.Models = {ZA1.EliteAssets.Enemies.fire.Model}
ENT.MaxHealth = ZA1.SpecialConfig.fire.Health
ENT.Height, ENT.Width = 90, 17
ENT.IdleAnimation = ZA1.SpecialConfig.fire.Idle[1]
ENT.WalkAnimation = ZA1.SpecialConfig.fire.Walk[1]
ENT.RunAnimation, ENT.FallAnimation = ENT.WalkAnimation, ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
