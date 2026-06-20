#include "Vec3f.as"
#include "SAT_Shapes.as"
#include "BlockCommon.as"

class Human
{
	Vec3f Pos;
	Vec3f Vel;
	Vec3f Look_dir;
	float dir_x = 0.01f;
	float dir_y = 0.01f;
	SAT_Shape Shape;
	CBlob@ blob;
	CPlayer@ player;

	Human(){}
	Human()
	{
		
	}
};

const Vec2f TOOLS_MENU_SIZE = Vec2f( 2, 8 );

// helper functions

namespace Human
{
	bool isHoldingBlocks( CBlob@ this )
	{
	   	CBlob@[]@ blob_blocks;
	    this.get( "blocks", @blob_blocks );
	    return blob_blocks.length > 0;
	}
	
	bool wasHoldingBlocks( CBlob@ this )
	{
		return getGameTime() - this.get_u32( "placedTime" ) < 10;
	}
	
	void clearHeldBlocks( CBlob@ this )
	{
		CBlob@[]@ blocks;
		if (this.get( "blocks", @blocks ))
		{
			for (uint i = 0; i < blocks.length; ++i)
			{
				blocks[i].Tag( "disabled" );
				blocks[i].server_Die();
			}

			blocks.clear();
		}
	}
}

const string camera_sync_cmd = "camerasync";
const string HUMAN_SEAT_RENDER_YAW = "human seat render yaw";

void SyncCamera(CBlob@ this)
{
	CBitStream bt;
	bt.write_f32(this.get_f32("dir_x"));	
	uint8 cmnd = this.getCommandID(camera_sync_cmd);
	this.SendCommand(cmnd, bt);
}

void HandleCamera(CBlob@ this, CBitStream@ bt, bool apply)
{
	if(!apply) return;
	
	float dirX;
	if(!bt.saferead_f32(dirX)) return;

	if (dirX > 360)
	dirX = 0;
	else if (dirX < 0)
	dirX = 360;

	this.set_f32("dir_x", dirX);
}

void BuildToolsMenu( CBlob@ this, string description, Vec2f offset )
{
	CRules@ rules = getRules();
	Block::Costs@ c = Block::getCosts( rules );
	Block::Weights@ w = Block::getWeights( rules );
	
	if (this is null || c is null || w is null )
		return;
		
	CGridMenu@ menu = CreateGridMenu( this.getScreenPos() + offset, this, TOOLS_MENU_SIZE, description );
	u32 gameTime = getGameTime();
	
	if ( menu !is null ) 
	{
		menu.deleteAfterClick = true;
		
		u16 netID = this.getNetworkID();
		string currentTool = this.get_string( "current tool" );

		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "fists" );
				
			CGridButton@ button = menu.AddButton( "$FISTS$", "Guantlets", this.getCommandID("swap tool"), params );
	
			bool select = currentTool == "fists";
			if ( select )
				button.SetSelected(1);
				
			button.SetHoverText( "Trusty hands, handy for hand to hand combat");
		}
		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "pistol" );
			
			CGridButton@ button = menu.AddButton( "$PISTOL$", "Pistol", this.getCommandID("swap tool"), params );
			
			bool select = currentTool == "pistol";
			if ( select )
				button.SetSelected(2);
			
			button.SetHoverText( "Pew Pew");
		}
		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "reconstructor" );
				
			CGridButton@ button = menu.AddButton( "$CONSTRUCTOR$", "Constructor", this.getCommandID("swap tool"), params );
	
			bool select = currentTool == "reconstructor";
			if ( select )
				button.SetSelected(2);
				
			button.SetHoverText( "Reapair, reclaim ship parts or claim stations");
		}
		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "telescope" );
				
			CGridButton@ button = menu.AddButton( "$TELESCOPE$", "Telescope", this.getCommandID("swap tool"), params );
	
			bool select = currentTool == "telescope";
			if ( select )
				button.SetSelected(2);
				
			button.SetHoverText( "Good from afar, but far from good");
		}		
	}
}
