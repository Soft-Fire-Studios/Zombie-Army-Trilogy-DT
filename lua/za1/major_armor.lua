local data = ZA1.MajorAssets.Enemies.mg42
local V = {Bodygroups = {}, ArmoredSet = 1, BodyHitboxes = data.BodyHitboxes,
    Armor = data.Armor, Pieces = data.ArmorPieces}
local A = include("za1/armor.lua")(V, ZA1.SpecialConfig.mg42.Armor, "ZAMG42")
ZA1.MG42Armor = A
return A
