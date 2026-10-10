-- Map-local zones. Candidate selection remains inside the director's budget.
local Z={Zones={},Cursor=0,Limit=64};ZA1.SpawnZones=Z
local N,P,M=ZA1.Navigation,ZA1.Population,ZA1.Manager
function Z.Register(zone)
    for _,other in ipairs(Z.Zones) do if other==zone then return end end
    Z.Zones[#Z.Zones+1]=zone
end
function Z.Remove(zone)
    for index=#Z.Zones,1,-1 do if Z.Zones[index]==zone or not IsValid(Z.Zones[index]) then table.remove(Z.Zones,index) end end
end
function Z.Contains(zone,pos)
    local center=zone:GetPos();local delta=pos-center
    return math.abs(delta.z)<=48 and delta:Length2DSqr()<=zone:GetZoneRadius()^2
end
function Z.Candidate(players,minimum,maximum)
    for checked=1,math.min(#Z.Zones,8) do
        if #Z.Zones==0 then return end
        Z.Cursor=Z.Cursor%#Z.Zones+1
        local zone=Z.Zones[Z.Cursor]
        if not IsValid(zone) then Z.Remove(zone)
        elseif zone:GetZoneEnabled() then
            local center,radius=zone:GetPos(),zone:GetZoneRadius()
            local nearby=false
            for _,ply in ipairs(players) do
                local distance=center:Distance(ply:GetPos())
                if distance-radius<=maximum and distance+radius>=minimum then nearby=true;break end
            end
            if nearby then
                local angle=math.Rand(0,math.pi*2);local distance=math.sqrt(math.Rand(0,1))*radius
                local sample=center+Vector(math.cos(angle)*distance,math.sin(angle)*distance,0)
                local area=N.Area(sample)
                if IsValid(area) and not area:IsBlocked() and not area:IsUnderwater() then
                    local pos=area:GetClosestPointOnArea(sample)
                    if area:Contains(pos) and Z.Contains(zone,pos) then return area,pos,zone end
                end
            end
        end
    end
end
function Z.Create(ply,pos,radius,enabled)
    if not IsValid(ply) or not ply:IsAdmin() or #Z.Zones>=Z.Limit or not navmesh.IsLoaded() then return end
    local area=N.Area(pos)
    if not IsValid(area) or area:IsBlocked() or area:IsUnderwater() then return end
    local point=area:GetClosestPointOnArea(pos)
    if point:DistToSqr(pos)>64^2 then return end
    local ground=P.ClearGround(point)
    if not ground or not area:Contains(ground) or math.abs(ground.z-point.z)>N.Profile().step then return end
    local zone=ents.Create("sent_za1_spawn_zone")
    if not IsValid(zone) then return end
    zone:SetPos(ground);zone:SetZoneRadius(math.Clamp(radius,64,1536));zone:SetZoneEnabled(enabled~=false)
    zone:Spawn();zone:Activate();Z.Register(zone)
    return zone
end
function Z.Pick(start,finish)
    local delta=finish-start;local length=delta:LengthSqr()
    if length==0 then return end
    local chosen,distance
    for _,zone in ipairs(Z.Zones) do if IsValid(zone) then
        local center=zone:GetPos()+Vector(0,0,16)
        local t=math.Clamp((center-start):Dot(delta)/length,0,1)
        local square=center:DistToSqr(start+delta*t)
        if square<=48^2 and (not distance or t<distance) then chosen,distance=zone,t end
    end end
    return chosen
end
local function Path() return "za1/spawn-zones/"..game.GetMap():gsub("[^%w_-]","_")..".json" end
local function Admin(ply) return IsValid(ply) and ply:IsAdmin() end
concommand.Add("za1_spawn_zones_save",function(ply)
    if not Admin(ply) then return end
    local rows={}
    for _,zone in ipairs(Z.Zones) do if IsValid(zone) then
        local p=zone:GetPos();rows[#rows+1]={position={p.x,p.y,p.z},radius=zone:GetZoneRadius(),enabled=zone:GetZoneEnabled()}
    end end
    file.CreateDir("za1/spawn-zones");file.Write(Path(),util.TableToJSON({version=1,zones=rows},true))
    ply:ChatPrint("Saved "..#rows.." Zombie Army spawn zones for "..game.GetMap()..".")
end)
concommand.Add("za1_spawn_zones_load",function(ply)
    if not Admin(ply) then return end
    local data=util.JSONToTable(file.Read(Path(),"DATA") or "")
    if not data or data.version~=1 or not istable(data.zones) then ply:ChatPrint("No valid spawn-zone save for this map.");return end
    -- Validate the complete save before replacing any current zones.
    if #data.zones>Z.Limit then return end
    for _,row in ipairs(data.zones) do
        if not istable(row) or not istable(row.position) or #row.position~=3 or not isnumber(row.radius) or row.radius~=row.radius then return end
        for _,v in ipairs(row.position) do if not isnumber(v) or v~=v or math.abs(v)>32768 then return end end
    end
    for index=#Z.Zones,1,-1 do local zone=Z.Zones[index];if IsValid(zone) then zone:Remove() end end
    Z.Zones={};local count=0
    for _,row in ipairs(data.zones) do
        if Z.Create(ply,Vector(unpack(row.position)),row.radius,row.enabled) then count=count+1 end
    end
    ply:ChatPrint("Loaded "..count.." valid Zombie Army spawn zones.")
end)
concommand.Add("za1_spawn_zones_clear",function(ply)
    if not Admin(ply) then return end
    for index=#Z.Zones,1,-1 do local zone=Z.Zones[index];if IsValid(zone) then zone:Remove() end end
    Z.Zones={}
end)
hook.Add("PostCleanupMap","ZA1/SpawnZones",function() Z.Zones={};Z.Cursor=0 end)
