-- Insert the display names of your weapons into 'weapon_names'.
-- Insert the codes of your weapons (name of its folder) into 'weapon_codes'. Make sure you keep it in the same order as 'weapon_names'.
-- You can separate multiple entries with commata. You have to put the names between two quotation marks!

local weapon_names = {
	"M16",
	"MAC-10",
	"Shotgun",
	"Scout Rifle",
	"Pistol",
	"Glock",
	"Desert Eagle"
}

local weapon_codes = {
	"weapon_ttt_m16",
	"weapon_zm_mac10",
	"weapon_zm_shotgun",
	"weapon_zm_rifle",
	"weapon_zm_pistol",
	"weapon_ttt_glock",
	"weapon_zm_revolver"
}


-- #####################################################################
-- ## ACTUAL CODE - DON'T MESS WITH UNLESS YOU KNOW WHAT YOU'RE DOING ##
-- #####################################################################
-- ##                          MADE BY w4rum                          ##
-- #####################################################################

-- ######## SWEP Configuration
SWEP.HoldType 				= "slam"

SWEP.Base 				= "weapon_tttbase"

SWEP.ViewModel  			= Model("models/weapons/v_c4.mdl")
SWEP.WorldModel 			= Model("models/weapons/w_c4.mdl")

SWEP.Kind 					= WEAPON_EQUIP2
SWEP.AutoSpawnable 			= false
SWEP.CanBuy 				= { ROLE_TRAITOR }
SWEP.LimitedStock 			= true

SWEP.WeaponID 				= WEAPON_BYTE_DEATHFAKER
SWEP.Primary.ClipSize                   = -1
SWEP.Primary.DefaultClip                = -1
SWEP.Primary.Ammo       	        = "noammo"
SWEP.Primary.Delay 			= 1.0
SWEP.Secondary.Delay		        = 1.0
SWEP.NoSights 				= true
SWEP.AllowDrop 				= false


-- ######## CLIENT CODE
if CLIENT then
    SWEP.PrintName                      = "Death Faker"
    SWEP.Slot                           = 7 
    
    SWEP.ViewModelFOV                   = 10
    SWEP.Icon                           = "vgui/ttt/icon_byte_deathfaker"
   
    SWEP.EquipMenuData = {
      type  = "item_weapon",
      name  = "Death Faker",
      desc  = "Turn yourself into a fake corpse!\nLMB for faking, RMB for configuration,\nReload for revival.\nMade by w4rum."
    };	
	
	hook.Add("TTTScoreGroup", "sghookdeathfaker", function(p)
		if p:GetNWBool("death_faked",false) and p:IsTerror() then -- work the scoreboard in a different way if the death was faked and the real player is still alive
			local client = LocalPlayer()
			if client:IsSpec() or client:IsActiveTraitor() or ((GAMEMODE.round_state != ROUND_ACTIVE) and client:IsTerror()) then
				return GROUP_TERROR -- Specs or Traitors will always see the through the fake
			elseif (p:GetNWBool("body_found", false)) then
				return GROUP_FOUND -- Innos and Detes will interpret the corpse as a death confirmation
			else
				return GROUP_TERROR -- Innos and Detes will not know about the fake until it's found
			end
		end
	end)
	-- ######## Clientside Variables
	local menu_open = false
end


-- ######## SERVER CODE
if SERVER then
   resource.AddFile("materials/vgui/ttt/icon_byte_deathfaker.vmt")
   AddCSLuaFile("shared.lua")
   util.AddNetworkString("deathfakerconfig")
   
	local function Unfake()
		for i, j in pairs(player.GetAll()) do -- set death_faked to false for every player
			if j:GetNWBool("death_faked", false) then
				j:SetNoDraw(false)
				j:SetNWBool("death_faked", false)
			end
		end
	end
	hook.Add("TTTPrepareRound", "ttt-deathfaker-unfake", Unfake) -- just hook this into the start of each round so that we don't have to do it manually
	
	local function ResetConfigs()
		for i, j in pairs(player.GetAll()) do
			j:SetNWInt("deathf_reason", DMG_FALL) -- default reason of death is fall
			j:SetNWEntity("deathf_inflictor", game.GetWorld())
			j:SetNWBool("deathf_headshot", false)
			j:SetNWBool("deathf_innocent", true)
                        j:SetNWBool("deathf_scream", true)
		end
	end
	hook.Add("TTTPrepareRound", "ttt-deathfaker-deathfconfigreset", ResetConfigs) -- same as above
	
	local function DFPlayerDisconnected(p)
		if p:GetNWBool("death_faked", false) then
			ply.fake_corpse:Remove()
		end
	end
	
	hook.Add("PlayerDisconnected", "ttt-deathfaker-player-disconnected", DFPlayerDisconnected)
	
	net.Receive("deathfakerconfig", function(length, client)
		reason = net.ReadInt(32)
		weapon = net.ReadString()
		hsd = net.ReadBit()
		innorole = net.ReadBit()
                scream = net.ReadBit()

		local inflEntity = nil
		
		if (reason == DMG_FALL) or (reason == DMG_DIRECT) or (reason == DMG_BLAST) or (reason == DMG_DROWN) or (reason == DMG_CRUSH) then
			inflEntity = game.GetWorld()
		else
			inflEntity = ents.Create(weapon)
                end
		
		-- convert int to bool
		innorole = (innorole == 1)
                hsd = (hsd == 1)
                scream = (scream == 1)
		
		client:SetNWString("deathf_reason", reason)
		client:SetNWBool("deathf_headshot", hsd)
		client:SetNWEntity("deathf_inflictor", inflEntity)
		client:SetNWBool("deathf_innocent", innorole)
                client:SetNWBool("deathf_scream", scream)
	end)
	
	-- function for transferring the damage done to the corpse onto the player
	local function transferDamage(ent, dmginfo)
		if ent.sid then -- check for nil value
			local ply = player.GetBySteamID(ent.sid)
			if IsValid(ply) and (ent == ply.fake_corpse) then
				if (dmginfo:GetDamage() < 0) then
					dmginfo:ScaleDamage(-1)
				end
				if ((ply:Health() - dmginfo:GetDamage()) <= 0) then -- if this blow is going to be lethal
					dmginfo:SetDamage(1000) -- make sure it actually kills him, weird things can happen
					ply:SetPos(ent:LocalToWorld(ent:OBBCenter()) + vector_up / 2) -- move the player back to the corpse
					ply:TakeDamageInfo(dmginfo)
					ply:SetNWBool("death_faked", false)
					ent:Remove() -- remove the fake corpse
					timer.Simple(0, function() -- make sure its really the next tick
						if ply:IsTerror() then
							ply:Kill() -- leaves an ugly death message but this is our last resort
						end
					end)
				else
					ply:TakeDamageInfo(dmginfo)
				end
			end
		end
	end
	
	hook.Add("EntityTakeDamage", "ttt-deathfaker-corpsedmgcheck", transferDamage)
end

-- replace the fake corpse with a player's actual corpse when he's killed, disconnects, moves to spectator...
hook.Add("TTTOnCorpseCreated", "DFReplaceFakeCorpseWithReal", function (rag, ply)
	local ply = player.GetBySteamID(rag.sid)
	if ply:GetNWBool("death_faked", false) then
		-- Currently not working, corpse position is not being updated
		--[[
		print("before")
		local ragPos = rag:GetPos()
		local fakePos = ply.fake_corpse:GetPos()
		print("rag (" .. ragPos.x .. ", " .. ragPos.y .. ", " .. ragPos.z ..")")
		print("fake (" .. fakePos.x .. ", " .. fakePos.y .. ", " .. fakePos.z ..")")
		rag:SetPos(ply.fake_corpse:GetPos() + vector_up)
		print("after")
		local ragPos = rag:GetPos()
		local fakePos = ply.fake_corpse:GetPos()
		print("rag (" .. ragPos.x .. ", " .. ragPos.y .. ", " .. ragPos.z ..")")
		print("fake (" .. fakePos.x .. ", " .. fakePos.y .. ", " .. fakePos.z ..")")		ply.fake_corpse:Remove()
		--]]
		ply.fake_corpse:Remove()
		ply:SetNWBool("death_faked", false)
	end
end)

-- ######## SWEP Methods
function SWEP:PrimaryAttack()
	self.Weapon:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	local ply = self.Owner
	if not ply:GetNWBool("death_faked",false) then
			ply.server_ragdoll = nil
		if (SERVER) then
			local fakedmg = DamageInfo()
			fakedmg:SetDamage(100)
			fakedmg:SetDamageType(ply:GetNWInt("deathf_reason"))
			ply.was_headshot = ply:GetNWBool("deathf_headshot")
			fakedmg:SetInflictor(ply:GetNWEntity("deathf_inflictor"))
			local fake_role
			if ply:GetNWBool("deathf_innocent", false) then
				fake_role = ROLE_INNOCENT
			else
				fake_role = ROLE_TRAITOR
			end
			
			ply:ChatPrint("Press Reload to revive from the fake. This will delete the corpse but not reset your death status.")
			ply:SetNWBool("death_faked", true)
			
                        -- play scream sound if option is activated
                        if (ply:GetNWBool("deathf_scream", false)) then
                            local deathsounds = {
                               Sound("vo/npc/male01/pain07.wav"),
                               Sound("vo/npc/male01/pain08.wav"),
                               Sound("vo/npc/male01/pain09.wav"),
                               Sound("vo/npc/male01/no02.wav"),
                               Sound("hostage/hpain/hpain2.wav"),
                               Sound("hostage/hpain/hpain3.wav"),
                               Sound("hostage/hpain/hpain5.wav"),
                               Sound("hostage/hpain/hpain6.wav")
                            };
                           sound.Play(table.Random(deathsounds), ply:GetShootPos(), 90, 100)
                        end

			ply.fake_corpse = CreateFakeCorpse(ply, fakedmg, fake_role)
			
			-- Transform the player into the fake corpse, dropping all his things
			-- Drop all weapons (expect the Faker itself)
			for k, wep in pairs(ply:GetWeapons()) do
				if not (wep == self) then
					WEPS.DropNotifiedWeapon(ply, wep, true) -- with ammo in them
					wep:DampenDrop()
				end
			end
			
			ply:SpectateEntity(ply.fake_corpse)
			ply:SetObserverMode(OBS_MODE_CHASE)
			ply:Flashlight(false)
			ply:Extinguish()
			--ply:GodDisable()
			ply:SetNoDraw(true)
			ply:SetPos(Vector(-10000,-10000,-10000)) -- moving player out of the map to avoid being hit by bullets etc.
                        -- This is a dirty workaround because not rendering in addition to disabling entity-entity-collision does not suffice.
                        -- Unfortunately, this makes the player not hear the sound emitted near the corpse
			ply:SetNWBool("disguised", true) -- don't wanna be seen by curious detectives' radars
				
		end
		ply:SetCustomCollisionCheck(true)
                ply:CollisionRulesChanged()
	else
		ply:ChatPrint("You have already placed the corpse!")
	end
end

local function PosInTable(tbl, item)
	for i,v in ipairs(tbl) do
		if (v == item) then
			return i
		end
	end
	return false
end

function SWEP:SecondaryAttack() -- secondary attack opens up the configuration (death details)
	self.Weapon:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
	if (CLIENT) then
		if not menu_open and not self.Owner:GetNWBool("death_faked",false) then
			menu_open = true
			
			-- Create the panel
			local panel = vgui.Create("DFrame")
                        local panelWidth = 220
                        local panelHeight = 200 
			panel:SetPos((ScrW() - panelWidth) / 2, (ScrH() - panelHeight) / 2) -- put it in the center
			panel:SetSize(panelWidth, panelHeight)
			panel:SetTitle("Death Faker configuration")
			panel:SetVisible(true)
			panel:SetDraggable(true)
			panel:ShowCloseButton(false)
			
			-- Create the submit button
			local submit = vgui.Create("DButton")
			submit:SetParent(panel)
			submit:SetText("Submit")
			submit:SetPos(30,170)
			submit:SetSize(80,20)
			
			-- Create the abort button
			local abort = vgui.Create("DButton")
			abort:SetParent(panel)
			abort:SetText("Abort")
			abort:SetPos(110,170)
			abort:SetSize(80,20)
			abort.DoClick = function()
				menu_open = false
				panel:Close()
			end
			
			-- Create the list of roles
			local roles = vgui.Create ("DComboBox", panel)
			roles:SetPos(10,30)
			roles:SetSize(200,30)
			roles:AddChoice("Innocent")							-- 1
			roles:AddChoice("Traitor")							-- 2
			roles:SetValue("Innocent")
			
			-- Create the list of reasons
			local reasons = vgui.Create ("DComboBox", panel)
			reasons:SetPos(10,70)
			reasons:SetSize(200,30)
			reasons:AddChoice("Fell from a significant height")		-- 1
			reasons:AddChoice("Burned to death")			    	-- 2
			reasons:AddChoice("Ripped apart by an explosion")		-- 3
			reasons:AddChoice("Shot to death")			        -- 4
			reasons:AddChoice("Stabbed")					-- 5
			reasons:AddChoice("Drowned")					-- 6
			reasons:AddChoice("Crushed by a heavy object")			-- 7
			reasons:SetValue("Fell from a significant height")
			
			-- Create the scream-checkbox
			local scream = vgui.Create("DCheckBoxLabel", panel)
			scream:SetPos(10,100)
			scream:SetText("Scream")
			scream:SetChecked(true)
			scream:SetVisible(true)
			scream:SizeToContents()

			-- Create the list of weapons
			local weapons = vgui.Create ("DComboBox", panel)
			weapons:SetPos(10,120)
			weapons:SetSize(200,30)
			weapons:SetVisible(false)			-- only show when reason "shot" has been selected
			for i,wpn in ipairs(weapon_names) do
				weapons:AddChoice(wpn)
			end
			weapons:SetValue(weapon_names[1])
			
			-- Create the headshot-checkbox
			local headshot = vgui.Create("DCheckBoxLabel", panel)
			headshot:SetPos(10,150)
			headshot:SetText("Headshot")
			headshot:SetChecked(false)
			headshot:SetVisible(false)			-- same as weapons
			headshot:SizeToContents()
			
			-- Show weapons and headshot when "shot" is the reason
			reasons.OnSelect = function()
				if (reasons:GetValue() == "Shot to death") then
					weapons:SetVisible(true)
					headshot:SetVisible(true)
				else
					weapons:SetVisible(false)
					headshot:SetVisible(false)
					headshot:SetValue(0)
				end
			end
			
			-- Submit functionality
			submit.DoClick = function()
				local reasonValue = reasons:GetValue()
				local reasonCode = nil
				local weaponValue = weapons:GetValue()
				local weaponCode = ""
				local headshotValue = headshot:GetChecked()
				local roleValue = false
                                local screamValue = scream:GetChecked()
				
				-- We have to translate the chosen reasonValueson into the corresponding DMG_*
				weaponCode = weapon_codes[PosInTable(weapon_names, weaponValue)]
				
				if (roles:GetValue() == "Innocent") then
					roleValue = true
				end
				
				if (reasonValue == "Fell from a significant height") then
					reasonCode = DMG_FALL
				elseif (reasonValue == "Burned to death") then
					reasonCode = DMG_DIreasonCodeT
				elseif (reasonValue == "Ripped apart by an explosion") then
					reasonCode = DMG_BLAST
				elseif (reasonValue == "Shot to death") then
					reasonCode = DMG_BULLET
				elseif (reasonValue == "Stabbed") then
					reasonCode = DMG_SLASH
					weaponCode = "weapon_ttt_knife"
				elseif (reasonValue == "Drowned") then
					reasonCode = DMG_DROWN
				elseif (reasonValue == "Crushed by a heavy object") then
					reasonCode = DMG_CRUSH
				end
				
				-- Now, to the sending part
				net.Start("deathfakerconfig")
					net.WriteInt(reasonCode,32)
					net.WriteString(weaponCode)
					net.WriteBit(headshotValue)
					net.WriteBit(roleValue)
                                        net.WriteBit(screamValue)
				net.SendToServer()
				
				menu_open = false
				panel:Close()
				
			end
			
			-- Finally, open the panel inlcuding everything
			panel:MakePopup()
		end
	end
end


function SWEP:Reload() -- Reload is for standing back up, deleting the fake
	local ply = self.Owner
	if ply:GetNWBool("death_faked",false) then -- not able to stand back up before actually planting the fake
		
		if SERVER then
			-- back everything important up
			local credits = ply:GetCredits()					-- credits
			local equip = ply:GetEquipmentItems()				-- current equiptment
			local bought = ply.bought							-- shop stock
			local hp = ply:Health()								-- Health Points
			local bodyfound = ply:GetNWBool("body_found",false) -- death confirmed
			
			-- perform a respawn
			ply:SpawnForRound(false)
			
			-- move player back
			ply:SetNoDraw(false)
			ply:SetPos(ply.fake_corpse:LocalToWorld(ply.fake_corpse:OBBCenter()) + vector_up) -- revive a bit above the ground, don't wanna get stuck
			ply:SetEyeAngles(Angle(0, ply.fake_corpse:GetAngles().y, 0))
			ply:SetCollisionGroup(COLLISION_GROUP_WEAPON)
			timer.Simple(2, function() ply:SetCollisionGroup(COLLISION_GROUP_PLAYER) end)
			
			-- give stuff back
			ply:SetCredits(credits)
			ply.equipment_items = equip
			ply.bought = bought
			ply:SetHealth(hp)
			ply:SetNWBool("body_found", bodyfound)
                        ply:SetNWBool("death_faked", false)
			ply:SetCustomCollisionCheck(false)
			
			-- remove the fake corpse
			ply.fake_corpse:Remove()
			
			-- disable the deathfaker-disguiser
			ply:SetNWBool("disguised", false)

			
			-- finally, remove the Faker
			self:Remove()
		end
		
	else
		ply:ChatPrint("You need to place the fake before reviving from it.")
	end
end

function SWEP:OnDrop() -- The Faker should only be used by the owner himself and despawn as soon as dropped
	if SERVER then
		self:Remove() 
	end
end

-- ######## Additional functions
function CreateFakeCorpse(ply, dmginfo, role)  -- modified version of CORPSE.Create
   -- comments were made before implementing the role-choose option
   
   if not IsValid(ply) then return end

   local rag = ents.Create("prop_ragdoll")
   if not IsValid(rag) then return nil end

   rag:SetPos(ply:GetPos())
   rag:SetModel(ply:GetModel())
   rag:SetAngles(ply:GetAngles())
   rag:SetColor(ply:GetColor())

   rag:Spawn()
   rag:Activate()

   -- nonsolid to players, but can be picked up and shot
   rag:SetCollisionGroup(GetConVar("ttt_ragdoll_collide"):GetBool() and COLLISION_GROUP_WEAPON or COLLISION_GROUP_DEBRIS_TRIGGER)

   -- flag this ragdoll as being a player's
   rag.player_ragdoll = true
   rag.uqid = ply:UniqueID()
   rag.sid = ply:SteamID()

   -- network data
   CORPSE.SetPlayerNick(rag, ply)
   CORPSE.SetFound(rag, false)
   CORPSE.SetCredits(rag, 0) -- we keep our credits

   -- if someone searches this body they can find info on the victim and the
   -- death circumstances
   rag.equipment = nil -- we have no EQ to display as innocent
   rag.was_role = role -- fake our role to innocent
   rag.bomb_wire = nil -- we wouldn't be planting C4, would we?
   rag.dmgtype = dmginfo:GetDamageType()

   local wep = util.WeaponFromDamage(dmginfo)
   rag.dmgwep = IsValid(wep) and wep:GetClass() or ""

   rag.was_headshot = (ply.was_headshot and dmginfo:IsBulletDamage())
   rag.time = CurTime()
   rag.kills = {} -- Nooo, we certainly haven't killed anyone, we're innocent!

   rag.killer_sample = nil -- no sample, its a fake death

   -- crime scene data
   rag.scene = nil -- don't wanna make a scene here, do we?


   -- position the bones
   local num = rag:GetPhysicsObjectCount()-1
   local v = ply:GetVelocity()

   -- bullets have a lot of force, which feels better when shooting props,
   -- but makes bodies fly, so dampen that here
   if dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_SLASH) then
      v = v / 5
   end

   for i=0, num do
      local bone = rag:GetPhysicsObjectNum(i)
      if IsValid(bone) then
         local bp, ba = ply:GetBonePosition(rag:TranslatePhysBoneToBone(i))
         if bp and ba then
            bone:SetPos(bp)
            bone:SetAngles(ba)
         end

         -- not sure if this will work:
         bone:SetVelocity(v)
      end
   end

   -- create advanced death effects (knives)
   if ply.effect_fn then
      -- next frame, after physics is happy for this ragdoll
      local efn = ply.effect_fn
      timer.Simple(0, function() efn(rag) end)
   end

   return rag -- we'll be speccing this
end
	
local function DFShouldCollide( ent1, ent2 )
    if ( ent1:IsPlayer() and ent1:GetNWBool("death_faked", false) ) then
        return false
    elseif ( ent2:IsPlayer() and ent2:GetNWBool("death_faked", false) ) then
	return false
    end
end

hook.Add( "ShouldCollide", "DFShouldCollide", DFShouldCollideplayer )
