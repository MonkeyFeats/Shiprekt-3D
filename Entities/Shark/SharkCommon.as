#include "Blob3D.as"
#include "OceanWave.as"
#include "Particle3D.as"
#include "Raycast3D.as"
#include "World.as"
#include "TileCommon.as"

namespace SharkVars
{
	const f32 speed = 4.5f;
	const f32 cruise_speed = 1.2f;
	const f32 vertical_speed = 4.4f;
	const f32 cruise_vertical_speed = 0.8f;
	const f32 accel = 0.18f;
	const f32 mass_inertia = 1.55f;
	const f32 water_drag = 0.985f;
	const f32 air_horizontal_drag = 0.996f;
	const f32 turn_speed = 7.5f;
	const f32 pitch_turn_speed = 5.0f;
	const f32 pitch_righting_speed = 1.8f;
	const f32 min_input_speed_factor = 0.12f;
	const f32 dash_speed = 10.5f;
	const f32 dash_vertical_speed = 5.8f;
	const f32 dash_duration = 16.0f;
	const f32 dash_cooldown = 36.0f;

	const f32 tail_base_amp = 5.0f;
	const f32 tail_speed_amp = 18.0f;
	const f32 tail_dash_amp = 28.0f;
	const f32 tail_turn_amp = 24.0f;
	const f32 tail_pitch_amp = 35.0f;
	const f32 tail_velocity_yaw_amp = 26.0f;
	const f32 tail_velocity_pitch_amp = 42.0f;
	const f32 tail_yaw_lag_amp = 3.0f;
	const f32 tail_pitch_lag_amp = 5.0f;
	const f32 tail_steer_smooth = 0.28f;
	const f32 tail_base_freq = 0.16f;
	const f32 tail_speed_freq = 0.09f;
	const f32 tail_dash_freq = 0.32f;

	const f32 velocity_align_water = 1.0f;
	const f32 velocity_align_air = 6.0f;
	const f32 velocity_align_vertical = 3.5f;

	const f32 swim_depth = 5.5f;
	const f32 gravity = 0.48f;
	const f32 breach_gravity = 0.28f;
	const f32 water_vertical_accel = 0.48f;
	const f32 depth_hold_accel = 0.035f;
	const f32 breach_surface_depth = 7.0f;
	const f32 breach_boost = 0.55f;
	const f32 breach_grace_ticks = 10.0f;
	const f32 air_drag = 0.992f;
	const f32 water_vertical_drag = 0.965f;
	const f32 ground_bounce = 0.28f;
	const f32 ground_friction = 0.72f;

	const f32 surface_skim_range = 2.4f;
	const f32 surface_trail_depth = 7.0f;
	const f32 splash_min_speed = 3.2f;
	const f32 underwater_trail_point_distance = 5.5f;

	const f32 render_scale = 1.0f;
	const f32 body_y_offset = -0.85f;
}

const string SHARK_UNDERWATER_TRAIL_PARTICLE = "shark_underwater_trail_particle";
const string SHARK_INFO = "shark info";
const string SHARK_JAW_CHILD = "shark_jaw";
const string SHARK_TAIL_CHILD = "shark_tail";

shared class SharkInfo
{
	f32 dir_x;
	f32 dir_y;
	f32 old_dir_x;
	f32 old_dir_y;
	f32 y;
	f32 old_y;
	f32 vel_y;
	f32 yaw;
	f32 pitch;
	f32 old_yaw;
	f32 old_pitch;
	f32 tail_phase;
	f32 tail_yaw;
	f32 tail_pitch;
	f32 old_tail_yaw;
	f32 old_tail_pitch;
	f32 dash_ticks;
	f32 dash_cooldown;
	f32 breach_ticks;
	bool was_in_water;

	SharkInfo()
	{
		Reset(0.0f);
	}

	void Reset(f32 startY)
	{
		dir_x = 0.0f;
		dir_y = 0.0f;
		old_dir_x = 0.0f;
		old_dir_y = 0.0f;
		y = startY;
		old_y = startY;
		vel_y = 0.0f;
		yaw = 0.0f;
		pitch = 0.0f;
		old_yaw = 0.0f;
		old_pitch = 0.0f;
		tail_phase = 0.0f;
		tail_yaw = 0.0f;
		tail_pitch = 0.0f;
		old_tail_yaw = 0.0f;
		old_tail_pitch = 0.0f;
		dash_ticks = 0.0f;
		dash_cooldown = 0.0f;
		breach_ticks = 0.0f;
		was_in_water = true;
	}
};

SharkInfo@ GetSharkInfo(CBlob@ this)
{
	SharkInfo@ info;
	if (!this.get(SHARK_INFO, @info) || info is null)
	{
		SharkInfo newInfo;
		@info = @newInfo;
		this.set(SHARK_INFO, @info);
	}

	return info;
}

void PublishSharkRenderState(CBlob@ this, SharkInfo@ info)
{
	if (info is null)
		return;

	this.set_f32("dir_x", info.dir_x);
	this.set_f32("dir_y", info.dir_y);
	this.set_f32("old_dir_x", info.old_dir_x);
	this.set_f32("old_dir_y", info.old_dir_y);
	this.set_f32("shark_y", info.y);
	this.set_f32("old_shark_y", info.old_y);
	this.set_f32("shark_yaw", info.yaw);
	this.set_f32("old_shark_yaw", info.old_yaw);
	this.set_f32("shark_pitch", info.pitch);
	this.set_f32("old_shark_pitch", info.old_pitch);
	this.set_f32("shark_tail_yaw", info.tail_yaw);
	this.set_f32("old_shark_tail_yaw", info.old_tail_yaw);
	this.set_f32("shark_tail_pitch", info.tail_pitch);
	this.set_f32("old_shark_tail_pitch", info.old_tail_pitch);
}

void ImportSharkCameraState(CBlob@ this, SharkInfo@ info)
{
	if (info is null)
		return;

	info.dir_x = this.get_f32("dir_x");
	info.dir_y = this.get_f32("dir_y");
	info.old_dir_x = this.get_f32("old_dir_x");
	info.old_dir_y = this.get_f32("old_dir_y");
}

void InitSharkState(CBlob@ this)
{
	SharkInfo@ info = GetSharkInfo(this);
	info.Reset(GetSharkStartY(this));
	PublishSharkRenderState(this, info);

	this.set_f32("eye height", -0.15f);
	this.set_f32("FOV", 12.0f);
}

void StoreOldSharkState(CBlob@ this)
{
	SharkInfo@ info = GetSharkInfo(this);
	info.old_dir_x = info.dir_x;
	info.old_dir_y = info.dir_y;
	info.old_y = info.y;
	info.old_yaw = info.yaw;
	info.old_pitch = info.pitch;
	info.old_tail_yaw = info.tail_yaw;
	info.old_tail_pitch = info.tail_pitch;
	PublishSharkRenderState(this, info);
}

Vec3f Shark3DPosition(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	return Vec3f(pos.x, GetSharkInfo(this).y, pos.y);
}

Vec3f GetSharkVelocity3D(CBlob@ this)
{
	Vec2f velocity = this.getVelocity();
	return Vec3f(velocity.x, GetSharkInfo(this).vel_y, velocity.y);
}

void SetSharkVelocity3D(CBlob@ this, Vec3f velocity)
{
	this.setVelocity(Vec2f(velocity.x, velocity.z));
	GetSharkInfo(this).vel_y = velocity.y;
}

f32 SharkYaw(CBlob@ this)
{
	return GetSharkInfo(this).yaw;
}

f32 SharkPitch(CBlob@ this)
{
	return GetSharkInfo(this).pitch;
}

f32 SharkCameraYaw(CBlob@ this)
{
	return -GetSharkInfo(this).dir_x;
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
	return GetOceanWaterHeight(Vec3f(pos.x, GetSharkInfo(this).y, pos.y));
}

f32 GetSharkStartY(CBlob@ this)
{
	return GetSharkWaterSurface(this) - SharkVars::swim_depth;
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
	SharkInfo@ info = GetSharkInfo(this);
	f32 y = info.y;
	f32 velY = velocity.y;
	const f32 waterSurfaceY = GetSharkWaterSurface(this);
	const f32 waterDepth = waterSurfaceY - y;
	const bool inWater = waterDepth > 0.0f;
	const bool nearSurface = inWater && waterDepth < SharkVars::breach_surface_depth;
	const bool tryingToBreach = dashFactor > 0.15f && activeVerticalInput && desiredSwimVelY > 0.0f && nearSurface;
	f32 breachTicks = Maths::Max(0.0f, info.breach_ticks - 1.0f);

	if (inWater)
	{
		velY += (desiredSwimVelY - velY) * (SharkVars::water_vertical_accel / SharkVars::mass_inertia);
		if (!activeVerticalInput)
		{
			velY += Maths::Clamp((waterDepth - SharkVars::swim_depth) * SharkVars::depth_hold_accel, -0.18f, 0.18f) / SharkVars::mass_inertia;
		}

		if (tryingToBreach)
		{
			velY += (SharkVars::breach_boost * (1.0f - waterDepth / SharkVars::breach_surface_depth)) / SharkVars::mass_inertia;
			breachTicks = SharkVars::breach_grace_ticks;
			velY *= 0.985f;
		}
		else
		{
			velY *= SharkVars::water_vertical_drag;
		}
	}
	else
	{
		velY -= breachTicks > 0.0f && velY > 0.0f ? SharkVars::breach_gravity : SharkVars::gravity;
		velY *= SharkVars::air_drag;
	}

	y += velY;

	Vec3f nextPosition(this.getPosition().x, y, this.getPosition().y);
	const f32 groundY = GetSharkGroundSurface(this, nextPosition);
	if (groundY > -9999.0f && y < groundY)
	{
		y = groundY;
		if (velY < 0.0f)
		{
			velY = -velY * SharkVars::ground_bounce;
		}
		velocity.x *= SharkVars::ground_friction;
		velocity.z *= SharkVars::ground_friction;
		if (dashFactor <= 0.0f)
		{
			info.pitch = ApproachAngle(info.pitch, 0.0f, SharkVars::pitch_turn_speed * 0.55f);
		}
	}

	info.y = y;
	info.breach_ticks = breachTicks;
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
	if ((newPoint - lastPoint).LengthSquared() < SharkVars::underwater_trail_point_distance * SharkVars::underwater_trail_point_distance)
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
	if (speed < SharkVars::splash_min_speed)
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

	SharkInfo@ info = GetSharkInfo(this);
	Vec3f position = Shark3DPosition(this);
	const f32 waterSurfaceY = GetSharkWaterSurface(this);
	const f32 waterDepth = waterSurfaceY - position.y;
	const bool inWater = waterDepth > 0.0f;
	const bool wasInWater = info.was_in_water;
	const f32 horizontalSpeed = Vec2f(velocity.x, velocity.z).getLength();
	const f32 speed = velocity.Length();
	const u32 time = getGameTime();

	if (inWater != wasInWater)
	{
		EmitSharkHardSplash(this, position, velocity, waterSurfaceY);
	}
	info.was_in_water = inWater;

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
		if (Maths::Abs(finWaterY - finPoint.y) <= SharkVars::surface_skim_range)
		{
			EmitSharkSkimSpray(Vec3f(finPoint.x, finWaterY + 0.18f, finPoint.z), velocity, skimPower);
		}
		if (Maths::Abs(tailWaterY - tailPoint.y) <= SharkVars::surface_skim_range)
		{
			EmitSharkSkimSpray(Vec3f(tailPoint.x, tailWaterY + 0.18f, tailPoint.z), velocity, skimPower * 0.85f);
		}
	}

	if (inWater && waterDepth > 1.0f && waterDepth < SharkVars::surface_trail_depth && time % 4 == 0)
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
	SharkInfo@ info = GetSharkInfo(this);
	f32 targetYaw = SharkCameraYaw(this) + SharkInputYawOffset(forward, back, left, right);
	f32 targetPitch = 0.0f;

	if (forward)
	{
		targetPitch = info.dir_y;
	}
	else if (back)
	{
		targetPitch = -info.dir_y;
	}

	return SharkDirection(targetYaw, Maths::Clamp(targetPitch, -65.0f, 65.0f));
}

bool HasSharkVerticalInput(CBlob@ this, bool forward, bool back)
{
	if (forward || back)
	{
		return Maths::Abs(GetSharkInfo(this).dir_y) > 8.0f;
	}

	return false;
}

void RightSharkPitch(CBlob@ this, f32 strength)
{
	if (strength <= 0.0f)
		return;

	SharkInfo@ info = GetSharkInfo(this);
	info.pitch = ApproachAngle(info.pitch, 0.0f, SharkVars::pitch_righting_speed * strength);
}

void SteerShark(CBlob@ this, bool forward, bool back, bool left, bool right)
{
	SharkInfo@ info = GetSharkInfo(this);
	if (!forward && !back && !left && !right)
	{
		RightSharkPitch(this, 1.0f);
		return;
	}

	f32 yaw = info.yaw;
	f32 pitch = info.pitch;
	f32 targetYaw = SharkCameraYaw(this) + SharkInputYawOffset(forward, back, left, right);
	f32 targetPitch = 0.0f;

	if (forward)
	{
		targetPitch = info.dir_y;
	}
	else if (back)
	{
		targetPitch = -info.dir_y;
	}

	info.yaw = ApproachAngle(yaw, targetYaw, SharkVars::turn_speed);
	if (HasSharkVerticalInput(this, forward, back))
	{
		info.pitch = ApproachAngle(pitch, Maths::Clamp(targetPitch, -65.0f, 65.0f), SharkVars::pitch_turn_speed);
	}
	else
	{
		RightSharkPitch(this, (left || right) && !forward && !back ? 0.85f : 0.45f);
	}
}

f32 SharkTurnInput(bool left, bool right)
{
	if (left && !right) return 1.0f;
	if (right && !left) return -1.0f;
	return 0.0f;
}

void AlignSharkBodyToVelocity(CBlob@ this, Vec3f velocity, bool inWater)
{
	SharkInfo@ info = GetSharkInfo(this);
	Vec2f horizontalVelocity(velocity.x, velocity.z);
	const f32 horizontalSpeed = horizontalVelocity.getLength();
	const f32 speed = velocity.Length();
	if (speed < 0.25f)
		return;

	f32 targetYaw = horizontalVelocity.getAngleDegrees() - 90.0f;
	f32 targetPitch = -Maths::ATan2(velocity.y, Maths::Max(horizontalSpeed, 0.1f)) * 180.0f / Maths::Pi;
	targetPitch = Maths::Clamp(targetPitch, -78.0f, 78.0f);

	const f32 verticalFactor = Maths::Clamp01(Maths::Abs(velocity.y) / (SharkVars::vertical_speed + SharkVars::dash_vertical_speed));
	const f32 waterAlign = inWater ? SharkVars::velocity_align_water : SharkVars::velocity_align_air;
	const f32 alignAmount = waterAlign + SharkVars::velocity_align_vertical * verticalFactor;
	info.yaw = ApproachAngle(info.yaw, targetYaw, alignAmount);
	info.pitch = ApproachAngle(info.pitch, targetPitch, alignAmount);
}

void UpdateSharkTail(CBlob@ this, Vec3f velocity, f32 speedFactor, f32 dashFactor, f32 turnInput, f32 verticalInput)
{
	SharkInfo@ info = GetSharkInfo(this);
	f32 phase = info.tail_phase;
	phase += SharkVars::tail_base_freq + SharkVars::tail_speed_freq * speedFactor + SharkVars::tail_dash_freq * dashFactor;

	f32 amp = SharkVars::tail_base_amp + SharkVars::tail_speed_amp * speedFactor + SharkVars::tail_dash_amp * dashFactor;
	Vec3f bodyRight(1.0f, 0.0f, 0.0f);
	bodyRight.xzRotateBy(info.yaw);
	f32 lateralVelocity = Maths::Clamp(velocity.Dot(bodyRight) / (SharkVars::cruise_speed + SharkVars::speed + SharkVars::dash_speed), -1.0f, 1.0f);
	f32 verticalVelocity = Maths::Clamp(velocity.y / (SharkVars::vertical_speed + SharkVars::dash_vertical_speed), -1.0f, 1.0f);
	f32 yawRate = NormalizeAngle(info.yaw - info.old_yaw);
	f32 pitchRate = NormalizeAngle(info.pitch - info.old_pitch);
	f32 bendStrength = Maths::Clamp01(speedFactor + dashFactor + 0.25f);
	f32 targetYaw = Maths::Sin(phase) * amp +
		turnInput * SharkVars::tail_turn_amp * Maths::Clamp01(speedFactor + 0.2f) -
		lateralVelocity * SharkVars::tail_velocity_yaw_amp -
		yawRate * SharkVars::tail_yaw_lag_amp;
	f32 targetPitch = -verticalInput * SharkVars::tail_pitch_amp * bendStrength +
		verticalVelocity * SharkVars::tail_velocity_pitch_amp -
		pitchRate * SharkVars::tail_pitch_lag_amp;
	info.tail_phase = phase;
	info.tail_yaw += (targetYaw - info.tail_yaw) * SharkVars::tail_steer_smooth;
	info.tail_pitch += (targetPitch - info.tail_pitch) * SharkVars::tail_steer_smooth;
}

void UpdatePlayerSharkMovement(CBlob@ this)
{
	SharkInfo@ info = GetSharkInfo(this);
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
	f32 dashTicks = Maths::Max(0.0f, info.dash_ticks - 1.0f);
	f32 dashCooldown = Maths::Max(0.0f, info.dash_cooldown - 1.0f);
	bool canDash = this.isKeyJustPressed(key_action1) && dashCooldown <= 0.0f;
	if (this.isMyPlayer())
	{
		canDash = canDash && !getHUD().hasButtons() && !getHUD().hasMenus();
	}
	if (canDash)
	{
		dashTicks = SharkVars::dash_duration;
		dashCooldown = SharkVars::dash_cooldown;
		velocity += bodyForward * (SharkVars::dash_speed * 0.65f);
		velocity.y += bodyForward.y * (SharkVars::dash_vertical_speed * 0.35f);
	}

	f32 dashFactor = Maths::Clamp01(dashTicks / SharkVars::dash_duration);
	f32 inputSpeedFactor = 0.0f;
	if (moving)
	{
		Vec3f inputDirection = SharkInputDirection(this, forward, back, left, right);
		inputSpeedFactor = Maths::Clamp01((bodyForward.Dot(inputDirection) + 0.15f) / 1.15f);
		inputSpeedFactor = SharkVars::min_input_speed_factor + (1.0f - SharkVars::min_input_speed_factor) * inputSpeedFactor * inputSpeedFactor;
	}

	f32 targetSpeed = SharkVars::cruise_speed + SharkVars::speed * inputSpeedFactor + SharkVars::dash_speed * dashFactor;
	f32 targetVerticalSpeed = SharkVars::cruise_vertical_speed + SharkVars::vertical_speed * inputSpeedFactor + SharkVars::dash_vertical_speed * dashFactor;
	Vec2f targetVel = Vec2f(bodyForward.x, bodyForward.z) * targetSpeed;
	desiredVelY = activeVerticalInput || dashFactor > 0.0f ? bodyForward.y * targetVerticalSpeed : 0.0f;
	const f32 waterDepth = GetSharkWaterSurface(this) - info.y;
	const bool inWater = waterDepth > 0.0f;
	const f32 thrustResponse = SharkVars::accel / SharkVars::mass_inertia;
	velocity.x += (targetVel.x - velocity.x) * thrustResponse;
	velocity.z += (targetVel.y - velocity.z) * thrustResponse;
	if (inWater)
	{
		velocity.x *= SharkVars::water_drag;
		velocity.z *= SharkVars::water_drag;
	}
	else
	{
		velocity.x *= SharkVars::air_horizontal_drag;
		velocity.z *= SharkVars::air_horizontal_drag;
	}

	f32 verticalTailInput = activeVerticalInput ? Maths::Clamp(info.dir_y / 65.0f, -1.0f, 1.0f) : 0.0f;
	if (back)
	{
		verticalTailInput *= -1.0f;
	}
	info.dash_ticks = dashTicks;
	info.dash_cooldown = dashCooldown;

	velocity = UpdateSharkVerticalPhysics(this, velocity, desiredVelY, activeVerticalInput, dashFactor);
	const bool velocityAlignInWater = GetSharkWaterSurface(this) - info.y > 0.0f;
	AlignSharkBodyToVelocity(this, velocity, velocityAlignInWater);
	f32 speedFactor = Maths::Clamp01((Vec2f(velocity.x, velocity.z).getLength() + Maths::Abs(velocity.y)) / (SharkVars::cruise_speed + SharkVars::speed + SharkVars::dash_speed));
	UpdateSharkTail(this, velocity, speedFactor, dashFactor, SharkTurnInput(left, right), verticalTailInput);
	SetSharkVelocity3D(this, velocity);
	UpdateSharkWaterParticles(this, velocity);
	PublishSharkRenderState(this, info);

	this.setAngleDegrees(SharkYaw(this));
}
