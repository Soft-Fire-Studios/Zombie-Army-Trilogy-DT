-- Health, melee damage and named resistance profiles come from Trilogy BLUE.
-- Fire's action timers, co-op waves and target bands come from its original AXBT.
-- Shared population limits and retained player attacks adapt those actions to Source.
-- Evidence: audit/native-combat.md and audit/fire-general-native-followup.md.
return {
    Director = {Chance = 15, SkeletonLimit = 4, SuicideLimit = 2, HeavyLimit = 2,
        FireLimit = 1, ChainsawLimit = 1, SummonerLimit = 1, BurningLimit = 6,
        Weights = {skeleton = 6, suicide = 3, heavy = 3, fire = 1, burning = 3, chainsaw = 1, summoner = 1}},
    Summoning = {PerTick = 1, BudgetMS = .35, MinRadius = 96, MaxRadius = 320, Attempts = 12},
    Effects = {Burning = "Undead_burnt_grunt_glowing_smoke", Fireball = "Undead_Fire_Demon_Fireball",
        FireballImpact = "Undead_Fire_Demon_Fireball_Explosion"},
    Projectiles = {Limit = 12, Lifetime = 3, Tick = .03, Hull = 4},
    fire = {
        Health = 500, MeleeDamage = 25, FlinchCooldown = 2,
        Resistance = {Bullet = 1, AIBullet = .4, Explosion = 1, Fire = 0},
        Idle = {"fire_demon_idle_a", "fire_demon_idle_b"},
        Walk = {"fire_demon_walk_a", "fire_demon_walk_b", "fire_demon_walk_c", "fire_demon_walk_d"},
        Melee = {"fire_demon_attack_a", "fire_demon_right_swipe"},
        MeleeWeights = {.2, .8}, MeleeStartRange = 2 * 39.37007874,
        MeleeHitRange = math.sqrt(6) * 39.37007874, MeleeCooldown = 0,
        Turn = {Left = {[90] = {"fire_demon_turn_left_90"}, [180] = {"fire_demon_turn_left_180"}},
            Right = {[90] = {"fire_demon_turn_right_90"}, [180] = {"fire_demon_turn_right_180"}}},
        Death = "fire_demon_death",
        -- Trilogy remains standing while vulnerable. A surviving blast adds
        -- ZA2's kneeling transition without extending the recovery deadline.
        Recover = "fire_demon_recover_idle_standing",
        RecoverOut = "fire_demon_recover_outro_standing", RestTime = 5, PowerSettle = .1,
        Ignite = "fire_demon_blast_standing",
        RecoveryHits = {Front = "fire_demon_recover_hitf_standing", Back = "fire_demon_recover_hitb_standing",
            Left = "fire_demon_recover_hitl_standing", Right = "fire_demon_recover_hitr_standing"},
        KneelingRecovery = {Into = "fire_demon_blast", Idle = "fire_demon_recover_idle", Out = "fire_demon_recover_outro",
            Hits = {Front = "fire_demon_recover_hitf", Back = "fire_demon_recover_hitb",
                Left = "fire_demon_recover_hitl", Right = "fire_demon_recover_hitr"}},
        Summon = "fire_demon_summon", SummonCooldown = 2, MinionLimit = 100,
        -- Inner/outer placement rings and depletion thresholds, for 1..4 players.
        Waves = {{Inner = 11, Outer = 0, AlivePercent = 45},
            {Inner = 6, Outer = 10, AlivePercent = 35},
            {Inner = 10, Outer = 12, AlivePercent = 40},
            {Inner = 12, Outer = 18, AlivePercent = 45}},
        WaveRadii = {Inner = {2 * 39.37007874, 2.5 * 39.37007874},
            Outer = {4 * 39.37007874, 5 * 39.37007874}},
        ConversionCooldown = 6, FindZombiesInterval = .25,
        -- Native search bands select the nearest living, unlit common in each
        -- band. The projectile branch uses the middle band, not corpses.
        ZombieSearchRadius = 100 * 39.37007874,
        ZombieFireballInner = 13 * 39.37007874, ZombieFireballOuter = 63 * 39.37007874,
        MeleeEncounterRange = 5 * 39.37007874,
        Follow = {Inner = 1 * 39.37007874, Outer = 4 * 39.37007874,
            DesiredMin = 1.9 * 39.37007874, DesiredMax = 3.1 * 39.37007874},
        IgniteTriggerRadius = 5 * 39.37007874, IgniteRadius = 7 * 39.37007874,
        -- These retained actions are disabled in Trilogy's original tree.
        -- Keep the player projectile available as the existing addon feature.
        PlayerFireballEnabled = true, RadialIgniteEnabled = false,
        Fireball = "fire_demon_attack_ranged", FireballRange = 1100, FireballMinRange = 160,
        FireballSpeed = 25 * 39.37007874, FireballDamage = 180,
        FireballGravity = 18 * 39.37007874, FireballSolveGravity = 20 * 39.37007874,
        -- Native flight integrates 18m/s² while the authored launch solve uses
        -- 20m/s². Preserve that bias; player-target damage and impulse are Source tuning.
        PlayerFireballDamage = 35, FireballForce = 500,
        FireballInnerRadius = 3 * 39.37007874, FireballRadius = 9 * 39.37007874, FireballCooldown = 6,
        Emerge = "undead_grunt_emerge_from_ground"
    },
    burning = {
        Health = 1, MeleeDamage = 12, FlinchCooldown = 2,
        Resistance = {Bullet = 1, AIBullet = .4, Explosion = 1, Fire = 0},
        Idle = {"undead_grunt_idle_weapon"},
        Walk = {"fire_zombie_run_fwd_a", "fire_zombie_run_fwd_b", "fire_zombie_run_fwd_c", "fire_zombie_run_fwd_d"},
        Melee = {"undead_grunt_melee_weapon_step_fwd_01", "undead_grunt_melee_weapon_triple_hit"},
        Turn = {Left = {[90] = {"fire_zombie_run_turn_left_90"}, [180] = {"fire_zombie_run_turn_left_180"}},
            Right = {[90] = {"fire_zombie_run_turn_right_90"}, [180] = {"fire_zombie_run_turn_right_180"}}},
        Flinch = "undead_grunt_flinch_front_chest_a", Emerge = "undead_grunt_emerge_from_ground"
    },
    chainsaw = {
        Health = 1000, MeleeDamage = 25, FlinchCooldown = 8,
        Resistance = {Bullet = .05, Pistol = .05, Rifle = .05, MachineGun = .05, AIBullet = .4, Explosion = 1, Fire = 0},
        PainStep = .2, -- Native reactions at 80%, 60%, 40% and 20% health.
        Armor = {DefaultHealth = 300, Health = {}, ImpactSound = "physics/metal/metal_solid_impact_bullet2.wav"},
        Idle = {"undead_elite_chainsaw_idle"}, Walk = {"undead_elite_chainsaw_stalk_fwd"},
        Run = {"undead_elite_chainsaw_stalk_fwd_fast_02"},
        Melee = {"undead_elite_chainsaw_attack_closeattack_01", "undead_elite_chainsaw_attack_closeattack_02", "undead_elite_chainsaw_attack_overhead"},
        Turn = {Left = {[90] = {"undead_chainsaw_elite_idle_turn_l_90"}, [180] = {"undead_chainsaw_elite_idle_turn_l_180"}},
            Right = {[90] = {"undead_chainsaw_elite_idle_turn_r_90"}, [180] = {"undead_chainsaw_elite_idle_turn_r_180"}}},
        Flinch = "undead_elite_chainsaw_flinch_damaged", Death = "undead_elite_chainsaw_death",
        DashTelegraph = "undead_elite_chainsaw_attack_dash_telegraph",
        DashLoop = "undead_elite_chainsaw_attack_dash", DashAttack = "undead_elite_chainsaw_attack_dashattack",
        DashCooldown = 10, DashMinRange = 120, DashMaxRange = 420, HitInterval = .25,
        Emerge = "undead_grunt_emerge_from_ground"
    },
    summoner = {
        Health = 100, MeleeDamage = 0,
        Resistance = {Default = 0, Bullet = 0, Explosion = 1},
        WeakpointResistance = {Bullet = 1},
        Idle = {"summoner_idle"}, Walk = {"undead_grunt_walk_fwd_weapon"}, Melee = {},
        Patient = "summoner_patient_loop",
        Turn = {Left = {[90] = {"undead_grunt_idle_turn_l_90"}, [180] = {"undead_grunt_idle_turn_l_180"}},
            Right = {[90] = {"undead_grunt_idle_turn_r_90"}, [180] = {"undead_grunt_idle_turn_r_180"}}},
        SummonInto = "summoner_summon_into", SummonLoop = "summoner_summon_loop", SummonOut = "summoner_summon_out",
        Death = "summoner_summon_death", SummonCooldown = 14, SummonCount = 3, MinionLimit = 6, ReviveRadius = 600,
        -- Trilogy evidence supports zombie waves and revival. A suicider-only
        -- default is not established; this named pool can be changed freely.
        SpawnPool = {"npc_dt_za1_zombie", "npc_dt_za1_zombie_camo", "npc_dt_za1_zombie_camo2"},
        Emerge = "undead_grunt_emerge_from_ground"
    },
    skeleton = {
        Health = 150, MeleeDamage = 12, ExplosionKillDamage = 25,
        Resistance = {Bullet = .75, Pistol = .65, Rifle = .75, MachineGun = .75, Explosion = 1, Fire = 0},
        -- Bullets must hit the heart. Kicks and strong explosions break it.
        -- Native ITEMS Health, independently per plate. Breaking hits are
        -- absorbed before exposure; penetration is a Source adaptation.
        Armor = {
            DefaultHealth = 200, Health = {},
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
        Health = 150, MeleeDamage = 12,
        Resistance = {Bullet = .2, Pistol = .2, Rifle = .2, MachineGun = .2, Explosion = .6},
        -- Native alternate profile for critical hits. Source maps this to
        -- an exposed head or rear torso; physical plates still intercept first.
        WeakpointResistance = {Bullet = 1, AIBullet = .4},
        Armor = {
            DefaultHealth = 400, Health = {},
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
        Health = 55, TriggerRange = 72, BlastRadius = 220, BlastDamage = 110,
        Resistance = {Bullet = 1, Explosion = .5},
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
