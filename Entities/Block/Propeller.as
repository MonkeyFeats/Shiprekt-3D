#include "IslandsCommon.as"
#include "BlockCommon.as"
#include "PropellerForceCommon.as"
#include "AccurateSoundPlay.as"
#include "TileCommon.as"
#include "Particle3D.as"
#include "OceanWave.as"
#include "PropellerWake3D.as"

Random _r(133701); //global clientside random object
const string PROPELLER_BLADES_CHILD = "propeller_blades";

void onInit( CBlob@ this )
{
	this.addCommandID("on/off");
	this.addCommandID("off");
	this.addCommandID("stall");
	this.Tag("propeller");
	this.set_f32("power", 0.0f);
	this.set_f32("powerFactor", 1.0f);
	this.set_u32( "onTime", 0 );
	this.set_u8( "stallTime", 0 );

	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ propeller = sprite.addSpriteLayer( "propeller" );
    if (propeller !is null)
    {
    	propeller.SetOffset(Vec2f(0,8));
    	propeller.SetRelativeZ(2);
    	propeller.SetLighting( false );
        Animation@ animcharge = propeller.addAnimation( "go", 1, true );
        animcharge.AddFrame(Block::PROPBLADES1);
        animcharge.AddFrame(Block::PROPBLADES2);
        propeller.SetAnimation("go");
    }

    sprite.SetEmitSound("PropellerMotor");
    sprite.SetEmitSoundPaused(true);


}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("on/off") && getNet().isServer())
    {
		this.set_f32("power", isOn(this) ? 0.0f : -this.get_f32("powerFactor"));
    }
	
    if (cmd == this.getCommandID("off") && getNet().isServer())
    {
		this.set_f32("power", 0.0f);
    }
	
    if (cmd == this.getCommandID("stall") && getNet().isClient())
	{
		directionalSoundPlay( "propellerStall.ogg", this.getPosition(), 2.5f );		
		this.set_u8( "stallTime", params.read_u8() );
	}
}

bool isOn(CBlob@ this)
{
	return this.get_f32("power") != 0;
}

void onTick( CBlob@ this )
{
	u32 gameTime = getGameTime();
	CSprite@ sprite = this.getSprite();
	f32 power = this.get_f32("power");
	Vec2f pos = this.getPosition();
	u8 stallTime = this.get_u8( "stallTime" );
	const bool stalled = stallTime > 0;
	const bool on = power != 0 && !stalled;	
	
	CSpriteLayer@ propeller = sprite.getSpriteLayer("propeller");
	if ( propeller !is null )
		propeller.animation.time = on ? 1 : 0;

	UpdatePropellerBlades3D(this, power, on);

	if ( getNet().isServer() )
		this.Sync("power", true);

	if (getNet().isClient() && on)
	{
		EmitPropellerWakeParticles3D(this, power, gameTime, v_fastrender ? 12 : 3);
	}

	if (this.getShape().getVars().customData <= 0)
		return;

	if ( stalled )
	{
		this.set_u8( "stallTime", stallTime - 1 );
		if ( getNet().isClient() )//stall smoke effect
		{
			if ( gameTime % ( v_fastrender ? 5 : 2 ) == 0 )
				smoke( pos );
		}
	}
	
	if (on)
	{
		//auto turn off after a while
		if ( getNet().isServer() && gameTime - this.get_u32( "onTime") > 750 )
		{
			this.SendCommand( this.getCommandID( "off" ) );
			return;
		}
		
		Island@ island = getIsland(this.getShape().getVars().customData);
		if (island !is null)
		{
			// move
			Vec2f moveVel;
			Vec2f moveNorm;
			float angleVel;
			
			//PropellerForces(this, island, power, moveVel, moveNorm, angleVel);
			
			const f32 mass = island.mass + island.carryMass;
			moveVel /= mass;
			angleVel /= mass;
			
			island.vel += moveVel;
			island.angle_vel += angleVel;
		
			// eat stuff
			if (getNet().isServer() && ( gameTime + this.getNetworkID() ) % 15 == 0)
			{
				//low health stall failure
				f32 healthPct = this.getHealth()/this.getInitialHealth();
				if ( healthPct < 0.25f && !stalled && XORRandom(25) == 0 )
				{
					u8 stallTime = 30 + XORRandom(50);
					this.set_u8( "stallTime", stallTime );
					CBitStream params;
					params.write_u8( stallTime );
					this.SendCommand( this.getCommandID( "stall" ), params );
				}
				
				//eat stuff
				//Vec2f faceNorm(0,-1);
				//faceNorm.RotateBy(this.getAngleDegrees());
				//CBlob@ victim = getMap().getBlobAtPosition( pos - faceNorm * Block::size );
				//if ( victim !is null && !victim.isAttached() 
				//	 && victim.getShape().getVars().customData > 0
				//	       && !victim.hasTag( "player" ) )	
				//{
				//	f32 hitPower = Maths::Max( 0.5f, Maths::Abs( this.get_f32("power") ) );
				//	if ( !victim.hasTag( "mothership" ) )
				//		this.server_Hit( victim, pos, Vec2f_zero, hitPower, 9, true );
				//	else
				//		victim.server_Hit( this, pos, Vec2f_zero, hitPower, 9, true );
				//}
			}
			
			// effects
			if ( getNet().isClient() )
			{
				if ((gameTime + this.getNetworkID()) % 24 == 0 && this.getHealth() < this.getInitialHealth() * 0.45f)
				{
					EmitFireplaceSmokeParticles3D(Vec3f(pos.x, 9.0f, pos.y), 0.65f);
				}
				
				// limit sounds		
				if (island.soundsPlayed == 0 && sprite.getEmitSoundPaused() == true)
				{
					sprite.SetEmitSoundPaused(false);								
				}
				island.soundsPlayed++;
				const f32 vol = Maths::Min(0.5f + float(island.soundsPlayed)/2.0f, 3.0f);
				sprite.SetEmitSoundVolume( vol );
			}
		}
	}
	else
	{
		if ( sprite.getEmitSoundPaused() == false )
		{
			sprite.SetEmitSoundPaused(true);
		}
	}
}

f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	if ( !getNet().isServer() || this.get_u8( "stallTime" ) > 0 )
		return damage;
		
	f32 healthPct = this.getHealth()/this.getInitialHealth();
	if ( healthPct > 0.0f && healthPct < 0.75f )
	{
		f32 stallFactor = 1.0f/healthPct + Maths::FastSqrt( damage );
		if ( stallFactor * XORRandom(9) > 15 )//chance based on health and damage to stall
		{
			u8 stallTime = stallFactor * 30;
			this.set_u8( "stallTime", stallTime );
			CBitStream params;
			params.write_u8( stallTime );
			this.SendCommand( this.getCommandID( "stall" ), params );
		}
	}
	
	return damage;
}

void onHitBlob( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData )
{
	if ( customData == 9 )
		directionalSoundPlay( "propellerHit.ogg", worldPoint );		
}

void smoke( Vec2f pos )
{
	EmitFireplaceSmokeParticles3D(Vec3f(pos.x, 9.0f, pos.y), 0.8f);
}

void UpdatePropellerBlades3D(CBlob@ this, f32 power, bool on)
{
	if (!getNet().isClient())
		return;

	Blob3D@ propeller;
	if (!this.get("blob3d", @propeller) || propeller is null)
		return;

	Blob3D@ blades = propeller.getChild(PROPELLER_BLADES_CHILD);
	if (blades is null)
		return;

	Vec3f rotation = blades.getLocalMayaRotation();
	f32 angle = rotation.z;
	if (on)
	{
		angle += 15.0f * Maths::Ceil(power);
		while (angle < 0.0f)
			angle += 360.0f;
		while (angle >= 360.0f)
			angle -= 360.0f;
	}

	blades.setLocalMayaRotation(Vec3f(rotation.x, 0.0f, angle));
}
