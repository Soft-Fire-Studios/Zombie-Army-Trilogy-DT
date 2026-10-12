AddCSLuaFile()
if not DT_Base then return end
ENT.Base, ENT.Type = "npc_dt_za1_major", "nextbot"
ENT.DT_NextBot, ENT.DT_Version, ENT.Spawnable = true, 1, false
ENT.PrintName, ENT.Category, ENT.ZASpecial = "Deadeye Sniper", "Zombie Army Trilogy", "sniper"
ENT.Models = {ZA1.MajorAssets.Enemies.sniper.Model}
ENT.MaxHealth = ZA1.SpecialConfig.sniper.Health
ENT.SightRange = ZA1.SpecialConfig.sniper.SightRange
ENT.Height, ENT.Width = 74, 15
ENT.IdleAnimation = ZA1.SpecialConfig.sniper.Idle[1]
ENT.WalkAnimation, ENT.RunAnimation = ZA1.SpecialConfig.sniper.Walk[1], ZA1.SpecialConfig.sniper.Walk[1]
ENT.FallAnimation = ENT.IdleAnimation
if SERVER then
    function ENT:OnRagdoll(rag)
        baseclass.Get("npc_dt_za1_special").OnRagdoll(self, rag)
        -- Corpse owns the intact-head death cue, so removing the NextBot
        -- cannot immediately stop its original dialogue recording.
        ZA1.Sniper.PlayVoice(self, "death", rag)
    end
end
DT_Base.AddNextBot(ENT)
