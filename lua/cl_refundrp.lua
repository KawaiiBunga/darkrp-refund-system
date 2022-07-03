include( 'sh_refundrp_config.lua' )
include( 'sh_refundrp_lang.lua' )

/*
	RefundMenu
*/

local PANEL = {}

function PANEL:InvalidateLayout()
	local exitB = vgui.Create( "DImageButton", self )
	exitB:SetIcon( "icon16/cancel.png" )
	exitB:SetPos( self:GetWide() - 20, 4 )
	exitB:SizeToContents()
	exitB.DoClick = function()
		chat.AddText( Color( 51, 204, 255 ), "[" .. REFUND_RP.getPhrase( 'refundSys' ) .. "] ", color_white, REFUND_RP.getPhrase( 'chatMsg' ) )
		self:Close()
	end
end

function PANEL:Paint( w, h )
	surface.SetDrawColor( color_white )
	surface.DrawOutlinedRect( 0, 0, w, h )
	
	surface.DrawLine( 0, 22, w, 22 )
	
	surface.SetDrawColor( Color( 33, 33, 33, 225 ) )
	surface.DrawRect( 0, 0, w, h )
end
vgui.Register( "RefundMenu", PANEL, "DFrame" )


// Font

surface.CreateFont( "RefundFont", {
	font = "Roboto Bk",
	size = 14,
	weight = 800
} )


// Cache table

local cache = {}


// Enums

local refundEnums = {

	ENT = 0,
	WEP = 1,
	SHIP = 2
}


local function RefundEntMenu()
	
	if ( table.Count( cache ) > 0 ) then
	
		local RefundEntMenu = vgui.Create( 'RefundMenu' )
		RefundEntMenu:SetSize( 400, 240 )
		RefundEntMenu:Center()
		RefundEntMenu:SetTitle( REFUND_RP.getPhrase( 'title' ) )
		RefundEntMenu:ShowCloseButton( false )
		RefundEntMenu:MakePopup()
		
		local entList = vgui.Create( "DListView", RefundEntMenu )
		entList:SetPos( 10, 30 )
		entList:SetSize( 135, 200 )
		entList:SetMultiSelect( true )
		entList:AddColumn( REFUND_RP.getPhrase( 'respawn' ) )
		
		for _, v in pairs( cache ) do
		
			local name
			
			if ( v.typ == refundEnums.WEP ) then
			
				name = "[" .. REFUND_RP.getPhrase( 'weapon' ) .. "] " .. v.name
			elseif ( v.typ == refundEnums.SHIP ) then
			
				name = "[" .. REFUND_RP.getPhrase( 'shipment' ) .. "] " .. v.name
			else
				name = v.name
			end
			
			entList:AddLine( name )
		end
		
		local entList2 = vgui.Create( "DListView", RefundEntMenu )
		entList2:SetPos( RefundEntMenu:GetWide() - 145, 30 )
		entList2:SetSize( 135, 200 )
		entList2:SetMultiSelect( true )
		entList2:AddColumn( REFUND_RP.getPhrase( 'refund' ) )
		
		----
		
		local addRefundB = vgui.Create( "DButton", RefundEntMenu )
		addRefundB:SetSize( 40, 40 )
		addRefundB:SetPos( RefundEntMenu:GetWide()/2 - 40/2, RefundEntMenu:GetTall()/2 - 40/2 - 25 )
		addRefundB:SetText( ">" )
		addRefundB.DoClick = function()
			
			local s = {}
			
			for k, v in next, entList:GetSelected() do
				table.insert( s, v:GetValue( 1 ) )
			end
			
			--
			
			local l1 = {}
			local l2 = {}
			
			for k, v in pairs( entList:GetLines() ) do
				table.insert( l1, v:GetValue( 1 ) )
				entList:RemoveLine( k )
			end
			for k, v in pairs( entList2:GetLines() ) do
				table.insert( l2, v:GetValue( 1 ) )
				entList2:RemoveLine( k )
			end
			
			--
			
			for k, v in next, s do
			
				if ( table.HasValue( l1, v ) ) then
				
					table.remove( l1, table.KeyFromValue( l1, v ) )
					table.insert( l2, v )
				end
			end
			
			for k, v in next, l1 do
				entList:AddLine( v )
			end
			for k, v in next, l2 do
				entList2:AddLine( v )
			end
		end
		
		local removeRefundB = vgui.Create( "DButton", RefundEntMenu )
		removeRefundB:SetSize( 40, 40 )
		removeRefundB:SetPos( RefundEntMenu:GetWide()/2 - 40/2, RefundEntMenu:GetTall()/2 - 40/2 + 25 )
		removeRefundB:SetText( "<" )
		removeRefundB.DoClick = function()
			
	
			local s = {}
			
			for k, v in next, entList2:GetSelected() do
				table.insert( s, v:GetValue( 1 ) )
			end
			
			--
			
			local l1 = {}
			local l2 = {}
			
			for k, v in pairs( entList:GetLines() ) do
				table.insert( l1, v:GetValue( 1 ) )
				entList:RemoveLine( k )
			end
			for k, v in pairs( entList2:GetLines() ) do
				table.insert( l2, v:GetValue( 1 ) )
				entList2:RemoveLine( k )
			end
			
			--
			
			for k, v in next, s do
			
				if ( table.HasValue( l2, v ) ) then
				
					table.remove( l2, table.KeyFromValue( l2, v ) )
					table.insert( l1, v )
				end
			end
			
			for k, v in next, l1 do
				entList:AddLine( v )
			end
			for k, v in next, l2 do
				entList2:AddLine( v )
			end
		end
		
		
	end
end

local function refundMenu()
	
	if ( table.Count( cache ) > 0 ) then
	
		local RefundMenu = vgui.Create( 'RefundMenu' )
		RefundMenu:SetSize( 400, 125 )
		RefundMenu:Center()
		RefundMenu:SetTitle( REFUND_RP.getPhrase( 'title' ) )
		RefundMenu:ShowCloseButton( false )
		RefundMenu:MakePopup()

		local RefundButton = vgui.Create( 'DButton', RefundMenu )
		RefundButton:SetSize( 325, 30 )
		RefundButton:SetPos( RefundMenu:GetWide()/2 - ( RefundButton:GetWide()/2 ), 40 )
		RefundButton:SetText( REFUND_RP.getPhrase( 'refund2' ) )
		RefundButton:SetFont( "RefundFont" )
		RefundButton.DoClick = function( self )

			net.Start( 'refundCash' )
			net.SendToServer()
			
			RefundMenu:Close()
		end


		local LaterButton = vgui.Create( 'DButton', RefundMenu )
		LaterButton:SetSize( 325, 30 )
		LaterButton:SetPos( RefundMenu:GetWide()/2 - ( LaterButton:GetWide()/2 ), RefundMenu:GetTall() - 30 - 10 )
		LaterButton:SetText( REFUND_RP.getPhrase( 'exitMenu' ) )
		LaterButton:SetFont( "RefundFont" )
		LaterButton.DoClick = function( self )

			chat.AddText( Color( 51, 204, 255 ), "[" .. REFUND_RP.getPhrase( 'refundSys' ) .. "] ", color_white, REFUND_RP.getPhrase( 'chatMsg' ) )
			RefundMenu:Close()
		end

		
	end
end

net.Receive( "refundMenu", function( len )

	cache = table.Copy( net.ReadTable() )
	refundMenu()
end )

net.Receive( "refundRPMsg", function( len )

	local amt = net.ReadString()
	chat.AddText( Color( 51, 204, 255 ), "[" .. REFUND_RP.getPhrase( 'refundSys' ) .. "]: ", color_white, REFUND_RP.getPhrase( 'beenRefunded' ) .. " $" .. string.Comma( amt ) .. "." )
end )

