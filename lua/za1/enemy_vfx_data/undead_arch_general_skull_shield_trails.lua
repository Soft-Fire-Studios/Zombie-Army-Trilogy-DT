-- Original Trilogy enemy effects: Undead_Arch_General_skull_shield_trails
return {
    ["Systems"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 10,
        ["Drain"] = 10,
        ["GroundPlane"] = false,
        ["NativeID"] = 1704601008,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 10,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_skull_shield_trails",
        ["Layers"] = {
            {
                ["NativeID"] = 1696762442,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/skull_shield_trails/deadeye_trail",
                ["Kind"] = "trail",
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {0.9999999403953552, 0, -1.589324938322534e-08, 0, 1, 0, 1.589324938322534e-08, 0, 0.9999999403953552},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_skull_shield_trails:deadeye_trail",
                ["Index"] = 0
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 10,
        ["Drain"] = 10,
        ["GroundPlane"] = false,
        ["NativeID"] = 1704601008,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 10,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_Arch_General_skull_shield_trails",
        ["Layers"] = {
            {
                ["NativeID"] = 1696762442,
                ["Material"] = "zombiearmytrilogy/enemyfx/general/skull_shield_trails/deadeye_trail",
                ["Kind"] = "trail",
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {0.9999999403953552, 0, -1.589324938322534e-08, 0, 1, 0, 1.589324938322534e-08, 0, 0.9999999403953552},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_skull_shield_trails:deadeye_trail",
                ["Index"] = 0
            }
        }
    },
    ["Ribbons"] = {
        {
            ["Component"] = {
                ["Flags"] = 0,
                ["Matrix"] = {0.9999999403953552, 0, -1.589324938322534e-08, 0, 1, 0, 1.589324938322534e-08, 0, 0.9999999403953552},
                ["Shape"] = 0,
                ["Translation"] = {0, 0, 0},
                ["Parameters"] = {},
                ["Delay"] = 0,
                ["ShapeName"] = "point"
            },
            ["Curves"] = {
                ["0x0"] = {{0}, {1}},
                ["0xcc"] = {{1}},
                ["0x104"] = {{1}},
                ["0x28"] = {{0}, {1}},
                ["0x50"] = {{0, 0, 0}},
                ["0xb0"] = {{1, 0.5238741040229797, 0.05882340669631958, 0}, {1, 0.5238741040229797, 0.05882340669631958, 0.08149496465921402}, {1, 0.5238741636276245, 0.05882340669631958, 0}},
                ["0xe8"] = {{0.42402172088623047}, {0.6954846978187561}, {0.5890244245529175}, {0.3254910707473755}, {0.10537204891443253}, {0}}
            },
            ["Index"] = 0,
            ["LeaderCap"] = 32,
            ["Duration"] = 1,
            ["Name"] = "UndeadSS\\Characters\\Undead_Arch_General_skull_shield_trails:deadeye_trail",
            ["Words"] = {
                ["0xac"] = 0,
                ["0x140"] = 1,
                ["0x14c"] = 4128,
                ["0x130"] = 1.75,
                ["0x6c"] = 1,
                ["0x144"] = 100,
                ["0x48"] = 1,
                ["0x134"] = 10,
                ["0x20"] = 1,
                ["0x148"] = 200,
                ["0x24"] = 0,
                ["0x138"] = 30,
                ["0x120"] = 1,
                ["0x4c"] = 0,
                ["0x13c"] = 0,
                ["0x1c"] = 0,
                ["0x12c"] = 1,
                ["0x44"] = 1,
                ["0x124"] = 1,
                ["0x128"] = 10
            },
            ["NativeID"] = 1696762442,
            ["Material"] = "zombiearmytrilogy/enemyfx/general/skull_shield_trails/deadeye_trail",
            ["PointCap"] = 64,
            ["ColorScale"] = 1,
            ["Loop"] = true,
            ["Atlas"] = {
                ["FrameBlend"] = true,
                ["CurveDriven"] = true,
                ["RuntimeUVLookup"] = "native per-component frames",
                ["Sequence"] = 1,
                ["RandomStart"] = true,
                ["Frames"] = {{0, 0, 1, 0.25, 0}, {0, 0.25, 1, 0.5, 0.25}, {0, 0.5, 1, 0.75, 0.5}, {0, 0.75, 1, 1, 0.75}},
                ["Loop"] = true,
                ["RateVariation"] = 1,
                ["Mode"] = 1,
                ["FrameCurve"] = {{0}, {12.000001907348633}}
            },
            ["BlendMode"] = 1,
            ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_explosion_spikes_strip"
        }
    }
}
