#include "BlockCommon.as"
#include "IslandsCommon.as"
#include "WaterEffects.as"
#include "HarpoonForceCommon.as"
#include "ParticleSparks.as"
#include "Blob3D.as"
#include "Particle3D.as"

const int FIRE_RATE = 45;
const f32 harpoon_grapple_length = 300.0f;
const f32 harpoon_grapple_slack = 16.0f;
const f32 harpoon_grapple_throw_speed = 20.0f;
const f32 harpoon_grapple_force = 2.0f;
const f32 harpoon_grapple_accel_limit = 1.5f;
const f32 harpoon_grapple_stiffness = 0.1f;
const u8 HARPOON_ROPE_TRAIL_POINTS = 14;
const Vec3f HARPOON_LOADED_HEAD_POSITION(4.0f, 11.0f, 0.0f);
const string HARPOON_HEAD_CHILD = "harpoon_projectile_head";
const string HARPOON_GUN_CHILD = "harpoon_gun";
const string HARPOON_LOADED_HEAD_CHILD = "harpoon_loaded_head";
const string HARPOON_ROPE_PARTICLE = "harpoon_rope_particle";

Random _shotspreadrandom(0x11598); //clientside

const string grapple_sync_cmd = "grapple sync";

shared class HarpoonInfo
{
	bool grappling;
	bool reeling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	HarpoonInfo()
	{
		grappling = false;
		reeling = false;
	}
};

void onInit( CBlob@ this )
{
	this.Tag("harpoon");
	this.Tag("weapon");
	this.set_f32("angle", this.getAngleDegrees());

	if (getNet().isServer())
	{
		this.set_bool("seatEnabled", true);
		this.Sync("seatEnabled", true);
	}

	CSprite@ sprite = this.getSprite();
	
	LoadSprites( sprite );
	
    CSpriteLayer@ layer = sprite.addSpriteLayer( "harpoon", 16, 16 );
    if (layer !is null)
    {
    	layer.SetRelativeZ(2);
    	layer.SetLighting( false );
     	Animation@ animFired = layer.addAnimation( "fired", FIRE_RATE, false );
        animFired.AddFrame(2);

		Animation@ animSet = layer.addAnimation( "set", FIRE_RATE, false );
        animSet.AddFrame(1);
        layer.SetAnimation("set");
    }
	
	HarpoonInfo harpoon;	  
	this.set("harpoonInfo", @harpoon);
	
	this.addCommandID(grapple_sync_cmd);
	this.addCommandID("unhook");
	this.addCommandID("clear attached");
}

void onTick( CBlob@ this )
{	
	if (this.getShape().getVars().customData <= 0)
	{
		ClearHarpoonVisuals3D(this);
		return;
	}
	
	HarpoonInfo@ harpoon;
	if (!this.get( "harpoonInfo", @harpoon )) {
		return;
	}
	
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.getSpriteLayer("harpoon");
	Vec2f pos = this.getPosition();
	Island@ thisIsland = getIsland(this.getShape().getVars().customData);
	
	doRopeUpdate(sprite, this, harpoon);
	UpdateHarpoonVisuals3D(this, harpoon);
	RefreshHarpoonGun3D(this);
	
	if (harpoon.grappling == false)
		layer.SetAnimation("set");
	
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();

	if (occupier !is null)
	{
		Manual( this, occupier );	
		
		const bool left_click = occupier.isKeyJustPressed( key_action1 );
		if (left_click)
		{
			if (true && harpoon.grappling == false && harpoon.reeling == false) //otherwise grapple PROBLEM BLOCK
			{
				harpoon.grappling = true;
				harpoon.grapple_id = 0xffff;
				harpoon.grapple_pos = pos;
				Vec2f aimVector = GetHarpoonAimVector(this, occupier);
				sprite.PlaySound("HookShot.ogg", 1.0f, XORRandom(2) == 1 ? 1.0f : 1.5f);
				CParticle@ p = ParticleAnimated( "Entities/Effects/Sprites/WhitePuff.png",
									this.getPosition(),
									this.getVelocity()*0.5f + aimVector,
									1.0f, 0.5f, 
									2, 
									0.0f, true );			
									
				if (p !is null)
				{
					p.Z = 550;
				}

				harpoon.grapple_ratio = 1.0f; //allow fully extended

				harpoon.grapple_vel = aimVector * harpoon_grapple_throw_speed;

				SyncGrapple( this );
			}
		}
	}
	
	
	if (harpoon.grappling || !(harpoon.grapple_id == 0xffff))
	{
		//update grapple
		//TODO move to its own script?
		
		bool ropeTooLong = (harpoon.grapple_pos - this.getPosition()).getLength() > harpoon_grapple_length;	
		
		bool ropeOutOfBounds = (harpoon.grapple_pos.x < 16.0f 
									|| harpoon.grapple_pos.x > (getMap().tilemapwidth * getMap().tilesize) - 16.0f
									|| harpoon.grapple_pos.y < 16.0f
									|| harpoon.grapple_pos.y > (getMap().tilemapheight * getMap().tilesize) - 16.0f );
		
		if ( (ropeTooLong && harpoon.grapple_id == 0xffff) && harpoon.reeling == false && !layer.isAnimation("set") )
				Sound::Play("HookReel.ogg", this.getPosition());
				
		if (occupier !is null)
		{
			if ( occupier.isKeyJustPressed( key_action2 ) && harpoon.reeling == false && !layer.isAnimation("set") )
			{
				Sound::Play("HookReel.ogg", this.getPosition());
				harpoon.reeling = true;
			}					
		}
		
		if( ( ((ropeTooLong || ropeOutOfBounds) && harpoon.grapple_id == 0xffff) || harpoon.reeling == true ) && !layer.isAnimation("set") )
		{
				harpoon.reeling = true;

				const f32 harpoon_grapple_range = harpoon_grapple_length * harpoon.grapple_ratio;
				const f32 harpoon_grapple_force_limit = this.getMass() * harpoon_grapple_accel_limit;

				CMap@ map = this.getMap();

				//reel in
				//TODO: sound
				if( harpoon.grapple_ratio > 0.2f)
					harpoon.grapple_ratio -= 1.0f / getTicksASecond();

				//get the force and offset vectors
				Vec2f force;
				Vec2f offset;
				f32 dist;
				{
					force = harpoon.grapple_pos - this.getPosition();
					dist = force.Normalize();
					f32 offdist = dist - harpoon_grapple_range;
					if(offdist > 0)
					{
						offset = force * Maths::Min(8.0f,offdist * harpoon_grapple_stiffness);
						force *= 1000.0f / (harpoon.grapple_pos - this.getPosition()).getLength();
					}
					else
					{
						force.Set(0,0);
					}
				}
				
				const f32 drag = map.isInWater(harpoon.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0,0.5);

				harpoon.grapple_vel = -force;
				
				Vec2f retractBaseMin = (harpoon.grapple_pos - this.getPosition());
				retractBaseMin.Normalize();
				Vec2f retract = retractBaseMin*5.0f;
				Vec2f next = harpoon.grapple_pos + harpoon.grapple_vel - retract;
				next -= offset;

				Vec2f dir = next - harpoon.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while(delta > 0 && !found) //fake raycast
				{				
					if(delta > step)
					{
						harpoon.grapple_pos += dir * step;
					}
					else
					{
						harpoon.grapple_pos = next;
					}
					delta -= step;
					CBlob@ b = map.getBlobAtPosition(harpoon.grapple_pos);
					if (b !is null)
					{
						if(b is this || b.getName() == "human")
						{
							//can't grapple self if not reeled in

							harpoon.grappling = false;
							SyncGrapple( this );						
														
							Sound::Play("HookReset.ogg", this.getPosition());
							harpoon.reeling = false;
						}
					}
				}
			
		}
		else
		{
			const f32 harpoon_grapple_range = harpoon_grapple_length * harpoon.grapple_ratio;
			const f32 harpoon_grapple_force_limit = this.getMass() * harpoon_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if( harpoon.grapple_ratio > 0.2f)
				harpoon.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = harpoon.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - harpoon_grapple_range;
				if(offdist > 0)
				{
					offset = force * Maths::Min(8.0f,offdist * harpoon_grapple_stiffness);
					force *= Maths::Min(harpoon_grapple_force_limit, Maths::Max(0.0f, offdist + harpoon_grapple_slack) * harpoon_grapple_force);
				}
				else
				{
					force.Set(0,0);
				}
			}

			if(harpoon.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(harpoon.grapple_pos) ? 0.7f : 0.90f;

				harpoon.grapple_vel = (harpoon.grapple_vel);

				Vec2f next = harpoon.grapple_pos + harpoon.grapple_vel;
				next -= offset;

				Vec2f dir = next - harpoon.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while(delta > 0 && !found) //fake raycast
				{
					if(delta > step)
					{
						harpoon.grapple_pos += dir * step;
					}
					else
					{
						harpoon.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, harpoon, map, dist);
				}
				
				layer.SetAnimation("fired");
			}
			else //stuck in map -> pull towards pos
			{
				CBlob@ b = null;
				if(harpoon.grapple_id != 0)
				{
					@b = getBlobByNetworkID( harpoon.grapple_id );
					if(b is null)
					{
						harpoon.grapple_id = 0;
					}
				}
				
				if(b !is null)
				{
					const bool isBlock = b.getName() == "block";
					if (isBlock)
					{
						const int blockType = b.getSprite().getFrame();
						if ( Block::isSolid(blockType) )
						{
							harpoon.grapple_pos = b.getPosition();
							
							// Pull the islands together
							Island@ hitIsland = getIsland(b.getShape().getVars().customData);
							if (hitIsland !is null && thisIsland !is null)
							{
								bool isMyIsland = hitIsland.id == thisIsland.id;
								bool ropeTooLong = (harpoon.grapple_pos - this.getPosition()).getLength() > harpoon_grapple_length;
								if(!isMyIsland && ropeTooLong)
								{
									Vec2f moveVel;
									Vec2f moveNorm;
									float angleVel;	
								
									const f32 hitMass = Maths::Max(1.0f, hitIsland.mass);
									HarpoonForces(this, b, -1.0f, moveVel, moveNorm, angleVel);
									moveVel /= hitMass;
									angleVel /= hitMass;
									hitIsland.vel += moveVel;
									hitIsland.angle_vel += angleVel*2.0f;
									
									const f32 thisMass = Maths::Max(1.0f, thisIsland.mass);
									HarpoonForces(b, this, -1.0f, moveVel, moveNorm, angleVel);
									moveVel /= thisMass;
									angleVel /= thisMass;
									thisIsland.vel += moveVel;
									thisIsland.angle_vel += angleVel*2.0f;
								}
							}
						}
					}				
					else if ( b.getName() == "scrap" )
					{
						b.AddForce(-(harpoon.grapple_pos - this.getPosition())*0.25f);
						harpoon.grapple_pos = b.getPosition();
					}
				}
				else
				{
					harpoon.reeling = true;		
					SyncGrapple( this );
				} 				
			}
		}

	}
}

void Manual( CBlob@ this, CBlob@ occupier )
{
	Vec2f aimvector = GetHarpoonAimVector(this, occupier);

	// rotate muzzle
	Rotate( this, aimvector );
	UpdateHarpoonGun3D(this, aimvector);
	
	occupier.setAngleDegrees( -aimvector.getAngleDegrees() );
}

Vec2f GetHarpoonAimVector(CBlob@ this, CBlob@ occupier)
{
	if (occupier !is null && occupier.exists("dir_x"))
	{
		Vec2f cameraForward(1.0f, 0.0f);
		cameraForward.RotateBy(occupier.get_f32("dir_x") + 90.0f);
		if (cameraForward.LengthSquared() > 0.001f)
		{
			cameraForward.Normalize();
			return cameraForward;
		}
	}

	Vec2f aimvector = occupier !is null ? occupier.get_Vec2f("aim_pos") - this.getPosition() : Vec2f(1.0f, 0.0f);
	if (aimvector.LengthSquared() <= 0.001f)
	{
		aimvector = Vec2f(1.0f, 0.0f);
	}
	aimvector.Normalize();
	return aimvector;
}

void UpdateHarpoonGun3D(CBlob@ this, Vec2f aimvector)
{
	if (aimvector.LengthSquared() > 0.001f)
	{
		this.set_f32("angle", -aimvector.Angle());
	}

	RefreshHarpoonGun3D(this);
}

void RefreshHarpoonGun3D(CBlob@ this)
{
	if (!getNet().isClient())
		return;

	Blob3D@ harpoon3d;
	if (!this.get("blob3d", @harpoon3d) || harpoon3d is null)
		return;

	Blob3D@ gun = harpoon3d.getChild(HARPOON_GUN_CHILD);
	if (gun is null)
		return;

	const f32 yaw = this.get_f32("angle") - this.getAngleDegrees();
	gun.setLocalMayaRotation(Vec3f(0.0f, yaw, 0.0f));

	HarpoonInfo@ harpoon;
	Blob3D@ loadedHead = gun.getChild(HARPOON_LOADED_HEAD_CHILD);
	if (loadedHead !is null && this.get("harpoonInfo", @harpoon) && harpoon !is null)
	{
		loadedHead.LocalTransform.Position = HARPOON_LOADED_HEAD_POSITION;
		loadedHead.LocalTransform.Orientation.x = 0.0f;
		loadedHead.LocalTransform.Orientation.y = 0.0f;
		loadedHead.LocalTransform.Orientation.z = 0.0f;
		loadedHead.renderScale = harpoon.grappling ? 0.0f : 1.0f;
	}
}

void Rotate( CBlob@ this, Vec2f aimvector )
{
	if (aimvector.LengthSquared() > 0.001f)
	{
		this.set_f32("angle", -aimvector.getAngleDegrees());
	}

	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("harpoon");
	if(layer !is null)
	{
		layer.ResetTransform();
		layer.RotateBy( -aimvector.getAngleDegrees() - this.getAngleDegrees(), Vec2f_zero );
	}	
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	
	if( cmd == this.getCommandID(grapple_sync_cmd) )
    {
		HandleGrapple( this, params, true );
	}
	else if (cmd == this.getCommandID("unhook"))
    {
		HarpoonInfo@ harpoon;
		if (!this.get( "harpoonInfo", @harpoon )) 
			return;
		
        harpoon.reeling = true;
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

void shotParticles(Vec2f pos, float angle)
{
	//muzzle flash
	{
		CParticle@ p = ParticleAnimated( "Entities/Block/turret_muzzle_flash.png",
												  pos, Vec2f(),
												  -angle, //angle
												  1.0f, //scale
												  3, //animtime
												  0.0f, //gravity
												  true ); //selflit
		if(p !is null)
			p.Z = 10.0f;
	}

	Vec2f shot_vel = Vec2f(0.5f,0);
	shot_vel.RotateBy(-angle);

	//smoke
	for(int i = 0; i < 5; i++)
	{
		//random velocity direction
		Vec2f vel(0.1f + _shotrandom.NextFloat()*0.2f, 0);
		vel.RotateBy(_shotrandom.NextFloat() * 360.0f);
		vel += shot_vel * i;

		CParticle@ p = ParticleAnimated( "Entities/Block/turret_smoke.png",
												  pos, vel,
												  _shotrandom.NextFloat() * 360.0f, //angle
												  1.0f, //scale
												  3+_shotrandom.NextRanged(4), //animtime
												  0.0f, //gravity
												  true ); //selflit
		if(p !is null)
			p.Z = 110.0f;
	}
}

void LoadSprites( CSprite@ this )
{
    string texname = "Entities/Block/Harpoon.png";
	
	//grapple
    this.RemoveSpriteLayer("hook");
    CSpriteLayer@ hook = this.addSpriteLayer( "hook", texname , 16, 16, this.getBlob().getTeamNum(), this.getBlob().getSkinNum() );

    if (hook !is null)
    {
        Animation@ anim = hook.addAnimation( "default", 0, false );
        anim.AddFrame(28);
        hook.SetRelativeZ(101.0f);
        hook.SetVisible(false);
    }
    
    this.RemoveSpriteLayer("loose rope");
    CSpriteLayer@ looseRope = this.addSpriteLayer( "loose rope", texname , 32, 32, this.getBlob().getTeamNum(), this.getBlob().getSkinNum() );

    if (looseRope !is null)
    {
        Animation@ anim = looseRope.addAnimation( "default", 1, true );
		array<int> frames = {0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1};
		anim.AddFrames( frames );
        looseRope.SetRelativeZ(100.0f);
        looseRope.SetVisible(false);
    }
	
	this.RemoveSpriteLayer("rope");
    CSpriteLayer@ rope = this.addSpriteLayer( "rope", texname , 32, 32, this.getBlob().getTeamNum(), this.getBlob().getSkinNum() );

    if (rope !is null)
    {
        Animation@ anim = rope.addAnimation( "default", 0, false );
        anim.AddFrame(3);
        rope.SetRelativeZ(100.0f);
        rope.SetVisible(false);
    }
}

void SyncGrapple( CBlob@ this )
{
	HarpoonInfo@ harpoon;
	if (!this.get( "harpoonInfo", @harpoon )) { return; }
	
	CBitStream bt;
	
	bt.write_bool(harpoon.grappling);
	if(harpoon.grappling)
	{
		bt.write_u16( harpoon.grapple_id );
		bt.write_u8( u8(harpoon.grapple_ratio*250) );
		bt.write_Vec2f( harpoon.grapple_pos );
		bt.write_Vec2f( harpoon.grapple_vel );
	}
	
	this.SendCommand( this.getCommandID(grapple_sync_cmd), bt );
}

void HandleGrapple( CBlob@ this, CBitStream@ bt, bool apply )
{
	HarpoonInfo@ harpoon;
	if (!this.get( "harpoonInfo", @harpoon )) { return; }
	
	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	Vec2f grapple_pos;
	Vec2f grapple_vel;
	
	grappling = bt.read_bool();
	
	if(grappling)
	{
		grapple_id = bt.read_u16();
		u8 temp = bt.read_u8();
		grapple_ratio = temp / 250.0f;
		grapple_pos = bt.read_Vec2f();
		grapple_vel = bt.read_Vec2f();
	}
	
	if(apply)
	{
		harpoon.grappling = grappling;
		if(harpoon.grappling)
		{
			harpoon.grapple_id = grapple_id;
			harpoon.grapple_ratio = grapple_ratio;
			harpoon.grapple_pos = grapple_pos;
			harpoon.grapple_vel = grapple_vel;
		}
		else
		{
			harpoon.grapple_id = 0xffff;
		}
	}
}

void doRopeUpdate(CSprite@ this, CBlob@ blob, HarpoonInfo@ harpoon)
{
	AttachmentPoint@ seat = blob.getAttachmentPoint(0);

	CSpriteLayer@ looseRope = this.getSpriteLayer("loose rope");
	CSpriteLayer@ rope = this.getSpriteLayer("rope");
	CSpriteLayer@ hook = this.getSpriteLayer("hook");
	
	bool visible = harpoon !is null && harpoon.grappling;
	
	if ( !(harpoon.grapple_id == 0xffff) || harpoon.grapple_id == 0 || harpoon.reeling == true )
	{
		rope.SetVisible(visible);
		looseRope.SetVisible(false);
	}
	else
	{
		looseRope.SetVisible(visible);
		rope.SetVisible(false);	
	}


	hook.SetVisible(false);
	if(!visible)
	{
		harpoon.reeling = false;
		return;
	}
	rope.SetVisible(false);
	looseRope.SetVisible(false);


	Vec2f off = harpoon.grapple_pos - blob.getPosition();
	
	f32 ropelen = Maths::Max(0.1f,off.Length() / 32.0f);
	
	rope.ResetTransform();
	rope.ScaleBy( Vec2f(ropelen,1.0f) );	
	rope.TranslateBy( Vec2f(ropelen*16.0f,0.0f) );	
	rope.RotateBy( -off.Angle() - blob.getAngleDegrees(), Vec2f());
	
	looseRope.ResetTransform();
	looseRope.ScaleBy( Vec2f(ropelen,1.0f) );	
	looseRope.TranslateBy( Vec2f(ropelen*16.0f,0.0f) );	
	looseRope.RotateBy( -off.Angle() - blob.getAngleDegrees(), Vec2f());
	
	hook.ResetTransform();
	if(harpoon.grapple_id == 0xffff) //still in air
	{
		harpoon.cache_angle = -harpoon.grapple_vel.Angle() - blob.getAngleDegrees();
	}
	hook.RotateBy( harpoon.cache_angle, Vec2f());
	
	hook.TranslateBy( off.RotateBy( -blob.getAngleDegrees(), Vec2f()) );
	hook.SetFacingLeft(false);
	
	GUI::DrawLine(blob.getPosition(), harpoon.grapple_pos, SColor(255,255,255,0));
}

bool checkGrappleStep(CBlob@ this, HarpoonInfo@ harpoon, CMap@ map, const f32 dist)
{
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	
	Island@ thisIsland = getIsland(this.getShape().getVars().customData);

	if(map.getSectorAtPosition( harpoon.grapple_pos, "barrier" ) !is null) //red barrier
	{
		harpoon.grappling = false;
		SyncGrapple( this );
	
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(harpoon.grapple_pos);
		if (b !is null)
		{
			Island@ hitIsland = getIsland( b );
			const int blockType = b.getSprite().getFrame();
			if (b is this || b.getName() == "human" || (!Block::isSolid(blockType)))
			{
				//can't grapple self if not reeled in
				if(harpoon.grapple_ratio > 0.5f)
					return false;

				harpoon.grappling = false;
				SyncGrapple( this );
				
				Sound::Play("HookReset.ogg", this.getPosition());

				return true;
			}
			else
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)
				
				Vec2f velocity = harpoon.grapple_vel;			

				harpoon.grapple_id = b.getNetworkID();
				
				SyncGrapple( this );
				
				
				Sound::Play( "crowbar_impact2.ogg", harpoon.grapple_pos );
				sparks(harpoon.grapple_pos, 0, 3.0f);
				
				return true;
			}
		}
	}

	return false;
}

bool shouldReleaseGrapple(CBlob@ this, HarpoonInfo@ harpoon, CMap@ map)
{
	AttachmentPoint@ seat = this.getAttachmentPoint(0);
	CBlob@ occupier = seat.getOccupied();
	
	if (occupier !is null)
		return occupier.isKeyPressed(key_action2);
	else
		return false;
}

bool canSend( CBlob@ occupier )
{
	return true;
}

void ApplyHarpoonHeadMeshSettings(SMesh@ mesh)
{
	if (mesh is null)
		return;

	SMaterial@ material = mesh.GetMaterial();
	if (material is null)
		return;

	material.SetFlag(SMaterial::LIGHTING, false);
	material.SetFlag(SMaterial::BILINEAR_FILTER, false);
	material.SetLayerBilinearFilter(0, false);
	material.SetMaterialType(SMaterial::SOLID);
}

Blob3D@ EnsureHarpoonHead3D(CBlob@ this)
{
	if (!getNet().isClient() || this is null)
		return null;

	Blob3D@ harpoon3d;
	if (!this.get("blob3d", @harpoon3d) || harpoon3d is null)
		return null;

	Blob3D@ head = harpoon3d.getChild(HARPOON_HEAD_CHILD);
	if (head !is null)
		return head;

	Blob3D newHead(Vec3f(), this.getTeamNum(), 1.0f);
	newHead.Name = HARPOON_HEAD_CHILD;
	newHead.mesh.LoadObjIntoMesh("HarpoonHead.obj");
	newHead.mesh.SetHardwareMapping(SMesh::STATIC);
	ApplyHarpoonHeadMeshSettings(newHead.mesh);
	newHead.mesh.BuildMesh();
	newHead.HasMesh = true;
	newHead.renderScale = 0.0f;
	harpoon3d.AddChild(@newHead);
	return harpoon3d.getChild(HARPOON_HEAD_CHILD);
}

Blob3D@ GetHarpoonHead3D(CBlob@ this)
{
	if (!getNet().isClient() || this is null)
		return null;

	Blob3D@ harpoon3d;
	if (!this.get("blob3d", @harpoon3d) || harpoon3d is null)
		return null;

	return harpoon3d.getChild(HARPOON_HEAD_CHILD);
}

Particle3D@ EnsureHarpoonRope3D(CBlob@ this)
{
	if (!getNet().isClient() || this is null)
		return null;

	Particle3D@ rope;
	if (this.get(HARPOON_ROPE_PARTICLE, @rope) && rope !is null)
	{
		if (!rope.IsAlive())
		{
			rope.age = 0.0f;
			EmitParticle3D(rope);
		}
		return rope;
	}

	@rope = Particle3D();
	rope.pointTrail = true;
	rope.uniformTrail = true;
	rope.tileTrailTexture = true;
	rope.IsStatic = true;
	rope.persistent = true;
	rope.lifetime = 999999.0f;
	rope.textureName = "Rope.png";
	rope.maxTrailPoints = HARPOON_ROPE_TRAIL_POINTS;
	rope.trailTextureLength = 16.0f;
	rope.startSize = 2.2f;
	rope.endSize = 2.2f;
	rope.size = 2.2f;
	rope.startColor = SColor(255, 255, 255, 255);
	rope.endColor = SColor(255, 255, 255, 255);
	this.set(HARPOON_ROPE_PARTICLE, @rope);
	EmitParticle3D(rope);
	return rope;
}

Vec3f GetHarpoonBasePoint3D(CBlob@ this)
{
	Blob3D@ harpoon3d;
	if (this !is null && this.get("blob3d", @harpoon3d) && harpoon3d !is null)
	{
		Vec3f pos = harpoon3d.getRenderPosition();
		pos.y += 8.0f;
		return pos;
	}

	return Vec3f(this.getPosition().x, 8.0f, this.getPosition().y);
}

Vec3f GetHarpoonGrapplePoint3D(CBlob@ this, HarpoonInfo@ harpoon)
{
	if (harpoon !is null && harpoon.grapple_id != 0xffff && harpoon.grapple_id != 0)
	{
		CBlob@ hit = getBlobByNetworkID(harpoon.grapple_id);
		Blob3D@ hit3d;
		if (hit !is null && hit.get("blob3d", @hit3d) && hit3d !is null)
		{
			Vec3f hitPos = hit3d.getRenderPosition();
			hitPos.y += 8.0f;
			return hitPos;
		}
	}

	return GetRenderedParticlePosition(this, harpoon.grapple_pos, 8.0f);
}

void SetHarpoonRopeTrailPoints(CBlob@ this, Particle3D@ rope, Vec3f basePoint, Vec3f grapplePoint, HarpoonInfo@ harpoon)
{
	if (rope is null)
		return;

	rope.trailPoints.clear();

	Vec3f ropeVector = grapplePoint - basePoint;
	const f32 length = ropeVector.Length();
	if (length <= 0.001f)
	{
		rope.trailPoints.push_back(basePoint);
		rope.trailPoints.push_back(grapplePoint);
		return;
	}

	Vec3f forward = ropeVector / length;
	Vec3f side = Cross(Vec3f(0.0f, 1.0f, 0.0f), forward);
	if (side.LengthSquared() <= 0.0001f)
	{
		side = Vec3f(1.0f, 0.0f, 0.0f);
	}
	else
	{
		side.Normalize();
	}

	const bool inAir = harpoon !is null && harpoon.grapple_id == 0xffff;
	const f32 phase = getGameTime() * 0.26f + this.getNetworkID() * 0.17f;
	const f32 wobble = inAir ? Maths::Clamp(length * 0.018f, 1.0f, 5.0f) : 0.0f;
	const f32 sag = inAir ? Maths::Clamp(length * 0.012f, 0.0f, 3.5f) : 0.0f;

	for (uint i = 0; i < HARPOON_ROPE_TRAIL_POINTS; i++)
	{
		const f32 t = f32(i) / f32(HARPOON_ROPE_TRAIL_POINTS - 1);
		Vec3f point = basePoint + ropeVector * t;
		if (inAir && i > 0 && i + 1 < HARPOON_ROPE_TRAIL_POINTS)
		{
			const f32 envelope = Maths::Sin(t * Maths::Pi);
			const f32 wave = Maths::Sin(t * Maths::Pi * 3.0f + phase);
			const f32 fineWave = Maths::Sin(t * Maths::Pi * 7.0f + phase * 1.35f);
			point += side * (wave * 0.72f + fineWave * 0.28f) * wobble * envelope;
			point.y -= Maths::Sin(t * Maths::Pi) * sag;
		}
		rope.trailPoints.push_back(point);
	}
}

void ClearHarpoonVisuals3D(CBlob@ this)
{
	Particle3D@ rope;
	if (this.get(HARPOON_ROPE_PARTICLE, @rope) && rope !is null)
	{
		rope.trailPoints.clear();
		rope.age = rope.lifetime + 1.0f;
	}

	Blob3D@ head = GetHarpoonHead3D(this);
	if (head !is null)
	{
		head.renderScale = 0.0f;
	}
}

void UpdateHarpoonVisuals3D(CBlob@ this, HarpoonInfo@ harpoon)
{
	if (!getNet().isClient() || this is null || harpoon is null)
		return;

	const bool visible = harpoon.grappling;
	if (!visible)
	{
		ClearHarpoonVisuals3D(this);
		return;
	}

	Vec3f basePoint = GetHarpoonBasePoint3D(this);
	Vec3f grapplePoint = GetHarpoonGrapplePoint3D(this, harpoon);
	Vec3f ropeVector = grapplePoint - basePoint;
	if (ropeVector.LengthSquared() <= 0.001f)
	{
		ClearHarpoonVisuals3D(this);
		return;
	}

	Particle3D@ rope = EnsureHarpoonRope3D(this);
	if (rope !is null)
	{
		rope.age = 0.0f;
		rope.position = basePoint;
		SetHarpoonRopeTrailPoints(this, rope, basePoint, grapplePoint, harpoon);
		rope.size = 2.2f;
		rope.startSize = rope.size;
		rope.endSize = rope.size;
	}

	Blob3D@ harpoon3d;
	Blob3D@ head = EnsureHarpoonHead3D(this);
	if (this.get("blob3d", @harpoon3d) && harpoon3d !is null && head !is null)
	{
		Vec3f localPos = grapplePoint - harpoon3d.getRenderPosition();
		localPos.xzRotateBy(-harpoon3d.transform.Orientation.x);
		head.LocalTransform.Position = localPos;

		Vec2f aim2D = (grapplePoint - basePoint).xz();
		f32 headYaw = aim2D.LengthSquared() > 0.001f ? -aim2D.Angle() : harpoon.cache_angle;
		head.LocalTransform.Orientation.x = headYaw - harpoon3d.transform.Orientation.x;
		head.LocalTransform.Orientation.y = 0.0f;
		head.LocalTransform.Orientation.z = 0.0f;
		head.renderScale = 1.0f;
	}
}

void GetButtonsFor( CBlob@ this, CBlob@ caller )
{   
	HarpoonInfo@ harpoon;
	if (!this.get( "harpoonInfo", @harpoon )) 
		return;
		
	Island@ thisIsland = getIsland(this.getShape().getVars().customData);
	
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ layer = sprite.getSpriteLayer("harpoon");
	
	CCamera@ camera = getCamera();
	
    if( (harpoon.grapple_pos - caller.getPosition()).getLength() > 16.0f || this.getShape().getVars().customData <= 0)
        return;

    if(harpoon.grapple_id != 0xffff && harpoon.grapple_id != 0 && !layer.isAnimation("set"))
	{
        CButton@ unhookButton = caller.CreateGenericButton( 1, (harpoon.grapple_pos - this.getPosition())*0.5f, this, this.getCommandID("unhook"), "Unhook Harpoon" );
	}
	print("got buttons");
}
