TOOL.Tab="dt_base"
TOOL.Category="ZombieArmy"
TOOL.Name="#tool.za1_spawn_zones.name"
TOOL.ClientConVar={radius="256"}
TOOL.Information={{name="left"},{name="right"},{name="reload"}}
if CLIENT then
    language.Add("tool.za1_spawn_zones.name","Zombie Army Spawn Zones")
    language.Add("tool.za1_spawn_zones.desc","Place spawn zones on the map's navmesh (admin only)")
    language.Add("tool.za1_spawn_zones.left","Place a zone, or resize the zone you are aiming at")
    language.Add("tool.za1_spawn_zones.right","Remove the zone you are aiming at")
    language.Add("tool.za1_spawn_zones.reload","Enable or disable the zone you are aiming at")
end
local function Pick(tool,trace)
    return ZA1.SpawnZones.Pick(trace.StartPos,trace.StartPos+tool:GetOwner():GetAimVector()*8192)
end
function TOOL:LeftClick(trace)
    if not self:GetOwner():IsAdmin() then return false end
    if CLIENT then return true end
    local radius=math.Clamp(self:GetClientNumber("radius"),64,1536)
    local zone=Pick(self,trace)
    if IsValid(zone) then zone:SetZoneRadius(radius);return true end
    if not trace.Hit or trace.HitSky then return false end
    zone=ZA1.SpawnZones.Create(self:GetOwner(),trace.HitPos,radius)
    if not IsValid(zone) then self:GetOwner():ChatPrint("Choose a clear, dry navmesh floor for the zone.");return false end
    undo.Create("Zombie Army spawn zone");undo.AddEntity(zone);undo.SetPlayer(self:GetOwner());undo.Finish()
    self:GetOwner():AddCleanup("za1_spawn_zones",zone)
    return true
end
function TOOL:RightClick(trace)
    if not self:GetOwner():IsAdmin() then return false end
    if CLIENT then return true end
    local zone=Pick(self,trace);if not IsValid(zone) then return false end
    zone:Remove();return true
end
function TOOL:Reload(trace)
    if not self:GetOwner():IsAdmin() then return false end
    if CLIENT then return true end
    local zone=Pick(self,trace);if not IsValid(zone) then return false end
    zone:SetZoneEnabled(not zone:GetZoneEnabled());return true
end
cleanup.Register("za1_spawn_zones")
function TOOL.BuildCPanel(panel)
    panel:Help("Left click: place / resize. Right click: remove. Reload: enable / disable. Zone markers are visible while this tool is selected.")
    panel:NumSlider("Zone radius","za1_spawn_zones_radius",64,1536,0)
    local modes=panel:ComboBox("Director spawn source","za1_director_spawn_mode")
    modes:AddChoice("Random navmesh","0");modes:AddChoice("Prefer zones (random fallback)","1")
    modes:AddChoice("Zones and random","2");modes:AddChoice("Zones only","3")
    -- Send server settings through the same admin-checked channel as Settings.
    modes.OnSelect=function(_,_,_,value) net.Start("ZA1/Setting");net.WriteString("za1_director_spawn_mode");net.WriteFloat(tonumber(value));net.SendToServer() end
    panel:Help("Player distance limits still apply. Specials need cover; common zombies can emerge in view. Save / load is per map and admin only.")
    panel:Button("Save zones for this map","za1_spawn_zones_save")
    panel:Button("Load zones for this map","za1_spawn_zones_load")
    panel:Button("Remove all zones","za1_spawn_zones_clear")
end
