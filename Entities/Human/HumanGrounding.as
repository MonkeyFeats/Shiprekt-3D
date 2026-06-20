#include "Blob3D.as"
#include "World.as"
#include "Raycast3D.as"

const f32 HUMAN_FEET_TERRAIN_SLOP = 0.35f;
const f32 HUMAN_GROUND_RAY_START_OFFSET = 4.0f;
const f32 HUMAN_GROUND_RAY_DISTANCE = 28.0f;
const f32 HUMAN_GROUNDED_MAX_UP_VELOCITY = 0.1f;
const u32 HUMAN_JUMP_GROUND_LOCK_TICKS = 6;
const string HUMAN_LAST_JUMP_TIME = "human last jump time";

Vec3f GetHumanSolvedVelocity(Blob3D@ blob3d)
{
	if (blob3d is null || blob3d.rb is null)
	{
		return Vec3f();
	}

	Vec3f velocity = blob3d.rb.pendingVelocityCorrection;
	if (velocity.LengthSquared() <= 0.0000001f)
	{
		velocity = blob3d.rb.getVelocity();
	}
	return velocity;
}

bool HasGroundColliderBelow(CBlob@ blob, Vec3f origin)
{
	f32 hitDistance;
	const Vec3f rayOrigin = origin + Vec3f(0.0f, HUMAN_GROUND_RAY_START_OFFSET, 0.0f);
	return Raycast3D::RaycastPhysicsColliders(rayOrigin, Vec3f(0.0f, -1.0f, 0.0f), HUMAN_GROUND_RAY_DISTANCE, blob, hitDistance);
}

bool AreHumanFeetGrounded(CBlob@ blob, Blob3D@ blob3d)
{
	if (blob is null || blob3d is null)
	{
		return false;
	}

	if (blob.isAttached())
	{
		return true;
	}

	const u32 lastJumpTime = blob.get_u32(HUMAN_LAST_JUMP_TIME);
	if (lastJumpTime > 0 && getGameTime() - lastJumpTime < HUMAN_JUMP_GROUND_LOCK_TICKS)
	{
		return false;
	}

	Vec3f feet = blob3d.getPosition();
	Vec3f velocity = GetHumanSolvedVelocity(blob3d);

	World@ world;
	if (getMap().get("terrainInfo", @world))
	{
		TerrainChunk@ chunk = world.getChunkWorldPos(feet / 16);
		if (chunk !is null)
		{
			const f32 groundHeight = chunk.getGroundHeight(feet);
			if (velocity.y <= HUMAN_GROUNDED_MAX_UP_VELOCITY && Maths::Abs(feet.y - groundHeight) <= HUMAN_FEET_TERRAIN_SLOP)
			{
				return true;
			}
		}
	}

	if (HasGroundColliderBelow(blob, feet))
	{
		return true;
	}

	return false;
}
