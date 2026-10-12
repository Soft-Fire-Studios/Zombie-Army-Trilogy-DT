if SERVER then AddCSLuaFile() end
AddCSLuaFile("za1/general_orbit_assets.lua")
local data = include("za1/general_orbit_assets.lua")
local O = {}; ZA1.GeneralOrbit = O
local rates = {}
for scene, value in pairs(data.Scenes) do
    rates[scene] = {}
    for _, marker in ipairs(value.Markers) do rates[scene][marker.Path] = marker.PlaybackRate end
end
function O.Rate(path, scene) return rates[scene] and rates[scene][path] end

-- Use the authored marker/hardpoint pose, including orientation. Interpolating
-- quaternions avoids an Euler flip when a tilted orbit crosses a singularity.
function O.Pose(path, age)
    local clip = data.Paths[path]
    if not clip then return end
    local frame = (age % clip.Duration) / clip.Duration * (#clip.Frames - 1)
    local index = math.floor(frame) + 1
    local a, b, t = clip.Frames[index], clip.Frames[index + 1], frame % 1
    local dot = a[7]*b[7] + a[8]*b[8] + a[9]*b[9] + a[10]*b[10]
    local sign = dot < 0 and -1 or 1
    dot = math.Clamp(math.abs(dot), 0, 1)
    local first, second = 1-t, t*sign
    if dot < .9995 then
        local angle = math.acos(dot)
        first, second = math.sin((1-t)*angle)/math.sin(angle), math.sin(t*angle)/math.sin(angle)*sign
    end
    local x, y = a[7]*first+b[7]*second, a[8]*first+b[8]*second
    local z, w = a[9]*first+b[9]*second, a[10]*first+b[10]*second
    local length = math.sqrt(x*x+y*y+z*z+w*w)
    x, y, z, w = x/length, y/length, z/length, w/length
    local xx, xy, xz = 1-2*(y*y+z*z), 2*(x*y+z*w), 2*(x*z-y*w)
    local angles = Angle(math.deg(math.atan2(-xz, math.sqrt(xx*xx+xy*xy))),
        math.deg(math.atan2(xy, xx)), math.deg(math.atan2(2*(y*z+x*w), 1-2*(x*x+y*y))))
    return Vector(a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t, a[3]+(b[3]-a[3])*t), angles
end

function O.World(path, age, center, rotation, scale)
    local position, angles = O.Pose(path, age)
    if not position then return end
    return LocalToWorld(position * scale, angles, center, rotation)
end

-- The compiled skull faces opposite its orbit marker. Rotate the mesh about
-- the marker's local up axis; keep the authored tilted path and position intact.
function O.ModelAngles(angles)
    return Angle(-angles.p, angles.y + 180, -angles.r)
end
