AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_skeleton"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Armored Skeleton"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "skeleton"
ENT.ZASkeletonVariant = "armored"
ENT.Models = {"models/zombiearmytrilogy/undead_skeleton_infantry.mdl"}
DT_Base.AddNextBot(ENT)
