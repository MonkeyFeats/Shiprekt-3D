#include "TetraBlocks.as"
#include "PhysicsEngine.as"

Random _rb;
int randomBlock = 1;

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
	const int blobTeam = blob.getTeamNum();

	if (getNet().isServer())
	{
		CBlob@[] blocks;
		for ( int i = 0; i < types.length; i++ )
		MakeBlock( types[i], Vec2f( 0, i ), Vec2f_zero, @blocks, blobTeam );

    	CBlob@[]@ blob_blocks;
	    blob.get( "blocks", @blob_blocks );
    	blob_blocks.clear();
		u16 blobID = blob.getNetworkID();
		u16 playerID = blob.getPlayer().getNetworkID();
    	for (uint i = 0; i < blocks.length; i++){
    		CBlob@ b = blocks[i];
        	blob_blocks.push_back( b );	        
        	b.set_u16( "ownerID", blobID );
        	b.set_u16( "playerID", playerID );
    		b.getShape().getVars().customData = -1; // don't push on island
    	}
	}
}
