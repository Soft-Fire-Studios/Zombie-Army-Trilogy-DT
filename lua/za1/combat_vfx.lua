if SERVER then AddCSLuaFile();AddCSLuaFile("za1/combat_vfx_data.lua") end
-- Original Blood_explosion, stick-grenade and TNT graphs. All layers share
-- the existing bounded atlas/ribbon renderer and finite world effects.
local data=include("za1/combat_vfx_data.lua")
game.AddParticles(data.PCF)
ZA1.FireVFX.RegisterData(data)
