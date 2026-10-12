-- Original Trilogy enemy effects: Undead_DeadEye_jump_trail
return {
    ["Systems"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 1,
        ["Drain"] = 1,
        ["GroundPlane"] = false,
        ["NativeID"] = 4194312630,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 1,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_DeadEye_jump_trail",
        ["Layers"] = {
            {
                ["NativeID"] = 4236510160,
                ["Material"] = "zombiearmytrilogy/enemyfx/deadeye/jump_trail/deadeye_trail",
                ["Kind"] = "trail",
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {5.960464477539063e-08, -1, 0, 1, 5.960464477539063e-08, 0, 0, 0, 1},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "UndeadSS\\Characters\\Undead_DeadEye_jump_trail:deadeye_trail",
                ["Index"] = 0
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 1,
        ["Drain"] = 1,
        ["GroundPlane"] = false,
        ["NativeID"] = 4194312630,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 1,
        ["NativeName"] = "UndeadSS\\Characters\\Undead_DeadEye_jump_trail",
        ["Layers"] = {
            {
                ["NativeID"] = 4236510160,
                ["Material"] = "zombiearmytrilogy/enemyfx/deadeye/jump_trail/deadeye_trail",
                ["Kind"] = "trail",
                ["Component"] = {
                    ["Flags"] = 0,
                    ["Matrix"] = {5.960464477539063e-08, -1, 0, 1, 5.960464477539063e-08, 0, 0, 0, 1},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["Renderer"] = "client_ordered_history",
                ["Name"] = "UndeadSS\\Characters\\Undead_DeadEye_jump_trail:deadeye_trail",
                ["Index"] = 0
            }
        }
    },
    ["Ribbons"] = {
        {
            ["Component"] = {
                ["Flags"] = 0,
                ["Matrix"] = {5.960464477539063e-08, -1, 0, 1, 5.960464477539063e-08, 0, 0, 0, 1},
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
                ["0xb0"] = {
                    {0, 0, 0, 0},
                    {0.1879435032606125, 0.4061800539493561, 0.27638936042785645, 0.03751812130212784},
                    {0.37775564193725586, 0.604331910610199, 0.43130895495414734, 0.05839931592345238},
                    {0.5592727661132812, 0.5684957504272461, 0.44747257232666016, 0.06249374523758888},
                    {0.7232762575149536, 0.4931032359600067, 0.4368811845779419, 0.05850297957658768},
                    {0.8823528289794922, 0.43598634004592896, 0.43598636984825134, 0}
                },
                ["0xe8"] = {
                    {0.08301673829555511},
                    {3.46256160736084},
                    {3.560786485671997},
                    {3.613131284713745},
                    {3.6239163875579834},
                    {3.5974624156951904},
                    {3.5380897521972656},
                    {3.4501190185546875},
                    {3.3378703594207764},
                    {3.20566463470459},
                    {3.057821750640869},
                    {2.89866304397583},
                    {2.417856216430664},
                    {1.6630576848983765},
                    {0.8149168491363525},
                    {4.76837158203125e-07}
                }
            },
            ["Index"] = 0,
            ["LeaderCap"] = 32,
            ["Duration"] = 1,
            ["Name"] = "UndeadSS\\Characters\\Undead_DeadEye_jump_trail:deadeye_trail",
            ["Words"] = {
                ["0xac"] = 0,
                ["0x140"] = 1,
                ["0x14c"] = 4096,
                ["0x130"] = 0.75,
                ["0x6c"] = 1,
                ["0x144"] = 100,
                ["0x48"] = 1,
                ["0x134"] = 1,
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
            ["NativeID"] = 4236510160,
            ["Material"] = "zombiearmytrilogy/enemyfx/deadeye/jump_trail/deadeye_trail",
            ["PointCap"] = 64,
            ["ColorScale"] = 1,
            ["Loop"] = true,
            ["Atlas"] = {
                ["FrameBlend"] = true,
                ["CurveDriven"] = true,
                ["RuntimeUVLookup"] = "native per-component frames",
                ["Sequence"] = 4,
                ["RandomStart"] = false,
                ["Frames"] = {{0, 0, 1, 0.25, 0}, {0, 0.25, 1, 0.5, 0.25}, {0, 0.5, 1, 0.75, 0.5}, {0, 0.75, 1, 1, 0.75}},
                ["Loop"] = true,
                ["RateVariation"] = 1,
                ["Mode"] = 1,
                ["FrameCurve"] = {{0}, {4}}
            },
            ["BlendMode"] = 1,
            ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_explosion_spikes_strip"
        }
    }
}
