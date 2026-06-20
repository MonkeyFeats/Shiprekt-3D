#include "IslandsCommon.as"
#include "AccurateSoundPlay.as"
#include "SAT_Shapes.as"
#include "BlockCommon.as"
#include "Raycast3D.as"

const f32 rotate_speed = 30.0f;
const f32 max_build_distance = 32.0f;
const string PLACEMENT_POINT_READY = "placement point ready";
const string PLACEMENT_POINT_X = "placement point x";
const string PLACEMENT_POINT_Y = "placement point y";
const string PLACEMENT_POINT_Z = "placement point z";
u16 crewCantPlaceCounter = 0;

void onInit( CBlob@ this )
{
    CBlob@[] blocks;
    this.set("blocks", blocks);
    this.set_f32("blocks_angle", 0.0f);
    this.set_f32("target_angle", 0.0f);
	SetPlacementPoint(this, V2toV3(this.getPosition(), Raycast3D::GetBuildPlaneY(this)), false, false);

    this.addCommandID("place");
}

bool GetWaveBuildSurfaceHit(CBlob@ builder, Island@ island, Raycast3D::RaycastHit3D &out surfaceHit, bool &out blockedByBlock)
{
	blockedByBlock = false;
	surfaceHit.Clear();

	if (builder is null || island is null)
	{
		return false;
	}

	Raycast3D::Ray3D ray;
	if (!Raycast3D::GetLocalCameraRay(builder, ray))
	{
		return false;
	}

	const Vec2f islandPos = island.pos;
	const f32 baseY = GetIslandWaveVisualY(island, Vec2f_zero);
	Vec3f planePoint(islandPos.x, baseY, islandPos.y);
	Vec3f planeNormal(-island.waveSlopeX, 1.0f, -island.waveSlopeZ);
	if (!Raycast3D::RaycastPlane(ray, planePoint, planeNormal, Raycast3D::BUILD_RAY_DISTANCE, surfaceHit))
	{
		return false;
	}

	Raycast3D::RaycastHit3D blockHit;
	const f32 blockMaxDistance = Maths::Max(0.0f, surfaceHit.distance - 0.05f);
	blockedByBlock = Raycast3D::RaycastBlockTarget(ray, Raycast3D::BLOCK_RAY_START_EPSILON, blockMaxDistance, builder, blockHit);
	return true;
}

void onTick( CBlob@ this )
{
    CBlob@[]@ blocks;
    if (this.get( "blocks", @blocks ) && blocks.size() > 0)
    {
		Vec2f pos = this.getPosition();
		CMap@ map = getMap();
		Tile tile = map.getTile( pos );
		bool onLand = map.isTileBackgroundNonEmpty( tile ) || map.isTileSolid( tile );
	
        Island@ island = getIsland( this );
		if (island !is null && island.centerBlock !is null)
        {
			Vec2f islandPos = island.centerBlock.getPosition();
            f32 blocks_angle = this.get_f32("blocks_angle");//next step angle
            f32 target_angle = this.get_f32("target_angle");//final angle (after manual rotation)
            Vec3f placementPoint = GetPlacementPoint(this);
			bool rayBlocked = false;
			bool rayHasPlacement = !this.isMyPlayer() && this.get_bool(PLACEMENT_POINT_READY);
			if (this.isMyPlayer())
			{
				Raycast3D::RaycastHit3D placementHit;
				rayHasPlacement = GetWaveBuildSurfaceHit(this, island, placementHit, rayBlocked);
				if (rayHasPlacement)
				{
					placementPoint = placementHit.point;
				}
				SetPlacementPoint(this, placementPoint, true, rayHasPlacement);
			}
			
			CBlob@ refBlob = getIslandBlob( this );
					
            if (refBlob is null)
			{
				warn("PlaceBlocks: refBlob not found");
                return;
            }

			if ( getNet().isClient() )
				PositionBlocks( @blocks, pos, placementPoint, blocks_angle, island.centerBlock, refBlob );

			CPlayer@ player = this.getPlayer();
            if (player !is null && player.isMyPlayer()) 
            {
				//checks for canPlace
				u32 gameTime = getGameTime();
				CRules@ rules = getRules();
				bool skipCoreCheck = gameTime > getRules().get_u16( "warmup_time" ) || ( island.isMothership && ( island.owner == "" ||  island.owner == "*" || island.owner == player.getUsername() ) );
				bool cLinked = false;
                const bool overlappingIsland = blocksOverlappingIsland( @blocks );

                Vec2f mouseNorm = placementPoint.xz() - pos;
				f32 mouseLen = mouseNorm.Length();
				if (mouseLen > 0.01f)
				{
					mouseNorm /= mouseLen;
				}

				bool toofar = (mouseLen > max_build_distance || !rayHasPlacement || rayBlocked);

				//print(""+blocks.length);	
				for (uint i = 0; i < blocks.length; ++i)
				{				
					if (toofar)
					{
						blocks[i].set_bool("red",true);	
						SetDisplay( blocks[i], SColor(255, 255, 0, 0), RenderStyle::additive );
						continue;
					}
					if ( overlappingIsland )
					{					
						blocks[i].set_bool("red",true);	
						SetDisplay( blocks[i], SColor(255, 255, 0, 0), RenderStyle::additive );
						continue;
					}
					
					if ( skipCoreCheck || blocks[i].hasTag( "coupling" ) || blocks[i].hasTag( "repulsor" ) )
						continue;
						
					if ( !cLinked )
					{
						CBlob@ core = getMothership( this.getTeamNum() );//could get the core properly based on adjacent blocks
						if ( core !is null )
							cLinked = coreLinkedDirectional( blocks[i], gameTime, core.getPosition() );
					}
					
					if ( cLinked )
						blocks[i].set_bool("red",true);
						SetDisplay( blocks[i], SColor(255, 255, 0, 0), RenderStyle::additive );
				}
				
				//can'tPlace heltips
				bool crewCantPlace = (!overlappingIsland && cLinked); //|| toofar;
				if ( crewCantPlace )
					crewCantPlaceCounter++;
				else
					crewCantPlaceCounter = 0;

				this.set_bool( "blockPlacementWarn", crewCantPlace && crewCantPlaceCounter > 15 );
				
                // place
                if (this.isKeyJustPressed( key_action1 ) && !getHUD().hasMenus() && !getHUD().hasButtons() )
                {
                	print("Just Placed");
                    if (target_angle == blocks_angle && !overlappingIsland && !cLinked && rayHasPlacement && !rayBlocked && !toofar)
                    {
                        CBitStream params;
                        params.write_netid( island.centerBlock.getNetworkID() );
                        params.write_netid( refBlob.getNetworkID() );
                        params.write_Vec2f( pos - islandPos );
                        params.write_f32( float(placementPoint.x) );
                        params.write_f32( float(placementPoint.y) );
                        params.write_f32( float(placementPoint.z) );
                        params.write_f32( target_angle );
                        params.write_f32( island.centerBlock.getAngleDegrees() );
                        this.SendCommand( this.getCommandID("place"), params );
                    }
                    else
                    {
                        this.getSprite().PlaySound("Denied.ogg");                        
                    }
                }

                CControls@ controls = getControls();
                // rotate
                if (controls.isKeyJustPressed(controls.getActionKeyKey(AK_ZOOMOUT)))
    			{
    				target_angle += 90.0f;
                    if (target_angle > 360.0f) 
                    {
                        target_angle -= 360.0f;
                        blocks_angle -= 360.0f;
                    }
                    this.set_f32("target_angle", target_angle);
                    this.Sync("target_angle", false);
    			}
  	 			else if (controls.isKeyJustPressed(controls.getActionKeyKey(AK_ZOOMIN)))
    			{
    				target_angle -= 90.0f;
                    if (target_angle < 0.0f) 
                    {
                        target_angle += 360.0f;
                        blocks_angle += 360.0f;
                    }
                    this.set_f32("target_angle", target_angle);
                    this.Sync("target_angle", false);
    			}
            }

            blocks_angle += rotate_speed;
            if (blocks_angle > target_angle)
                blocks_angle = target_angle;        
            this.set_f32("blocks_angle", blocks_angle);
        }
        else
        {
            // cant place in water
            for (uint i = 0; i < blocks.length; ++i)
            {
                CBlob @block = blocks[i];
                block.set_bool("red",true);
                SetDisplay( block, SColor(255, 255, 0, 0), RenderStyle::light, -10.0f);
            }
        }
    }
}

Vec3f GetPlacementPoint(CBlob@ this)
{
	return Vec3f(
		this.get_f32(PLACEMENT_POINT_X),
		this.get_f32(PLACEMENT_POINT_Y),
		this.get_f32(PLACEMENT_POINT_Z)
	);
}

void SetPlacementPoint(CBlob@ this, Vec3f point, bool sync, bool ready = true)
{
	this.set_bool(PLACEMENT_POINT_READY, ready);
	this.set_f32(PLACEMENT_POINT_X, float(point.x));
	this.set_f32(PLACEMENT_POINT_Y, float(point.y));
	this.set_f32(PLACEMENT_POINT_Z, float(point.z));

	if (sync)
	{
		this.Sync(PLACEMENT_POINT_READY, false);
		this.Sync(PLACEMENT_POINT_X, false);
		this.Sync(PLACEMENT_POINT_Y, false);
		this.Sync(PLACEMENT_POINT_Z, false);
	}
}

void PositionBlocks( CBlob@[]@ blocks, Vec2f pos, Vec3f placementPoint, const f32 blocks_angle, CBlob@ centerBlock, CBlob@ refBlock )
{
    if ( centerBlock is null )
	{
        warn("PositionBlocks: centerblock not found");
        return;
    }
	
    f32 angle = centerBlock.getAngleDegrees();
	f32 refBAngle = refBlock.getAngleDegrees();//reference block angle
	//current island angle as point of reference
	while(refBAngle > angle + 45)	refBAngle -= 90.0f;
	while(refBAngle < angle - 45)	refBAngle += 90.0f;

	Vec2f island_pos = refBlock.getPosition();
	Vec2f islandAim = placementPoint.xz() - island_pos;//island to 'buildblock' pointer
	islandAim.RotateBy( -refBAngle );		islandAim = SnapToGrid( islandAim );		islandAim.RotateBy( refBAngle );
	Vec2f cursor_pos = island_pos + islandAim;//position of snapped buildblock
	
	//rotate and position blocks
	for (uint i = 0; i < blocks.length; ++i)
	{
		CBlob @block = blocks[i];
		Vec2f offset = block.get_Vec2f( "offset" );
		offset.RotateBy( blocks_angle );                        
		offset.RotateBy( refBAngle );                
  
		block.setPosition( cursor_pos + offset );//align to island grid
		block.setAngleDegrees( ( refBAngle + blocks_angle ) % 360.0f );//set angle: reference angle + rotation angle
		Blob3D@ block3d;
		if (block.get("blob3d", @block3d) && block3d !is null)
		{
			Island@ island = getIsland(centerBlock.getShape().getVars().customData);
			Vec2f islandPos = centerBlock.getPosition();
			if (island !is null)
			{
				islandPos = island.pos;
			}
			Vec2f worldOffset = block.getPosition() - islandPos;
			block3d.renderOffset = Vec3f(0.0f, GetIslandWaveVisualY(island, worldOffset), 0.0f);
			block3d.renderRotation = GetIslandWaveVisualRotation(island);
		}

		SetDisplay( block, color_white, RenderStyle::additive, 560.0f );
		block.set_bool("red",false);
	}
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("place"))
    {
        CBlob@ centerBlock = getBlobByNetworkID( params.read_netid() );
        CBlob@ refBlock = getBlobByNetworkID( params.read_netid() );
        if (centerBlock is null || refBlock is null)
        {
            warn("place cmd: centerBlock not found");
            return;
        }

        Vec2f pos_offset = params.read_Vec2f();
		const f32 placementX = params.read_f32();
		const f32 placementY = params.read_f32();
		const f32 placementZ = params.read_f32();
        Vec3f placementPoint = Vec3f(placementX, placementY, placementZ);
        const f32 target_angle = params.read_f32();
        const f32 island_angle = params.read_f32();

        Island@ island = getIsland( centerBlock.getShape().getVars().customData );
        if (island is null)
        {
            warn("place cmd: island not found");
            return;
        }
		
		Vec2f islandPos = centerBlock.getPosition();
		f32 islandAngle = centerBlock.getAngleDegrees();
		f32 angleDelta = islandAngle - island_angle;//to account for island angle lag

		const Vec2f[] Shape =  {
					        Vec2f(-8.0, -8.0),
							Vec2f( 8.0, -8.0),
							Vec2f( 8.0, 8.0),
							Vec2f(-8.0, 8.0)
					      };
		
		bool overlappingIsland = false;
        CBlob@[]@ blocks;
        if (this.get( "blocks", @blocks ) && blocks.size() > 0)                 
        {	
			PositionBlocks( @blocks, islandPos + pos_offset.RotateBy( angleDelta ), placementPoint, target_angle, centerBlock, refBlock );

			if ( true )
			{
				int iColor = centerBlock.getShape().getVars().customData;
				for (uint i = 0; i < blocks.length; ++i)
				{
					CBlob@ b = blocks[i];
					if (b !is null)
					{						
						const int blockType = b.getSprite().getFrame();
						b.set_u16("ownerID", 0);//so it wont add to owner blocks
						f32 z = 510.0f;
						if ( blockType == 0 )	z = 509.0f;//platforms
						else if ( b.hasTag( "weapon" ) )	z = 511.0f;//weaps
						SetDisplay( b, color_white, RenderStyle::normal, z );
						b.set_bool("red",false);
						if ( !getNet().isServer() )//add it locally till a sync
						{
							IslandBlock isle_block;
							isle_block.blobID = b.getNetworkID();
							isle_block.offset = b.getPosition() - islandPos;
							isle_block.offset.RotateBy( -islandAngle );
							isle_block.angle_offset = b.getAngleDegrees() - islandAngle;
							b.getShape().getVars().customData = iColor;
							island.blocks.push_back(isle_block);							

						const bool solid = Block::isSolid(blockType);
						SAT_Shape sat_shape(b, Shape, V2toV3(b.getPosition()), false, 0, b.getMass(), solid, iColor);
						b.set("SAT_Info", @sat_shape);	

						} else
							b.getShape().getVars().customData = 0; // push on island 
										
						b.set_u32( "placedTime", getGameTime() ); 
					}
					else{
						warn("place cmd: blob not found");
					}
				}
				this.set_u32( "placedTime", getGameTime() );
			}
			else
			{
				warn("place cmd: blocks overlapping, cannot place");
				this.getSprite().PlaySound("Denied.ogg");
				return;	
			}
        }
        else
        {
            warn("place cmd: no blocks");
            return;
        }
		
		blocks.clear();//releases the blocks (they are placed)
		getRules().set_bool("dirty islands", true);
		directionalSoundPlay( "build_ladder.ogg", this.getPosition() );
    }
}

void SetDisplay( CBlob@ blob, SColor color, RenderStyle::Style style, f32 Z=-10000)
{
    CSprite@ sprite = blob.getSprite();
    sprite.asLayer().SetColor( color );
    sprite.asLayer().setRenderStyle( style );
    if (Z>-10000){
        sprite.SetZ(Z);
    }
}
