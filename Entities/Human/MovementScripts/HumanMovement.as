// Shiprekt3D Movement

//#include "HumanCommon.as"
#include "HumanMovementCommon.as"
#include "FallDamageCommon.as"
#include "IslandsCommon.as"
//#include "BlockCommon.as"
#include "SAT_Shapes.as"
#include "World.as"
#include "HumanGrounding.as"
#include "OceanWave.as"
#include "Particle3D.as"
#include "TileCommon.as"

const f32 HUMAN_WATER_SURFACE_DEADBAND = 5.2f;
const f32 HUMAN_WATER_EXIT_HEIGHT = 2.0f;
const f32 HUMAN_WATER_JUMP_DEPTH = 18.0f;
const f32 HUMAN_WATER_JUMP_FORCE = 90.0f;
const f32 HUMAN_WATER_JUMP_VELOCITY = 9.0f;
const f32 HUMAN_WATER_JUMP_SURFACE_CLEARANCE = 0.5f;
const f32 HUMAN_WATER_SURFACE_FOLLOW_FORCE = 10.0f;
const f32 HUMAN_JUMP_HOLD_FORCE = 34.0f;
const s32 HUMAN_JUMP_HOLD_TICKS = 30;
const string HUMAN_JUMP_STATE = "human jump state";
const string HUMAN_WAS_IN_WATER = "human was in water";
const string HUMAN_LAST_FOOTSTEP_PARTICLE_TIME = "human last footstep particle time";

void onInit(CMovement@ this)
{
	//Movement Vars
	{
		HumanMoveVars moveVars;
		//walking vars
		moveVars.walkSpeed = 8.6f;
		moveVars.walkSpeedInAir = 0.4f;
		//jumping vars
		moveVars.jumpVel = 300.0f;
		//swimming
		moveVars.swimspeed = 0.2f;
		moveVars.floatForce = 18.0f;
		moveVars.swimDownForce = 28.0f;
		//stopping forces
		moveVars.stoppingForce = 0.80f; //function of mass
		moveVars.stoppingForceAir = 0.30f; //function of mass
		
		this.getBlob().set("moveVars", moveVars);
		this.getBlob().getShape().getVars().waterDragScale = 30.0f;
		this.getBlob().getShape().getConsts().collideWhenAttached = false;
	}

	this.getCurrentScript().removeIfTag = "dead";
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getBlob().set_s32(HUMAN_JUMP_STATE, 0);
	this.getBlob().set_bool(HUMAN_WAS_IN_WATER, false);
	this.getBlob().set_u32(HUMAN_LAST_FOOTSTEP_PARTICLE_TIME, 0);
}

void onTick(CMovement@ this)
{
	CBlob@ blob = this.getBlob();
	Blob3D@ blob3d; if (!blob.get("blob3d", @blob3d)) { return; }	
	RigidBody@ rb = blob3d.rb; if (rb is null) { return; }
	BoundingShape@ shape = blob3d.shape; if (shape is null) { return; }
	HumanMoveVars@ moveVars; if (!blob.get("moveVars", @moveVars)) { return; }

	if (blob.getTickSinceCreated() < 10) return;		

	const bool is_client = getNet().isClient();
	if (is_client && !getNet().isServer() && !blob.isMyPlayer())
	{
		return;
	}

	const bool left		= blob.isKeyPressed(key_left);
	const bool right	= blob.isKeyPressed(key_right);
	const bool up		= blob.isKeyPressed(key_up);
	const bool down		= blob.isKeyPressed(key_down);
	const bool spacebar	= blob.isKeyJustPressed(key_action3);
	const bool jumpHeld	= blob.isKeyPressed(key_action3);
	const bool localControls = is_client && blob.isMyPlayer();
	const bool serverControls = getNet().isServer();
	const bool swimDown = localControls && getControls().isKeyPressed( KEY_KEY_C );
	const u32 time = getGameTime();

	Vec3f Pos = blob3d.getPosition();
	const bool grounded = AreHumanFeetGrounded(blob, blob3d);
	shape.onGround = grounded;
	blob.set_bool("onGround", grounded);
	blob.getShape().getVars().onground = grounded;

    CControls@ c = null;
    Driver@ d = null;
	if (localControls)
	{
		@c = getControls();
		@d = getDriver();
	}

	Vec3f moveForce;
	s32 jumpState = blob.get_s32(HUMAN_JUMP_STATE);
	const f32 waterSurfaceY = GetOceanWaterHeight(Pos);
	const f32 waterDepth = waterSurfaceY - Pos.y;
	const bool inwater = waterDepth >= -HUMAN_WATER_EXIT_HEIGHT;
	shape.inWater = inwater;
	const bool underWaterSurface = inwater && waterDepth > HUMAN_WATER_SURFACE_DEADBAND;
	const bool atWaterSurface = inwater && waterDepth >= -HUMAN_WATER_SURFACE_DEADBAND && waterDepth <= HUMAN_WATER_JUMP_DEPTH;
	const bool canControl = serverControls || (localControls && c !is null && d !is null && isWindowActive() && isWindowFocused() && Menu::getMainMenu() is null && !block_menu && !getHUD().hasButtons() && !blob.get_bool("build menu open"));
	const bool wasInWater = blob.get_bool(HUMAN_WAS_IN_WATER);
	if (is_client && inwater && !wasInWater && rb.getVelocity().y < -3.5f)
	{
		EmitWaterSplashParticles3D(Vec3f(Pos.x, waterSurfaceY, Pos.z), rb.getVelocity(), Maths::Clamp(Maths::Abs(rb.getVelocity().y) * 0.16f, 0.65f, 1.45f));
	}
	blob.set_bool(HUMAN_WAS_IN_WATER, inwater);

    if (canControl)
    {
		if (localControls)
		{
			Vec2f ScrMid = d.getScreenCenterPos();//Vec2f(float(getScreenWidth()) / 2.0f, float(getScreenHeight()) / 2.0f);
			Vec2f dir = (c.getMouseScreenPos() - ScrMid);

			blob3d.transform.Orientation.x -= dir.x*0.15;
			if(blob3d.transform.Orientation.x < 0) blob3d.transform.Orientation.x += 360;
			blob3d.transform.Orientation.x = blob3d.transform.Orientation.x % 360;
			blob3d.transform.Orientation.y = Maths::Clamp(blob3d.transform.Orientation.y+(dir.y*0.15), -60,60); // -44 is a weird way to say 90, but ok? ToDo: fix this with stuff below and camera3d!
		}
        // pitch = Maths::Clamp(pitch - dir.y * 0.15f, -85.0f, 85.0f);
		// yaw += dir.x * 0.15f;
		// Quaternion q;
		// q.SetFromYawPitchRoll(yaw, pitch, 0);
		// transform.Orientation = q;
        
		//if (onship)
		//{
		//	moveForce.y += 1.6; //swim up
		//}	
		//else if (inwater)
		//{
		//	if (spacebar && !onwater)
		//	{
		//		moveForce.y += 1.6; //swim up
		//	}
		//	else if (shift)
		//	{
		//		moveForce.y -= 1.6f; //swim down
		//	}
		//	else
		//	{
		//		moveForce.y += 0.2; //float up
		//	}
//
		//	bool BoatAbove = (Pos.y > -20.0 && Pos.y < -18.0);
		//	if (BoatAbove)
		//	{
		//		moveForce.y = Maths::Min(Vel.y, 0); //stop going up
		//	}
		//}

		//else 
		//if (inAir) // falling
		{
			//if (TerrainHeight < -2.0f) //water plane below
			//{
			//	moveForce.y -= Maths::Max(Maths::Abs(Pos.y - -2.0f), 0.2f);
			//}
			//else if (moveForce.y < 0)
			//{
			//	moveForce.y -= Maths::Max(Maths::Abs(Pos.y - TerrainHeight), 0.2f);
			//}
			//else 
			//moveForce.y -= 0.981f*2;
		}

		// move
		Vec3f moveDir;
		if (up)		  moveDir.z += 1.0f;
		if (down)	  moveDir.z -= 1.0f;
		if (left)	  moveDir.x -= 1.0f;
		if (right)	  moveDir.x += 1.0f;

		if (moveDir.LengthSquared() > 0.0f)
		{
			moveForce += moveDir.Normalize() * moveVars.walkSpeed;
		}
		//if (shift)	  moveForce.y = -moveVars.walkSpeed;

		//	//if ( blob.wasOnGround() && time - blob.get_u32( "lastSplash" ) > 45 )
		//	//{
		//	//	//directionalSoundPlay( "SplashFast", pos );
		//	//	blob.set_u32( "lastSplash", time );
		//	//}
		//}
		
		//jumping
		if (grounded)
		{			
		    if (spacebar) 
		    {
				moveForce.y += moveVars.jumpVel;
				jumpState = HUMAN_JUMP_HOLD_TICKS;
				blob.set_u32(HUMAN_LAST_JUMP_TIME, getGameTime());
				shape.onGround = false;
				blob.set_bool("onGround", false);
				blob.getShape().getVars().onground = false;

				if (is_client)
				{	
					blob.getSprite().PlayRandomSound("/EarthJump");
				}
			}
			else
			{
				if (moveForce.Length() > 0.3f && is_client)
				{	
					if (time % (10) == 0)
					{						
						const u16 tileType = getMap().getTile(Pos.xz()).type;
						const bool shallowFootstep = tileType >= CMap::water_1 && tileType <= CMap::water_4;
						if (tileType == CMap::sand || shallowFootstep)
						{
							EmitFootstepParticles3D(Vec3f(Pos.x, shallowFootstep ? waterSurfaceY : 0.25f, Pos.z), shallowFootstep);
						}
						{
							blob.getSprite().PlayRandomSound("/EarthStep", 0.6f, 0.75f );
						} 
					}
				}
			}
		}
		else if (atWaterSurface && spacebar)
		{
			moveForce.y += HUMAN_WATER_JUMP_FORCE;
			jumpState = 0;
			blob.set_u32(HUMAN_LAST_JUMP_TIME, getGameTime());
			shape.inWater = false;
			Vec3f velocity = rb.getVelocity();
			if (velocity.y < HUMAN_WATER_JUMP_VELOCITY)
			{
				velocity.y = HUMAN_WATER_JUMP_VELOCITY;
				rb.setSolvedVelocity(velocity);
			}

			if (blob3d.transform.Position.y < waterSurfaceY + HUMAN_WATER_JUMP_SURFACE_CLEARANCE)
			{
				blob3d.transform.Position.y = waterSurfaceY + HUMAN_WATER_JUMP_SURFACE_CLEARANCE;
				shape.setPosition(blob3d.transform.Position);
			}
		}
		else if (jumpState > 0 && jumpHeld)
		{
			moveForce.y += HUMAN_JUMP_HOLD_FORCE;
			jumpState--;
		}
		else
		{
			jumpState = 0;
		}

		if (is_client && inwater)
		{
			//if (spacebar)
			//{
			//	moveForce.y += 0.8;
			//}
			blob.getSprite().SetEmitSound("/WaterRunning.ogg");
			blob.getSprite().SetEmitSoundSpeed(0.1f);
			blob.getSprite().SetEmitSoundVolume(0.4f);
			blob.getSprite().SetEmitSoundPaused(false);
//
			if (time % 45 == 0)
			{
				blob.getSprite().PlayRandomSound("/WaterBubble", 0.6f, 0.85f );
			}

			if (atWaterSurface && rb.getVelocity().xz().LengthSquared() > 1.0f && time - blob.get_u32(HUMAN_LAST_FOOTSTEP_PARTICLE_TIME) > 12)
			{
				blob.set_u32(HUMAN_LAST_FOOTSTEP_PARTICLE_TIME, time);
				EmitWakeParticles3D(Vec3f(Pos.x, waterSurfaceY, Pos.z), rb.getVelocity() * -1.0f, 0.45f);
			}
//
			if (time % 160 == 0)
			{
				blob.getSprite().PlayRandomSound("/Gurgle", 0.8f, 0.85f );
			}
		}
		//else if (shape.hitWater)
		//{			
		//	blob.getSprite().PlayRandomSound("/SplashSlow");
		//}
		else
		{
			blob.getSprite().SetEmitSoundPaused(true);
		}
	}

	if (inwater)
	{
		if (canControl && swimDown)
		{
			moveForce.y -= moveVars.swimDownForce;
		}
		else if (underWaterSurface)
		{
			const f32 depth = Maths::Clamp(waterDepth, 0.0f, 4.0f);
			moveForce.y += moveVars.floatForce + depth * 4.0f;
		}
		else if (atWaterSurface)
		{
			moveForce.y += Maths::Clamp(waterDepth, -HUMAN_WATER_SURFACE_DEADBAND, HUMAN_WATER_JUMP_DEPTH) * HUMAN_WATER_SURFACE_FOLLOW_FORCE;
		}
	}

	//canmove check
	//if ( !getRules().get_bool( "whirlpool" ))
	{
		moveForce.xzRotateBy(blob3d.transform.Orientation.x);
		//shape.setAngleDegreesXZ(blob3d.look_dir.x );
		//shape.addForce(moveForce);
	}
		
	blob.set_s32(HUMAN_JUMP_STATE, jumpState);
	rb.addForce(moveForce * rb.getMass());
}


