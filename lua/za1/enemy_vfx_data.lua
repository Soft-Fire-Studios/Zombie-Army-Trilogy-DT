-- Original Trilogy enemy effects. Generated named sections; preserve all native values.
-- Each section is registered for joining clients before it is included.
if SERVER then
    AddCSLuaFile("za1/enemy_vfx_data/chainsaw_blade.lua")
    AddCSLuaFile("za1/enemy_vfx_data/chainsaw_blade_trail.lua")
    AddCSLuaFile("za1/enemy_vfx_data/chainsaw_exhaust.lua")
    AddCSLuaFile("za1/enemy_vfx_data/skeleton_bone_frags_small.lua")
    AddCSLuaFile("za1/enemy_vfx_data/skeleton_heart_activate.lua")
    AddCSLuaFile("za1/enemy_vfx_data/skeleton_weak_spot_impact.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_aoe.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_aoe_base.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_aoe_damage.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_damaged.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_emergedemonicring.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_hands.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_highlight.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_skinswitch_flash.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_base.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_base_radial.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_core.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_core_regen.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_electric.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_electrichuge.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_electric_mute.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_eye_flames.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_eye_flames_orange.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_ressurrect_interupt.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_shield_recharged_flash.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_shot.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_shot_body.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_skull_shield_central_trails.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_skull_shield_fire.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_skull_shield_regeneration.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_skull_shield_shot.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_skull_shield_trails.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_arch_general_spawning_trails.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_deadeye_sniper_eye_flame.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_deadeye_sniper_gas.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_deadeye_headshot.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_deadeye_jump_trail.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_grunt_orange_dissolve.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_grunt_orange_dissolvenonloop.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_grunt_orange_dissolve_nza3.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_summoner_spawn_trail.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_superelite_body_impact_dust.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_skeleton_corpseredmist.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_suicide_grunt_smoke.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_summoner_default.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_summoner_overload.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_summoner_summon.lua")
    AddCSLuaFile("za1/enemy_vfx_data/undead_summoner_summon_appear.lua")
end
local part_1 = include("za1/enemy_vfx_data/chainsaw_blade.lua")
local part_2 = include("za1/enemy_vfx_data/chainsaw_blade_trail.lua")
local part_3 = include("za1/enemy_vfx_data/chainsaw_exhaust.lua")
local part_4 = include("za1/enemy_vfx_data/skeleton_bone_frags_small.lua")
local part_5 = include("za1/enemy_vfx_data/skeleton_heart_activate.lua")
local part_6 = include("za1/enemy_vfx_data/skeleton_weak_spot_impact.lua")
local part_7 = include("za1/enemy_vfx_data/undead_arch_general_aoe.lua")
local part_8 = include("za1/enemy_vfx_data/undead_arch_general_aoe_base.lua")
local part_9 = include("za1/enemy_vfx_data/undead_arch_general_aoe_damage.lua")
local part_10 = include("za1/enemy_vfx_data/undead_arch_general_damaged.lua")
local part_11 = include("za1/enemy_vfx_data/undead_arch_general_emergedemonicring.lua")
local part_12 = include("za1/enemy_vfx_data/undead_arch_general_hands.lua")
local part_13 = include("za1/enemy_vfx_data/undead_arch_general_highlight.lua")
local part_14 = include("za1/enemy_vfx_data/undead_arch_general_skinswitch_flash.lua")
local part_15 = include("za1/enemy_vfx_data/undead_arch_general_base.lua")
local part_16 = include("za1/enemy_vfx_data/undead_arch_general_base_radial.lua")
local part_17 = include("za1/enemy_vfx_data/undead_arch_general_core.lua")
local part_18 = include("za1/enemy_vfx_data/undead_arch_general_core_regen.lua")
local part_19 = include("za1/enemy_vfx_data/undead_arch_general_electric.lua")
local part_20 = include("za1/enemy_vfx_data/undead_arch_general_electrichuge.lua")
local part_21 = include("za1/enemy_vfx_data/undead_arch_general_electric_mute.lua")
local part_22 = include("za1/enemy_vfx_data/undead_arch_general_eye_flames.lua")
local part_23 = include("za1/enemy_vfx_data/undead_arch_general_eye_flames_orange.lua")
local part_24 = include("za1/enemy_vfx_data/undead_arch_general_ressurrect_interupt.lua")
local part_25 = include("za1/enemy_vfx_data/undead_arch_general_shield_recharged_flash.lua")
local part_26 = include("za1/enemy_vfx_data/undead_arch_general_shot.lua")
local part_27 = include("za1/enemy_vfx_data/undead_arch_general_shot_body.lua")
local part_28 = include("za1/enemy_vfx_data/undead_arch_general_skull_shield_central_trails.lua")
local part_29 = include("za1/enemy_vfx_data/undead_arch_general_skull_shield_fire.lua")
local part_30 = include("za1/enemy_vfx_data/undead_arch_general_skull_shield_regeneration.lua")
local part_31 = include("za1/enemy_vfx_data/undead_arch_general_skull_shield_shot.lua")
local part_32 = include("za1/enemy_vfx_data/undead_arch_general_skull_shield_trails.lua")
local part_33 = include("za1/enemy_vfx_data/undead_arch_general_spawning_trails.lua")
local part_34 = include("za1/enemy_vfx_data/undead_deadeye_sniper_eye_flame.lua")
local part_35 = include("za1/enemy_vfx_data/undead_deadeye_sniper_gas.lua")
local part_36 = include("za1/enemy_vfx_data/undead_deadeye_headshot.lua")
local part_37 = include("za1/enemy_vfx_data/undead_deadeye_jump_trail.lua")
local part_38 = include("za1/enemy_vfx_data/undead_grunt_orange_dissolve.lua")
local part_39 = include("za1/enemy_vfx_data/undead_grunt_orange_dissolvenonloop.lua")
local part_40 = include("za1/enemy_vfx_data/undead_grunt_orange_dissolve_nza3.lua")
local part_41 = include("za1/enemy_vfx_data/undead_summoner_spawn_trail.lua")
local part_42 = include("za1/enemy_vfx_data/undead_superelite_body_impact_dust.lua")
local part_43 = include("za1/enemy_vfx_data/undead_skeleton_corpseredmist.lua")
local part_44 = include("za1/enemy_vfx_data/undead_suicide_grunt_smoke.lua")
local part_45 = include("za1/enemy_vfx_data/undead_summoner_default.lua")
local part_46 = include("za1/enemy_vfx_data/undead_summoner_overload.lua")
local part_47 = include("za1/enemy_vfx_data/undead_summoner_summon.lua")
local part_48 = include("za1/enemy_vfx_data/undead_summoner_summon_appear.lua")
return {
    ["DynamicLights"] = false,
    ["Basis"] = "z,-x,-y",
    ["PCF"] = "particles/zat_enemies.pcf",
    ["Sprites"] = {
        ["Chainsaw_blade"] = part_1["Sprites"],
        ["Chainsaw_exhaust"] = part_3["Sprites"],
        ["Skeleton_bone_frags_small"] = part_4["Sprites"],
        ["Skeleton_heart_activate"] = part_5["Sprites"],
        ["Skeleton_weak_spot_impact"] = part_6["Sprites"],
        ["Undead_Arch_General_AOE_base"] = part_8["Sprites"],
        ["Undead_Arch_General_AOE_damage"] = part_9["Sprites"],
        ["Undead_Arch_General_Damaged"] = part_10["Sprites"],
        ["Undead_Arch_General_EmergeDemonicRing"] = part_11["Sprites"],
        ["Undead_Arch_General_Hands"] = part_12["Sprites"],
        ["Undead_Arch_General_Highlight"] = part_13["Sprites"],
        ["Undead_Arch_General_SkinSwitch_Flash"] = part_14["Sprites"],
        ["Undead_Arch_General_base"] = part_15["Sprites"],
        ["Undead_Arch_General_base_radial"] = part_16["Sprites"],
        ["Undead_Arch_General_core"] = part_17["Sprites"],
        ["Undead_Arch_General_core_regen"] = part_18["Sprites"],
        ["Undead_Arch_General_electric"] = part_19["Sprites"],
        ["Undead_Arch_General_electricHuge"] = part_20["Sprites"],
        ["Undead_Arch_General_electric_Mute"] = part_21["Sprites"],
        ["Undead_Arch_General_eye_flames"] = part_22["Sprites"],
        ["Undead_Arch_General_eye_flames_orange"] = part_23["Sprites"],
        ["Undead_Arch_General_ressurrect_interupt"] = part_24["Sprites"],
        ["Undead_Arch_General_shield_recharged_flash"] = part_25["Sprites"],
        ["Undead_Arch_General_shot"] = part_26["Sprites"],
        ["Undead_Arch_General_shot_body"] = part_27["Sprites"],
        ["Undead_Arch_General_skull_shield_fire"] = part_29["Sprites"],
        ["Undead_Arch_General_skull_shield_regeneration"] = part_30["Sprites"],
        ["Undead_Arch_General_skull_shield_shot"] = part_31["Sprites"],
        ["Undead_Arch_General_spawning_trails"] = part_33["Sprites"],
        ["Undead_DeadEye_Sniper_Eye_flame"] = part_34["Sprites"],
        ["Undead_DeadEye_Sniper_gas"] = part_35["Sprites"],
        ["Undead_DeadEye_headshot"] = part_36["Sprites"],
        ["Undead_Grunt_Orange_Dissolve"] = part_38["Sprites"],
        ["Undead_Grunt_Orange_DissolveNonLoop"] = part_39["Sprites"],
        ["Undead_Grunt_Orange_Dissolve_NZA3"] = part_40["Sprites"],
        ["Undead_Summoner_Spawn_trail"] = part_41["Sprites"],
        ["Undead_SuperElite_body_impact_dust"] = part_42["Sprites"],
        ["Undead_skeleton_corpseRedMist"] = part_43["Sprites"],
        ["Undead_suicide_grunt_smoke"] = part_44["Sprites"],
        ["Undead_summoner_default"] = part_45["Sprites"],
        ["Undead_summoner_overload"] = part_46["Sprites"],
        ["Undead_summoner_summon"] = part_47["Sprites"],
        ["Undead_summoner_summon_appear"] = part_48["Sprites"],
    },
    ["Systems"] = {
        ["Chainsaw_blade"] = part_1["Systems"],
        ["Chainsaw_blade_trail"] = part_2["Systems"],
        ["Chainsaw_exhaust"] = part_3["Systems"],
        ["Skeleton_bone_frags_small"] = part_4["Systems"],
        ["Skeleton_heart_activate"] = part_5["Systems"],
        ["Skeleton_weak_spot_impact"] = part_6["Systems"],
        ["Undead_Arch_General_AOE"] = part_7["Systems"],
        ["Undead_Arch_General_AOE_base"] = part_8["Systems"],
        ["Undead_Arch_General_AOE_damage"] = part_9["Systems"],
        ["Undead_Arch_General_Damaged"] = part_10["Systems"],
        ["Undead_Arch_General_EmergeDemonicRing"] = part_11["Systems"],
        ["Undead_Arch_General_Hands"] = part_12["Systems"],
        ["Undead_Arch_General_Highlight"] = part_13["Systems"],
        ["Undead_Arch_General_SkinSwitch_Flash"] = part_14["Systems"],
        ["Undead_Arch_General_base"] = part_15["Systems"],
        ["Undead_Arch_General_base_radial"] = part_16["Systems"],
        ["Undead_Arch_General_core"] = part_17["Systems"],
        ["Undead_Arch_General_core_regen"] = part_18["Systems"],
        ["Undead_Arch_General_electric"] = part_19["Systems"],
        ["Undead_Arch_General_electricHuge"] = part_20["Systems"],
        ["Undead_Arch_General_electric_Mute"] = part_21["Systems"],
        ["Undead_Arch_General_eye_flames"] = part_22["Systems"],
        ["Undead_Arch_General_eye_flames_orange"] = part_23["Systems"],
        ["Undead_Arch_General_ressurrect_interupt"] = part_24["Systems"],
        ["Undead_Arch_General_shield_recharged_flash"] = part_25["Systems"],
        ["Undead_Arch_General_shot"] = part_26["Systems"],
        ["Undead_Arch_General_shot_body"] = part_27["Systems"],
        ["Undead_Arch_General_skull_shield_central_trails"] = part_28["Systems"],
        ["Undead_Arch_General_skull_shield_fire"] = part_29["Systems"],
        ["Undead_Arch_General_skull_shield_regeneration"] = part_30["Systems"],
        ["Undead_Arch_General_skull_shield_shot"] = part_31["Systems"],
        ["Undead_Arch_General_skull_shield_trails"] = part_32["Systems"],
        ["Undead_Arch_General_spawning_trails"] = part_33["Systems"],
        ["Undead_DeadEye_Sniper_Eye_flame"] = part_34["Systems"],
        ["Undead_DeadEye_Sniper_gas"] = part_35["Systems"],
        ["Undead_DeadEye_headshot"] = part_36["Systems"],
        ["Undead_DeadEye_jump_trail"] = part_37["Systems"],
        ["Undead_Grunt_Orange_Dissolve"] = part_38["Systems"],
        ["Undead_Grunt_Orange_DissolveNonLoop"] = part_39["Systems"],
        ["Undead_Grunt_Orange_Dissolve_NZA3"] = part_40["Systems"],
        ["Undead_Summoner_Spawn_trail"] = part_41["Systems"],
        ["Undead_SuperElite_body_impact_dust"] = part_42["Systems"],
        ["Undead_skeleton_corpseRedMist"] = part_43["Systems"],
        ["Undead_suicide_grunt_smoke"] = part_44["Systems"],
        ["Undead_summoner_default"] = part_45["Systems"],
        ["Undead_summoner_overload"] = part_46["Systems"],
        ["Undead_summoner_summon"] = part_47["Systems"],
        ["Undead_summoner_summon_appear"] = part_48["Systems"],
    },
    ["Ribbons"] = {
        ["Chainsaw_blade"] = part_1["Ribbons"],
        ["Chainsaw_blade_trail"] = part_2["Ribbons"],
        ["Undead_Arch_General_AOE"] = part_7["Ribbons"],
        ["Undead_Arch_General_skull_shield_central_trails"] = part_28["Ribbons"],
        ["Undead_Arch_General_skull_shield_trails"] = part_32["Ribbons"],
        ["Undead_Arch_General_spawning_trails"] = part_33["Ribbons"],
        ["Undead_DeadEye_jump_trail"] = part_37["Ribbons"],
        ["Undead_Summoner_Spawn_trail"] = part_41["Ribbons"],
        ["Undead_skeleton_corpseRedMist"] = part_43["Ribbons"],
        ["Undead_summoner_default"] = part_45["Ribbons"],
        ["Undead_summoner_overload"] = part_46["Ribbons"],
        ["Undead_summoner_summon"] = part_47["Ribbons"],
        ["Undead_summoner_summon_appear"] = part_48["Ribbons"],
    },
    ["Scale"] = 39.37007874015748,
    ["Effects"] = {
        ["Chainsaw_blade"] = part_1["Effects"],
        ["Chainsaw_blade_trail"] = part_2["Effects"],
        ["Chainsaw_exhaust"] = part_3["Effects"],
        ["Skeleton_bone_frags_small"] = part_4["Effects"],
        ["Skeleton_heart_activate"] = part_5["Effects"],
        ["Skeleton_weak_spot_impact"] = part_6["Effects"],
        ["Undead_Arch_General_AOE"] = part_7["Effects"],
        ["Undead_Arch_General_AOE_base"] = part_8["Effects"],
        ["Undead_Arch_General_AOE_damage"] = part_9["Effects"],
        ["Undead_Arch_General_Damaged"] = part_10["Effects"],
        ["Undead_Arch_General_EmergeDemonicRing"] = part_11["Effects"],
        ["Undead_Arch_General_Hands"] = part_12["Effects"],
        ["Undead_Arch_General_Highlight"] = part_13["Effects"],
        ["Undead_Arch_General_SkinSwitch_Flash"] = part_14["Effects"],
        ["Undead_Arch_General_base"] = part_15["Effects"],
        ["Undead_Arch_General_base_radial"] = part_16["Effects"],
        ["Undead_Arch_General_core"] = part_17["Effects"],
        ["Undead_Arch_General_core_regen"] = part_18["Effects"],
        ["Undead_Arch_General_electric"] = part_19["Effects"],
        ["Undead_Arch_General_electricHuge"] = part_20["Effects"],
        ["Undead_Arch_General_electric_Mute"] = part_21["Effects"],
        ["Undead_Arch_General_eye_flames"] = part_22["Effects"],
        ["Undead_Arch_General_eye_flames_orange"] = part_23["Effects"],
        ["Undead_Arch_General_ressurrect_interupt"] = part_24["Effects"],
        ["Undead_Arch_General_shield_recharged_flash"] = part_25["Effects"],
        ["Undead_Arch_General_shot"] = part_26["Effects"],
        ["Undead_Arch_General_shot_body"] = part_27["Effects"],
        ["Undead_Arch_General_skull_shield_central_trails"] = part_28["Effects"],
        ["Undead_Arch_General_skull_shield_fire"] = part_29["Effects"],
        ["Undead_Arch_General_skull_shield_regeneration"] = part_30["Effects"],
        ["Undead_Arch_General_skull_shield_shot"] = part_31["Effects"],
        ["Undead_Arch_General_skull_shield_trails"] = part_32["Effects"],
        ["Undead_Arch_General_spawning_trails"] = part_33["Effects"],
        ["Undead_DeadEye_Sniper_Eye_flame"] = part_34["Effects"],
        ["Undead_DeadEye_Sniper_gas"] = part_35["Effects"],
        ["Undead_DeadEye_headshot"] = part_36["Effects"],
        ["Undead_DeadEye_jump_trail"] = part_37["Effects"],
        ["Undead_Grunt_Orange_Dissolve"] = part_38["Effects"],
        ["Undead_Grunt_Orange_DissolveNonLoop"] = part_39["Effects"],
        ["Undead_Grunt_Orange_Dissolve_NZA3"] = part_40["Effects"],
        ["Undead_Summoner_Spawn_trail"] = part_41["Effects"],
        ["Undead_SuperElite_body_impact_dust"] = part_42["Effects"],
        ["Undead_skeleton_corpseRedMist"] = part_43["Effects"],
        ["Undead_suicide_grunt_smoke"] = part_44["Effects"],
        ["Undead_summoner_default"] = part_45["Effects"],
        ["Undead_summoner_overload"] = part_46["Effects"],
        ["Undead_summoner_summon"] = part_47["Effects"],
        ["Undead_summoner_summon_appear"] = part_48["Effects"],
    },
}
