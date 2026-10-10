-- Both armored actors share shot-only plate checks and breakoff rules.
ZA1.SkeletonArmor = include("za1/armor.lua")(ZA1.SkeletonAssets or include("za1/skeleton_assets.lua"),
    ZA1.SpecialConfig.skeleton.Armor, "ZASkeleton")
return ZA1.SkeletonArmor
