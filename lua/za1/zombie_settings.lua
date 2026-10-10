-- Shared by all three soldier variants. Distances are Source units,
-- angles are degrees, and delays are seconds. Animation speed comes from
-- each model sequence's walkframes, not a separate movement-speed setting.
return {
    Audio = {
        VocalVolume = 0.5, BreathVolume = 0.5,
        EventDistance = 1400, EventDistanceInterval = 0.25,
        -- Addon play/silence weights; native event probabilities are unverified.
        VocalEvents = {
            Undead_Vox_Random_Low = {Chance = 0.18, MinDelay = 6, MaxDelay = 12},
            Undead_Vox_Turn = {Chance = 0.35, MinDelay = 3, MaxDelay = 6}
        }
    },
    Director = {
        MaxCommon = 100, InitialDensity = 12, DensityPerMinute = 12,
        ThinkInterval = 0.5, SpawnMinDelay = 1.5, SpawnMaxDelay = 3,
        BuildupGroup = 2, PeakGroup = 4,
        BuildupDuration = 20, PeakMinDuration = 25, PeakMaxDuration = 40,
        RestMinDuration = 6, RestMaxDuration = 10, RestEarlyExit = 4,
        ReliefCooldown = 25, RestFraction = 0.25, RestMaximum = 12,
        RestMinimum = 4 -- Keep commons arriving during relief, including after a wipe.
    },
    Equipment = {
        HeadwearBodygroup = 4,
        WeaponBodygroup = 5,
        -- Compiled bodygroup order follows native Grunt held-weapon variants.
        Weapons = {"stump", "bent_metal", "bent_metal_b", "bone", "bone_b", "bone_c",
            "broken_bottle", "hammer", "meathook", "metal_bracket", "plank",
            "short_plank", "shovel", "torch", "wrench", "mp40", "thompson", "luger"}
    },
    Melee = {
        StartRange = 55, -- Leave room for the swipe's small backward root motion.
        Range = 60,
        FacingAngle = 35, -- Half-angle: target must be this close to forward.
        HullWidth = 12,
        HullHeight = 20,
        Damage = 20,
        UnarmedDamage = 12,
        Cooldown = 0.4
    },
    Turning = {
        StartAngle = 70, -- Smaller corrections use locomotion instead of a 90-degree clip.
        StationarySpeed = 10,
        RetargetAngle = 45, -- Stop an old turn when the target changes direction.
        Cooldown = 0.35
    },
    Doors = {
        Enabled = true, Health = 100, Damage = 20,
        ProbeDistance = 160, ProbeInterval = 0.35,
        AttackRange = 60, FacingAngle = 50,
        DebrisLifetime = 12, DebrisCap = 12, KnockSpeed = 180
    },
    Impact = {MinMass = 2, MinSpeed = 180, EnergyPerDamage = 5000, MaxDamage = 200, Cooldown = 0.2},
    Sever = {LimbDamage = 55, ExplosionDamage = 80, AbdomenDamage = 35},
    -- Addon balance; the three authored Trilogy gun actions are occasional.
    Ranged = {MinDistance = 240, MaxDistance = 1400, Chance = 0.35,
        MinCooldown = 8, MaxCooldown = 16,
        FireInterval = 0.12, Damage = 6, Spread = 0.12, Volume = 0.65},
    Lunge = {Chance = 0.35, Cooldown = 6, RetryDelay = 1},
    Navigation = {
        Acceleration = 300,
        Deceleration = 500,
        -- Reach the authored cruise speed quickly; gait phases only pace feet.
        AccelerationTime = 0.1,
        DecelerationTime = 0.1,
        YawRate = 120,
        LookAhead = 64,
        GoalTolerance = 24,
        RepathDistance = 24,
        RepathMinDelay = 0.5,
        RepathMaxDelay = 0.8,
        ArrivalDistance = 40,
        SightInterval = 0.2,
        MemoryDuration = 10,
        StepHeight = 18,
        PathBuildsPerTick = 2,
        PathBurstBuildsPerTick = 8, -- Clear backlogs while native paths are cheap.
        PathBurstQueueAge = 0.1,
        PathBudgetMS = 1.5,
        PathSearchMS = 1.25,
        PathCostCallsPerBuild = 512,
        BoundedRetryDelay = 0.25,
        FailedRouteLifetime = 2,
        FailedRouteLimit = 256,
        RetryDelay = 1,
        SharedRouteDistance = 256,
        SharedRouteHops = 6,
        FlowNodesPerTick = 192,
        GraphAreasPerTick = 48,
        FlowBudgetMS = 0.8,
        FlowCacheSize = 12,
        FlowLifetime = 6, -- Evict unused routes; active routes retain their settled areas.
        FlowDemandLifetime = 2,
        FlowBlockedChecksPerTick = 4, -- Refresh a route when an excluded area reopens.
        StuckDelay = 1.5,
        RecoveryDistance = 48,
        -- Direct movement is checked in the shared queue, never every Think.
        DirectMovement = true,
        DirectInterval = 0.4,
        DirectChecksPerTick = 4,
        DirectBudgetMS = 0.5,
        DirectAreasPerCheck = 32,
        DirectEdgesPerCheck = 96
    },
    Obstacles = {
        Interval = 0.25, ChecksPerTick = 3, BudgetMS = 0.6,
        ProbeDistance = 120, Clearance = 8, MaxDetour = 320,
        RouteLifetime = 3, RetryDelay = 0.75,
        MantleEnabled = true, MantleMaxHeight = 128, MantleMinHeight = 32,
        MantleReach = 120, MantleCooldown = 2,
        Mantle = {"undead_grunt_mantle_coast_2m_01", "undead_grunt_mantle_coast_2m_01_part2"}
    },
    Performance = {
        NearDistance = 900,
        FarDistance = 2200,
        NearDecisionInterval = 0.1,
        MediumDecisionInterval = 0.25,
        FarDecisionInterval = 0.6,
        MediumSightInterval = 0.4,
        FarSightInterval = 0.9,
        SightTracesPerTick = 8,
        GridInterval = 0.25,
        HearingTracesPerTick = 4,
        HearingBudgetMS = 0.5,
        HearingLifetime = 2
    },
    Crowd = {
        CellSize = 128,
        UpdateInterval = 0.15,
        NeighborRadius = 72,
        MaxCandidates = 24,
        MaxNeighbors = 8,
        SeparationDistance = 32,
        SteeringDistance = 12,
        ProbeInterval = 0.3,
        ProbesPerTick = 4,
        AttackSlots = 8,
        AttackRadius = 48,
        WaitingRadius = 96,
        SlotLifetime = 2,
        TargetRefreshDistance = 16,
        YieldDuration = 0.35
    },
    Population = {
        SpawnMinDistance = 750,
        SpawnMaxDistance = 3200,
        VisibleCommonSpawns = true, -- Commons emerge from the ground in view.
        WakeDistance = 3200,
        SleepDistance = 4500, -- Hysteresis keeps actors from being repeatedly retired/restored.
        SleepDelay = 10,
        RecentDamageProtection = 12,
        MaxDormant = 100,
        ChangesPerTick = 2,
        ChecksPerTick = 8,
        SpawnCandidates = 8,
        CandidateLifetime = 4,
        CandidateAreasPerTick = 128,
        CandidateScanBudgetMS = 0.5,
        WorkBudgetMS = 2
    },
    Wander = {Radius = 450, MinDelay = 7, MaxDelay = 14, Duration = 7, Tries = 8},
    Gore = {CrunchVolume = 0.75, SplatVolume = 0.8, HitCooldown = 0.1, Bursts = 2},
    Look = {Interval = 0.1, Speed = 75}, -- Native look poses supply degrees; this is addon follow speed.
    Recovery = {
        ResurrectionChance = 0.2, -- Addon tuning; the original AI probability is not decoded.
        ResurrectionHealth = 0.45,
        MaxResurrections = 1,
        MinExplosionDamage = 20,
        MinDownTime = 2, MaxDownTime = 4,
        ResurrectionDelay = 4,
        SettleSpeed = 35,
        MaxKnockdownSpeed = 400, -- Added speed in Source units/s, distributed across the whole ragdoll.
        MaxDownTimeLimit = 10,
        MaxActiveRagdolls = 8,
        GroundRetries = 3
    },
    Flinch = {MinDamage = 10, Cooldown = 1.5},
    Animations = {
        Emerge = {"undead_grunt_emerge_from_ground"},
        -- Pick one idle and one walk at spawn; do not reroll every AI tick.
        Idle = {
            "undead_grunt_idle_weapon",
            "undead_grunt_idle_weapon_b",
            "undead_grunt_idle_weapon_c"
        },
        Walk = {
            "undead_grunt_walk_fwd_weapon",
            "undead_grunt_walk_fwd_weapon_b",
            "undead_grunt_walk_fwd_weapon_c",
            "undead_grunt_walk_fwd_weapon_d",
            "undead_grunt_walk_fwd_weapon_e",
            "undead_grunt_walk_fwd_weapon_f",
            "undead_grunt_walk_fwd_weapon_g",
            "undead_grunt_walk_fwd_weapon_h",
            "undead_grunt_walk_fwd_weapon_i",
            "undead_grunt_walk_fwd_weapon_j",
            "undead_grunt_walk_fwd_weapon_k",
            "undead_grunt_walk_fwd_weapon_l",
            "undead_grunt_walk_fwd_weapon_m",
            "undead_grunt_walk_fwd_weapon_n",
            "undead_grunt_walk_fwd_weapon_o",
            "undead_grunt_walk_fwd_weapon_p",
            "undead_grunt_walk_fwd_weapon_q",
            "undead_grunt_walk_fwd_weapon_r"
        },
        Melee = {
            "undead_grunt_single_swipe_right_a",
            "undead_grunt_single_swipe_right_b",
            "undead_grunt_overhead_swipe_a"
        },
        -- Existing compiled hit-marker cycles. Reach/travel are read from the
        -- model's walkframes; these attacks do not increase damage reach.
        Lunge = {
            {Sequence = "undead_grunt_melee_weapon_step_fwd_01", Hits = {15 / 51}},
            {Sequence = "undead_grunt_lunge_attack_short_a", Hits = {21 / 36}},
            {Sequence = "undead_grunt_lunge_attack_short_b", Hits = {14 / 80, 32 / 80}},
            {Sequence = "undead_grunt_lunge_attack_long_a", Hits = {25 / 90}},
            {Sequence = "undead_grunt_lunge_attack_long_b", Hits = {24 / 113, 50 / 113}},
            {Sequence = "undead_grunt_lunge_attack_long_c", Hits = {24 / 105, 61 / 105}},
            {Sequence = "undead_grunt_lunge_attack_long_d", Hits = {14 / 78, 52 / 78}},
            {Sequence = "undead_grunt_melee_weapon_pounce_4m_no_buildup", Hits = {16 / 44}}
        },
        Turn = {
            Left = {
                [90] = {"undead_grunt_idle_turn_l_90", "undead_grunt_idle_turn_l_90_b", "undead_grunt_idle_turn_l_90_c"},
                [180] = {"undead_grunt_idle_turn_l_180", "undead_grunt_idle_turn_l_180_b", "undead_grunt_idle_turn_l_180_c"}
            },
            Right = {
                [90] = {"undead_grunt_idle_turn_r_90", "undead_grunt_idle_turn_r_90_b", "undead_grunt_idle_turn_r_90_c"},
                [180] = {"undead_grunt_idle_turn_r_180", "undead_grunt_idle_turn_r_180_b", "undead_grunt_idle_turn_r_180_c"}
            }
        },
        Flinch = {
            [HITGROUP_HEAD] = "undead_grunt_flinch_front_glancing_chest_b",
            [HITGROUP_CHEST] = "undead_grunt_flinch_front_glancing_chest_a",
            [HITGROUP_STOMACH] = "undead_grunt_flinch_front_glancing_chest_c",
            [HITGROUP_LEFTARM] = "undead_grunt_flinch_front_glancing_shoulder_left",
            [HITGROUP_RIGHTARM] = "undead_grunt_flinch_front_glancing_shoulder_right",
            [HITGROUP_LEFTLEG] = "undead_grunt_flinch_front_glancing_legs",
            [HITGROUP_RIGHTLEG] = "undead_grunt_flinch_front_glancing_legs_b"
        }
    }
}
