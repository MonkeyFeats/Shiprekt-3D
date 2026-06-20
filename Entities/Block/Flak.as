#include "BlockCommon.as"
#include "IslandsCommon.as"
#include "AccurateSoundPlay.as"
#include "SAT_Shapes.as"
#include "Particle3D.as"
#include "CollisionDebug.as"
//#include "BoundingShapes.as";

const f32 PROJECTILE_SPEED = 9.0f;
const f32 PROJECTILE_SPREAD = 2.25;
const int FIRE_RATE = 60;
const f32 PROJECTILE_RANGE = 450.0f;
const f32 CLONE_RADIUS = 20.0f;
const u8 REFILL_AMMOUNT = 10;//every second
const f32 AUTO_RADIUS = 400.0f;

Random _shotspreadrandom(0x11598); //clientside
const string FLAK_RECOIL_TIME = "flak recoil time";
const f32 FLAK_RECOIL_DISTANCE = 3.5f;
const f32 FLAK_RECOIL_KICK_TICKS = 2.0f;
const f32 FLAK_RECOIL_RETURN_TICKS = 7.0f;

void onInit( CBlob@ this )
{
	this.Tag("flak");
	this.Tag("weapon");
	this.Tag("usesAmmo");
	this.addCommandID("fire");
	this.addCommandID("clear attached");
	
	if ( getNet().isServer() )
	{	
		u16 maxAmmo = 30;
		this.set_u16( "ammo", maxAmmo );
		this.set_u16( "maxAmmo", maxAmmo );
		this.set( "ammo", maxAmmo );
		this.set( "maxAmmo", maxAmmo );

		this.Sync("ammo", true );
		this.Sync("maxAmmo", true );
	}
	
	this.set_u32("fire time", 0);
	this.set_f32("angle", this.getAngleDegrees());
	this.set_u16("parentID", 0);
	this.set_u16("childID", 0);
	
	if ( getNet().isServer() )
	{
		this.set_bool( "seatEnabled", true );
		this.Sync( "seatEnabled", true );
	}
	
	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer( "weapon", 16, 16 );
    if (layer !is null)
    {
    	layer.SetRelativeZ(2);
    	layer.SetLighting( false );
     	Animation@ anim = layer.addAnimation( "fire", 15, false );
        anim.AddFrame(1);
        anim.AddFrame(2);
        layer.SetAnimation("fire");    	
    }

    //if (getNet().isServer())
	{
		//Blob3D blob3d(this, Vec3f(this.getPosition().x, 0, this.getPosition().y), 6, 2.0f);
		//if ( blob3d !is null )
		//{	
		//	@blob3d.shape = BoundingBox( Vec3f(-8.0, -1.0, -8.0), Vec3f(8.0, 0.0, 8.0));
		//	//blob3d.shape.ownerBlob = blob3d;
		//	blob3d.shape.SetStatic(false);
		//	blob3d.shape.setPosition(Vec3f(this.getPosition().x, 0, this.getPosition().y));
//
		//	this.set("blob3d", @blob3d);
		//	//blob3d.shape.ownerBlob = @blob3d;
		//}
	}

}

void onRender(CSprite@ this)
{
	if (!IsCollisionDebugEnabled())
		return;

	SAT_Shape@ sat_shape;
	if (this.getBlob().get("SAT_Info", @sat_shape))
 	sat_shape.Render();	
}


void onTick( CBlob@ this )
{
	if ( this.getShape().getVars().customData <= 0 )
		return;
	
	u32 gameTime = getGameTime();
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	u16 thisID = this.getNetworkID();
	if ( occupier !is null )
	{
		u32 gameTime = getGameTime();
		this.set_u16( "parentID", 0 );
		Manual( this, occupier );
		
		CBlob@ childFlak = getBlobByNetworkID( this.get_u16( "childID" ) );
		if ( childFlak !is null )
		{
			if ( !childFlak.hasAttached() && childFlak.getDistanceTo( this ) < CLONE_RADIUS )
				Clone( childFlak, this, occupier );
			else
				this.set_u16( "childID", 0 );
		}
		else if ( gameTime % 20 == 0 )
		{
			@childFlak = findFlakChild( this );
			if ( childFlak !is null )
			{
				this.set_u16( "childID", childFlak.getNetworkID() );
				childFlak.set_u16( "parentID", thisID );
			}
		}
		
		//owned repulsors managing
		if ( occupier.isKeyJustPressed( key_action3 ) )
		{
			CPlayer@ player = occupier.getPlayer();
			if ( player !is null )
			{
				string occupierName = player.getUsername();
				CBlob@[] repulsors;	
				getBlobsByTag( "repulsor", @repulsors );
				for (uint b_iter = 0; b_iter < repulsors.length; ++b_iter)
				{
					CBlob@ r = repulsors[b_iter];
					if ( r.getShape().getVars().customData > 0 && r.isOnScreen() && !r.hasTag("activated" ) && r.get_string( "playerOwner" ) == occupierName )
					{
						CButton@ button = occupier.CreateGenericButton( 8, Vec2f(0.0f, 0.0f), r, r.getCommandID("chainReaction"), "Activate" );
							
						if ( button !is null )
							button.enableRadius = 999.0f;
					}
				}
			}
		}
		else if ( occupier.isKeyJustReleased( key_action3 ) )
			occupier.ClearButtons();
	}
	else if ( this.get_u16( "childID" ) != 0 )//free child; parent
	{
		CBlob@ childFlak = getBlobByNetworkID( this.get_u16( "childID" ) );
		if ( childFlak !is null  )
			childFlak.set_u16( "parentID", 0 );
			
		this.set_u16( "childID", 0 );
	}
	else
	{
		Auto( this );
	}
	
	//ammo reload when docked
	if ( getNet().isServer() && ( gameTime + thisID * 33 ) % 30 == 0 )//every 1 sec
	{
		Island@ isle = getIsland( this.getShape().getVars().customData );
		if ( isle !is null )
		{
			u16 ammo, maxAmmo;
			this.get( "ammo", ammo );
			this.get( "maxAmmo", maxAmmo );

			if ( isle.isMothership || isle.isStation )
			{
				//reload ammo
				if ( ammo < maxAmmo )
				{
					this.Sync( "ammo", true );//workaround for sync policy
					ammo = Maths::Min( maxAmmo, ammo + REFILL_AMMOUNT );
					this.set( "ammo", ammo );
					this.set_u16( "ammo", ammo );
					this.Sync( "ammo", true );
				}
			}
			
			if ( ammo == 0 )
			{
				this.set_u16( "ammo", ammo );
				this.Sync( "ammo", true );
			}
		}
	}

	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d)) { return; }

	UpdateFlakBlob3D(this, blob3d);
}

void UpdateFlakBlob3D(CBlob@ this, Blob3D@ blob3d)
{
	if (!getNet().isClient() || blob3d is null)
		return;

	Blob3D@ topper = blob3d.getChild("flaktopper");
	if (topper is null)
		return;

	const f32 yaw = this.get_f32("angle") - this.getAngleDegrees();
	topper.setLocalMayaRotation(Vec3f(0.0f, yaw, 0.0f));

	Blob3D@ barrel = topper.getChild("FlakBarrel");
	if (barrel is null)
		return;

	f32 recoil = 0.0f;
	if (this.exists(FLAK_RECOIL_TIME))
	{
		const f32 age = Maths::Max(0.0f, float(getGameTime() - this.get_u32(FLAK_RECOIL_TIME)));
		if (age <= FLAK_RECOIL_KICK_TICKS)
		{
			recoil = FLAK_RECOIL_DISTANCE;
		}
		else
		{
			const f32 returnAge = age - FLAK_RECOIL_KICK_TICKS;
			if (returnAge < FLAK_RECOIL_RETURN_TICKS)
			{
				recoil = FLAK_RECOIL_DISTANCE * (1.0f - returnAge / FLAK_RECOIL_RETURN_TICKS);
			}
		}
	}

	barrel.LocalTransform.Position = Vec3f(-recoil, 0.0f, 0.0f);
}

void Manual( CBlob@ this, CBlob@ controller )
{
	Vec2f aimpos = controller.get_Vec2f("aim_pos");
	Vec2f pos = this.getPosition();
	Vec2f aimVec = aimpos - pos;	
	CPlayer@ player = controller.getPlayer();

	// fire
	if ( controller.isMyPlayer() && controller.isKeyPressed( key_action1 ) && canShootManual( this, true ) && isClearShot( this, aimVec ) )
	{
		Island@ isle = getIsland( this.getShape().getVars().customData );
		u16 netID = 0;
		if ( isle !is null && player !is null && ( !isle.isMothership || isle.owner != player.getUsername() ) )
			netID = controller.getNetworkID();
		Fire( this, aimVec, netID );
	}
	
	// rotate turret

	//this.set_f32("angle", controller.get_f32("dir_x"));
	Rotate( this, aimVec );
	//aimVec.y *= -1;
	//controller.setAngleDegrees( aimVec.Angle() );
}

void Auto( CBlob@ this )
{
	//f32 ang = this.get_f32("angle");
	//if(aimVector.getAngleDegrees() > ang)
	//ang--;
	//else if (aimVector.getAngleDegrees() < ang)
	//ang++;
	//this.set_f32("angle", ang);

	if ( ( getGameTime() + this.getNetworkID() * 33 ) % 20 != 0 )
		return;
		
	CBlob@[] blobsInRadius;
	Vec2f pos = this.getPosition();
	int thisColor = this.getShape().getVars().customData;
	f32 minDistance = 9999999.9f;
	bool shoot = false;
	Vec2f shootVec = Vec2f(0, 0);

	if ( getNet().isServer() && this.getMap().getBlobsInRadius( this.getPosition(), AUTO_RADIUS, @blobsInRadius ) )
	{
		for ( uint i = 0; i < blobsInRadius.length; i++ )
		{
			CBlob @b = blobsInRadius[i];
			if ( b.getTeamNum() != this.getTeamNum() 
					&& ( b.getName() == "human"|| b.hasTag( "mothership" ) ||  b.hasTag( "rocket" ) || ( b.hasTag( "weapon" ) && b.getShape().getVars().customData > 0 ) ) )
			{
				Vec2f bPos = b.getPosition();
				
				Island@ targetIsland;
				if ( b.getName() == "block" )
					@targetIsland = getIsland( b.getShape().getVars().customData );
				else
				{
					@targetIsland = getIsland(b);
					if ( b.isAttached() )
					{
						AttachmentPoint@ humanAttach = b.getAttachmentPoint(0);
						CBlob@ seat = humanAttach.getOccupied();
						if ( seat !is null )
						{
							SAT_Shape@ sat_shape;
							if (!this.get("SAT_Info", @sat_shape)) { return; }
							sat_shape.Pos.xz() = seat.getPosition();
							//bPos = seat.getPosition();
						}
					}
				}
				
				Vec2f aimVec = bPos - pos;
				f32 distance = aimVec.Length();

				int bColor = 0;
				if ( targetIsland !is null )
				{
					bColor = b.getShape().getVars().customData;
					
					//prediction compensation
					//aimVec += targetIsland.vel * distance /PROJECTILE_SPEED * 0.9f;//poor man's kinematics
					aimVec += targetIsland.vel * Maths::FastSqrt( distance ) * 13.0f/PROJECTILE_SPEED;
					distance = aimVec.Length();//account for compensation
				}
				else if ( b.hasTag( "rocket" ) )
				{
					aimVec += b.getVelocity() * distance /PROJECTILE_SPEED * 0.9f;//poor man's kinematics
					distance = aimVec.Length();//account for compensation
				}
				
				bool merged = bColor != 0 && thisColor == bColor;
				
				if ( b.getName() == "human" )
					distance += 80.0f;//humans have lower priority
				
				if ( distance < minDistance && isClearShot( this, aimVec, merged ) )
				{
					shoot = true;					
					shootVec = aimVec;
					Rotate( this, aimVec ); 
					minDistance = distance;
				}
			}
		}
	}
	
	if ( shoot )
	{
		if ( getNet().isServer() && canShootAuto( this ) )
		{
			u16 netID = 0;
			Island@ island = getIsland( this.getShape().getVars().customData );
			if ( island !is null )
			{
				CPlayer@ islandOwner = getPlayerByUsername( island.owner );
				if ( islandOwner !is null )
				{
					CBlob@ pBlob = islandOwner.getBlob();
					if ( pBlob !is null )
						netID = pBlob.getNetworkID();
				}
			}
			Fire( this, shootVec, netID );
		}
	}
}

void Clone( CBlob@ this, CBlob@ parent, CBlob@ controller )
{
	Vec2f aimpos = controller.get_Vec2f("aim_pos");
	Vec2f pos = parent.getPosition();
	Vec2f aimVec = aimpos - pos;	
	CPlayer@ player = controller.getPlayer();
	// fire
	if ( isClearShot( this, aimVec ) )
	{
		//Rotate( this, aimVec );
		if ( controller.isMyPlayer() && controller.isKeyPressed( key_action1 ) && canShootManual( this, true ) && ( getGameTime() - parent.get_u32("fire time") == FIRE_RATE/2 ) )
		{
			Island@ isle = getIsland( this.getShape().getVars().customData );
			u16 netID = 0;
			if ( isle !is null && player !is null && ( !isle.isMothership || isle.owner != player.getUsername() ) )
				netID = controller.getNetworkID();
			Fire( this, aimVec, netID );
		}
	}
	else if ( getGameTime() - this.get_u32("fire time") > 50 )//free it so it tries to find another
	{
		parent.set_u16( "childID", 0 );
		this.set_u16( "parentID", 0 );
	}
}

CBlob@ findFlakChild( CBlob@ this )
{
	int color = this.getShape().getVars().customData;
	CBlob@[] flak;
	CBlob@[] radBlobs;
	getMap().getBlobsInRadius( this.getPosition(), CLONE_RADIUS, @radBlobs );
	for ( uint i = 0; i < radBlobs.length; i++ )
	{
		CBlob@ b = radBlobs[i];
		if ( b.hasTag( "flak" ) && !b.hasAttached() && b.get_u16( "parentID" ) == 0 && color == b.getShape().getVars().customData )
			flak.push_back(b);
	}
	
	if ( flak.length > 0 )
		return flak[ getGameTime() % flak.length ];
		
	return null;
}

bool canShootAuto( CBlob@ this, bool manual = false )
{
	return this.get_u32("fire time") + FIRE_RATE < getGameTime();
}

bool canShootManual( CBlob@ this, bool manual = false )
{
	return this.get_u32("fire time") + FIRE_RATE/2 < getGameTime();
}

bool isClearShot( CBlob@ this, Vec2f aimVec, bool targetMerged = false )
{
	Vec2f pos = this.getPosition();
	const f32 distanceToTarget = Maths::Max( aimVec.Length(), 80.0f );
	HitInfo@[] hitInfos;
	CMap@ map = getMap();
	
	Vec2f offset = aimVec;
	offset.Normalize();
	offset *= 7.0f;

	map.getHitInfosFromRay( pos + offset.RotateBy(30), -aimVec.Angle(), distanceToTarget, this, @hitInfos );
	map.getHitInfosFromRay( pos + offset.RotateBy(-60), -aimVec.Angle(), distanceToTarget, this, @hitInfos );
	if ( hitInfos.length > 0 )
	{
		//HitInfo objects are sorted, first come closest hits
		for ( uint i = 0; i < hitInfos.length; i++ )
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;	  
			if( b is null || b is this ) continue;

			int thisColor = this.getShape().getVars().customData;
			int bColor = b.getShape().getVars().customData;
			bool sameIsland = bColor != 0 && thisColor == bColor;
			
			const int blockType = b.getSprite().getFrame();

			bool canShootSelf = targetMerged && hi.distance > distanceToTarget * 0.7f;
			
			bool isOwnCore = Block::isCore( blockType ) && this.getTeamNum() == b.getTeamNum();
		
			//if ( sameIsland || targetMerged ) print ( "" + ( sameIsland ? "sameisland; " : "" ) + ( targetMerged ? "targetMerged; " : "" ) );
			
			if ( b.getName() == "block" && b.getShape().getVars().customData > 0 && ( Block::isSolid( blockType ) || isOwnCore || b.hasTag("weapon") ) && sameIsland && !canShootSelf )
			{
				//print ( "not clear " + ( b.getName() == "block" ? " (block) " : "" ) + ( !canShootSelf ? "!canShootSelf; " : "" )  );
				return false;
			}
		}
	}
	
	Vec2f solidPos;
	if ( map.rayCastSolid(pos, pos + aimVec, solidPos) )
	{
		AttachmentPoint@ seat = this.getAttachmentPoint(0);
		CBlob@ occupier = seat.getOccupied();
		
		if ( occupier is null)
			return false;
	}

	return true;
}

void Fire( CBlob@ this, Vec2f aimVector, const u16 netid )
{
	const f32 aimdist = Maths::Min( aimVector.Normalize(), PROJECTILE_RANGE );

	Vec2f offset(_shotspreadrandom.NextFloat() * PROJECTILE_SPREAD,0);
	offset.RotateBy(_shotspreadrandom.NextFloat() * 360.0f, Vec2f());

	Vec2f _vel = (aimVector * PROJECTILE_SPEED) + offset;

	f32 _lifetime = Maths::Max( 0.05f + aimdist/PROJECTILE_SPEED/32.0f, 0.25f);

	CBitStream params;
	params.write_netid( netid );
	params.write_Vec2f( _vel );
	params.write_f32( _lifetime );
	this.SendCommand( this.getCommandID("fire"), params );
	this.set_u32("fire time", getGameTime());
}

void Rotate( CBlob@ this, Vec2f aimVector )
{
	this.set_f32("angle", -aimVector.getAngleDegrees());

	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
	if(layer !is null)
	{
		layer.ResetTransform();
		layer.RotateBy( -aimVector.getAngleDegrees() - this.getAngleDegrees(), Vec2f_zero );
	}
}

void GetButtonsFor( CBlob@ this, CBlob@ caller )
{
	// Flaks are controlled by the 3D center-screen raycast prompt in Human.as.
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("fire"))
    {
		CBlob@ caller = getBlobByNetworkID( params.read_netid() );
		Vec2f pos = this.getPosition();
		bool isServer = getNet().isServer();
		//ammo
		u16 ammo = this.get_u16( "ammo" );
		if ( isServer )
			this.get( "ammo", ammo );
		
		if ( ammo == 0 )
		{
			directionalSoundPlay( "LoadingTick1", pos, 1.0f );
			return;
		}
		
		ammo--;
		this.set_u16( "ammo", ammo );
		if ( isServer )
			this.set( "ammo", ammo );

		Vec2f velocity = params.read_Vec2f();
		Vec2f aimVector = velocity;		aimVector.Normalize();
		const f32 time = params.read_f32();

		if ( isServer )
		{
            CBlob@ bullet = server_CreateBlob( "flakbullet", this.getTeamNum(), pos + aimVector*9 );
            if (bullet !is null)
            {
            	if ( caller !is null )
                	bullet.SetDamageOwnerPlayer( caller.getPlayer() );

                bullet.setVelocity( velocity );
                bullet.server_SetTimeToDie( time );
				bullet.set_u32( "color", this.getShape().getVars().customData );
				bullet.setAngleDegrees( -aimVector.Angle() );
            }
    	}
		
		shotParticles(this, pos + aimVector*9, velocity.Angle());
		directionalSoundPlay( "FlakFire.ogg", pos, 0.50f );
		this.set_u32(FLAK_RECOIL_TIME, getGameTime());
		
		CSpriteLayer@ layer = this.getSprite().getSpriteLayer( "weapon" );
		if ( layer !is null )
			layer.animation.SetFrameIndex(0);
    }
	else if (cmd == this.getCommandID("clear attached"))
	{
		AttachmentPoint@ seat = this.getAttachmentPoint(0);
		CBlob@ crewmate = seat.getOccupied();
		if ( crewmate !is null )
			crewmate.SendCommand( crewmate.getCommandID("get out") );
	}
}

Random _shotrandom(0x15125); //clientside
void shotParticles(CBlob@ this, Vec2f pos, float angle)
{
	EmitMuzzleParticles3D(this, pos, angle, 1.0f);
}
