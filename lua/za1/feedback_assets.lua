-- SNPC-PRP provides these systems; no PRP PCFs or materials are bundled.
return {
    ["Particles"] = {"ins_blood_impact_headshot", "horror_bloodsplosion", "doi_muzzleflash_mp40_3p", "doi_muzzleflash_thompson_3p", "doi_muzzleflash_luger_1p", "doi_grenade_explosion"},
    ["Headshot"] = "ins_blood_impact_headshot",
    ["FullGib"] = "horror_bloodsplosion",
    ["Explosion"] = "doi_grenade_explosion",
    ["Muzzles"] = {["mp40"] = "doi_muzzleflash_mp40_3p", ["thompson"] = "doi_muzzleflash_thompson_3p", ["luger"] = "doi_muzzleflash_luger_1p"},
    ["ExplosionSounds"] = {
        {
            ["Volume"] = 0.85,
            ["Name"] = "Grenade_Explosion_Bang",
            ["Files"] = {
                "zombiearmytrilogy/other/explosions/grenade_explosion_bang_01.wav",
                "zombiearmytrilogy/other/explosions/grenade_explosion_bang_02.wav",
                "zombiearmytrilogy/other/explosions/grenade_explosion_bang_03.wav",
                "zombiearmytrilogy/other/explosions/grenade_explosion_bang_04.wav"
            }
        },
        {["Volume"] = 0.6, ["Name"] = "Grenade_Explosion_Bass", ["Files"] = {"zombiearmytrilogy/other/explosions/grenade_explosion_bass_01.wav"}},
        {
            ["Volume"] = 0.35,
            ["Name"] = "Grenade_explosion_ricochet",
            ["Files"] = {
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_01.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_02.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_03.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_04.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_05.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_06.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_07.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_08.wav",
                "zombiearmytrilogy/weapons/bullet_ricochets/bullet_ricochet_a_09.wav"
            }
        }
    }
}
