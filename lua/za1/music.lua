local Enabled = CreateClientConVar("za1_music", "1", true, false, "Enable Zombie Army's layered music.")
local Volume = CreateClientConVar("za1_music_volume", "0.7", true, false, "Zombie Army music volume.", 0, 1)
local Theme = CreateClientConVar("za1_music_theme", "0", true, false, "Trilogy theme: 0 random; select an episode/theme in the Zombie Army tool panel.", 0, 64)
-- Upgrade the old saved default once; retain custom levels, including mute.
local VolumeVersion = CreateClientConVar("za1_music_volume_version", "0", true, false, "Saved music-volume default revision.", 0, 1)
if VolumeVersion:GetInt() < 1 then
    if math.abs(Volume:GetFloat() - 0.35) < 0.0001 then Volume:SetFloat(0.7) end
    VolumeVersion:SetFloat(1)
end
local channels, token, pending = {}, 0, false
local active, target, intensity, lastPacket, nextAttempt, nextSync = false, 0, 0, 0, 0, 0
local function Stop()
    token = token + 1
    for _, channel in pairs(channels) do if IsValid(channel) then channel:Stop() end end
    channels = {}; pending = false
end
local function Load()
    local sets = ZA1.Assets.music
    if #sets == 0 then return end
    Stop(); pending = true
    local generation = token
    local choices = {}
    for _, set in ipairs(sets) do if Theme:GetInt() == 0 or set.theme == Theme:GetInt() then choices[#choices + 1] = set end end
    if #choices == 0 then pending = false; nextAttempt = RealTime() + 30; return end
    local set = choices[math.random(#choices)]
    local ready, loaded = 0, channels
    for index, file in ipairs(set.files) do
        local slot, path = index, file
        sound.PlayFile("sound/" .. file, "noplay noblock", function(channel, code, message)
            if generation ~= token then if IsValid(channel) then channel:Stop() end; return end
            if not IsValid(channel) then
                for _, item in pairs(loaded) do if IsValid(item) then item:Stop() end end
                Stop(); nextAttempt = RealTime() + 30
                ErrorNoHalt("Zombie Army music could not load " .. path .. ": " .. tostring(message) .. "\n")
                return
            end
            channel:SetVolume(0); channel:EnableLooping(true)
            loaded[slot] = channel; ready = ready + 1
            if ready == #set.files then
                channels = loaded; pending = false
                -- All stems start together after the last asynchronous load.
                for _, item in ipairs(channels) do item:SetTime(0); item:Play() end
                nextSync = RealTime() + 5
            end
        end)
    end
end
net.Receive("ZA1/Music", function()
    active = net.ReadBool(); target = math.Clamp(net.ReadFloat(), 0, 1)
    local horde = net.ReadUInt(16)
    ZA1.MusicHorde = horde
    lastPacket = RealTime()
end)
local nextUpdate = 0
hook.Add("Think", "ZA1/LayeredMusic", function()
    local now = RealTime()
    if now < nextUpdate then return end
    local dt = math.min(0.2, math.max(0.01, now - nextUpdate + 0.05))
    nextUpdate = now + 0.05
    if not Enabled:GetBool() or now - lastPacket > 3 then active = false end
    local wanted = active and target or 0
    intensity = math.Approach(intensity, wanted, dt * (wanted > intensity and 0.35 or 0.15))
    if not active and pending then Stop() end
    if active and Enabled:GetBool() and next(channels) == nil and not pending and now >= nextAttempt then Load() end
    if pending then return end
    local volume = active and Enabled:GetBool() and Volume:GetFloat() or 0
    for index, channel in ipairs(channels) do
        if IsValid(channel) then
            local weight = index == 1 and 0.65 or index == 2 and math.Clamp((intensity - 0.15) / 0.55, 0, 1) or math.Clamp((intensity - 0.55) / 0.4, 0, 1)
            local desired = volume * weight
            channel:SetVolume(math.Approach(channel:GetVolume(), desired, dt * 0.4))
        end
    end
    if not active and #channels > 0 then
        local quiet = true
        for _, channel in ipairs(channels) do if IsValid(channel) and channel:GetVolume() > 0.001 then quiet = false; break end end
        if quiet then Stop() end
    end
    if #channels > 1 and now >= nextSync and IsValid(channels[1]) then
        nextSync = now + 5
        local master, length = channels[1]:GetTime(), channels[1]:GetLength()
        if length > 0 then
            for index = 2, #channels do
                local channel = channels[index]
                if IsValid(channel) then
                    local error = (channel:GetTime() - master + length / 2) % length - length / 2
                    if math.abs(error) > 0.06 then channel:SetTime(master) end
                end
            end
        end
    end
end)
hook.Add("ShutDown", "ZA1/StopMusic", Stop)
hook.Add("PostCleanupMap", "ZA1/CleanupMusic", function() active = false; Stop() end)
cvars.AddChangeCallback("za1_music_theme", function() nextAttempt = 0; Stop() end, "ZA1/ThemeChange")
