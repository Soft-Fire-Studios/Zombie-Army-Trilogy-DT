AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_elite"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Chainsaw Elite"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "chainsaw"
ENT.Models = {ZA1.EliteAssets.Enemies.chainsaw.Model}
ENT.MaxHealth = ZA1.SpecialConfig.chainsaw.Health
ENT.Height, ENT.Width = 90, 17
ENT.IdleAnimation = ZA1.SpecialConfig.chainsaw.Idle[1]
ENT.WalkAnimation = ZA1.SpecialConfig.chainsaw.Walk[1]
ENT.RunAnimation = ZA1.SpecialConfig.chainsaw.Run[1]
ENT.FallAnimation = ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
