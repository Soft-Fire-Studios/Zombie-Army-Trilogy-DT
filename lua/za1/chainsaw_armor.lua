-- The mask uses the same native helmet hardpoint and model as the Heavy.
-- Their exported bone-local bounds differ by less than 0.00005 Source units.
local data = (ZA1.EliteAssets or include("za1/elite_assets.lua")).Enemies.chainsaw
local V = {Bodygroups = {}, ArmoredSet = 1,
    Armor = {{Name = "helmet", Bodygroup = 2, States = {{"heavyarmour_mask_120"}}}},
    Pieces = {heavyarmour_mask_120 = ZA1.HeavyAssets.Pieces.heavyarmour_mask_120},
    BodyHitboxes = data.BodyHitboxes}
local A = include("za1/armor.lua")(V, ZA1.SpecialConfig.chainsaw.Armor, "ZAChainsaw")
ZA1.ChainsawArmor = A
return A
