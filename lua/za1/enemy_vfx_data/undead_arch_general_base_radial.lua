-- Original Trilogy enemy effects: Undead_Arch_General_base_radial
return {
    ["Systems"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 2,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 11,
        ["Drain"] = 6,
        ["GroundPlane"] = false,
        ["NativeID"] = 407195804,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 6,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_base_radial",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 5,
                ["ParticleDrain"] = 6,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_base_radial:radial_thick",
                ["NativeID"] = 2790982555,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/base_radial/radial_thick",
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {0.9999997615814209, 0, 0, 0, 1, 0, 0, 0, 0.9999997615814209},
                    ["Shape"] = 0,
                    ["Translation"] = {0, -0.021615339443087578, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["SourceCapacity"] = 128,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 2,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 11,
        ["Drain"] = 6,
        ["GroundPlane"] = false,
        ["NativeID"] = 407195804,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 6,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_base_radial",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 5,
                ["ParticleDrain"] = 6,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_base_radial:radial_thick",
                ["NativeID"] = 2790982555,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/base_radial/radial_thick",
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {0.9999997615814209, 0, 0, 0, 1, 0, 0, 0, 0.9999997615814209},
                    ["Shape"] = 0,
                    ["Translation"] = {0, -0.021615339443087578, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["SourceCapacity"] = 128,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Sprites"] = {
        {
            ["NativeID"] = 2790982555,
            ["Leader"] = {
                ["Curves"] = {
                    ["0x0"] = {
                        {1, 1, 1, 0},
                        {2.6237363815307617, 2.6237363815307617, 2.6237363815307617, 0.33294764161109924},
                        {3.1241002082824707, 3.1241002082824707, 3.1241002082824707, 0.4892939031124115},
                        {3.130188226699829, 3.130188226699829, 3.130188226699829, 0.5682712197303772},
                        {3.041301727294922, 3.041301727294922, 3.041301727294922, 0.6273528337478638},
                        {3, 3, 3, 0.660358190536499},
                        {3, 3, 3, 0.6683624982833862},
                        {3, 3, 3, 0.6592511534690857},
                        {3, 3, 3, 0.6351231336593628},
                        {3.0015106201171875, 3.0015106201171875, 3.0015106201171875, 0.5971190929412842},
                        {3.103947162628174, 3.103947162628174, 3.103947162628174, 0.529785692691803},
                        {3.2169926166534424, 3.2169926166534424, 3.2169926166534424, 0.44262319803237915},
                        {3.1284689903259277, 3.1284689903259277, 3.1284689903259277, 0.34991979598999023},
                        {2.493035078048706, 2.493035078048706, 2.493035078048706, 0.24335765838623047},
                        {1.2776156663894653, 1.2776156663894653, 1.2776156663894653, 0.12199461460113525},
                        {0, 0, 0, 0}
                    },
                    ["0x14c"] = {{0, 0, 0}, {0, 0, 0}},
                    ["0x54"] = {{0}, {0.028000028803944588}},
                    ["0x130"] = {{0}},
                    ["0x114"] = {{1}},
                    ["0x168"] = {{0}},
                    ["0x1c"] = {{0, 1}},
                    ["0x38"] = {
                        {0.6140120029449463, 0.6140120029449463},
                        {0.5880011916160583, 0.5880011916160583},
                        {0.6100102663040161, 0.6100102663040161},
                        {0.7042021155357361, 0.7042021155357361},
                        {0.8448529839515686, 0.8448529839515686},
                        {1.033345103263855, 1.033345103263855},
                        {1.889660120010376, 1.889660120010376}
                    },
                    ["0x70"] = {{0}}
                },
                ["Atlas"] = {
                    ["FrameBlend"] = true,
                    ["CurveDriven"] = true,
                    ["RuntimeUVLookup"] = "native per-component frames",
                    ["Sequence"] = 2,
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
                    ["FrameCurve"] = {{0}, {20}}
                },
                ["Index"] = 0,
                ["BlendMode"] = 1,
                ["GroundPlane"] = false,
                ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_base_radial:radial_thick",
                ["Words"] = {
                    ["0xac"] = 45,
                    ["0xa4"] = 15,
                    ["0x98"] = 0,
                    ["0xfc"] = 0.699999988079071,
                    ["0x94"] = 3,
                    ["0x90"] = 0,
                    ["0xf0"] = 0,
                    ["0xf8"] = 0.5,
                    ["0x104"] = 1,
                    ["0x184"] = 0,
                    ["0x10c"] = 0,
                    ["0x9c"] = 0,
                    ["0xf4"] = 0,
                    ["0x108"] = 0,
                    ["0xa8"] = 10,
                    ["0x100"] = 0,
                    ["0x8c"] = 6,
                    ["0xb0"] = 55,
                    ["0xa0"] = 1
                },
                ["NativeID"] = 2790982555,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/base_radial/radial_thick",
                ["NoHistory"] = true,
                ["ColorScale"] = 3.2169926166534424,
                ["SourceCapacity"] = 128,
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {0.9999997615814209, 0, 0, 0, 1, 0, 0, 0, 0.9999997615814209},
                    ["Shape"] = 0,
                    ["Translation"] = {0, -0.021615339443087578, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["Emitter"] = {
                    ["Curves"] = {
                        ["0x0"] = {{0.8924323916435242}},
                        ["0xc4"] = {{0, 0, 0}},
                        ["0x8c"] = {{1}},
                        ["0xfc"] = {{0}},
                        ["0xe0"] = {{0}, {0.8342876434326172}},
                        ["0xa8"] = {{0}, {0}, {0.01414798479527235}, {0.05947507917881012}, {-0.15606199204921722}, {-0.5206161141395569}, {-0.9028348922729492}},
                        ["0x38"] = {{0}},
                        ["0x1c"] = {{0, 0, 0}},
                        ["0x54"] = {{0, 1, 8.519282914676296e-07}},
                        ["0x70"] = {{26.523944854736328}}
                    },
                    ["Words"] = {
                        ["0x140"] = 0.5,
                        ["0x14c"] = 0,
                        ["0x130"] = 2790982555,
                        ["0x150"] = 100,
                        ["0x160"] = -1,
                        ["0x11c"] = 0,
                        ["0x144"] = 0.20000000298023224,
                        ["0x154"] = 5,
                        ["0x134"] = 5,
                        ["0x148"] = 1,
                        ["0x16c"] = 1,
                        ["0x164"] = 1,
                        ["0x158"] = 1,
                        ["0x120"] = 0,
                        ["0x138"] = 0,
                        ["0x15c"] = 160,
                        ["0x168"] = 0,
                        ["0x13c"] = 1,
                        ["0x170"] = 1168,
                        ["0x12c"] = 0,
                        ["0x124"] = 0,
                        ["0x118"] = 0,
                        ["0x128"] = 1
                    }
                },
                ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_smoke_black"
            },
            ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_base_radial:radial_thick",
            ["Index"] = 0
        }
    }
}
