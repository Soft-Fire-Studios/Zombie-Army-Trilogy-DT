if SERVER then AddCSLuaFile() end
game.AddParticles("particles/demonic_resurection_source.pcf")
PrecacheParticleSystem("UndeadSS_Demonic_Resurection_source")
if SERVER then return end
local effects={}
net.Receive("ZA1/ResurrectionStop",function()
    local actor=net.ReadEntity()
    for index=#effects,1,-1 do
        local row=effects[index]
        if row.actor==actor then
            if row.effect:IsValid() then row.effect:StopEmissionAndDestroyImmediately() end
            table.remove(effects,index)
        end
    end
end)
net.Receive("ZA1/Resurrection",function()
    local actor,pos,normal,life=net.ReadEntity(),net.ReadVector(),net.ReadVector(),net.ReadFloat()
    if not IsValid(actor) then return end
    local effect=CreateParticleSystem(actor,"UndeadSS_Demonic_Resurection_source",PATTACH_CUSTOMORIGIN,0)
    if not effect then return end
    effect:SetControlPoint(0,pos)
    local angles=normal:Angle()
    effect:SetControlPointOrientation(0,angles:Up(),angles:Right(),angles:Forward())
    effects[#effects+1]={actor=actor,effect=effect,expires=CurTime()+math.min(life,14)}
end)
hook.Add("Think","ZA1/ResurrectionFX",function()
    if #effects==0 then return end
    for index=#effects,1,-1 do
        local row=effects[index]
        if not IsValid(row.actor) or CurTime()>=row.expires then
            if row.effect:IsValid() then row.effect:StopEmissionAndDestroyImmediately() end
            table.remove(effects,index)
        end
    end
end)
hook.Add("PostCleanupMap","ZA1/ResurrectionFX",function()
    for _,row in ipairs(effects) do if row.effect:IsValid() then row.effect:StopEmissionAndDestroyImmediately() end end
    effects={}
end)
