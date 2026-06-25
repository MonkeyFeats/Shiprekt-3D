#include "IslandsCommon.as"
#include "BlockCommon.as"
#include "AccurateSoundPlay.as"
#include "TileCommon.as"
#include "SAT_Shapes.as"
#include "OceanWave.as"

const f32 VEL_DAMPING = 0.985f;
const f32 ANGLE_VEL_DAMPING = 0.982f;
const uint FORCE_UPDATE_TICKS = 21;
f32 UPDATE_DELTA_SMOOTHNESS = 32.0f;//~16-64

const f32 SHIP_WAVE_MIN_SAMPLE_DISTANCE = 96.0f;
const f32 SHIP_WAVE_MAX_SAMPLE_DISTANCE = 192.0f;
const f32 SHIP_MAX_SPEED = 8.0f;
const f32 SHIP_MAX_ANGLE_SPEED = 6.0f;
const f32 SHIP_COLLISION_RESTITUTION = 0.78f;
const f32 SHIP_COLLISION_POSITION_PERCENT = 0.94f;
const f32 SHIP_COLLISION_MIN_PUSH = 0.22f;
const f32 SHIP_COLLISION_MAX_PUSH = 1.60f;
const f32 SHIP_COLLISION_PUSH_BIAS = 0.12f;
const f32 SHIP_COLLISION_MIN_DYNAMIC_SHARE = 0.28f;
const f32 SHIP_COLLISION_SEPARATION_BOOST = 0.35f;
const f32 SHIP_COLLISION_ANGULAR_TRANSFER = 0.85f;
const f32 SHIP_COLLISION_MAX_ANGULAR_KICK = 2.20f;
const f32 SHIP_COLLISION_BROADPHASE_PADDING = 20.0f;
const f32 SHIP_COLLISION_BLOCK_RADIUS = 32.0f;

class IslandCollisionContact
{
	CBlob@ blockA;
	CBlob@ blockB;
	Vec2f mtv;
	Vec2f point;
	bool solidA;
	bool solidB;
	bool platformA;
	bool platformB;
}

uint color;
bool updatedThisTick = false;
void onInit( CRules@ this )
{
	Island[] islands;
	this.set("islands", islands);
	this.addCommandID("islands sync");
	this.addCommandID("islands update");
	this.set_u32("islands id", 0);
	this.set_bool("dirty islands", true);
}

void onRestart( CRules@ this )
{
	this.clear("islands");
	this.set_bool("dirty islands", true);
}

void onTick( CRules@ this )
{
	bool full_sync = false;				
	if (getNet().isServer())
	{
		const int time = getMap().getTimeSinceStart();
		if (time < 2) // errors are generated when done on first game tick
			return;

		const bool dirty = this.get_bool("dirty islands");
		if (dirty)
		{
			GenerateIslands( this );			
			setUpdateSeatsArrays();
			this.set_bool("dirty islands", false);
			full_sync = true;
		}

		UpdateIslands( this, true, full_sync );
		Synchronize( this, full_sync );
	}
	else
		UpdateIslands( this );//client-side integrate
		
	updatedThisTick = false;
}

void GenerateIslands( CRules@ this )
{
	StoreVelocities( this );

	CBlob@[] blocks;
	this.clear("islands");
	if (getBlobsByName( "block", @blocks ))
	{	
		color = 0;
		for (uint i = 0; i < blocks.length; ++i)
		{
			if (blocks[i].getShape().getVars().customData > 0)
				blocks[i].getShape().getVars().customData = 0;
		}

		for (uint i = 0; i < blocks.length; ++i)
		{
			CBlob@ b = blocks[i];
			if (b.getShape().getVars().customData == 0)
			{
				color++;

				Island island;
				SetNextId( this, @island );
				this.push("islands", island);
				Island@ p_island;
				this.getLast( "islands", @p_island );
				ColorBlocks( b, p_island );		
			}
		}	
		for (uint i = 0; i < blocks.length; ++i)
		{
			CBlob@ b = blocks[i];
			b.set_u16("last color", b.getShape().getVars().customData);				
		}
	}

	//print("Generated " + color + " islands");
}

void ColorBlocks( CBlob@ blob, Island@ island )
{
	blob.getShape().getVars().customData = color;
	
	IslandBlock isle_block;
	isle_block.blobID = blob.getNetworkID();
	island.blocks.push_back(isle_block);	

	CBlob@[] overlapping;
    if (blob.getOverlapping( @overlapping ))
    {
        for (uint i = 0; i < overlapping.length; i++)
        {
            CBlob@ b = overlapping[i];
			
            if ( b.getShape().getVars().customData == 0 
				&& b.getName() == "block" 
				&& ( b.getInterpolatedPosition() - blob.getInterpolatedPosition() ).LengthSquared() < 264 // avoid "corner" overlaps
				&& ( (b.get_u16("last color") == blob.get_u16("last color")) || (b.getSprite().getFrame() == Block::COUPLING) || (blob.getSprite().getFrame() == Block::COUPLING) 
				|| ((getGameTime() - b.get_u32( "placedTime" )) < 10) || ((getGameTime() - blob.get_u32( "placedTime" )) < 10) 
				|| (getMap().getTimeSinceStart() < 100) ) )
				{
					ColorBlocks( b, island ); 
				}
        }
    }
}

void InitIsland( Island @isle )//called for all islands after a block is placed or collides
{
	Vec2f center, vel;
	f32 angle_vel = 0.0f;
	if ( isle.centerBlock is null )//when clients InitIsland(), they should have key values pre-synced. no need to calculate
	{
		//get island vels (stored previously on all blobs), center
		for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
		{
			CBlob@ b = getBlobByNetworkID( isle.blocks[b_iter].blobID );
			if (b !is null)
			{
				center += b.getInterpolatedPosition();
				if (b.getVelocity().LengthSquared() > 0.0f)
				{
					vel = b.getVelocity();
					angle_vel = b.getAngularVelocity();			
				}
			}
		}
		center /= float(isle.blocks.length);

		//find center block and mass and if it's mothership
		f32 totalMass = 0.0f;
		f32 maxDistance = 999999.9f;
		for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
		{
			CBlob@ b = getBlobByNetworkID( isle.blocks[b_iter].blobID );
			if (b !is null)
			{
				Vec2f vec = b.getInterpolatedPosition() - center;
				f32 dist = vec.LengthSquared();
				if (dist < maxDistance){
					maxDistance = dist;
					@isle.centerBlock = b;
				}
				//mass calculation
				totalMass += b.get_f32( "weight" );
				
				if ( b.hasTag( "mothership" ) )
					isle.isMothership = true;
					
				if ( b.hasTag( "station" ) )
					isle.isStation = true;
			}
		}
		
		isle.mass = totalMass;//linear mass growth
		isle.vel = vel;
		isle.angle_vel = angle_vel;
		if ( isle.centerBlock !is null )
		{
			isle.angle = isle.centerBlock.getAngleDegrees();
			isle.pos = isle.centerBlock.getInterpolatedPosition();
		}
	}
	
	if (isle.centerBlock is null)
	{
		if ( !getNet().isClient() )
			warn("isle.centerBlock is null");
		return;
	}

	center = isle.centerBlock.getInterpolatedPosition();
	//print( isle.id + " mass: " + totalMass + "; effective: " + isle.mass );
	
	//update block positions/angle array
	isle.collisionRadius = 0.0f;
	for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
	{
		IslandBlock@ isle_block = isle.blocks[b_iter];
		CBlob@ b = getBlobByNetworkID( isle_block.blobID );
		if (b !is null)
		{
			isle_block.offset = b.getInterpolatedPosition() - center;
			isle_block.offset.RotateBy( -isle.angle );
			isle_block.angle_offset = b.getAngleDegrees() - isle.angle;
			//isle_block.setModel(b);
			isle.collisionRadius = Maths::Max( isle.collisionRadius, isle_block.offset.Length() + Block::size );
		}
	}

	RebuildIslandPhysicsProperties( isle );
	isle.CombineModels();	
}

void UpdateIslands( CRules@ this, const bool integrate = true, const bool forceOwnerSearch = false )
{
	updatedThisTick = true;
	bool isServer = getNet().isServer();
	CMap@ map = getMap();
	
	Island[]@ islands;
	this.get( "islands", @islands );	
	for (uint i = 0; i < islands.length; ++i)
	{
		Island @isle = islands[i];
		//if (i == 3)
		//print("update "+(isle.pos));

		isle.soundsPlayed = 0;
		isle.carryMass = 0;
		
		if (!isle.initialized || isle.centerBlock is null)
		{
			if ( !isServer ) print ("client: initializing island: " + isle.blocks.length);
			InitIsland( isle );
			isle.initialized = true;
		}

		if ( integrate && !isle.isStation )
		{
			isle.old_pos = isle.pos;
			isle.old_angle = isle.angle;
			isle.pos += isle.vel;		
			isle.angle += isle.angle_vel;
			ApplyWaterDrag( isle );
			
			//check for beached or slowed islands
			isle.beached = false;
			isle.slowed = false;
			for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
			{
				IslandBlock@ isle_block = isle.blocks[b_iter];
				CBlob@ b = getBlobByNetworkID( isle_block.blobID );
				if ( b !is null )
				{
					Vec2f bPos = GetIslandBlockWorldPosition( isle, isle_block );
	
					Tile bTile = map.getTile( bPos );
					bool onLand = map.isTileBackgroundNonEmpty( bTile );
					bool onRock = map.isTileSolid( bTile );
					
					if (onRock)
					{
						TileCollision( isle, bPos );
						if ( !b.hasTag("mothership") || this.get_bool("sudden death") )
							b.server_Hit( b, bPos, Vec2f_zero, 2.2f, 0, true );
					}
					else if ( isTouchingLand(bPos) )
						isle.beached = true;						
					else if ( isTouchingShoal(bPos) )
						isle.slowed = true;
				}
			}
			
			if ( isle.beached )
			{
				isle.vel *= 0.25f;
				isle.angle_vel *= 0.25f;
			}
			else if ( isle.slowed )
			{
				isle.vel *= 0.9f;
				isle.angle_vel *= 0.9f;
			}

			while(isle.angle < 0.0f)
				isle.angle += 360.0f;
				
			while(isle.angle > 360.0f)
				isle.angle -= 360.0f;
		}
		else if ( isle.isStation )
		{
			isle.vel = Vec2f(0, 0);
			isle.angle_vel = 0.0f;			
		}

		UpdateIslandWaveVisual( isle );

		if ( !isServer || ( !forceOwnerSearch && ( getGameTime() + isle.id * 33 ) % 45 > 0 ) )//updateIslandBlobs if !isServer OR isServer and not on a 'second tick'
		{
			for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
			{
				IslandBlock@ isle_block = isle.blocks[b_iter];
				CBlob@ b = getBlobByNetworkID( isle_block.blobID );
				if ( b !is null )
				{
					UpdateIslandBlob( b, isle, isle_block );
				}
			}
		}
		else//(server) updateIslandBlobs and find island.owner once a second or after GenerateIslands()
		{
			u8 cores = 0;
			CBlob@ core = null;
			bool multiTeams = false;
			s8 teamComp = -1;	
			u16[] seatIDs;
			
			for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
			{
				IslandBlock@ isle_block = isle.blocks[b_iter];
				CBlob@ b = getBlobByNetworkID( isle_block.blobID );
				if (b !is null)
				{
					UpdateIslandBlob( b, isle, isle_block );
					
					if ( b.hasTag( "control" ) && b.get_string( "playerOwner" ) != "" )
					{
						seatIDs.push_back( isle_block.blobID );
						
						if ( teamComp == -1 )
							teamComp = b.getTeamNum();
						else if ( b.getTeamNum() != teamComp )
							multiTeams = true;
					} 
					else if ( b.hasTag( "mothership" ) )
					{
						cores++;
						@core = b;
					}
				}
			}
			
			string oldestSeatOwner = "";
			
			if ( seatIDs.length > 0 )
			{
				seatIDs.sortAsc();
				if ( isle.isMothership )
				{
					if ( cores > 1 && multiTeams )
						oldestSeatOwner = "*";
					else if ( core !is null )
						for ( int i = 0; i < seatIDs.length; i++ )
						{
							CBlob@ oldestSeat = getBlobByNetworkID( seatIDs[i] );
							if ( oldestSeat !is null && coreLinkedDirectional( oldestSeat, getGameTime(), core.getPosition() ) )
							{
								oldestSeatOwner = oldestSeat.get_string( "playerOwner" );
								break;
							}
						}
				}
				else
				{
					if ( multiTeams )
						oldestSeatOwner = "*";
					else
						for ( int i = 0; i < seatIDs.length; i++ )
						{
							CBlob@ oldestSeat = getBlobByNetworkID( seatIDs[i] );
							if ( oldestSeat !is null )
							{
								oldestSeatOwner = oldestSeat.get_string( "playerOwner" );
								break;
							}
						}
				}
			}
			
			//change ship color (only non-motherships that have activated seats)
			if ( !isle.isMothership && !isle.isStation && !multiTeams && oldestSeatOwner != "" && isle.owner != oldestSeatOwner )
			{
				CPlayer@ iOwner = getPlayerByUsername( oldestSeatOwner );
				if ( iOwner !is null )
					setIsleTeam( isle, iOwner.getTeamNum() );
			}
			
			isle.owner = oldestSeatOwner;
		}
		//if( isle.owner != "") 	print( "updated isle " + isle.id + "; owner: " + isle.owner + "; mass: " + isle.mass );
	}

	//calculate carryMass weight
	CBlob@[] humans;
	getBlobsByName( "human", @humans );
	for ( u8 i = 0; i < humans.length; i++ )
	{
	    CBlob@[]@ blocks;
		if ( humans[i].get( "blocks", @blocks ) && blocks.size() > 0 )
		{
			Island@ isle = getIsland( humans[i] );
			if ( isle !is null )
			{
				//player-carried blocks add to the island mass (with penalty)
				for ( u8 i = 0; i < blocks.length; i++ )
					isle.carryMass += 2.5f * blocks[i].get_f32( "weight" );
			}
		}
	}

	if ( integrate )
	{
		ResolveIslandCollisions( this, islands );
	}
}

float iLastXPos = 0.01f;
float iLastYPos = 0.01f;

Vec2f GetIslandBlockWorldOffset( Island@ isle, IslandBlock@ isle_block )
{
	if ( isle is null || isle_block is null )
		return Vec2f_zero;

	Vec2f offset = isle_block.offset;
	offset.RotateBy( isle.angle );
	return offset;
}

Vec2f GetIslandBlockWorldPosition( Island@ isle, IslandBlock@ isle_block )
{
	if ( isle is null )
		return Vec2f_zero;

	return isle.pos + GetIslandBlockWorldOffset( isle, isle_block );
}

void UpdateIslandBlob( CBlob@ blob, Island @isle, IslandBlock@ isle_block )
{
	Vec2f offset = GetIslandBlockWorldOffset( isle, isle_block );
	const f32 worldAngle = isle.angle + isle_block.angle_offset;
	const Vec2f blockPos = GetIslandBlockWorldPosition( isle, isle_block );
	const f32 blockY = GetIslandWaveVisualY( isle, offset );
	Vec3f blockPos3D( blockPos.x, blockY, blockPos.y );

	Blob3D@ blob3d;
	if (blob.get("blob3d", @blob3d))
	{		
		Vec3f oldBlockPos3D = blob3d.transform.Position;
		blob.set_f32("platform 3d delta x", blockPos3D.x - oldBlockPos3D.x);
		blob.set_f32("platform 3d delta y", blockPos3D.y - oldBlockPos3D.y);
		blob.set_f32("platform 3d delta z", blockPos3D.z - oldBlockPos3D.z);
		blob3d.setPosition( blockPos3D );
		blob3d.transform.Orientation.x = worldAngle;
		blob3d.transform.Orientation.y = 0.0f;
		blob3d.transform.Orientation.z = 0.0f;
		ApplyIslandWaveVisualToBlob( isle, offset, worldAngle, blob3d );
		blob.setPosition( blob3d.getPosition().xz() );

		//blob3d.shape.model.SetTranslation(V2toV3( isle.pos + offset ));
        //blob3d.shape.model.setRotationDegrees(-(isle.angle + isle_block.angle_offset),0,0);

		if (blob3d.shape !is null)
		{
			blob3d.shape.setPosition( blob3d.getPosition() );
			blob3d.shape.transform.Orientation.x = worldAngle;
			blob3d.shape.transform.Orientation.y = blob3d.renderRotation.x;
			blob3d.shape.transform.Orientation.z = blob3d.renderRotation.z;
			//blob3d.shape.setAngleDegreesXZ( -worldAngle );
		}
		blob3d.SyncExtraShapes();

		//blob3d.shape.UpdateAttributes(SColor(255,255,0,255));
	}

 	blob.setAngleDegrees( worldAngle );

	blob.setVelocity( Vec2f_zero );
	blob.setAngularVelocity( 0.0f );
}

f32 GetShipWaveBobAt(Vec2f pos)
{
    Vec3f samplePos = GetShipWaveSamplePosition(pos);
    const f32 waterDisplacement = GetOceanWaterHeight(samplePos) - GetOceanRestWaterHeight();
    return Maths::Clamp(waterDisplacement * SHIP_WAVE_BOB_SCALE, -SHIP_WAVE_MAX_BOB, SHIP_WAVE_MAX_BOB);
}

f32 SmoothShipWaveValue(const f32 current, const f32 target)
{
	return current + (target - current) * SHIP_WAVE_VISUAL_SMOOTH_FACTOR;
}

void UpdateIslandWaveVisual( Island@ isle )
{
	if ( isle is null )
		return;

	CRules@ rules = getRules();
	if ( rules !is null && rules.get_bool(SHIP_WAVE_VISUALS_DISABLED) )
	{
		isle.waveYOffset = 0.0f;
		isle.waveSlopeX = 0.0f;
		isle.waveSlopeZ = 0.0f;
		isle.waveVisualInitialized = false;
		return;
	}

	const f32 sampleDistance = Maths::Clamp(isle.collisionRadius * 0.45f, SHIP_WAVE_MIN_SAMPLE_DISTANCE, SHIP_WAVE_MAX_SAMPLE_DISTANCE);
	const f32 invSampleSpan = 1.0f / (sampleDistance * 2.0f);
	const Vec2f sampleX(sampleDistance, 0.0f);
	const Vec2f sampleZ(0.0f, sampleDistance);
	const f32 targetYOffset = GetShipWaveBobAt(isle.pos);
	const f32 targetSlopeX = (GetShipWaveBobAt(isle.pos + sampleX) - GetShipWaveBobAt(isle.pos - sampleX)) * invSampleSpan;
	const f32 targetSlopeZ = (GetShipWaveBobAt(isle.pos + sampleZ) - GetShipWaveBobAt(isle.pos - sampleZ)) * invSampleSpan;

	if (!isle.waveVisualInitialized)
	{
		isle.waveYOffset = targetYOffset;
		isle.waveSlopeX = targetSlopeX;
		isle.waveSlopeZ = targetSlopeZ;
		isle.waveVisualInitialized = true;
		return;
	}

	isle.waveYOffset = SmoothShipWaveValue(isle.waveYOffset, targetYOffset);
	isle.waveSlopeX = SmoothShipWaveValue(isle.waveSlopeX, targetSlopeX);
	isle.waveSlopeZ = SmoothShipWaveValue(isle.waveSlopeZ, targetSlopeZ);
}

void ApplyIslandWaveVisualToBlob( Island@ isle, Vec2f worldOffset, const f32 worldAngle, Blob3D@ blob3d )
{
	if ( isle is null || blob3d is null )
		return;

	CRules@ rules = getRules();
	if ( rules !is null && rules.get_bool(SHIP_WAVE_VISUALS_DISABLED) )
	{
		blob3d.renderOffset = Vec3f();
		blob3d.renderRotation = Vec3f();
		return;
	}

	blob3d.renderOffset = Vec3f();
	blob3d.renderRotation = GetIslandWaveVisualRotation(isle);
}

void ApplyWaterDrag( Island@ isle )
{
	if ( isle is null )
		return;

	isle.vel *= VEL_DAMPING;
	isle.angle_vel *= ANGLE_VEL_DAMPING;

	if ( isle.vel.LengthSquared() < 0.000025f )
		isle.vel = Vec2f_zero;

	if ( Maths::Abs( isle.angle_vel ) < 0.0005f )
		isle.angle_vel = 0.0f;

	LimitIslandMotion( isle );
}

void ResolveIslandCollisions( CRules@ rules, Island[]@ islands )
{
	if ( islands is null )
		return;

	for (uint i = 0; i < islands.length; ++i)
	{
		Island@ island = islands[i];
		if ( !CanIslandCollide( island ) )
			continue;

		const f32 islandRadius = GetIslandCollisionRadius( island );

		for (uint j = i + 1; j < islands.length; ++j)
		{
			Island@ other = islands[j];
			if ( !CanIslandCollide( other ) || ( island.isStation && other.isStation ) )
				continue;

			const f32 otherRadius = GetIslandCollisionRadius( other );
			const f32 broadphaseRadius = islandRadius + otherRadius + SHIP_COLLISION_BROADPHASE_PADDING;

			if ( ( island.pos - other.pos ).LengthSquared() > broadphaseRadius * broadphaseRadius )
				continue;

			IslandCollisionContact contact;
			bool foundContact = false;
			if ( island.blocks.length <= other.blocks.length )
			{
				foundContact = FindIslandCollisionContact( island, other, @contact );
			}
			else
			{
				foundContact = FindIslandCollisionContact( other, island, @contact );
				if ( foundContact )
					FlipIslandCollisionContact( @contact );
			}

			if ( !foundContact )
				continue;

			if ( HandlePlatformCollision( rules, @contact ) )
				return;

			if ( contact.solidA && contact.solidB )
			{
				ApplySolidIslandCollision( island, other, @contact );
				RefreshIslandBlobs( island );
				RefreshIslandBlobs( other );
			}
		}
	}
}

bool CanIslandCollide( Island@ isle )
{
	return isle !is null && isle.centerBlock !is null && isle.blocks.length > 0;
}

f32 GetIslandCollisionRadius( Island@ isle )
{
	if ( isle is null )
		return 0.0f;

	if ( isle.collisionRadius > 0.0f )
		return isle.collisionRadius;

	for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
	{
		IslandBlock@ isle_block = isle.blocks[b_iter];
		if ( isle_block !is null )
			isle.collisionRadius = Maths::Max( isle.collisionRadius, isle_block.offset.Length() + Block::size );
	}

	return isle.collisionRadius;
}

void RebuildIslandPhysicsProperties( Island@ isle )
{
	if ( isle is null )
		return;

	f32 totalMass = 0.0f;
	Vec2f weightedCenter = Vec2f_zero;
	isle.collisionRadius = 0.0f;

	for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
	{
		IslandBlock@ isle_block = isle.blocks[b_iter];
		if ( isle_block is null )
			continue;

		CBlob@ block = getBlobByNetworkID( isle_block.blobID );
		const f32 blockMass = block !is null ? Maths::Max( 0.1f, block.get_f32( "weight" ) ) : 1.0f;
		totalMass += blockMass;
		weightedCenter += isle_block.offset * blockMass;
		isle.collisionRadius = Maths::Max( isle.collisionRadius, isle_block.offset.Length() + Block::size );
	}

	if ( totalMass <= 0.0f )
	{
		isle.centerOfMassOffset = Vec2f_zero;
		isle.momentOfInertia = 1.0f;
		return;
	}

	isle.centerOfMassOffset = weightedCenter / totalMass;

	f32 inertia = 0.0f;
	for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
	{
		IslandBlock@ isle_block = isle.blocks[b_iter];
		if ( isle_block is null )
			continue;

		CBlob@ block = getBlobByNetworkID( isle_block.blobID );
		const f32 blockMass = block !is null ? Maths::Max( 0.1f, block.get_f32( "weight" ) ) : 1.0f;
		Vec2f arm = isle_block.offset - isle.centerOfMassOffset;
		inertia += Maths::Sqrt( blockMass ) * ( arm.LengthSquared() + 42.0f );
	}

	isle.momentOfInertia = Maths::Max( 24.0f, inertia );
}

bool FindIslandCollisionContact( Island@ island, Island@ other, IslandCollisionContact@ contact )
{
	if ( contact is null )
		return false;

	const int otherColor = GetIslandColor( other );
	if ( otherColor <= 0 )
		return false;

	bool found = false;
	f32 accumulatedWeight = 0.0f;
	f32 accumulatedPenetration = 0.0f;
	uint contactCount = 0;
	Vec2f accumulatedMTV = Vec2f_zero;
	Vec2f accumulatedPoint = Vec2f_zero;
	const f32 otherRadius = GetIslandCollisionRadius( other ) + SHIP_COLLISION_BLOCK_RADIUS;
	const f32 otherRadiusSquared = otherRadius * otherRadius;

	for (uint a_iter = 0; a_iter < island.blocks.length; ++a_iter)
	{
		IslandBlock@ islandBlockA = island.blocks[a_iter];
		CBlob@ blockA = getBlobByNetworkID( islandBlockA.blobID );
		bool solidA = false;
		bool platformA = false;
		if ( !IsCollisionCandidateBlock( blockA, solidA, platformA ) )
			continue;

		Vec2f blockAPos = GetIslandBlockWorldPosition( island, islandBlockA );
		if ( ( blockAPos - other.pos ).LengthSquared() > otherRadiusSquared )
			continue;

		for (uint b_iter = 0; b_iter < other.blocks.length; ++b_iter)
		{
			IslandBlock@ islandBlockB = other.blocks[b_iter];
			CBlob@ blockB = getBlobByNetworkID( islandBlockB.blobID );
			if ( blockB is blockA || blockB is null || blockB.getName() != "block" )
				continue;

			if ( blockB.getShape().getVars().customData != otherColor )
				continue;

			bool solidB = false;
			bool platformB = false;
			if ( !IsCollisionCandidateBlock( blockB, solidB, platformB ) )
				continue;

			const bool platformBreak = ( Block::destroysPlatformOnCollision( blockA.getSprite().getFrame() ) && platformB )
				|| ( Block::destroysPlatformOnCollision( blockB.getSprite().getFrame() ) && platformA );
			const bool solidBounce = solidA && solidB;
			if ( !platformBreak && !solidBounce )
				continue;

			Vec2f blockBPos = GetIslandBlockWorldPosition( other, islandBlockB );
			if ( ( blockAPos - blockBPos ).LengthSquared() > SHIP_COLLISION_BLOCK_RADIUS * SHIP_COLLISION_BLOCK_RADIUS )
				continue;

			Vec2f mtv;
			if ( !GetBlockCollisionMTV( blockA, blockB, blockAPos, blockBPos, mtv ) )
				continue;

			if ( platformBreak )
			{
				@contact.blockA = blockA;
				@contact.blockB = blockB;
				contact.mtv = mtv;
				contact.point = ( blockAPos + blockBPos ) * 0.5f;
				contact.solidA = solidA;
				contact.solidB = solidB;
				contact.platformA = platformA;
				contact.platformB = platformB;
				return true;
			}

			f32 penetration = mtv.Normalize();
			if ( penetration > 0.0001f )
			{
				found = true;
				@contact.blockA = blockA;
				@contact.blockB = blockB;
				contact.solidA = solidA;
				contact.solidB = solidB;
				contact.platformA = platformA;
				contact.platformB = platformB;

				Vec2f point = ( blockAPos + blockBPos ) * 0.5f;
				accumulatedMTV += mtv * penetration;
				accumulatedPoint += point * penetration;
				accumulatedPenetration += penetration;
				accumulatedWeight += penetration;
				contactCount++;
			}
		}
	}

	if ( found && accumulatedWeight > 0.0f && contactCount > 0 )
	{
		Vec2f normal = accumulatedMTV;
		if ( normal.Normalize() > 0.0001f )
		{
			const f32 averagePenetration = accumulatedPenetration / contactCount;
			contact.mtv = normal * Maths::Min( Block::size * 0.85f, averagePenetration * 1.35f );
			contact.point = accumulatedPoint / accumulatedWeight;
		}
	}

	return found;
}

void FlipIslandCollisionContact( IslandCollisionContact@ contact )
{
	if ( contact is null )
		return;

	CBlob@ blockA = contact.blockA;
	CBlob@ blockB = contact.blockB;
	const bool solidA = contact.solidA;
	const bool platformA = contact.platformA;

	@contact.blockA = blockB;
	@contact.blockB = blockA;
	contact.mtv = -contact.mtv;
	contact.solidA = contact.solidB;
	contact.solidB = solidA;
	contact.platformA = contact.platformB;
	contact.platformB = platformA;
}

int GetIslandColor( Island@ isle )
{
	if ( isle is null || isle.centerBlock is null )
		return 0;

	return isle.centerBlock.getShape().getVars().customData;
}

bool IsCollisionCandidateBlock( CBlob@ block, bool &out solid, bool &out platform )
{
	solid = false;
	platform = false;

	if ( block is null || block.hasTag( "noCollide" ) )
		return false;

	const int type = block.getSprite().getFrame();
	if ( type == Block::COUPLING || Block::isRepulsor( type ) )
		return false;

	solid = Block::isSolidCollisionBlock( type );
	platform = Block::isPlatform( type );
	return solid || platform;
}

bool GetBlockCollisionMTV( CBlob@ blockA, CBlob@ blockB, Vec2f blockAPos, Vec2f blockBPos, Vec2f &out mtv )
{
	Blob3D@ blob3dA;
	Blob3D@ blob3dB;
	if ( blockA.get( "blob3d", @blob3dA ) && blockB.get( "blob3d", @blob3dB )
		&& blob3dA !is null && blob3dB !is null
		&& blob3dA.shape !is null && blob3dB.shape !is null )
	{
		Vec3f mtv3d;
		if ( blob3dA.shape.Contains( blob3dB.shape, Vec3f(), Vec3f(), mtv3d ) != ContainmentType::None )
		{
			mtv = Vec2f( mtv3d.x, mtv3d.z );
			if ( mtv.LengthSquared() > 0.0001f )
				return true;
		}
	}

	return GetFallbackBlockMTV( blockAPos, blockBPos, mtv );
}

bool GetFallbackBlockMTV( Vec2f blockAPos, Vec2f blockBPos, Vec2f &out mtv )
{
	Vec2f delta = blockAPos - blockBPos;
	f32 distance = delta.Normalize();
	if ( distance < 0.001f )
	{
		delta = Vec2f( 1.0f, 0.0f );
		distance = 0.0f;
	}

	const f32 overlap = Block::size - distance;
	if ( overlap <= 0.0f )
		return false;

	mtv = delta * overlap;
	return true;
}

bool HandlePlatformCollision( CRules@ rules, IslandCollisionContact@ contact )
{
	if ( contact is null )
		return false;

	const bool breakA = contact.platformA && contact.solidB;
	const bool breakB = contact.platformB && contact.solidA;
	if ( !breakA && !breakB )
		return false;

	if ( getNet().isServer() )
	{
		if ( breakA )
			ServerDestroyCollisionBlock( contact.blockA );

		if ( breakB )
			ServerDestroyCollisionBlock( contact.blockB );

		rules.set_bool( "dirty islands", true );
	}

	return true;
}

void ServerDestroyCollisionBlock( CBlob@ block )
{
	if ( block is null || !getNet().isServer() || block.hasTag( "noCollide" ) )
		return;

	block.Tag( "noCollide" );
	block.server_Die();
}

void ApplySolidIslandCollision( Island@ island, Island@ other, IslandCollisionContact@ contact )
{
	if ( island is null || other is null || contact is null )
		return;

	Vec2f normal = contact.mtv;
	f32 penetration = normal.Normalize();
	if ( penetration <= 0.001f )
	{
		normal = island.pos - other.pos;
		penetration = normal.Normalize();
	}

	if ( penetration <= 0.001f )
		return;

	const f32 baseInvMassA = GetIslandInverseMass( island );
	const f32 baseInvMassB = GetIslandInverseMass( other );
	const f32 invMassTotal = baseInvMassA + baseInvMassB;
	if ( invMassTotal <= 0.0f )
		return;

	f32 shareA = baseInvMassA / invMassTotal;
	f32 shareB = baseInvMassB / invMassTotal;
	if ( !island.isStation && !other.isStation )
	{
		shareA = Maths::Clamp( shareA, SHIP_COLLISION_MIN_DYNAMIC_SHARE, 1.0f - SHIP_COLLISION_MIN_DYNAMIC_SHARE );
		shareB = 1.0f - shareA;
	}
	const f32 invMassA = shareA * invMassTotal;
	const f32 invMassB = shareB * invMassTotal;
	const f32 invInertiaA = GetIslandInverseInertia( island );
	const f32 invInertiaB = GetIslandInverseInertia( other );

	Vec2f correction = normal * penetration * SHIP_COLLISION_POSITION_PERCENT;

	island.pos += correction * shareA;
	other.pos -= correction * shareB;

	Vec2f centerA = GetIslandCenterOfMass( island );
	Vec2f centerB = GetIslandCenterOfMass( other );
	Vec2f armA = contact.point - centerA;
	Vec2f armB = contact.point - centerB;
	const f32 armCrossA = Cross2D( armA, normal );
	const f32 armCrossB = Cross2D( armB, normal );
	const f32 impulseDenominator = invMassA + invMassB + armCrossA * armCrossA * invInertiaA + armCrossB * armCrossB * invInertiaB;
	if ( impulseDenominator <= 0.0001f )
		return;

	Vec2f relativeVelocity = GetIslandPointVelocity( island, contact.point ) - GetIslandPointVelocity( other, contact.point );
	const f32 separatingVelocity = relativeVelocity * normal;
	const f32 pushBias = Maths::Clamp( penetration * SHIP_COLLISION_PUSH_BIAS, SHIP_COLLISION_MIN_PUSH, SHIP_COLLISION_MAX_PUSH );

	f32 impulseMagnitude = 0.0f;
	if ( separatingVelocity < 0.0f )
	{
		impulseMagnitude = ( -( 1.0f + SHIP_COLLISION_RESTITUTION ) * separatingVelocity + pushBias ) / impulseDenominator;
	}
	else if ( separatingVelocity < pushBias )
	{
		impulseMagnitude = ( pushBias - separatingVelocity ) / impulseDenominator;
	}

	if ( impulseMagnitude > 0.0f )
	{
		Vec2f impulse = normal * impulseMagnitude;
		island.vel += impulse * invMassA;
		other.vel -= impulse * invMassB;

		ApplyIslandAngularImpulse( island, contact.point, impulse, invInertiaA );
		ApplyIslandAngularImpulse( other, contact.point, -impulse, invInertiaB );
	}

	if ( !island.isStation && !other.isStation )
	{
		const f32 separationBoost = Maths::Min( SHIP_COLLISION_MAX_PUSH, pushBias + penetration * SHIP_COLLISION_SEPARATION_BOOST );
		island.vel += normal * separationBoost * shareA;
		other.vel -= normal * separationBoost * shareB;
	}

	Vec2f tangentVelocity = relativeVelocity - normal * separatingVelocity;
	if ( tangentVelocity.LengthSquared() > 0.0001f )
	{
		island.vel -= tangentVelocity * 0.035f * shareA;
		other.vel += tangentVelocity * 0.035f * shareB;
	}

	LimitIslandMotion( island );
	LimitIslandMotion( other );
}

f32 GetIslandEffectiveMass( Island@ isle )
{
	if ( isle is null )
		return 1.0f;

	return Maths::Max( 1.0f, Maths::Sqrt( isle.mass + isle.carryMass ) );
}

f32 GetIslandInverseMass( Island@ isle )
{
	if ( isle is null || isle.isStation )
		return 0.0f;

	return 1.0f / GetIslandEffectiveMass( isle );
}

f32 GetIslandInverseInertia( Island@ isle )
{
	if ( isle is null || isle.isStation )
		return 0.0f;

	if ( isle.momentOfInertia <= 0.0f )
		RebuildIslandPhysicsProperties( isle );

	return isle.momentOfInertia > 0.0f ? 1.0f / isle.momentOfInertia : 0.0f;
}

Vec2f GetIslandCenterOfMass( Island@ isle )
{
	if ( isle is null )
		return Vec2f_zero;

	Vec2f offset = isle.centerOfMassOffset;
	offset.RotateBy( isle.angle );
	return isle.pos + offset;
}

Vec2f GetIslandPointVelocity( Island@ isle, Vec2f point )
{
	if ( isle is null )
		return Vec2f_zero;

	Vec2f arm = point - GetIslandCenterOfMass( isle );
	const f32 angularRadians = isle.angle_vel * Maths::Pi / 180.0f;
	return isle.vel + Vec2f( -arm.y, arm.x ) * angularRadians;
}

f32 Cross2D( Vec2f a, Vec2f b )
{
	return a.x * b.y - a.y * b.x;
}

void ApplyIslandAngularImpulse( Island@ isle, Vec2f point, Vec2f impulse, f32 invInertia )
{
	if ( isle is null || isle.isStation || invInertia <= 0.0f )
		return;

	Vec2f arm = point - GetIslandCenterOfMass( isle );
	const f32 torque = Cross2D( arm, impulse );
	const f32 deltaAngularVelocity = torque * invInertia * 180.0f / Maths::Pi * SHIP_COLLISION_ANGULAR_TRANSFER;
	isle.angle_vel += Maths::Clamp( deltaAngularVelocity, -SHIP_COLLISION_MAX_ANGULAR_KICK, SHIP_COLLISION_MAX_ANGULAR_KICK );
}

void LimitIslandMotion( Island@ isle )
{
	if ( isle is null )
		return;

	const f32 speedSquared = isle.vel.LengthSquared();
	const f32 maxSpeedSquared = SHIP_MAX_SPEED * SHIP_MAX_SPEED;
	if ( speedSquared > maxSpeedSquared )
	{
		isle.vel *= SHIP_MAX_SPEED / Maths::Sqrt( speedSquared );
	}

	isle.angle_vel = Maths::Clamp( isle.angle_vel, -SHIP_MAX_ANGLE_SPEED, SHIP_MAX_ANGLE_SPEED );
}

void RefreshIslandBlobs( Island@ isle )
{
	if ( isle is null )
		return;

	for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
	{
		IslandBlock@ isle_block = isle.blocks[b_iter];
		if ( isle_block is null )
			continue;

		CBlob@ b = getBlobByNetworkID( isle_block.blobID );
		if ( b !is null )
			UpdateIslandBlob( b, isle, isle_block );
	}
}

void TileCollision( Island@ island, Vec2f tilePos )
{
	if ( island is null )
		return;
		
	if ( island.mass <= 0 )
		return;
	
	Vec2f normal = island.pos - tilePos;
	if ( normal.Normalize() <= 0.001f )
		return;

	const f32 incomingSpeed = island.vel * normal;
	if ( incomingSpeed < 0.0f )
	{
		island.vel -= normal * incomingSpeed * 1.35f;
	}

	island.vel += normal * 0.35f;
	island.vel *= 0.86f;
	island.angle_vel *= 0.88f;
	LimitIslandMotion( island );
	
	//effects

}

void setIsleTeam( Island @isle, u8 teamNum = 255 )
{
	//print (  "setting team for " + isle.owner + "'s " + isle.id + " to " + teamNum );
	for ( uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter )
	{
		CBlob@ b = getBlobByNetworkID( isle.blocks[b_iter].blobID );
		if ( b !is null )
		{
			int blockType = b.getSprite().getFrame();
			b.server_setTeamNum( teamNum );
			b.getSprite().SetFrame( blockType );
		}
	}
}

void onBlobChangeTeam( CRules@ this, CBlob@ blob, const int oldTeam )//awkward fix for blob team changes wiping up the frame state (rest on Block.as)
{
	if ( !getNet().isServer() && blob.getName() == "block" )
		blob.set_u8( "frame", blob.getSprite().getFrame() );
}

void StoreVelocities( CRules@ this )
{
	Island[]@ islands;
	if (this.get( "islands", @islands ))
		for (uint i = 0; i < islands.length; ++i)
		{
			Island @isle = islands[i];
			
			if ( !isle.isStation )
			{
				for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
				{
					CBlob@ b = getBlobByNetworkID( isle.blocks[b_iter].blobID );
					if (b !is null)
					{
						b.setVelocity( isle.vel );
						b.setAngularVelocity( isle.angle_vel );	
					}
				}
			}
		}
}

void onBlobDie( CRules@ this, CBlob@ blob )
{
	// this will leave holes until next full sync
	if (blob.getShape().getVars().customData > 0)
	{
		const u16 id = blob.getNetworkID();
		Island@ isle = getIsland( blob.getShape().getVars().customData );
		if (isle !is null)
		{
			for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
			{
				if (isle.blocks[b_iter].blobID == id){
					isle.blocks.erase(b_iter); 
					if (isle.centerBlock is null || isle.centerBlock.getNetworkID() == id)
					{
						@isle.centerBlock = null;
						isle.initialized = false;
					}
					b_iter = 0;

					if (blob.getSprite().getFrame() == Block::COUPLING){
						this.set_bool("dirty islands", true);		
						return;
					}
				}
			}
			//if (isle.blocks.length == 0)
				this.set_bool("dirty islands", true);			
		}
	}
}

void setUpdateSeatsArrays()
{
	CBlob@[] seats;
	if ( getBlobsByTag( "seat", @seats ) )
		for ( uint i = 0; i < seats.length; i++ )
			seats[i].set_bool( "updateArrays", true );
}


// network

void Synchronize( CRules@ this, bool full_sync, CPlayer@ player = null )
{
	CBitStream bs;
	if (Serialize( this, bs, full_sync ))
		this.SendCommand( full_sync ? this.getCommandID("islands sync") : this.getCommandID("islands update"), bs, player );
}

bool Serialize( CRules@ this, CBitStream@ stream, const bool full_sync )
{
	Island[]@ islands;
	if (this.get( "islands", @islands ))
	{
		stream.write_u16( islands.length );
		bool atLeastOne = false;
		for (uint i = 0; i < islands.length; ++i)
		{
			Island @isle = islands[i];
			if (full_sync)
			{
				stream.write_Vec2f( isle.pos );
				CPlayer@ owner = getPlayerByUsername( isle.owner );
				stream.write_u16( owner !is null ? owner.getNetworkID() : 0 );
				stream.write_u16( isle.centerBlock !is null ? isle.centerBlock.getNetworkID() : 0 );
				stream.write_Vec2f( isle.vel );
				stream.write_f32( isle.angle );
				stream.write_f32( isle.angle_vel );			
				stream.write_f32( isle.mass );
				stream.write_bool( isle.isMothership );
				stream.write_bool( isle.isStation );
				stream.write_u16( isle.blocks.length );
				for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
				{
					IslandBlock@ isle_block = isle.blocks[b_iter];
					CBlob@ b = getBlobByNetworkID( isle_block.blobID );
					if (b !is null)
					{
						stream.write_netid( b.getNetworkID() );	
						stream.write_Vec2f( isle_block.offset );
						stream.write_f32( isle_block.angle_offset );
					}
					else
					{
						stream.write_netid( 0 );	
						stream.write_Vec2f( Vec2f_zero );
						stream.write_f32( 0.0f );
					}
				}

				stream.write_u16(isle.island_Vertices.length());
				stream.write_u16(isle.island_IDs.length());

				for (uint i = 0; i < isle.island_Vertices.length(); i++)
				{ 
					float x = isle.island_Vertices[i].x;
					float y = isle.island_Vertices[i].y;
					float z = isle.island_Vertices[i].z;
					float u = isle.island_Vertices[i].u;
					float v = isle.island_Vertices[i].v;		
					stream.write_f32(x);
					stream.write_f32(y);
					stream.write_f32(z);
					stream.write_f32(u);
					stream.write_f32(v);
				}

				for (uint i = 0; i < isle.island_IDs.length(); i++)
				{ stream.write_u16(isle.island_IDs[i]); }

				isle.net_pos = isle.pos;		
				isle.net_vel = isle.vel;
				isle.net_angle = isle.angle;
				isle.net_angle_vel = isle.angle_vel;
				atLeastOne = true;
			}
			else
			{
				const f32 thresh = 0.005f;
				if ((getGameTime()+i) % FORCE_UPDATE_TICKS == 0 || isIslandChanged( isle ))				
				{
					stream.write_bool( true );
					CPlayer@ owner = getPlayerByUsername( isle.owner );
					stream.write_u16( owner !is null ? owner.getNetworkID() : 0 );			
					if ((isle.net_pos - isle.pos).LengthSquared() > thresh){
						stream.write_bool( true );
						stream.write_Vec2f( isle.pos );
						isle.net_pos = isle.pos;
					}
					else stream.write_bool( false );

					
					if ((isle.net_vel - isle.vel).LengthSquared() > thresh){
						stream.write_bool( true );
						stream.write_Vec2f( isle.vel );
						isle.net_vel = isle.vel;
					}
					else stream.write_bool( false );
					
					if (Maths::Abs(isle.net_angle - isle.angle) > thresh){
						stream.write_bool( true );
						stream.write_f32( isle.angle );
						isle.net_angle = isle.angle;
					}
					else stream.write_bool( false );

					if (Maths::Abs(isle.net_angle_vel - isle.angle_vel) > thresh){
						stream.write_bool( true );
						stream.write_f32( isle.angle_vel );
						isle.net_angle_vel = isle.angle_vel;
					}
					else stream.write_bool( false );

					atLeastOne = true;		
				}
				else
					stream.write_bool( false );
			}
		}
		return atLeastOne;
	}
	
	warn("islands not found on serialize");
	return false;
}

void onCommand( CRules@ this, u8 cmd, CBitStream @params )
{
	if (getNet().isServer())
		return;

	if (cmd == this.getCommandID("islands sync"))
	{
		Island[]@ islands;
		if (this.get( "islands", @islands ))
		{
			islands.clear();
			const u16 count = params.read_u16();
			for (uint i = 0; i < count; ++i)
			{
				Island isle;
				if (!params.saferead_Vec2f(isle.pos)){
					warn("islands sync: isle.pos not found");
					return;
				}
				u16 ownerID = params.read_u16();
				CPlayer@ owner = ownerID != 0 ? getPlayerByNetworkId( ownerID ) : null;
				isle.owner = owner !is null ? owner.getUsername() : "";
				u16 centerBlockID = params.read_u16();
				@isle.centerBlock = centerBlockID != 0 ? getBlobByNetworkID( centerBlockID ) : null;
				isle.vel = params.read_Vec2f();
				isle.angle = params.read_f32();
				isle.angle_vel = params.read_f32();
				isle.mass = params.read_f32();
				isle.isMothership = params.read_bool();
				isle.isStation = params.read_bool();
				if ( isle.centerBlock !is null )
				{
					isle.initialized = true;
				}

				isle.old_pos = isle.pos;
				isle.old_angle = isle.angle;
				
				const u16 blocks_count = params.read_u16();
				for (uint b_iter = 0; b_iter < blocks_count; ++b_iter)
				{
					u16 netid;
					if (!params.saferead_netid(netid)){
						warn("islands sync: netid not found");
						return;
					}
					CBlob@ b = getBlobByNetworkID( netid );
					Vec2f pos = params.read_Vec2f();
					f32 angle = params.read_f32();
					if (b !is null)
					{
						IslandBlock isle_block;
						isle_block.blobID = netid;
						isle_block.offset = pos;
						isle_block.angle_offset = angle;
						isle.blocks.push_back(isle_block);	
	    				b.getShape().getVars().customData = i+1; // color		
							// safety on desync
							b.SetVisible(true);
						    CSprite@ sprite = b.getSprite();
	    					sprite.asLayer().SetColor( color_white );
	    					sprite.asLayer().setRenderStyle( RenderStyle::normal );
					}
					else
						warn(" Blob not found when creating island, id = " + netid);
				}
				
				u16 l1 = params.read_u16();
				u16 l2 = params.read_u16();

				for (u16 i = 0; i < l1; i++)
				{ 
					float x = params.read_f32();
					float y = params.read_f32();
					float z = params.read_f32();
					float u = params.read_f32();
					float v = params.read_f32();

					isle.island_Vertices.push_back(Vertex(x,y,z,u,v, color_white));
				}
				for (u16 i = 0; i < l2; i++)
				{
					isle.island_IDs.push_back(params.read_u16()); 
				}

				islands.push_back(isle);
			}

			UpdateIslands( this, false );
		}
		else
		{
				warn("Islands not found on sync");
				return;
		}
	}
	else if (cmd == this.getCommandID("islands update"))
	{
		Island[]@ islands;
		if (this.get( "islands", @islands ))
		{
			u16 count;
			if (!params.saferead_u16(count)){
				warn("islands update: count not found");
				return;
			}
			if (count != islands.length){
				warn("Update received before island sync " + count + " != " + islands.length);
				return;
			}
			for (uint i = 0; i < count; ++i)
			{
				if (params.read_bool())
				{
					Island @isle = islands[i];
					u16 ownerID = params.read_u16();
					CPlayer@ owner = ownerID != 0 ? getPlayerByNetworkId( ownerID ) : null;
					isle.owner = owner !is null ? owner.getUsername() : "";
					if (params.read_bool())
					{
						Vec2f dDelta = params.read_Vec2f() - isle.pos;
						if ( dDelta.LengthSquared() < 512 )//8 blocks threshold
							isle.pos = isle.pos + dDelta/UPDATE_DELTA_SMOOTHNESS;
						else
							isle.pos += dDelta; 
					}
					if (params.read_bool())
					{
						isle.vel = params.read_Vec2f()/VEL_DAMPING;
					}
					if (params.read_bool())
					{
						f32 aDelta =  params.read_f32() - isle.angle;
						if ( aDelta > 180 )	aDelta -= 360;
						if ( aDelta < -180 )	aDelta += 360;
						isle.angle = isle.angle + aDelta/UPDATE_DELTA_SMOOTHNESS;
						while ( isle.angle < 0.0f )	isle.angle += 360.0f;
						while ( isle.angle > 360.0f )	isle.angle -= 360.0f;
					}
					if (params.read_bool())
					{
						isle.angle_vel = params.read_f32()/ANGLE_VEL_DAMPING;
					}
				}
			}
			UpdateIslands( this, false );
		}
		else
		{
				warn("Islands not found on update");
				return;
		}
	}
}

void onNewPlayerJoin( CRules@ this, CPlayer@ player )
{
	if (!player.isMyPlayer())
		Synchronize( this, true, player ); // will set old values
}

bool isIslandChanged( Island@ isle )
{
	const f32 thresh = 0.01f;
	return ((isle.pos - isle.old_pos).LengthSquared() > thresh || Maths::Abs(isle.angle - isle.old_angle) > thresh);
}

bool candy = false;

void ShowWaveSampleOffset( CRules@ rules )
{
	if (rules is null)
		return;

	client_AddToChat(
		"Wave sample offset: x "
		+ rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_X)
		+ ", y "
		+ rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_Y)
		+ ", z "
		+ rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_Z)
		+ " | debug "
		+ (rules.get_bool(SHIP_WAVE_SAMPLE_DEBUG) ? "on" : "off")
		+ " | visuals "
		+ (rules.get_bool(SHIP_WAVE_VISUALS_DISABLED) ? "off" : "on")
	);
}

void AddWaveSampleOffset( CRules@ rules, const string &in key, const f32 amount )
{
	if (rules is null)
		return;

	rules.set_f32(key, rules.get_f32(key) + amount);
	ShowWaveSampleOffset(rules);
}

bool onClientProcessChat( CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player )
{	
	if (  player !is null )
	{
		bool myPlayer = player.isMyPlayer();
		if ( myPlayer && textIn == "!candy" )
		{
			candy = !candy;
			return false;
		}
		
		if (textIn.substr(0,1) == "!" )
		{
			string[]@ tokens = textIn.split(" ");

			if (tokens[0] == "!ds")
			{
				if ( myPlayer )
				{
					if (tokens.length > 1)
					{
						UPDATE_DELTA_SMOOTHNESS = Maths::Max( 1.0f, parseFloat( tokens[1] ) );
						client_AddToChat( "Delta smoothness set to " + UPDATE_DELTA_SMOOTHNESS );
					} else
						client_AddToChat( "Delta smoothness: " + UPDATE_DELTA_SMOOTHNESS );
				}
				return false;
			}

			if (tokens[0] == "!wave")
			{
				if ( myPlayer )
				{
					if (tokens.length <= 1)
					{
						ShowWaveSampleOffset(this);
					}
					else if (tokens[1] == "debug")
					{
						this.set_bool(SHIP_WAVE_SAMPLE_DEBUG, !this.get_bool(SHIP_WAVE_SAMPLE_DEBUG));
						ShowWaveSampleOffset(this);
					}
					else if (tokens[1] == "off" || tokens[1] == "disable")
					{
						this.set_bool(SHIP_WAVE_VISUALS_DISABLED, true);
						ShowWaveSampleOffset(this);
					}
					else if (tokens[1] == "on" || tokens[1] == "enable")
					{
						this.set_bool(SHIP_WAVE_VISUALS_DISABLED, false);
						ShowWaveSampleOffset(this);
					}
					else if (tokens[1] == "toggle")
					{
						this.set_bool(SHIP_WAVE_VISUALS_DISABLED, !this.get_bool(SHIP_WAVE_VISUALS_DISABLED));
						ShowWaveSampleOffset(this);
					}
					else if (tokens[1] == "reset")
					{
						this.set_f32(SHIP_WAVE_SAMPLE_OFFSET_X, 0.0f);
						this.set_f32(SHIP_WAVE_SAMPLE_OFFSET_Y, 0.0f);
						this.set_f32(SHIP_WAVE_SAMPLE_OFFSET_Z, 0.0f);
						ShowWaveSampleOffset(this);
					}
					else if (tokens[1] == "x+")
					{
						AddWaveSampleOffset(this, SHIP_WAVE_SAMPLE_OFFSET_X, 8.0f);
					}
					else if (tokens[1] == "x-")
					{
						AddWaveSampleOffset(this, SHIP_WAVE_SAMPLE_OFFSET_X, -8.0f);
					}
					else if (tokens[1] == "y+")
					{
						AddWaveSampleOffset(this, SHIP_WAVE_SAMPLE_OFFSET_Y, 8.0f);
					}
					else if (tokens[1] == "y-")
					{
						AddWaveSampleOffset(this, SHIP_WAVE_SAMPLE_OFFSET_Y, -8.0f);
					}
					else if (tokens[1] == "z+")
					{
						AddWaveSampleOffset(this, SHIP_WAVE_SAMPLE_OFFSET_Z, 8.0f);
					}
					else if (tokens[1] == "z-")
					{
						AddWaveSampleOffset(this, SHIP_WAVE_SAMPLE_OFFSET_Z, -8.0f);
					}
					else
					{
						client_AddToChat("Usage: !wave [on|off|toggle|debug|reset|x+|x-|y+|y-|z+|z-]");
					}
				}
				return false;
			}
		}
	}
	
	return true;
}

void onRender( CRules@ this )
{
	if (g_debug == 1 || candy)
	{
		CCamera@ camera = getCamera();
		if ( camera is null ) return;
		f32 camRotation = 0;
		Island[]@ islands;
		if (this.get( "islands", @islands ))
			for (uint i = 0; i < islands.length; ++i)
			{
				Island @isle = islands[i];
				if ( isle.centerBlock !is null )
				{
					Vec2f cbPos = getDriver().getScreenPosFromWorldPos( isle.centerBlock.getInterpolatedPosition() );
					Vec2f iVel = isle.vel * 20;
					iVel.RotateBy( -camRotation );					
					GUI::DrawArrow2D( cbPos, cbPos + iVel, SColor( 175, 0, 200, 0) );
					//GUI::DrawText( "" + isle.vel.Length(), cbPos, SColor( 255,255,255,255 ));
				}
					
				for (uint b_iter = 0; b_iter < isle.blocks.length; ++b_iter)
				{
					IslandBlock@ isle_block = isle.blocks[b_iter];
					CBlob@ b = getBlobByNetworkID( isle_block.blobID );
					if (b !is null)
					{
						int c = b.getShape().getVars().customData;
						GUI::DrawRectangle( getDriver().getScreenPosFromWorldPos(b.getInterpolatedPosition() - Vec2f(8, 8).RotateBy( camRotation ) )
						, getDriver().getScreenPosFromWorldPos(b.getInterpolatedPosition() + Vec2f(8, 8).RotateBy( camRotation ) ), SColor( 100, c*50, -c*90, 93*c ) );
						GUI::DrawText( "" + isle_block.blobID, getDriver().getScreenPosFromWorldPos(b.getInterpolatedPosition()), SColor( 255,255,255,255 ));
					}
				}
			}
	}
}
