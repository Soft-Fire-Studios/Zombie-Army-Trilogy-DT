AddCSLuaFile()
ZA1 = ZA1 or {}
AddCSLuaFile("za1/assets.lua")
AddCSLuaFile("za1/music.lua")
AddCSLuaFile("za1/performance_client.lua")
ZA1.Assets = include("za1/assets.lua")
AddCSLuaFile("za1/skin_assets.lua")
ZA1.SkinAssets = include("za1/skin_assets.lua")
for _, prop in ipairs(ZA1.Assets.props) do
    local variant = ZA1.SkinAssets[prop.model]
    if variant then prop.model, prop.skin = variant.Model, prop.skin or variant.Skin end
end
AddCSLuaFile("za1/zombie_settings.lua")
ZA1.Config = include("za1/zombie_settings.lua")
AddCSLuaFile("za1/special_settings.lua")
AddCSLuaFile("za1/special_assets.lua")
ZA1.SpecialConfig = include("za1/special_settings.lua")
ZA1.SpecialAssets = include("za1/special_assets.lua")
AddCSLuaFile("za1/skeleton_assets.lua")
ZA1.SkeletonAssets = include("za1/skeleton_assets.lua")
AddCSLuaFile("za1/heavy_assets.lua")
ZA1.HeavyAssets = include("za1/heavy_assets.lua")
ZA1.SpecialAssets.Enemies.heavy = ZA1.HeavyAssets
for file, duration in pairs(ZA1.HeavyAssets.Durations) do ZA1.SpecialAssets.Durations[file] = duration end
AddCSLuaFile("za1/look_assets.lua")
AddCSLuaFile("za1/revival_assets.lua")
ZA1.LookAssets = include("za1/look_assets.lua")
ZA1.RevivalAssets = include("za1/revival_assets.lua")
for sequence,binding in pairs(ZA1.RevivalAssets.animationSounds) do ZA1.Assets.animationSounds[sequence]=binding end
for file,duration in pairs(ZA1.RevivalAssets.soundDurations) do ZA1.Assets.soundDurations[file]=duration end
AddCSLuaFile("za1/equipment_assets.lua")
include("za1/debris.lua")
AddCSLuaFile("za1/doors.lua")
if CLIENT then include("za1/doors.lua") end
include("za1/equipment.lua")
include("za1/dismemberment.lua")
include("za1/feedback.lua")
include("za1/gore.lua")
include("za1/halves.lua")
include("za1/look.lua")
include("za1/presentation.lua")
include("za1/recovery.lua")
include("za1/resurrection_effect.lua")
if SERVER then
    include("za1/impact.lua")
    include("za1/ranged.lua")
    include("za1/awareness.lua")
    include("za1/navigation.lua")
    include("za1/doors.lua")
    include("za1/crowd.lua")
    include("za1/motion.lua")
    include("za1/population.lua")
    include("za1/spawn_zones.lua")
    include("za1/obstacles.lua")
    include("za1/corpse_charges.lua")
    include("za1/skeleton_armor.lua")
    include("za1/heavy_armor.lua")
    include("za1/specials.lua")
    include("za1/performance.lua")
else
    local replicated = {
        za1_director_running="1", za1_population_cap="100",
        za1_director_initial_density=tostring(ZA1.Config.Director.InitialDensity),
        za1_director_density_per_minute=tostring(ZA1.Config.Director.DensityPerMinute),
        za1_director_radius="3200", za1_recycle_delay="10", za1_dormancy="1",
        za1_director_spawn_min_radius=tostring(ZA1.Config.Population.SpawnMinDistance),
        za1_director_visible_commons=ZA1.Config.Population.VisibleCommonSpawns and "1" or "0",
        za1_director_spawn_mode="0",za1_resurrection="1",za1_resurrection_chance=tostring(ZA1.Config.Recovery.ResurrectionChance*100),
        za1_mantle="1",za1_mantle_height=tostring(ZA1.Config.Obstacles.MantleMaxHeight),
        za1_wander="1", za1_alert_range="600", za1_event_sound_distance="1400",
        za1_ragdoll_lifetime="45", za1_ragdoll_cap="24", za1_crowd="1",
        za1_shared_routes="1", za1_path_budget="2", za1_path_burst="8",
        za1_specials="1", za1_special_chance=tostring(ZA1.SpecialConfig.Director.Chance),
        za1_skeleton_limit=tostring(ZA1.SpecialConfig.Director.SkeletonLimit), za1_suicide_limit=tostring(ZA1.SpecialConfig.Director.SuicideLimit),
        za1_heavy_limit=tostring(ZA1.SpecialConfig.Director.HeavyLimit)
    }
    for name, value in pairs(replicated) do
        CreateConVar(name, value, FCVAR_REPLICATED)
    end
    include("za1/music.lua")
    include("za1/performance_client.lua")
end

if CLIENT then
    hook.Add("AddToolMenuCategories", "ZA1/SettingsCategory", function()
        spawnmenu.AddToolCategory("dt_base", "ZombieArmy", "Zombie Army")
    end)
    hook.Add("PopulateToolMenu", "ZA1/Settings", function()
        spawnmenu.AddToolMenuOption("dt_base", "ZombieArmy", "ZA1Settings", "Settings", "", "", function(panel)
            panel:Help("Spawn the invisible Zombie Army Director from DT Base > Zombie Army Trilogy. Maps need a navmesh. Undo removes the director and its horde.")
            local function setting(name, value)
                timer.Create("ZA1/Setting/" .. name, 0.12, 1, function()
                    net.Start("ZA1/Setting"); net.WriteString(name); net.WriteFloat(value); net.SendToServer()
                end)
            end
            local function checkbox(label, name)
                local control = vgui.Create("DCheckBoxLabel", panel)
                control:SetText(label); control:SetValue(GetConVar(name):GetBool()); control:SetEnabled(LocalPlayer():IsAdmin())
                control.OnChange = function(_, value) setting(name, value and 1 or 0) end
                panel:AddItem(control)
            end
            local function slider(label, name, low, high)
                local control = vgui.Create("DNumSlider", panel)
                control:SetText(label); control:SetMinMax(low, high); control:SetDecimals(0)
                control:SetValue(GetConVar(name):GetFloat()); control:SetEnabled(LocalPlayer():IsAdmin())
                control.OnValueChanged = function(_, value) setting(name, value) end
                panel:AddItem(control)
            end
            panel:Help("Director settings (admin only)")
            checkbox("Director running", "za1_director_running")
            slider("Common zombie limit", "za1_population_cap", 8, 100)
            slider("Starting horde density", "za1_director_initial_density", 0, 100)
            slider("Density increase per minute", "za1_director_density_per_minute", 0, 100)
            panel:Help("Density is the director's population target, capped by the limit above. Set growth to 0 for a fixed target. Each additional living player adds 4. Changes adjust spawning without removing existing zombies.")
            slider("Minimum spawn radius", "za1_director_spawn_min_radius", 128, 8192)
            slider("Maximum spawn / player radius", "za1_director_radius", 960, 8192)
            checkbox("Common zombies can emerge in view", "za1_director_visible_commons")
            local source=vgui.Create("DComboBox",panel)
            source:SetValue("Spawn source");source:SetEnabled(LocalPlayer():IsAdmin())
            for id,label in ipairs({"Random navmesh", "Prefer zones (random fallback)", "Zones and random", "Zones only"}) do
                source:AddChoice(label,id-1,GetConVar("za1_director_spawn_mode"):GetInt()==id-1)
            end
            source.OnSelect=function(_,_,_,value) setting("za1_director_spawn_mode",value) end;panel:AddItem(source)
            panel:Help("Use the Spawn Zones tool to place, disable, save and load zones for this map. All sources respect player radii, navmesh and clear space.")
            panel:Help("Spawns stay outside the minimum distance from every living player and inside the maximum radius of a living player. Specials emerge out of sight. The maximum radius also controls distant recycling.")
            checkbox("Recycle distant unseen zombies", "za1_dormancy")
            slider("Unseen retirement delay (seconds)", "za1_recycle_delay", 3, 60)
            checkbox("Director spawns special enemies", "za1_specials")
            slider("Special spawn chance (%)", "za1_special_chance", 0, 50)
            slider("Skeleton limit", "za1_skeleton_limit", 0, 12)
            slider("Suicide Grunt limit", "za1_suicide_limit", 0, 6)
            slider("Armored Heavy limit", "za1_heavy_limit", 0, 6)
            panel:Help("Zombie settings (admin only)")
            checkbox("Zombies wander", "za1_wander")
            checkbox("Allow resurrection", "za1_resurrection")
            slider("Resurrection chance (%)", "za1_resurrection_chance", 0, 100)
            checkbox("Allow mantling", "za1_mantle")
            slider("Maximum mantle height", "za1_mantle_height", 32, 160)
            slider("Nearby alert distance", "za1_alert_range", 128, 1500)
            slider("Animation sound distance (0 = unlimited)", "za1_event_sound_distance", 0, 4096)
            slider("Ragdoll lifetime (seconds)", "za1_ragdoll_lifetime", 10, 180)
            slider("Ragdoll cap", "za1_ragdoll_cap", 0, 64)
            panel:Help("Horde performance (admin only)")
            checkbox("Crowd spacing and attack positions", "za1_crowd")
            checkbox("Shared horde routes", "za1_shared_routes")
            slider("Normal path builds per tick", "za1_path_budget", 1, 8)
            slider("Backlog path builds per tick", "za1_path_burst", 1, 16)
            panel:Help("Music and HUD (personal settings)")
            panel:CheckBox("Dynamic music", "za1_music")
            panel:CheckBox("Show horde density bar", "za1_horde_hud")
            panel:CheckBox("Head gibs and dropped equipment", "za1_debris")
            panel:CheckBox("Gun and explosion lights", "za1_effect_lights")
            panel:NumSlider("Particle and light distance", "za1_effect_distance", 256, 8192, 0)
            panel:NumSlider("Debris limit", "za1_debris_cap", 0, 96, 0)
            panel:NumSlider("Dropped equipment lifetime", "za1_debris_lifetime", 2, 60, 0)
            panel:NumSlider("Music volume", "za1_music_volume", 0, 1, 2)
            local themes = panel:ComboBox("Music theme", "za1_music_theme")
            themes:AddChoice("Random Trilogy theme", "0")
            for id,label in SortedPairs(ZA1.Assets.themes) do themes:AddChoice(label,tostring(id)) end
            panel:Help("Named Trilogy arrangements blend synchronized stems with horde intensity.")
        end)
    end)
    hook.Add("PopulatePropMenu", "ZA1/Props", function()
        spawnmenu.AddContentType("za1_model", function(container, object)
            local icon = spawnmenu.CreateContentIcon("model", container, object)
            if IsValid(icon) then icon:SetTooltip(object.name) end
            return icon
        end)
        local categories = {Headwear = {}, Equipment = {}, Weapons = {}, Miscellaneous = {}}
        for _, prop in ipairs(ZA1.Assets.props) do
            local n = prop.name
            local category = n:find("helmet") or n:find("hat") or n:find("cap_")
            local gear = n:find("pouch") or n:find("belt") or n:find("backpack") or n:find("webbing") or n:find("gasmask") or n:find("armour") or n:find("armor")
            local weapon = n:find("rifle") or n:find("pistol") or n:find("grenade") or n:find("ammo") or n:find("gun") or n:find("magazine") or n:find("clip") or n:find("weapon") or n:find("sword")
            local list = categories[category and "Headwear" or gear and "Equipment" or weapon and "Weapons" or "Miscellaneous"]
            list[#list + 1] = {type = "za1_model", name = prop.name, model = prop.model, skin = prop.skin or 0}
        end
        spawnmenu.AddPropCategory("za1", "Zombie Army Trilogy", {}, "icon16/box.png", 829810)
        for index, name in ipairs({"Headwear", "Equipment", "Weapons", "Miscellaneous"}) do
            spawnmenu.AddPropCategory("za1_" .. name, name, categories[name], "icon16/box.png", 829810 + index, 829810)
        end
    end)
end
