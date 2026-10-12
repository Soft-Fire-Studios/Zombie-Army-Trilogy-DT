-- Native weapon cadence, ammunition, firing waits and AI rules are recorded
-- in audit/. Metres are converted to Source units. Map admission limits,
-- physical aim tolerance and possession controls are Source adaptations.
-- Edit these tables rather than the action implementation.
local sniperJumpMax, sniperHeightMax = 4000, 3000
-- Sight/firing use twice the common zombie's 1,800-unit sight range.
-- Jump searches separately cover the complete elevated landing envelope.
local sniperSightRange = 3600
local sniperSearchRadius = math.ceil(math.sqrt(sniperJumpMax ^ 2 + sniperHeightMax ^ 2))
return {
    sniper = {
        Health = 100, MeleeDamage = 12, FlinchCooldown = 3,
        Resistance = {Bullet = 1, Explosion = 1},
        Idle = {"za1_sniper_idle"}, Walk = {"za1_sniper_walk"}, Melee = {},
        Turn = {Left = {[90] = {"sniper_st_idle_turn_l_90_rf"}, [180] = {"sniper_st_idle_turn_l_180_rf"}},
            Right = {[90] = {"sniper_st_idle_turn_r_90_rf"}, [180] = {"sniper_st_idle_turn_r_180_rf"}}},
        Emerge = "undead_grunt_emerge_from_ground",
        -- Deadeye's scoped-AI flag selects a five-second post-ready wait.
        -- Normal difficulty telegraphs for .75 seconds; pose convergence is
        -- checked separately and does not add another fixed aim delay.
        SightRange = sniperSightRange,
        Gun = {Damage = 50, Range = sniperSightRange, MinRange = 180, Interval = 1 / 1.5, Magazine = 10, InitialAmmo = 7,
            AimTime = 0, Telegraph = .75, PostShotWait = 5, ChamberAfterShot = false,
            GlintInterval = 15, GlintDuration = .75,
            TelegraphByDifficulty = {Easy = 1.25, Medium = .75, Hard = .25, Dev = 1},
            HitChance = 50, AccuracyDistance = 250 * 39.37007874,
            AccuracyCurve = {2.07598614692688, 1.1510684490203857, 1.0730222463607788, 1.0459178686141968,
                1.041189193725586, 1.0317041873931885, .9680666923522949, .5535964965820312},
            InitialMisses = 2, InitialMissRange = 50 * 39.37007874,
            MissRadius = 2.5 * 39.37007874, MissPropChance = 74, MissWorldChance = 80, MissPropCooldown = 5,
            UnseenMissPropChance = 75, UnseenMissPropCooldown = 4,
            AimTolerance = 6, Spread = .004, BurstMin = 1, BurstMax = 1,
            BurstPause = 5, AimPhaseRate = 1.5, RaiseRate = 5, Tick = .05},
        -- Native scene-point distances are 100m search, 30m preferred and
        -- 10m minimum. Prefer 200-3000 units above the target, then the
        -- sniper's current level. Search is also bounded by one direct jump.
        -- All distances below are Source units; the work budget is shared.
        Point = {SearchRadius = sniperSearchRadius,
            TargetMinDistance = 10 * 39.37007874, TargetPreferredDistance = 30 * 39.37007874,
            TargetMaxDistance = sniperSightRange, PreferHigherThanTarget = true,
            TargetHeightMin = 200, TargetHeightMax = sniperHeightMax,
            BudgetMS = .35, AreasPerTick = 32, CandidateChecksPerTick = 2, Candidates = 32,
            FailureCooldown = 6, FailureLimit = 32, ProofLifetime = 2},
        -- The original owns special jump links, not a 720-unit jump cap.
        -- 2000-4000 horizontal units and these height bounds are editable Source
        -- admission limits. The authored 3s clip/70% landing clock stay intact.
        Jump = {Cooldown = 12, ThreatRange = 300, SearchRadius = sniperJumpMax, MinDistance = 2000,
            MaxRise = sniperHeightMax, MaxDrop = 96, Segments = 12,
            SearchInterval = 2, RecentDamage = 2, SegmentsPerTick = 4},
        PointSearchRadius = sniperSearchRadius, PreferredThreatRange = 30 * 39.37007874,
        MinThreatRange = 10 * 39.37007874, CloseThreatRange = 1 * 39.37007874,
        ThreatMemory = 2, ReloadReentryWait = 2,
        PointShotsMin = 3, PointShotsMax = 5, IdleRelocateMin = 7, IdleRelocateMax = 15,
        LostSightGrace = 6, GrenadeRange = 15 * 39.37007874, GrenadeScanInterval = .25
    },
    mg42 = {
        Health = 1000, MeleeDamage = 25, PainStep = .2,
        Resistance = {Bullet = .05, Pistol = .05, Rifle = .05, MachineGun = .05,
            AIBullet = .4, Explosion = 1, Fire = 0},
        Armor = {DefaultHealth = 100, Health = {}, ImpactSound = "physics/metal/metal_solid_impact_bullet2.wav"},
        Idle = {"za1_mg42_idle"}, Walk = {"za1_mg42_walk"}, Melee = {"undead_elite_melee_a"},
        -- Forced native health reactions use Arms, then Head at 20 percent.
        -- Source plays the complete authored clip; native partial bone masks
        -- have not been established. Each health stage is consumed once.
        Flinches = {[80] = "undead_elite_flinch_botharms", [60] = "undead_elite_flinch_onearm_short",
            [40] = "undead_elite_flinch_onearm", [20] = "undead_elite_flinch_head_small",
            [100] = "undead_elite_flinch_head_small"},
        Death = "undead_elite_death", RagdollTime = 3.833333 * .53,
        Turn = {Left = {[90] = {"sniper_st_idle_turn_l_90_rf"}, [180] = {"sniper_st_idle_turn_l_180_rf"}},
            Right = {[90] = {"sniper_st_idle_turn_r_90_rf"}, [180] = {"sniper_st_idle_turn_r_180_rf"}}},
        Emerge = "undead_grunt_emerge_from_ground",
        MeleeRange = 1.5 * 39.37007874, FollowFireMinRange = 1 * 39.37007874,
        Gun = {Damage = 35, Range = 50 * 39.37007874, MinRange = 1 * 39.37007874, Interval = .1, Magazine = 32,
            AimTime = .3, AimTolerance = 10, Spread = .022, BurstMin = 2, BurstMax = 10,
            BurstPause = .5, BurstPauseMin = .5, BurstPauseMax = 4,
            AimPhaseRate = 1.5, RaiseRate = 5, Tick = .05}
    },
    general = {
        Health = 30, CoopHealth = {30, 300, 650, 1000}, MeleeDamage = 0,
        Resistance = {Default = 0, Bullet = 0, Explosion = 0, Fire = 0},
        Idle = {"arch_general_idle"}, Walk = {"arch_general_idle_stationary"}, Melee = {},
        Emerge = "arch_general_emerge", MinionLimit = 100,
        -- Original coffin_sinkback prefab's demonic-ring controller delay.
        -- Source presents its ring at this actor's floor origin during defeat.
        RetreatRingDelay = 3.5,
        -- Native stages, wave counts and recharge timers live in general_assets.
        -- LVL02 uses these four marker paths. Source anchors their assembly to
        -- the authored core socket because arbitrary maps have no mission rigs.
        Shield = {Paths = {"Skull_Attachment_P1", "Skull_Attachment_P2",
            "Skull_Attachment_P4", "Skull_Attachment_P6"}, Anchor = "Core",
            Scene = "envs\\Undead\\NZA3_LVL02\\M00_NZA3_LVL02.pc",
            SkullHealth = 1, Tick = .03, Phases = 3},
        Sequences = {Idle = "arch_general_idle", Enter = "arch_general_emerge",
            CastInto = "arch_general_resurrect_into", CastLoop = "arch_general_resurrect_loop",
            CastOut = "arch_general_resurrect_exit", Interrupted = "arch_general_resurrect_interrupted",
            BreakInto = "arch_general_flinch_shield_destroyed_p1", BreakLoop = "arch_general_flinch_shield_destroyed_p2",
            RechargeInto = "arch_general_flinch_shield_destroyed_to_recharge", Recharge = "arch_general_flinch_shield_recharge",
            RestoredFlash = "arch_general_idle_stationary",
            Restored = "arch_general_flinch_shield_restored",
            HitLeft = "arch_general_flinch_shield_charging_left", HitRight = "arch_general_flinch_shield_charging_right"}
    }
}
