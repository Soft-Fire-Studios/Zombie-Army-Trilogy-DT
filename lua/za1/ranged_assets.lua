-- Native gun actions: machine guns spray; the pistol takes one shot.
return {
    ["Actions"] = {
        ["shot"] = {{["Sequence"] = "undead_grunt_shoot_mg_shot_01", ["Start"] = 0.27906976744186046, ["Frames"] = 43, ["End"] = 0.5813953488372093, ["MaxShots"] = 1}},
        ["spray"] = {
            {["Sequence"] = "undead_grunt_shoot_mg_spray_01", ["Start"] = 0.2, ["Frames"] = 60, ["End"] = 0.6, ["MaxShots"] = 6},
            {["Sequence"] = "undead_grunt_shoot_mg_spray_02", ["Start"] = 0.1724137931034483, ["Frames"] = 58, ["End"] = 0.5862068965517241, ["MaxShots"] = 6}
        }
    },
    ["Weapons"] = {
        [17] = {
            ["Loop"] = {"zombiearmytrilogy/weapons/thompson/thompson_fire_loop_01_tp.wav"},
            ["Name"] = "thompson",
            ["Stop"] = {"zombiearmytrilogy/weapons/mp40/mp40_loopend_st_01.wav"},
            ["Action"] = "spray"
        },
        [16] = {
            ["Loop"] = {"zombiearmytrilogy/weapons/mp40/mp40_loop_mn_01.wav"},
            ["Name"] = "mp40",
            ["Stop"] = {
                "zombiearmytrilogy/weapons/mp40/wpn_npc_mp40_fire_end_01.wav",
                "zombiearmytrilogy/weapons/mp40/wpn_npc_mp40_fire_end_02.wav",
                "zombiearmytrilogy/weapons/mp40/wpn_npc_mp40_fire_end_03.wav"
            },
            ["Action"] = "spray"
        },
        [18] = {["Name"] = "luger", ["Single"] = {"zombiearmytrilogy/weapons/pistol02/pistol02_fire_mn_01.wav", "zombiearmytrilogy/weapons/pistol02/pistol02_fire_mn_02.wav"}, ["Action"] = "shot"}
    }
}
