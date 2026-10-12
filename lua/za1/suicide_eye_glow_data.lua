-- Original BLUE eye glows: pixel width/depth, .1-second history and authored red color.
-- Exact source anchors and native consumers are retained in audit/suicide-eye-glow-assets.json.
return {
    ["Kind"] = "suicide",
    ["Model"] = "models/zombiearmytrilogy/undead_suicide_grunt.mdl",
    ["Bone"] = "Bip01 Head",
    ["HeadGroup"] = 1,
    ["IntactHead"] = 0,
    ["Material"] = "zombiearmytrilogy/enemyfx/suicider/nza_persistentglow",
    ["Scale"] = 39.37007874015748,
    ["HistorySeconds"] = 0.10000000149011612,
    ["InitialWidth"] = 65.0,
    ["TerminalWidth"] = 0.0,
    ["Spacing"] = 1.0,
    ["OcclusionTolerance"] = 0.07500000298023224,
    ["Aspect"] = 0.6000000238418579,
    ["Color"] = {1.0, 0.0, 0.0},
    ["Alpha"] = 0.3499999940395355,
    ["Samples"] = 100,
    ["MaxDistance"] = 150,
    ["Eyes"] = {
        {["Name"] = "Left", ["Position"] = {3.732797465018318, -1.377958216617146, 4.12215198933547}, ["WearableID"] = "BA2C73CC"},
        {["Name"] = "Right", ["Position"] = {3.7327979836468126, 1.3779471426525731, 4.122159361290776}, ["WearableID"] = "8BB866F7"}
    }
}
