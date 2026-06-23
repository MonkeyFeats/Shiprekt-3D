#include "WaterEffects.as"
#include "Booty.as"
#include "AccurateSoundPlay.as"
#include "HumanCommon.as"
#include "IslandsCommon.as"
#include "Blob3D.as"
#include "Camera3D.as"
#include "OceanWave.as"
#include "Particle3D.as"
#include "Raycast3D.as"
#include "World.as"
#include "TileCommon.as"

const f32 SHARK_SPEED = 4.5f;
const f32 SHARK_CRUISE_SPEED = 1.2f;
const f32 SHARK_VERTICAL_SPEED = 4.4f;
const f32 SHARK_CRUISE_VERTICAL_SPEED = 0.8f;
const f32 SHARK_ACCEL = 0.18f;
const f32 SHARK_MASS_INERTIA = 1.55f;
const f32 SHARK_WATER_DRAG = 0.985f;
const f32 SHARK_AIR_HORIZONTAL_DRAG = 0.996f;
const f32 SHARK_TURN_SPEED = 7.5f;
const f32 SHARK_PITCH_TURN_SPEED = 5.0f;
const f32 SHARK_PITCH_RIGHTING_SPEED = 1.8f;
const f32 SHARK_MIN_INPUT_SPEED_FACTOR = 0.12f;
const f32 SHARK_DASH_SPEED = 10.5f;
const f32 SHARK_DASH_VERTICAL_SPEED = 5.8f;
const f32 SHARK_DASH_DURATION = 16.0f;
const f32 SHARK_DASH_COOLDOWN = 36.0f;
const f32 SHARK_TAIL_BASE_AMP = 5.0f;
const f32 SHARK_TAIL_SPEED_AMP = 18.0f;
const f32 SHARK_TAIL_DASH_AMP = 28.0f;
const f32 SHARK_TAIL_TURN_AMP = 24.0f;
const f32 SHARK_TAIL_PITCH_AMP = 35.0f;
const f32 SHARK_TAIL_VELOCITY_YAW_AMP = 26.0f;
const f32 SHARK_TAIL_VELOCITY_PITCH_AMP = 42.0f;
const f32 SHARK_TAIL_YAW_LAG_AMP = 3.0f;
const f32 SHARK_TAIL_PITCH_LAG_AMP = 5.0f;
const f32 SHARK_TAIL_STEER_SMOOTH = 0.28f;
const f32 SHARK_TAIL_BASE_FREQ = 0.16f;
const f32 SHARK_TAIL_SPEED_FREQ = 0.09f;
const f32 SHARK_TAIL_DASH_FREQ = 0.32f;
const f32 SHARK_VELOCITY_ALIGN_WATER = 1.0f;
const f32 SHARK_VELOCITY_ALIGN_AIR = 6.0f;
const f32 SHARK_VELOCITY_ALIGN_VERTICAL = 3.5f;
const f32 SHARK_CAMERA_HEIGHT = 12.0f;
const f32 SHARK_SWIM_DEPTH = 5.5f;
const f32 SHARK_GRAVITY = 0.48f;
const f32 SHARK_BREACH_GRAVITY = 0.28f;
const f32 SHARK_WATER_VERTICAL_ACCEL = 0.48f;
const f32 SHARK_DEPTH_HOLD_ACCEL = 0.035f;
const f32 SHARK_BREACH_SURFACE_DEPTH = 7.0f;
const f32 SHARK_BREACH_BOOST = 0.55f;
const f32 SHARK_BREACH_GRACE_TICKS = 10.0f;
const f32 SHARK_AIR_DRAG = 0.992f;
const f32 SHARK_WATER_VERTICAL_DRAG = 0.965f;
const f32 SHARK_GROUND_BOUNCE = 0.28f;
const f32 SHARK_GROUND_FRICTION = 0.72f;
const f32 SHARK_SURFACE_SKIM_RANGE = 2.4f;
const f32 SHARK_SURFACE_TRAIL_DEPTH = 7.0f;
const f32 SHARK_SPLASH_MIN_SPEED = 3.2f;
const f32 SHARK_UNDERWATER_TRAIL_POINT_DISTANCE = 5.5f;
const string SHARK_UNDERWATER_TRAIL_PARTICLE = "shark_underwater_trail_particle";
const f32 SHARK_RENDER_SCALE = 1.0f;
const f32 SHARK_BODY_Y_OFFSET = -0.85f;
const string SHARK_JAW_CHILD = "shark_jaw";
const string SHARK_TAIL_CHILD = "shark_tail";

void onInit( CBlob@ this )
{
	//find target to swim towards
	this.set_Vec2f("target", getTargetVel( this ) * 0.5f);
	
	this.set_bool("retreating", false);

	CSprite@ sprite = this.getSprite();
	sprite.SetZ(-10.0f);
	sprite.ReloadSprites(0,0); //always blue
	sprite.SetAnimation("out");
	this.SetVisible(false);

	this.set_u8("ID", 57);
	this.Untag("prop");

	this.addCommandID(camera_sync_cmd);
	this.set_f32("dir_x", 0.0f);
	this.set_f32("dir_y", 0.0f);
	this.set_f32("old_dir_x", 0.0f);
	this.set_f32("old_dir_y", 0.0f);
	this.set_f32("shark_yaw", 0.0f);
	this.set_f32("shark_pitch", 0.0f);
	this.set_f32("old_shark_yaw", 0.0f);
	this.set_f32("old_shark_pitch", 0.0f);
	this.set_f32("shark_tail_phase", 0.0f);
	this.set_f32("shark_tail_yaw", 0.0f);
	this.set_f32("shark_tail_pitch", 0.0f);
	this.set_f32("old_shark_tail_yaw", 0.0f);
	this.set_f32("old_shark_tail_pitch", 0.0f);
	this.set_f32("shark_dash_ticks", 0.0f);
	this.set_f32("shark_dash_cooldown", 0.0f);
	this.set_f32("shark_breach_ticks", 0.0f);
	this.set_bool("shark_was_in_water", true);
	this.set_f32("eye height", -0.15f);
	this.set_f32("FOV", 12.0f);
	const f32 startY = GetSharkStartY(this);
	this.set_f32("shark_y", startY);
	this.set_f32("old_shark_y", startY);
	this.set_f32("shark_vel_y", 0.0f);

	SetupSharkBlob3D(this);
	
	this.SetMapEdgeFlags( u8(CBlob::map_collide_up) |
	u8(CBlob::map_collide_down) |
	u8(CBlob::map_collide_sides) );
}

Vec3f Shark3DPosition(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	return Vec3f(pos.x, this.get_f32("shark_y"), pos.y);
}

Vec3f GetSharkVelocity3D(CBlob@ this)
{
	Vec2f velocity = this.getVelocity();
	return Vec3f(velocity.x, this.get_f32("shark_vel_y"), velocity.y);
}

void SetSharkVelocity3D(CBlob@ this, Vec3f velocity)
{
	this.setVelocity(Vec2f(velocity.x, velocity.z));
	this.set_f32("shark_vel_y", velocity.y);
}

f32 SharkYaw(CBlob@ this)
{
	return this.get_f32("shark_yaw");
}

f32 SharkPitch(CBlob@ this)
{
	return this.get_f32("shark_pitch");
}

f32 SharkCameraYaw(CBlob@ this)
{
	return -this.get_f32("dir_x");
}

Vec3f SharkDirection(f32 yaw, f32 pitch)
{
	Vec3f forward(0.0f, 0.0f, 1.0f);
	forward.yzRotateBy(pitch);
	forward.xzRotateBy(yaw);
	return forward.Normalize();
}

Vec3f SharkBodyDirection(CBlob@ this)
{
	return SharkDirection(SharkYaw(this), SharkPitch(this));
}

Vec3f SharkRightDirection(CBlob@ this)
{
	Vec3f right(1.0f, 0.0f, 0.0f);
	right.xzRotateBy(SharkYaw(this));
	return right.Normalize();
}

Vec3f SharkUpDirection(CBlob@ this)
{
	Vec3f forward = SharkBodyDirection(this);
	Vec3f right = SharkRightDirection(this);
	Vec3f up = Cross(forward, right);
	if (up.LengthSquared() <= 0.0001f)
		return Vec3f(0.0f, 1.0f, 0.0f);

	return up.Normalize();
}

f32 GetSharkWaterSurface(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	return GetOceanWaterHeight(Vec3f(pos.x, this.get_f32("shark_y"), pos.y));
}

f32 GetSharkStartY(CBlob@ this)
{
	return GetSharkWaterSurface(this) - SHARK_SWIM_DEPTH;
}

bool IsSharkOverLand(CBlob@ this)
{
	CMap@ map = getMap();
	if (map is null)
		return false;

	return map.getTile(this.getPosition()).type < CMap::water_1;
}

bool GetTerrainHeightBelow(Vec3f position, f32 &out groundHeight)
{
	World@ world;
	if (!getMap().get("terrainInfo", @world))
		return false;

	TerrainChunk@ chunk = world.getChunkWorldPos(position / 16);
	if (chunk is null)
		return false;

	groundHeight = chunk.getGroundHeight(position);
	return true;
}

bool GetPhysicsSurfaceBelow(CBlob@ this, Vec3f position, f32 &out surfaceY)
{
	f32 hitDistance;
	const f32 rayStart = 14.0f;
	const f32 rayDistance = 30.0f;
	if (!Raycast3D::RaycastPhysicsColliders(position + Vec3f(0.0f, rayStart, 0.0f), Vec3f(0.0f, -1.0f, 0.0f), rayDistance, this, hitDistance))
		return false;

	surfaceY = position.y + rayStart - hitDistance;
	return true;
}

f32 GetSharkGroundSurface(CBlob@ this, Vec3f position)
{
	f32 ground = -99999.0f;
	f32 terrainHeight;
	if (IsSharkOverLand(this) && GetTerrainHeightBelow(position, terrainHeight))
	{
		ground = Maths::Max(ground, terrainHeight);
	}

	f32 physicsSurface;
	if (GetPhysicsSurfaceBelow(this, position, physicsSurface))
	{
		ground = Maths::Max(ground, physicsSurface);
	}

	return ground;
}

Vec3f UpdateSharkVerticalPhysics(CBlob@ this, Vec3f velocity, f32 desiredSwimVelY, bool activeVerticalInput, f32 dashFactor)
{
	f32 y = this.get_f32("shark_y");
	f32 velY = velocity.y;
	const f32 waterSurfaceY = GetSharkWaterSurface(this);
	const f32 waterDepth = waterSurfaceY - y;
	const bool inWater = waterDepth > 0.0f;
	const bool nearSurface = inWater && waterDepth < SHARK_BREACH_SURFACE_DEPTH;
	const bool tryingToBreach = dashFactor > 0.15f && activeVerticalInput && desiredSwimVelY > 0.0f && nearSurface;
	f32 breachTicks = Maths::Max(0.0f, this.get_f32("shark_breach_ticks") - 1.0f);

	if (inWater)
	{
		velY += (desiredSwimVelY - velY) * (SHARK_WATER_VERTICAL_ACCEL / SHARK_MASS_INERTIA);
		if (!activeVerticalInput)
		{
			velY += Maths::Clamp((waterDepth - SHARK_SWIM_DEPTH) * SHARK_DEPTH_HOLD_ACCEL, -0.18f, 0.18f) / SHARK_MASS_INERTIA;
		}

		if (tryingToBreach)
		{
			velY += (SHARK_BREACH_BOOST * (1.0f - waterDepth / SHARK_BREACH_SURFACE_DEPTH)) / SHARK_MASS_INERTIA;
			breachTicks = SHARK_BREACH_GRACE_TICKS;
			velY *= 0.985f;
		}
		else
		{
			velY *= SHARK_WATER_VERTICAL_DRAG;
		}
	}
	else
	{
		velY -= breachTicks > 0.0f && velY > 0.0f ? SHARK_BREACH_GRAVITY : SHARK_GRAVITY;
		velY *= SHARK_AIR_DRAG;
	}

	y += velY;

	Vec3f nextPosition(this.getPosition().x, y, this.getPosition().y);
	const f32 groundY = GetSharkGroundSurface(this, nextPosition);
	if (groundY > -9999.0f && y < groundY)
	{
		y = groundY;
		if (velY < 0.0f)
		{
			velY = -velY * SHARK_GROUND_BOUNCE;
		}
		velocity.x *= SHARK_GROUND_FRICTION;
		velocity.z *= SHARK_GROUND_FRICTION;
		if (dashFactor <= 0.0f)
		{
			this.set_f32("shark_pitch", ApproachAngle(SharkPitch(this), 0.0f, SHARK_PITCH_TURN_SPEED * 0.55f));
		}
	}

	this.set_f32("shark_y", y);
	this.set_f32("shark_breach_ticks", breachTicks);
	velocity.y = velY;
	return velocity;
}

void EmitSharkSkimSpray(Vec3f origin, Vec3f velocity, f32 power)
{
	if (!getNet().isClient())
		return;

	Random random(getGameTime() * 881 + Maths::Round(origin.x * 4.0f) + Maths::Round(origin.z * 9.0f));
	Vec3f backwash = velocity.LengthSquared() > 0.001f ? -velocity.Normalize() : Vec3f(0.0f, 0.0f, -1.0f);
	const int count = Maths::Max(2, Maths::Round(5.0f * power));
	for (int i = 0; i < count; i++)
	{
		Vec3f dir = backwash;
		dir.xzRotateBy((random.NextFloat() - 0.5f) * 44.0f);
		dir.y = 0.28f + random.NextFloat() * 0.55f;
		dir = dir.Normalize();

		Particle3D@ spray = Particle3D(
			origin + Vec3f((random.NextFloat() - 0.5f) * 1.2f, 0.25f, (random.NextFloat() - 0.5f) * 1.2f),
			dir * (1.2f + random.NextFloat() * 1.8f) * power,
			Vec3f(0.0f, -0.045f, 0.0f),
			9.0f + random.NextFloat() * 8.0f,
			1.7f + random.NextFloat() * 1.8f,
			0.0f,
			SColor(185, 185, 230, 255),
			SColor(0, 110, 175, 220)
		);
		spray.damping = 0.90f;
		spray.stretch = 2.0f + random.NextFloat() * 1.2f;
		spray.facingMode = ParticleFace3D::CameraVelocity;
		EmitParticle3D(spray);
	}
}

void ClearSharkUnderwaterTrail(CBlob@ this)
{
	Particle3D@ trail;
	if (this.get(SHARK_UNDERWATER_TRAIL_PARTICLE, @trail) && trail !is null)
	{
		trail.trailPoints.clear();
	}
}

void UpdateSharkUnderwaterTrail(CBlob@ this, Vec3f origin, Vec3f velocity, f32 power)
{
	if (!getNet().isClient())
		return;

	Particle3D@ trail;
	if (!this.get(SHARK_UNDERWATER_TRAIL_PARTICLE, @trail) || trail is null)
	{
		@trail = Particle3D();
		trail.pointTrail = true;
		trail.IsStatic = true;
		trail.persistent = true;
		trail.lifetime = 999999.0f;
		trail.startSize = 1.0f;
		trail.endSize = 1.0f;
		trail.size = 1.0f;
		trail.maxTrailPoints = 34;
		trail.startColor = SColor(120, 145, 215, 235);
		trail.endColor = SColor(120, 145, 215, 235);
		this.set(SHARK_UNDERWATER_TRAIL_PARTICLE, @trail);
		EmitParticle3D(trail);
	}

	Random random(getGameTime() * 977 + Maths::Round(origin.x * 5.0f) + Maths::Round(origin.z * 3.0f));
	Vec3f newPoint = origin + Vec3f((random.NextFloat() - 0.5f) * 1.4f, (random.NextFloat() - 0.5f) * 0.55f, (random.NextFloat() - 0.5f) * 1.4f);
	const f32 trailSize = 0.9f + power * 0.75f;
	trail.startSize = trailSize;
	trail.endSize = trailSize;
	trail.size = trailSize;
	trail.position = newPoint;
	trail.velocity = velocity.LengthSquared() > 0.001f ? -velocity.Normalize() : Vec3f(0.0f, 0.0f, -1.0f);

	if (trail.trailPoints.length() == 0)
	{
		trail.trailPoints.push_back(newPoint);
		return;
	}

	Vec3f lastPoint = trail.trailPoints[trail.trailPoints.length() - 1];
	if ((newPoint - lastPoint).LengthSquared() < SHARK_UNDERWATER_TRAIL_POINT_DISTANCE * SHARK_UNDERWATER_TRAIL_POINT_DISTANCE)
		return;

	trail.trailPoints.push_back(newPoint);
	while (trail.trailPoints.length() > trail.maxTrailPoints)
	{
		trail.trailPoints.removeAt(0);
	}
}

void EmitSharkHardSplash(CBlob@ this, Vec3f position, Vec3f velocity, f32 waterSurfaceY)
{
	if (!getNet().isClient())
		return;

	const f32 speed = velocity.Length();
	if (speed < SHARK_SPLASH_MIN_SPEED)
		return;

	const f32 power = Maths::Clamp(speed * 0.16f + Maths::Abs(velocity.y) * 0.18f, 0.85f, 2.4f);
	EmitWaterSplashParticles3D(Vec3f(position.x, waterSurfaceY, position.z), velocity, power);

	if (power > 1.1f)
	{
		EmitSharkSkimSpray(Vec3f(position.x, waterSurfaceY + 0.3f, position.z), velocity, power * 0.85f);
	}
}

void UpdateSharkWaterParticles(CBlob@ this, Vec3f velocity)
{
	if (!getNet().isClient())
		return;

	Vec3f position = Shark3DPosition(this);
	const f32 waterSurfaceY = GetSharkWaterSurface(this);
	const f32 waterDepth = waterSurfaceY - position.y;
	const bool inWater = waterDepth > 0.0f;
	const bool wasInWater = this.get_bool("shark_was_in_water");
	const f32 horizontalSpeed = Vec2f(velocity.x, velocity.z).getLength();
	const f32 speed = velocity.Length();
	const u32 time = getGameTime();

	if (inWater != wasInWater)
	{
		EmitSharkHardSplash(this, position, velocity, waterSurfaceY);
	}
	this.set_bool("shark_was_in_water", inWater);

	if (!inWater)
	{
		ClearSharkUnderwaterTrail(this);
	}

	if (speed < 1.0f)
	{
		if (inWater)
		{
			ClearSharkUnderwaterTrail(this);
		}
		return;
	}

	Vec3f forward = SharkBodyDirection(this);
	Vec3f up = SharkUpDirection(this);
	Vec3f finPoint = position + up * 5.2f - forward * 1.5f;
	Vec3f tailPoint = position - forward * 29.0f;
	const f32 finWaterY = GetOceanWaterHeight(finPoint);
	const f32 tailWaterY = GetOceanWaterHeight(tailPoint);
	const f32 skimPower = Maths::Clamp(horizontalSpeed * 0.16f + Maths::Abs(velocity.y) * 0.08f, 0.35f, 1.5f);

	if (time % 2 == 0)
	{
		if (Maths::Abs(finWaterY - finPoint.y) <= SHARK_SURFACE_SKIM_RANGE)
		{
			EmitSharkSkimSpray(Vec3f(finPoint.x, finWaterY + 0.18f, finPoint.z), velocity, skimPower);
		}
		if (Maths::Abs(tailWaterY - tailPoint.y) <= SHARK_SURFACE_SKIM_RANGE)
		{
			EmitSharkSkimSpray(Vec3f(tailPoint.x, tailWaterY + 0.18f, tailPoint.z), velocity, skimPower * 0.85f);
		}
	}

	if (inWater && waterDepth > 1.0f && waterDepth < SHARK_SURFACE_TRAIL_DEPTH && time % 4 == 0)
	{
		EmitWakeParticles3D(Vec3f(position.x, waterSurfaceY + 0.18f, position.z), velocity * -1.0f, Maths::Clamp(horizontalSpeed * 0.12f, 0.35f, 1.25f));
	}

	if (inWater)
	{
		UpdateSharkUnderwaterTrail(this, position - forward * 12.0f, velocity, Maths::Clamp(speed * 0.14f, 0.35f, 1.2f));
	}
}

f32 NormalizeAngle(f32 angle)
{
	while (angle > 180.0f) angle -= 360.0f;
	while (angle < -180.0f) angle += 360.0f;
	return angle;
}

f32 ApproachAngle(f32 current, f32 target, f32 amount)
{
	f32 delta = NormalizeAngle(target - current);
	delta = Maths::Clamp(delta, -amount, amount);
	return NormalizeAngle(current + delta);
}

f32 SharkInputYawOffset(bool forward, bool back, bool left, bool right)
{
	if (forward)
	{
		if (left) return 45.0f;
		if (right) return -45.0f;
		return 0.0f;
	}

	if (back)
	{
		if (left) return 135.0f;
		if (right) return -135.0f;
		return 180.0f;
	}

	if (left) return 90.0f;
	if (right) return -90.0f;
	return 0.0f;
}

Vec3f SharkInputDirection(CBlob@ this, bool forward, bool back, bool left, bool right)
{
	f32 targetYaw = SharkCameraYaw(this) + SharkInputYawOffset(forward, back, left, right);
	f32 targetPitch = 0.0f;

	if (forward)
	{
		targetPitch = this.get_f32("dir_y");
	}
	else if (back)
	{
		targetPitch = -this.get_f32("dir_y");
	}

	return SharkDirection(targetYaw, Maths::Clamp(targetPitch, -65.0f, 65.0f));
}

bool HasSharkVerticalInput(CBlob@ this, bool forward, bool back)
{
	if (forward || back)
	{
		return Maths::Abs(this.get_f32("dir_y")) > 8.0f;
	}

	return false;
}

void RightSharkPitch(CBlob@ this, f32 strength)
{
	if (strength <= 0.0f)
		return;

	this.set_f32("shark_pitch", ApproachAngle(SharkPitch(this), 0.0f, SHARK_PITCH_RIGHTING_SPEED * strength));
}

void SteerShark(CBlob@ this, bool forward, bool back, bool left, bool right)
{
	if (!forward && !back && !left && !right)
	{
		RightSharkPitch(this, 1.0f);
		return;
	}

	f32 yaw = SharkYaw(this);
	f32 pitch = SharkPitch(this);
	f32 targetYaw = SharkCameraYaw(this) + SharkInputYawOffset(forward, back, left, right);
	f32 targetPitch = 0.0f;

	if (forward)
	{
		targetPitch = this.get_f32("dir_y");
	}
	else if (back)
	{
		targetPitch = -this.get_f32("dir_y");
	}

	this.set_f32("shark_yaw", ApproachAngle(yaw, targetYaw, SHARK_TURN_SPEED));
	if (HasSharkVerticalInput(this, forward, back))
	{
		this.set_f32("shark_pitch", ApproachAngle(pitch, Maths::Clamp(targetPitch, -65.0f, 65.0f), SHARK_PITCH_TURN_SPEED));
	}
	else
	{
		RightSharkPitch(this, (left || right) && !forward && !back ? 0.85f : 0.45f);
	}
}

void ApplySharkMeshSettings(SMesh@ mesh)
{
	if (mesh is null)
		return;

	SMaterial@ material = mesh.GetMaterial();
	if (material is null)
		return;

	material.AddTexture("RGB_Alpha.png", 0);
	material.SetFlag(SMaterial::LIGHTING, false);
	material.SetFlag(SMaterial::BILINEAR_FILTER, false);
	material.SetLayerBilinearFilter(0, false);
	material.SetMaterialType(SMaterial::SOLID);
	mesh.SetMaterial(material);
}

void LoadSharkObjMesh(SMesh@ mesh, const string &in objPath)
{
	if (mesh is null)
		return;

	mesh.LoadObjIntoMesh(objPath);
	mesh.SetHardwareMapping(SMesh::STATIC);
	ApplySharkMeshSettings(mesh);
	mesh.BuildMesh();
}

void AddSharkChild(Blob3D@ shark, const string &in name, const string &in objPath, Vec3f localPosition, Vec3f localRotation)
{
	if (shark is null)
		return;

	Blob3D child(localPosition, shark.getTeamNum(), 1.0f);
	if (child !is null)
	{
		child.Name = name;
		LoadSharkObjMesh(child.mesh, objPath);
		child.HasMesh = true;
		child.renderScale = SHARK_RENDER_SCALE;
		child.transform.Orientation.y = localRotation.x;
		child.transform.Orientation.x = localRotation.y;
		child.transform.Orientation.z = localRotation.z;
		shark.AddChild(@child);
	}
}

Vec3f SharkScaledOffset(f32 x, f32 y, f32 z)
{
	return Vec3f(x * SHARK_RENDER_SCALE, y * SHARK_RENDER_SCALE, z * SHARK_RENDER_SCALE);
}

void SetSharkChildPitch(Blob3D@ shark, const string &in childName, f32 pitch)
{
	if (shark is null)
		return;

	Blob3D@ child = shark.getChild(childName);
	if (child !is null)
	{
		child.LocalTransform.Orientation.y = pitch;
	}
}

void SetSharkTailPose(Blob3D@ shark, f32 yaw, f32 pitch)
{
	if (shark is null)
		return;

	Blob3D@ tail = shark.getChild(SHARK_TAIL_CHILD);
	if (tail !is null)
	{
		tail.LocalTransform.Orientation.x = yaw;
		tail.LocalTransform.Orientation.y = pitch;
	}
}

void UpdateSharkChildren(Blob3D@ shark, f32 pitch, f32 tailYaw, f32 tailPitch)
{
	SetSharkChildPitch(shark, SHARK_JAW_CHILD, pitch);
	SetSharkChildPitch(shark, SHARK_TAIL_CHILD, pitch);
	SetSharkTailPose(shark, tailYaw, pitch + tailPitch);
}

f32 SharkTurnInput(bool left, bool right)
{
	if (left && !right) return 1.0f;
	if (right && !left) return -1.0f;
	return 0.0f;
}

void AlignSharkBodyToVelocity(CBlob@ this, Vec3f velocity, bool inWater)
{
	Vec2f horizontalVelocity(velocity.x, velocity.z);
	const f32 horizontalSpeed = horizontalVelocity.getLength();
	const f32 speed = velocity.Length();
	if (speed < 0.25f)
		return;

	f32 targetYaw = horizontalVelocity.getAngleDegrees() - 90.0f;
	f32 targetPitch = -Maths::ATan2(velocity.y, Maths::Max(horizontalSpeed, 0.1f)) * 180.0f / Maths::Pi;
	targetPitch = Maths::Clamp(targetPitch, -78.0f, 78.0f);

	const f32 verticalFactor = Maths::Clamp01(Maths::Abs(velocity.y) / (SHARK_VERTICAL_SPEED + SHARK_DASH_VERTICAL_SPEED));
	const f32 waterAlign = inWater ? SHARK_VELOCITY_ALIGN_WATER : SHARK_VELOCITY_ALIGN_AIR;
	const f32 alignAmount = waterAlign + SHARK_VELOCITY_ALIGN_VERTICAL * verticalFactor;
	this.set_f32("shark_yaw", ApproachAngle(SharkYaw(this), targetYaw, alignAmount));
	this.set_f32("shark_pitch", ApproachAngle(SharkPitch(this), targetPitch, alignAmount));
}

void UpdateSharkTail(CBlob@ this, Vec3f velocity, f32 speedFactor, f32 dashFactor, f32 turnInput, f32 verticalInput)
{
	f32 phase = this.get_f32("shark_tail_phase");
	phase += SHARK_TAIL_BASE_FREQ + SHARK_TAIL_SPEED_FREQ * speedFactor + SHARK_TAIL_DASH_FREQ * dashFactor;

	f32 amp = SHARK_TAIL_BASE_AMP + SHARK_TAIL_SPEED_AMP * speedFactor + SHARK_TAIL_DASH_AMP * dashFactor;
	Vec3f bodyRight(1.0f, 0.0f, 0.0f);
	bodyRight.xzRotateBy(SharkYaw(this));
	f32 lateralVelocity = Maths::Clamp(velocity.Dot(bodyRight) / (SHARK_CRUISE_SPEED + SHARK_SPEED + SHARK_DASH_SPEED), -1.0f, 1.0f);
	f32 verticalVelocity = Maths::Clamp(velocity.y / (SHARK_VERTICAL_SPEED + SHARK_DASH_VERTICAL_SPEED), -1.0f, 1.0f);
	f32 yawRate = NormalizeAngle(SharkYaw(this) - this.get_f32("old_shark_yaw"));
	f32 pitchRate = NormalizeAngle(SharkPitch(this) - this.get_f32("old_shark_pitch"));
	f32 bendStrength = Maths::Clamp01(speedFactor + dashFactor + 0.25f);
	f32 targetYaw = Maths::Sin(phase) * amp +
		turnInput * SHARK_TAIL_TURN_AMP * Maths::Clamp01(speedFactor + 0.2f) -
		lateralVelocity * SHARK_TAIL_VELOCITY_YAW_AMP -
		yawRate * SHARK_TAIL_YAW_LAG_AMP;
	f32 targetPitch = -verticalInput * SHARK_TAIL_PITCH_AMP * bendStrength +
		verticalVelocity * SHARK_TAIL_VELOCITY_PITCH_AMP -
		pitchRate * SHARK_TAIL_PITCH_LAG_AMP;
	this.set_f32("shark_tail_phase", phase);
	this.set_f32("shark_tail_yaw", this.get_f32("shark_tail_yaw") + (targetYaw - this.get_f32("shark_tail_yaw")) * SHARK_TAIL_STEER_SMOOTH);
	this.set_f32("shark_tail_pitch", this.get_f32("shark_tail_pitch") + (targetPitch - this.get_f32("shark_tail_pitch")) * SHARK_TAIL_STEER_SMOOTH);
}

void SetupSharkMeshes(Blob3D@ blob3d)
{
	if (blob3d is null || !getNet().isClient())
		return;

	blob3d.Name = "shark_body";
	LoadSharkObjMesh(blob3d.mesh, "SharkBody.obj");
	blob3d.HasMesh = true;
	blob3d.renderScale = SHARK_RENDER_SCALE;
	blob3d.renderOffset = SharkScaledOffset(0.0f, SHARK_BODY_Y_OFFSET, 0.0f);
	AddSharkChild(blob3d, SHARK_JAW_CHILD, "SharkJaw.obj", SharkScaledOffset(0.0f, -6.104f, 21.235f), Vec3f(0.0f, 0.0f, 0.0f));
	AddSharkChild(blob3d, SHARK_TAIL_CHILD, "SharkTail.obj", SharkScaledOffset(0.0f, 0.0f, -14.479f), Vec3f(0.0f, 0.0f, 0.0f));
}

void SetupSharkBlob3D(CBlob@ this)
{
	Blob3D blob3d(this, Shark3DPosition(this), this.getTeamNum(), this.getHealth());
	if (blob3d !is null)
	{
		SetupSharkMeshes(@blob3d);
		blob3d.transform.Orientation.x = SharkYaw(this);
		blob3d.transform.Orientation.y = SharkPitch(this);
		UpdateSharkChildren(@blob3d, SharkPitch(this), this.get_f32("shark_tail_yaw"), this.get_f32("shark_tail_pitch"));
		this.set("blob3d", @blob3d);
	}
}

void UpdateSharkBlob3D(CBlob@ this)
{
	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d) || blob3d is null)
	{
		SetupSharkBlob3D(this);
		return;
	}

	Vec3f position = Shark3DPosition(this);
	blob3d.setPosition(position);
	blob3d.transform.Orientation.x = SharkYaw(this);
	blob3d.transform.Orientation.y = SharkPitch(this);
	blob3d.renderOffset = SharkScaledOffset(0.0f, SHARK_BODY_Y_OFFSET, 0.0f);
	UpdateSharkChildren(blob3d, SharkPitch(this), this.get_f32("shark_tail_yaw"), this.get_f32("shark_tail_pitch"));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID(camera_sync_cmd))
	{
		HandleCamera(this, params, !canSend(this));
	}
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void onTick( CBlob@ this )
{
	this.SetVisible(false);
	this.set_f32("old_dir_x", this.get_f32("dir_x"));
	this.set_f32("old_dir_y", this.get_f32("dir_y"));
	this.set_f32("old_shark_y", this.get_f32("shark_y"));
	this.set_f32("old_shark_yaw", SharkYaw(this));
	this.set_f32("old_shark_pitch", SharkPitch(this));
	this.set_f32("old_shark_tail_yaw", this.get_f32("shark_tail_yaw"));
	this.set_f32("old_shark_tail_pitch", this.get_f32("shark_tail_pitch"));
	UpdateSharkBlob3D(this);

	Vec2f pos = this.getPosition();	
	CMap@ map = getMap();
	Tile tile = map.getTile( pos );
	bool onLand = map.isTileBackgroundNonEmpty( tile ) || map.isTileSolid( tile );
	
	if ( onLand )
		this.set_bool("retreating", true);

	if (this.getPlayer() is null)
	{
		u32 ticktime = (getGameTime() + this.getNetworkID());

		if(ticktime % 5 == 0 && //check each 5 ticks
			this.hasTag("vanish") && //read tag
			getGameTime() > this.get_u32("vanishtime")) //compare time
		{
			this.Tag("no gib");
			this.server_Die();
			return;
		}
		if( ticktime % 40 == 0 )
		{
			this.set_Vec2f("target", getTargetVel( this ));
		}
		
		if ( !this.get_bool("retreating") )
			MoveTo( this, this.get_Vec2f("target") );
		else
		{
			MoveTo( this, -this.get_Vec2f("target") );
			this.Tag("vanish");
		}
	}
	else
	{		
		// player
		Vec3f velocity = GetSharkVelocity3D(this);
		f32 desiredVelY = 0.0f;
		const bool forward = this.isKeyPressed(key_up);
		const bool back = this.isKeyPressed(key_down);
		const bool left = this.isKeyPressed(key_left);
		const bool right = this.isKeyPressed(key_right);
		const bool moving = forward || back || left || right;

		SteerShark(this, forward, back, left, right);

		Vec3f bodyForward = SharkBodyDirection(this);
		const bool activeVerticalInput = HasSharkVerticalInput(this, forward, back);
		f32 dashTicks = Maths::Max(0.0f, this.get_f32("shark_dash_ticks") - 1.0f);
		f32 dashCooldown = Maths::Max(0.0f, this.get_f32("shark_dash_cooldown") - 1.0f);
		bool canDash = this.isKeyJustPressed(key_action1) && dashCooldown <= 0.0f;
		if (this.isMyPlayer())
		{
			canDash = canDash && !getHUD().hasButtons() && !getHUD().hasMenus();
		}
		if (canDash)
		{
			dashTicks = SHARK_DASH_DURATION;
			dashCooldown = SHARK_DASH_COOLDOWN;
			velocity += bodyForward * (SHARK_DASH_SPEED * 0.65f);
			velocity.y += bodyForward.y * (SHARK_DASH_VERTICAL_SPEED * 0.35f);
		}

		f32 dashFactor = Maths::Clamp01(dashTicks / SHARK_DASH_DURATION);
		f32 inputSpeedFactor = 0.0f;
		if (moving)
		{
			Vec3f inputDirection = SharkInputDirection(this, forward, back, left, right);
			inputSpeedFactor = Maths::Clamp01((bodyForward.Dot(inputDirection) + 0.15f) / 1.15f);
			inputSpeedFactor = SHARK_MIN_INPUT_SPEED_FACTOR + (1.0f - SHARK_MIN_INPUT_SPEED_FACTOR) * inputSpeedFactor * inputSpeedFactor;
		}

		f32 targetSpeed = SHARK_CRUISE_SPEED + SHARK_SPEED * inputSpeedFactor + SHARK_DASH_SPEED * dashFactor;
		f32 targetVerticalSpeed = SHARK_CRUISE_VERTICAL_SPEED + SHARK_VERTICAL_SPEED * inputSpeedFactor + SHARK_DASH_VERTICAL_SPEED * dashFactor;
		Vec2f targetVel = Vec2f(bodyForward.x, bodyForward.z) * targetSpeed;
		desiredVelY = activeVerticalInput || dashFactor > 0.0f ? bodyForward.y * targetVerticalSpeed : 0.0f;
		const f32 waterDepth = GetSharkWaterSurface(this) - this.get_f32("shark_y");
		const bool inWater = waterDepth > 0.0f;
		const f32 thrustResponse = SHARK_ACCEL / SHARK_MASS_INERTIA;
		velocity.x += (targetVel.x - velocity.x) * thrustResponse;
		velocity.z += (targetVel.y - velocity.z) * thrustResponse;
		if (inWater)
		{
			velocity.x *= SHARK_WATER_DRAG;
			velocity.z *= SHARK_WATER_DRAG;
		}
		else
		{
			velocity.x *= SHARK_AIR_HORIZONTAL_DRAG;
			velocity.z *= SHARK_AIR_HORIZONTAL_DRAG;
		}

		f32 verticalTailInput = activeVerticalInput ? Maths::Clamp(this.get_f32("dir_y") / 65.0f, -1.0f, 1.0f) : 0.0f;
		if (back)
		{
			verticalTailInput *= -1.0f;
		}
		this.set_f32("shark_dash_ticks", dashTicks);
		this.set_f32("shark_dash_cooldown", dashCooldown);

		velocity = UpdateSharkVerticalPhysics(this, velocity, desiredVelY, activeVerticalInput, dashFactor);
		const bool velocityAlignInWater = GetSharkWaterSurface(this) - this.get_f32("shark_y") > 0.0f;
		AlignSharkBodyToVelocity(this, velocity, velocityAlignInWater);
		f32 speedFactor = Maths::Clamp01((Vec2f(velocity.x, velocity.z).getLength() + Maths::Abs(velocity.y)) / (SHARK_CRUISE_SPEED + SHARK_SPEED + SHARK_DASH_SPEED));
		UpdateSharkTail(this, velocity, speedFactor, dashFactor, SharkTurnInput(left, right), verticalTailInput);
		SetSharkVelocity3D(this, velocity);
		UpdateSharkWaterParticles(this, velocity);

		this.setAngleDegrees( SharkYaw(this) );
		UpdateSharkBlob3D(this);

		//Vec2f pos = this.getPosition();	
		// water effect
		//if( (getGameTime() + this.getNetworkID()) % 9 == 0){
		//	MakeWaterWave(pos, Vec2f_zero, -angle + (_anglerandom.NextRanged(100) > 50 ? 180 : 0)); 
		//}

		//MoveTo( this, vel );

		if (this.isMyPlayer())
		{
			ManageCamera(this);	

		    if (getHUD().hasButtons())
		    {
		        if (this.isKeyJustPressed(key_action1))
		        {
				    CGridMenu @gmenu;
				    CGridButton @gbutton;
				    this.ClickGridMenu(0, gmenu, gbutton); 
			    }
			}
		}
		this.getSprite().SetAnimation("default");
	}
	
}

void ManageCamera(CBlob@ this)
{
	//if(this.isMyPlayer() && getNet().isClient())
	//{
		CControls@ c = getControls();
		Driver@ d = getDriver();
		bool ctrl = c.isKeyJustPressed(KEY_LCONTROL);
		if(ctrl){ this.set_bool("stuck", !this.get_bool("stuck")); this.Sync("stuck", true);}
		if(!this.get_bool("stuck") && d !is null && c !is null && !c.isMenuOpened() && !getHUD().hasButtons() && !getHUD().hasMenus())
		{
			Vec2f ScrMid = Vec2f(f32(d.getScreenWidth()) / 2, f32(d.getScreenHeight()) / 2);
			Vec2f dir = (c.getMouseScreenPos() - ScrMid)/10;
			float dirX = this.get_f32("dir_x");
			float dirY = this.get_f32("dir_y");
			dirX += dir.x;
			dirY = Maths::Clamp(dirY+dir.y,-65,65);

			this.set_f32("dir_x", dirX);
			this.set_f32("dir_y", dirY);
			c.setMousePosition(ScrMid);

			//Vec2f dir2 =  Vec2f((1080.0f/((1+dirY)%360))+8.0f,0); // i cant do math dont judge
    		//Vec2f aimPos = this.getPosition() - dir2.RotateBy(dirX);	
    		//this.set_Vec2f("aim_pos", aimPos);
		}
		if(getGameTime() % 2 == 0)
		{
			SyncCamera(this);
		}
	//}
}

//sprite update
void onTick( CSprite@ this )
{
	CBlob@ blob = this.getBlob();

	if(this.isAnimation("out") && this.isAnimationEnded())
		this.SetAnimation("default");

	if( blob.hasTag("vanish"))
		this.SetAnimation("in");
}

Random _anglerandom(0x9090); //clientside

void MoveTo( CBlob@ this, Vec2f moveVel )
{	
	
}

Vec2f getTargetVel( CBlob@ this )
{
	CBlob@[] blobsInRadius;
	Vec2f pos = this.getPosition();
	Vec2f target = this.getVelocity();
	int humansInWater = 0;
	if (getMap().getBlobsInRadius( pos, 150.0f, @blobsInRadius ))
	{
		f32 maxDistance = 9999999.9f;
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (!b.isOnGround() && b.getName() == "human")
			{
				humansInWater++;
				f32 dist = (pos - b.getPosition()).getLength();
				if (dist < maxDistance)
				{
					target = b.getPosition() - pos;
					maxDistance = dist;
				}
			}
		}
	}

	if (humansInWater == 0)
	{
		this.Tag("vanish");
		this.set_u32("vanishtime", getGameTime() + 15);
	}

	target.Normalize();
	return target;
}

void onDie( CBlob@ this )
{
	MakeWaterParticle(this.getPosition(), Vec2f_zero); 
}

void onCollision( CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1 )
{
	if (blob is null) {
		return;
	}

	if ( blob.getName() == "human" && !blob.get_bool( "onGround" ) )
	{
		MakeWaterParticle(point1, Vec2f_zero); 
		directionalSoundPlay( "ZombieBite", point1 );		
		blob.server_Die();
		this.server_Die();
	}
}

void onSetPlayer( CBlob@ this, CPlayer@ player )
{
	this.Untag( "vanish" );
	if (player !is null && player.isMyPlayer()) // setup camera to follow
	{
		CCamera@ camera = getCamera();
		camera.setRotation(0);
		camera.mousecamstyle = 1; // follow
		camera.targetDistance = 1.0f; // zoom factor
		camera.posLag = 5; // lag/smoothen the movement of the camera
		this.SetMinimapVars("GUI/Minimap/MinimapIcons.png", 0, Vec2f(8,8));
		client_AddToChat( "You are a shark now." );

		Camera3D@ camera3d;
		if (player.get("Camera3D", @camera3d) && camera3d !is null)
		{
			Blob3D@ blob3d;
			if (this.get("blob3d", @blob3d) && blob3d !is null)
			{
				camera3d.setTarget(blob3d);
			}
		}
	}
}


f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	if ( this.getHealth() - damage <= 0 && hitterBlob.getName() == "bullet" )
	{
		CPlayer@ owner = hitterBlob.getDamageOwnerPlayer();
		if ( owner !is null )
		{
			string pName = owner.getUsername();
			if ( owner.isMyPlayer() )
				directionalSoundPlay( "coinpick.ogg", worldPoint, 0.75f );

			if ( getNet().isServer() )
				server_setPlayerBooty( pName, server_getPlayerBooty( pName ) + 10 );
		}
	}
	
	return damage;
}
