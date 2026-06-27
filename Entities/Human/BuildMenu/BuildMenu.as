
#include "IslandsCommon.as"
#include "BuildWheelMenuCommon.as"
#include "BlockCommon.as"

#define CLIENT_ONLY

const u8 BUILD_MENU_COOLDOWN = 30;
const Vec2f BUILD_MENU_SIZE = Vec2f( 12, 6 );
const string build_menu = "build_menu";
const string tool_menu = "tool_menu";

void onInit(CRules@ rules)
{
	Render::addScript(Render::layer_posthud, "BuildMenu.as", "render", 0.0f);

	Block::Costs@ c = Block::getCosts( rules );
	Block::Weights@ w = Block::getWeights( rules );
	
	if ( c is null || w is null )
		return;

	WheelMenu@ menu = get_wheel_menu(build_menu);
	menu.option_notice = getTranslatedString("Build");
	menu.show_cost = true;
	menu.entries.clear();
		
	//CGridMenu@ menu = CreateGridMenu( blob.getScreenPos() + offset, core, BUILD_MENU_SIZE, description );
	u32 gameTime = getGameTime();
	string repBuyTip = "\nPress the inventory key to buy again.\n";
	u16 WARMUP_TIME = getPlayersCount() > 1 && !rules.get_bool("freebuild") ? rules.get_u16( "warmup_time" ) : 0;
	string warmupText = "Weapons are enabled after the warm-up time ends.\n";
	
	if ( menu !is null ) 
	{
		IconWheelMenuEntry Seat("seat");
		Seat.visible_name = getTranslatedString("Seat");
		Seat.texture_name = "Blocks.png";
		Seat.frame = Block::SEAT;
		Seat.frame_size = Vec2f(32.0f, 32.0f);
		Seat.scale = 0.75f;
		Seat.offset = Vec2f(0.0f, -3.0f);
		Seat.cost = c.seat;
		menu.entries.push_back(@Seat);

		IconWheelMenuEntry Flak("flak");
		Flak.visible_name = getTranslatedString("Flak");
		Flak.texture_name = "Blocks.png";
		Flak.frame = Block::FLAK;
		Flak.frame_size = Vec2f(32.0f, 32.0f);
		Flak.scale = 0.75f;
		Flak.offset = Vec2f(0.0f, -3.0f);
		Flak.cost = c.flak;
		menu.entries.push_back(@Flak);

		IconWheelMenuEntry Propeller("propeller");
		Propeller.visible_name = getTranslatedString("Propeller");
		Propeller.texture_name = "Blocks.png";
		Propeller.frame = Block::PROPELLER;
		Propeller.frame_size = Vec2f(32.0f, 32.0f);
		Propeller.scale = 0.75f;
		Propeller.offset = Vec2f(0.0f, -3.0f);
		Propeller.cost = c.propeller;
		menu.entries.push_back(@Propeller);

		IconWheelMenuEntry Solid("solid");
		Solid.visible_name = getTranslatedString("Solid Wall");
		Solid.texture_name = "Blocks.png";
		Solid.frame = Block::SOLID;
		Solid.frame_size = Vec2f(32.0f, 32.0f);
		Solid.scale = 0.75f;
		Solid.offset = Vec2f(0.0f, -3.0f);
		Solid.cost = c.solid;
		menu.entries.push_back(@Solid);

		IconWheelMenuEntry Platform("wood");
		Platform.visible_name = getTranslatedString("Platform");
		Platform.texture_name = "Blocks.png";
		Platform.frame = Block::PLATFORM;
		Platform.frame_size = Vec2f(32.0f, 32.0f);
		Platform.scale = 0.75f;
		Platform.offset = Vec2f(0.0f, -3.0f);
		Platform.cost = c.wood;
		menu.entries.push_back(@Platform);

		IconWheelMenuEntry Coupling("coupling");
		Coupling.visible_name = getTranslatedString("Coupling");
		Coupling.texture_name = "Blocks.png";
		Coupling.frame = Block::COUPLING;
		Coupling.frame_size = Vec2f(32.0f, 32.0f);
		Coupling.scale = 0.75f;
		Coupling.offset = Vec2f(0.0f, -3.0f);
		Coupling.cost = c.coupling;
		menu.entries.push_back(@Coupling);

		IconWheelMenuEntry Harvester("harvester");
		Harvester.visible_name = getTranslatedString("Harvester");
		Harvester.texture_name = "Blocks.png";
		Harvester.frame = Block::HARVESTER;
		Harvester.frame_size = Vec2f(32.0f, 32.0f);
		Harvester.scale = 0.75f;
		Harvester.offset = Vec2f(0.0f, -3.0f);
		Harvester.cost = c.harvester;
		menu.entries.push_back(@Harvester);

		IconWheelMenuEntry Bomb("bomb");
		Bomb.visible_name = getTranslatedString("Bomb");
		Bomb.texture_name = "Blocks.png";
		Bomb.frame = Block::BOMB;
		Bomb.frame_size = Vec2f(32.0f, 32.0f);
		Bomb.scale = 0.75f;
		Bomb.offset = Vec2f(0.0f, -3.0f);
		Bomb.cost = c.bomb;
		menu.entries.push_back(@Bomb);

		IconWheelMenuEntry Cannon("cannon");
		Cannon.visible_name = getTranslatedString("Cannon");
		Cannon.texture_name = "Blocks.png";
		Cannon.frame = Block::CANNON;
		Cannon.frame_size = Vec2f(32.0f, 32.0f);
		Cannon.scale = 0.75f;
		Cannon.offset = Vec2f(0.0f, -3.0f);
		Cannon.cost = c.cannon;
		menu.entries.push_back(@Cannon);

		IconWheelMenuEntry PDefense("pointDefense");
		PDefense.visible_name = getTranslatedString("Pointdefense");
		PDefense.texture_name = "Blocks.png";
		PDefense.frame = Block::POINTDEFENSE;
		PDefense.frame_size = Vec2f(32.0f, 32.0f);
		PDefense.scale = 0.75f;
		PDefense.offset = Vec2f(0.0f, -3.0f);
		PDefense.cost = c.pointDefense;
		menu.entries.push_back(@PDefense);

		IconWheelMenuEntry MachineGun("machinegun");
		MachineGun.visible_name = getTranslatedString("MachineGun");
		MachineGun.texture_name = "Blocks.png";
		MachineGun.frame = Block::MACHINEGUN;
		MachineGun.frame_size = Vec2f(32.0f, 32.0f);
		MachineGun.scale = 0.75f;
		MachineGun.offset = Vec2f(0.0f, -3.0f);
		MachineGun.cost = c.machinegun;
		menu.entries.push_back(@MachineGun);

		IconWheelMenuEntry Harpoon("harpoon");
		Harpoon.visible_name = getTranslatedString("Harpoon");
		Harpoon.texture_name = "Blocks.png";
		Harpoon.frame = Block::HARPOON;
		Harpoon.frame_size = Vec2f(32.0f, 32.0f);
		Harpoon.scale = 0.75f;
		Harpoon.offset = Vec2f(0.0f, -3.0f);
		Harpoon.cost = c.harpoon;
		menu.entries.push_back(@Harpoon);

		IconWheelMenuEntry Repulsor("repulsor");
		Repulsor.visible_name = getTranslatedString("Repulsor");
		Repulsor.texture_name = "Blocks.png";
		Repulsor.frame = Block::REPULSOR;
		Repulsor.frame_size = Vec2f(32.0f, 32.0f);
		Repulsor.scale = 0.75f;
		Repulsor.offset = Vec2f(0.0f, -3.0f);
		Repulsor.cost = c.repulsor;
		menu.entries.push_back(@Repulsor);

		IconWheelMenuEntry Launcher("launcher");
		Launcher.visible_name = getTranslatedString("Launcher");
		Launcher.texture_name = "Blocks.png";
		Launcher.frame = Block::LAUNCHER;
		Launcher.frame_size = Vec2f(32.0f, 32.0f);
		Launcher.scale = 0.75f;
		Launcher.offset = Vec2f(0.0f, -3.0f);
		Launcher.cost = c.launcher;
		menu.entries.push_back(@Launcher);

		IconWheelMenuEntry ramEngine("ramEngine");
		ramEngine.visible_name = getTranslatedString("Ram Engine");
		ramEngine.texture_name = "Blocks.png";
		ramEngine.frame = Block::RAMENGINE;
		ramEngine.frame_size = Vec2f(32.0f, 32.0f);
		ramEngine.scale = 0.75f;
		ramEngine.offset = Vec2f(0.0f, -3.0f);
		ramEngine.cost = c.ramEngine;
		menu.entries.push_back(@ramEngine);

	}

	WheelMenu@ tools = get_wheel_menu(tool_menu);
	tools.option_notice = getTranslatedString("Tool");
	tools.show_cost = false;
	tools.entries.clear();

	IconWheelMenuEntry Fists("fists");
	Fists.visible_name = getTranslatedString("Fists");
	Fists.texture_name = "Tools_GUI.png";
	Fists.frame = 2;
	Fists.frame_size = Vec2f(32.0f, 32.0f);
	Fists.scale = 0.75f;
	Fists.offset = Vec2f(0.0f, -3.0f);
	tools.entries.push_back(@Fists);

	IconWheelMenuEntry Gun("pistol");
	Gun.visible_name = getTranslatedString("Gun");
	Gun.texture_name = "Tools_GUI.png";
	Gun.frame = 0;
	Gun.frame_size = Vec2f(32.0f, 32.0f);
	Gun.scale = 0.75f;
	Gun.offset = Vec2f(0.0f, -3.0f);
	tools.entries.push_back(@Gun);

	IconWheelMenuEntry Deconstructor("deconstructor");
	Deconstructor.visible_name = getTranslatedString("Deconstructor");
	Deconstructor.texture_name = "Tools_GUI.png";
	Deconstructor.frame = 1;
	Deconstructor.frame_size = Vec2f(32.0f, 32.0f);
	Deconstructor.scale = 0.75f;
	Deconstructor.offset = Vec2f(0.0f, -3.0f);
	tools.entries.push_back(@Deconstructor);

	IconWheelMenuEntry Reconstructor("reconstructor");
	Reconstructor.visible_name = getTranslatedString("Reconstructor");
	Reconstructor.texture_name = "Tools_GUI.png";
	Reconstructor.frame = 1;
	Reconstructor.frame_size = Vec2f(32.0f, 32.0f);
	Reconstructor.scale = 0.75f;
	Reconstructor.offset = Vec2f(0.0f, -3.0f);
	tools.entries.push_back(@Reconstructor);
}

void onTick(CRules@ rules)
{
	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
	{ set_active_wheel_menu(null); return; }

	CHUD@ hud = getHUD();
	CControls@ controls = getControls();
	Driver@ d = getDriver();

	WheelMenu@ menu = get_wheel_menu(build_menu);
	WheelMenu@ tools = get_wheel_menu(tool_menu);

	if (blob.isAttached() && get_active_wheel_menu() is tools)
	{
		blob.set_bool( "build menu open", false );
		set_active_wheel_menu(null);
	}

	if ( blob.isKeyJustPressed(key_action2) && !blob.isAttached() && !hud.hasButtons() && get_active_wheel_menu() is null )
	{
		set_active_wheel_menu(@tools);
		blob.set_bool( "build menu open", true );
		Sound::Play( "buttonclick.ogg" );
	}
	else if (blob.isKeyJustReleased(key_action2) && get_active_wheel_menu() is tools)
	{
		WheelMenuEntry@ selected = tools.get_selected();
		if (selected !is null)
		{
			CBitStream params;
			params.write_u16( blob.getNetworkID() );
			params.write_string( selected.name );
			blob.SendCommand( blob.getCommandID("swap tool"), params );
			blob.set_string( "current tool", selected.name );

			Vec2f ScrMid = Vec2f(f32(d.getScreenWidth()) / 2, f32(d.getScreenHeight()) / 2);
			controls.setMousePosition(ScrMid);
		}

		blob.set_bool( "build menu open", false );
		set_active_wheel_menu(null);
	}

	//build menu
	if ( blob.isKeyJustPressed(key_inventory) && !blob.isAttached() )
	{		
		CBlob@ core = getMothership( blob.getTeamNum() );
		if ( core !is null && !core.hasTag( "critical" ) )
		{
			Island@ pIsle = getIsland( blob );
			bool canShop = pIsle !is null && pIsle.centerBlock !is null 
							&& ( (pIsle.centerBlock.getShape().getVars().customData == core.getShape().getVars().customData) 
									|| (pIsle.isStation && pIsle.centerBlock.getTeamNum() == blob.getTeamNum()) );									
		
			if ( !hud.hasButtons() )
			{
				if ( canShop  && get_active_wheel_menu() is null)
				{					
					set_active_wheel_menu(@menu);
					blob.set_bool( "build menu open", true );
				
					CBitStream params;
					params.write_u16( core.getNetworkID() );
					u32 gameTime = getGameTime();
					
					if ( gameTime - blob.get_u32( "menu time" ) > BUILD_MENU_COOLDOWN )
					{
						Sound::Play( "buttonclick.ogg" );
						blob.set_u32( "menu time", gameTime );
						//BuildShopMenu( blob, core, "mCore Block Transmitter", Vec2f(0,0) );
					}
					else
						Sound::Play( "/Sounds/bone_fall1.ogg" );
				}
				else
					Sound::Play( "/Sounds/bone_fall1.ogg" );
			} 
			else if ( hud.hasMenus() )
			{
				blob.ClearMenus();
				Sound::Play( "buttonclick.ogg" );
				
				if ( blob.get_bool( "build menu open" ) )
				{
					CBitStream params;
					params.write_u16( blob.getNetworkID() );
					params.write_string( blob.get_string( "last buy" ) );
					
					core.SendCommand( core.getCommandID("buyBlock"), params );
				}
				blob.set_bool( "build menu open", false );
			}
		}
	}
	else if (blob.isKeyJustReleased(key_inventory) && get_active_wheel_menu() is menu)
	{
		CBlob@ core = getMothership( blob.getTeamNum() );
		if ( core !is null )
		{
			WheelMenuEntry@ selected = menu.get_selected();
			if (selected !is null)
			{					
				if ( blob.get_bool( "build menu open" ) )
				{
					if ( Human::isHoldingBlocks(blob) )
					{		
						CBitStream params;
						params.write_u16( blob.getNetworkID() );
						core.SendCommand( core.getCommandID("returnBlocks"), params );						
					}					

					CBitStream params;
					params.write_u16( blob.getNetworkID() );
					params.write_string( menu.get_selected().name );					
					core.SendCommand( core.getCommandID("buyBlock"), params );

					Vec2f ScrMid = Vec2f(f32(d.getScreenWidth()) / 2, f32(d.getScreenHeight()) / 2);
					controls.setMousePosition(ScrMid);
				}
			}
			blob.set_bool( "build menu open", false );
			set_active_wheel_menu(null);
		}
	}
	
	WheelMenu@ active = get_active_wheel_menu();
	if (active !is null)
	{
		active.update();
	}
}

void render(int)
{
	WheelMenu@ menu = get_active_wheel_menu();
	if (menu is null) return;

	GUI::SetFont("menu");
	menu.render();
}
