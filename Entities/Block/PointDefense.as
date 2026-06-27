#include "BlockCommon.as"
#include "IslandsCommon.as"
#include "AccurateSoundPlay.as"
#include "Particle3D.as"
#include "Blob3D.as"
#include "Raycast3D.as"

const int FIRE_RATE = 50;
const u8 REFILL_AMMOUNT = 10;//every second
const f32 AUTO_RADIUS = 160.0f;
const f32 POINT_DEFENSE_BARREL_HEIGHT = 12.0f;
const f32 POINT_DEFENSE_BARREL_FORWARD = 11.0f;
const f32 POINT_DEFENSE_TARGET_HEIGHT = 12.0f;
const string POINT_DEFENSE_AIM_X = "point defense aim x";
const string POINT_DEFENSE_AIM_Y = "point defense aim y";
const string POINT_DEFENSE_AIM_Z = "point defense aim z";

void onInit( CBlob@ this )
{
	this.Tag("pointDefense");
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
	this.set_f32(POINT_DEFENSE_AIM_X, 1.0f);
	this.set_f32(POINT_DEFENSE_AIM_Y, 0.0f);
	this.set_f32(POINT_DEFENSE_AIM_Z, 0.0f);
	
	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ layer = sprite.addSpriteLayer( "weapon", 16, 16 );
    if (layer !is null)
    {
    	layer.SetRelativeZ(2);
    	layer.SetLighting( false );
     	Animation@ anim = layer.addAnimation( "fire", 15, false );
        anim.AddFrame(2);
        anim.AddFrame(1);
        layer.SetAnimation("fire");    	
    }
}

void onTick( CBlob@ this )
{
	if ( this.getShape().getVars().customData <= 0 )
		return;
	
	u32 gameTime = getGameTime();
	u16 thisID = this.getNetworkID();

	Auto( this );
	
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

	UpdatePointDefenseBlob3D(this);
}

void Auto( CBlob@ this )
{
	if ( ( getGameTime() + this.getNetworkID() * 33 ) % 5 != 0 )
		return;
		
	CBlob@[] blobsInRadius;
	Vec2f pos = this.getPosition();
	f32 minDistance = 9999999.9f;
	bool shoot = false;
	Vec2f shootVec = Vec2f(0, 0);
	Vec3f shootVec3D;
	
	u16 hitBlobNetID = 0;
	Vec2f bPos = Vec2f(0, 0);
	
	//ammo
	u16 ammo = this.get_u16( "ammo" );
	if ( getNet().isServer() )
		this.get( "ammo", ammo );
	if (ammo == 0 || !canShootAuto(this))
		return;

	if ( this.getMap().getBlobsInRadius( this.getPosition(), AUTO_RADIUS, @blobsInRadius ) )
	{
		for ( uint i = 0; i < blobsInRadius.length; i++ )
		{
			CBlob @b = blobsInRadius[i];
			if ( b.getTeamNum() != this.getTeamNum() && IsPointDefenseTarget(b) )
			{
				bPos = b.getPosition();
				
				if ( b.getName() != "block" )
				{
					if ( b.isAttached() )
					{
						AttachmentPoint@ humanAttach = b.getAttachmentPoint(0);
						CBlob@ seat = humanAttach.getOccupied();
						if ( seat !is null )
							bPos = seat.getPosition();
					}
				}
				
				Vec3f targetPoint = GetPointDefenseTargetPoint3D(b);
				Vec3f barrelPoint = GetPointDefenseBarrelBase3D(this);
				Vec3f aimVec3D = targetPoint - barrelPoint;
				f32 distance3D = aimVec3D.Length();
				Vec2f aimVec = bPos - pos;
				f32 distance = Maths::Max(distance3D, aimVec.Length());

				if ( distance < minDistance && isClearShot3D( this, b, barrelPoint, targetPoint ) )
				{
					shoot = true;					
					shootVec = aimVec;
					shootVec3D = aimVec3D;
					minDistance = distance;
					hitBlobNetID = b.getNetworkID();
				}
			}
		}
	}
	
	if ( shoot )
	{	
		if ( getNet().isServer() )
		{		
			Fire( this, shootVec, shootVec3D, hitBlobNetID );
		}
	}
}

bool canShootAuto( CBlob@ this, bool manual = false )
{
	return this.get_u32("fire time") + FIRE_RATE < getGameTime();
}

bool IsPointDefenseTarget(CBlob@ target)
{
	return target !is null
		&& (target.hasTag("rocket")
			|| target.hasTag("cannonball")
			|| target.hasTag("bullet")
			|| target.hasTag("flak shell")
			|| target.hasTag("projectile"));
}

bool isClearShot3D(CBlob@ this, CBlob@ target, Vec3f origin, Vec3f targetPoint)
{
	Vec3f aimVector = targetPoint - origin;
	const f32 distance = aimVector.Length();
	if (distance <= 0.001f)
		return false;

	aimVector = aimVector / distance;

	Raycast3D::Ray3D ray(origin, aimVector);
	Raycast3D::RaycastHit3D hit;
	const f32 maxBlockDistance = Maths::Max(0.0f, distance - 1.5f);
	if (Raycast3D::RaycastBlockTarget(ray, 1.0f, maxBlockDistance, this, hit))
	{
		return hit.blob is target;
	}

	return true;
}

void Fire( CBlob@ this, Vec2f aimVector, Vec3f aimVector3D, const u16 hitBlobNetID )
{
	CBitStream params;
	params.write_netid( hitBlobNetID );
	params.write_Vec2f( aimVector );
	params.write_f32( aimVector3D.x );
	params.write_f32( aimVector3D.y );
	params.write_f32( aimVector3D.z );
	
	this.SendCommand( this.getCommandID("fire"), params );
}

void Rotate( CBlob@ this, Vec2f aimVector )
{
	CSpriteLayer@ layer = this.getSprite().getSpriteLayer("weapon");
	if(layer !is null)
	{
		layer.ResetTransform();
		layer.RotateBy( -aimVector.getAngleDegrees() - this.getAngleDegrees(), Vec2f_zero );
	}
}

void SetPointDefenseAim(CBlob@ this, Vec3f aimVector)
{
	if (aimVector.LengthSquared() <= 0.001f)
		return;

	aimVector = aimVector.Normalize();
	this.set_f32(POINT_DEFENSE_AIM_X, aimVector.x);
	this.set_f32(POINT_DEFENSE_AIM_Y, aimVector.y);
	this.set_f32(POINT_DEFENSE_AIM_Z, aimVector.z);
}

Vec3f GetPointDefenseAim(CBlob@ this)
{
	Vec3f aim(
		this.get_f32(POINT_DEFENSE_AIM_X),
		this.get_f32(POINT_DEFENSE_AIM_Y),
		this.get_f32(POINT_DEFENSE_AIM_Z)
	);
	if (aim.LengthSquared() <= 0.001f)
	{
		return Vec3f(1.0f, 0.0f, 0.0f);
	}
	return aim.Normalize();
}

Vec3f GetPointDefenseBarrelBase3D(CBlob@ this)
{
	Blob3D@ blob3d;
	if (this !is null && this.get("blob3d", @blob3d) && blob3d !is null)
	{
		Vec3f pos = getNet().isClient() ? blob3d.getRenderPosition() : blob3d.getPosition();
		pos.y += POINT_DEFENSE_BARREL_HEIGHT;
		return pos;
	}

	return Vec3f(this.getPosition().x, POINT_DEFENSE_BARREL_HEIGHT, this.getPosition().y);
}

Vec3f GetPointDefenseBarrelTip3D(CBlob@ this)
{
	return GetPointDefenseBarrelBase3D(this) + GetPointDefenseAim(this) * POINT_DEFENSE_BARREL_FORWARD;
}

Vec3f GetPointDefenseTargetPoint3D(CBlob@ target)
{
	if (target is null)
		return Vec3f();

	Blob3D@ target3d;
	if (target !is null && target.get("blob3d", @target3d) && target3d !is null)
	{
		return getNet().isClient() ? target3d.getRenderPosition() : target3d.getPosition();
	}

	Vec2f pos = target.getPosition();
	f32 y = POINT_DEFENSE_TARGET_HEIGHT;
	if (target.exists("bullet 3d position y"))
	{
		y = target.get_f32("bullet 3d position y");
	}
	else if (target.hasTag("rocket") || target.hasTag("cannonball") || target.hasTag("flak shell"))
	{
		y = 10.0f;
	}
	return Vec3f(pos.x, y, pos.y);
}

void UpdatePointDefenseBlob3D(CBlob@ this)
{
	if (!getNet().isClient())
		return;

	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d) || blob3d is null)
		return;

	Blob3D@ ball = blob3d.getChild("point_defense_ball");
	if (ball is null)
		return;

	Vec3f aim = GetPointDefenseAim(this);
	Vec2f aimXZ(aim.x, aim.z);
	if (aimXZ.LengthSquared() > 0.001f)
	{
		const f32 yaw = -aimXZ.Angle() - this.getAngleDegrees();
		ball.setLocalMayaRotation(Vec3f(0.0f, yaw, 0.0f));
	}

	Blob3D@ barrel = ball.getChild("PointBarrel");
	if (barrel !is null)
	{
		const f32 pitch = -Maths::ATan2(aim.y, Maths::Max(0.001f, Maths::Sqrt(aim.x * aim.x + aim.z * aim.z))) * 180.0f / Maths::Pi;
		barrel.LocalTransform.Orientation.y = pitch;
	}
}

void EmitPointDefenseLaser3D(CBlob@ this, CBlob@ hitBlob)
{
	if (!getNet().isClient() || hitBlob is null)
		return;

	Vec3f start = GetPointDefenseBarrelTip3D(this);
	Vec3f end = GetPointDefenseTargetPoint3D(hitBlob);

	Particle3D@ laser = Particle3D();
	laser.pointTrail = true;
	laser.uniformTrail = true;
	laser.IsStatic = false;
	laser.lifetime = 6.0f;
	laser.textureName = "pixel";
	laser.maxTrailPoints = 2;
	laser.startSize = 1.25f;
	laser.endSize = 0.15f;
	laser.size = laser.startSize;
	laser.startColor = SColor(235, 80, 180, 255);
	laser.endColor = SColor(0, 50, 120, 255);
	laser.trailPoints.push_back(start);
	laser.trailPoints.push_back(end);
	EmitParticle3D(laser);
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("fire"))
    {
		CBlob@ hitBlob = getBlobByNetworkID( params.read_netid() );
		Vec2f aimVector = params.read_Vec2f();
		Vec3f aimVector3D(params.read_f32(), params.read_f32(), params.read_f32());
		
		if (hitBlob is null)
			return;
		
		Vec2f pos = this.getPosition();		
		Vec2f bPos = hitBlob.getPosition();
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
		
		if (hitBlob !is null)
		{		
			SetPointDefenseAim(this, aimVector3D);
			UpdatePointDefenseBlob3D(this);

			if ( isServer )
			{
				f32 damage = getDamage( hitBlob );
				this.server_Hit( hitBlob, bPos, Vec2f_zero, damage, 0, true );
			}
			
			Rotate( this, aimVector ); 
			shotParticles(this, pos + aimVector*9, aimVector.Angle());
			directionalSoundPlay( "Laser1.ogg", pos, 1.0f );
			EmitPointDefenseLaser3D(this, hitBlob);

			if ( getNet().isClient() )//effects
			{	
				hitEffects( hitBlob, bPos );
			}
		}
		
		CSpriteLayer@ layer = this.getSprite().getSpriteLayer( "weapon" );
		if ( layer !is null )
			layer.animation.SetFrameIndex(0);
			
		this.set_u32("fire time", getGameTime());
    }
}

f32 getDamage( CBlob@ hitBlob )
{	
	if ( hitBlob.hasTag( "rocket" ) )
		return 1.0f;

	if ( hitBlob.hasTag( "cannonball" ) )
		return 1.0f;
		
	if ( hitBlob.hasTag( "bullet" ) )
		return 1.0f;
	
	if ( hitBlob.hasTag( "flak shell" ) )
		return 1.0f;
		
	return 0.01f;//cores, solids
}

Random _shotrandom(0x15125); //clientside
void shotParticles(CBlob@ this, Vec2f pos, float angle)
{
	EmitMuzzleParticles3D(this, pos, angle, 0.75f);
}

void hitEffects( CBlob@ hitBlob, Vec2f worldPoint )
{
	if (hitBlob.hasTag("player") )
	{
		directionalSoundPlay( "ImpactFlesh", worldPoint );
		ParticleBloodSplat( worldPoint, true );
	}
	else if ( hitBlob.hasTag("projectile") )
	{
		sparks(worldPoint, 4);
	}
}

Random _sprk_r;
void sparks(Vec2f pos, int amount)
{
	for (int i = 0; i < amount; i++)
    {
        Vec2f vel(_sprk_r.NextFloat() * 1.0f, 0);
        vel.RotateBy(_sprk_r.NextFloat() * 360.0f);

        CParticle@ p = ParticlePixel( pos, vel, SColor( 255, 255, 128+_sprk_r.NextRanged(128), _sprk_r.NextRanged(128)), true );
        if(p is null) return; //bail if we stop getting particles

        p.timeout = 10 + _sprk_r.NextRanged(20);
        p.scale = 0.5f + _sprk_r.NextFloat();
        p.damping = 0.95f;
    }
}
