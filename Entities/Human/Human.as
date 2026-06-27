#include "HumanCommon.as"
#include "EmotesCommon.as"
#include "MakeBlock.as"
#include "WaterEffects.as"
#include "IslandsCommon.as"
#include "BlockCommon.as"
#include "Booty.as"
#include "AccurateSoundPlay.as"
#include "TileCommon.as"
#include "Blob3D.as"
#include "BoundingCapsule.as"
#include "Raycast3D.as"
#include "World.as"
#include "HumanGrounding.as"
#include "Particle3D.as"
#include "BuildWheelMenuCommon.as"

int useClickTime = 0;
const int PUNCH_RATE = 15;
const int FIRE_RATE = 40;
const int CONSTRUCT_RATE = 14;
const int CONSTRUCT_VALUE = 5;
const int CONSTRUCT_RANGE = 48;
const f32 BULLET_SPREAD = 0.2f;
const f32 BULLET_SPEED = 150.0f;
const f32 BULLET_RANGE = 1000.0f;
const f32 BULLET_3D_BARREL_FORWARD = 5.5f;
const f32 BULLET_3D_BARREL_RIGHT = 0.0f;
const f32 BULLET_3D_BARREL_UP = 10.0f;
const f32 TOOL_BEAM_3D_HEIGHT = 11.0f;
const f32 TOOL_BEAM_3D_FORWARD = 6.0f;
const string TOOL_BEAM_3D_CORE = "tool beam 3d core";
const string TOOL_BEAM_3D_GLOW = "tool beam 3d glow";
const bool BULLET_3D_DEBUG = false;
const bool BULLET_3D_MUZZLE_DEBUG = false;
const string BULLET_3D_VEL_X = "bullet 3d velocity x";
const string BULLET_3D_VEL_Y = "bullet 3d velocity y";
const string BULLET_3D_VEL_Z = "bullet 3d velocity z";
const string BULLET_3D_POS_Y = "bullet 3d position y";
const string BULLET_3D_IGNORE_ID = "bullet 3d ignore id";
Random _shotspreadrandom(0x11598); //clientside
string menu_selected = "build_menu";
const string ATTACHED_SEAT_ID = "attached seat id";
const string SEAT_CAMERA_SNAP_ID = "seat camera snap id";
const string SHIP_STAY_ID = "shipID";
const string SHIP_STAY_POS = "stay ship pos";
const string SHIP_STAY_Y = "stay ship y";
const string SHIP_STAY_ANGLE = "stay ship angle";
const string HUMAN_3D_NET_POS = "human 3d net pos";
const string HUMAN_3D_NET_OLD_POS = "human 3d net old pos";
const string HUMAN_3D_NET_Y = "human 3d net y";
const string HUMAN_3D_NET_OLD_Y = "human 3d net old y";
const u32 HUMAN_3D_SYNC_RATE = 1;
const f32 HUMAN_3D_SPAWN_Y = 16.0f;
const f32 HUMAN_3D_WATER_EXIT_HEIGHT = 2.0f;
const f32 HUMAN_3D_OWNER_CORRECTION_START = 4.0f;
const f32 HUMAN_3D_OWNER_CORRECTION_HARD_SNAP = 96.0f;
const f32 HUMAN_3D_OWNER_CORRECTION_BLEND = 0.25f;
const u8 HUMAN_3D_TEAM = 6;

Vec2f Human3DXZ(Vec3f v)
{
	return Vec2f(v.x, v.z);
}

void Bullet3DDebugShoot(const string &in message)
{
	if (!BULLET_3D_DEBUG)
		return;

	print("[Bullet3D][Shoot] " + message);
}

void Bullet3DMuzzleDebug(const string &in message)
{
	if (!BULLET_3D_MUZZLE_DEBUG)
		return;

	print("[Bullet3D][Muzzle] " + message);
}

string Bullet3DDebugVec3(Vec3f value)
{
	return "(" + value.x + ", " + value.y + ", " + value.z + ")";
}

string Bullet3DDebugVec2(Vec2f value)
{
	return "(" + value.x + ", " + value.y + ")";
}

string Bullet3DDebugBool(bool value)
{
	return value ? "true" : "false";
}

bool GetLocalCameraForwardAxis(CBlob@ this, Vec3f &out direction)
{
	if (this is null || !this.isMyPlayer())
		return false;

	CPlayer@ player = this.getPlayer();
	if (player is null)
		return false;

	Camera3D@ camera;
	if (!player.get("Camera3D", @camera) || camera is null)
		return false;

	direction = camera.getDirection();
	direction = direction.Normalize();
	return direction.LengthSquared() > 0.0001f;
}

Vec3f SafeNormal3D(Vec3f value, Vec3f fallback)
{
	if (value.LengthSquared() <= 0.0001f)
	{
		return fallback;
	}

	return value.Normalize();
}

Vec3f ApplyBulletSpread3D(Vec3f direction)
{
	direction = SafeNormal3D(direction, Vec3f(1.0f, 0.0f, 0.0f));
	if (BULLET_SPREAD <= 0.0f)
	{
		return direction;
	}

	Vec3f worldUp(0.0f, 1.0f, 0.0f);
	Vec3f right = Cross(worldUp, direction);
	if (right.LengthSquared() <= 0.0001f)
	{
		right = Vec3f(1.0f, 0.0f, 0.0f);
	}
	right = right.Normalize();

	Vec3f up = Cross(direction, right);
	if (up.LengthSquared() <= 0.0001f)
	{
		up = worldUp;
	}
	up = up.Normalize();

	const f32 yawRadians = (_shotspreadrandom.NextFloat() - 0.5f) * BULLET_SPREAD * Maths::Pi / 180.0f;
	const f32 pitchRadians = (_shotspreadrandom.NextFloat() - 0.5f) * BULLET_SPREAD * Maths::Pi / 180.0f;
	Vec3f spreadDirection = direction + right * Maths::Tan(yawRadians) + up * Maths::Tan(pitchRadians);
	return SafeNormal3D(spreadDirection, direction);
}

Vec3f GetHumanMuzzlePivot3D(CBlob@ this, Blob3D@ shooter3D)
{
	Vec2f pos = this.getPosition();
	Vec3f pivot(pos.x, BULLET_3D_BARREL_UP, pos.y);
	if (shooter3D !is null)
	{
		pivot = shooter3D.getRenderPosition();
		pivot.y += BULLET_3D_BARREL_UP;
	}

	return pivot;
}

Vec3f GetHumanToolBeamOrigin3D(CBlob@ this, Blob3D@ player3D, Vec3f forward)
{
	Vec2f pos = this.getPosition();
	Vec3f origin(pos.x, TOOL_BEAM_3D_HEIGHT, pos.y);
	if (player3D !is null)
	{
		origin = player3D.getRenderPosition();
		origin.y += TOOL_BEAM_3D_HEIGHT;
	}

	return origin + forward * TOOL_BEAM_3D_FORWARD;
}

Vec3f GetToolTargetPoint3D(CBlob@ target)
{
	if (target is null)
	{
		return Vec3f();
	}

	Blob3D@ target3D;
	if (target.get("blob3d", @target3D) && target3D !is null)
	{
		Vec3f targetPoint = target3D.getRenderPosition();
		targetPoint.y += 8.0f;
		return targetPoint;
	}

	return GetRenderedParticlePosition(target, target.getInterpolatedPosition(), 8.0f);
}

Particle3D@ EnsureToolBeamParticle(CBlob@ this, const string &in key, bool glow)
{
	Particle3D@ beam;
	if (this.get(key, @beam) && beam !is null)
	{
		if (!beam.IsAlive())
		{
			beam.age = 0.0f;
			EmitParticle3D(beam);
		}
		return beam;
	}

	@beam = Particle3D();
	beam.pointTrail = true;
	beam.uniformTrail = true;
	beam.IsStatic = true;
	beam.persistent = true;
	beam.lifetime = 999999.0f;
	beam.textureName = "pixel";
	beam.maxTrailPoints = 10;
	beam.startSize = glow ? 3.1f : 1.25f;
	beam.endSize = beam.startSize;
	beam.size = beam.startSize;
	this.set(key, @beam);
	EmitParticle3D(beam);
	return beam;
}

void KillToolBeam3D(CBlob@ this)
{
	Particle3D@ core;
	if (this.get(TOOL_BEAM_3D_CORE, @core) && core !is null)
	{
		core.age = core.lifetime + 1.0f;
	}

	Particle3D@ glow;
	if (this.get(TOOL_BEAM_3D_GLOW, @glow) && glow !is null)
	{
		glow.age = glow.lifetime + 1.0f;
	}
}

void SetToolBeamArcPoints(Particle3D@ beam, Vec3f origin, Vec3f targetPoint, f32 wobble, f32 phase)
{
	if (beam is null)
		return;

	Vec3f beamVector = targetPoint - origin;
	if (beamVector.LengthSquared() <= 0.001f)
		return;

	Vec3f direction = beamVector.Normalize();
	Vec3f side = Cross(direction, Vec3f(0.0f, 1.0f, 0.0f));
	if (side.LengthSquared() <= 0.001f)
	{
		side = Vec3f(1.0f, 0.0f, 0.0f);
	}
	side = side.Normalize();

	Vec3f up = Cross(side, direction);
	if (up.LengthSquared() <= 0.001f)
	{
		up = Vec3f(0.0f, 1.0f, 0.0f);
	}
	up = up.Normalize();

	const uint pointCount = 10;
	beam.trailPoints.clear();
	for (uint i = 0; i < pointCount; i++)
	{
		const f32 t = pointCount <= 1 ? 0.0f : f32(i) / f32(pointCount - 1);
		Vec3f point = origin + beamVector * t;
		if (i > 0 && i + 1 < pointCount)
		{
			const f32 envelope = Maths::Sin(t * Maths::Pi);
			const f32 sideWave = Maths::Sin(phase + t * 27.0f) + Maths::Sin(phase * 1.7f + t * 51.0f) * 0.45f;
			const f32 upWave = Maths::Cos(phase * 1.35f + t * 35.0f) + Maths::Sin(phase * 0.9f + t * 74.0f) * 0.35f;
			point += side * sideWave * wobble * envelope;
			point += up * upWave * wobble * 0.55f * envelope;
		}
		beam.trailPoints.push_back(point);
	}
}

void EmitToolBeamImpact3D(Vec3f targetPoint, Vec3f beamDir, SColor color)
{
	if (!getNet().isClient())
		return;

	Random random(getGameTime() * 349 + Maths::Round(targetPoint.x * 5.0f) + Maths::Round(targetPoint.z * 7.0f));
	for (int i = 0; i < 3; i++)
	{
		Vec3f dir = beamDir * -(0.45f + random.NextFloat() * 0.5f);
		dir.xzRotateBy((random.NextFloat() - 0.5f) * 105.0f);
		dir.y += (random.NextFloat() - 0.35f) * 0.65f;
		if (dir.LengthSquared() <= 0.001f)
		{
			dir = Vec3f(0.0f, 1.0f, 0.0f);
		}
		dir = dir.Normalize();

		Particle3D@ spark = Particle3D(
			targetPoint + dir * (0.4f + random.NextFloat() * 1.6f),
			dir * (1.4f + random.NextFloat() * 2.2f),
			Vec3f(0.0f, -0.015f, 0.0f),
			6.0f + random.NextFloat() * 5.0f,
			1.5f + random.NextFloat() * 1.2f,
			0.0f,
			SColor(210, color.getRed(), color.getGreen(), color.getBlue()),
			SColor(0, color.getRed() / 2, color.getGreen() / 2, color.getBlue() / 2)
		);
		spark.damping = 0.88f;
		spark.stretch = 2.0f;
		spark.facingMode = ParticleFace3D::CameraVelocity;
		EmitParticle3D(spark);
	}
}

void UpdateToolBeam3D(CBlob@ this, Blob3D@ player3D)
{
	if (!getNet().isClient() || !this.isMyPlayer())
		return;

	const string currentTool = this.get_string("current tool");
	if ((currentTool != "deconstructor" && currentTool != "reconstructor") || !this.isKeyPressed(key_action1) || this.isAttached() || this.hasTag("dead"))
	{
		KillToolBeam3D(this);
		return;
	}

	CBlob@ target = getMap().getBlobAtPosition(this.get_Vec2f("aim_pos"));
	if (target is null || target.getShape().getVars().customData <= 0 || target.hasTag("mothership"))
	{
		KillToolBeam3D(this);
		return;
	}

	Vec3f targetPoint = GetToolTargetPoint3D(target);
	Vec3f forward;
	if (!GetLocalCameraForwardAxis(this, forward))
	{
		Vec2f fallback(1.0f, 0.0f);
		fallback.RotateBy(this.get_f32("dir_x") + 90.0f);
		forward = Vec3f(fallback.x, 0.0f, fallback.y);
	}
	if (forward.LengthSquared() <= 0.001f)
	{
		Vec2f fallback(1.0f, 0.0f);
		fallback.RotateBy(this.get_f32("dir_x") + 90.0f);
		forward = Vec3f(fallback.x, 0.0f, fallback.y);
	}
	forward = forward.Normalize();

	Vec3f origin = GetHumanToolBeamOrigin3D(this, player3D, forward);
	Vec3f beam = targetPoint - origin;
	const f32 distance = beam.Length();
	if (distance <= 1.0f || distance > CONSTRUCT_RANGE + 14.0f)
	{
		KillToolBeam3D(this);
		return;
	}

	Vec3f direction = beam / distance;
	const bool reconstructing = currentTool == "reconstructor";
	SColor coreColor = reconstructing ? SColor(245, 72, 255, 120) : SColor(245, 255, 70, 58);
	SColor glowColor = reconstructing ? SColor(95, 25, 220, 70) : SColor(95, 255, 24, 18);

	Particle3D@ core = EnsureToolBeamParticle(this, TOOL_BEAM_3D_CORE, false);
	Particle3D@ glow = EnsureToolBeamParticle(this, TOOL_BEAM_3D_GLOW, true);
	if (core is null || glow is null)
		return;

	core.age = 0.0f;
	core.position = origin;
	core.velocity = direction;
	core.startColor = coreColor;
	core.endColor = coreColor;
	core.size = 0.85f + Maths::Sin(getGameTime() * 0.45f) * 0.16f;
	core.startSize = core.size;
	core.endSize = core.size;

	glow.age = 0.0f;
	glow.position = origin;
	glow.velocity = direction;
	glow.startColor = glowColor;
	glow.endColor = glowColor;
	glow.size = 2.5f + Maths::Sin(getGameTime() * 0.28f) * 0.42f;
	glow.startSize = glow.size;
	glow.endSize = glow.size;

	const f32 phase = getGameTime() * 0.58f + f32(this.getNetworkID() % 97);
	const f32 wobble = Maths::Clamp(distance * 0.045f, 1.0f, 3.2f);
	SetToolBeamArcPoints(core, origin, targetPoint, wobble, phase);
	SetToolBeamArcPoints(glow, origin, targetPoint, wobble * 0.75f, phase + 1.3f);

	if (getGameTime() % 3 == 0)
	{
		EmitToolBeamImpact3D(targetPoint - direction * 1.5f, direction, coreColor);
	}
}

void onInit( CBlob@ this )
{	
	this.Tag("player");	 

	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	this.addCommandID("get out");
	this.addCommandID("shoot");
	this.addCommandID("construct");
	this.addCommandID("punch");
	this.addCommandID("giveBooty");
	this.addCommandID("releaseOwnership");
	this.addCommandID("swap tool");
	this.addCommandID(camera_sync_cmd);
	this.addCommandID("cycle");
	this.set_u16(SHIP_STAY_ID, 0);
	this.set_Vec2f(SHIP_STAY_POS, this.getPosition());
	this.set_f32(SHIP_STAY_Y, 0.0f);
	this.set_f32(SHIP_STAY_ANGLE, 0.0f);

	if ( getNet().isClient() )
	{
		CBlob@ core = getMothership( this.getTeamNum() );
		if (core !is null) 
		{

			this.setPosition( core.getPosition() );
			this.set_u16( SHIP_STAY_ID, core.getNetworkID() );
			this.set_Vec2f(SHIP_STAY_POS, core.getInterpolatedPosition());
			this.set_f32(SHIP_STAY_Y, GetBlob3DY(core));
			this.set_f32(SHIP_STAY_ANGLE, core.getAngleDegrees());
			//blob3d.setPosition(V2toV3(core.getPosition()));

			//BuildShopMenu( this, core, "mCore Block Transmitter", Vec2f(0,0) );
		}
	}
	
	this.SetMapEdgeFlags( u8(CBlob::map_collide_up) |
		u8(CBlob::map_collide_down) |
		u8(CBlob::map_collide_sides) );
	
	this.set_u32("menu time", 0);
	this.set_bool( "build menu open", false );
	this.set_string("last buy", "coupling");
	this.set_string("current tool", "fists");
	this.set_u32("fire time", 0);
	this.set_u32("punch time", 0);
	this.set_u32("groundTouch time", 0);
	this.set_bool( "onGround", true );//for syncing
	this.set_Vec2f(HUMAN_3D_NET_POS, this.getPosition());
	this.set_Vec2f(HUMAN_3D_NET_OLD_POS, this.getPosition());
	this.set_f32(HUMAN_3D_NET_Y, HUMAN_3D_SPAWN_Y);
	this.set_f32(HUMAN_3D_NET_OLD_Y, HUMAN_3D_SPAWN_Y);
	this.getShape().getVars().onground = true;
	directionalSoundPlay( "Respawn", this.getInterpolatedPosition(), 2.5f );


	if (!Texture::exists("pixel"))
	{
		Texture::createFromFile("pixel", "pixel.png");
	}

	EnsureHumanBlob3D(this);
}

Vec3f myPos(CBlob@ this)
{
	f32 x = this.get_f32("pos_x");
	f32 y =	this.get_f32("pos_y");
	f32 z =	this.get_f32("pos_z");
	return Vec3f(x,y,z);
}

Vec3f GetHumanBlob3DSpawnPosition(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	return Vec3f(pos.x, HUMAN_3D_SPAWN_Y, pos.y);
}

void RefreshHumanBlob3DOwner(CBlob@ this, Blob3D@ blob3d)
{
	if (this is null || blob3d is null)
	{
		return;
	}

	@blob3d.ownerBlob = this;
	blob3d.setPlayer(this.getPlayer());
}

Blob3D@ EnsureHumanBlob3D(CBlob@ this)
{
	if (this is null)
	{
		return null;
	}

	Blob3D@ blob3d;
	if (this.get("blob3d", @blob3d) && blob3d !is null)
	{
		RefreshHumanBlob3DOwner(this, blob3d);
		return @blob3d;
	}

	if (!getNet().isClient())
	{
		return null;
	}

	CPlayer@ player = this.getPlayer();
	if (player is null)
	{
		return null;
	}

	Vec3f spawnPosition = GetHumanBlob3DSpawnPosition(this);
	BoundingShape@ shape = BoundingCapsule(3.3f, 20.0f, spawnPosition);
	RigidBody@ rigidBody = RigidBody();
	Blob3D newBlob3D(this, player, spawnPosition, HUMAN_3D_TEAM, 2.0f, @shape, @rigidBody);
	if (newBlob3D !is null)
	{
		newBlob3D.transform.Orientation.x = this.get_f32("dir_x");
		newBlob3D.transform.Orientation.y = this.get_f32("dir_y");
		newBlob3D.shape.setPosition(spawnPosition);
		const bool simulateLocally = this.isMyPlayer();
		newBlob3D.rb.UseGravity = simulateLocally;
		newBlob3D.rb.GravityScale = 1.0f;
		if (simulateLocally)
		{
			newBlob3D.rb.Init(@newBlob3D);
			newBlob3D.shape.Init(@newBlob3D);
		}
		else
		{
			@newBlob3D.rb.parent = @newBlob3D;
			newBlob3D.shape.setCollides(false);
		}
		this.set("blob3d", @newBlob3D);
	}

	return @newBlob3D;
}

void PublishHumanCameraState(CBlob@ this, Blob3D@ blob3d)
{
	if (this is null || blob3d is null)
	{
		return;
	}

	this.set_f32("dir_x", blob3d.transform.Orientation.x);
	this.set_f32("dir_y", blob3d.transform.Orientation.y);
}

void ApplyHumanCameraStateToBlob3D(CBlob@ this)
{
	if (this is null)
	{
		return;
	}

	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d) || blob3d is null)
	{
		return;
	}

	blob3d.transform.Orientation.x = this.get_f32("dir_x");
	blob3d.transform.Orientation.y = this.get_f32("dir_y");
	blob3d.transform.Orientation.z = 0.0f;

	if (blob3d.shape !is null)
	{
		blob3d.shape.transform.Orientation.x = blob3d.transform.Orientation.x;
		blob3d.shape.transform.Orientation.y = 0.0f;
		blob3d.shape.transform.Orientation.z = 0.0f;
	}
}

bool ReadHumanReplicatedTransform(CBlob@ this, f32 &out oldX, f32 &out oldY, f32 &out oldZ, f32 &out x, f32 &out y, f32 &out z)
{
	if (this is null || !this.exists(HUMAN_3D_NET_POS) || !this.exists(HUMAN_3D_NET_Y))
	{
		return false;
	}

	Vec2f currentXZ = this.get_Vec2f(HUMAN_3D_NET_POS);
	const f32 currentY = this.get_f32(HUMAN_3D_NET_Y);
	Vec2f oldXZ = this.exists(HUMAN_3D_NET_OLD_POS) ? this.get_Vec2f(HUMAN_3D_NET_OLD_POS) : currentXZ;
	const f32 previousY = this.exists(HUMAN_3D_NET_OLD_Y) ? this.get_f32(HUMAN_3D_NET_OLD_Y) : currentY;

	oldX = oldXZ.x;
	oldY = previousY;
	oldZ = oldXZ.y;
	x = currentXZ.x;
	y = currentY;
	z = currentXZ.y;
	return true;
}

Vec3f LerpHumanTransform(const f32 oldX, const f32 oldY, const f32 oldZ, const f32 x, const f32 y, const f32 z, const f32 amount)
{
	return Vec3f(
		Maths::Lerp(oldX, x, amount),
		Maths::Lerp(oldY, y, amount),
		Maths::Lerp(oldZ, z, amount)
	);
}

void UpdateRemoteHumanNetworkState(CBlob@ this, Blob3D@ blob3d)
{
	if (!getNet().isClient() || this is null || blob3d is null || this.isMyPlayer() || this.isAttached())
	{
		return;
	}

	Vec3f position(this.getPosition().x, blob3d.transform.Position.y, this.getPosition().y);
	const f32 amount = Maths::Clamp01(getRules().get_f32("interFrameTime"));
	f32 oldX;
	f32 oldY;
	f32 oldZ;
	f32 x;
	f32 y;
	f32 z;
	if (ReadHumanReplicatedTransform(this, oldX, oldY, oldZ, x, y, z))
	{
		position = LerpHumanTransform(oldX, oldY, oldZ, x, y, z, amount);
	}

	blob3d.setPosition(position);
	if (blob3d.shape !is null)
	{
		blob3d.shape.setPosition(position);
		const f32 waterSurfaceY = GetOceanWaterHeight(position);
		blob3d.shape.inWater = waterSurfaceY - position.y >= -HUMAN_3D_WATER_EXIT_HEIGHT;
		blob3d.shape.onGround = this.get_bool("onGround");
	}

	blob3d.transform.Orientation.x = this.get_f32("dir_x");
	blob3d.transform.Orientation.y = this.get_f32("dir_y");
	blob3d.transform.Orientation.z = 0.0f;

	if (blob3d.shape !is null)
	{
		blob3d.shape.transform.Orientation.x = blob3d.transform.Orientation.x;
		blob3d.shape.transform.Orientation.y = 0.0f;
		blob3d.shape.transform.Orientation.z = 0.0f;
	}
}

void ReconcileLocalHumanNetworkState(CBlob@ this, Blob3D@ blob3d)
{
	if (!getNet().isClient() || getNet().isServer() || this is null || blob3d is null || !this.isMyPlayer() || this.isAttached())
	{
		return;
	}

	if (!this.exists(HUMAN_3D_NET_POS) || !this.exists(HUMAN_3D_NET_Y))
	{
		return;
	}

	f32 oldX;
	f32 oldY;
	f32 oldZ;
	f32 serverX;
	f32 serverY;
	f32 serverZ;
	if (!ReadHumanReplicatedTransform(this, oldX, oldY, oldZ, serverX, serverY, serverZ))
	{
		return;
	}

	Vec3f currentPosition(blob3d.transform.Position.x, blob3d.transform.Position.y, blob3d.transform.Position.z);
	Vec3f delta = Vec3f(
		serverX - currentPosition.x,
		serverY - currentPosition.y,
		serverZ - currentPosition.z
	);
	if (delta.LengthSquared() < HUMAN_3D_OWNER_CORRECTION_START * HUMAN_3D_OWNER_CORRECTION_START)
	{
		return;
	}

	Vec3f correctedPosition(currentPosition.x, currentPosition.y, currentPosition.z);
	if (delta.LengthSquared() >= HUMAN_3D_OWNER_CORRECTION_HARD_SNAP * HUMAN_3D_OWNER_CORRECTION_HARD_SNAP)
	{
		correctedPosition.x = serverX;
		correctedPosition.y = serverY;
		correctedPosition.z = serverZ;
	}
	else
	{
		correctedPosition.x += delta.x * HUMAN_3D_OWNER_CORRECTION_BLEND;
		correctedPosition.y += delta.y * HUMAN_3D_OWNER_CORRECTION_BLEND;
		correctedPosition.z += delta.z * HUMAN_3D_OWNER_CORRECTION_BLEND;
	}

	blob3d.setPosition(correctedPosition);
	if (blob3d.shape !is null)
	{
		blob3d.shape.setPosition(correctedPosition);
		blob3d.shape.onGround = this.get_bool("onGround");
	}
}

void EnsureHumanShape(Blob3D@ blob3d)
{
	if (blob3d is null || blob3d.shape !is null)
	{
		return;
	}

	@blob3d.shape = BoundingCapsule(3.3f, 20.0f, blob3d.transform.Position);
	blob3d.shape.Init(@blob3d);
}

void UpdateHumanSeatCollision(CBlob@ this, Blob3D@ blob3d)
{
	if (blob3d is null || blob3d.shape is null)
	{
		return;
	}

	const bool attached = this.isAttached();
	blob3d.shape.Attached = attached;
	blob3d.shape.setCollides(!attached);
}

void UpdateAttachedSeatTransform(CBlob@ this, Blob3D@ blob3d)
{
	if (!this.isAttached())
	{
		return;
	}

	blob3d.renderOffset = Vec3f();
	blob3d.renderRotation = Vec3f();

	CBlob@ seat = getBlobByNetworkID(this.get_u16(ATTACHED_SEAT_ID));
	if (seat is null)
	{
		return;
	}

	Blob3D@ seatBlob3d;
	if (!seat.get("blob3d", @seatBlob3d))
	{
		return;
	}

	Vec3f seatPos = getNet().isClient() ? seatBlob3d.getRenderPosition() : seatBlob3d.getPosition();
	if (seat.hasTag("flak") || seat.hasTag("harpoon"))
	{
		const f32 seatAngle = seat.get_f32("angle")-90;
		this.set_f32(HUMAN_SEAT_RENDER_YAW, -seatAngle);
		Vec2f backOffset(0.0f, -6.0f);
		backOffset.RotateBy(seatAngle);
		seatPos.x += backOffset.x;
		//seatPos.y -= 2.0f;
		seatPos.z += backOffset.y;
		blob3d.setPosition(seatPos);

		if (blob3d.shape !is null)
		{
			blob3d.shape.transform.Orientation.x = seatAngle;
			blob3d.shape.transform.Orientation.y = 0.0f;
			blob3d.shape.transform.Orientation.z = 0.0f;
		}

		return;
	}

	this.set_f32(HUMAN_SEAT_RENDER_YAW, -seatBlob3d.transform.Orientation.x+90);
	//seatPos.y += 2.0f;

	blob3d.setPosition(seatPos);

	if (blob3d.shape !is null)
	{
		blob3d.shape.transform.Orientation.x = seatBlob3d.transform.Orientation.x;
		blob3d.shape.transform.Orientation.y = 0.0f;
		blob3d.shape.transform.Orientation.z = 0.0f;
	}
}

void UpdateAttachedAim(CBlob@ this, Blob3D@ blob3d)
{
	if (!this.isMyPlayer() || !this.isAttached())
	{
		return;
	}

	if (ShouldSuspendHumanMouseAim(this))
	{
		return;
	}

	CControls@ controls = getControls();
	Driver@ driver = getDriver();
	Vec2f screenMid = driver.getScreenCenterPos();

	const u16 seatID = this.get_u16(ATTACHED_SEAT_ID);
	if (seatID != 0 && this.get_u16(SEAT_CAMERA_SNAP_ID) != seatID)
	{
		CBlob@ seat = getBlobByNetworkID(seatID);
		Blob3D@ seatBlob3d;
		if (seat !is null && seat.get("blob3d", @seatBlob3d))
		{
			blob3d.transform.Orientation.x = (seatBlob3d.transform.Orientation.x + 270.0f) % 360.0f;
			blob3d.transform.Orientation.y = 0.0f;
			this.set_f32("dir_x", blob3d.transform.Orientation.x);
			this.set_u16(SEAT_CAMERA_SNAP_ID, seatID);
			controls.setMousePosition(screenMid);
			return;
		}
	}

	Vec2f mouseDelta = controls.getMouseScreenPos() - screenMid;

	blob3d.transform.Orientation.x -= mouseDelta.x * 0.15f * Get3DCameraHorizontalMirrorSign();
	if (blob3d.transform.Orientation.x < 0.0f)
	{
		blob3d.transform.Orientation.x += 360.0f;
	}
	blob3d.transform.Orientation.x = blob3d.transform.Orientation.x % 360.0f;
	blob3d.transform.Orientation.y = Maths::Clamp(blob3d.transform.Orientation.y + mouseDelta.y * 0.15f, -60.0f, 60.0f);

	this.set_f32("dir_x", blob3d.transform.Orientation.x);
}

bool ShouldSuspendHumanMouseAim(CBlob@ this)
{
	CHUD@ hud = getHUD();
	return !isWindowActive()
		|| !isWindowFocused()
		|| Menu::getMainMenu() !is null
		|| get_active_wheel_menu() !is null
		|| block_menu
		|| (hud !is null && (hud.hasButtons() || hud.hasMenus()))
		|| this.get_bool("build menu open");
}

void UpdateFreeHumanShapeRotation(CBlob@ this, Blob3D@ blob3d)
{
	if (this.isAttached() || blob3d.shape is null)
	{
		return;
	}

	blob3d.shape.transform.Orientation.x = blob3d.transform.Orientation.x;
	blob3d.shape.transform.Orientation.y = 0.0f;
	blob3d.shape.transform.Orientation.z = 0.0f;
}

bool IsHumanGrounded(CBlob@ this, Blob3D@ blob3d)
{
	if (this.isAttached())
	{
		return true;
	}

	return AreHumanFeetGrounded(this, blob3d);
}

void SetHumanGrounded(CBlob@ this, Blob3D@ blob3d, bool grounded)
{
	this.getShape().getVars().onground = grounded;
	this.set_bool("onGround", grounded);
	if (blob3d.shape !is null)
	{
		blob3d.shape.onGround = grounded;
	}
}

void ClearHumanShipRenderOffset(CBlob@ this, Blob3D@ blob3d)
{
	if (blob3d is null)
	{
		return;
	}

	blob3d.renderRotation = Vec3f();
	blob3d.renderOffset = Vec3f();
}

void UpdateAimPosition3D(CBlob@ this)
{
	if (!this.isMyPlayer() || ShouldSuspendHumanMouseAim(this))
	{
		return;
	}

	Raycast3D::Ray3D ray;
	if (!Raycast3D::GetPlayerAimRay(this, ray))
	{
		return;
	}

	Raycast3D::RaycastHit3D blockHit;
	if (Raycast3D::RaycastBlockTarget(ray, Raycast3D::BLOCK_RAY_START_EPSILON, Raycast3D::BUILD_RAY_DISTANCE, this, blockHit) && blockHit.blob !is null)
	{
		this.set_Vec2f("aim_pos", blockHit.blob.getPosition());
		return;
	}

	Raycast3D::RaycastHit3D planeHit;
	if (RaycastHumanWaveAimSurface(this, ray, planeHit))
	{
		this.set_Vec2f("aim_pos", planeHit.point.xz());
	}
}

bool RaycastHumanWaveAimSurface(CBlob@ this, Raycast3D::Ray3D ray, Raycast3D::RaycastHit3D &out hit)
{
	Island@ island = getIsland(this);
	if (island is null)
	{
		return Raycast3D::RaycastYPlane(ray, Raycast3D::GetBuildPlaneY(this), Raycast3D::BUILD_RAY_DISTANCE, hit);
	}

	Vec3f planePoint(island.pos.x, GetIslandWaveVisualY(island, Vec2f_zero), island.pos.y);
	Vec3f planeNormal(-island.waveSlopeX, 1.0f, -island.waveSlopeZ);
	return Raycast3D::RaycastPlane(ray, planePoint, planeNormal, Raycast3D::BUILD_RAY_DISTANCE, hit);
}

CBlob@ GetShipStayReference(CBlob@ shipBlob)
{
	if (shipBlob is null)
	{
		return null;
	}

	Island@ island = getIsland(shipBlob.getShape().getVars().customData);
	if (island !is null && island.centerBlock !is null)
	{
		return island.centerBlock;
	}

	return shipBlob;
}

f32 GetBlob3DY(CBlob@ blob)
{
	Blob3D@ blob3d;
	if (blob !is null && blob.get("blob3d", @blob3d) && blob3d !is null)
	{
		return blob3d.transform.Position.y;
	}

	return 0.0f;
}

f32 GetShipStaySurfaceY(CBlob@ shipBlob, CBlob@ referenceBlob)
{
	if (shipBlob !is null)
	{
		return GetBlob3DY(shipBlob);
	}

	return GetBlob3DY(referenceBlob);
}

void CacheShipStayTransform(CBlob@ this, CBlob@ shipBlob)
{
	CBlob@ referenceBlob = GetShipStayReference(shipBlob);
	if (referenceBlob is null)
	{
		return;
	}

	this.set_u16(SHIP_STAY_ID, referenceBlob.getNetworkID());
	this.set_Vec2f(SHIP_STAY_POS, referenceBlob.getInterpolatedPosition());
	this.set_f32(SHIP_STAY_Y, GetShipStaySurfaceY(shipBlob, referenceBlob));
	this.set_f32(SHIP_STAY_ANGLE, referenceBlob.getAngleDegrees());
}

void ApplyShipStayMotion(CBlob@ this, Blob3D@ blob3d, CBlob@ shipBlob)
{
	CBlob@ referenceBlob = GetShipStayReference(shipBlob);
	if (referenceBlob is null)
	{
		return;
	}

	if (this.get_u16(SHIP_STAY_ID) != referenceBlob.getNetworkID())
	{
		CacheShipStayTransform(this, shipBlob);
		return;
	}

	Vec2f oldShipPos = this.get_Vec2f(SHIP_STAY_POS);
	Vec2f newShipPos = referenceBlob.getInterpolatedPosition();
	f32 oldShipY = this.get_f32(SHIP_STAY_Y);
	f32 newShipY = GetShipStaySurfaceY(shipBlob, referenceBlob);
	f32 oldShipAngle = this.get_f32(SHIP_STAY_ANGLE);
	f32 newShipAngle = referenceBlob.getAngleDegrees();

	Vec2f newPlayerPos = blob3d.transform.Position.xz();
	Vec2f playerOffset = newPlayerPos - oldShipPos;
	playerOffset.RotateBy(newShipAngle - oldShipAngle);
	newPlayerPos = oldShipPos + playerOffset + (newShipPos - oldShipPos);

	blob3d.transform.Position.x = newPlayerPos.x;
	blob3d.transform.Position.y += newShipY - oldShipY;
	blob3d.transform.Position.z = newPlayerPos.y;
	this.setPosition(newPlayerPos);
	if (blob3d.shape !is null)
	{
		blob3d.shape.setPosition(blob3d.transform.Position);
	}

	this.set_Vec2f(SHIP_STAY_POS, newShipPos);
	this.set_f32(SHIP_STAY_Y, newShipY);
	this.set_f32(SHIP_STAY_ANGLE, newShipAngle);
}

void onTick( CBlob@ this )
{	
	Blob3D@ blob3d = EnsureHumanBlob3D(this);
	if (blob3d is null) { return; }

	EnsureHumanShape(blob3d);
	UpdateRemoteHumanNetworkState(this, blob3d);
	ReconcileLocalHumanNetworkState(this, blob3d);

	const bool remoteClient = getNet().isClient() && !getNet().isServer() && !this.isMyPlayer();
	if (remoteClient && !this.isAttached())
	{
		return;
	}

	UpdateAttachedAim(this, blob3d);
	UpdateAttachedSeatTransform(this, blob3d);
	UpdateHumanSeatCollision(this, blob3d);
	UpdateFreeHumanShapeRotation(this, blob3d);

	blob3d.onTick();

	this.setPosition(blob3d.getPosition().xz());

	ClearHumanShipRenderOffset(this, blob3d);
	UpdateAimPosition3D(this);

	Update( this );
	UpdateToolBeam3D(this, blob3d);

	u32 gameTime = getGameTime();

	if (this.isMyPlayer())
	{
		PublishHumanCameraState(this, blob3d);
		if (gameTime % HUMAN_3D_SYNC_RATE == 0)
		{
			SyncCamera(this);
		}

		PlayerControls( this );

		if ( gameTime % 10 == 0 )
		{
			this.set_bool( "onGround", IsHumanGrounded(this, blob3d) );
			this.Sync( "onGround", false );
		}	
	}

	CSprite@ sprite = this.getSprite();
    CSpriteLayer@ laser = sprite.getSpriteLayer( "laser" );

	//kill laser after a certain time
	if ( laser !is null && !this.isKeyPressed(key_action1) && this.get_u32("fire time") + CONSTRUCT_RATE < gameTime )
	{
		sprite.RemoveSpriteLayer("laser");
	}
	
	// stop reclaim effects
	if (this.isKeyJustReleased(key_action1) || this.isAttached())
	{
		this.set_bool( "reclaimPropertyWarn", false );
		if ( sprite.getEmitSoundPaused() == false )
		{
			sprite.SetEmitSoundPaused(true);
		}
		sprite.RemoveSpriteLayer("laser");
	}
}

void Update( CBlob@ this )
{
	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d)) { return; }

	const bool myPlayer = this.isMyPlayer();
	const f32 camRotation = blob3d.transform.Orientation.x; //change to cam3d dirx
	const bool attached = this.isAttached();

	Vec2f pos = this.getPosition();//sat_shape.Pos;	
	Vec2f aimpos = this.getAimPos();
	Vec2f forward = aimpos - pos;
	CShape@ shape = this.getShape();
	CSprite@ sprite = this.getSprite();
	
	string currentTool = this.get_string( "current tool" );
	
	if (!attached)
	{
		const bool action1 = this.isKeyPressed( key_action1 );
		const u32 time = getGameTime();
		const f32 vellen = shape.vellen;
		CMap@ map = this.getMap();
		const bool solidGround = IsHumanGrounded(this, blob3d);
		SetHumanGrounded(this, blob3d, solidGround);
		if ( !this.wasOnGround() && solidGround )
			this.set_u32("groundTouch time", time);//used on collisions
		
		//tool actions
		if (!Human::isHoldingBlocks(this))
		{
			if (action1)
			{
				if (currentTool == "fists" && canPunch(this))
				{
					Punch( this );
					sprite.SetAnimation("punch");				
				}
				else if ( currentTool == "pistol" && canShootPistol( this ) ) // shoot
				{
					ShootPistol( this );
					sprite.SetAnimation("shoot");
				}
				else if ( currentTool == "reconstructor" ) //repair
				{
					Construct( this );
					sprite.SetAnimation("repair");
				}
				else if ( currentTool == "deconstructor" ) //reclaim
				{
					Construct( this );
					sprite.SetAnimation("reclaim");
				}
			}
		}			

		// artificial stay on ship
		if ( getNet().isServer() || myPlayer )
		{
			CBlob@ islandBlob = getIslandBlob( this );
			if (solidGround && islandBlob !is null)
			{
				ApplyShipStayMotion(this, blob3d, islandBlob);
				CacheShipStayTransform(this, islandBlob);
			}
			else
			{
				this.set_u16( SHIP_STAY_ID, 0 );
			}
		}
	}
	else
	{
		SetHumanGrounded(this, blob3d, true);
	}
}

void PlayerControls( CBlob@ this )
{
	CHUD@ hud = getHUD();
	CControls@ controls = getControls();
	CSprite@ sprite = this.getSprite();
	
	if (this.isAttached())
	{
	    // get out of seat
		if (this.isKeyJustPressed(key_use))
		{
			CBitStream params;
			this.SendCommand( this.getCommandID("get out"), params );
		}			
	}
	else
	{
		if (HasRaycastInteractTarget(this))
		{
			if (this.isKeyJustPressed(key_use))
			{
				TryUseRaycastInteract(this);
			}
			this.ClearMenus();
			this.ClearButtons();
			return;
		}

		// use menu
	    if (this.isKeyJustPressed(key_use))
	    {
	        useClickTime = getGameTime();
	    }
	    if (this.isKeyPressed(key_use))
	    {
	        this.ClearMenus();
			this.ClearButtons();
	        this.ShowInteractButtons();
	    }
	    else if (this.isKeyJustReleased(key_use))
	    {
	    	bool tapped = (getGameTime() - useClickTime) < 10; 
			this.ClickClosestInteractButton( tapped ? this.getPosition() : this.getAimPos(), this.getRadius()*2 );

	        this.ClearButtons();
	    }	  
	}

	//// click action1 to click buttons
	//if (hud.hasButtons() && this.isKeyPressed(key_action1) && !this.ClickClosestInteractButton( this.getAimPos(), 2.0f ))
	//{
	//}

	// click grid menus

    if (hud.hasButtons())
    {
        if (this.isKeyJustPressed(key_action1))
        {
		    CGridMenu @gmenu;
		    CGridButton @gbutton;
		    this.ClickGridMenu(0, gmenu, gbutton); 
	    }
	}

}

bool HasRaycastInteractTarget( CBlob@ this )
{
	u16 targetID;
	string promptLabel;
	return Raycast3D::GetInteractTarget(this, targetID, promptLabel);
}

bool TryUseRaycastInteract( CBlob@ this )
{
	u16 targetID;
	string promptLabel;
	if (!Raycast3D::GetInteractTarget(this, targetID, promptLabel))
	{
		return false;
	}

	CBlob@ target = getBlobByNetworkID(targetID);
	if (target is null)
	{
		return false;
	}

	CBitStream params;
	params.write_u16(this.getNetworkID());
	this.ClearButtons();
	this.ClearMenus();
	target.SendCommand(target.getCommandID("get in seat"), params);
	return true;
}


void Punch( CBlob@ this )
{
	Vec2f pos = this.getPosition();
	Vec2f aimVector = Vec2f(1,0).RotateBy(this.get_f32("dir_x") + 90.0f);
	
    HitInfo@[] hitInfos;
    if ( this.getMap().getHitInfosFromCircle( pos, this.getRadius()*4.0f, this, @hitInfos) )
	{
		for (uint i = 0; i < hitInfos.length; i++)
		{
			CBlob @b = hitInfos[i].blob;
			if (b is null)
				continue;
			//dirty fix: get occupier if seat
			if( b.hasTag( "seat" ) )
			{
				AttachmentPoint@ seat = b.getAttachmentPoint(0);
				@b = seat.getOccupied();
			}
			if (b !is null && b.getName() == "human" && b.getTeamNum() != this.getTeamNum())
			{
				if (this.isMyPlayer())
				{
					CBitStream params;
					params.write_u16( b.getNetworkID() );
					this.SendCommand( this.getCommandID("punch"), params );
				}
				return;
			}
		}
	}

	// miss
	directionalSoundPlay( "throw", pos );
	this.set_u32("punch time", getGameTime());	
}

void ShootPistol( CBlob@ this )
{
	if ( !this.isMyPlayer() )
		return;

	Bullet3DDebugShoot("ShootPistol begin shooterID=" + this.getNetworkID() + " pos2d=" + Bullet3DDebugVec2(this.getPosition()));

	Vec2f pos = this.getPosition();
	Vec3f launchDirection;
	const bool usedCameraForward = GetLocalCameraForwardAxis(this, launchDirection);
	launchDirection.y+=0.01;
	if (!usedCameraForward)
	{
		Vec2f fallbackAim = Vec2f(1,0).RotateBy(this.get_f32("dir_x") + 90.0f);
		fallbackAim.Normalize();
		launchDirection = Vec3f(fallbackAim.x, 0.0f, fallbackAim.y);
	}
	launchDirection = launchDirection.Normalize();
	launchDirection = ApplyBulletSpread3D(launchDirection);
	Bullet3DDebugShoot("launchDirection=" + Bullet3DDebugVec3(launchDirection) + " cameraForward=" + Bullet3DDebugBool(usedCameraForward));

	Vec2f aimVector = Human3DXZ(launchDirection);
	if (aimVector.LengthSquared() <= 0.0001f)
	{
		aimVector = Vec2f(1,0).RotateBy(this.get_f32("dir_x") + 90.0f);
	}
	aimVector.Normalize();

	Vec2f vel = aimVector * BULLET_SPEED;
	Vec3f velocity3D(vel.x, launchDirection.y * BULLET_SPEED, vel.y);
	Bullet3DDebugShoot("velocity2d=" + Bullet3DDebugVec2(vel) + " velocity3d=" + Bullet3DDebugVec3(velocity3D));

	Blob3D@ shooter3D;
	this.get("blob3d", @shooter3D);
	Vec3f muzzlePivot = GetHumanMuzzlePivot3D(this, shooter3D);

	f32 bodyYaw = this.get_f32("dir_x");
	if (shooter3D !is null)
	{
		if (shooter3D.shape !is null)
		{
			bodyYaw = shooter3D.shape.transform.Orientation.x;
		}
		else
		{
			bodyYaw = shooter3D.transform.Orientation.x;
		}
	}

	Vec2f bodyForward2D(1.0f, 0.0f);
	bodyForward2D.RotateBy(bodyYaw + 90.0f);
	if (bodyForward2D.LengthSquared() <= 0.0001f)
	{
		bodyForward2D = aimVector;
	}
	bodyForward2D.Normalize();

	Vec3f barrelForward(bodyForward2D.x, 0.0f, bodyForward2D.y);
	Vec3f barrelRight(-bodyForward2D.y, 0.0f, bodyForward2D.x);
	Vec3f spawnPosition3D = muzzlePivot;
	spawnPosition3D += barrelForward * BULLET_3D_BARREL_FORWARD;
	spawnPosition3D += barrelRight * BULLET_3D_BARREL_RIGHT;
	Bullet3DMuzzleDebug("pivot=" + Bullet3DDebugVec3(muzzlePivot)
		+ " spawn=" + Bullet3DDebugVec3(spawnPosition3D)
		+ " bodyYaw=" + bodyYaw
		+ " bodyForward=" + Bullet3DDebugVec3(barrelForward)
		+ " shotForward=" + Bullet3DDebugVec3(launchDirection));

	f32 lifetime = Maths::Min( 0.05f + BULLET_RANGE/BULLET_SPEED/4.0f, 4.0f);

	CBitStream params;
	params.write_Vec2f( vel );
	params.write_f32( lifetime );
	params.write_f32( spawnPosition3D.y );
	params.write_f32( velocity3D.x );
	params.write_f32( velocity3D.y );
	params.write_f32( velocity3D.z );

	Island@ island = getIsland( this );
	if ( island !is null && island.centerBlock !is null )//relative positioning
	{
		params.write_bool( true );
		Vec2f rPos = Human3DXZ(spawnPosition3D) - island.centerBlock.getPosition();
		params.write_Vec2f( rPos );
		u32 islandColor = island.centerBlock.getShape().getVars().customData;
		params.write_u32( islandColor );
	} else//absolute positioning
	{
		params.write_bool( false );
		Vec2f aPos = Human3DXZ(spawnPosition3D);
		params.write_Vec2f( aPos );
	}
	
	this.SendCommand( this.getCommandID("shoot"), params );
	EmitMuzzleParticles3D(spawnPosition3D, barrelForward, Human3DXZ(spawnPosition3D), 0.75f);
	Bullet3DDebugShoot("ShootPistol command sent");
}

void Construct( CBlob@ this )
{
	Vec2f pos = this.getPosition();
    Vec2f aimPos = this.get_Vec2f("aim_pos");    
    f32 aim_height = this.get_f32("aim_height");

	CBlob@ mBlob = getMap().getBlobAtPosition( aimPos );
	Vec2f aimVector = aimPos - pos;

	Vec2f offset(_shotspreadrandom.NextFloat() * BULLET_SPREAD,0);
	offset.RotateBy(_shotspreadrandom.NextFloat() * 360.0f, Vec2f());
	CSprite@ sprite = this.getSprite();
	
	string currentTool = this.get_string( "current tool" );

	if (mBlob !is null && aimVector.getLength() <= CONSTRUCT_RANGE)
	{
		if ( this.isMyPlayer() )
		{
			CBitStream params;
			params.write_Vec2f( pos );
			params.write_Vec2f( aimPos );
			params.write_netid( mBlob.getNetworkID() );
			
			this.SendCommand( this.getCommandID("construct"), params );
		}
		if ( sprite.getEmitSoundPaused() == true )
		{
			sprite.SetEmitSoundPaused(false);
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

bool canPunch( CBlob@ this )
{
	return !this.hasTag( "dead" ) && this.get_u32("punch time") + PUNCH_RATE < getGameTime();
}

bool canShootPistol( CBlob@ this )
{
	return !this.hasTag( "dead" ) && this.get_string( "current tool" ) == "pistol" && this.get_u32("fire time") + FIRE_RATE < getGameTime();
}

bool canConstruct( CBlob@ this )
{
	return !this.hasTag( "dead" ) && (this.get_string( "current tool" ) == "deconstructor" || this.get_string( "current tool" ) == "reconstructor")
				&& !Human::isHoldingBlocks(this)
				&& this.get_u32("fire time") + CONSTRUCT_RATE < getGameTime();
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
	if (cmd == this.getCommandID(camera_sync_cmd))
	{
		const bool apply = !canSend(this);
		HandleCamera(this, params, apply);
		if (apply)
		{
			ApplyHumanCameraStateToBlob3D(this);
		}
	}

	if (getNet().isServer() && this.getCommandID("get out") == cmd){
		this.server_DetachFromAll();
	}
	else if (this.getCommandID("punch") == cmd  && canPunch( this ) )
	{
		CBlob@ b = getBlobByNetworkID( params.read_u16() );
		if (b !is null && b.getName() == "human" && b.getDistanceTo( this ) < 100.0f)
		{
			Vec2f pos = b.getPosition();
			this.set_u32("punch time", getGameTime());
			directionalSoundPlay( "Kick.ogg", pos );
			ParticleBloodSplat( pos, false );

			if ( getNet().isServer() )
				this.server_Hit( b, pos, Vec2f_zero, 0.25f, 0, false );
		}
	}
	else if (this.getCommandID("shoot") == cmd && canShootPistol( this ) )
	{
		Bullet3DDebugShoot("onCommand shoot begin server=" + Bullet3DDebugBool(getNet().isServer()) + " shooterID=" + this.getNetworkID());
		Vec2f velocity = params.read_Vec2f();
		f32 lifetime = params.read_f32();
		f32 spawnY = params.read_f32();
		Vec3f velocity3D(params.read_f32(), params.read_f32(), params.read_f32());
		Vec2f pos;
		Bullet3DDebugShoot("onCommand params vel2d=" + Bullet3DDebugVec2(velocity) + " lifetime=" + lifetime + " spawnY=" + spawnY + " vel3d=" + Bullet3DDebugVec3(velocity3D));
		
		if ( params.read_bool() )//relative positioning
		{
			Vec2f rPos = params.read_Vec2f();
			int islandColor = params.read_u32();
			Bullet3DDebugShoot("onCommand relative rPos=" + Bullet3DDebugVec2(rPos) + " islandColor=" + islandColor);
			Island@ island = getIsland( islandColor );
			if ( island !is null && island.centerBlock !is null )
			{
				pos = rPos + island.centerBlock.getPosition();
				velocity += island.vel;
				Bullet3DDebugShoot("onCommand relative resolved pos=" + Bullet3DDebugVec2(pos));
			}
			else
			{
				warn( "BulletSpawn: island or centerBlock is null" );
				pos = this.getPosition();//failsafe (bullet will spawn lagging behind player)
				Bullet3DDebugShoot("onCommand relative fallback pos=" + Bullet3DDebugVec2(pos));
			}
		}
		else
		{
			pos = params.read_Vec2f();
			Bullet3DDebugShoot("onCommand absolute pos=" + Bullet3DDebugVec2(pos));
		}

		velocity3D.x = velocity.x;
		velocity3D.z = velocity.y;
		
		if (getNet().isServer())
		{
			Bullet3DDebugShoot("server_CreateBlobNoInit begin");
            CBlob@ bullet = server_CreateBlobNoInit( "bullet" );
            if (bullet !is null)
            {
				Bullet3DDebugShoot("server_CreateBlobNoInit ok bulletID=" + bullet.getNetworkID());
            	if (this.getPlayer() !is null){
                	bullet.SetDamageOwnerPlayer( this.getPlayer() );
                } 

				bullet.server_setTeamNum(this.getTeamNum());
				bullet.setPosition(pos);
				bullet.setVelocity( velocity );
				Bullet3DDebugShoot("bullet base fields set pos2d=" + Bullet3DDebugVec2(pos) + " vel2d=" + Bullet3DDebugVec2(velocity));
				bullet.set_f32(BULLET_3D_POS_Y, spawnY);
				bullet.set_f32(BULLET_3D_VEL_X, velocity3D.x);
				bullet.set_f32(BULLET_3D_VEL_Y, velocity3D.y);
				bullet.set_f32(BULLET_3D_VEL_Z, velocity3D.z);
				bullet.set_u16(BULLET_3D_IGNORE_ID, this.getNetworkID());
				Bullet3DDebugShoot("bullet 3d fields set; Init begin");
				bullet.Init();
				Bullet3DDebugShoot("bullet Init end");
				bullet.setVelocity( velocity );
				bullet.server_SetTimeToDie( lifetime );
				Bullet3DDebugShoot("bullet lifetime set");
            }
			else
			{
				Bullet3DDebugShoot("server_CreateBlobNoInit returned null");
			}
		}
		
		this.set_u32("fire time", getGameTime());	
		Bullet3DDebugShoot("effects begin");
		if (getNet().isClient() && !this.isMyPlayer())
		{
			Vec3f muzzlePosition3D(pos.x, spawnY, pos.y);
			f32 remoteBodyYaw = this.get_f32("dir_x");
			Blob3D@ remoteShooter3D;
			if (this.get("blob3d", @remoteShooter3D) && remoteShooter3D !is null)
			{
				if (remoteShooter3D.shape !is null)
				{
					remoteBodyYaw = remoteShooter3D.shape.transform.Orientation.x;
				}
				else
				{
					remoteBodyYaw = remoteShooter3D.transform.Orientation.x;
				}
			}
			Vec2f remoteForward2D(1.0f, 0.0f);
			remoteForward2D.RotateBy(remoteBodyYaw + 90.0f);
			remoteForward2D.Normalize();
			Vec3f muzzleForward(remoteForward2D.x, 0.0f, remoteForward2D.y);
			EmitMuzzleParticles3D(muzzlePosition3D, muzzleForward, pos, 0.75f);
		}
		directionalSoundPlay( "Gunshot.ogg", pos, 0.75f );
		Bullet3DDebugShoot("onCommand shoot end");
	}
	else if (this.getCommandID("construct") == cmd && canConstruct( this ) )
	{
		Vec2f pos = params.read_Vec2f();
		Vec2f aimPos = params.read_Vec2f();
		CBlob@ mBlob = getBlobByNetworkID( params.read_netid() );
		
		CPlayer@ thisPlayer = this.getPlayer();						
		if ( thisPlayer is null ) 
			return;		
		
		string currentTool = this.get_string( "current tool" );
		Vec2f aimVector = aimPos - pos;	 
		
		if (mBlob !is null)
		{		
			CRules@ rules = getRules();
			const int blockType = mBlob.getSprite().getFrame();
			Island@ island = getIsland( mBlob.getShape().getVars().customData );
				
			const f32 mBlobCost = mBlob.get_u32("cost");
			f32 mBlobHealth = mBlob.getHealth();
			f32 mBlobInitHealth = mBlob.getInitialHealth();
			const f32 initialReclaim = mBlob.get_f32("initial reclaim");
			f32 currentReclaim = mBlob.get_f32("current reclaim");
			
			f32 fullConstructAmount;
			if ( mBlobCost > 0 )
				fullConstructAmount = (CONSTRUCT_VALUE/mBlobCost)*initialReclaim;
			else if ( blockType == Block::SHIPCORE )
				fullConstructAmount = (0.01f)*mBlobInitHealth;
			else
				fullConstructAmount = 0.0f;
							
			if ( island !is null)
			{
				string islandOwnerName = island.owner;
				CBlob@ mBlobOwnerBlob = getBlobByNetworkID(mBlob.get_u16( "ownerID" ));
				
				if ( currentTool == "deconstructor" && !(blockType == Block::SHIPCORE) && mBlobCost > 0 )
				{
					f32 deconstructAmount = 0;
					if ( islandOwnerName == "" 
						|| (islandOwnerName == "" && mBlob.get_string( "playerOwner" ) == "")
						|| islandOwnerName == thisPlayer.getUsername() 
						|| mBlob.get_string( "playerOwner" ) == thisPlayer.getUsername()
						|| blockType == Block::STATION)
					{
						deconstructAmount = fullConstructAmount; 
					}
					else
					{
						deconstructAmount = (1.0f/mBlobCost)*initialReclaim; 
						this.set_bool( "reclaimPropertyWarn", true );
					}
					
					if ( blockType != Block::STATION && island.isStation && mBlob.getTeamNum() != this.getTeamNum() )
					{
						deconstructAmount = (1.0f/mBlobCost)*initialReclaim; 
						this.set_bool( "reclaimPropertyWarn", true );					
					}
					
					if ( (currentReclaim - deconstructAmount) <=0 )
					{		
						if ( blockType == Block::STATION )
						{
							if ( mBlob.getTeamNum() != this.getTeamNum() && mBlob.getTeamNum() != 255 )
							{
								mBlob.server_setTeamNum( 255 );
								mBlob.getSprite().SetFrame( Block::STATION );
							}
						}
						else
						{
							string cName = thisPlayer.getUsername();
							u16 cBooty = server_getPlayerBooty( cName );

							server_setPlayerBooty( cName, cBooty + mBlobCost*(mBlobHealth/mBlobInitHealth) );
							directionalSoundPlay( "/ChaChing.ogg", pos );
							mBlob.Tag( "disabled" );
							mBlob.server_Die();
						}
					}
					else
						mBlob.set_f32("current reclaim", currentReclaim - deconstructAmount);
				}
				else if ( currentTool == "reconstructor" )
				{			
					f32 reconstructAmount = 0;
					u16 reconstructCost = 0;
					string cName = thisPlayer.getUsername();
					u16 cBooty = server_getPlayerBooty( cName );
					
					if ( blockType == Block::SHIPCORE )
					{
						const f32 motherInitHealth = 8.0f;
						if ( (mBlobHealth + reconstructAmount) <= motherInitHealth  )
						{
							reconstructAmount = fullConstructAmount;
							reconstructCost = CONSTRUCT_VALUE;
						}
						else if ( (mBlobHealth + reconstructAmount) > motherInitHealth  )
						{
							reconstructAmount = motherInitHealth - mBlobHealth;
							reconstructCost = (CONSTRUCT_VALUE - CONSTRUCT_VALUE*(reconstructAmount/fullConstructAmount));
						}
						
						if ( cBooty >= reconstructCost && mBlobHealth < motherInitHealth )
						{
							mBlob.server_SetHealth( mBlobHealth + reconstructAmount );
							server_setPlayerBooty( cName, cBooty - reconstructCost );
						}
					}
					else if ( blockType == Block::STATION )
					{							
						if ( (currentReclaim + reconstructAmount) <= initialReclaim )
						{
							reconstructAmount = fullConstructAmount;
							reconstructCost = CONSTRUCT_VALUE;
						}
						else if ( (currentReclaim + reconstructAmount) > initialReclaim  )
						{
							reconstructAmount = initialReclaim - currentReclaim;
							reconstructCost = CONSTRUCT_VALUE - CONSTRUCT_VALUE*(reconstructAmount/fullConstructAmount);
							
							if ( mBlob.getTeamNum() == 255 ) //neutral
							{
								mBlob.server_setTeamNum( this.getTeamNum() );
								mBlob.getSprite().SetFrame( Block::STATION );
							}
						}
						
						mBlob.set_f32("current reclaim", currentReclaim + reconstructAmount);
					}
					else if ( currentReclaim < initialReclaim )
					{					
						if ( (currentReclaim + reconstructAmount) <= initialReclaim )
						{
							reconstructAmount = fullConstructAmount;
							reconstructCost = CONSTRUCT_VALUE;
						}
						else if ( (currentReclaim + reconstructAmount) > initialReclaim  )
						{
							reconstructAmount = initialReclaim - currentReclaim;
							reconstructCost = CONSTRUCT_VALUE - CONSTRUCT_VALUE*(reconstructAmount/fullConstructAmount);
						}
						
						if ( (currentReclaim + reconstructAmount > mBlobHealth) && cBooty >= reconstructCost)
						{
							mBlob.server_SetHealth( mBlobHealth + reconstructAmount );
							mBlob.set_f32("current reclaim", currentReclaim + reconstructAmount);
							server_setPlayerBooty( cName, cBooty - reconstructCost );
						}
						else if ( (currentReclaim + reconstructAmount) < mBlobHealth )
							mBlob.set_f32("current reclaim", currentReclaim + reconstructAmount);
					}
					
					if ( currentReclaim >= initialReclaim*0.75f )	//visually repair block
					{
						CSprite@ mBlobSprite = mBlob.getSprite();
						for (uint frame = 0; frame < 11; ++frame)
						{
							mBlobSprite.RemoveSpriteLayer("dmg"+frame);
						}
					}
				}
			}
		}
		
		this.set_u32("fire time", getGameTime());
	}
	else if ( getNet().isServer() && this.getCommandID( "releaseOwnership" ) == cmd )
	{
		CPlayer@ player = this.getPlayer();
		CBlob@ seat = getBlobByNetworkID( params.read_u16() );
		
		if ( player is null || seat is null ) return;
	
		string owner;
		seat.get( "playerOwner", owner );
		if ( owner == player.getUsername() )
		{
			print( "$ " + owner + " released seat" );
			owner = "";
			seat.set( "playerOwner", owner );
			seat.set_string( "playerOwner", "" );
			seat.Sync( "playerOwner", true );
		}
	}
	else if ( getNet().isServer() && this.getCommandID( "giveBooty" ) == cmd )//transfer booty
	{
		CRules@ rules = getRules();
		if ( getGameTime() < rules.get_u16( "warmup_time" ) )	return;
			
		u8 teamNum = this.getTeamNum();
		CPlayer@ player = this.getPlayer();
		string cName = getCaptainName( teamNum );		
		CPlayer@ captain = getPlayerByUsername( cName );
		
		if ( captain is null || player is null ) return;
		
		u16 transfer = rules.get_u16( "booty_transfer" );
		u16 fee = Maths::Round( transfer * rules.get_f32( "booty_transfer_fee" ) );		
		string pName = player.getUsername();
		u16 playerBooty = server_getPlayerBooty( pName );
		if ( playerBooty < transfer + fee )	return;
			
		if ( player !is captain )
		{
			print( "$ " + pName + " transfers Booty to captain " + cName );
			u16 captainBooty = server_getPlayerBooty( cName );
			server_setPlayerBooty( pName, playerBooty - transfer - fee );
			server_setPlayerBooty( cName, captainBooty + transfer );
		} else
		{
			CBlob@ core = getMothership( teamNum );
			if ( core !is null )
			{
				int coreColor = core.getShape().getVars().customData;
				CBlob@[] crew;
				CBlob@[] humans;
				getBlobsByName( "human", @humans );
				for ( u8 i = 0; i < humans.length; i++ )
					if ( humans[i].getTeamNum() == teamNum && humans[i] !is this )
					{
						CBlob@ islandBlob = getIslandBlob( humans[i] );
						if ( islandBlob !is null && islandBlob.getShape().getVars().customData == coreColor )
							crew.push_back( humans[i] );
					}
				
				if ( crew.length > 0 )
				{
					print( "$ " + pName + " transfers Booty to crew" );
					server_setPlayerBooty( pName, playerBooty - transfer - fee );
					u16 shareBooty = Maths::Floor( transfer/crew.length );
					for ( u8 i = 0; i < crew.length; i++ )
					{
						CPlayer@ crewPlayer = crew[i].getPlayer();						
						if ( player is null ) continue;
						
						string cName = crewPlayer.getUsername();
						u16 cBooty = server_getPlayerBooty( cName );

						server_setPlayerBooty( cName, cBooty + shareBooty );
					}
				}
			}
		}
	}
	else if ( this.getCommandID( "swap tool" ) == cmd )
	{
		u16 netID = params.read_u16();
		string tool = params.read_string();
		CPlayer@ player = this.getPlayer();
		
		if ( player is null ) return;

		if (tool != "fists" && tool != "pistol" && tool != "deconstructor" && tool != "reconstructor")
		{
			return;
		}

		this.getSprite().SetEmitSound("/ReclaimSound.ogg");
		this.getSprite().SetEmitSoundVolume(0.5f);
		this.getSprite().SetEmitSoundPaused(true);
		
		this.set_string("current tool", tool);
	}
}

void onAttached( CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint )
{
	this.ClearMenus();
}

void onDetach( CBlob@ this, CBlob@ detached, AttachmentPoint @attachedPoint )
{
	CacheShipStayTransform(this, detached);
	this.set_u16(SEAT_CAMERA_SNAP_ID, 0);
	KillToolBeam3D(this);
}

void onDie( CBlob@ this )
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();
	KillToolBeam3D(this);
	
	ParticleBloodSplat( pos, true );
	directionalSoundPlay( "BodyGibFall", pos );
	
	if (!sprite.getVars().gibbed) 
	{
		directionalSoundPlay( "SR_ManDeath" + ( XORRandom(4) + 1 ), pos, 0.75f );
		sprite.Gib();
	}
	
	//return held blocks
	CRules@ rules = getRules();
	CBlob@[]@ blocks;
	if (this.get( "blocks", @blocks ) && blocks.size() > 0)                 
	{
		if ( getNet().isServer() )
		{
			CPlayer@ player = this.getPlayer();
			if ( player !is null )
			{
				string pName = player.getUsername();
				u16 pBooty = server_getPlayerBooty( pName );
				u16 returnBooty = 0;
				for (uint i = 0; i < blocks.length; ++i)
				{
					if (blocks[i] is null)
					{
						warn("Human onDie: held block is null at index " + i);
						continue;
					}

					int type = Block::getType( blocks[i] );
					if ( type != Block::COUPLING && blocks[i].getShape().getVars().customData == -1 )
						returnBooty += Block::getCost( type );
				}
				
				if ( returnBooty > 0 && !(getPlayersCount() == 1 || rules.get_bool("freebuild")))
					server_setPlayerBooty( pName, pBooty + returnBooty );
			}
		}
		Human::clearHeldBlocks( this );
		this.set_bool( "blockPlacementWarn", false );
	}
}

f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	//when killed: reward hitterBlob if this was boarding his mothership
	if ( hitterBlob.getName() == "human" && hitterBlob !is this && this.getHealth() - damage <= 0 )
	{
		Island@ pIsle = getIsland( this );
		CPlayer@ hitterPlayer = hitterBlob.getPlayer();
		u8 teamNum = hitterBlob.getTeamNum();
		if ( hitterPlayer !is null && pIsle !is null && pIsle.isMothership && pIsle.centerBlock !is null && pIsle.centerBlock.getTeamNum() == teamNum )
		{
			if ( hitterPlayer.isMyPlayer() )
				Sound::Play( "snes_coin.ogg" );

			if ( getNet().isServer() )
			{
				string attackerName = hitterPlayer.getUsername();
				u16 reward = 50;
				if ( getRules().get_bool( "whirlpool" ) ) reward *= 3;
				
				server_setPlayerBooty( attackerName, server_getPlayerBooty( attackerName ) + reward );
				server_updateTotalBooty( teamNum, reward );
			}
		}
	}
	
	if ( this.getTickSinceCreated() > 60 )
		return damage;
	else
		return 0.0f;
}

void onHealthChange( CBlob@ this, f32 oldHealth )
{
	if ( this.getHealth() > oldHealth )
		directionalSoundPlay( "Heal.ogg", this.getPosition(), 2.0f );
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
			p.Z = 540.0f;
	}

	Vec2f shot_vel = Vec2f(0.5f,0);
	shot_vel.RotateBy(-angle);

	//smoke
	for(int i = 0; i < 5; i++)
	{
		//random velocity direction
		Vec2f vel(0.03f + _shotrandom.NextFloat()*0.03f, 0);
		vel.RotateBy(_shotrandom.NextFloat() * 360.0f);
		vel += shot_vel * i;

		CParticle@ p = ParticleAnimated( "Entities/Block/turret_smoke.png",
												  pos, vel,
												  _shotrandom.NextFloat() * 360.0f, //angle
												  0.6f, //scale
												  3+_shotrandom.NextRanged(4), //animtime
												  0.0f, //gravity
												  true ); //selflit
		if(p !is null)
			p.Z = 550.0f;
	}
}
