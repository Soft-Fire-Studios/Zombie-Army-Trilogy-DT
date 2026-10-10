-- Local climbing probes run in the obstacle queue. Playback moves the actor
-- once from extracted walkframes, with a swept hull and a checked landing.
local T={Active=setmetatable({},{__mode="k"}),DropSlots=setmetatable({},{__mode="k"}),DropCount=0,
    Stats={vaults=0,fences=0,drops=0,doors=0}}
ZA1.Traversal=T
local C,M,N=ZA1.Config.Obstacles,ZA1.Manager,ZA1.Navigation
local A=ZA1.TraversalAssets
local ApproachTolerance,EdgeInset=4,1
local function Eligible(z)
    return not z.ZACrawling and (not z.ZASpecial or z.ZASpecial=="suicide")
        and not z.ZAFuse and not z.ZADowned and not z.ZAActing and not z:IsPossessed()
        and CurTime()>=(z.ZANextMantle or 0) and A.Models[z:GetModel()]~=nil
end
local function Clips(z,kind)
    local out={};local model=A.Models[z:GetModel()]
    if model then for _,clip in ipairs(model.Clips) do if clip.Kind==kind then out[#out+1]=clip end end end
    return out
end
function T.Sample(clip,time)
    local previous=clip.Curve[1]
    for i=2,#clip.Curve do
        local point=clip.Curve[i]
        if time<=point[1] then
            local f=math.Clamp((time-previous[1])/math.max(point[1]-previous[1],0.00001),0,1)
            return Vector(previous[2]+(point[2]-previous[2])*f,previous[3]+(point[3]-previous[3])*f,previous[4]+(point[4]-previous[4])*f)
        end
        previous=point
    end
    return Vector(previous[2],previous[3],previous[4])
end
local function Sweep(z,start,finish) return ZA1.Obstacles.Sweep(z,start,finish) end
local function Clear(z,start,finish)
    local tr=Sweep(z,start,finish);return not tr.Hit and not tr.StartSolid and not tr.AllSolid
end
local function Floor(z,pos,top,bottom,support)
    local tr=util.TraceHull({start=Vector(pos.x,pos.y,top),endpos=Vector(pos.x,pos.y,bottom),
        mins=Vector(-2,-2,0),maxs=Vector(2,2,1),mask=MASK_SOLID,collisiongroup=COLLISION_GROUP_NONE,
        filter=function(ent) return IsValid(ent) and ent~=z and ent~=z:GetEnemy() and not ent.ZA1Zombie
            and not ent.ZA1Corpse and not IsValid(ent.ZARecoveryOwner) end})
    if tr.Hit and not tr.StartSolid and (tr.HitNormal.z>=0.65 or support and tr.Entity==support) then return tr.HitPos,tr.Entity end
end
local function NavFloor(z,pos)
    if not pos then return end
    local area=N.Area(pos)
    if IsValid(area) and not area:IsBlocked() and not area:IsUnderwater() and area:Contains(pos)
        and math.abs(area:GetClosestPointOnArea(pos).z-pos.z)<=z.loco:GetStepHeight()+2 then return area end
end
local function Support(plan)
    if not plan.support then return true end
    if not ZA1.Obstacles.IsFixed(plan.support) or plan.support:GetPos():DistToSqr(plan.supportPos)>8^2 then return false end
    local angles=plan.support:GetAngles()
    return math.abs(math.AngleDifference(angles.p,plan.supportAngles.p))<=5
        and math.abs(math.AngleDifference(angles.y,plan.supportAngles.y))<=5
        and math.abs(math.AngleDifference(angles.r,plan.supportAngles.r))<=5
end
local function Setup(z,clip,direction,start,landing)
    local endMotion=Vector(clip.End[1],clip.End[2],0)
    local angles=Angle(0,direction:Angle().y-endMotion:Angle().y,0)
    return {clip=clip,direction=direction,angles=angles,start=Vector(start),approach=Vector(start),landing=landing,
        scale=z:GetModelScale(),expires=CurTime()+3,kind=clip.Kind}
end
local function Takeoff(clip,height,scale,onTop)
    local target=onTop and height or height+C.Clearance*0.5
    local front,previousForward,previousLift=0,nil,nil
    -- Keep the standing hull outside the support until the authored rise
    -- clears it. A fixed four-unit ramp lifted the entire actor during the
    -- preparation frames, before the animation actually started climbing.
    for _,point in ipairs(clip.Curve) do
        if point[1]>clip.PeakTime then break end
        local forward=(point[2]*clip.End[1]+point[3]*clip.End[2])/clip.Distance*scale
        local lift=onTop and point[4]*scale or (height+C.Clearance)*math.Clamp(point[4]/math.max(clip.Peak,1),0,1)
        if lift<target then front=math.max(front,forward) end
        if previousLift and (previousLift<target)~=(lift<target) then
            local fraction=(target-previousLift)/(lift-previousLift)
            front=math.max(front,previousForward+(forward-previousForward)*fraction)
        end
        previousForward,previousLift=forward,lift
    end
    -- Starting anywhere inside the accepted approach tolerance must still
    -- leave the hull clear during preparation; the edge probe is inset too.
    return math.max(C.Clearance,front+ApproachTolerance+EdgeInset)
end
function T.Position(plan,motion,time)
    local raw=Vector(motion)*plan.scale;local horizontal=Vector(raw.x,raw.y,0);horizontal:Rotate(plan.angles)
    local progress=math.Clamp(horizontal:Dot(plan.direction)/math.max(plan.clip.Distance*plan.scale,1),0,1)
    local lift=raw.z
    if plan.height then
        local peak=plan.clip.Peak*plan.scale;local endZ=plan.clip.End[3]*plan.scale
        if plan.onTop then lift=math.Clamp(raw.z,0,plan.height)
        elseif time<=plan.clip.PeakTime then lift=plan.rise*math.Clamp(raw.z/math.max(peak,1),0,1)
        else
            local f=math.Clamp((raw.z-endZ)/math.max(peak-endZ,1),0,1)
            lift=plan.rise*f+(plan.landing.z-plan.start.z)*(1-f)
        end
        -- A standing navigation hull is wider than the folded limbs in a
        -- vault. Keep its feet above the support while the hull crosses it.
        local forward=horizontal:Dot(plan.direction)
        local supportLift=plan.onTop and plan.height or plan.rise
        if forward>=plan.front and forward<=plan.back then lift=math.max(lift,supportLift)
        elseif forward>plan.back then
            local f=math.Clamp((forward-plan.back)/math.max(plan.clip.Distance*plan.scale-plan.back,1),0,1)
            lift=math.max(lift,plan.rise+(plan.landing.z-plan.start.z-plan.rise)*f)
        end
    elseif plan.kind=="door" then lift=raw.z-plan.clip.End[3]*plan.scale*progress
    elseif plan.kind=="drop" then lift=math.max(0,raw.z) end
    return plan.start+horizontal+Vector(0,0,lift)
end
local function CheckPath(z,plan,endTime,ignore)
    if plan.height then
        -- Prove the complete climb corridor without a long series of traces.
        -- Actual curved movement is swept on every playback delta as well.
        local raised=plan.start+Vector(0,0,plan.rise)
        local across=Vector(plan.landing.x,plan.landing.y,raised.z)
        return Clear(z,plan.start,raised) and Clear(z,raised,across) and Clear(z,across,plan.landing)
    end
    local previous=plan.start;local old=z.ZAObstacleIgnore;z.ZAObstacleIgnore=ignore
    local ok=true
    -- Eight bounded corridor sweeps; playback rechecks every actual delta.
    for i=1,8 do
        local time=endTime*i/8;local desired=T.Position(plan,T.Sample(plan.clip,time),time)
        if not Clear(z,previous,desired) then ok=false;break end
        previous=desired
    end
    z.ZAObstacleIgnore=old;return ok
end
function T.Plan(z,tr,goal,deadline)
    if not Eligible(z) or not M.MantleEnabled:GetBool() or tr.StartSolid or not ZA1.Obstacles.IsFixed(tr.Entity) then return end
    deadline=deadline or math.huge
    local origin=z:GetPos();local direction=goal-origin;direction.z=0;direction:Normalize()
    if direction:LengthSqr()==0 then return end
    local maximum=M.MantleHeight:GetFloat()
    local ceiling=Sweep(z,origin,origin+Vector(0,0,maximum+C.Clearance))
    if ceiling.StartSolid then return end
    if ceiling.Hit then maximum=math.min(maximum,ceiling.HitPos.z-origin.z-C.Clearance) end
    if maximum<C.MantleMinHeight then return end
    local radius=z.Width*(math.abs(direction.x)+math.abs(direction.y))
    local edge=tr.HitPos+direction*(radius+EdgeInset)
    local inside=edge+direction*2
    local free
    -- L4D's local climb probe: ceiling, first clear horizontal hull, then a
    -- downward hull to find the ledge. No global path search is involved.
    for height=C.MantleMinHeight,maximum+C.LedgeScanStep,C.LedgeScanStep do
        if SysTime()>=deadline then return end
        height=math.min(height,maximum)
        local raised=origin+Vector(0,0,height+C.Clearance)
        if Clear(z,raised,inside+Vector(0,0,raised.z-inside.z)) then free=height+C.Clearance;break end
        if height==maximum then break end
    end
    if not free then return end
    local top,support
    -- A jersey barrier's first contact is its wide foot/sloped face. Search
    -- a short distance inward for its narrower flat top, retaining the real
    -- front edge for approach clearance and the far-edge measurement.
    for inset=0,math.min(C.MantleReach,z.Width*2),4 do
        if SysTime()>=deadline then return end
        local sample=inside+direction*inset
        top,support=Floor(z,sample,origin.z+free,origin.z+z.loco:GetStepHeight()+2)
        if top and ZA1.Obstacles.IsFixed(support) then inside=sample;break end
        top=nil
    end
    if not top then return end
    local height=top.z-origin.z
    if height<C.MantleMinHeight or height>maximum then return end
    edge.z=top.z
    -- Measure the whole support, including a barrier's sloped foot. Its flat
    -- cap alone cannot prove that a descending standing hull clears the back.
    local depth=0;local last=inside;local far
    local function OnSupport(point,ent)
        return point and ent==support and (not support:IsWorld() or math.abs(point.z-top.z)<=4)
    end
    for distance=C.EdgeScanStep,C.MantleReach,C.EdgeScanStep do
        if SysTime()>=deadline then return end
        local sample=inside+direction*distance
        local point,ent=Floor(z,sample,top.z+4,origin.z+2,support)
        if not OnSupport(point,ent) then
            local low,high=last,sample
            for _=1,3 do
                local middle=(low+high)*0.5;local ground,ent=Floor(z,middle,top.z+4,origin.z+2,support)
                if OnSupport(ground,ent) then low=middle else high=middle end
            end
            far=high;depth=(far-edge):Dot(direction);break
        end
        last=sample
    end
    local model=IsValid(support) and support:GetModel() or ""
    local fence=model and (model:lower():find("fence",1,true) or model:lower():find("chainlink",1,true))
    local pool={}
    for _,kind in ipairs(fence and {"fence"} or height>C.MantleCoastHeight and {"fence"} or {"vault","bunker"}) do
        for _,clip in ipairs(Clips(z,kind)) do
            if far and (kind~="fence" or height<=C.FenceHeight) then pool[#pool+1]=clip end
        end
    end
    table.sort(pool,function(a,b) return a.Distance<b.Distance end)
    -- Prefer the shortest sufficient clip. Similar variants can both appear.
    if #pool>1 and pool[2].Kind==pool[1].Kind and pool[2].Distance-pool[1].Distance<8 and math.random(2)==1 then pool[1],pool[2]=pool[2],pool[1] end
    if not fence and height<=C.MantleCoastHeight then for _,clip in ipairs(Clips(z,"climb")) do pool[#pool+1]=clip end end
    for _,clip in ipairs(pool) do
        if SysTime()>=deadline then return end
        local onTop=clip.Kind=="climb"
        local scale=z:GetModelScale();local front=Takeoff(clip,height,scale,onTop)
        local required=math.max(0,depth)+radius*2+front+C.Clearance*0.5
        if not onTop and clip.Distance*scale<required then continue end
        local approach=edge-direction*(radius+front);approach.z=origin.z
        if not Clear(z,origin,approach) then continue end
        local floor=Floor(z,approach,origin.z+z.loco:GetStepHeight(),origin.z-z.loco:GetStepHeight()-2)
        if not floor or math.abs(floor.z-origin.z)>ApproachTolerance then continue end
        local landing=approach+direction*(clip.Distance*scale)
        landing=Floor(z,landing,onTop and top.z+4 or origin.z+z.loco:GetStepHeight(),origin.z-z.loco:GetStepHeight()-2)
        local area=NavFloor(z,landing)
        local exit=onTop and landing and Floor(z,landing+direction*(radius*2+32),top.z+4,origin.z-z.loco:GetStepHeight()-2)
        if landing and (area or onTop and NavFloor(z,exit))
            and (onTop and math.abs(landing.z-top.z)<=2 or not onTop and math.abs(landing.z-origin.z)<=z.loco:GetStepHeight()) then
            local plan=Setup(z,clip,direction,approach,landing)
            plan.height,plan.rise,plan.depth,plan.onTop=height,height+C.Clearance,depth,onTop
            plan.front=front;plan.back=onTop and clip.Distance*plan.scale or depth+radius*2+front
            plan.support=IsValid(support) and not support:IsWorld() and support or nil
            plan.supportPos=plan.support and Vector(support:GetPos());plan.supportAngles=plan.support and support:GetAngles()
            if CheckPath(z,plan,clip.Duration) then return plan end
        end
    end
end
local function DropCorridor(z,plan)
    local takeoff=T.Position(plan,T.Sample(plan.clip,C.DropRagdollTime),C.DropRagdollTime)
    local prior=T.Sample(plan.clip,C.DropRagdollTime-0.05)
    local vertical=math.min(0,(T.Sample(plan.clip,C.DropRagdollTime).z-prior.z)*plan.scale/0.05)
    local gravity=math.max(z.loco:GetGravity(),1)
    local flight=(vertical+math.sqrt(vertical^2+2*gravity*(takeoff.z-plan.landing.z)))/gravity
    if flight<=0 then return false end
    local velocity=(plan.landing-takeoff)/flight;velocity.z=vertical
    if velocity:Length2D()>C.DropMaxSpeed then return false end
    local previous=takeoff
    for i=1,5 do
        local t=flight*i/5;local point=takeoff+velocity*t-Vector(0,0,gravity*t*t*0.5)
        if not Clear(z,previous,point+Vector(0,0,2)) then return false end
        previous=point
    end
    plan.velocity=velocity;return true
end
function T.DropPlan(z,goal)
    if not Eligible(z) or not M.DropEnabled:GetBool() or ZA1.Recovery.active+T.DropCount>=ZA1.Config.Recovery.MaxActiveRagdolls then return end
    local enemy=z:GetEnemy();if not IsValid(enemy) then return end
    goal=enemy:GetPos();local origin=z:GetPos();local maximum=M.DropHeight:GetFloat()
    if origin.z-goal.z<C.DropMinHeight then return end
    local clip=Clips(z,"drop")[1];if not clip then return end
    local direction=goal-origin;direction.z=0;direction:Normalize()
    if direction:LengthSqr()==0 then return end
    local last=origin;local edge
    for distance=C.EdgeScanStep,C.ProbeDistance,C.EdgeScanStep do
        local point=origin+direction*distance
        if not Clear(z,origin,point) then return end
        local floor=Floor(z,point,origin.z+4,origin.z-maximum-2)
        if not floor then return end -- An unmeasured pit is never a safe drop.
        if origin.z-floor.z>C.DropMinHeight then
            local low,high=last,point
            for _=1,3 do
                local middle=(low+high)*0.5;local ground=Floor(z,middle,origin.z+4,origin.z-z.loco:GetStepHeight()-2)
                if ground then low=middle else high=middle end
            end
            edge=high;break
        end
        last=point
    end
    if not edge then return end
    local scale=z:GetModelScale();local release=T.Sample(clip,C.DropRagdollTime)*scale
    local endMotion=Vector(clip.End[1],clip.End[2],0);local angles=Angle(0,direction:Angle().y-endMotion:Angle().y,0)
    release:Rotate(angles)
    local radius=z.Width*(math.abs(direction.x)+math.abs(direction.y))
    local approach=edge+direction*(radius+4)-Vector(release.x,release.y,0);approach.z=origin.z
    if approach:DistToSqr(origin)>C.ProbeDistance^2 or not Clear(z,origin,approach) then return end
    local landing=approach+direction*(clip.Distance*scale)
    landing=Floor(z,landing,origin.z-2,origin.z-maximum-2)
    if not landing or origin.z-landing.z<C.DropMinHeight or origin.z-landing.z>maximum then return end
    local area=NavFloor(z,landing)
    if not area or N.Reachable(area,goal,N.Profile(z))~=true then return end
    if not Clear(z,landing,landing) then return end
    local plan=Setup(z,clip,direction,approach,landing)
    if DropCorridor(z,plan) and CheckPath(z,plan,C.DropRagdollTime) then return plan end
end
local function Place(z,pos)
    local multiplayer=not game.SinglePlayer()
    if multiplayer then z:PhysicsDestroy() end
    z:SetPos(pos)
    if multiplayer then z:PhysicsInitShadow() end
end
function T.Clear(z)
    T.Active[z]=nil
    if T.DropSlots[z] then T.DropSlots[z]=nil;T.DropCount=math.max(0,T.DropCount-1) end
    if not IsValid(z) then return end
    if z.ZAMantleGravity then z.loco:SetGravity(z.ZAMantleGravity);z.ZAMantleGravity=nil end
    if z.ZAMantling then z.ZAMantling,z.ZAActing=false,false end
end
function T.Run(z,plan)
    if plan.door and not ZA1.Doors.IsClosed(plan.door) then ZA1.Doors.Clear(z);return false end
    if not Support(plan) or not Clear(z,z:GetPos(),plan.start) then return false end
    if plan.kind=="drop" then
        if ZA1.Recovery.active+T.DropCount>=ZA1.Config.Recovery.MaxActiveRagdolls then return false end
        T.DropSlots[z]=true;T.DropCount=T.DropCount+1
    end
    N.Cancel(z);ZA1.Crowd.ReleaseClaim(z);ZA1.Look.Reset(z)
    if z.ZASpecial=="suicide" then z.ZACharging=nil;ZA1.Specials.StopVoice(z) end
    z.ZAActing,z.ZAMantling=true,true;T.Active[z]=true;z:SetAngles(plan.angles)
    local gravity=z.loco:GetGravity();z.ZAMantleGravity=gravity;z.loco:SetGravity(0);z.loco:SetVelocity(vector_origin)
    local flags=DT_Base.ToYieldFlags({doWounded=false,doIncapacitated=true})
    local elapsed,offset=0,Vector();local completed=true;local dropped=false
    for _,part in ipairs(plan.clip.Parts) do
        if not completed then break end
        local id=z:PlaySequence(part,{move=false});local duration=z:SequenceDuration(id);local finish=CurTime()+duration+1
        while IsValid(z) and z:Alive() and not z:IsAIDisabled() and not z.ZADowned and z:GetSequence()==id and CurTime()<finish do
            if plan.door and not ZA1.Doors.IsClosed(plan.door) then ZA1.Doors.Clear(z);completed=false;break end
            local cycle=z:GetCycle();local time=elapsed+cycle*duration
            local ok,motion=z:GetSequenceMovement(id,0,cycle)
            if not ok or not Support(plan) or plan.kind~="door" and not (plan.kind=="drop" and M.DropEnabled:GetBool() or plan.kind~="drop" and M.MantleEnabled:GetBool()) then completed=false;break end
            if plan.kind=="drop" and time>=C.DropRagdollTime then
                local release=T.Position(plan,T.Sample(plan.clip,C.DropRagdollTime),C.DropRagdollTime)
                if not Clear(z,z:GetPos(),release) then completed=false;break end
                Place(z,release)
                z.loco:SetGravity(gravity);z.ZAMantleGravity=nil
                dropped=ZA1.Recovery.Drop(z,plan.velocity,plan.landing)
                completed=dropped;break
            end
            local desired=T.Position(plan,offset+motion,time);local tr=Sweep(z,z:GetPos(),desired)
            if plan.door and tr.Hit and tr.Entity==plan.door then
                ZA1.Doors.Break(z,plan.door,tr.HitPos);plan.door=nil;tr=Sweep(z,z:GetPos(),desired)
            end
            if tr.Hit or tr.StartSolid or tr.AllSolid then completed=false;break end
            z.loco:SetVelocity(vector_origin);Place(z,desired)
            if cycle>=1 then break end
            if coroutine.yield(flags) then completed=false;break end
        end
        if dropped then break end
        if not IsValid(z) then completed=false;break end
        if not z:Alive() or z:IsAIDisabled() or z.ZADowned or z:GetSequence()~=id or CurTime()>=finish then completed=false end
        local _,travel=z:GetSequenceMovement(id,0,1);offset=offset+(travel or Vector());elapsed=elapsed+duration
    end
    T.Clear(z)
    if IsValid(z) then
        z.loco:SetGravity(gravity);z.loco:SetVelocity(vector_origin)
        z.ZANextMantle=CurTime()+C.MantleCooldown;N.PauseProgress(z);z.ZADirect,z.ZAPathGoal=nil,nil
        if z:Alive() then if not z.ZADowned then z:ResetAnimState() end;M.Wake(z) end
    end
    if completed then
        if plan.kind~="drop" and plan.kind~="door" then ZA1.Obstacles.Stats.mantles=ZA1.Obstacles.Stats.mantles+1 end
        if plan.kind=="drop" then T.Stats.drops=T.Stats.drops+1
        elseif plan.kind=="door" then T.Stats.doors=T.Stats.doors+1
        elseif plan.kind=="fence" then T.Stats.fences=T.Stats.fences+1
        else T.Stats.vaults=T.Stats.vaults+1 end
    end
    return true
end
function T.Try(z)
    local plan=z.ZAMantlePlan
    if not plan then return false end
    if not M.Active(z) or CurTime()>=plan.expires or not Support(plan) then z.ZAMantlePlan=nil;return false end
    if z:GetPos():DistToSqr(plan.approach)>ApproachTolerance^2 then return false end
    z.ZAMantlePlan,z.ZAObstacleRoute=nil,nil;ZA1.Obstacles.Pending[z]=nil
    local adjustment=z:GetPos()-plan.start
    plan.start=Vector(z:GetPos()) -- The approach must not snap the actor backwards.
    if plan.front then plan.front=plan.front-adjustment:Dot(plan.direction);plan.back=plan.back-adjustment:Dot(plan.direction) end
    if plan.kind=="drop" then
        if not NavFloor(z,plan.landing) or not DropCorridor(z,plan) then return true end
    else
        plan.landing=plan.landing+Vector(adjustment.x,adjustment.y,0)
        local floor=Floor(z,plan.landing,plan.landing.z+4,plan.landing.z-4)
        if not floor or math.abs(floor.z-plan.landing.z)>2 then return true end
        if not plan.onTop and not NavFloor(z,floor) then return true end
        plan.landing=floor
    end
    if not CheckPath(z,plan,plan.kind=="drop" and C.DropRagdollTime or plan.clip.Duration) then return true end
    return T.Run(z,plan)
end
function T.Door(z,door)
    if not Eligible(z) or not ZA1.Doors.IsClosed(door) then return false end
    local direction=door:NearestPoint(z:WorldSpaceCenter())-z:WorldSpaceCenter();direction.z=0;direction:Normalize()
    local pool=Clips(z,"door");if #pool==2 and math.random(2)==1 then pool[1],pool[2]=pool[2],pool[1] end
    for _,clip in ipairs(pool) do
        local start=z:GetPos();local plan=Setup(z,clip,direction,start,start+direction*(clip.Distance*z:GetModelScale()))
        plan.door=door
        local landing=Floor(z,plan.landing,start.z+z.loco:GetStepHeight(),start.z-z.loco:GetStepHeight()-2)
        if landing and CheckPath(z,plan,clip.Duration,door) then return T.Run(z,plan) end
    end
    return false
end
