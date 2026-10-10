-- Addon balance values; clip timing, speed, hit markers and attachment bounds
-- come from the original assets. Distances are Source units, times are seconds.
return {
    Director = {Chance = 15, SkeletonLimit = 4, SuicideLimit = 2, HeavyLimit = 2},
    skeleton = {
        Health = 100, MeleeDamage = 25, ExplosionKillDamage = 25,
        -- Bullets must hit the heart. Kicks and strong explosions break it.
        -- Addon armor durability in bullet damage units, independently per
        -- plate. The breaking shot is absorbed before exposing the body.
        Armor = {
            DefaultHealth = 40, Health = {chest = 80, back = 60, pelvis = 50},
            ImpactSound = "physics/metal/metal_solid_impact_bullet2.wav"
        },
        Idle = {"undead_grunt_idle_weapon"},
        Walk = {"undead_skeleton_walk_fwd_a", "undead_skeleton_walk_fwd_b", "undead_skeleton_walk_fwd_c"},
        ArmoredWalk = {"undead_armoured_skeleton_walk_fwd_a", "undead_armoured_skeleton_walk_fwd_b"},
        -- Addon population weights; all variants share the director's skeleton cap.
        Variants = {
            {Class = "npc_dt_za1_skeleton", Weight = 2},
            {Class = "npc_dt_za1_armored_skeleton", Weight = 1},
            {Class = "npc_dt_za1_rotten_skeleton", Weight = 1}
        },
        Melee = {"undead_skeleton_melee_e", "undead_skeleton_melee_f"},
        Turn = {
            Left = {[90] = {"skeleton_idle_turn_l_90"}, [180] = {"skeleton_idle_turn_l_180"}},
            Right = {[90] = {"skeleton_idle_turn_r_90"}, [180] = {"skeleton_idle_turn_r_180"}}
        },
        Emerge = "undead_grunt_emerge_from_ground"
    },
    heavy = {
        Health = 250, MeleeDamage = 40, HeadDamageScale = 2,
        -- Addon damage units. Native plates cover the front and parts of the
        -- back; bullets reaching uncovered flesh damage the zombie directly.
        Armor = {
            DefaultHealth = 100, Health = {chest = 200, back = 140, stomach = 150, helmet = 160},
            ImpactSound = "physics/metal/metal_solid_impact_bullet2.wav"
        },
        Idle = {"undead_grunt_idle_weapon", "undead_grunt_idle_weapon_b", "undead_grunt_idle_weapon_c"},
        Walk = {"heavy_armour_walk_fwd_a", "heavy_armour_walk_fwd_b"},
        Melee = {"heavy_armour_attack_left_arm_a", "heavy_armour_attack_right_arm_a"},
        Flinch = "undead_grunt_flinch_front_chest_a", FlinchBack = "undead_grunt_flinch_back_chest",
        FlinchHead = "undead_elite_flinch_head_small", FlinchCooldown = 2,
        Turn = {
            Left = {[90] = {"heavy_armour_turn_left_90"}, [180] = {"heavy_armour_turn_left_180"}},
            Right = {[90] = {"heavy_armour_turn_right_90"}, [180] = {"heavy_armour_turn_right_180"}}
        },
        Emerge = "undead_grunt_emerge_from_ground"
    },
    suicide = {
        Health = 60, TriggerRange = 72, BlastRadius = 220, BlastDamage = 110,
        -- Extra upward velocity for the detached upper torso, in units/second.
        UpperLaunchSpeed = 400,
        YawRate = 360, DirectInterval = 0.12,
        Idle = {"undead_grunt_idle_weapon"}, Walk = {"undead_grunt_walk_fwd_weapon"},
        Run = {"sniper_st_gn_suicide_sprint", "sniper_st_gn_suicide_sprint_b"},
        Detonate = "sniper_st_gn_suicide_static", DetonateMoving = "sniper_st_gn_suicide",
        Flinch = "undead_grunt_flinch_front_glancing_chest_a",
        Turn = {
            Left = {[90] = {"undead_grunt_idle_turn_l_90"}, [180] = {"undead_grunt_idle_turn_l_180"}},
            Right = {[90] = {"undead_grunt_idle_turn_r_90"}, [180] = {"undead_grunt_idle_turn_r_180"}}
        },
        Emerge = "undead_grunt_emerge_from_ground"
    }
}
