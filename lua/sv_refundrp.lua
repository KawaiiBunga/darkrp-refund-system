// Add CS lua file

AddCSLuaFile( 'cl_refundrp.lua' )
AddCSLuaFile( 'sh_refundrp_config.lua' )
AddCSLuaFile( 'sh_refundrp_lang.lua' )

include( 'sh_refundrp_config.lua' )
include( 'sh_refundrp_lang.lua' )

// Network messages

util.AddNetworkString( 'refundMenu' )
util.AddNetworkString( 'refundCash' )
util.AddNetworkString( 'refundRespawn' )
util.AddNetworkString( 'refundRespawnOnly' )
util.AddNetworkString( 'refundRPMsg' )


// Enums

local refundEnums = {

	ENT = 0,
	WEP = 1,
	SHIP = 2
}


// Tables

local refund = {}
local canRefund = {}
local rpEntities = {}


// Returns index of first instance of name in the table

local function refundEntNameInTab( refundTab, lostEntTab )

	for k, v in next, refundTab do
	
		if ( string.find( v, lostEntTab.name ) != nil ) then
		
			return k
		end
	end
	
	return -1 // sentinel value
end


// Hooks

local REFUND_SERVER_RESTART = false

hook.Add( "ShutDown", "SD_RSE", function()

	REFUND_SERVER_RESTART = true
end )

hook.Add( "InitPostEntity", "IPE_RSE", function()

	timer.Simple( 1, function()
	
		if ( !sql.TableExists( "rpRefund" ) ) then
		
			sql.Query( [[CREATE TABLE rpRefund ( id VARCHAR(20), txt TEXT )]] )
		end
		
		
		// Store the custom entities in an order (to avoid looping later on)
		
		for k = 1, #DarkRPEntities do

			local t = table.Copy( DarkRPEntities[ k ] )
			local name = string.Trim( t.name ) != "" && t.name || t.cmd
			
			rpEntities[ name ] = t
		end
		
		// Override create function

		local rpCreateEntity = DarkRP.createEntity

		function DarkRP.createEntity( name, entity, model, price, max, command, classes, CustomCheck )

			rpCreateEntity( name, entity, model, price, max, command, classes, CustomCheck )
			
			local t = table.Copy( DarkRPEntities[ #DarkRPEntities ] )
			local name = string.Trim( t.name ) != "" && t.name || t.cmd
			
			rpEntities[ name ] = t
		end
	end )
end )

hook.Add( "PlayerInitialSpawn", "PIS_RSE", function( ply )

	timer.Simple( 1, function()
	
		local id = ply:SteamID()
		local json = sql.QueryValue( "SELECT txt FROM rpRefund WHERE id = '" .. id .. "'" )
		
		if ( json != nil && json ) then
		
			refund[ id ] = util.JSONToTable( json )
			
			if ( table.Count( refund[ id ] ) > 0 ) then
				
				local methCash = refund[ id ][ "meth" ]
				
				if ( methCash != nil ) then
					
					ply:SetNWInt( "player_meth", methCash )
					
					// Return if the only entry is the meth
					if ( table.Count( refund[ id ] ) == 1 ) then
					
						return
					end
				end
				
				canRefund[ id ] = true
				
				net.Start( 'refundMenu' )
					net.WriteTable( refund[ id ] )
				net.Send( ply )
			end
		else
		
			refund[ id ] = {}
			sql.Query( "INSERT INTO rpRefund (`id`, `txt`) VALUES ('" .. id .. "', '[]')" )
		end
	end )
end )


gameevent.Listen( "player_disconnect" )

hook.Add( "player_disconnect", "PD_RSE", function( data )

	local reason = data.reason
	
	if ( ( string.lower( reason ) == "disconnect by user." ) && !REFUND_SERVER_RESTART ) then
	
		local id = data.networkid
		refund[ id ] = nil
		canRefund[ id ] = nil
		
		sql.Query( "UPDATE rpRefund SET txt = '[]' WHERE id = '" .. id .. "'" )
	end
end )


local function playerBoughtEntity( ply, entTable, ent, price, typ )

	timer.Simple( 1, function()
	
		if ( IsValid( ply ) && IsValid( ent ) ) then
			
			local id = ply:SteamID()
			
			refund[ id ][ ent:EntIndex() ] = {
				name = string.Trim( entTable.name ) != "" && entTable.name || entTable.cmd,
				typ = typ,
			}
			
			if ( ent.GetNetworkVars ) then
				refund[ id ][ ent:EntIndex() ].DT = ent:GetNetworkVars()
			else
				refund[ id ][ ent:EntIndex() ].DT = {}
			end
			
			local json = util.TableToJSON( refund[ id ] )
			sql.Query( "UPDATE rpRefund SET txt = '" .. json .. "' WHERE id = '" .. id .. "'" )
			
			--
			
			if ( ent.GetNetworkVars ) then
			
				local entindex = ent:EntIndex()
				
				timer.Create( "saveCustomEntity" .. entindex, REFUND_RP.CONFIG.REFRESH_NETVARS, 0, function()
					
					if ( IsValid( ply ) && IsValid( ent ) && refund[ id ] && refund[ id ][ entindex ] ) then
					
						local id = ply:SteamID()
						refund[ id ][ entindex ].DT = ent:GetNetworkVars()
						
						-- CustomHQ printer support
						if ( ent.PrintName == "MoneyPrinter_Base" ) then
						
							refund[ id ][ entindex ].PR = { // 'PR' stands for printer
								nm = ent.PName, 
								pw = ent.PPower, 
								pt = ent.PTemp, 
								mn = ent.PMoney, 
								en = ent.PEnable, 
								cs = ent.PCoolerState, 
								ptm = ent.PTime, 
								pp = ent.PPaper, 
								mp = ent.MaxPapers, 
								pc = ent.PColors, 
 								mc = ent.MaxColors, 
								cc = ent.CClass,
							}
						elseif ( ent.GetClass && string.find( ent:GetClass(), "boost_printer" ) != nil ) then
							
							refund[ id ][ entindex ].PR2 = {
								b = ent.Battery, 
								h = ent.Heat, 
								s = ent.Speed, 
								pm = ent.PrintedMoney, 
								c = ent.Cooling, 
								pr = ( ent.Speed * TPRINTERS_CONFIG.Money ), 
								n = TPRINTERS_CONFIG.Name,
							}
						end
						
						local json = util.TableToJSON( refund[ id ] )
						sql.Query( "UPDATE rpRefund SET txt = '" .. json .. "' WHERE id = '" .. id .. "'" )
					else
					
						timer.Destroy( "saveCustomEntity" .. entindex )
					end
				end )
			end
		end
	end )
end

hook.Add( "playerBoughtPistol", "PBP_RSE", function( ply, weaponTable, ent, price )

	ent.owner = ply
	playerBoughtEntity( ply, weaponTable, ent, price, refundEnums.WEP )
end )

hook.Add( "playerBoughtCustomEntity", "PBCE_RSE", function( ply, entTable, ent, price )

	playerBoughtEntity( ply, entTable, ent, price, refundEnums.ENT )
end )

hook.Add( "playerBoughtShipment", "PBS_RSE", function( ply, shipTable, ent, price )

	playerBoughtEntity( ply, shipTable, ent, price, refundEnums.SHIP )
	
	// Redefined SpawnItem method
	// Thanks to FPtje, fruitwasp, MStruntze, Fuzzik, and Bo98

	// https://github.com/FPtje/DarkRP/blob/master/entities/entities/spawned_shipment/init.lua
	
	ent.SpawnItem = function( self )
	
		if not IsValid(self) then return end
		timer.Remove(self:EntIndex() .. "crate")
		self.sparking = false
		local count = self:Getcount()
		if count <= 1 then self:Remove() end
		local contents = self:Getcontents()

		if CustomShipments[contents] and CustomShipments[contents].spawn then self.USED = false return CustomShipments[contents].spawn(self, CustomShipments[contents]) end

		local weapon = ents.Create("spawned_weapon")

		local weaponAng = self:GetAngles()
		local weaponPos = self:GetAngles():Up() * 40 + weaponAng:Up() * (math.sin(CurTime() * 3) * 8)
		weaponAng:RotateAroundAxis(weaponAng:Up(), (CurTime() * 180) % 360)

		if not CustomShipments[contents] then
			weapon:Remove()
			self:Remove()
			return
		end

		local class = CustomShipments[contents].entity
		local model = CustomShipments[contents].model

		weapon:SetWeaponClass(class)
		weapon:SetModel(model)
		weapon.ammoadd = self.ammoadd or (weapons.Get(class) and weapons.Get(class).Primary.DefaultClip)
		weapon.clip1 = self.clip1
		weapon.clip2 = self.clip2
		weapon:SetPos(self:GetPos() + weaponPos)
		weapon:SetAngles(weaponAng)
		weapon.nodupe = true
		weapon:Spawn()
		
		count = count - 1
		self:Setcount(count)
		self.locked = false
		self.USED = nil
		
		local t = CustomShipments[ self:Getcontents() or "" ]
		
		if ( t != nil ) then
			hook.Call( "playerBoughtPistol", nil, self.Getowning_ent && self:Getowning_ent() || nil, t, weapon, math.floor( t.price * ( 1 / t.amount ) ) )
		end
	end
end )

hook.Add( "EntityRemoved", "ER_RSE", function( ent )

	local ply = ent.Getowning_ent && ent:Getowning_ent() || ( ( ent.dt && type( ent.dt ) == "table" ) && ent.dt.owning_ent || ( ent.owner || nil ) )
	
	if ( IsValid( ply ) && IsValid( ent ) && ply.SteamID && refund[ ply:SteamID() ][ ent:EntIndex() ] && !REFUND_SERVER_RESTART ) then
	
		local id = ply:SteamID()
		local entindex = ent:EntIndex()
		
		timer.Destroy( "saveCustomEntity" .. entindex )
		
		refund[ id ][ entindex ] = nil
		
		local json = util.TableToJSON( refund[ id ] )
		sql.Query( "UPDATE rpRefund SET txt = '" .. json .. "' WHERE id = '" .. id .. "'" )
	end
end )

hook.Add( "PlayerSay", "PS_RSE", function( ply, txt )
	
	if ( string.Trim( txt ) == "!refund" ) then
	
		local t = refund[ ply:SteamID() ]
		
		if ( t != nil && table.Count( t ) > 0 && canRefund[ ply:SteamID() ] ) then
		
			net.Start( "refundMenu" )
				net.WriteTable( t )
			net.Send( ply )
		end
	end
end )

-- Meth compatibility
hook.Add( "PlayerUse", "PU_RSE", function( ply, ent )

	if ( IsValid( ent ) && ent.GetClass && ent:GetClass() == "eml_meth" ) then
		
		if ( EML_Meth_UseSalesman && IsValid( ply ) ) then
			
			local newValue = ply:GetNWInt( "player_meth" ) + ( ent:GetNWInt( "amount" ) * EML_Meth_ValueModifier )
			if ( newValue == nil ) then
				newValue = 0
			end
			
			local id = ply:SteamID()
			
			refund[ id ][ "meth" ] = newValue
			
			local json = util.TableToJSON( refund[ id ] )
			sql.Query( "UPDATE rpRefund SET txt = '" .. json .. "' WHERE id = '" .. id .. "'" )
		end
	end
end )


// Network messages

net.Receive( "refundCash", function( len, ply )
	
	local id = ply:SteamID()
	local t = refund[ id ]
	
	if ( t != nil && canRefund[ id ] ) then
		
		local refundCost = 0
		
		for k, v in next, t do
		
			local entTab
			
			if ( v.typ == refundEnums.WEP || v.typ == refundEnums.SHIP ) then
			
				entTab = DarkRP.getShipmentByName( v.name )
				
				if ( v.DT && v.DT.amount ) then
					refundCost = refundCost + math.floor( entTab.price * ( v.DT.amount / entTab.amount ) )
				else
					refundCost = refundCost + math.floor( entTab.price * ( v.DT.count / entTab.amount ) )
				end
			else
			
				entTab = rpEntities[ v.name ]
				refundCost = refundCost + math.floor( entTab.price )
			end
		end
		
		refundCost = math.floor( refundCost * math.Clamp( REFUND_RP.CONFIG.REFUND_RATE, 0, 1 ) )
		ply:addMoney( refundCost )
		
		net.Start( "refundRPMsg" )
			net.WriteString( refundCost )
		net.Send( ply )
		
		--
		
		refund[ id ] = {}
		canRefund[ id ] = false
		
		sql.Query( "UPDATE rpRefund SET txt = '[]' WHERE id = '" .. id .. "'" )
	end
end )

net.Receive( "refundRespawnOnly", function( len, ply )

	if ( REFUND_RP.CONFIG.REFUND_ONLY ) then return end
	
	local id = ply:SteamID()
	local t = refund[ id ]
	
	if ( t != nil && canRefund[ id ] != nil ) then
		
		for k, v in next, t do
		
			local entTab
			
			if ( v.typ == refundEnums.WEP || v.typ == refundEnums.SHIP ) then
				entTab = DarkRP.getShipmentByName( v.name )
			else
				entTab = rpEntities[ v.name ]
			end
			
			if ( entTab != nil ) then
			
				local trace = {}
				trace.start = ply:EyePos()
				trace.endpos = trace.start + ply:GetAimVector() * 85
				trace.filter = ply
				
				local tr = util.TraceLine( trace )
				
				
				if ( v.typ == refundEnums.WEP ) then
				
					local weapon = ents.Create( "spawned_weapon" )
					weapon:SetModel( entTab.model )
					weapon:SetWeaponClass( entTab.entity )
					weapon:SetPos( tr.HitPos )
					weapon.ammoadd = weapons.Get( entTab.entity ) and ( entTab.spareammo or weapons.Get( entTab.entity ).Primary.DefaultClip )
					weapon.clip1 = entTab.clip1
					weapon.clip2 = entTab.clip2
					weapon.nodupe = true
					weapon:Spawn()
					
					if ( IsValid( weapon ) && weapon.RestoreNetworkVars ) then
						weapon:RestoreNetworkVars( v.DT )
					end
					
					if ( entTab.onBought ) then
						entTab.onBought( ply, entTab, weapon )
					end
					
					local cost = price or entTab.getPrice and entTab.getPrice( ply, entTab.pricesep ) or entTab.pricesep or 0
					hook.Call( "playerBoughtPistol", nil, ply, entTab, weapon, cost )
					
				elseif ( v.typ == refundEnums.SHIP ) then
				
					local found, key = DarkRP.getShipmentByName( v.name )
					
					local crate = ents.Create( found.shipmentClass or "spawned_shipment" )
					crate.SID = ply.SID
					crate:Setowning_ent( ply )
					crate:SetContents( key, entTab.amount )
					
					crate:SetPos( Vector( tr.HitPos.x, tr.HitPos.y, tr.HitPos.z ) )
					crate.nodupe = true
					crate.ammoadd = entTab.spareammo
					crate.clip1 = entTab.clip1
					crate.clip2 = entTab.clip2
					crate:Spawn()
					crate:SetPlayer( ply )
					
					local phys = crate:GetPhysicsObject()
					phys:Wake()
					
					if ( entTab.weight ) then
						phys:SetMass( entTab.weight )
					end
					
					if ( CustomShipments[ key ].onBought ) then
						CustomShipments[ key ].onBought( ply, CustomShipments[ key ], crate )
					end
					
					hook.Call( "playerBoughtShipment", nil, ply, CustomShipments[ key ], crate, entTab.price )
				else
				
					local pass = true
					
					if ( ply:customEntityLimitReached( entTab ) && !REFUND_RP.CONFIG.SURPASS_LIMIT ) then
						
						DarkRP.notify( ply, 1, 4, DarkRP.getPhrase( "limit", entTab.name ) )
						pass = false
					end
					
					if ( pass ) then
						
						local ent
						
						if ( entTab.spawn ) then
						
							ent = entTab.spawn( ply, tr, entTab )
							
							ent.onlyremover = true
							ent.SID = ply.SID
							ent.allowed = entTab.allowed
							ent.DarkRPItem = entTab
							
							if ( IsValid( ent ) && ent.RestoreNetworkVars ) then
								ent:RestoreNetworkVars( v.DT )
							end
						else
						
							ent = ents.Create( entTab.ent )
							
							ent.dt = ent.dt or {}
							ent.dt.owning_ent = ply
							if ( ent.Setowning_ent ) then ent:Setowning_ent( ply ) end
							
							--
							
							table.Merge( ent:GetTable(), v )
							
							--
							
							local pos, mins = ent:GetPos(), ent:WorldSpaceAABB()
							local offset = pos.z - mins.z
							
							ent:SetPos( tr.HitPos + Vector( 0, 0, offset ) )
							
							
							--
							
							// Avoid potential lua errors
							ent.onlyremover = true
							ent.SID = ply.SID
							ent.allowed = entTab.allowed
							ent.DarkRPItem = entTab
							
							--
							
							if ( IsValid( ent ) && ent.RestoreNetworkVars ) then
								ent:RestoreNetworkVars( v.DT )
							end
							
							--
							
							ent:Spawn()
							ent:Activate()
						end
						
						
						local phys = ent:GetPhysicsObject()
						
						timer.Simple( 0, function()
						
							if ( phys:IsValid() ) then
								phys:Wake()
							end
							
							-- CustomHQ printer support
							if ( v.PR ) then
								
								local t = v.PR
								
								ent.PName 			= t.nm
								ent.PPower			= t.pw
								ent.PTemp			= t.pt
								ent.PMoney 			= t.mn
								ent.PEnable 		= t.en
								ent.PCoolerState 	= t.cs
								ent.PTime 			= t.ptm
								ent.PPaper			= t.pp
								ent.MaxPapers 		= t.mp
								ent.PColors 		= t.pc
								ent.MaxColors		= t.mc
								ent.CClass			= t.cc
								
								timer.Simple( 2, function()
									
									if ( IsValid( ent ) ) then
										
										local ptab = {}
										ptab[ "name" ] 		= ent.PName
										ptab[ "power" ]		= ent.PPower
										ptab[ "temp" ] 		= math.floor( ent.PTemp )
										ptab[ "money" ] 	= ent.PMoney
										ptab[ "enable" ]	= ent.PEnable
										ptab[ "cooler" ]	= ent.PCoolerState
										ptab[ "time" ] 		= ent.PTime
										ptab[ "paper" ]		= ent.PPaper .. " / " .. ent.MaxPapers
										ptab[ "colors" ]	= ent.PColors.." / " .. ent.MaxColors
										
										net.Start( "customprinter_send" )
											net.WriteEntity( ent )
											net.WriteTable( ptab )
										net.Broadcast()
										
										--
										
										if ( ent.CClass != nil && ent.CClass ) then
										
											local cooler = ents.Create( ent.CClass )
											cooler:Spawn()
											cooler:Activate()
											
											ent:CreateCooler( cooler )
										end
									end
								end )
							elseif ( v.PR2 ) then
								
								local t = v.PR2
								
								ent.Battery = t.b
								ent.Heat = t.h
								ent.Speed = t.s
								ent.PrintedMoney = t.pm
								ent.Cooling = t.c
								ent.PrintRate = t.pr
								ent.Name = t.n
								
								timer.Simple( 2, function()
								
									if ( IsValid( ent ) ) then
									
										local ptab = {}
										ptab.Battery = t.b
										ptab.Heat = t.h
										ptab.Speed = t.s
										ptab.PrintedMoney = t.pm
										ptab.Cooling = t.c
										ptab.PrintRate = t.pr
										ptab.Name = t.n
										
										net.Start( "UpdatePrinter" )
											net.WriteTable( ptab )
											net.WriteEntity( ent )
										net.Broadcast()
									end
								end )
							end
						end )
						
						hook.Call( "playerBoughtCustomEntity", nil, ply, entTab, ent, entTab.price )
						ply:addCustomEntity( entTab )
					end
				end
			end
			
			refund[ id ] = {}
			sql.Query( "UPDATE rpRefund SET txt = '[]' WHERE id = '" ..  id .. "'" )
			canRefund[ id ] = false
		end
	end
end )

net.Receive( "refundRespawn", function( len, ply )
	
	if ( REFUND_RP.CONFIG.REFUND_ONLY ) then return end
	
	local id = ply:SteamID()
	local t = refund[ id ]
	
	if ( t != nil && canRefund[ id ] != nil ) then
		
		local refundEnt = net.ReadTable()
		
		if ( refundEnt ) then
			
			local refundCost = 0
			
			for k, v in next, t do
			
				local fIndex = refundEntNameInTab( refundEnt, v )
				
				if ( fIndex != -1 ) then
					
					local entTab
					
					if ( v.typ == refundEnums.WEP || v.typ == refundEnums.SHIP ) then
					
						entTab = DarkRP.getShipmentByName( v.name )
						
						if ( v.DT && v.DT.amount ) then
							refundCost = refundCost + math.floor( entTab.price * ( v.DT.amount / entTab.amount ) * math.Clamp( REFUND_RP.CONFIG.REFUND_RATE, 0, 1 ) )
						else
							refundCost = refundCost + math.floor( entTab.price * ( v.DT.count / entTab.amount ) * math.Clamp( REFUND_RP.CONFIG.REFUND_RATE, 0, 1 ) )
						end
					else
					
						entTab = rpEntities[ v.name ]
						refundCost = refundCost + math.floor( entTab.price * math.Clamp( REFUND_RP.CONFIG.REFUND_RATE, 0, 1 ) )
					end
					
					table.remove( refundEnt, fIndex )
				else
					
					local entTab
					
					if ( v.typ == refundEnums.WEP || v.typ == refundEnums.SHIP ) then
						entTab = DarkRP.getShipmentByName( v.name )
					else
						entTab = rpEntities[ v.name ]
					end
					
					if ( entTab != nil ) then
					
						local trace = {}
						trace.start = ply:EyePos()
						trace.endpos = trace.start + ply:GetAimVector() * 85
						trace.filter = ply
						
						local tr = util.TraceLine( trace )
						
						if ( v.typ == refundEnums.WEP ) then
						
							local weapon = ents.Create( "spawned_weapon" )
							weapon:SetModel( entTab.model )
							weapon:SetWeaponClass( entTab.entity )
							weapon:SetPos( tr.HitPos )
							weapon.ammoadd = weapons.Get( entTab.entity ) and ( entTab.spareammo or weapons.Get( entTab.entity ).Primary.DefaultClip )
							weapon.clip1 = entTab.clip1
							weapon.clip2 = entTab.clip2
							weapon.nodupe = true
							weapon:Spawn()
							
							if ( IsValid( weapon ) && weapon.RestoreNetworkVars ) then
								weapon:RestoreNetworkVars( v.DT )
							end
							
							if ( entTab.onBought ) then
								entTab.onBought( ply, entTab, weapon )
							end
							
							local cost = price or entTab.getPrice and entTab.getPrice( ply, entTab.pricesep ) or entTab.pricesep or 0
							hook.Call( "playerBoughtPistol", nil, ply, entTab, weapon, cost )
							
						elseif ( v.typ == refundEnums.SHIP ) then
							

							local found, key = DarkRP.getShipmentByName( v.name )
							
							local crate = ents.Create( found.shipmentClass or "spawned_shipment" )
							crate.SID = ply.SID
							crate:Setowning_ent( ply )
							crate:SetContents( key, entTab.amount )
							
							crate:SetPos( Vector( tr.HitPos.x, tr.HitPos.y, tr.HitPos.z ) )
							crate.nodupe = true
							crate.ammoadd = entTab.spareammo
							crate.clip1 = entTab.clip1
							crate.clip2 = entTab.clip2
							crate:Spawn()
							crate:SetPlayer( ply )
							
							local phys = crate:GetPhysicsObject()
							phys:Wake()
							
							if ( entTab.weight ) then
								phys:SetMass( entTab.weight )
							end
							
							if ( CustomShipments[ key ].onBought ) then
								CustomShipments[ key ].onBought( ply, CustomShipments[ key ], crate )
							end
							
							hook.Call( "playerBoughtShipment", nil, ply, CustomShipments[ key ], crate, entTab.price )
						else
							
							local pass = true
							
							if ( ply:customEntityLimitReached( entTab ) && !REFUND_RP.CONFIG.SURPASS_LIMIT ) then
								
								DarkRP.notify( ply, 1, 4, DarkRP.getPhrase( "limit", entTab.name ) )
								refundCost = refundCost + math.floor( entTab.price * math.Clamp( REFUND_RP.CONFIG.REFUND_RATE, 0, 1 ) )
								pass = false
							end
							
							if ( pass ) then
								
									
								local ent
								
								if ( entTab.spawn ) then
								
									ent = entTab.spawn( ply, tr, entTab )
									
									-- For good measure
									ent.onlyremover = true
									ent.SID = ply.SID
									ent.allowed = entTab.allowed
									ent.DarkRPItem = entTab
								else
								
									ent = ents.Create( entTab.ent )
									
									ent.dt = ent.dt or {}
									ent.dt.owning_ent = ply
									if ( ent.Setowning_ent ) then ent:Setowning_ent( ply ) end
									
									--
									
									table.Merge( ent:GetTable(), v )
									
									--
									
									local pos, mins = ent:GetPos(), ent:WorldSpaceAABB()
									local offset = pos.z - mins.z
									
									ent:SetPos( tr.HitPos + Vector( 0, 0, offset ) )
									
									----
									
									-- Avoid potential lua errors
									ent.onlyremover = true
									ent.SID = ply.SID
									ent.allowed = entTab.allowed
									ent.DarkRPItem = entTab
									
									----
									
									ent:Spawn()
									ent:Activate()
								end
								
								local phys = ent:GetPhysicsObject()
								
								timer.Simple( 0, function()
								
									if ( phys:IsValid() ) then
										phys:Wake()
									end
									
									if ( IsValid( ent ) && ent.RestoreNetworkVars ) then
										ent:RestoreNetworkVars( v.DT )
									end
									
									-- CustomHQ printer support
									if ( v.PR ) then
										
										local t = v.PR
										
										ent.PName 			= t.nm
										ent.PPower			= t.pw
										ent.PTemp			= t.pt
										ent.PMoney 			= t.mn
										ent.PEnable 		= t.en
										ent.PCoolerState 	= t.cs
										ent.PTime 			= t.ptm
										ent.PPaper			= t.pp
										ent.MaxPapers 		= t.mp
										ent.PColors 		= t.pc
										ent.MaxColors		= t.mc
										ent.CClass			= t.cc
										
										timer.Simple( 2, function()
											
											if ( IsValid( ent ) ) then
												
												local ptab = {}
												ptab[ "name" ] 		= ent.PName
												ptab[ "power" ]		= ent.PPower
												ptab[ "temp" ] 		= math.floor( ent.PTemp )
												ptab[ "money" ] 	= ent.PMoney
												ptab[ "enable" ]	= ent.PEnable
												ptab[ "cooler" ]	= ent.PCoolerState
												ptab[ "time" ] 		= ent.PTime
												ptab[ "paper" ]		= ent.PPaper .. " / " .. ent.MaxPapers
												ptab[ "colors" ]	= ent.PColors.." / " .. ent.MaxColors
												
												net.Start( "customprinter_send" )
													net.WriteEntity( ent )
													net.WriteTable( ptab )
												net.Broadcast()
												
												--
												
												if ( ent.CClass != nil && ent.CClass ) then
												
													local cooler = ents.Create( ent.CClass )
													cooler:Spawn()
													cooler:Activate()
													
													ent:CreateCooler( cooler )
												end
											end
										end )
									elseif ( v.PR2 ) then
										
										local t = v.PR2
										
										ent.Battery = t.b
										ent.Heat = t.h
										ent.Speed = t.s
										ent.PrintedMoney = t.pm
										ent.Cooling = t.c
										ent.PrintRate = t.pr
										ent.Name = t.n
										
										timer.Simple( 2, function()
										
											if ( IsValid( ent ) ) then
											
												local ptab = {}
												ptab.Battery = t.b
												ptab.Heat = t.h
												ptab.Speed = t.s
												ptab.PrintedMoney = t.pm
												ptab.Cooling = t.c
												ptab.PrintRate = t.pr
												ptab.Name = t.n
												
												net.Start( "UpdatePrinter" )
													net.WriteTable( ptab )
													net.WriteEntity( ent )
												net.Broadcast()
											end
										end )
									end
								end )
								
								hook.Call( "playerBoughtCustomEntity", nil, ply, entTab, ent, entTab.price )
								ply:addCustomEntity( entTab )
							end
						end
					end
				end
			end
			
			if ( refundCost > 0 ) then
			
				ply:addMoney( refundCost )
				
				net.Start( "refundRPMsg" )
					net.WriteString( refundCost )
				net.Send( ply )
			end
			
			refund[ id ] = {}
			
			sql.Query( "UPDATE rpRefund SET txt = '[]' WHERE id = '" ..  id .. "'" )
			canRefund[ id ] = false
		end
	end
end )


timer.Simple( 2, function()

	// Redefined shipment functions
	// Thanks to FPtje, fruitwasp, MStruntze, Fuzzik, and Bo98

	// https://github.com/FPtje/DarkRP/blob/master/entities/entities/spawned_shipment/commands.lua

	--[[---------------------------------------------------------------------------
	Create a shipment from a spawned_weapon
	---------------------------------------------------------------------------]]
	local function createShipment(ply, args)
		local id = tonumber(args) or -1
		local ent = Entity(id)

		ent = IsValid(ent) and ent or ply:GetEyeTrace().Entity

		if not IsValid(ent) or not ent.IsSpawnedWeapon or ent.PlayerUse == false then
			DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
			return
		end

		local pos = ent:GetPos()

		if pos:Distance(ply:GetShootPos()) > 130 or not pos:isInSight({ent, ply} , ply) then
			DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("distance_too_big"))
			return
		end

		ent.PlayerUse = false

		local shipID
		for k,v in pairs(CustomShipments) do
			if v.entity == ent:GetWeaponClass() then
				shipID = k
				break
			end
		end

		if not shipID or ent.USED then
			DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("unable", "/makeshipment", ""))
			return
		end

		local crate = ents.Create(CustomShipments[shipID].shipmentClass or "spawned_shipment")
		crate.SID = ply.SID
		crate:SetPos(ent:GetPos())
		crate.nodupe = true
		crate:SetContents(shipID, ent.dt.amount)
		crate:Spawn()
		crate:SetPlayer(ply)
		crate:Setowning_ent( ply )
		
		crate.clip1 = ent.clip1
		crate.clip2 = ent.clip2
		crate.ammoadd = ent.ammoadd or 0
		
		SafeRemoveEntity(ent)

		local phys = crate:GetPhysicsObject()
		phys:Wake()
		
		local t = CustomShipments[ crate:Getcontents() or "" ]
		
		if ( t != nil && ent.owner == ply ) then
			hook.Call( "playerBoughtShipment", nil, ply, t, crate, 0 )
		end
	end
	DarkRP.defineChatCommand("makeshipment", createShipment, 0.3)
	
	--[[---------------------------------------------------------------------------
	Split a shipment in two
	---------------------------------------------------------------------------]]
	local function splitShipment(ply, args)
		local id = tonumber(args) or -1
		local ent = Entity(id)

		ent = IsValid(ent) and ent or ply:GetEyeTrace().Entity

		if not IsValid(ent) or not ent.IsSpawnedShipment then
			DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
			return
		end

		if ent:Getcount() < 2 or ent.locked or ent.USED then
			DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("shipment_cannot_split"))
			return
		end

		local pos = ent:GetPos()

		if pos:Distance(ply:GetShootPos()) > 130 or not pos:isInSight({ent, ply} , ply) then
			DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("distance_too_big"))
			return
		end

		local count = math.floor(ent:Getcount() / 2)
		ent:Setcount(ent:Getcount() - count)

		ent:StartSpawning()

		local crate = ents.Create("spawned_shipment")
		crate.locked = true
		crate.SID = ply.SID
		crate:SetPos(ent:GetPos())
		crate.nodupe = true
		crate:SetContents(ent:Getcontents(), count)
		crate:SetPlayer(ply)
		crate:Setowning_ent( ply )
		
		crate.clip1 = ent.clip1
		crate.clip2 = ent.clip2
		crate.ammoadd = ent.ammoadd

		crate:Spawn()
		
		local phys = crate:GetPhysicsObject()
		phys:Wake()
		
		local t = CustomShipments[ crate:Getcontents() or "" ]
		
		if ( t != nil && ent.SID == ply.SID ) then
			hook.Call( "playerBoughtShipment", nil, ply, t, crate, 0 )
		end
	end
	DarkRP.defineChatCommand("splitshipment", splitShipment, 0.3)
end )

