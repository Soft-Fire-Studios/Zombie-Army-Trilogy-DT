if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("za1/suicide_eye_glow_data.lua")
    return
end
-- The original Suicide Grunt owns two persistent glow components, not FXETs.
-- Preserve their pixel width/depth, red color, aspect and short sample history.
local data = include("za1/suicide_eye_glow_data.lua")
local G = {}; ZA1.EyeGlow = G
G.Limits = {Actors = 128, Quads = 1024, Segments = 32}
local tracked, count = {}, 0
local material = Material(data.Material)
local min, max, abs, ceil, floor = math.min, math.max, math.abs, math.ceil, math.floor
local zero = Angle()
local lastFrame
local function active(owner)
    if not IsValid(owner) or owner.ZASpecial ~= data.Kind or owner:IsDormant()
        or owner:GetModel() ~= data.Model or owner:GetBodygroup(data.HeadGroup) ~= data.IntactHead
        or owner:Health() <= 0 or not ZA1.FireVFX.IsVisible(owner:GetPos()) then return false end
    local state = owner:GetNW2String("za1_enemy_vfx_state", "idle")
    return state ~= "stopped" and state ~= "dead"
end
local function remove(owner)
    if tracked[owner] then tracked[owner] = nil; count = count - 1 end
end
function G.Update(owner)
    if not active(owner) then remove(owner); return false end
    if tracked[owner] then return true end
    if count >= G.Limits.Actors then return false end
    local row = {Eyes = {}, Bone = owner:LookupBone(data.Bone)}
    for index, point in ipairs(data.Eyes) do
        row.Eyes[index] = {Offset = Vector(unpack(point.Position)), History = {}, Head = 1, Count = 0,
            Visibility = util.GetPixelVisibleHandle()}
    end
    tracked[owner], count = row, count + 1
    return true
end
local function node(eye, logical)
    return eye.History[(eye.Head + logical - 2) % data.Samples + 1]
end
local function drain(eye, now)
    while eye.Count > 0 and node(eye, 1).Until <= now do
        eye.Head = eye.Head % data.Samples + 1; eye.Count = eye.Count - 1
    end
end
local function publish(eye, screen, depth, alpha, now)
    if eye.LastSample == now then return end -- A paused native clock emits no new history.
    eye.LastSample = now
    if eye.Count == data.Samples then eye.Head = eye.Head % data.Samples + 1; eye.Count = eye.Count - 1 end
    local slot = (eye.Head + eye.Count - 1) % data.Samples + 1
    local point = eye.History[slot]
    if not point then point = {}; eye.History[slot] = point end
    point.X, point.Y, point.Depth, point.Alpha, point.Until = screen.x, screen.y, max(.1, depth), alpha,
        now + data.HistorySeconds
    eye.Count = eye.Count + 1
end
local function clamp(value) return min(1, max(0, value)) end
local function rounded(value) return floor(clamp(value) * 255 + .5) end
local function quad(a, b, phase, now, visibility)
    local life = clamp((a.Until + (b.Until - a.Until) * phase - now) / data.HistorySeconds)
    local depth = a.Depth + (b.Depth - a.Depth) * phase
    local width = (data.TerminalWidth + (data.InitialWidth - data.TerminalWidth) * life) / depth
    local height = width * data.Aspect
    local alpha = clamp((a.Alpha + (b.Alpha - a.Alpha) * phase) * 2) * visibility
    if width <= 0 or height <= 0 or alpha <= 0 then return false end
    local x, y = a.X + (b.X - a.X) * phase, a.Y + (b.Y - a.Y) * phase
    surface.SetDrawColor(rounded(data.Color[1] * life), rounded(data.Color[2] * life),
        rounded(data.Color[3] * life), rounded(alpha))
    surface.DrawTexturedRect(x - width * .5, y - height * .5, width, height)
    return true
end
local function drawHistory(eye, now, budget)
    if eye.Visible <= 0 then return budget end
    local previous = node(eye, 1)
    for index = 1, eye.Count do
        local point = node(eye, index)
        local life = clamp((previous.Until - now) / data.HistorySeconds)
        local width = (data.TerminalWidth + (data.InitialWidth - data.TerminalWidth) * life) / previous.Depth
        local spacing = data.Spacing * max(10, width) * .1
        local segments = min(G.Limits.Segments, max(1, ceil(max(abs(point.X - previous.X),
            abs(point.Y - previous.Y)) / spacing)))
        for segment = 0, segments - 1 do
            if budget <= 0 then return 0 end
            if quad(previous, point, segment / segments, now, eye.Visible) then budget = budget - 1 end
        end
        previous = point
    end
    return budget
end
function G.Render(depthPass, skybox)
    if depthPass or skybox then return end
    local frame = FrameNumber()
    if frame == lastFrame then return end -- Pixel visibility handles are queried once per frame.
    lastFrame = frame
    local camera, forward, now = EyePos(), EyeAngles():Forward(), CurTime()
    local width, height, any = ScrW(), ScrH(), false
    for owner, row in pairs(tracked) do
        if not active(owner) then remove(owner)
        else
            if row.Bone == nil then row.Bone = owner:LookupBone(data.Bone) end
            local matrix = row.Bone and owner:GetBoneMatrix(row.Bone)
            if matrix then
                local translation, angles = matrix:GetTranslation(), matrix:GetAngles()
                local scale = owner:GetModelScale()
                for _, eye in ipairs(row.Eyes) do
                    drain(eye, now)
                    local position = LocalToWorld(eye.Offset * scale, zero, translation, angles)
                    local dx, dy, dz = position.x - camera.x, position.y - camera.y, position.z - camera.z
                    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local viewDepth = (dx * forward.x + dy * forward.y + dz * forward.z) / data.Scale
                    local screen = position:ToScreen()
                    local visible = viewDepth > 0 and distance < data.MaxDistance * data.Scale
                        and screen.visible and screen.x >= 0 and screen.x <= width and screen.y >= 0 and screen.y <= height
                    eye.Visible = 0
                    if visible then
                        -- The original ray accepts hits within .075m of the eye.
                        -- Source supplies a pixel visibility query at that near-
                        -- camera point, without allocating another AI/world trace.
                        local shift = min(distance, data.OcclusionTolerance * data.Scale) / max(distance, .0001)
                        position.x, position.y, position.z = position.x - dx * shift,
                            position.y - dy * shift, position.z - dz * shift
                        if eye.VisibilityTime ~= now then
                            eye.VisibilityTime = now
                            eye.VisibilityValue = clamp(util.PixelVisible(position, 1, eye.Visibility) or 0)
                        end
                        eye.Visible = eye.VisibilityValue or 0
                        publish(eye, screen, viewDepth, data.Alpha, now)
                    end
                    if eye.Count > 0 and eye.Visible > 0 then any = true end
                end
            else
                for _, eye in ipairs(row.Eyes) do eye.Visible = 0; drain(eye, now) end
            end
        end
    end
    if not any then return end
    cam.Start2D(); surface.SetMaterial(material)
    local budget = G.Limits.Quads
    for _, row in pairs(tracked) do
        for _, eye in ipairs(row.Eyes) do
            if eye.Count > 0 then budget = drawHistory(eye, now, budget) end
            if budget == 0 then break end
        end
        if budget == 0 then break end
    end
    cam.End2D()
end
function G.Cleanup() for owner in pairs(tracked) do tracked[owner] = nil end; count = 0; lastFrame = nil end
function G.Stats() return count end
hook.Add("PostDrawTranslucentRenderables", "ZA1/EyeGlow", G.Render)
hook.Add("EntityRemoved", "ZA1/EyeGlow", remove)
hook.Add("PostCleanupMap", "ZA1/EyeGlow", G.Cleanup)
hook.Add("ShutDown", "ZA1/EyeGlow", G.Cleanup)
