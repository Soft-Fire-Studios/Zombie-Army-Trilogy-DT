AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_elite"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Ignited Zombie"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "burning"
ENT.Models = {ZA1.EliteAssets.Enemies.burning.Model}
ENT.MaxHealth = ZA1.SpecialConfig.burning.Health
ENT.Height, ENT.Width = 74, 14
ENT.IdleAnimation = ZA1.SpecialConfig.burning.Idle[1]
ENT.WalkAnimation = ZA1.SpecialConfig.burning.Walk[1]
ENT.RunAnimation, ENT.FallAnimation = ENT.WalkAnimation, ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
