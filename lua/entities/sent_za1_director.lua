AddCSLuaFile()
ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName = "Zombie Army Director"
ENT.Category = "Zombie Army Trilogy"
ENT.Spawnable = false -- Registered in DT Base's NPC menu, not the Entities tab.
ENT.AdminOnly = true
function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "HordeSize")
    self:NetworkVar("Int", 1, "ThreatLevel")
    self:NetworkVar("Int", 2, "HordePhase")
    self:NetworkVar("Int", 3, "DensityTarget")
    self:NetworkVar("Int", 4, "PopulationLimit")
    self:NetworkVar("Float", 0, "Intensity")
    self:NetworkVar("Float", 1, "PlayerRadius")
    self:NetworkVar("Bool", 0, "Running")
end
if DT_Base then
    local entry = {Name = ENT.PrintName, Category = ENT.Category, AdminOnly = true, NoDrop = true, Class = "sent_za1_director"}
    list.Set("DT/NextBots", entry.Class, entry)
    list.Set("NPC", entry.Class, entry)
end
if CLIENT then
    local hud = CreateClientConVar("za1_horde_hud", "1", true, false, "Show Zombie Army horde density.")
    local background, border = Color(16, 18, 20, 220), Color(215, 215, 210, 100)
    local textColor = Color(235, 235, 225)
    local low, medium, high = Color(110, 145, 90), Color(195, 155, 65), Color(175, 60, 45)
    local phases = {[1] = "BUILDING", [2] = "SURGE", [3] = "LULL"}
    function ENT:Draw() end
    function ENT:DrawTranslucent() end
    function ENT:Initialize()
        local shown, lastCount, lastLimit, caption = 0, nil, nil, ""
        hook.Add("HUDPaint", self, function(director)
            if not hud:GetBool() then return end
            local limit = math.max(director:GetPopulationLimit(), 1)
            local count = math.max(director:GetHordeSize(), 0)
            local ratio = math.Clamp(count / limit, 0, 1)
            shown = math.Approach(shown, ratio, FrameTime() * 0.5)
            if lastCount ~= count or lastLimit ~= limit then
                lastCount, lastLimit = count, limit
                caption = "HORDE DENSITY  " .. count .. " / " .. limit
            end
            local width, y = math.min(ScrW() * 0.36, 520), 24
            local x, fill = (ScrW() - width) / 2, ratio > 0.75 and high or ratio > 0.4 and medium or low
            draw.SimpleText(caption, "DermaDefaultBold", x, y, textColor)
            draw.SimpleText(director:GetRunning() and (phases[director:GetHordePhase()] or "BUILDING") or "PAUSED",
                "DermaDefaultBold", x + width, y, textColor, TEXT_ALIGN_RIGHT)
            surface.SetDrawColor(background); surface.DrawRect(x, y + 19, width, 12)
            surface.SetDrawColor(fill); surface.DrawRect(x + 1, y + 20, (width - 2) * shown, 10)
            surface.SetDrawColor(border); surface.DrawOutlinedRect(x, y + 19, width, 12)
            local target = math.Clamp(director:GetDensityTarget() / limit, 0, 1)
            surface.SetDrawColor(textColor); surface.DrawRect(x + 1 + (width - 3) * target, y + 18, 1, 14)
        end)
    end
    function ENT:OnRemove() hook.Remove("HUDPaint", self) end
    return
end
local M, P, C = ZA1.Manager, ZA1.Population, ZA1.Config.Director
function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end
function ENT:Initialize()
    if not DT_Base or IsValid(M.Director) then self:Remove(); return end
    M.Director = self
    self:SetMoveType(MOVETYPE_NONE); self:SetSolid(SOLID_NONE)
    self.ZARunningSetting = M.DirectorEnabled:GetBool()
    self:SetRunning(self.ZARunningSetting)
    self:SetThreatLevel(1); self:SetHordeSize(M.Count()); self:SetIntensity(0)
    self:SetHordePhase(1); self:SetPopulationLimit(M.PopulationLimit()); self:SetPlayerRadius(M.Radius:GetFloat())
    self.ZAOwned = {}; self.ZAKills = 0; self.ZAKillRequirement = 15
    P.Setup(self); ZA1.Navigation.Begin()
    self.ZAElapsed, self.ZALastThink = 0, CurTime()
    self.ZAPhase, self.ZAPhaseEnd = "buildup", C.BuildupDuration
    self.ZANextSpawn, self.ZAPlayerPressure = CurTime() + 3, 0
    self.ZANextDecay = CurTime() + 120
    self:SetDensityTarget(math.min(M.PopulationLimit(), M.InitialDensity:GetInt()))
    self:CallOnRemove("ZA1/OwnedZombies", function()
        for z in pairs(self.ZAOwned) do if IsValid(z) then z:Remove() end end
        self.ZADormant, self.ZAActors, self.ZASpawnCache = {}, {}, {}
        if M.Director == self then M.Director = nil end
    end)
end
function ENT:RecordKill(z)
    if not self.ZAOwned[z] then return end
    self.ZAOwned[z] = nil
    self.ZAKills = self.ZAKills + 1; self.ZANextDecay = CurTime() + 120
    if self.ZAKills >= self.ZAKillRequirement and self:GetThreatLevel() < 6 then
        self:SetThreatLevel(self:GetThreatLevel() + 1)
        self.ZAKills = 0; self.ZAKillRequirement = self.ZAKillRequirement + 2 * self:GetThreatLevel() + 25
    end
end
function ENT:FindSpawn(players, class, deadline) return P.FindSpawn(self, players, class, deadline) end
function ENT:SpawnZombie(players, deadline)
    if M.Count() >= M.PopulationLimit() then return false end
    deadline = deadline or SysTime() + ZA1.Config.Population.WorkBudgetMS / 1000
    local class = self.ZAPhase ~= "rest" and ZA1.Specials and ZA1.Specials.SelectClass(self) or "npc_dt_za1_zombie"
    local pos, target = self:FindSpawn(players, class, deadline)
    if not pos and class ~= "npc_dt_za1_zombie" and SysTime() < deadline then
        class = "npc_dt_za1_zombie"; pos, target = self:FindSpawn(players, class, deadline)
    end
    if not pos or not IsValid(target) then return false end
    local z = ents.Create(class)
    if not IsValid(z) then return false end
    z.ZAEmerge = ZA1.Specials and ZA1.Specials.Emerge(class) or ZA1.Config.Animations.Emerge[math.random(#ZA1.Config.Animations.Emerge)]
    z:SetPos(pos); z:SetAngles(Angle(0, math.random(0, 359), 0)); z:Spawn()
    if not IsValid(z) then return false end
    P.Own(self, z); M.Investigate(z, target:GetPos(), 20)
    return true
end
function ENT:ZAUpdatePhase(count, target, weakest, pressure)
    local elapsed=self.ZAElapsed
    local restTarget=math.min(target, math.Clamp(math.ceil(target*C.RestFraction), C.RestMinimum, C.RestMaximum))
    local rested=self.ZAPhase=="rest" and elapsed-(self.ZAPhaseStarted or 0)>=C.RestEarlyExit and count<=restTarget
    if self.ZAPhase=="rest" then
        if elapsed>=self.ZAPhaseEnd or rested then
            self.ZAPhase,self.ZAPhaseStarted,self.ZAPhaseEnd="buildup",elapsed,elapsed+C.BuildupDuration
            self.ZAReliefUntil=elapsed+C.ReliefCooldown
        end
    elseif elapsed>=(self.ZAReliefUntil or 0) and (pressure>0.85 or weakest<0.25 and pressure>0.25)
        or self.ZAPhase=="peak" and elapsed>=self.ZAPhaseEnd then
        self.ZAPhase,self.ZAPhaseStarted,self.ZAPhaseEnd="rest",elapsed,elapsed+math.Rand(C.RestMinDuration,C.RestMaxDuration)
    elseif elapsed>=self.ZAPhaseEnd then
        self.ZAPhase,self.ZAPhaseStarted,self.ZAPhaseEnd="peak",elapsed,elapsed+math.Rand(C.PeakMinDuration,C.PeakMaxDuration)
    end
    self:SetHordePhase(self.ZAPhase=="rest" and 3 or self.ZAPhase=="peak" and 2 or 1)
    return self.ZAPhase=="rest" and restTarget or target
end
function ENT:Think()
    local now, limit = CurTime(), M.PopulationLimit()
    local running = M.DirectorEnabled:GetBool()
    if running ~= self.ZARunningSetting then self.ZARunningSetting = running; self:SetRunning(running) end
    local elapsed = math.Clamp(now - (self.ZALastThink or now), 0, C.ThinkInterval * 2)
    self.ZALastThink = now; self:NextThink(now + C.ThinkInterval)
    self:SetHordeSize(M.Count()); self:SetPopulationLimit(limit); self:SetPlayerRadius(M.Radius:GetFloat())
    if not self:GetRunning() or GetConVar("ai_disabled"):GetBool() or GetConVar("ai_ignoreplayers"):GetBool() then return true end
    if not navmesh.IsLoaded() then return true end
    local players, weakest = {}, 1
    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) and ply:Alive() then
            players[#players + 1] = ply
            weakest = math.min(weakest, ply:Health() / math.max(ply:GetMaxHealth(), 1))
        end
    end
    if #players == 0 then return true end
    self.ZAElapsed = (self.ZAElapsed or 0) + elapsed
    local targetCount = math.min(limit, math.floor(M.InitialDensity:GetInt() + self.ZAElapsed * M.DensityPerMinute:GetInt() / 60 + 4 * (#players - 1)))
    self:SetDensityTarget(targetCount)
    local spawnTarget=self:ZAUpdatePhase(M.Count(),targetCount,weakest,self:GetIntensity())
    P.Tick(self, players, spawnTarget)
    local count = M.Count(); self:SetHordeSize(count)
    self.ZAPlayerPressure = math.max(0, self.ZAPlayerPressure - elapsed * 0.02)
    local pressure = math.Clamp(self.ZAPlayerPressure * 0.6 + count / limit * 0.4, 0, 1)
    self:SetIntensity(pressure)
    if now >= self.ZANextDecay and self:GetThreatLevel() > 1 then
        self:SetThreatLevel(self:GetThreatLevel() - 1); self.ZANextDecay = now + 120
    end
    if now < self.ZANextSpawn then return true end
    local group = self.ZAPhase == "rest" and 1 or self.ZAPhase == "peak" and C.PeakGroup or C.BuildupGroup
    local deadline = SysTime() + ZA1.Config.Population.WorkBudgetMS / 1000
    local spawned = 0
    for i = 1, math.min(group, spawnTarget - count) do
        if SysTime() >= deadline or not self:SpawnZombie(players, deadline) then break end
        spawned = spawned + 1
    end
    -- A pending scan, route or hidden special must not consume a full spawn delay.
    self.ZANextSpawn = now + (spawned > 0 and math.Rand(C.SpawnMinDelay, C.SpawnMaxDelay) or C.ThinkInterval)
    self:SetHordeSize(M.Count())
    return true
end
