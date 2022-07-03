local languages = {}
local curr_lang = GetConVarString( "gmod_language" )

if ( not REFUND_RP ) then

	REFUND_RP = {}
end

function REFUND_RP.addLanguage( name, lang )

	languages[ name ] = lang
end

function REFUND_RP.getPhrase( name )

	if ( languages[ curr_lang ] ) then
		return ( languages[ curr_lang ][ name ] )
	elseif ( languages[ "en" ] ) then
		return ( languages[ "en" ][ name ] )
	end
	
	return ( "error" )
end


-- Add all language files

local f = file.Find( 'refund_lang/*', 'LUA' )

for k, v in ipairs( f ) do
	if ( SERVER ) then
		AddCSLuaFile( 'refund_lang/' .. v )
	end
	include( 'refund_lang/' .. v )
end

