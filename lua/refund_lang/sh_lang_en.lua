
/*
	-------------------------------------
	// Default language file (English) //
	-------------------------------------
	
	Don't see your language?
	
		Follow these instructions:
		
		1) Copy and paste this file in the same directory (rename it to anything)
		2) Change the text in the double quotes to your language
		3) At the bottom, change 'en' to your language code. e.g. de
		
		Type 'gmod_language' in the GMod console to discover your language code.
*/

local lang = {

	title = "Refunds",
	refundSys = "Refund System",
	
	
	refund = "Refund Money For Entites",
	refund2 = "Refund Entites",
	beenRefunded = "You have been refunded",

	
	weapon = "Weapon",
	shipment = "Shipment",
	
	exitMenu = "Exit",
	chatMsg = "Enter " .. REFUND_RP.CONFIG.CHAT_COMMAND .. " in chat before you leave!",
}

REFUND_RP.addLanguage( "en", lang )
