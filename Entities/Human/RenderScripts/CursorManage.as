#define CLIENT_ONLY

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";

	CHUD@ hud = getHUD();
	hud.SetCursorImage("Cursors.png", Vec2f(32,32));
	hud.SetCursorOffset( Vec2f(-32, -32) );
}

void onRender(CSprite@ this)
{
	//if (g_videorecording)
	//	return;

	CBlob@ blob = this.getBlob();

	ManageCursors(blob);
}

void ManageCursors(CBlob@ this)
{
	// default cursor
	CHUD@ hud = getHUD();
	if ( hud.hasMenus() || hud.hasButtons() || this.get_bool( "build menu open" ) )
		hud.SetCursorFrame(0);
	else
	{
		//string currentTool = this.get_string( "current tool" );
		//if (currentTool == "reclaimer")
		hud.SetCursorFrame(1);
	}
}
