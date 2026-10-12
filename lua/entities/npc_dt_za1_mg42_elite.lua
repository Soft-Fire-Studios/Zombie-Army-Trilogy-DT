AddCSLuaFile()
if not DT_Base then return end
ENT.Base, ENT.Type = "npc_dt_za1_major", "nextbot"
ENT.DT_NextBot, ENT.DT_Version, ENT.Spawnable = true, 1, false
ENT.PrintName, ENT.Category, ENT.ZASpecial = "MG42 Elite", "Zombie Army Trilogy", "mg42"
ENT.Models = {ZA1.MajorAssets.Enemies.mg42.Model}
ENT.MaxHealth = ZA1.SpecialConfig.mg42.Health
ENT.Height, ENT.Width = 88, 17
ENT.IdleAnimation = ZA1.SpecialConfig.mg42.Idle[1]
ENT.WalkAnimation, ENT.RunAnimation = ZA1.SpecialConfig.mg42.Walk[1], ZA1.SpecialConfig.mg42.Walk[1]
ENT.FallAnimation = ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
