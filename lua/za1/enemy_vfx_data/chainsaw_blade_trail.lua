-- Original Trilogy enemy effects: Chainsaw_blade_trail
return {
    ["Systems"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 0.20000000298023224,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 0.5,
        ["Drain"] = 0.5,
        ["GroundPlane"] = false,
        ["NativeID"] = 830541527,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 0.5,
        ["NativeName"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail",
        ["Layers"] = {
            {
                ["NativeID"] = 866485091,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/blade_trail/trail_lines",
                ["Kind"] = "trail",
                ["Component"] = {["Flags"] = 0, ["Matrix"] = {1, 0, 0, 0, 1, 0, 0, 0, 1}, ["Shape"] = 0, ["Translation"] = {0, 0, 0}, ["Parameters"] = {}, ["Delay"] = 0, ["ShapeName"] = "point"},
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail:trail_lines",
                ["Index"] = 0
            },
            {
                ["NativeID"] = 4045677737,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/blade_trail/trail_glow",
                ["Kind"] = "trail",
                ["Component"] = {["Flags"] = 0, ["Matrix"] = {1, 0, 0, 0, 1, 0, 0, 0, 1}, ["Shape"] = 0, ["Translation"] = {0, 0, 0}, ["Parameters"] = {}, ["Delay"] = 0, ["ShapeName"] = "point"},
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail:trail_glow",
                ["Index"] = 1
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 0.20000000298023224,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 0.5,
        ["Drain"] = 0.5,
        ["GroundPlane"] = false,
        ["NativeID"] = 830541527,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 0.5,
        ["NativeName"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail",
        ["Layers"] = {
            {
                ["NativeID"] = 866485091,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/blade_trail/trail_lines",
                ["Kind"] = "trail",
                ["Component"] = {["Flags"] = 0, ["Matrix"] = {1, 0, 0, 0, 1, 0, 0, 0, 1}, ["Shape"] = 0, ["Translation"] = {0, 0, 0}, ["Parameters"] = {}, ["Delay"] = 0, ["ShapeName"] = "point"},
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail:trail_lines",
                ["Index"] = 0
            },
            {
                ["NativeID"] = 4045677737,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/blade_trail/trail_glow",
                ["Kind"] = "trail",
                ["Component"] = {["Flags"] = 0, ["Matrix"] = {1, 0, 0, 0, 1, 0, 0, 0, 1}, ["Shape"] = 0, ["Translation"] = {0, 0, 0}, ["Parameters"] = {}, ["Delay"] = 0, ["ShapeName"] = "point"},
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail:trail_glow",
                ["Index"] = 1
            }
        }
    },
    ["Ribbons"] = {
        {
            ["Component"] = {["Flags"] = 0, ["Matrix"] = {1, 0, 0, 0, 1, 0, 0, 0, 1}, ["Shape"] = 0, ["Translation"] = {0, 0, 0}, ["Parameters"] = {}, ["Delay"] = 0, ["ShapeName"] = "point"},
            ["Curves"] = {
                ["0x0"] = {{0}, {1}},
                ["0xcc"] = {{0.9691429138183594}},
                ["0x104"] = {{1}},
                ["0x28"] = {{0}, {1}},
                ["0x50"] = {{0, 0, 0}},
                ["0xb0"] = {
                    {1.000000238418579, 1.000000238418579, 1.000000238418579, 1},
                    {1.000000238418579, 1.000000238418579, 1.000000238418579, 0.9993338584899902},
                    {1.0000003576278687, 1.0000003576278687, 1.0000003576278687, 0.4668174982070923},
                    {1.0000003576278687, 1.0000003576278687, 1.0000003576278687, 0}
                },
                ["0xe8"] = {{0}, {0.4423182010650635}, {0.5046195387840271}, {0.521090030670166}, {0.516963005065918}, {0.49360764026641846}, {0.4426500201225281}, {5.960464477539063e-08}}
            },
            ["Index"] = 0,
            ["LeaderCap"] = 32,
            ["Duration"] = 0.20000000298023224,
            ["Name"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail:trail_lines",
            ["Words"] = {
                ["0xac"] = 0.30000001192092896,
                ["0x140"] = 1,
                ["0x14c"] = 53248,
                ["0x130"] = 0.5,
                ["0x6c"] = 1,
                ["0x144"] = 100,
                ["0x48"] = 1,
                ["0x134"] = 0.20000000298023224,
                ["0x20"] = 1,
                ["0x148"] = 200,
                ["0x24"] = 0,
                ["0x138"] = 40,
                ["0x120"] = 1,
                ["0x4c"] = 0,
                ["0x13c"] = 0,
                ["0x1c"] = 0,
                ["0x12c"] = 0.009999999776482582,
                ["0x44"] = 1,
                ["0x124"] = 1,
                ["0x128"] = 1
            },
            ["NativeID"] = 866485091,
            ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/blade_trail/trail_lines",
            ["PointCap"] = 64,
            ["ColorScale"] = 1.0000003576278687,
            ["Loop"] = true,
            ["Atlas"] = {
                ["FrameBlend"] = false,
                ["CurveDriven"] = false,
                ["RuntimeUVLookup"] = "native per-component frames",
                ["Sequence"] = 0,
                ["RandomStart"] = false,
                ["Frames"] = {{0, 0, 1, 1, 0}},
                ["Loop"] = false,
                ["RateVariation"] = 1,
                ["Mode"] = 11,
                ["FrameCurve"] = {{0}, {1}}
            },
            ["BlendMode"] = 11,
            ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_heathaze_trail"
        },
        {
            ["Component"] = {["Flags"] = 0, ["Matrix"] = {1, 0, 0, 0, 1, 0, 0, 0, 1}, ["Shape"] = 0, ["Translation"] = {0, 0, 0}, ["Parameters"] = {}, ["Delay"] = 0, ["ShapeName"] = "point"},
            ["Curves"] = {
                ["0x0"] = {{0}, {1}},
                ["0xcc"] = {{0.016466623172163963}, {0.01646662876009941}},
                ["0x104"] = {{1}},
                ["0x28"] = {{0}, {1}},
                ["0x50"] = {{0, 0, 0}},
                ["0xb0"] = {{1.000000238418579, 1.000000238418579, 1.000000238418579, 1}},
                ["0xe8"] = {{0}, {0.7544307708740234}, {0.8606936931610107}, {0.8887861967086792}, {0.8817469477653503}, {0.8419114351272583}, {0.7549965381622314}, {0}}
            },
            ["Index"] = 1,
            ["LeaderCap"] = 32,
            ["Duration"] = 0.20000000298023224,
            ["Name"] = "Weapons\\Chainsaw\\Chainsaw_blade_trail:trail_glow",
            ["Words"] = {
                ["0xac"] = 1.4901161193847656e-08,
                ["0x140"] = 1,
                ["0x14c"] = 53248,
                ["0x130"] = 0.5,
                ["0x6c"] = 1,
                ["0x144"] = 100,
                ["0x48"] = 1,
                ["0x134"] = 0.20000000298023224,
                ["0x20"] = 1,
                ["0x148"] = 200,
                ["0x24"] = 0,
                ["0x138"] = 40,
                ["0x120"] = 1,
                ["0x4c"] = 0,
                ["0x13c"] = 0,
                ["0x1c"] = 0,
                ["0x12c"] = 0.009999999776482582,
                ["0x44"] = 1,
                ["0x124"] = 1,
                ["0x128"] = 1
            },
            ["NativeID"] = 4045677737,
            ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/blade_trail/trail_glow",
            ["PointCap"] = 64,
            ["ColorScale"] = 1.000000238418579,
            ["Loop"] = true,
            ["Atlas"] = {
                ["FrameBlend"] = false,
                ["CurveDriven"] = false,
                ["RuntimeUVLookup"] = "native per-component frames",
                ["Sequence"] = 5,
                ["RandomStart"] = false,
                ["Frames"] = {{0, 0, 1, 0.25, 0}},
                ["Loop"] = false,
                ["RateVariation"] = 1,
                ["Mode"] = 1,
                ["FrameCurve"] = {{0}, {9.60006046295166}}
            },
            ["BlendMode"] = 1,
            ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_explosion_spikes_strip"
        }
    }
}
