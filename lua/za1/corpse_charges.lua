-- Only surviving Suicide Grunt corpses are tested, and only on a bullet hit.
-- No helper entities, Think traces, navigation collisions or live-bot hitboxes.
local C={Corpses={}};ZA1.CorpseCharges=C
local A=ZA1.SpecialAssets.Enemies.suicide
local settings=ZA1.SpecialConfig.suicide
function C.Register(z,rag)
    if z.ZADetonated or z.ZABrokenApart or z.ZAExplodeOnDeath or not IsValid(rag) then return end
    local shapes={}
    for _,shape in ipairs(A.Weakpoint.Shapes or {A.Weakpoint}) do
        local bone=rag:LookupBone(shape.Bone)
        if bone then
            local boxes={}
            for _,box in ipairs(shape.Boxes) do boxes[#boxes+1]={mins=Vector(box[1],box[2],box[3]),maxs=Vector(box[4],box[5],box[6])} end
            shapes[#shapes+1]={bone=bone,boxes=boxes,name=shape.Name}
        end
    end
    if #shapes==0 then return end
    rag.ZASpecial,rag.ZASpecialAssets,rag.ZASpecialSettings="suicide",A,settings
    rag.ZAHeadDestroyed,rag.ZAHeadLayout=z.ZAHeadDestroyed,z.ZAHeadLayout
    rag.ZABreakupBones={}
    for index,piece in ipairs(ZA1.Specials.SuicideGibs) do rag.ZABreakupBones[index]=rag:LookupBone(piece.Bone) end
    C.Corpses[rag]={shapes=shapes,created=CurTime()}
    rag:CallOnRemove("ZA1/CorpseCharges",function(entity) C.Corpses[entity]=nil end)
end
function C.Trace(rag,state,start,delta)
    local scale=rag:GetModelScale();local closest,fraction,name
    for _,shape in ipairs(state.shapes) do
        local matrix=rag:GetBoneMatrix(shape.bone)
        if matrix then for _,box in ipairs(shape.boxes) do
            local pos,_,hit=util.IntersectRayWithOBB(start,delta,matrix:GetTranslation(),matrix:GetAngles(),
                box.mins*scale,box.maxs*scale)
            if pos and (not fraction or hit<fraction) then closest,fraction,name=pos,hit,shape.name end
        end end
    end
    return closest,fraction,name
end
function C.Detonate(rag,pos,info,explosive)
    if not IsValid(rag) or not C.Corpses[rag] or rag.ZADetonated then return false end
    C.Corpses[rag]=nil;rag.ZADetonated=true
    local attacker,inflictor=info:GetAttacker(),info:GetInflictor()
    local damage=DamageInfo();damage:SetDamage(settings.BlastDamage);damage:SetDamageType(DMG_BLAST)
    damage:SetDamagePosition(pos);damage:SetDamageForce(info:GetDamageForce())
    damage:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
    damage:SetInflictor(IsValid(inflictor) and inflictor or rag)
    local scale=rag:GetModelScale()
    -- Defer removal/physics creation out of the engine's bullet damage callback.
    timer.Simple(0,function()
        if IsValid(rag) then ZA1.Specials.Breakup(rag,damage) end
        ZA1.Feedback.Explosion(pos,explosive)
        attacker=IsValid(attacker) and attacker or game.GetWorld()
        inflictor=IsValid(inflictor) and inflictor or (IsValid(rag) and rag or game.GetWorld())
        if ZA1.Doors then ZA1.Doors.Blast(inflictor,pos,settings.BlastRadius*scale,settings.BlastDamage) end
        util.BlastDamage(inflictor,attacker,pos,settings.BlastRadius*scale,settings.BlastDamage)
        if IsValid(rag) then rag:Remove() end
    end)
    return true
end
hook.Add("EntityFireBullets","ZA1/CorpseCharges",function(shooter,data)
    if next(C.Corpses)==nil then return end
    local callback=data.Callback;local fired=CurTime()
    data.Callback=function(attacker,tr,info)
        local result=callback and callback(attacker,tr,info)
        if info:GetDamage()<=0 or type(result)=="table" and result.damage==false then return result end
        local delta=tr.HitPos-tr.StartPos;local length=delta:Length()
        if length<1 then return result end
        local chosen,position,nearest,explosive
        for rag,state in pairs(C.Corpses) do
            if not IsValid(rag) then C.Corpses[rag]=nil
            elseif state.created<fired then
                -- Cheap coarse rejection before looking up any moving joints.
                local center=rag:WorldSpaceCenter()
                local t=math.Clamp((center-tr.StartPos):Dot(delta)/(length*length),0,1)
                if center:DistToSqr(tr.StartPos+delta*t)<=(100*rag:GetModelScale())^2 then
                    -- A hit on this ragdoll's flesh may lie in front of its
                    -- attached charge. Other hit entities still occlude it.
                    local extension=tr.Entity==rag and 32*rag:GetModelScale() or 0
                    local pos,fraction,name=C.Trace(rag,state,tr.StartPos,delta:GetNormalized()*(length+extension))
                    if pos and (not nearest or fraction*(length+extension)<nearest) then
                        chosen,position,nearest,explosive=rag,pos,fraction*(length+extension),name
                    end
                end
            end
        end
        if chosen then C.Detonate(chosen,position,info,explosive) end
        return result
    end
end)
hook.Add("EntityTakeDamage","ZA1/CorpseCharges",function(entity,info)
    if C.Corpses[entity] and info:IsExplosionDamage() and info:GetDamage()>=ZA1.Config.Recovery.MinExplosionDamage then
        C.Detonate(entity,info:GetDamagePosition(),info)
    end
end)
hook.Add("PostCleanupMap","ZA1/CorpseCharges",function() C.Corpses={} end)
