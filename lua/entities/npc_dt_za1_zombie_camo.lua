AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_zombie"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.PrintName = "Soldier Zombie"
ENT.Category = "Zombie Army Trilogy"
ENT.Spawnable = false
-- Preserve the old saved class; Trilogy now assembles its native modular body.
DT_Base.AddNextBot(ENT)
