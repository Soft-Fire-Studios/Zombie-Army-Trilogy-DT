-- Original FXTTs are ordered histories. They cannot be represented by a
-- render_sprite_trail particle. Linked FXPT leaders live here as well, so the
-- exported PCF deliberately omits those two sprite children. Missing additive
-- fire layers and resurrection sprites share this atlas/curve renderer without
-- allocating a trail history or a second PCF particle for each visible sprite.
if SERVER then return end
ZA1 = ZA1 or {}
local R = ZA1.FireVFXRibbons or {}
ZA1.FireVFXRibbons = R
if R.Cleanup then R.Cleanup() end
R.Limits = {Instances = 512, Leaders = 4096, GlyphReserve = 100, PerEmitter = 128, History = 96,
  RenderSegments = 4096, Distance = 4096, MaxStep = 0.1}
local limits, min, max, abs, floor, ceil, sqrt = R.Limits, math.min, math.max,
  math.abs, math.floor, math.ceil, math.sqrt
local sin, cos, pi, band = math.sin, math.cos, math.pi, bit.band
local active, materials, leaderCount, glyphCount, glyphInstances = {}, {}, 0, 0, 0
local surfaceModels = {}
local identity = {1, 0, 0, 0, 1, 0, 0, 0, 1}
local zero = {0, 0, 0}
local vertex = Vector()
local nowTime = CurTime
local distanceConVar
local clearDrawQueue, prewarm
local function cullDistance()
  if not distanceConVar and GetConVar then distanceConVar = GetConVar("za1_effect_distance") end
  return distanceConVar and min(8192, max(256, distanceConVar:GetFloat())) or limits.Distance
end
local function clamp(x, a, b) return min(b, max(a, x)) end
local function frac(x) return x - floor(x) end
local function flag(bits, mask) return band(bits or 0, mask) ~= 0 end
local function word(t, key, default)
  local v = t.Words and t.Words[key]
  return type(v) == "number" and v or (default or 0)
end
local function curve(samples, t, lane, default)
  if not samples or #samples == 0 then return default or 0 end
  lane = lane or 1
  if #samples == 1 then return samples[1][lane] or default or 0 end
  local q = t * (#samples - 1)
  -- Native sampled curves truncate towards zero, including their small
  -- negative-domain extrapolation. Normalized birth inputs are clamped by the
  -- caller; the history/particle domains remain distinct.
  local i = q < 0 and ceil(q) or floor(q)
  if i < 0 then return samples[1][lane] or default or 0 end
  if i >= #samples - 1 then return samples[#samples][lane] or default or 0 end
  local a, b = samples[i + 1][lane], samples[i + 2][lane]
  return (a or default or 0) + ((b or default or 0) - (a or default or 0)) * (q - i)
end
local function sample(t, key, age, lane, default)
  return curve(t.Curves and t.Curves[key], age, lane, default)
end
local function unit(x, y, z)
  local length = sqrt(x*x + y*y + z*z)
  if length < 0.000001 then return 0, 0, 1, 0 end
  return x/length, y/length, z/length, length
end
local function random(s)
  -- Instance-local RNG; never alters Garry's Mod's shared random state. The
  -- native seed generator is not reproduced by this Source adapter.
  s.seed = (s.seed * 16807) % 2147483647
  return (s.seed - 1) / 2147483646
end
local function material(path)
  local m = materials[path]
  if not m then m = Material(path); materials[path] = m end
  return m
end
local function basis(instance, angle)
  -- Source local +Y is LEFT. Native (x,y,z) becomes (z,-x,-y)
  -- before this orientation; all dimensional data is scaled exactly once.
  local pitch, yaw, roll = angle.p*pi/180, angle.y*pi/180, angle.r*pi/180
  local cp, sp, cy, sy, cr, sr = cos(pitch), sin(pitch), cos(yaw), sin(yaw), cos(roll), sin(roll)
  instance.fx, instance.fy, instance.fz = cp*cy, cp*sy, -sp
  instance.lx, instance.ly, instance.lz = sr*sp*cy-cr*sy, sr*sp*sy+cr*cy, sr*cp
  instance.ux, instance.uy, instance.uz = cr*sp*cy+sr*sy, cr*sp*sy-sr*cy, cr*cp
end
local function nativeVector(instance, component, x, y, z, dimensional)
  local m = component and component.Matrix or identity
  local a, b, c = m[1]*x + m[2]*y + m[3]*z,
    m[4]*x + m[5]*y + m[6]*z, m[7]*x + m[8]*y + m[9]*z
  local scale = dimensional and instance.scale or 1
  return (instance.fx*c - instance.lx*a - instance.ux*b)*scale,
    (instance.fy*c - instance.ly*a - instance.uy*b)*scale,
    (instance.fz*c - instance.lz*a - instance.uz*b)*scale
end
local function origin(instance, component)
  local v = component and component.Translation or zero
  local x, y, z = nativeVector(instance, nil, v[1], v[2], v[3], true)
  return instance.x+x, instance.y+y, instance.z+z
end
local function previousOrigin(instance, component)
  local v = component and component.Translation or zero
  local a, b, c = v[1]*instance.scale, v[2]*instance.scale, v[3]*instance.scale
  return instance.prevX+instance.prevFX*c-instance.prevLX*a-instance.prevUX*b,
    instance.prevY+instance.prevFY*c-instance.prevLY*a-instance.prevUY*b,
    instance.prevZ+instance.prevFZ*c-instance.prevLZ*a-instance.prevUZ*b
end
local function rotateFollow(instance, x, y, z)
  local f = x*instance.prevFX+y*instance.prevFY+z*instance.prevFZ
  local l = x*instance.prevLX+y*instance.prevLY+z*instance.prevLZ
  local u = x*instance.prevUX+y*instance.prevUY+z*instance.prevUZ
  return f*instance.fx+l*instance.lx+u*instance.ux,
    f*instance.fy+l*instance.ly+u*instance.uy,
    f*instance.fz+l*instance.lz+u*instance.uz
end
local function rememberBasis(instance)
  instance.prevX, instance.prevY, instance.prevZ = instance.x, instance.y, instance.z
  instance.prevFX, instance.prevFY, instance.prevFZ = instance.fx, instance.fy, instance.fz
  instance.prevLX, instance.prevLY, instance.prevLZ = instance.lx, instance.ly, instance.lz
  instance.prevUX, instance.prevUY, instance.prevUZ = instance.ux, instance.uy, instance.uz
end
local function surfaceDefinition(owner)
  if not owner.GetHitBoxCount or not owner.GetHitBoxBounds or not owner.GetHitBoxBone
    or not owner.GetModel or not owner.GetBoneMatrix then return end
  local model, set = owner:GetModel(), owner.GetHitboxSet and owner:GetHitboxSet() or 0
  if not model then return end
  local key = model..":"..tostring(set)
  local cached = surfaceModels[key]
  if cached then return cached end
  local boxes, total = {}, 0
  for index = 0, min(256, owner:GetHitBoxCount(set) or 0)-1 do
    local a, b = owner:GetHitBoxBounds(index, set)
    local bone = owner:GetHitBoxBone(index, set)
    if a and b and bone and bone >= 0 then
      local dx, dy, dz = abs(b.x-a.x), abs(b.y-a.y), abs(b.z-a.z)
      local area = 2*(dx*dy+dx*dz+dy*dz)
      if area > 0 then
        total = total+area
        boxes[#boxes+1] = {bone=bone, x0=a.x,y0=a.y,z0=a.z,x1=b.x,y1=b.y,z1=b.z,
          yz=dy*dz,xz=dx*dz,xy=dx*dy,area=area,total=total}
      end
    end
  end
  if total <= 0 then return end -- Model/hitboxes can arrive after the entity.
  cached = {boxes=boxes,total=total}
  surfaceModels[key] = cached
  return cached
end
local function surfacePosition(instance, state)
  local owner = instance.surfaceOwner
  if not IsValid(owner) then return end
  local definition = surfaceDefinition(owner)
  if not definition or definition.total <= 0 then return end
  local threshold = random(state)*definition.total
  local box = definition.boxes[#definition.boxes]
  for _, candidate in ipairs(definition.boxes) do if threshold <= candidate.total then box=candidate; break end end
  local matrix = owner:GetBoneMatrix(box.bone)
  if not matrix then return end
  local position, angles = matrix:GetTranslation(), matrix:GetAngles()
  if not position or not angles then return end
  local face = random(state)*box.area
  local x, y, z = box.x0+(box.x1-box.x0)*random(state),
    box.y0+(box.y1-box.y0)*random(state), box.z0+(box.z1-box.z0)*random(state)
  if face < box.yz then x=box.x0
  elseif face < 2*box.yz then x=box.x1
  elseif face < 2*box.yz+box.xz then y=box.y0
  elseif face < 2*(box.yz+box.xz) then y=box.y1
  elseif face < 2*(box.yz+box.xz)+box.xy then z=box.z0 else z=box.z1 end
  local scale = owner.GetModelScale and owner:GetModelScale() or 1
  -- Source hitbox surfaces are an explicit bounded adapter for native skin
  -- surfaces. Rigid bone angles plus model scale avoid applying matrix scale twice.
  local p,yaw,r = angles.p*pi/180,angles.y*pi/180,angles.r*pi/180
  local cp,sp,cy,sy,cr,sn = cos(p),sin(p),cos(yaw),sin(yaw),cos(r),sin(r)
  return position.x+scale*(x*cp*cy+y*(sn*sp*cy-cr*sy)+z*(cr*sp*cy+sn*sy)),
    position.y+scale*(x*cp*sy+y*(sn*sp*sy+cr*cy)+z*(cr*sp*sy-sn*cy)),
    position.z+scale*(-x*sp+y*sn*cp+z*cr*cp)
end
local function shape(s, component)
  local kind, p = component.Shape or 0, component.Parameters or {}
  local surface = flag(component.Flags, 1)
  if kind == 0 then return 0, 0, 0 end
  if kind == 1 then
    local x = p.min_x + (p.max_x-p.min_x)*random(s)
    local y = p.min_y + (p.max_y-p.min_y)*random(s)
    local z = p.min_z + (p.max_z-p.min_z)*random(s)
    if surface then
      local face = floor(random(s)*6)
      if face == 0 then x = p.min_x elseif face == 1 then x = p.max_x
      elseif face == 2 then y = p.min_y elseif face == 3 then y = p.max_y
      elseif face == 4 then z = p.min_z else z = p.max_z end
    end
    return x, y, z
  end
  if kind == 2 or kind == 3 then
    local z, phase = random(s)*2-1, random(s)*2*pi
    local disk = sqrt(max(0, 1-z*z))
    local radius = surface and 1 or random(s)^(1/3)
    local a = kind == 2 and p.radius or p.radius_x
    local b = kind == 2 and p.radius or p.radius_y
    local c = kind == 2 and p.radius or p.radius_z
    return cos(phase)*disk*radius*a, sin(phase)*disk*radius*b, z*radius*c
  end
  local phase, minorPhase = random(s)*2*pi, random(s)*2*pi
  local ax, ay = cos(phase), sin(phase)
  local radius = surface and 1 or sqrt(random(s))
  local bx, by = cos(minorPhase)*radius, sin(minorPhase)*radius
  local minor = p.minor_radius
  if kind == 4 then
    return (p.major_radius+minor*bx)*ax, (p.major_radius+minor*bx)*ay, minor*by
  end
  local nx, ny = unit(p.major_radius_y*ax, p.major_radius_x*ay, 0)
  return p.major_radius_x*ax+minor*bx*nx, p.major_radius_y*ay+minor*bx*ny, minor*by
end
local function capacity(t)
  local bits = word(t, "0x14c")
  local n = flag(bits, 1) and ceil(word(t, "0x128")/max(0.000001, word(t, "0x12c")))+1
    or ceil(word(t, "0x138")*word(t, "0x130"))+1
  return clamp(n, 2, min(limits.History, t.PointCap or limits.History))
end
local function newHistory(t)
  local h = {template = t, points = {}, boundary = {}, capacity = capacity(t), first = 1, count = 0,
    distance = 0, residual = 0, born = 0, alive = true}
  for i = 1, h.capacity do h.points[i] = {} end
  return h
end
local function point(h, logical)
  return h.points[(h.first + logical - 2) % h.capacity + 1]
end
local function append(h, x, y, z, sx, sy, sz, time, distance)
  local index
  if h.count == h.capacity then
    index = h.first; h.first = h.first % h.capacity + 1
  else
    h.count = h.count + 1
    index = (h.first+h.count-2) % h.capacity + 1
  end
  local p = h.points[index]
  p.x, p.y, p.z, p.sx, p.sy, p.sz, p.time, p.distance = x, y, z, sx, sy, sz, time, distance
end
local function resetHistory(h, x, y, z, sx, sy, sz, time)
  h.first, h.count, h.distance, h.residual, h.born, h.alive = 1, 0, 0, 0, time, true
  h.x, h.y, h.z, h.sx, h.sy, h.sz, h.time = x, y, z, sx, sy, sz, time
  h.px, h.py, h.pz = x, y, z
  append(h, x, y, z, sx, sy, sz, time, 0)
end
local function record(h, x, y, z, sx, sy, sz, time, scale)
  if not h.alive then return end
  if h.count == 0 then resetHistory(h, x, y, z, sx, sy, sz, time); return end
  local dx, dy, dz, dt = x-h.x, y-h.y, z-h.z, time-h.time
  if dt < 0 then resetHistory(h, x, y, z, sx, sy, sz, time); return end
  local length = sqrt(dx*dx+dy*dy+dz*dz)
  local distanceMode = flag(word(h.template, "0x14c"), 1)
  local step = distanceMode and word(h.template, "0x12c")*scale
    or 1/max(0.000001, word(h.template, "0x138"))
  local travel = distanceMode and length or dt
  if step <= 0 then return end
  local total, oldDistance = h.residual+travel, h.distance
  local samples = floor(total/step)
  local skip = max(0, samples-h.capacity)
  -- Work after a network jump/hitch is bounded by the ring's capacity.
  for i = skip+1, samples do
    local fraction = travel > 0 and clamp((i*step-h.residual)/travel, 0, 1) or 1
    local a, b, c = h.x+dx*fraction, h.y+dy*fraction, h.z+dz*fraction
    -- 0x1000 requests curved inserted positions. This Hermite adapter retains
    -- adjacent motion tangents; exact native cubic coefficients are unproved.
    if flag(word(h.template, "0x14c"), 0x1000) and travel > 0 then
      local f2, f3 = fraction*fraction, fraction*fraction*fraction
      local c0, c1, v0, v1 = 2*f3-3*f2+1, -2*f3+3*f2, f3-2*f2+fraction, f3-f2
      a = c0*h.x+c1*x+v0*(h.x-h.px)+v1*dx
      b = c0*h.y+c1*y+v0*(h.y-h.py)+v1*dy
      c = c0*h.z+c1*z+v0*(h.z-h.pz)+v1*dz
    end
    append(h, a, b, c, h.sx+(sx-h.sx)*fraction, h.sy+(sy-h.sy)*fraction,
      h.sz+(sz-h.sz)*fraction, h.time+dt*fraction, oldDistance+length*fraction)
  end
  h.residual = total-samples*step
  h.distance = oldDistance+length
  h.px, h.py, h.pz = h.x, h.y, h.z
  h.x, h.y, h.z, h.sx, h.sy, h.sz, h.time = x, y, z, sx, sy, sz, time
end
local function release(s, p)
  if p.active then
    p.active = false; leaderCount = leaderCount-1; s.count = s.count-1
    if s.glyph then glyphCount = glyphCount-1 end
  end
end
local function clear(instance)
  for _, s in ipairs(instance.states) do
    if s.history then s.history.count = 0 end
    for _, p in ipairs(s.pool) do release(s, p); if p.history then p.history.count = 0 end end
  end
end
local function aliveOwner(instance)
  local owner = instance.owner
  return owner == nil or (IsValid(owner) and (not owner.IsDormant or not owner:IsDormant()))
end
function R.Update(instance, position, angle)
  if not instance or instance.dead then return false end
  if position then instance.x, instance.y, instance.z = position.x, position.y, position.z end
  if angle then basis(instance, angle) end
  return true
end
function R.Surface(instance, owner)
  if not instance or instance.dead then return false end
  instance.surfaceOwner = owner
  return owner == nil or IsValid(owner)
end
function R.Start(owner, effect, position, angle, now, options)
  local data = ZA1.FireVFXData
  local trails = data and data.Ribbons and data.Ribbons[effect]
  local sprites = data and data.Sprites and data.Sprites[effect]
  if not trails and not sprites then return nil end
  local e = (data.Effects and data.Effects[effect]) or (data.Systems and data.Systems[effect]) or {}
  local glyph = options and options.Glyph or e.NativeID == 0x0C4F1EC3 or e.NativeID == 0x377B3231
  if #active >= limits.Instances or not glyph and #active-glyphInstances >= limits.Instances-limits.GlyphReserve then
    for i = #active, 1, -1 do
      if active[i].dead then
        if active[i].glyph then glyphInstances=glyphInstances-1 end
        active[i] = active[#active]; active[#active] = nil
      end
    end
    if #active >= limits.Instances or not glyph and #active-glyphInstances >= limits.Instances-limits.GlyphReserve then return nil end
  end
  if owner ~= nil and not IsValid(owner) then return nil end
  now = now or nowTime()
  local rate=clamp(options and options.PlaybackRate or 1,.05,1)
  local instance = {owner = owner, effect = effect, scale = data.Scale, states = {}, components = {}, glyph = glyph,
    keepOnRemove = options and options.KeepOnRemove or false,
    sourceColorRemap = options and options.SourceColorRemap,
    prewarm = flag(e.NativeFlags,0x40) and e.Loop and (not options or options.Prewarm~=false),
    last = now, start = now, clock = 0, duration = e.Duration or 0, loop = e.Loop, playbackRate=rate,
    drain = (e.Drain or e.MaxParticleLife or e.MaxLife or 4)/rate, stopped = false, culled = false,
    dx=0,dy=0,dz=0,step=1/60}
  R.Update(instance, position or (owner and owner:GetPos()) or Vector(), angle or Angle())
  rememberBasis(instance)
  if options and options.SurfaceOwner then R.Surface(instance, options.SurfaceOwner) end
  local templates = {}
  for _, t in ipairs(trails or {}) do templates[#templates+1] = t end
  for _, t in ipairs(sprites or {}) do templates[#templates+1] = t end
  for index, t in ipairs(templates) do
    local s = {template = t, pool = {}, count = 0, accumulator = 0, progress = 0, glyph=glyph,
      seed = ((floor(now*1000)+index*8191+#active*65537) % 2147483646)+1, burst = false}
    if not t.Leader then s.history = newHistory(t) end
    instance.states[index] = s
    local nativeIndex = t.Leader and (t.Leader.Index or t.Index) or t.Index
    if nativeIndex ~= nil then instance.components[nativeIndex] = s end
    if t.Material then material(t.Material) end
    if t.Leader then material(t.Leader.Material) end
  end
  active[#active+1] = instance
  if glyph then glyphInstances = glyphInstances+1 end
  if instance.prewarm then prewarm(instance,now) end
  return instance
end
function R.Stop(instance, immediate)
  if not instance or instance.dead then return end
  instance.stopped, instance.stopTime = true, nowTime()
  if immediate then instance.dead = true; clear(instance) end
  for _, s in ipairs(instance.states) do
    if s.history and flag(word(s.template, "0x14c"), 0x10000) then s.history.count = 0 end
    local e = s.template.Leader and s.template.Leader.Emitter
    if e and flag(word(e, "0x170"), 0x10000) then
      for _, p in ipairs(s.pool) do release(s, p) end
    end
  end
end
function R.StopOwner(owner, immediate)
  for _, instance in ipairs(active) do
    if instance.owner == owner or instance.surfaceOwner == owner then
      if instance.keepOnRemove then
        instance.owner,instance.surfaceOwner=nil,nil;R.Stop(instance,false)
      else R.Stop(instance,immediate) end
    end
  end
end
function R.Cleanup()
  for _, instance in ipairs(active) do clear(instance); instance.dead = true end
  active = {}; leaderCount, glyphCount, glyphInstances = 0, 0, 0
  if clearDrawQueue then clearDrawQueue() end
end
local function birth(instance, s, time, lag)
  local t, leader = s.template, s.template.Leader
  local e, bits = leader.Emitter, word(leader.Emitter, "0x170")
  local cap = min(limits.PerEmitter, leader.SourceCapacity or limits.PerEmitter, max(0, word(e, "0x15c")))
  if s.count >= cap or leaderCount >= limits.Leaders
    or not s.glyph and leaderCount-glyphCount >= limits.Leaders-limits.GlyphReserve then return end
  if random(s) > clamp(sample(e, "0x8c", s.progress, nil, 1), 0, 1) then return end
  local seed = random(s)
  local life = word(leader, "0x8c")
  if flag(word(leader, "0x100"), 0x20000) then life = life+frac(seed*10)*word(leader, "0x90") end
  if life <= lag then return end
  local p
  for i = 1, #s.pool do if not s.pool[i].active then p = s.pool[i]; break end end
  if not p then p = {history = not leader.NoHistory and newHistory(t) or nil}; s.pool[#s.pool+1] = p end
  local component = leader.Component or {}
  local x, y, z = shape(s, component)
  -- Shape flag2 independently chooses whether the component matrix affects
  -- the sampled position. The CP0 basis and length conversion always apply.
  local ox, oy, oz = nativeVector(instance, flag(component.Flags, 2) and component or nil, x, y, z, true)
  local bx, by, bz = origin(instance, component)
  local sourceIndex = word(e, "0x160", -1)
  if sourceIndex >= 0 then
    local source = instance.components[sourceIndex]
    if not source or source.count <= 0 then return end
    -- Native006D9770 chooses uniformly from the active component's particles
    -- and returns position-velocity*birthlag. Pool holes never become sources.
    local wanted = floor(random(s)*source.count)+1
    for _, candidate in ipairs(source.pool) do
      if candidate.active then
        wanted = wanted-1
        if wanted == 0 then bx,by,bz=candidate.x-candidate.vx*lag,
          candidate.y-candidate.vy*lag,candidate.z-candidate.vz*lag; break end
      end
    end
  elseif instance.surfaceOwner then
    bx, by, bz = surfacePosition(instance, s)
    if not bx then return end
  end
  if not flag(bits, 0x10) then
    local backdate = lag/max(.000001, instance.step)
    bx,by,bz = bx-instance.dx*backdate,by-instance.dy*backdate,bz-instance.dz*backdate
  end
  p.x, p.y, p.z = bx+ox, by+oy, bz+oz
  local input = clamp(s.progress-lag/max(0.000001, word(e, "0x134")), 0, 1)
  local ax = pi*(sample(e, "0x1c", input, 1)+(2*random(s)-1)*sample(e, "0x54", input, 1))
  local ay = pi*(sample(e, "0x1c", input, 2)+(2*random(s)-1)*sample(e, "0x54", input, 2))
  local az = pi*(sample(e, "0x1c", input, 3)+(2*random(s)-1)*sample(e, "0x54", input, 3))
  local vx, vy, vz = sin(ay)*cos(ax), -sin(ax), cos(ay)*cos(ax)
  vx, vy = vx*cos(az)-vy*sin(az), vx*sin(az)+vy*cos(az)
  local speed = sample(e, "0x0", input)*(1-random(s)*sample(e, "0x38", input))
  vx, vy, vz = nativeVector(instance, component, vx*speed, vy*speed, vz*speed, true)
  if flag(bits, 0x1000) then
    local dt = max(0.000001, instance.step)
    local inherited = word(e, "0x144", 1)/dt
    vx, vy, vz = vx+instance.dx*inherited, vy+instance.dy*inherited, vz+instance.dz*inherited
  end
  p.vx, p.vy, p.vz = vx, vy, vz
  p.life, p.age, p.born, p.active = life, lag, time-lag, true
  p.seed, p.appearanceSeed, p.atlasSeed = seed*2*pi, seed, seed
  p.atlasBits = nil
  if not flag(word(leader, "0x100"), 0x04000000) then
    p.x, p.y, p.z = p.x+vx*lag, p.y+vy*lag, p.z+vz*lag
  end
  s.count, leaderCount = s.count+1, leaderCount+1
  if s.glyph then glyphCount=glyphCount+1 end
  local sx, sy, sz = nativeVector(instance, component, 1, 0, 0, false)
  if p.history then resetHistory(p.history, p.x, p.y, p.z, sx, sy, sz, time-lag) end
end
local function noise(x, y, z, phase)
  -- Smooth, bounded Source-side field. Original E0/28 strength, native
  -- coordinate frequency and separate time phase are retained. The native
  -- lattice/noise implementation is not claimed to match this field.
  return sin(x+sin(y*0.79+phase)), sin(y+sin(z*0.83+phase)), sin(z+sin(x*0.91+phase))
end
local function move(instance, s, p, dt, time)
  local leader, e = s.template.Leader, s.template.Leader.Emitter
  local bits, scale = word(e, "0x170"), instance.scale
  local delta = dt*(flag(bits, 8) and word(e, "0x140", 1) or 1)
  p.age = p.age+delta
  local particleBits = word(leader, "0x100")
  local frozen = flag(particleBits, 0x04000000)
  if p.age > p.life then
    -- Native006D60A0 drops overshoot, and its varied-life branch wraps even
    -- after owner expiry. The Source instance still has a bounded stop drain.
    local nativeActive = not instance.stopped and (instance.loop or instance.clock <= instance.duration)
    if frozen and (flag(particleBits, 0x20000) or nativeActive) then p.age=0
    else release(s, p); return end
  end
  local age = p.age/p.life
  if flag(bits, 0x10) then
    if flag(bits, 0x20000) then
      local x,y,z = rotateFollow(instance,p.x-s.oldX,p.y-s.oldY,p.z-s.oldZ)
      p.x,p.y,p.z = s.originX+x,s.originY+y,s.originZ+z
      p.vx,p.vy,p.vz = rotateFollow(instance,p.vx,p.vy,p.vz)
    else p.x,p.y,p.z = p.x+s.dx,p.y+s.dy,p.z+s.dz end
  end
  if not frozen then
  p.x, p.y, p.z = p.x+p.vx*delta, p.y+p.vy*delta, p.z+p.vz*delta
  local ax, ay, az = 0, 0, 0
  if flag(bits, 0x400000) then
    ax, ay, az = nativeVector(instance, flag(bits, 0x800000) and nil or leader.Component,
      sample(e, "0xc4", age, 1), sample(e, "0xc4", age, 2), sample(e, "0xc4", age, 3), true)
  else
    local force = sample(e, "0xa8", age)*scale
    if flag(bits, 0x800) then
      -- The higher-level native external-attractor callback is unresolved;
      -- Source explicitly supplies this effect's CP0 as its attraction point.
      ax, ay, az = unit(instance.x-p.x, instance.y-p.y, instance.z-p.z)
      ax, ay, az = ax*force, ay*force, az*force
    elseif flag(bits, 0x400) then
      -- Regular native configured-force uses environmental up. Source's
      -- environment has no rotated gravity, so native +Y is world -Z.
      ax, ay, az = word(e, "0x12c")*force, -word(e, "0x124")*force, -word(e, "0x128")*force
    end
  end
  if flag(bits, 0x80) then
    local frequency = word(e, "0x148", 1)/scale
    local nx, ny, nz = noise(p.x*frequency, p.y*frequency, p.z*frequency, p.seed+time)
    local strength = sample(e, "0xe0", age)*scale
    ax, ay, az = ax+nx*strength, ay+ny*strength, az+nz*strength
  end
  p.vx, p.vy, p.vz = p.vx+ax*delta, p.vy+ay*delta, p.vz+az*delta
  if flag(bits, 0x100) or flag(bits, 0x200) then
    local drag = sample(e, "0xfc", age)
    if flag(bits, 0x100) then
      drag = drag*(sample(leader, "0x38", age, 1)+sample(leader, "0x38", age, 2))*0.5
    end
    local g = max(0, 1-drag/30)
    local denominator = 30*delta+g-30*delta*g
    local retention = denominator > 0 and g/denominator or 0
    -- Unknown external wind/drift input is explicitly zero in this host.
    p.vx, p.vy, p.vz = p.vx*retention, p.vy*retention, p.vz*retention
  end
  end
  local h = p.history
  if not h then return end
  if time-h.born > word(s.template, "0x134") then h.alive = false; h.count = 0 end
  local sx, sy, sz = nativeVector(instance, leader.Component, 1, 0, 0, false)
  record(h, p.x, p.y, p.z, sx, sy, sz, time, scale)
end
prewarm = function(instance,time)
  -- Native006D9490/006D95D0 fills on first-enable/visibility re-enable, not
  -- every controller loop. Capacity bounds apply before any birth allocation.
  for _,s in ipairs(instance.states) do
    if s.template.Leader then
      local leader,e=s.template.Leader,s.template.Leader.Emitter
      local duration=word(e,"0x134")
      local life=word(leader,"0x8c")+(flag(word(leader,"0x100"),0x20000) and word(leader,"0x90") or 0)
      local rate=max(0,sample(e,"0x70",s.progress))
      if duration>0 and life>0 and rate>0 then
        for _,p in ipairs(s.pool) do release(s,p);if p.history then p.history.count=0 end end
        s.burst=false
        local offset,windows=0,0
        repeat
          local window=instance.duration<=duration and life or min(duration,life)
          local total=rate*window
          local attempts=floor(total)
          s.accumulator=total-attempts
          for i=1,min(attempts,limits.PerEmitter) do
            birth(instance,s,time,(attempts-i+s.accumulator)/rate+offset)
          end
          windows=windows+1;offset=offset+instance.duration
        until instance.duration<=duration or offset>=life or instance.duration<=0 or windows>=limits.PerEmitter
      end
    end
  end
end
local function step(instance, time, view, distance)
  if instance.dead then return end
  if not aliveOwner(instance) then instance.dead = true; clear(instance); return end
  local raw = time-instance.last
  if raw <= 0 then return end
  local dt = min(raw, limits.MaxStep)*instance.playbackRate
  -- Simulation pauses use CurTime. An actual long client hitch cannot queue
  -- unbounded births or preserve several seconds of stale leader movement.
  if raw > limits.MaxStep then clear(instance) end
  instance.last, instance.step = time, dt
  instance.dx, instance.dy, instance.dz = instance.x-(instance.prevX or instance.x),
    instance.y-(instance.prevY or instance.y), instance.z-(instance.prevZ or instance.z)
  local far = view and ((instance.x-view.x)^2+(instance.y-view.y)^2+(instance.z-view.z)^2 > distance^2)
  if far then
    if not instance.culled then clear(instance) end
    instance.culled = true
  elseif instance.culled then
    instance.culled = false
    for _, s in ipairs(instance.states) do if s.history then s.history.count = 0 end end
    if instance.prewarm and not instance.stopped then prewarm(instance,time) end
  end
  instance.clock = instance.clock+raw*instance.playbackRate
  if instance.loop and not instance.stopped and instance.duration > 0 and instance.clock > instance.duration then
    instance.clock = dt -- Native FXET restart discards its overshoot.
    for _, s in ipairs(instance.states) do
      -- Native006D6CE0 preserves fractional accumulatorBC across restarts.
      -- Resetting it would suppress authored slow-rate glows forever.
      s.progress, s.burst = 0, false
      if s.history then s.history.born = time end
    end
  end
  local live, pending = false, false
  for _, s in ipairs(instance.states) do
    local t = s.template
    if t.Leader then
      local leader, e = t.Leader, t.Leader.Emitter
      local delay = leader.Component and leader.Component.Delay or 0
      local duration = word(e, "0x134")
      local delta = dt*(flag(word(e, "0x170"), 8) and word(e, "0x140", 1) or 1)
      s.originX,s.originY,s.originZ = origin(instance,leader.Component)
      s.oldX,s.oldY,s.oldZ = previousOrigin(instance,leader.Component)
      s.dx,s.dy,s.dz = s.originX-s.oldX,s.originY-s.oldY,s.originZ-s.oldZ
      -- Birth catch-up already includes its lag. Advance the existing pool
      -- first so newly created particles are never integrated twice.
      for _, p in ipairs(s.pool) do if p.active then move(instance, s, p, dt, time) end end
      if instance.clock > delay and duration > 0 then
        s.progress = s.progress+delta/duration
        if not instance.stopped and not instance.culled and s.progress < 1 then
          if flag(word(e, "0x170"), 0x20) then
            if not s.burst then
              s.burst = true
              for _ = 1, min(limits.PerEmitter, leader.SourceCapacity or limits.PerEmitter,
                max(0, word(e, "0x15c")-s.count)) do birth(instance, s, time, delta) end
            end
          else
            local rate = max(0, sample(e, "0x70", s.progress))
            s.accumulator = s.accumulator+rate*delta
            local attempts = floor(s.accumulator)
            s.accumulator = s.accumulator-attempts
            for attempt = 1, min(attempts, limits.PerEmitter) do
              birth(instance, s, time, rate > 0 and (attempts-attempt+s.accumulator)/rate or 0)
            end
          end
        end
      end
      pending = pending or not instance.stopped and not instance.culled and duration > 0
        and s.progress < 1 and (not flag(word(e, "0x170"), 0x20) or not s.burst)
      live = live or s.count > 0
    else
      local h = s.history
      if not instance.stopped and not instance.culled and instance.clock > (t.Component.Delay or 0) then
        local x, y, z = origin(instance, t.Component)
        local sx, sy, sz = nativeVector(instance, t.Component, 1, 0, 0, false)
        record(h, x, y, z, sx, sy, sz, time, instance.scale)
      end
      if not instance.loop and time-h.born > word(t, "0x134") then h.count = 0; h.alive = false end
      live = live or h.count > 1
    end
  end
  if instance.stopped and (not live or time-instance.stopTime > instance.drain) then instance.dead = true; clear(instance) end
  if not instance.loop and instance.clock > instance.duration and not live and not pending then instance.dead = true; clear(instance) end
  rememberBasis(instance)
end
function R.Think(time, view)
  time = time or nowTime()
  view = view or EyePos()
  local distance = cullDistance()
  for i = #active, 1, -1 do
    local instance = active[i]
    step(instance, time, view, distance)
    if instance.dead then
      if instance.glyph then glyphInstances=glyphInstances-1 end
      active[i] = active[#active]; active[#active] = nil
    end
  end
end
local function floatSeedBits(seed)
  -- Native 6D331A..6D334B passes the IEEE float bits as the random start,
  -- independently of the same seed's floating-point rate variation.
  if not seed or seed <= 0 then return 0 end
  local mantissa, exponent = math.frexp(seed)
  local significand = mantissa*16777216
  local rounded = floor(significand)
  local remainder = significand-rounded
  if remainder > .5 or remainder == .5 and rounded % 2 ~= 0 then rounded = rounded+1 end
  return rounded+(exponent+125)*8388608
end
local function atlas(t, age, life, seed, seedBits)
  local a = t.Atlas
  local frames = a and a.Frames
  if not frames or #frames == 0 then return 0, 0, 1, 1, 0, 0, 1, 1, 0 end
  local index, nextIndex, blend = 1, 1, 0
  if a.CurveDriven then
    local variation = a.RateVariation or 1
    local factor = seed and seed > 0 and seed < 1 and (1-seed)*variation+seed or variation
    local location = max(0, curve(a.FrameCurve, age, 1)*factor*(life or 1))
    local frame = floor(location)
    if a.Loop then
      local start = a.RandomStart and (seedBits or floatSeedBits(seed)) or 0
      index, nextIndex = (frame+start) % #frames+1, (frame+start+1) % #frames+1
    else
      index, nextIndex = min(frame, #frames-1)+1, min(frame+1, #frames-1)+1
    end
    blend = a.FrameBlend and frac(location) or 0
  else
    for i = #frames, 2, -1 do if age >= frames[i][5] then index = i; break end end
    nextIndex = min(index+1, #frames)
    if a.FrameBlend and nextIndex ~= index then
      local span = frames[nextIndex][5]-frames[index][5]
      blend = span > 0 and clamp((age-frames[index][5])/span, 0, 1) or 0
    end
  end
  if not a.FrameBlend or nextIndex == index then nextIndex, blend = index, 0 end
  local f, n = frames[index], frames[nextIndex]
  if f[1] == n[1] and f[2] == n[2] and f[3] == n[3] and f[4] == n[4] then blend = 0 end
  return f[1], f[2], f[3], f[4], n[1], n[2], n[3], n[4], blend
end
local function submit(x, y, z, r, g, b, a, u, v)
  vertex.x, vertex.y, vertex.z = x, y, z
  mesh.Position(vertex); mesh.Color(r, g, b, a); mesh.TexCoord(0, u, v); mesh.AdvanceVertex()
end
local function rgba(t, key, phase, alpha, remap)
  local scale = t.ColorScale or 1
  -- Per-instance Source appearance override. Native curves/textures and their
  -- HDR scale stay intact; the General retreat swaps red/blue only here.
  return clamp(sample(t, key, phase, remap and remap[1] or 1, 1)/scale, 0, 1)*255,
    clamp(sample(t, key, phase, remap and remap[2] or 2, 1)/scale, 0, 1)*255,
    clamp(sample(t, key, phase, remap and remap[3] or 3, 1)/scale, 0, 1)*255,
    clamp(sample(t, key, phase, 4, 1)*alpha, 0, 1)*255
end
local function historyPhase(h, p, time, scale)
  if flag(word(h.template, "0x14c"), 1) then return (h.distance-p.distance)/max(0.000001, word(h.template, "0x128")*scale) end
  return (time-p.time)/max(0.000001, word(h.template, "0x130"))
end
local function appearance(instance, h, p, nextP, history, whole, occupied, view, time)
  local t, bits = h.template, word(h.template, "0x14c")
  local domain = flag(bits, 0x80) and whole or history
  local displacement = flag(bits, 0x800) and history/max(0.000001, occupied) or domain
  local x, y, z = p.x, p.y, p.z
  if flag(bits, 2) then
    local a, b, c = nativeVector(instance, t.Component, word(t, "0x1c"), word(t, "0x20"), word(t, "0x24"), true)
    local amount = sample(t, "0x0", displacement)
    x, y, z = x+a*amount, y+b*amount, z+c*amount
  end
  if flag(bits, 4) then
    local nativeScale = word(t, "0x44", 1)/instance.scale
    local nx, ny, nz = noise(x*nativeScale, y*nativeScale, z*word(t, "0x48", 1)/instance.scale, time*word(t, "0x4c"))
    local amplitude = sample(t, "0x28", displacement)*instance.scale
    x, y, z = x+nx*amplitude, y+ny*amplitude, z+nz*amplitude
  end
  local sx, sy, sz = unit(p.sx, p.sy, p.sz)
  local suppression = 1
  if flag(bits, 0x10) then
    local tx, ty, tz = unit(nextP.x-p.x, nextP.y-p.y, nextP.z-p.z)
    local vx, vy, vz = unit(view.x-x, view.y-y, view.z-z)
    local length
    sx, sy, sz, length = unit(ty*vz-tz*vy, tz*vx-tx*vz, tx*vy-ty*vx)
    if flag(bits, 0x4000) then suppression = clamp(length*10, 0, 1) end
  end
  local width = sample(t, "0xe8", domain)*instance.scale
  if flag(bits, 0x400) then
    local coefficient = word(t, "0x120")
    local sign = coefficient < 0 and -1 or coefficient > 0 and 1 or 0
    width = width*sample(t, "0x104", frac((sign+whole)*coefficient+history*word(t, "0x124")))
  end
  local distance = sqrt((view.x-x)^2+(view.y-y)^2+(view.z-z)^2)/instance.scale
  local alpha = sample(t, "0xcc", whole, nil, 1)*suppression
  if flag(bits, 0x20) and distance < word(t, "0x140") then
    local d = word(t, "0x140")-word(t, "0x13c")
    alpha = alpha*(d ~= 0 and clamp((distance-word(t, "0x13c"))/d, 0, 1) or 0)
  end
  if flag(bits, 0x40) and distance > word(t, "0x144") then
    local d = word(t, "0x144")-word(t, "0x148")
    alpha = alpha*(d ~= 0 and clamp((distance-word(t, "0x148"))/d, 0, 1) or 0)
  end
  local r, g, b, a = rgba(t, "0xb0", history, alpha, instance.sourceColorRemap)
  return x, y, z, sx*width*0.5, sy*width*0.5, sz*width*0.5, r, g, b, a
end
local endpoint = {}
local function historySegments(instance, h, time, budget)
  if h.count < 1 or not h.alive then return 0 end
  local first = 1
  while first <= h.count and historyPhase(h, point(h, first), time, instance.scale) > 1 do first = first+1 end
  h.cropIndex = nil
  -- Preserve a fractional oldest edge at exactly the authored history span;
  -- dropping the whole expired sample instead would shorten the ribbon in
  -- visible .4m/.02s jumps.
  if first > 1 and first <= h.count then
    local a, b, p = point(h, first-1), point(h, first), h.boundary
    local ah, bh = historyPhase(h, a, time, instance.scale), historyPhase(h, b, time, instance.scale)
    local f = clamp((ah-1)/max(0.000001, ah-bh), 0, 1)
    p.x,p.y,p.z = a.x+(b.x-a.x)*f, a.y+(b.y-a.y)*f, a.z+(b.z-a.z)*f
    p.sx,p.sy,p.sz = a.sx+(b.sx-a.sx)*f, a.sy+(b.sy-a.sy)*f, a.sz+(b.sz-a.sz)*f
    p.time,p.distance = a.time+(b.time-a.time)*f, a.distance+(b.distance-a.distance)*f
    first = first-1; h.cropIndex = first
  end
  return max(0, min(budget, h.count-first+1)), first
end
local function renderHistorySegment(instance, h, i, time, view)
  endpoint.x, endpoint.y, endpoint.z, endpoint.sx, endpoint.sy, endpoint.sz = h.x, h.y, h.z, h.sx, h.sy, h.sz
  endpoint.distance, endpoint.time = h.distance, time
  local t, whole = h.template, clamp((time-h.born)/max(0.000001, word(h.template, "0x134")), 0, 1)
  local occupied = historyPhase(h, h.cropIndex == h.drawFirst and h.boundary or point(h, h.drawFirst), time, instance.scale)
  local u0, v0, u1, v1 = atlas(t, whole, word(t, "0x134"))
  local scroll = word(t, "0xac")*whole
    local p, q = h.cropIndex == i and h.boundary or point(h, i), i < h.count and point(h, i+1) or endpoint
    local ph, qh = clamp(historyPhase(h, p, time, instance.scale), 0, 1),
      clamp(historyPhase(h, q, time, instance.scale), 0, 1)
    local x, y, z, sx, sy, sz, r, g, b, a = appearance(instance, h, p, q, ph, whole, occupied, view, time)
    -- Endpoint tangent looks backwards; reversing its side avoids a twist.
    local qx, qy, qz, qsx, qsy, qsz, qr, qg, qb, qa = appearance(instance, h, q, p, qh, whole, occupied, view, time)
    if flag(word(t, "0x14c"), 0x10) then qsx, qsy, qsz = -qsx, -qsy, -qsz end
    local pu, qu = u0+(u1-u0)*ph+scroll, u0+(u1-u0)*qh+scroll
    submit(x-sx, y-sy, z-sz, r, g, b, a, pu, v0)
    submit(x+sx, y+sy, z+sz, r, g, b, a, pu, v1)
    submit(qx+qsx, qy+qsy, qz+qsz, qr, qg, qb, qa, qu, v1)
    submit(x-sx, y-sy, z-sz, r, g, b, a, pu, v0)
    submit(qx+qsx, qy+qsy, qz+qsz, qr, qg, qb, qa, qu, v1)
    submit(qx-qsx, qy-qsy, qz-qsz, qr, qg, qb, qa, qu, v0)
end
local function spriteFrame(s, p)
  local t = s.template.Leader
  if not p.atlasBits then p.atlasBits = floatSeedBits(p.atlasSeed) end
  p.u0,p.v0,p.u1,p.v1,p.u2,p.v2,p.u3,p.v3,p.frameBlend = atlas(t, p.age/p.life, word(t, "0x8c"), p.atlasSeed, p.atlasBits)
  return p.frameBlend > 0 and p.frameBlend < 1 and 2 or 1
end
local function spriteQuad(p, rx, ry, rz, ux, uy, uz, r, g, b, a, u0, v0, u1, v1)
  submit(p.x-rx-ux, p.y-ry-uy, p.z-rz-uz, r, g, b, a, u0, v1)
  submit(p.x-rx+ux, p.y-ry+uy, p.z-rz+uz, r, g, b, a, u0, v0)
  submit(p.x+rx+ux, p.y+ry+uy, p.z+rz+uz, r, g, b, a, u1, v0)
  submit(p.x-rx-ux, p.y-ry-uy, p.z-rz-uz, r, g, b, a, u0, v1)
  submit(p.x+rx+ux, p.y+ry+uy, p.z+rz+uz, r, g, b, a, u1, v0)
  submit(p.x+rx-ux, p.y+ry-uy, p.z+rz-uz, r, g, b, a, u1, v1)
end
local function velocityQuad(t, p, width, height, meanNativeSize, forward, result)
  local q = result or {}
  local vx,vy,vz = p.vx,p.vy,p.vz
  local length = sqrt(vx*vx+vy*vy+vz*vz)
  local ax,ay,az,sx,sy,sz = 0,0,0,0,0,0
  if length > 0 then
    ax,ay,az = vx/length,vy/length,vz/length
    sx,sy,sz = ay*forward.z-az*forward.y,az*forward.x-ax*forward.z,ax*forward.y-ay*forward.x
    local side = sqrt(sx*sx+sy*sy+sz*sz)
    if side > 0 then sx,sy,sz = sx/side,sy/side,sz/side end
    ax,ay,az,sx,sy,sz = ax*width,ay*width,az*width,sx*height,sy*height,sz*height
  end
  local bits = word(t,"0x100")
  local sweep = word(t,"0x94")
  if not flag(bits,8) then sweep=min(p.age,sweep) end
  if flag(bits,4) then sweep=sweep*meanNativeSize end
  local tailX,tailY,tailZ = vx*sweep,vy*sweep,vz*sweep
  if flag(bits,8) then ax,ay,az=ax+tailX*.5,ay+tailY*.5,az+tailZ*.5;tailX,tailY,tailZ=0,0,0 end
  local px,py,pz = ax*word(t,"0xf0")+sx*word(t,"0xf4"),
    ay*word(t,"0xf0")+sy*word(t,"0xf4"),az*word(t,"0xf0")+sz*word(t,"0xf4")
  q[1],q[2],q[3] = p.x-tailX-ax+sx-px,p.y-tailY-ay+sy-py,p.z-tailZ-az+sz-pz
  q[4],q[5],q[6] = p.x+ax+sx-px,p.y+ay+sy-py,p.z+az+sz-pz
  q[7],q[8],q[9] = p.x+ax-sx-px,p.y+ay-sy-py,p.z+az-sz-pz
  q[10],q[11],q[12] = p.x-tailX-ax-sx-px,p.y-tailY-ay-sy-py,p.z-tailZ-az-sz-pz
  return q
end
local function submitVelocity(q,r,g,b,a,u0,v0,u1,v1)
  submit(q[1],q[2],q[3],r,g,b,a,u0,v0)
  submit(q[4],q[5],q[6],r,g,b,a,u1,v0)
  submit(q[7],q[8],q[9],r,g,b,a,u1,v1)
  submit(q[1],q[2],q[3],r,g,b,a,u0,v0)
  submit(q[7],q[8],q[9],r,g,b,a,u1,v1)
  submit(q[10],q[11],q[12],r,g,b,a,u0,v1)
end
local function renderLeader(instance, s, p, view, up, right, forward)
  local t, phase = s.template.Leader, p.age/p.life
  local extent = 1-p.appearanceSeed*sample(t, "0x70", phase)
  local width = sample(t, "0x38", phase, 1)*instance.scale*extent
  local height = sample(t, "0x38", phase, 2)*instance.scale*extent
  local meanNativeSize = (width+height)*.5/instance.scale
  if flag(word(t, "0x100"), 0x2000000) and p.v1 ~= p.v0 then
    width = width*(p.u1-p.u0)/(p.v1-p.v0)
  end
  local roll = sample(t, "0x54", phase)*2*pi
  local rightX,rightY,rightZ,upX,upY,upZ = right.x,right.y,right.z,up.x,up.y,up.z
  if t.PlaneAxes then
    -- FXPT+0x100 fixed-plane flags select native frame columns. Convert those
    -- dimensionless directions through the component and host frame once.
    local a, b = t.PlaneAxes[1], t.PlaneAxes[2]
    rightX,rightY,rightZ = nativeVector(instance,t.Component,a[1],a[2],a[3],false)
    upX,upY,upZ = nativeVector(instance,t.Component,b[1],b[2],b[3],false)
  elseif t.GroundPlane then
    -- Keep the ground symbol tangent to the surface, independent of the camera.
    rightX,rightY,rightZ = instance.fx,instance.fy,instance.fz
    upX,upY,upZ = instance.lx,instance.ly,instance.lz
  end
  local c, sn = cos(roll), sin(roll)
  local rx, ry, rz = (rightX*c+upX*sn)*width, (rightY*c+upY*sn)*width, (rightZ*c+upZ*sn)*width
  local ux, uy, uz = (upX*c-rightX*sn)*height, (upY*c-rightY*sn)*height, (upZ*c-rightZ*sn)*height
  local r, g, b, a = rgba(t, "0x0", phase, 1, instance.sourceColorRemap)
  local u0,v0,u1,v1,u2,v2,u3,v3 = p.u0,p.v0,p.u1,p.v1,p.u2,p.v2,p.u3,p.v3
  local bits = word(t, "0x100")
  if flag(bits, 0x80) and p.appearanceSeed > .5 then u0,u1,u2,u3 = u1,u0,u3,u2 end
  if flag(bits, 0x100) and p.appearanceSeed > .25 and p.appearanceSeed <= .75 then v0,v1,v2,v3 = v1,v0,v3,v2 end
  -- Two alpha-over quads are the explicit Source adaptation for mode1's
  -- native dual-UV shader. Identical sampled rectangles already use one quad.
  if flag(bits,2) then
    p.quad = velocityQuad(t,p,width,height,meanNativeSize,forward,p.quad)
    if p.frameBlend < 1 then submitVelocity(p.quad,r,g,b,a*(1-p.frameBlend),u0,v0,u1,v1) end
    if p.frameBlend > 0 then submitVelocity(p.quad,r,g,b,a*p.frameBlend,u2,v2,u3,v3) end
  else
    if p.frameBlend < 1 then spriteQuad(p, rx,ry,rz, ux,uy,uz, r,g,b,a*(1-p.frameBlend), u0,v0,u1,v1) end
    if p.frameBlend > 0 then spriteQuad(p, rx,ry,rz, ux,uy,uz, r,g,b,a*p.frameBlend, u2,v2,u3,v3) end
  end
end
local alphaItems, glyphAlpha, additive, glyphAdditive = {}, {}, {}, {}
local alphaCount, glyphAlphaCount, additiveOrder, glyphOrder = 0,0,{},{}
local function clearBuckets(order)
  for index=#order,1,-1 do
    local bucket=order[index]
    for i=1,bucket.count do bucket.items[i]=nil end
    bucket.count,bucket.quads=0,0;order[index]=nil
  end
end
clearDrawQueue = function()
  for i=1,alphaCount do alphaItems[i]=nil end
  for i=1,glyphAlphaCount do glyphAlpha[i]=nil end
  clearBuckets(additiveOrder);clearBuckets(glyphOrder)
  alphaCount,glyphAlphaCount=0,0
end
local function queueItem(item, path, mode, glyph)
  item.drawMaterial=path
  if mode~=5 then
    if glyph then glyphAlphaCount=glyphAlphaCount+1;glyphAlpha[glyphAlphaCount]=item
    else alphaCount=alphaCount+1;alphaItems[alphaCount]=item end
  else
    local bank,order = glyph and glyphAdditive or additive,glyph and glyphOrder or additiveOrder
    local bucket=bank[path]
    if not bucket then bucket={material=path,items={},count=0,quads=0};bank[path]=bucket end
    if bucket.count==0 then order[#order+1]=bucket end
    bucket.count=bucket.count+1;bucket.items[bucket.count]=item;bucket.quads=bucket.quads+item.drawQuads
  end
end
local function drawItem(item,time,view,up,right,forward)
  if item.drawKind==1 then renderLeader(item.drawInstance,item.drawState,item,view,up,right,forward)
  else renderHistorySegment(item.drawInstance,item.drawHistory,item.drawLogical,time,view) end
end
local function collectHistory(instance,h,time,view,forward,budget,order)
  if budget<=0 then return budget,order end
  local segments,first=historySegments(instance,h,time,budget)
  h.drawFirst=first
  for i=first or 1,(first or 1)+segments-1 do
    local item=point(h,i)
    local p=h.cropIndex==i and h.boundary or item
    local q=i<h.count and point(h,i+1) or h
    item.drawKind,item.drawInstance,item.drawHistory,item.drawLogical,item.drawQuads=2,instance,h,i,1
    item.drawDepth=((p.x+q.x)*.5-view.x)*forward.x+((p.y+q.y)*.5-view.y)*forward.y
      +((p.z+q.z)*.5-view.z)*forward.z
    order=order+1;item.drawOrder=order
    queueItem(item,h.template.Material,h.template.Atlas.Mode,instance.glyph)
  end
  return budget-segments,order
end
local function sortDepth(a,b)
  if a.drawDepth==b.drawDepth then return a.drawOrder<b.drawOrder end
  return a.drawDepth>b.drawDepth
end
local function drawAlpha(items,count,time,view,up,right,forward)
  table.sort(items,sortDepth)
  local first=1
  while first<=count do
    local path,last,quads=items[first].drawMaterial,first,items[first].drawQuads
    while last<count and items[last+1].drawMaterial==path do last=last+1;quads=quads+items[last].drawQuads end
    -- Only consecutive same-material items are batched: grouping all alpha
    -- particles by material would undo their global far-to-near depth order.
    render.SetMaterial(material(path));mesh.Begin(MATERIAL_TRIANGLES,quads*2)
    for i=first,last do drawItem(items[i],time,view,up,right,forward) end
    mesh.End();first=last+1
  end
end
local function drawAdditive(order,time,view,up,right,forward)
  for _,bucket in ipairs(order) do
    render.SetMaterial(material(bucket.material));mesh.Begin(MATERIAL_TRIANGLES,bucket.quads*2)
    for i=1,bucket.count do drawItem(bucket.items[i],time,view,up,right,forward) end
    mesh.End()
  end
end
local cameraForward = Vector()
function R.Render(depth, sky)
  if depth or sky or #active == 0 then return end
  local time, view, angle = nowTime(), EyePos(), EyeAngles()
  local up, right, budget = angle:Up(), angle:Right(), limits.RenderSegments
  local pitch,yaw = angle.p*pi/180,angle.y*pi/180
  cameraForward.x,cameraForward.y,cameraForward.z=cos(pitch)*cos(yaw),cos(pitch)*sin(yaw),-sin(pitch)
  clearDrawQueue()
  local order=0
  -- Collect/render glyphs first. Both their particles and draw work survive
  -- full decorative budgets during100 simultaneous director emergence cues.
  for pass=1,2 do
  for _, instance in ipairs(active) do
    if instance.glyph==(pass==1) then
    if not instance.dead and not instance.culled then
      for _, s in ipairs(instance.states) do
        if s.history then budget,order=collectHistory(instance,s.history,time,view,cameraForward,budget,order) end
        if s.template.Leader and budget>0 then
          for _,p in ipairs(s.pool) do
            if p.active and p.history then budget,order=collectHistory(instance,p.history,time,view,cameraForward,budget,order) end
          end
          for _,p in ipairs(s.pool) do
            if p.active and budget>0 and sample(s.template.Leader,"0x0",p.age/p.life,4,1)>0 then
              local count=spriteFrame(s,p)
              if count<=budget then
                p.drawKind,p.drawInstance,p.drawState,p.drawQuads=1,instance,s,count
                p.drawDepth=(p.x-view.x)*cameraForward.x+(p.y-view.y)*cameraForward.y+(p.z-view.z)*cameraForward.z
                order=order+1;p.drawOrder=order
                queueItem(p,s.template.Leader.Material,s.template.Leader.Atlas.Mode,instance.glyph)
                budget=budget-count
              end
            end
          end
        end
      end
    end
    if budget <= 0 then break end
    end
  end
  end
  drawAlpha(glyphAlpha,glyphAlphaCount,time,view,up,right,cameraForward)
  drawAdditive(glyphOrder,time,view,up,right,cameraForward)
  drawAlpha(alphaItems,alphaCount,time,view,up,right,cameraForward)
  drawAdditive(additiveOrder,time,view,up,right,cameraForward)
end
function R.Stats() return #active, leaderCount, glyphCount end
-- These pure helpers also support the offline native-data regression fixture.
R.Curve, R.Capacity, R.Atlas, R.NativeVector = curve, capacity, atlas, nativeVector
R.VelocityQuad = velocityQuad
hook.Add("Think", "ZA1/FireVFXRibbons", function() R.Think() end)
hook.Add("PostDrawTranslucentRenderables", "ZA1/FireVFXRibbons", R.Render)
hook.Add("EntityRemoved", "ZA1/FireVFXRibbons", function(owner) R.StopOwner(owner, true) end)
hook.Add("PostCleanupMap", "ZA1/FireVFXRibbons", R.Cleanup)
hook.Add("ShutDown", "ZA1/FireVFXRibbons", R.Cleanup)
return R
