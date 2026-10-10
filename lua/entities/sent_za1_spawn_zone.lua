AddCSLuaFile()
ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Zombie Army Spawn Zone"
ENT.Spawnable=false
ENT.RenderGroup=RENDERGROUP_TRANSLUCENT
function ENT:SetupDataTables()
    self:NetworkVar("Float",0,"ZoneRadius")
    self:NetworkVar("Bool",0,"ZoneEnabled")
end
if SERVER then
    function ENT:Initialize()
        self:SetNoDraw(true);self:SetNotSolid(true);self:SetMoveType(MOVETYPE_NONE)
        ZA1.SpawnZones.Register(self)
    end
    function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end
    function ENT:OnRemove() if ZA1.SpawnZones then ZA1.SpawnZones.Remove(self) end end
    function ENT:OnTakeDamage() end
else
    local zones=setmetatable({},{__mode="k"})
    function ENT:Initialize() zones[self]=true end
    hook.Add("PostDrawTranslucentRenderables","ZA1/SpawnZones",function(_,sky)
        if sky then return end
        local ply=LocalPlayer();if not IsValid(ply) then return end
        local gun=ply:GetActiveWeapon()
        if not IsValid(gun) or gun:GetClass()~="gmod_tool" or ply:GetInfo("gmod_toolmode")~="za1_spawn_zones" then return end
        for zone in pairs(zones) do if IsValid(zone) and zone:GetPos():DistToSqr(ply:GetPos())<4096^2 then
            local color=zone:GetZoneEnabled() and Color(210,35,35,160) or Color(110,110,110,120)
            render.DrawWireframeSphere(zone:GetPos()+Vector(0,0,4),zone:GetZoneRadius(),24,4,color,true)
            render.DrawWireframeSphere(zone:GetPos()+Vector(0,0,16),16,12,6,color,true)
        end end
    end)
end
