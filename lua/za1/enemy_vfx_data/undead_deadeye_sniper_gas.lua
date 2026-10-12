-- Original Trilogy enemy effects: Undead_DeadEye_Sniper_gas
return {
    ["Systems"] = {
        ["NativeFlags"] = 70,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 10,
        ["Drain"] = 8,
        ["GroundPlane"] = false,
        ["NativeID"] = 3981031050,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 8,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_DeadEye_Sniper_gas",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 2,
                ["ParticleDrain"] = 8,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_DeadEye_Sniper_gas:steamCloud_S",
                ["NativeID"] = 331970697,
                ["Material"] = "zombiearmytrilogy/enemyfx/deadeye/gas/steamcloud_s",
                ["Component"] = {
                    ["Flags"] = 2,
                    ["Matrix"] = {
                        0.9999995827674866,
                        -1.862645149230957e-09,
                        1.7636921256780624e-08,
                        -1.862645149230957e-09,
                        1,
                        -6.51925802230835e-09,
                        4.7322828322649e-08,
                        -6.51925802230835e-09,
                        0.999999463558197
                    },
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0.0025634765625},
                    ["Parameters"] = {["radius"] = 0.5},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["SourceCapacity"] = 13,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 70,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 10,
        ["Drain"] = 8,
        ["GroundPlane"] = false,
        ["NativeID"] = 3981031050,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 8,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_DeadEye_Sniper_gas",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 2,
                ["ParticleDrain"] = 8,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_DeadEye_Sniper_gas:steamCloud_S",
                ["NativeID"] = 331970697,
                ["Material"] = "zombiearmytrilogy/enemyfx/deadeye/gas/steamcloud_s",
                ["Component"] = {
                    ["Flags"] = 2,
                    ["Matrix"] = {
                        0.9999995827674866,
                        -1.862645149230957e-09,
                        1.7636921256780624e-08,
                        -1.862645149230957e-09,
                        1,
                        -6.51925802230835e-09,
                        4.7322828322649e-08,
                        -6.51925802230835e-09,
                        0.999999463558197
                    },
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0.0025634765625},
                    ["Parameters"] = {["radius"] = 0.5},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["SourceCapacity"] = 13,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Sprites"] = {
        {
            ["NativeID"] = 331970697,
            ["Leader"] = {
                ["Curves"] = {
                    ["0x0"] = {{0, 0, 0, 0}, {0, 0, 0, 0.3426855504512787}, {0, 0, 0, 0.5921355485916138}, {0, 0, 0, 0.5148167014122009}, {0, 0, 0, 0.2624700665473938}, {0, 0, 0, 5.960464477539063e-08}},
                    ["0x14c"] = {{0, 0, 0}, {0, 0, 0}},
                    ["0x54"] = {{0}, {0}},
                    ["0x130"] = {{0}},
                    ["0x114"] = {{1}},
                    ["0x168"] = {{0}},
                    ["0x1c"] = {{0, 1}},
                    ["0x38"] = {{1.6748878955841064, 1.6748878955841064}, {1.9569451808929443, 1.9569451808929443}},
                    ["0x70"] = {{0.14479956030845642}}
                },
                ["Atlas"] = {
                    ["FrameBlend"] = true,
                    ["CurveDriven"] = true,
                    ["RuntimeUVLookup"] = "native per-component frames",
                    ["Sequence"] = 0,
                    ["RandomStart"] = true,
                    ["Frames"] = {
                        {0, 0, 0.25, 0.25, 0},
                        {0.25, 0, 0.5, 0.25, 0.0625},
                        {0.5, 0, 0.75, 0.25, 0.125},
                        {0.75, 0, 1, 0.25, 0.1875},
                        {0, 0.25, 0.25, 0.5, 0.25},
                        {0.25, 0.25, 0.5, 0.5, 0.3125},
                        {0.5, 0.25, 0.75, 0.5, 0.375},
                        {0.75, 0.25, 1, 0.5, 0.4375},
                        {0, 0.5, 0.25, 0.75, 0.5},
                        {0.25, 0.5, 0.5, 0.75, 0.5625},
                        {0.5, 0.5, 0.75, 0.75, 0.625},
                        {0.75, 0.5, 1, 0.75, 0.6875},
                        {0, 0.75, 0.25, 1, 0.75},
                        {0.25, 0.75, 0.5, 1, 0.8125},
                        {0.5, 0.75, 0.75, 1, 0.875},
                        {0.75, 0.75, 1, 1, 0.9375}
                    },
                    ["Loop"] = true,
                    ["RateVariation"] = 1,
                    ["Mode"] = 1,
                    ["FrameCurve"] = {{0}, {6.000000953674316}}
                },
                ["Index"] = 0,
                ["BlendMode"] = 1,
                ["GroundPlane"] = false,
                ["NativeName"] = "UndeadSS\\Characters\\Undead_DeadEye_Sniper_gas:steamCloud_S",
                ["Words"] = {
                    ["0xac"] = 1,
                    ["0xa4"] = 4,
                    ["0x98"] = 0,
                    ["0xfc"] = 0.699999988079071,
                    ["0x94"] = 5,
                    ["0x90"] = 3,
                    ["0xf0"] = 0,
                    ["0xf8"] = 0.5,
                    ["0x104"] = 0.09999999403953552,
                    ["0x184"] = 0,
                    ["0x10c"] = 0,
                    ["0x9c"] = 0,
                    ["0xf4"] = 0,
                    ["0x108"] = 0,
                    ["0xa8"] = 2,
                    ["0x100"] = 1181056,
                    ["0x8c"] = 1,
                    ["0xb0"] = 40,
                    ["0xa0"] = 5
                },
                ["NativeID"] = 331970697,
                ["Material"] = "zombiearmytrilogy/enemyfx/deadeye/gas/steamcloud_s",
                ["NoHistory"] = true,
                ["ColorScale"] = 1,
                ["SourceCapacity"] = 13,
                ["Component"] = {
                    ["Flags"] = 2,
                    ["Matrix"] = {
                        0.9999995827674866,
                        -1.862645149230957e-09,
                        1.7636921256780624e-08,
                        -1.862645149230957e-09,
                        1,
                        -6.51925802230835e-09,
                        4.7322828322649e-08,
                        -6.51925802230835e-09,
                        0.999999463558197
                    },
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0.0025634765625},
                    ["Parameters"] = {["radius"] = 0.5},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["Emitter"] = {
                    ["Curves"] = {
                        ["0x0"] = {{0.53243088722229}},
                        ["0xc4"] = {{0, 0, 0}},
                        ["0x8c"] = {{1}},
                        ["0xfc"] = {{0.5}},
                        ["0xe0"] = {{1}},
                        ["0xa8"] = {{-0.10662086308002472}},
                        ["0x38"] = {{0.28700000047683716}},
                        ["0x1c"] = {{0, 0, 0}},
                        ["0x54"] = {{0.02452101744711399, 0.030112216249108315, 0.024524250999093056}},
                        ["0x70"] = {{5.002523422241211}}
                    },
                    ["Words"] = {
                        ["0x140"] = 0.5,
                        ["0x14c"] = 0,
                        ["0x130"] = 331970697,
                        ["0x150"] = 100,
                        ["0x160"] = -1,
                        ["0x11c"] = 0,
                        ["0x144"] = 1,
                        ["0x154"] = 5,
                        ["0x134"] = 1,
                        ["0x148"] = 1,
                        ["0x16c"] = 1,
                        ["0x164"] = 1,
                        ["0x158"] = 0.15000000596046448,
                        ["0x120"] = 0,
                        ["0x138"] = 0.5,
                        ["0x15c"] = 13,
                        ["0x168"] = 0,
                        ["0x13c"] = 1,
                        ["0x170"] = 5640,
                        ["0x12c"] = 0,
                        ["0x124"] = 0,
                        ["0x118"] = 0,
                        ["0x128"] = 0.09375
                    }
                },
                ["Texture"] = "zombiearmytrilogy/firefx/textures/pfx_flames_short_16flip"
            },
            ["Name"] = "UndeadSS\\Characters\\Undead_DeadEye_Sniper_gas:steamCloud_S",
            ["Index"] = 0
        }
    }
}
