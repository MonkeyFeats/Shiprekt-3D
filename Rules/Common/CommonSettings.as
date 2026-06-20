//#include "PrecacheTextures.as"
#include "BlockCommon.as"
#include "Camera3D.as"
#include "CollisionDebug.as"

const int BUTTON_SIZE = 4;

void onInit( CRules@ this )
{
    particles_gravity.y = 0.0f; 
    sv_gravity = 0;    
    sv_visiblity_scale = 2.0f;
	cc_halign = 2;
	cc_valign = 2;
	s_effects = false;
	sv_max_localplayers = 1;

		//gameplay settings (could be a cfg file)
	this.set_u16( "starting_booty", 325 );
	this.set_u16( "warmup_time", 1 * 60 * 30 );//no weapons warmup time
	this.set_u16( "booty_x_max", 200 );
	this.set_u16( "booty_x_min", 100 );
	this.set_u16( "booty_transfer", 50 );//min transfer ammount
	this.set_f32( "booty_transfer_fee", 0.0f );
	this.set_f32( "build_distance", 16 * 16 );//max distance from the core for purchasing blocks

	ConfigFile cfg;
	const bool firstPersonCamera = cfg.loadFile("SHRKTVars.cfg") ? cfg.read_bool("first_person_camera", true) : true;
	this.set_bool(FIRST_PERSON_CAMERA_ENABLED, firstPersonCamera);
	this.set_bool(COLLISION_DEBUG_ENABLED, false);
	if (getNet().isServer())
	{
		this.Sync(FIRST_PERSON_CAMERA_ENABLED, true);
		this.Sync(COLLISION_DEBUG_ENABLED, true);
	}

	Block::Costs@ c = Block::getCosts( this );
	this.set_u16( "bootyRefillLimit", c !is null ? c.propeller : 50 );
	
	//Icons
	AddIconToken( "$BOOTY$", "InteractionIconsBig.png", Vec2f(64,64), 26 );
	AddIconToken( "$CORE$", "InteractionIconsBig.png", Vec2f(64,64), 29 );
	AddIconToken( "$CAPTAIN$", "InteractionIconsBig.png", Vec2f(64,64), 11 );
	AddIconToken( "$CREW$", "InteractionIconsBig.png", Vec2f(64,64), 15 );
	AddIconToken( "$FREEMAN$", "InteractionIconsBig.png", Vec2f(64,64), 14 );
	AddIconToken( "$SEA$", "InteractionIconsBig.png", Vec2f(64,64), 9 );
	AddIconToken( "$ASSAIL$", "InteractionIconsBig.png", Vec2f(64,64), 10 );
	AddIconToken( "$PISTOL$", "Tools_GUI.png", Vec2f(32,32), 0 );
	AddIconToken( "$CONSTRUCTOR$", "Tools_GUI.png", Vec2f(32,32), 1 );
	AddIconToken( "$FISTS$", "Tools_GUI.png", Vec2f(32,32), 2 );
	AddIconToken( "$TELESCOPE$", "Tools_GUI.png", Vec2f(32,32), 3 );
	AddIconToken( "$WOOD$", "Blocks.png", Vec2f(16,16), 0 );
	AddIconToken( "$SOLID$", "Blocks.png", Vec2f(16,16), 4 );
	AddIconToken( "$DOOR$", "Blocks.png", Vec2f(16,16), 12 );
	AddIconToken( "$RAM$", "Blocks.png", Vec2f(16,16), 8 );
	AddIconToken( "$PROPELLER$", "Blocks.png", Vec2f(16,16), 16 );
	AddIconToken( "$RAMENGINE$", "Blocks.png", Vec2f(16,16), 17 );
	AddIconToken( "$SEAT$", "Blocks.png", Vec2f(16,16), 23 );
	AddIconToken( "$BOMB$", "Blocks.png", Vec2f(16,16), 19 );
	AddIconToken( "$HARVESTER$", "Blocks.png", Vec2f(32,32), 67 );
	AddIconToken( "$HARPOON$", "Blocks.png", Vec2f(32,32), 75 ); 
	AddIconToken( "$MACHINEGUN$", "Blocks.png", Vec2f(32,32), 27 );
	AddIconToken( "$CANNON$", "Blocks.png", Vec2f(32,32), 30 );
	AddIconToken( "$FLAK$", "Blocks.png", Vec2f(32,32), 11 );
	AddIconToken( "$POINTDEFENSE$", "Blocks.png", Vec2f(32,32), 59 );
	AddIconToken( "$LAUNCHER$", "Blocks.png", Vec2f(32,32), 51 );
	AddIconToken( "$COUPLING$", "Blocks.png", Vec2f(16,16), 35 );
	AddIconToken( "$REPULSOR$", "Blocks.png", Vec2f(16,16), 28 );
    AddIconToken( "$TEAMS$", "GUI/MenuItems.png", Vec2f(32,32), 1 );
    AddIconToken( "$SPECTATOR$", "GUI/MenuItems.png", Vec2f(32,32), 19 );
	
	//smooth shader
	Driver@ driver = getDriver();

	driver.AddShader("hq2x", 1.0f);
	driver.SetShader("hq2x", true);

	//driver.AddShader("FXAA", 2.0f);
	//driver.SetShader("FXAA", true);
	//driver.ForceStartShaders();	

	//PrecacheTextures(); //crashing, player sprites too big :C

	//reset var if you came from another gamemode that edits it
	SetGridMenusSize(24,2.0f,32);

	//spectator stuff
	this.addCommandID("pick teams");
    this.addCommandID("pick spectator");
	this.addCommandID("pick none");
}

void ShowTeamMenu( CRules@ this )
{
	CPlayer@ local = getLocalPlayer();
    if (local is null) 
	{
        return;
    }

    CGridMenu@ menu = CreateGridMenu( getDriver().getScreenCenterPos(), null, Vec2f( BUTTON_SIZE, BUTTON_SIZE), "Change team" );

    if (menu !is null)
    {
		CBitStream exitParams;
		menu.AddKeyCommand( KEY_ESCAPE, this.getCommandID("pick none"), exitParams );
		menu.SetDefaultCommand( this.getCommandID("pick none"), exitParams );


        CBitStream params;
        params.write_u16( local.getNetworkID() );
        if (local.getTeamNum() == this.getSpectatorTeamNum())
        {
			CGridButton@ button = menu.AddButton( "$TEAMS$", "Auto-pick teams", this.getCommandID("pick teams"), Vec2f(BUTTON_SIZE, BUTTON_SIZE), params );
		}
		else
		{
			CGridButton@ button = menu.AddButton( "$SPECTATOR$", "Spectator", this.getCommandID("pick spectator"), Vec2f(BUTTON_SIZE, BUTTON_SIZE), params );
		}
    }
}

void ReadChangeTeam( CRules@ this, CBitStream @params, int team )
{
    CPlayer@ player = getPlayerByNetworkId( params.read_u16() );
    if (player is getLocalPlayer())
    {
        player.client_ChangeTeam( team );
        getHUD().ClearMenus();
    }
}

void onCommand( CRules@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("pick teams"))
    {
        ReadChangeTeam( this, params, -1);
    }
    else if (cmd == this.getCommandID("pick spectator"))
    {
        ReadChangeTeam( this, params, this.getSpectatorTeamNum() );
	} else if (cmd == this.getCommandID("pick none"))
	{
		getHUD().ClearMenus();
	}
}
