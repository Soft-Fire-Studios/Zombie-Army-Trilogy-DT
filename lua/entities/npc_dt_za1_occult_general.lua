AddCSLuaFile()
if not DT_Base then return end
ENT.Base, ENT.Type = "npc_dt_za1_major", "nextbot"
ENT.DT_NextBot, ENT.DT_Version, ENT.Spawnable = true, 1, false
ENT.PrintName, ENT.Category, ENT.ZASpecial = "Occult General", "Zombie Army Trilogy", "general"
ENT.Models = {ZA1.MajorAssets.Enemies.general.Model}
ENT.MaxHealth = ZA1.SpecialConfig.general.Health
ENT.Height, ENT.Width = 90, 17
ENT.IdleAnimation = ZA1.SpecialConfig.general.Idle[1]
ENT.WalkAnimation, ENT.RunAnimation = ENT.IdleAnimation, ENT.IdleAnimation
ENT.FallAnimation = ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
-- The actor origin belongs on the floor; the authored pose floats above it.
-- Sandbox DropToFloor would instead put the aerial hull on the floor and
-- bury that origin. Keep the clicked ground position, also for duplication.
local spawn = list.GetForEdit("NPC").npc_dt_za1_occult_general
if spawn then spawn.Offset, spawn.NoDrop = 0, true end
