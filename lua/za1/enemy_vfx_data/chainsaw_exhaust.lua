-- Original Trilogy enemy effects: Chainsaw_exhaust
return {
    ["Systems"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 1.5,
        ["Drain"] = 0.5,
        ["GroundPlane"] = false,
        ["NativeID"] = 1491111138,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 0.5,
        ["NativeName"] = "Weapons\\Chainsaw\\Chainsaw_exhaust",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 1,
                ["ParticleDrain"] = 0.5,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "Weapons\\Chainsaw\\Chainsaw_exhaust:chamber_smoke1",
                ["NativeID"] = 1306902011,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/exhaust/chamber_smoke1",
                ["Component"] = {
                    ["Flags"] = 2,
                    ["Matrix"] = {0.9999998807907104, 0, 0, -2.9802322387695312e-08, 1, -4.470348358154297e-08, 0, -5.960464477539063e-08, 1},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["SourceCapacity"] = 7,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Effects"] = {
        ["NativeFlags"] = 2,
        ["SourceStopPolicy"] = "stop emission recursively; drain for MaxParticleLife; clear on owner removal",
        ["Duration"] = 1,
        ["StopOnStateEnd"] = true,
        ["MaxLife"] = 1.5,
        ["Drain"] = 0.5,
        ["GroundPlane"] = false,
        ["NativeID"] = 1491111138,
        ["NativeLightingSuppressed"] = false,
        ["Loop"] = true,
        ["MaxParticleLife"] = 0.5,
        ["NativeName"] = "Weapons\\Chainsaw\\Chainsaw_exhaust",
        ["Layers"] = {
            {
                ["EmissionEnd"] = 1,
                ["ParticleDrain"] = 0.5,
                ["Index"] = 0,
                ["Renderer"] = "client_native_sprite",
                ["Name"] = "Weapons\\Chainsaw\\Chainsaw_exhaust:chamber_smoke1",
                ["NativeID"] = 1306902011,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/exhaust/chamber_smoke1",
                ["Component"] = {
                    ["Flags"] = 2,
                    ["Matrix"] = {0.9999998807907104, 0, 0, -2.9802322387695312e-08, 1, -4.470348358154297e-08, 0, -5.960464477539063e-08, 1},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["SourceCapacity"] = 7,
                ["Kind"] = "particle",
                ["BlendMode"] = 1,
                ["HostSprite"] = true
            }
        }
    },
    ["Sprites"] = {
        {
            ["NativeID"] = 1306902011,
            ["Leader"] = {
                ["Curves"] = {
                    ["0x0"] = {
                        {0.07843132317066193, 0.07843132317066193, 0.07843132317066193, 0.03199676424264908},
                        {0.07843132317066193, 0.07843132317066193, 0.07843132317066193, 0.26579374074935913},
                        {0.07843132317066193, 0.07843132317066193, 0.07843132317066193, 0.27807819843292236},
                        {0.07843132317066193, 0.07843132317066193, 0.07843132317066193, 0.2006123811006546},
                        {0.07843133062124252, 0.07843133062124252, 0.07843133062124252, 0}
                    },
                    ["0x14c"] = {{0, 0, 0}, {0, 0, 0}},
                    ["0x54"] = {{0}, {0}},
                    ["0x130"] = {{0}},
                    ["0x114"] = {{1}},
                    ["0x168"] = {{0}},
                    ["0x1c"] = {{0, 1}},
                    ["0x38"] = {{0.03199988603591919, 0.03199988603591919}, {0.14628243446350098, 0.14628243446350098}},
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
                    ["Mode"] = 1,
                    ["FrameCurve"] = {{0}, {1}}
                },
                ["Index"] = 0,
                ["BlendMode"] = 1,
                ["GroundPlane"] = false,
                ["NativeName"] = "Weapons\\Chainsaw\\Chainsaw_exhaust:chamber_smoke1",
                ["Words"] = {
                    ["0xac"] = 100,
                    ["0xa4"] = 1,
                    ["0x98"] = 0,
                    ["0xfc"] = 0.699999988079071,
                    ["0x94"] = 0.10000000149011612,
                    ["0x90"] = 0.09999999403953552,
                    ["0xf0"] = 0,
                    ["0xf8"] = 0.5,
                    ["0x104"] = 0.44999995827674866,
                    ["0x184"] = 0,
                    ["0x10c"] = 0,
                    ["0x9c"] = 0,
                    ["0xf4"] = 0,
                    ["0x108"] = 0,
                    ["0xa8"] = 0.5,
                    ["0x100"] = 131072,
                    ["0x8c"] = 0.4000000059604645,
                    ["0xb0"] = 200,
                    ["0xa0"] = 1
                },
                ["NativeID"] = 1306902011,
                ["Material"] = "zombiearmytrilogy/enemyfx/chainsaw/exhaust/chamber_smoke1",
                ["NoHistory"] = true,
                ["ColorScale"] = 1,
                ["SourceCapacity"] = 7,
                ["Component"] = {
                    ["Flags"] = 2,
                    ["Matrix"] = {0.9999998807907104, 0, 0, -2.9802322387695312e-08, 1, -4.470348358154297e-08, 0, -5.960464477539063e-08, 1},
                    ["Shape"] = 0,
                    ["Translation"] = {0, 0, 0},
                    ["Parameters"] = {},
                    ["Delay"] = 0,
                    ["ShapeName"] = "point"
                },
                ["Emitter"] = {
                    ["Curves"] = {
                        ["0x0"] = {{0}},
                        ["0xc4"] = {{0, 0, 0}},
                        ["0x8c"] = {{1}},
                        ["0xfc"] = {{0}},
                        ["0xe0"] = {{1}},
                        ["0xa8"] = {{-0.0030474811792373657}},
                        ["0x38"] = {{0.3535004258155823}},
                        ["0x1c"] = {{0, 0, 0}},
                        ["0x54"] = {{0.13650000095367432, 0.13650000095367432, 0.13650000095367432}},
                        ["0x70"] = {{12.820652961730957}}
                    },
                    ["Words"] = {
                        ["0x140"] = 1,
                        ["0x14c"] = 0,
                        ["0x130"] = 1306902011,
                        ["0x150"] = 100,
                        ["0x160"] = -1,
                        ["0x11c"] = 0,
                        ["0x144"] = 0.3999999165534973,
                        ["0x154"] = 5,
                        ["0x134"] = 1,
                        ["0x148"] = 1,
                        ["0x16c"] = 1,
                        ["0x164"] = 1,
                        ["0x158"] = 1,
                        ["0x120"] = 0,
                        ["0x138"] = 0.5,
                        ["0x15c"] = 7,
                        ["0x168"] = 0,
                        ["0x13c"] = 1,
                        ["0x170"] = 5120,
                        ["0x12c"] = 0,
                        ["0x124"] = 0,
                        ["0x118"] = 0,
                        ["0x128"] = 1
                    }
                },
                ["Texture"] = "zombiearmytrilogy/enemyfx/textures/pfx_smoke_16flip_sm"
            },
            ["Name"] = "Weapons\\Chainsaw\\Chainsaw_exhaust:chamber_smoke1",
            ["Index"] = 0
        }
    }
}
