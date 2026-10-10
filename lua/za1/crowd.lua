-- Small local queries, stable attack claims, and budgeted hull probes.
local G = {Grid = {}, Buckets = {}, Targets = setmetatable({}, {__mode = "k"}), Pending = setmetatable({}, {__mode = "k"})}
ZA1.Crowd = G
local C, M, N = ZA1.Config.Crowd, ZA1.Manager, ZA1.Navigation
G.Stats = {candidates = 0, neighbors = 0, probes = 0, yields = 0, slots = 0}
local function ID(z) return z:EntIndex() end
local attackOffsets, waitingOffsets = {}, {}
local offsetSlots, offsetRadius, waitingRadius
local function Offsets()
    if offsetSlots ~= C.AttackSlots or offsetRadius ~= C.AttackRadius then
        offsetSlots, offsetRadius, attackOffsets = C.AttackSlots, C.AttackRadius, {}
        for slot = 1, offsetSlots do
            local angle = (slot - 1) * math.pi * 2 / offsetSlots
            attackOffsets[slot] = {x = math.cos(angle) * offsetRadius, y = math.sin(angle) * offsetRadius}
        end
    end
    if waitingRadius ~= C.WaitingRadius then
        waitingRadius, waitingOffsets = C.WaitingRadius, {}
        for index = 0, 15 do
            local angle = index * math.pi / 8
            waitingOffsets[index] = {x = math.cos(angle) * waitingRadius, y = math.sin(angle) * waitingRadius}
        end
    end
end
Offsets()
function G.ReleaseClaim(z)
    if not IsValid(z) then G.Pending[z] = nil; return end
    local claim = z.ZAAttackClaim
    if claim and G.Targets[claim.target] and G.Targets[claim.target].slots[claim.slot] == z then
        G.Targets[claim.target].slots[claim.slot] = nil
    end
    z.ZAAttackClaim = nil
    if G.Pending[z] and G.Pending[z].kind == "slot" then G.Pending[z] = nil end
end
function G.Release(z)
    G.Pending[z] = nil
    if not IsValid(z) then return end
    G.ReleaseClaim(z)
    z.ZASteerPoint, z.ZARecoveryGoal, z.ZAYieldUntil = nil, nil, nil
    G.Pending[z] = nil
end
function G.Hold(z)
    -- Stop avoidance/recovery during a close attack handoff, retaining the
    -- attack reservation and its pending ground probe.
    local job = G.Pending[z]
    if job and job.kind ~= "slot" then G.Pending[z] = nil end
    z.ZASteerPoint, z.ZASteerUntil = nil, nil
    z.ZARecoveryGoal, z.ZARecoveryUntil, z.ZAYieldUntil = nil, nil, nil
end
function G.Rebuild()
    for _, bucket in ipairs(G.Buckets) do for i = #bucket, 1, -1 do bucket[i] = nil end end
    for z in pairs(M.Zombies) do
        if M.Active(z) then
            local pos = z:GetPos()
            z.ZACrowdPos = Vector(pos)
            local x, y = math.floor(pos.x / C.CellSize), math.floor(pos.y / C.CellSize)
            local row = G.Grid[x]
            if not row then row = {}; G.Grid[x] = row end
            local bucket = row[y]
            if not bucket then bucket = {}; row[y] = bucket; G.Buckets[#G.Buckets + 1] = bucket end
            bucket[#bucket + 1] = z
        end
    end
    for target, state in pairs(G.Targets) do
        if not IsValid(target) then G.Targets[target] = nil
        else
            for slot, z in pairs(state.slots) do
                if not M.Active(z) or z:GetEnemy() ~= target or not z.ZAAttackClaim or z.ZAAttackClaim.expires < CurTime() then
                    state.slots[slot] = nil
                    if IsValid(z) then z.ZAAttackClaim = nil end
                end
            end
        end
    end
end
function G.Neighbors(z)
    if not M.Active(z) then return {} end
    local pos, list, visited = z:GetPos(), {}, 0
    local cx, cy = math.floor(pos.x / C.CellSize), math.floor(pos.y / C.CellSize)
    -- Own cell first; cap candidates even in a densely packed horde.
    for ring = 0, 1 do
        for x = cx - ring, cx + ring do
            local row = G.Grid[x]
            if row then
                for y = cy - ring, cy + ring do
                    if ring == 0 or x ~= cx or y ~= cy then
                        local bucket = row[y]
                        if bucket then
                            local count = #bucket
                            local offset = count > 0 and ID(z) % count or 0
                            for i = 1, count do
                                local other = bucket[(i + offset - 1) % count + 1]
                                visited = visited + 1
                                G.Stats.candidates = G.Stats.candidates + 1
                                -- Buckets live between rebuilds. A death/removal must be
                                -- rejected before reading fields or calling GetPos.
                                if other ~= z and M.Active(other) then
                                    local p = other.ZACrowdPos or other:GetPos()
                                    if math.abs(p.z - pos.z) < z.Height / 2 and p:DistToSqr(pos) < C.NeighborRadius ^ 2 then
                                        list[#list + 1] = other
                                        G.Stats.neighbors = G.Stats.neighbors + 1
                                    end
                                end
                                if visited >= C.MaxCandidates or #list >= C.MaxNeighbors then return list end
                            end
                        end
                    end
                end
            end
        end
    end
    return list
end
local function Queue(z, job)
    local old = G.Pending[z]
    if old and old.priority > job.priority then return end
    job.queued = old and old.queued or CurTime()
    G.Pending[z] = job
end
function G.AttackGoal(z, enemy)
    local perf = ZA1.Performance
    local capture = perf and perf.Capture
    local started = capture and SysTime()
    if not IsValid(enemy) then
        G.ReleaseClaim(z); local goal = z:GetPos()
        if capture then perf.RecordStage(capture, "crowd:AttackGoal.inputs", z, enemy, started) end
        return goal, false
    end
    if not M.Crowd:GetBool() or not navmesh.IsLoaded() then
        G.ReleaseClaim(z); local goal = enemy:GetPos()
        if capture then perf.RecordStage(capture, "crowd:AttackGoal.inputs", z, enemy, started) end
        return goal, true
    end
    -- One fresh position read per entity; no stale grid snapshot in combat.
    local targetPos, pos = enemy:GetPos(), z:GetPos()
    if pos:DistToSqr(targetPos) > 256 ^ 2 then
        G.ReleaseClaim(z)
        if capture then perf.RecordStage(capture, "crowd:AttackGoal.inputs", z, enemy, started) end
        return targetPos, false
    end
    local own, now = z:GetTable(), CurTime()
    if capture then perf.RecordStage(capture, "crowd:AttackGoal.inputs", z, enemy, started); started = SysTime() end
    Offsets()
    local state = G.Targets[enemy]
    if not state then state = {slots = {}, blocked = {}, position = Vector(targetPos), version = 1}; G.Targets[enemy] = state end
    if state.position:DistToSqr(targetPos) > C.TargetRefreshDistance ^ 2 then
        state.position, state.version, state.blocked = Vector(targetPos), state.version + 1, {}
    end
    local claim = own.ZAAttackClaim
    if claim and (claim.target ~= enemy or state.slots[claim.slot] ~= z) then G.ReleaseClaim(z); claim = nil end
    if not claim then
        local best, distance
        for slot = 1, C.AttackSlots do
            local owner = state.slots[slot]
            if owner then
                local active = M.Active(owner)
                local ownerClaim = active and owner:GetTable().ZAAttackClaim
                if not ownerClaim or ownerClaim.expires < now then state.slots[slot], owner = nil, nil end
            end
            if not owner and now >= (state.blocked[slot] or 0) then
                -- Compare coordinates, creating a Vector only for the chosen
                -- queued/returned goal. Keep height in the distance calculation.
                local offset = attackOffsets[slot]
                local dx, dy, dz = pos.x - targetPos.x - offset.x, pos.y - targetPos.y - offset.y, pos.z - targetPos.z
                local square = dx * dx + dy * dy + dz * dz
                if not distance or square < distance then best, distance = slot, square end
            end
        end
        if best then
            claim = {target = enemy, slot = best, expires = now + C.SlotLifetime}
            own.ZAAttackClaim, state.slots[best] = claim, z
            G.Stats.slots = G.Stats.slots + 1
        end
    end
    if capture then perf.RecordStage(capture, "crowd:AttackGoal.claims", z, enemy, started); started = SysTime() end
    if claim then
        claim.expires = now + C.SlotLifetime
        if claim.version ~= state.version and not G.Pending[z] then
            local offset = attackOffsets[claim.slot]
            if not offset then
                -- A live settings edit can leave an older claim beyond the
                -- new slot count; preserve its original angular placement.
                local angle = (claim.slot - 1) * math.pi * 2 / C.AttackSlots
                offset = {x = math.cos(angle) * C.AttackRadius, y = math.sin(angle) * C.AttackRadius}
                attackOffsets[claim.slot] = offset
            end
            Queue(z, {kind = "slot", priority = 3, claim = claim, version = state.version,
                position = Vector(targetPos.x + offset.x, targetPos.y + offset.y, targetPos.z)})
        end
        if capture then perf.RecordStage(capture, "crowd:AttackGoal.queue", z, enemy, started); started = SysTime() end
        if claim.position and claim.version == state.version then return claim.position, true end
    end
    -- Stable outer waiting positions leave the attack ring open.
    local offset = waitingOffsets[ID(z) % 16]
    local goal = Vector(targetPos.x + offset.x, targetPos.y + offset.y, targetPos.z)
    if capture then perf.RecordStage(capture, "crowd:AttackGoal.waiting", z, enemy, started) end
    return goal, false
end
function G.Steer(z, path, directGoal)
    if not M.Crowd:GetBool() then z.ZASteerPoint = nil; return end
    if CurTime() >= (z.ZANextCrowdProbe or 0) then
        z.ZANextCrowdProbe = CurTime() + C.ProbeInterval + (ID(z) % 5) * 0.01
        local point = directGoal
        if not point then
            local current = path:GetCurrentGoal()
            if not current or current.type ~= 0 then z.ZASteerPoint = nil; return end
            point = current.pos
        end
        if math.abs(point.z - z:GetPos().z) > z.loco:GetStepHeight() then z.ZASteerPoint = nil; return end
        local direction = point - z:GetPos(); direction.z = 0
        if direction:LengthSqr() == 0 then return end
        direction = direction:GetNormalized()
        local side, separation, crowded = Vector(-direction.y, direction.x, 0), 0, false
        for _, other in ipairs(G.Neighbors(z)) do
            local delta = (other.ZACrowdPos or other:GetPos()) - z:GetPos(); delta.z = 0
            local distance = delta:Length2D()
            if distance < C.SeparationDistance then
                crowded = true
                local lateral = side:Dot(delta)
                local sign = lateral == 0 and (ID(z) < ID(other) and -1 or 1) or lateral > 0 and -1 or 1
                separation = separation + sign * (1 - distance / C.SeparationDistance)
                local ahead = direction:Dot(delta)
                -- One actor yields. The deterministic tie-break prevents mutual deadlock.
                if ahead > 0 and math.abs(lateral) < z.Width * 1.5
                    and (direction:Dot(other:GetForward()) > 0.5 or ID(z) > ID(other)) and not other.ZAActing then
                    z.ZAYieldUntil = CurTime() + C.YieldDuration
                    G.Stats.yields = G.Stats.yields + 1
                end
            end
        end
        if crowded and math.abs(separation) > 0.05 then
            Queue(z, {kind = "steer", priority = 0, position = z:GetPos() + direction * 36 + side * math.Clamp(separation * C.SteeringDistance, -C.SteeringDistance, C.SteeringDistance)})
        else z.ZASteerPoint = nil end
    end
    if z.ZASteerPoint and CurTime() < (z.ZASteerUntil or 0) and z:GetPos():DistToSqr(z.ZASteerPoint) > 8 ^ 2 then return z.ZASteerPoint end
end
function G.Recover(z)
    if G.Pending[z] and G.Pending[z].priority > 2 then return end
    local angle = math.rad(z:GetAngles().y + (ID(z) % 2 == 0 and 90 or -90))
    Queue(z, {kind = "recover", priority = 2, position = z:GetPos() + Vector(math.cos(angle), math.sin(angle), 0) * ZA1.Config.Navigation.RecoveryDistance})
end
local function Probe(z, job)
    local area = N.Area(job.position)
    if not area or area:IsBlocked() or not z.loco:IsAreaTraversable(area) then return end
    local pos = area:GetClosestPointOnArea(job.position)
    if pos:DistToSqr(job.position) > 32 ^ 2 or math.abs(pos.z - z:GetPos().z) > z.loco:GetStepHeight() then return end
    if job.kind == "slot" then
        local target = job.claim.target
        if not IsValid(target) or z.ZAAttackClaim ~= job.claim then return end
        local square = pos:DistToSqr(target:GetPos())
        if square < 32 ^ 2 or square > ZA1.Config.Melee.StartRange ^ 2 then return end
    end
    local ground = util.TraceLine({start = pos + Vector(0, 0, 24), endpos = pos - Vector(0, 0, 32), mask = MASK_NPCSOLID_BRUSHONLY, filter = z})
    if not ground.Hit or ground.StartSolid or ground.HitNormal.z < 0.6 then return end
    pos = ground.HitPos + Vector(0, 0, 2)
    local start = job.kind == "slot" and pos or z:GetPos()
    local hull = util.TraceHull({start = start, endpos = pos, mins = Vector(-z.Width, -z.Width, 2), maxs = Vector(z.Width, z.Width, z.Height), mask = MASK_NPCSOLID, filter = z, collisiongroup = COLLISION_GROUP_NPC})
    if hull.Hit or hull.StartSolid then return end
    return pos
end
function G.Process()
    for i = 1, C.ProbesPerTick do
        local chosen, job, best
        for z, pending in pairs(G.Pending) do
            if not M.Active(z) or CurTime() - pending.queued > C.SlotLifetime then G.Pending[z] = nil
            else
                local score = pending.priority + (CurTime() - pending.queued) * 4
                if not best or score > best then chosen, job, best = z, pending, score end
            end
        end
        if not chosen then break end
        G.Pending[chosen] = nil
        local pos = Probe(chosen, job)
        G.Stats.probes = G.Stats.probes + 1
        if job.kind == "slot" then
            local state = G.Targets[job.claim.target]
            if state and state.version == job.version and chosen.ZAAttackClaim == job.claim then
                if pos then job.claim.position, job.claim.version = pos, job.version
                else state.blocked[job.claim.slot] = CurTime() + 1; G.ReleaseClaim(chosen) end
            end
        elseif job.kind == "recover" and pos then
            chosen.ZARecoveryGoal, chosen.ZARecoveryUntil = pos, CurTime() + 0.8
            chosen.ZAYieldUntil = nil
        elseif job.kind == "steer" then
            chosen.ZASteerPoint, chosen.ZASteerUntil = pos, CurTime() + C.ProbeInterval
        end
    end
end
local nextGrid = 0
hook.Add("Think", "ZA1/Crowd", function()
    if CurTime() >= nextGrid then nextGrid = CurTime() + C.UpdateInterval; G.Rebuild() end
    G.Process()
end)
hook.Add("PostCleanupMap", "ZA1/Crowd", function()
    G.Grid, G.Buckets, G.Targets, G.Pending = {}, {}, setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
end)
