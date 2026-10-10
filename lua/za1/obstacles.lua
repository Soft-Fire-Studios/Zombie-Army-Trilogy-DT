-- Props are not represented by the static navmesh. Sweep a short corridor in
-- one shared queue, then follow a checked local detour or an authored mantle.
local O={Pending=setmetatable({},{__mode="k"}),Stats={checks=0,detours=0,mantles=0,blocked=0}}
ZA1.Obstacles=O
local C,M,N=ZA1.Config.Obstacles,ZA1.Manager,ZA1.Navigation
function O.IsFixed(ent)
    if not IsValid(ent) then return false end
    if ent:IsWorld() then return true end
    local phys=ent:GetPhysicsObject()
    if IsValid(phys) then return not phys:IsMotionEnabled() end
    return ent:GetMoveType()==MOVETYPE_NONE
end
local function Filter(z)
    if not z.ZAObstacleFilter then
        z.ZAObstacleFilter=function(other)
            return IsValid(other) and other~=z and other~=z.ZAObstacleEnemy and other~=z.ZAObstacleIgnore
                and not other.ZA1Zombie and not other.ZA1Corpse and not IsValid(other.ZARecoveryOwner)
        end
    end
    z.ZAObstacleEnemy=z:GetEnemy()
    return z.ZAObstacleFilter
end
function O.Sweep(z,start,finish)
    return util.TraceHull({start=start,endpos=finish,mins=Vector(-z.Width,-z.Width,2),maxs=Vector(z.Width,z.Width,z.Height),
        mask=MASK_SOLID,collisiongroup=COLLISION_GROUP_NONE,filter=Filter(z)})
end
local function Clear(z,start,finish)
    local tr=O.Sweep(z,start,finish)
    return not tr.Hit and not tr.StartSolid and not tr.AllSolid
end
local function Floor(z,pos,top,bottom)
    local tr=util.TraceLine({start=Vector(pos.x,pos.y,top),endpos=Vector(pos.x,pos.y,bottom),mask=MASK_SOLID,filter=Filter(z)})
    if tr.Hit and not tr.StartSolid and tr.HitNormal.z>=0.65 then return tr.HitPos,tr.Entity end
end
local function NavFloor(z,pos)
    if not pos then return false end
    local area=N.Area(pos)
    return IsValid(area) and not area:IsBlocked() and not area:IsUnderwater() and area:Contains(pos)
        and math.abs(area:GetClosestPointOnArea(pos).z-pos.z)<=z.loco:GetStepHeight()+2
end
-- A closed door can block its entire nav area, including the floor on our
-- side. Check only that short, grounded approach; never cross the door.
function O.PrepareDoor(z)
    z.ZADoorLocal=nil
    local B=ZA1.Doors;local door=z.ZADoorTarget
    if not B or not B.IsClosed(door) then return end
    local start=z:GetPos();local goal=B.ApproachPoint(z,door)
    local delta=goal-start;local distance=delta:Length2D()
    if distance>ZA1.Config.Doors.ProbeDistance or not Clear(z,start,goal) then return end
    local step=z.loco:GetStepHeight();local previous=start
    local count=math.max(1,math.ceil(distance/32))
    for i=1,count do
        local sample=start+delta*(i/count)
        local floor=Floor(z,sample,previous.z+step,previous.z-step-2)
        if not floor or math.abs(floor.z-previous.z)>step then return end
        if navmesh.IsLoaded() then
            local area=N.Area(floor)
            if not IsValid(area) or area:IsUnderwater() or not area:Contains(floor)
                or math.abs(area:GetClosestPointOnArea(floor).z-floor.z)>step+2 then return end
        end
        previous=floor
    end
    z.ZADoorLocal={door=door,from=Vector(start),goal=previous,position=Vector(door:GetPos()),
        angles=door:GetAngles(),expires=CurTime()+math.max(0.5,C.Interval*4)}
end
function O.DoorPoint(z)
    local route=z.ZADoorLocal
    if not route or CurTime()>=route.expires or route.door~=z.ZADoorTarget or not ZA1.Doors.IsClosed(route.door) then return end
    local angles=route.door:GetAngles()
    if route.door:GetPos():DistToSqr(route.position)>1 or math.abs(math.AngleDifference(angles.y,route.angles.y))>1
        or math.abs(math.AngleDifference(angles.p,route.angles.p))>1 or math.abs(math.AngleDifference(angles.r,route.angles.r))>1 then return end
    local pos=z:GetPos();local delta=route.goal-route.from
    local fraction=math.Clamp((pos-route.from):Dot(delta)/math.max(delta:LengthSqr(),1),0,1)
    if pos:DistToSqr(route.from+delta*fraction)>4^2 then return end
    return route.goal
end
function O.Detour(z,obstacle,goal,side)
    local start=z:GetPos();local low,high=obstacle:WorldSpaceAABB()
    local margin=z.Width+C.Clearance
    if high.x-low.x>C.MaxDetour or high.y-low.y>C.MaxDetour then return end
    local delta=goal-start;local x=math.abs(delta.x)>=math.abs(delta.y)
    local sign=(x and delta.x or delta.y)>=0 and 1 or -1
    local a,b
    if x then
        local y=side>0 and high.y+margin or low.y-margin
        a=Vector(sign>0 and low.x-margin or high.x+margin,y,start.z)
        b=Vector(sign>0 and high.x+margin or low.x-margin,y,start.z)
    else
        local xx=side>0 and high.x+margin or low.x-margin
        a=Vector(xx,sign>0 and low.y-margin or high.y+margin,start.z)
        b=Vector(xx,sign>0 and high.y+margin or low.y-margin,start.z)
    end
    -- A point inside the corner margin needs only the far corner.
    if (x and (start.x-a.x)*sign>0 or not x and (start.y-a.y)*sign>0) then a=b end
    local step=z.loco:GetStepHeight()
    a=Floor(z,a,start.z+step,start.z-step-2);if not a or not NavFloor(z,a) then return end
    b=Floor(z,b,start.z+step,start.z-step-2);if not b or not NavFloor(z,b) then return end
    local rejoin=b+delta:GetNormalized()*math.min(64,delta:Length2D())
    rejoin=Floor(z,rejoin,start.z+step,start.z-step-2)
    if not rejoin or not NavFloor(z,rejoin) then return end
    if not Clear(z,start,a) or not Clear(z,a,b) or not Clear(z,b,rejoin) then return end
    return {points={a,b,rejoin},index=1,entity=obstacle,entityPos=Vector(obstacle:GetPos()),goal=Vector(goal),expires=CurTime()+C.RouteLifetime}
end
function O.MantlePlan(z,tr,goal,deadline)
    return ZA1.Traversal.Plan(z,tr,goal,deadline)
end
function O.Queue(z,goal)
    if CurTime()<(z.ZANextObstacle or 0) or not goal then return end
    local job=O.Pending[z]
    if job then job.goal=Vector(goal)
    else O.Pending[z]={goal=Vector(goal),queued=CurTime()} end
end
function O.Steer(z,path,destination)
    local current=not destination and IsValid(path) and path:GetCurrentGoal()
    local goal=destination or current and current.pos or z.ZAMoveGoal
    local plan=z.ZAMantlePlan
    if plan and CurTime()<plan.expires then return plan.approach end
    local route=z.ZAObstacleRoute
    if route then
        if CurTime()>=route.expires or not IsValid(route.entity) or route.entity:GetPos():DistToSqr(route.entityPos)>16^2
            or goal and route.goal:DistToSqr(goal)>256^2 then z.ZAObstacleRoute=nil
        else
            while route.points[route.index] and z:GetPos():DistToSqr(route.points[route.index])<=12^2 do route.index=route.index+1 end
            local point=route.points[route.index]
            if point then return point end
            z.ZAObstacleRoute=nil;z.ZADirect=nil;z.ZAPathGoal=nil
            if IsValid(path) then path:Invalidate() end
            if z.ZAMoveGoal then N.Request(z,z.ZAMoveGoal,z.ZAMovePriority,z.ZAMoveGoal,z.ZAMoveGoal) end
        end
    end
    O.Queue(z,goal)
end
function O.Tick()
    local deadline=SysTime()+C.BudgetMS/1000
    for count=1,C.ChecksPerTick do
        local chosen,job
        for z,pending in pairs(O.Pending) do
            if not M.Active(z) or z.ZAActing or not z.ZAMoveGoal and not z.ZADoorTarget then O.Pending[z]=nil
            elseif not job or pending.queued<job.queued then chosen,job=z,pending end
        end
        if not chosen then break end
        O.Pending[chosen]=nil;chosen.ZANextObstacle=CurTime()+C.Interval
        local start=chosen:GetPos();local delta=job.goal-start;delta.z=0
        if delta:LengthSqr()>1 then
            local finish=start+delta:GetNormalized()*math.min(C.ProbeDistance,delta:Length())
            local tr=O.Sweep(chosen,start,finish);O.Stats.checks=O.Stats.checks+1
            if tr.Hit or tr.StartSolid then
                chosen.ZADirect=nil;chosen.ZADirectRetry=CurTime()+C.RetryDelay
                local obstacle=tr.Entity
                local door=ZA1.Doors and ZA1.Doors.IsDoor(obstacle)
                if door then ZA1.Doors.Observe(chosen,obstacle,job.goal) end
                if not door or not ZA1.Doors.IsClosed(obstacle) then
                    -- An open leaf is a physical obstacle, never a vault or
                    -- door attack. Use the normal checked local detour.
                    local plan=not door and O.IsFixed(obstacle) and O.MantlePlan(chosen,tr,job.goal,deadline)
                    if plan then chosen.ZAMantlePlan=plan;chosen.ZAObstacleRoute=nil
                    elseif IsValid(obstacle) and not obstacle:IsWorld() and SysTime()<deadline then
                        local low,high=obstacle:WorldSpaceAABB()
                        local center=(low+high)*0.5
                        local side=math.abs(delta.x)>=math.abs(delta.y) and (start.y>=center.y and 1 or -1) or (start.x>=center.x and 1 or -1)
                        local route=O.Detour(chosen,obstacle,job.goal,side)
                        if not route and SysTime()<deadline then route=O.Detour(chosen,obstacle,job.goal,-side) end
                        if route then chosen.ZAObstacleRoute=route;O.Stats.detours=O.Stats.detours+1
                        else chosen.ZANextObstacle=CurTime()+C.RetryDelay;O.Stats.blocked=O.Stats.blocked+1 end
                    end
                end
            elseif ZA1.Traversal then
                local plan=ZA1.Traversal.DropPlan(chosen,job.goal)
                if plan then chosen.ZAMantlePlan=plan end
            end
        end
        if chosen.ZADoorTarget then O.PrepareDoor(chosen) end
        if SysTime()>=deadline then break end
    end
end
function O.TryMantle(z)
    return ZA1.Traversal.Try(z)
end
function O.Clear(z)
    if ZA1.Traversal then ZA1.Traversal.Clear(z) end
    O.Pending[z]=nil
    if not IsValid(z) then return end
    z.ZAMantlePlan,z.ZAObstacleRoute=nil,nil
    if ZA1.Doors then ZA1.Doors.Clear(z) end
    if z.ZAMantleGravity then z.loco:SetGravity(z.ZAMantleGravity);z.ZAMantleGravity=nil end
    if z.ZAMantling then z.ZAMantling,z.ZAActing=false,false end
end
hook.Add("Think","ZA1/Obstacles",O.Tick)
hook.Add("PostCleanupMap","ZA1/Obstacles",function()
    if ZA1.Traversal then
        for z in pairs(ZA1.Traversal.Active) do ZA1.Traversal.Clear(z) end
        ZA1.Traversal.DropSlots=setmetatable({},{__mode="k"});ZA1.Traversal.DropCount=0
    end
    O.Pending=setmetatable({},{__mode="k"})
end)
