-- Props are not represented by the static navmesh. Sweep a short corridor in
-- one shared queue, then follow a checked local detour or an authored mantle.
local O={Pending=setmetatable({},{__mode="k"}),Stats={checks=0,detours=0,mantles=0,blocked=0}}
ZA1.Obstacles=O
local C,M,N=ZA1.Config.Obstacles,ZA1.Manager,ZA1.Navigation
local function Filter(z)
    if not z.ZAObstacleFilter then
        z.ZAObstacleFilter=function(other)
            return IsValid(other) and other~=z and other~=z.ZAObstacleEnemy and not other.ZA1Zombie and not other.ZA1Corpse
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
function O.MantlePlan(z,tr,goal)
    if not M.MantleEnabled:GetBool() or z.ZACrawling or z.ZASpecial=="heavy" or CurTime()<(z.ZANextMantle or 0) then return end
    local sequence=z:LookupSequence(C.Mantle[1]);if sequence<0 then return end
    local ok,motion=z:GetSequenceMovement(sequence,0,1)
    if not ok or motion.z<1 then return end -- Only clips with extracted vertical motion.
    local start=z:GetPos();local direction=goal-start;direction.z=0;direction:Normalize()
    if direction:LengthSqr()==0 then return end
    local maximum=M.MantleHeight:GetFloat()
    local sample=tr.HitPos+direction*(z.Width*2+C.Clearance)
    local top,support=Floor(z,sample,start.z+maximum+4,start.z+z.loco:GetStepHeight()+2)
    if not top then return end
    local height=top.z-start.z
    if height<C.MantleMinHeight or height>maximum then return end
    local landing=top+direction*(z.Width+C.Clearance)
    landing=Floor(z,landing,top.z+4,top.z-z.loco:GetStepHeight()-2)
    if not landing or math.abs(landing.z-top.z)>z.loco:GetStepHeight() or landing:DistToSqr(start)>C.MantleReach^2+height^2 then return end
    -- A top may be a solid prop with no navmesh of its own. Require a safe
    -- nearby exit on the navmesh rather than treating empty space as a ledge.
    local exit=landing+direction*(z.Width*2+32)
    exit=Floor(z,exit,top.z+4,start.z-z.loco:GetStepHeight()-2)
    if not NavFloor(z,landing) and (not exit or not NavFloor(z,exit)) then return end
    local rise=height+4;local raised=start+Vector(0,0,rise);local across=landing+Vector(0,0,4)
    if not Clear(z,start,raised) or not Clear(z,raised,across) or not Clear(z,across,landing) then return end
    return {start=Vector(start),landing=landing,rise=rise,height=height,direction=direction,
        support=IsValid(support) and support or nil,supportPos=IsValid(support) and Vector(support:GetPos()),
        expires=CurTime()+2,approach=tr.HitPos-direction*3}
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
            if not M.Active(z) or not z.ZAMoveGoal or z.ZAActing then O.Pending[z]=nil
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
                if not door then
                    local plan=O.MantlePlan(chosen,tr,job.goal)
                    if plan then chosen.ZAMantlePlan=plan
                    elseif IsValid(obstacle) and not obstacle:IsWorld() then
                        local low,high=obstacle:WorldSpaceAABB()
                        local center=(low+high)*0.5
                        local side=math.abs(delta.x)>=math.abs(delta.y) and (start.y>=center.y and 1 or -1) or (start.x>=center.x and 1 or -1)
                        local route=O.Detour(chosen,obstacle,job.goal,side)
                        if not route and SysTime()<deadline then route=O.Detour(chosen,obstacle,job.goal,-side) end
                        if route then chosen.ZAObstacleRoute=route;O.Stats.detours=O.Stats.detours+1
                        else chosen.ZANextObstacle=CurTime()+C.RetryDelay;O.Stats.blocked=O.Stats.blocked+1 end
                    end
                end
            end
        end
        if SysTime()>=deadline then break end
    end
end
function O.TryMantle(z)
    local plan=z.ZAMantlePlan
    if not plan then return false end
    if not M.Active(z) or not M.MantleEnabled:GetBool() or CurTime()>=plan.expires
        or plan.support and (not IsValid(plan.support) or plan.support:GetPos():DistToSqr(plan.supportPos)>8^2) then z.ZAMantlePlan=nil;return false end
    if z:GetPos():DistToSqr(plan.approach)>16^2 then return false end
    local start=z:GetPos()
    if not Clear(z,start,start+Vector(0,0,plan.rise)) then z.ZAMantlePlan=nil;return false end
    z.ZAMantlePlan=nil;z.ZAObstacleRoute=nil;O.Pending[z]=nil
    N.Cancel(z);ZA1.Crowd.ReleaseClaim(z);ZA1.Look.Reset(z)
    z.ZAActing,z.ZAMantling=true,true
    z:SetAngles(Angle(0,plan.direction:Angle().y,0))
    local gravity=z.loco:GetGravity();z.ZAMantleGravity=gravity;z.loco:SetGravity(0);z.loco:SetVelocity(vector_origin)
    local flags=DT_Base.ToYieldFlags({doWounded=false,doIncapacitated=true})
    local completed=true;local totalZ=0;local entries={}
    for _,name in ipairs(C.Mantle) do
        local id=z:LookupSequence(name);local ok,travel
        if id>=0 then ok,travel=z:GetSequenceMovement(id,0,1) end
        if not ok then completed=false;break end
        entries[#entries+1]={name=name,id=id,travel=travel};totalZ=totalZ+travel.z
    end
    local accumulated,highest=0,0
    for _,entry in ipairs(entries) do
        if not completed then break end
        local id=z:PlaySequence(entry.name,{move=false});local finish=CurTime()+z:SequenceDuration(id)+1
        while z:Alive() and not z:IsAIDisabled() and not z.ZADowned and z:GetSequence()==id and CurTime()<finish do
            local _,travel=z:GetSequenceMovement(id,0,z:GetCycle())
            highest=math.max(highest,math.Clamp((accumulated+travel.z)/math.max(totalZ,1),0,1))
            -- Follow the authored lift. Cross the edge only after the hull's
            -- feet clear it, then settle onto the validated support at the end.
            local lift=plan.rise*highest
            local progress=math.Clamp((lift-plan.height)/(plan.rise-plan.height),0,1)
            local desired=LerpVector(progress,start,plan.landing)+Vector(0,0,lift-progress*plan.height)
            local tr=O.Sweep(z,z:GetPos(),desired)
            if tr.Hit or tr.StartSolid or tr.AllSolid then completed=false;break end
            z.loco:SetVelocity(vector_origin)
            local multiplayer=not game.SinglePlayer()
            if multiplayer then z:PhysicsDestroy() end
            z:SetPos(desired)
            if multiplayer then z:PhysicsInitShadow() end
            if z:GetCycle()>=1 then break end
            if coroutine.yield(flags) then completed=false;break end
            if plan.support and (not IsValid(plan.support) or plan.support:GetPos():DistToSqr(plan.supportPos)>8^2) then completed=false;break end
        end
        if not z:Alive() or z:IsAIDisabled() or z.ZADowned or z:GetSequence()~=id or CurTime()>=finish then completed=false end
        accumulated=accumulated+entry.travel.z
    end
    if IsValid(z) then
        z.loco:SetGravity(gravity);z.ZAMantleGravity=nil;z.loco:SetVelocity(vector_origin)
        z.ZAActing,z.ZAMantling=false,false;z.ZANextMantle=CurTime()+C.MantleCooldown
        N.PauseProgress(z);z.ZADirect=nil;z.ZAPathGoal=nil
        if z:Alive() then
            if not z.ZADowned then z:ResetAnimState() end
            M.Wake(z)
        end
    end
    if completed then O.Stats.mantles=O.Stats.mantles+1 end
    return true
end
function O.Clear(z)
    O.Pending[z]=nil;z.ZAMantlePlan,z.ZAObstacleRoute=nil,nil
    if z.ZAMantleGravity then z.loco:SetGravity(z.ZAMantleGravity);z.ZAMantleGravity=nil end
    if z.ZAMantling then z.ZAMantling,z.ZAActing=false,false end
end
hook.Add("Think","ZA1/Obstacles",O.Tick)
hook.Add("PostCleanupMap","ZA1/Obstacles",function() O.Pending=setmetatable({},{__mode="k"}) end)
