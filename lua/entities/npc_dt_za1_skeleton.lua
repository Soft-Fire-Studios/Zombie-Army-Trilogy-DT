AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_special"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Skeleton"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "skeleton"
ENT.ZASkeletonVariant = "normal"
ENT.Models = {"models/zombiearmytrilogy/undead_skeleton_infantry.mdl"}
ENT.MaxHealth = ZA1.SpecialConfig.skeleton.Health
ENT.BloodColor = DONT_BLEED
ENT.IdleAnimation = ZA1.SpecialConfig.skeleton.Idle[1]
ENT.WalkAnimation = ZA1.SpecialConfig.skeleton.Walk[1]
ENT.RunAnimation = ENT.WalkAnimation
ENT.FallAnimation = ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
