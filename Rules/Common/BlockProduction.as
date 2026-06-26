#include "TetraBlocks.as"
#include "PhysicsEngine.as"

Random _rb;
int randomBlock = 1;
const bool DEBUG_PRODUCE_BLOCK = true;

void DebugProduceBlock(const string &in message)
{
	if (DEBUG_PRODUCE_BLOCK)
	{
		print("[BlockPull] " + message);
	}
}

void onInit( CRules@ this )
{
	onRestart( this );
	
	PhysicsWorld@ physWorld = PhysicsWorld();
	if (physWorld is null) print("hello");
	this.set("physics", @physWorld);
}



void onRestart( CRules@ this )
{
	Reseed();
	if (getMap() !is null){
		_rb.Reset(XORRandom(9999999));
	}


}
void onTick(CRules@ this)
{
	PhysicsWorld@ physWorld;
    this.get("physics", @physWorld);
    if (physWorld !is null)
    {
    	physWorld.onTick();
    }
}
void ProduceBlock( CRules@ this, CBlob@ blob, Block::Type[] types)
{
	if (blob is null)
	{
		DebugProduceBlock("ProduceBlock aborted: caller blob is null");
		return;
	}

	const int blobTeam = blob.getTeamNum();

	if (getNet().isServer())
	{
		CPlayer@ player = blob.getPlayer();
		if (player is null)
		{
			DebugProduceBlock("ProduceBlock aborted: caller has no player caller=" + blob.getNetworkID() + " team=" + blobTeam);
			return;
		}

		DebugProduceBlock("ProduceBlock begin caller=" + blob.getNetworkID() + " player=" + player.getUsername() + " team=" + blobTeam + " requestedTypes=" + types.length);
		blob.set_string("current tool", "fists");
		blob.Sync("current tool", true);

		CBlob@[] blocks;
		for ( int i = 0; i < types.length; i++ )
		{
			DebugProduceBlock("ProduceBlock make type=" + types[i] + " index=" + i);
			MakeBlock( types[i], Vec2f( 0, i ), Vec2f_zero, @blocks, blobTeam );
		}

    	CBlob@[]@ blob_blocks;
	    if (!blob.get( "blocks", @blob_blocks ) || blob_blocks is null)
		{
			DebugProduceBlock("ProduceBlock aborted: caller blocks array missing caller=" + blob.getNetworkID());
			for (uint i = 0; i < blocks.length; i++)
			{
				if (blocks[i] !is null)
				{
					blocks[i].Tag("disabled");
					blocks[i].server_Die();
				}
			}
			return;
		}

    	blob_blocks.clear();
		u16 blobID = blob.getNetworkID();
		u16 playerID = player.getNetworkID();
		string playerName = player.getUsername();
    	for (uint i = 0; i < blocks.length; i++){
    		CBlob@ b = blocks[i];
			if (b is null)
			{
				DebugProduceBlock("ProduceBlock skipped null created block index=" + i + " caller=" + blobID);
				continue;
			}

        	blob_blocks.push_back( b );	        
        	b.set_u16( "ownerID", blobID );
        	b.set_u16( "playerID", playerID );
			b.set( "playerOwner", playerName );
			b.set_string( "playerOwner", playerName );
			b.Sync( "playerOwner", true );
    		b.getShape().getVars().customData = -1; // don't push on island
			DebugProduceBlock("ProduceBlock assigned blockID=" + b.getNetworkID() + " owner=" + blobID + " playerID=" + playerID + " playerOwner=" + playerName + " frame=" + b.getSprite().getFrame());
    	}

		DebugProduceBlock("ProduceBlock end caller=" + blobID + " heldBlocks=" + blob_blocks.length);
	}
}
