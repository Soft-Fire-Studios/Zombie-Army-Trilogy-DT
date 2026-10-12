-- Original Trilogy enemy effects: Undead_Arch_General_core_regen
return {
    ["Systems"] = {
        ["NativeFlags"] = 10,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 2.5,
        ["Drain"] = 1.5,
        ["GroundPlane"] = false,
        ["NativeID"] = 1725963374,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 1.5,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_core_regen",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 1,
                ["ParticleDrain"] = 1.5,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_core_regen:source",
                ["NativeID"] = 662929575,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/core_regen/source",
                ["Component"] = {
                    ["Flags"] = 3,
                    ["Matrix"] = {0.9999998807907104, 0, 0, 0, 1, 0, 0, 0, 0.9999998807907104},
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {["radius"] = 5.499997138977051},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["SourceCapacity"] = 50,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 10,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 2.5,
        ["Drain"] = 1.5,
        ["GroundPlane"] = false,
        ["NativeID"] = 1725963374,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 1.5,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_core_regen",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 1,
                ["ParticleDrain"] = 1.5,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_core_regen:source",
                ["NativeID"] = 662929575,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/core_regen/source",
                ["Component"] = {
                    ["Flags"] = 3,
                    ["Matrix"] = {0.9999998807907104, 0, 0, 0, 1, 0, 0, 0, 0.9999998807907104},
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {["radius"] = 5.499997138977051},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["SourceCapacity"] = 50,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Sprites"] = {
        {
            ["NativeID"] = 662929575,
            ["Leader"] = {
                ["Curves"] = {
                    ["0x0"] = {
                        {0.9999999403953552, 0.809688150882721, 0.5098040699958801, 0},
                        {1, 0.8096880912780762, 0.5098040699958801, 0.08907710015773773},
                        {1.0000001192092896, 0.8096879720687866, 0.5098041296005249, 0}
                    },
                    ["0x14c"] = {{0, 0, 0}, {0, 0, 0}},
                    ["0x54"] = {
                        {0},
                        {0.0022222225088626146},
                        {0.008888889104127884},
                        {0.019999999552965164},
                        {0.03555556386709213},
                        {0.0555555522441864},
                        {0.07999999821186066},
                        {0.10888887941837311},
                        {0.14222222566604614},
                        {0.18000000715255737},
                        {0.222222238779068},
                        {0.2688888907432556},
                        {0.3199999928474426},
                        {0.37555551528930664},
                        {0.43555551767349243},
                        {0.5}
                    },
                    ["0x130"] = {{0}},
                    ["0x114"] = {{1}},
                    ["0x168"] = {{0}},
                    ["0x1c"] = {{0, 1}},
                    ["0x38"] = {{0, 0}, {0.36914288997650146, 0.36914288997650146}},
                    ["0x70"] = {{0}}
                },
                ["Atlas"] = {
                    ["FrameBlend"] = true,
                    ["CurveDriven"] = true,
                    ["RuntimeUVLookup"] = "native per-component frames",
                    ["Sequence"] = 1,
                    ["RandomStart"] = true,
                    ["Frames"] = {
                        {0, 0, 0.5, 0.125, 0},
                        {0.5, 0, 1, 0.125, 0.0625},
                        {0, 0.125, 0.5, 0.25, 0.125},
                        {0.5, 0.125, 1, 0.25, 0.1875},
                        {0, 0.25, 0.5, 0.375, 0.25},
                        {0.5, 0.25, 1, 0.375, 0.3125},
                        {0, 0.375, 0.5, 0.5, 0.375},
                        {0.5, 0.375, 1, 0.5, 0.4375},
                        {0, 0.5, 0.5, 0.625, 0.5},
                        {0.5, 0.5, 1, 0.625, 0.5625},
                        {0, 0.625, 0.5, 0.75, 0.625},
                        {0.5, 0.625, 1, 0.75, 0.6875},
                        {0, 0.75, 0.5, 0.875, 0.75},
                        {0.5, 0.75, 1, 0.875, 0.8125},
                        {0, 0.875, 0.5, 1, 0.875},
                        {0.5, 0.875, 1, 1, 0.9375}
                    },
                    ["Loop"] = true,
                    ["RateVariation"] = 1,
                    ["Mode"] = 1,
                    ["FrameCurve"] = {{0}, {16}}
                },
                ["Index"] = 0,
                ["BlendMode"] = 1,
                ["GroundPlane"] = false,
                ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_core_regen:source",
                ["Words"] = {
                    ["0xac"] = 100,
                    ["0xa4"] = 1,
                    ["0x98"] = 0,
                    ["0xfc"] = 0.699999988079071,
                    ["0x94"] = 0.75,
                    ["0x90"] = 0,
                    ["0xf0"] = 0,
                    ["0xf8"] = 0.5,
                    ["0x104"] = 0,
                    ["0x184"] = 0,
                    ["0x10c"] = 0,
                    ["0x9c"] = 0,
                    ["0xf4"] = 0,
                    ["0x108"] = 0,
                    ["0xa8"] = 0.5,
                    ["0x100"] = 2,
                    ["0x8c"] = 1.5,
                    ["0xb0"] = 200,
                    ["0xa0"] = 1
                },
                ["NativeID"] = 662929575,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/core_regen/source",
                ["NoHistory"] = true,
                ["ColorScale"] = 1.0000001192092896,
                ["SourceCapacity"] = 50,
                ["Component"] = {
                    ["Flags"] = 3,
                    ["Matrix"] = {0.9999998807907104, 0, 0, 0, 1, 0, 0, 0, 0.9999998807907104},
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {["radius"] = 5.499997138977051},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["Emitter"] = {
                    ["Curves"] = {
                        ["0x0"] = {{0}},
                        ["0xc4"] = {{0, 0, 0}},
                        ["0x8c"] = {{1}},
                        ["0xfc"] = {{0}},
                        ["0xe0"] = {{1}},
                        ["0xa8"] = {{19.817798614501953}, {5.988279342651367}, {3.9293320178985596}, {3.323404312133789}, {2.7301721572875977}},
                        ["0x38"] = {{0}},
                        ["0x1c"] = {{0, 0, 0}},
                        ["0x54"] = {{0, 0, 0}},
                        ["0x70"] = {{33.054359436035156}}
                    },
                    ["Words"] = {
                        ["0x140"] = 1,
                        ["0x14c"] = 0,
                        ["0x130"] = 662929575,
                        ["0x150"] = 100,
                        ["0x160"] = -1,
                        ["0x11c"] = 0,
                        ["0x144"] = 1,
                        ["0x154"] = 5,
                        ["0x134"] = 1,
                        ["0x148"] = 1,
                        ["0x16c"] = 1,
                        ["0x164"] = 1,
                        ["0x158"] = 1,
                        ["0x120"] = 0,
                        ["0x138"] = 0.5,
                        ["0x15c"] = 50,
                        ["0x168"] = 0,
                        ["0x13c"] = 1,
                        ["0x170"] = 2064,
                        ["0x12c"] = 0,
                        ["0x124"] = 0,
                        ["0x118"] = 0,
                        ["0x128"] = 0
                    }
                },
                ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_flame_long_16flip"
            },
            ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_core_regen:source",
            ["Index"] = 0
        }
    }
}
