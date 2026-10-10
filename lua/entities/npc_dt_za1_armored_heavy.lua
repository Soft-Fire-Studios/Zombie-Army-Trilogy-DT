AddCSLuaFile()
if not DT_Base then return end
ENT.Base = "npc_dt_za1_special"
ENT.Type = "nextbot"
ENT.DT_NextBot = true
ENT.DT_Version = 1
ENT.Spawnable = false
ENT.PrintName = "Armored Heavy"
ENT.Category = "Zombie Army Trilogy"
ENT.ZASpecial = "heavy"
ENT.Models = {"models/zombiearmytrilogy/undead_heavyarmour_burnt.mdl"}
ENT.MaxHealth = ZA1.SpecialConfig.heavy.Health
-- The native Heavy rig is 1.2 times the common soldier's height. Scale the
-- navigation hull accordingly; visual armor does not become navigation props.
ENT.Height = 90
ENT.Width = 17
ENT.PossessionViewDistance = 132
ENT.BloodColor = BLOOD_COLOR_RED
ENT.IdleAnimation = ZA1.SpecialConfig.heavy.Idle[1]
ENT.WalkAnimation = ZA1.SpecialConfig.heavy.Walk[1]
ENT.RunAnimation = ENT.WalkAnimation
ENT.FallAnimation = ENT.IdleAnimation
DT_Base.AddNextBot(ENT)
