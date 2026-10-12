-- Original Trilogy enemy effects: Undead_Arch_General_SkinSwitch_Flash
return {
    ["Systems"] = {
        ["NativeFlags"] = 76,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 1,
        ["Drain"] = 1,
        ["GroundPlane"] = false,
        ["NativeID"] = 1099190579,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = false,
        ["MaxParticleLife"] = 1,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_SkinSwitch_Flash",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 0,
                ["ParticleDrain"] = 1,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_SkinSwitch_Flash:highlight",
                ["NativeID"] = 1655429933,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/skinswitch_flash/highlight",
                ["Component"] = {
                    ["Flags"] = 3,
                    ["Matrix"] = {0.9999998807907104, 0, 0, 0, 1, 0, 0, 0, 0.9999998807907104},
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {["radius"] = 0.09999992698431015},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["SourceCapacity"] = 5,
                ["Kind"] = "particle",
                ["BlendMode"] = 5,
                ["HostSprite"] = true
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 76,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 1,
        ["Drain"] = 1,
        ["GroundPlane"] = false,
        ["NativeID"] = 1099190579,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = false,
        ["MaxParticleLife"] = 1,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_SkinSwitch_Flash",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 0,
                ["ParticleDrain"] = 1,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_SkinSwitch_Flash:highlight",
                ["NativeID"] = 1655429933,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/skinswitch_flash/highlight",
                ["Component"] = {
                    ["Flags"] = 3,
                    ["Matrix"] = {0.9999998807907104, 0, 0, 0, 1, 0, 0, 0, 0.9999998807907104},
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {["radius"] = 0.09999992698431015},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["SourceCapacity"] = 5,
                ["Kind"] = "particle",
                ["BlendMode"] = 5,
                ["HostSprite"] = true
            }
        }
    },
    ["Sprites"] = {
        {
            ["NativeID"] = 1655429933,
            ["Leader"] = {
                ["Curves"] = {
                    ["0x0"] = {
                        {30.000001907348633, 24.42766761779785, 15.64706039428711, 0},
                        {29.999998092651367, 24.42766761779785, 15.647058486938477, 0.9690067768096924},
                        {30.000001907348633, 24.42766761779785, 15.64706039428711, 0.9710763692855835},
                        {30.000001907348633, 24.42766761779785, 15.64706039428711, 0.940650224685669},
                        {30.000001907348633, 24.42766761779785, 15.64706039428711, 0.8919389247894287},
                        {30.000001907348633, 24.42766761779785, 15.64706039428711, 0.8276736736297607},
                        {30.000001907348633, 24.42766761779785, 15.64706039428711, 0.750585675239563},
                        {30, 24.42766761779785, 15.64706039428711, 0.6634060144424438},
                        {30, 24.42766761779785, 15.647059440612793, 0.5688658952713013},
                        {30, 24.42766761779785, 15.647059440612793, 0.46969640254974365},
                        {30, 24.42766761779785, 15.647059440612793, 0.3686287999153137},
                        {30, 24.42766761779785, 15.647059440612793, 0.2683941721916199},
                        {29.999998092651367, 24.42766761779785, 15.647059440612793, 0.17172372341156006},
                        {29.999998092651367, 24.42766761779785, 15.647058486938477, 0.08134859800338745},
                        {29.999996185302734, 24.42766571044922, 15.647058486938477, 0}
                    },
                    ["0x14c"] = {{0, 0, 0}, {0, 0, 0}},
                    ["0x54"] = {{0}, {0}},
                    ["0x130"] = {{0}},
                    ["0x114"] = {{1}},
                    ["0x168"] = {{0}},
                    ["0x1c"] = {{0, 1}},
                    ["0x38"] = {
                        {0.0034785056486725807, 0.0034785056486725807},
                        {0.5660704970359802, 0.5660704970359802},
                        {0.689130425453186, 0.689130425453186},
                        {0.8089478611946106, 0.8089478611946106},
                        {0.9275232553482056, 0.9275232553482056},
                        {1.046857237815857, 1.046857237815857}
                    },
                    ["0x70"] = {{0}}
                },
                ["Atlas"] = {
                    ["FrameBlend"] = true,
                    ["CurveDriven"] = true,
                    ["RuntimeUVLookup"] = "native per-component frames",
                    ["Sequence"] = 0,
                    ["RandomStart"] = false,
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
                    ["Mode"] = 5,
                    ["FrameCurve"] = {{0}, {8}}
                },
                ["Index"] = 0,
                ["BlendMode"] = 5,
                ["GroundPlane"] = false,
                ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_SkinSwitch_Flash:highlight",
                ["Words"] = {
                    ["0xac"] = 45,
                    ["0xa4"] = 15,
                    ["0x98"] = 270,
                    ["0xfc"] = 0.699999988079071,
                    ["0x94"] = 0.20000000298023224,
                    ["0x90"] = 0.25,
                    ["0xf0"] = 0,
                    ["0xf8"] = 0.5,
                    ["0x104"] = 1,
                    ["0x184"] = 0,
                    ["0x10c"] = 0,
                    ["0x9c"] = 0,
                    ["0xf4"] = 0,
                    ["0x108"] = 0,
                    ["0xa8"] = 10,
                    ["0x100"] = 131073,
                    ["0x8c"] = 0.75,
                    ["0xb0"] = 55,
                    ["0xa0"] = 1
                },
                ["NativeID"] = 1655429933,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/skinswitch_flash/highlight",
                ["NoHistory"] = true,
                ["ColorScale"] = 30.000001907348633,
                ["SourceCapacity"] = 5,
                ["Component"] = {
                    ["Flags"] = 3,
                    ["Matrix"] = {0.9999998807907104, 0, 0, 0, 1, 0, 0, 0, 0.9999998807907104},
                    ["Shape"] = 2,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {["radius"] = 0.09999992698431015},
                    ["Delay"] = 0,
                    ["ShapeName"] = "sphere"
                },
                ["Emitter"] = {
                    ["Curves"] = {
                        ["0x0"] = {{0.018127107992768288}},
                        ["0xc4"] = {{0, 0, 0}},
                        ["0x8c"] = {{1}},
                        ["0xfc"] = {{0.25}},
                        ["0xe0"] = {{8.995004653930664}},
                        ["0xa8"] = {{-0.24415254592895508}},
                        ["0x38"] = {{0}},
                        ["0x1c"] = {{0, 0, 0}},
                        ["0x54"] = {{0.021000001579523087, 0.10679307579994202, 0}},
                        ["0x70"] = {{10.407526969909668}}
                    },
                    ["Words"] = {
                        ["0x140"] = 0.30000001192092896,
                        ["0x14c"] = 0,
                        ["0x130"] = 1655429933,
                        ["0x150"] = 100,
                        ["0x160"] = -1,
                        ["0x11c"] = 0,
                        ["0x144"] = 0.20000000298023224,
                        ["0x154"] = 5,
                        ["0x134"] = 0.5,
                        ["0x148"] = 1,
                        ["0x16c"] = 1,
                        ["0x164"] = 1,
                        ["0x158"] = 1,
                        ["0x120"] = 0,
                        ["0x138"] = 0.5,
                        ["0x15c"] = 5,
                        ["0x168"] = 0,
                        ["0x13c"] = 1,
                        ["0x170"] = 65584,
                        ["0x12c"] = 0,
                        ["0x124"] = 0,
                        ["0x118"] = 0,
                        ["0x128"] = 1
                    }
                },
                ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_impact_dust_v2"
            },
            ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_SkinSwitch_Flash:highlight",
            ["Index"] = 0
        }
    }
}
