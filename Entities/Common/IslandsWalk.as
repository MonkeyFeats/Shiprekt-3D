#define CLIENT_ONLY
#include "IslandsCommon.as"
#include "SAT_Shapes.as"

//saving local values because the ones provied by sv aren't correct after a desync
u16 currentCenterBlockID = 0;
f32 islandOldAngle = 0;
Vec2f islandOldPos = Vec2f_zero;

void onInit( CBlob@ this )
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	currentCenterBlockID = 0;
	islandOldAngle = 0;
	islandOldPos = Vec2f_zero;
}

void onTick( CBlob@ this )
{
	SAT_Shape@ sat_shape;
	if (!this.get("SAT_Info", @sat_shape)) return;
	if ( !this.get_bool("onGround") ) return;
		
	Island@ island = getIsland( this );
	if ( island !is null && island.centerBlock !is null )
	{
		u16 id = island.centerBlock.getNetworkID();
		if ( id != currentCenterBlockID || !this.wasOnGround() )//island changed: set cached values to current
		{
			islandOldPos = island.centerBlock.getInterpolatedPosition();
			islandOldAngle = island.centerBlock.getAngleDegrees();
			currentCenterBlockID = id;
		}
		
    	Vec2f pos = sat_shape.Pos.xz();
		f32 islandAngle = island.centerBlock.getAngleDegrees();
		Vec2f islandPos = island.centerBlock.getInterpolatedPosition();
		Vec2f islandDisplacement = islandPos - islandOldPos;
		f32 islandAngleDelta = islandAngle - islandOldAngle;
		Vec2f islandToBlob = pos - islandPos + islandDisplacement;
		islandToBlob.RotateBy( islandAngleDelta );
		
		islandOldPos = islandPos;
		islandOldAngle = islandAngle;

		sat_shape.Pos = V2toV3( islandPos + islandToBlob, sat_shape.Pos.y);
	}
}
