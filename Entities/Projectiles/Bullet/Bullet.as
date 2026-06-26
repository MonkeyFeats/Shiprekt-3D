#include "BlockCommon.as"
#include "IslandsCommon.as"
#include "Booty.as"
#include "AccurateSoundPlay.as"
#include "TileCommon.as"
#include "Blob3D.as"
#include "BoundingCapsule.as"
#include "Particle3D.as"
#include "OceanWave.as"

const f32 BULLET_3D_SPAWN_HEIGHT = 15.0f;
const f32 BULLET_3D_COLLIDER_RADIUS = 1.6f;
const f32 BULLET_3D_HIT_RADIUS = 3.0f;
const f32 BULLET_3D_GRAVITY_SCALE = 0.35f;
const f32 BULLET_3D_MAP_KILL_MARGIN = 64.0f;
const f32 BULLET_3D_PHYSICS_DT = 0.125f;
const f32 BULLET_SHIP_WAVE_MIN_SAMPLE_DISTANCE = 96.0f;
const f32 BULLET_SHIP_WAVE_MAX_SAMPLE_DISTANCE = 192.0f;
const bool BULLET_3D_DEBUG = false;
const string BULLET_3D_VEL_X = "bullet 3d velocity x";
const string BULLET_3D_VEL_Y = "bullet 3d velocity y";
const string BULLET_3D_VEL_Z = "bullet 3d velocity z";
const string BULLET_3D_POS_Y = "bullet 3d position y";
const string BULLET_3D_IGNORE_ID = "bullet 3d ignore id";

namespace BulletHitMaterial3D
{
	const u8 Rock = 0;
	const u8 Sand = 1;
	const u8 Water = 2;
}

Vec2f Bullet3DXZ(Vec3f v)
{
	return Vec2f(v.x, v.z);
}

void Bullet3DDebug(CBlob@ this, const string &in message)
{
	if (!BULLET_3D_DEBUG)
		return;

	const u16 id = this is null ? 0 : this.getNetworkID();
	const u32 tick = this is null ? 0 : this.getTickSinceCreated();
	print("[Bullet3D][" + id + "][" + tick + "] " + message);
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

Vec3f EnsureBullet3DVelocity(CBlob@ this)
{
	Vec2f vel2d = this.getVelocity();
	Vec3f velocity(
		this.exists(BULLET_3D_VEL_X) ? this.get_f32(BULLET_3D_VEL_X) : vel2d.x,
		this.exists(BULLET_3D_VEL_Y) ? this.get_f32(BULLET_3D_VEL_Y) : 0.0f,
		this.exists(BULLET_3D_VEL_Z) ? this.get_f32(BULLET_3D_VEL_Z) : vel2d.y
	);
	SetBullet3DVelocity(this, velocity);
	return velocity;
}

f32 EnsureBullet3DSpawnY(CBlob@ this)
{
	const f32 spawnY = this.exists(BULLET_3D_POS_Y) ? this.get_f32(BULLET_3D_POS_Y) : BULLET_3D_SPAWN_HEIGHT;
	this.set_f32(BULLET_3D_POS_Y, spawnY);
	return spawnY;
}

void onInit( CBlob@ this )
{
	Bullet3DDebug(this, "onInit begin pos2d=" + Bullet3DDebugVec2(this.getPosition()) + " vel2d=" + Bullet3DDebugVec2(this.getVelocity())
		+ " has3dVel=" + Bullet3DDebugBool(this.exists(BULLET_3D_VEL_X) && this.exists(BULLET_3D_VEL_Y) && this.exists(BULLET_3D_VEL_Z))
		+ " hasSpawnY=" + Bullet3DDebugBool(this.exists(BULLET_3D_POS_Y)));

	this.Tag("projectile");
	this.Tag("bullet");

	ShapeConsts@ consts = this.getShape().getConsts();
    consts.mapCollisions = false;
	consts.bullet = true;	
	this.set_u8("ID", 48);
	this.Tag("prop");

	this.getSprite().SetZ(550.0f);	

	if (!this.exists(BULLET_3D_IGNORE_ID))
	{
		this.set_u16(BULLET_3D_IGNORE_ID, 0);
	}

	Vec3f spawnPosition(this.getPosition().x, EnsureBullet3DSpawnY(this), this.getPosition().y);
	Bullet3DDebug(this, "spawnPosition3D=" + Bullet3DDebugVec3(spawnPosition));

	Blob3D blob3d(this, spawnPosition, this.getTeamNum(), 1.0f);
	Bullet3DDebug(this, "blob3d constructed");
	blob3d.HasMesh = false;
	@blob3d.shape = BoundingSphere(BULLET_3D_COLLIDER_RADIUS);
	Bullet3DDebug(this, "shape assigned");
	blob3d.shape.setPosition(spawnPosition);
	blob3d.shape.Elasticity = 0.0f;
	blob3d.shape.Friction = 0.05f;
	blob3d.shape.Collides = true;
	@blob3d.shape.ownerBlob = @blob3d;

	Bullet3DDebug(this, "resolve velocity begin");
	Vec3f velocity = EnsureBullet3DVelocity(this);
	Bullet3DDebug(this, "velocity3D=" + Bullet3DDebugVec3(velocity));

	RigidBody@ rb = RigidBody();
	Bullet3DDebug(this, "rigidbody constructed");
	rb.setMass(1.0f);
	Bullet3DDebug(this, "rigidbody mass set");
	rb.LinearDragScale = 0.1f;
	Bullet3DDebug(this, "rigidbody linear drag set");
	rb.AngularDragScale = 0.1f;
	Bullet3DDebug(this, "rigidbody angular drag set");
	rb.UseGravity = true;
	Bullet3DDebug(this, "rigidbody use gravity set");
	rb.GravityScale = 1.0f;
	Bullet3DDebug(this, "rigidbody gravity scale set");
	@rb.parent = @blob3d;
	Bullet3DDebug(this, "rigidbody parent set");
	@blob3d.rb = rb;
	Bullet3DDebug(this, "blob3d rb assigned");

	blob3d.rb.addImpulse(velocity * blob3d.rb.getMass());
	Bullet3DDebug(this, "impulse applied");
	if (velocity.LengthSquared() > 0.0001f)
	{
		blob3d.transform.Orientation.x = -Bullet3DXZ(velocity).Angle();
	}

	this.set("blob3d", @blob3d);
	Bullet3DDebug(this, "onInit end");
}

void onTick( CBlob@ this )
{
	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d))
	{
		Bullet3DDebug(this, "onTick missing blob3d");
		return;
	}

	if (this.getTickSinceCreated() < 5)
	{
		Bullet3DDebug(this, "onTick begin pos3d=" + Bullet3DDebugVec3(blob3d.getPosition()));
	}

	Vec3f previousPosition = blob3d.getPosition();
	if (blob3d.rb !is null)
	{
		if (this.getTickSinceCreated() < 5)
			Bullet3DDebug(this, "rb step begin vel=" + Bullet3DDebugVec3(blob3d.rb.getVelocity()));
		Vec3f oldVelocity = blob3d.rb.getVelocity();
		blob3d.rb.PreUpdate(BULLET_3D_PHYSICS_DT);
		blob3d.rb.Update(BULLET_3D_PHYSICS_DT);
		if (getNet().isServer() && oldVelocity.LengthSquared() > 0.001f && blob3d.rb.getVelocity().LengthSquared() > 0.001f)
		{
			Vec3f newVelocity = blob3d.rb.getVelocity();
			CMap@ map = getMap();
			if (map !is null && (newVelocity - oldVelocity).LengthSquared() > 9.0f && IsBulletRockTile(map.getTile(blob3d.getPosition().xz()).type))
			{
				SendBullet3DHitParticles(this, blob3d.getPosition(), oldVelocity, BulletHitMaterial3D::Rock);
				this.server_Die();
				return;
			}
		}
		if (this.getTickSinceCreated() < 5)
			Bullet3DDebug(this, "rb step end vel=" + Bullet3DDebugVec3(blob3d.rb.getVelocity()) + " pos3d=" + Bullet3DDebugVec3(blob3d.getPosition()));
	}
	else if (this.getTickSinceCreated() < 5)
	{
		Bullet3DDebug(this, "onTick rb null");
	}

	Vec3f position = blob3d.getPosition();
	Vec3f velocity = GetBullet3DVelocity(this);
	if (HandleBullet3DWorldImpact(this, position, velocity))
		return;

	if (IsBullet3DOffMap(position))
	{
		Bullet3DDebug(this, "off map die pos3d=" + Bullet3DDebugVec3(position));
		this.server_Die();
		return;
	}

	if (blob3d.rb !is null)
	{
		Vec3f bodyVelocity = blob3d.rb.getVelocity();
		if (bodyVelocity.LengthSquared() > 0.0001f)
		{
			velocity = bodyVelocity;
			SetBullet3DVelocity(this, velocity);
		}
	}

	this.setPosition(Bullet3DXZ(blob3d.getPosition()));
	this.setVelocity(Bullet3DXZ(velocity));

	if (blob3d.shape !is null)
	{
		blob3d.shape.setPosition(blob3d.getPosition());
		blob3d.shape.transform.Orientation = blob3d.transform.Orientation;
	}

	if (getNet().isServer())
	{
		if (this.getTickSinceCreated() < 5)
			Bullet3DDebug(this, "hit test begin");
		CBlob@ hitBlob = GetBullet3DHit(this, blob3d, previousPosition);
		if (hitBlob !is null)
		{
			Bullet3DDebug(this, "hit blob id=" + hitBlob.getNetworkID() + " name=" + hitBlob.getName());
			HandleBullet3DHit(this, hitBlob, blob3d.getPosition());
		}
	}
}

bool IsBulletWaterTile(u16 tileType)
{
	return tileType >= CMap::water_1 && tileType <= CMap::water;
}

bool IsBulletSandTile(u16 tileType)
{
	return tileType == CMap::sand;
}

bool IsBulletRockTile(u16 tileType)
{
	return tileType >= CMap::rock && tileType <= CMap::rock_shoal_border_diagonal_L1;
}

bool HandleBullet3DWorldImpact(CBlob@ this, Vec3f position, Vec3f velocity)
{
	if (!getNet().isServer())
		return false;

	CMap@ map = getMap();
	if (map is null)
		return false;

	const u16 tileType = map.getTile(position.xz()).type;
	if (IsBulletWaterTile(tileType) && position.y <= GetOceanWaterHeight(position) + 1.0f)
	{
		SendBullet3DHitParticles(this, Vec3f(position.x, GetOceanWaterHeight(position), position.z), velocity, BulletHitMaterial3D::Water);
		this.server_Die();
		return true;
	}

	if (position.y > 1.5f && !IsBulletRockTile(tileType))
		return false;

	if (IsBulletSandTile(tileType))
	{
		SendBullet3DHitParticles(this, Vec3f(position.x, 0.2f, position.z), velocity, BulletHitMaterial3D::Sand);
		this.server_Die();
		return true;
	}

	if (IsBulletRockTile(tileType) && position.y <= 64.0f)
	{
		SendBullet3DHitParticles(this, Vec3f(position.x, Maths::Max(position.y, 3.0f), position.z), velocity, BulletHitMaterial3D::Rock);
		this.server_Die();
		return true;
	}

	return false;
}

bool IsBullet3DOffMap(Vec3f position)
{
	CMap@ map = getMap();
	if (map is null)
		return false;

	const f32 mapWidth = map.tilemapwidth * map.tilesize;
	const f32 mapHeight = map.tilemapheight * map.tilesize;
	return position.x < -BULLET_3D_MAP_KILL_MARGIN
		|| position.z < -BULLET_3D_MAP_KILL_MARGIN
		|| position.x > mapWidth + BULLET_3D_MAP_KILL_MARGIN
		|| position.z > mapHeight + BULLET_3D_MAP_KILL_MARGIN
		|| position.y < -256.0f
		|| position.y > 512.0f;
}

Vec3f GetBullet3DVelocity(CBlob@ this)
{
	return Vec3f(
		this.exists(BULLET_3D_VEL_X) ? this.get_f32(BULLET_3D_VEL_X) : this.getVelocity().x,
		this.exists(BULLET_3D_VEL_Y) ? this.get_f32(BULLET_3D_VEL_Y) : 0.0f,
		this.exists(BULLET_3D_VEL_Z) ? this.get_f32(BULLET_3D_VEL_Z) : this.getVelocity().y
	);
}

void SetBullet3DVelocity(CBlob@ this, Vec3f velocity)
{
	this.set_f32(BULLET_3D_VEL_X, velocity.x);
	this.set_f32(BULLET_3D_VEL_Y, velocity.y);
	this.set_f32(BULLET_3D_VEL_Z, velocity.z);
}

CBlob@ GetBullet3DHit(CBlob@ this, Blob3D@ bullet3d, Vec3f previousPosition)
{
	if (bullet3d is null || bullet3d.shape is null)
		return null;

	BoundingSphere@ bulletSphere = cast<BoundingSphere@>(bullet3d.shape);
	if (bulletSphere is null)
		return null;

	CBlob@[] nearby;
	if (!getMap().getBlobsInRadius(Bullet3DXZ(bullet3d.getPosition()), BULLET_3D_HIT_RADIUS + 24.0f, @nearby))
		return null;

	CBlob@ bestBlob = null;
	f32 bestDistance = 99999999.0f;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ b = nearby[i];
		if (b is null || b is this || IsIgnoredBullet3DTarget(this, b) || !CanBullet3DHit(this, b))
			continue;

		Blob3D@ other3d;
		if (!b.get("blob3d", @other3d) || other3d is null || other3d.shape is null)
			continue;

		const f32 visualYOffset = GetBulletTargetVisualYOffset(b, other3d);
		if (!BulletSphereIntersectsBlob3DShapes(bulletSphere, previousPosition, other3d, visualYOffset))
			continue;

		Vec3f targetPosition = other3d.getPosition();
		targetPosition.y += visualYOffset;
		const f32 distance = (targetPosition - bullet3d.getPosition()).LengthSquared();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@bestBlob = b;
		}
	}

	return bestBlob;
}

bool BulletSphereIntersectsBlob3DShapes(BoundingSphere@ sphere, Vec3f previousPosition, Blob3D@ blob3d, const f32 visualYOffset = 0.0f)
{
	if (sphere is null || blob3d is null)
		return false;

	if (BulletSphereIntersectsShape(sphere, blob3d.shape, visualYOffset))
		return true;
	if (BulletSweptSphereIntersectsShape(previousPosition, sphere.getPosition(), float(sphere.Radius), blob3d.shape, visualYOffset))
		return true;

	if (blob3d.ExtraShapes.length() == 0)
		return false;

	blob3d.SyncExtraShapes();
	for (uint i = 0; i < blob3d.ExtraShapes.length(); i++)
	{
		if (BulletSphereIntersectsShape(sphere, blob3d.ExtraShapes[i], 0.0f))
			return true;
		if (BulletSweptSphereIntersectsShape(previousPosition, sphere.getPosition(), float(sphere.Radius), blob3d.ExtraShapes[i], 0.0f))
			return true;
	}

	return false;
}

bool IsIgnoredBullet3DTarget(CBlob@ this, CBlob@ b)
{
	if (b is null)
		return true;

	if (this.exists(BULLET_3D_IGNORE_ID) && b.getNetworkID() == this.get_u16(BULLET_3D_IGNORE_ID))
		return true;

	CPlayer@ owner = this.getDamageOwnerPlayer();
	CBlob@ ownerBlob = owner is null ? null : owner.getBlob();
	return ownerBlob !is null && b is ownerBlob;
}

f32 GetBulletShipWaveBobAt(Vec2f pos)
{
	Vec3f samplePos = GetShipWaveSamplePosition(pos);
	const f32 waterDisplacement = GetOceanWaterHeight(samplePos) - GetOceanRestWaterHeight();
	return Maths::Clamp(waterDisplacement * SHIP_WAVE_BOB_SCALE, -SHIP_WAVE_MAX_BOB, SHIP_WAVE_MAX_BOB);
}

f32 GetBulletIslandVisualY(Island@ island, Vec2f worldOffset)
{
	if (island is null)
		return 0.0f;

	CRules@ rules = getRules();
	if (rules !is null && rules.get_bool(SHIP_WAVE_VISUALS_DISABLED))
		return 0.0f;

	const f32 sampleDistance = Maths::Clamp(island.collisionRadius * 0.45f, BULLET_SHIP_WAVE_MIN_SAMPLE_DISTANCE, BULLET_SHIP_WAVE_MAX_SAMPLE_DISTANCE);
	const f32 invSampleSpan = 1.0f / (sampleDistance * 2.0f);
	const Vec2f sampleX(sampleDistance, 0.0f);
	const Vec2f sampleZ(0.0f, sampleDistance);
	const f32 targetYOffset = GetBulletShipWaveBobAt(island.pos);
	const f32 targetSlopeX = (GetBulletShipWaveBobAt(island.pos + sampleX) - GetBulletShipWaveBobAt(island.pos - sampleX)) * invSampleSpan;
	const f32 targetSlopeZ = (GetBulletShipWaveBobAt(island.pos + sampleZ) - GetBulletShipWaveBobAt(island.pos - sampleZ)) * invSampleSpan;
	return SHIP_WAVE_BASE_Y_OFFSET + targetYOffset + worldOffset.x * targetSlopeX + worldOffset.y * targetSlopeZ;
}

f32 GetBulletTargetVisualYOffset(CBlob@ target, Blob3D@ target3D)
{
	if (target is null || target3D is null || target.getName() != "block")
		return 0.0f;

	const int islandColor = target.getShape().getVars().customData;
	if (islandColor <= 0)
		return 0.0f;

	Island@ island = getIsland(islandColor);
	if (island is null)
		return 0.0f;

	return GetBulletIslandVisualY(island, target3D.getPosition().xz() - island.pos);
}

bool BulletSphereIntersectsShape(BoundingSphere@ sphere, BoundingShape@ shape, const f32 visualYOffset = 0.0f)
{
	if (sphere is null || shape is null)
		return false;

	BoundingBox@ box = cast<BoundingBox@>(shape);
	if (box !is null)
	{
		return BulletSphereIntersectsBox(sphere.getPosition(), float(sphere.Radius), box, visualYOffset);
	}

	BoundingSphere@ otherSphere = cast<BoundingSphere@>(shape);
	if (otherSphere !is null)
	{
		const f32 radius = float(sphere.Radius + otherSphere.Radius);
		Vec3f otherPosition = otherSphere.getPosition();
		otherPosition.y += visualYOffset;
		return (sphere.getPosition() - otherPosition).LengthSquared() <= radius * radius;
	}

	BoundingCapsule@ capsule = cast<BoundingCapsule@>(shape);
	if (capsule !is null)
	{
		return BulletSphereIntersectsCapsule(sphere.getPosition(), float(sphere.Radius), capsule, visualYOffset);
	}

	return false;
}

Vec3f BulletClosestPointOnSegment(Vec3f point, Vec3f a, Vec3f b)
{
	Vec3f ab = b - a;
	const f32 lengthSquared = ab.LengthSquared();
	if (lengthSquared <= 0.000001f)
		return a;

	const f32 t = Maths::Clamp((point - a).Dot(ab) / lengthSquared, 0.0f, 1.0f);
	return a + ab * t;
}

bool BulletSweptSphereIntersectsShape(Vec3f startPosition, Vec3f endPosition, f32 sphereRadius, BoundingShape@ shape, const f32 visualYOffset = 0.0f)
{
	if (shape is null || (endPosition - startPosition).LengthSquared() <= 0.000001f)
		return false;

	BoundingSphere@ otherSphere = cast<BoundingSphere@>(shape);
	if (otherSphere !is null)
	{
		Vec3f otherPosition = otherSphere.getPosition();
		otherPosition.y += visualYOffset;
		Vec3f closest = BulletClosestPointOnSegment(otherPosition, startPosition, endPosition);
		const f32 radius = sphereRadius + float(otherSphere.Radius);
		return (closest - otherPosition).LengthSquared() <= radius * radius;
	}

	return false;
}

bool BulletSphereIntersectsBox(Vec3f spherePosition, f32 radius, BoundingBox@ box, const f32 visualYOffset = 0.0f)
{
	Vec3f boxPosition = box.getPosition();
	boxPosition.y += visualYOffset;
	Vec3f localPosition = spherePosition - boxPosition;
	localPosition.rotateXZBy(-box.transform.Orientation.x);

	Vec3f closest = localPosition.Clamp(box.Min, box.Max);
	Vec3f offset = localPosition - closest;
	return offset.LengthSquared() <= radius * radius;
}

bool BulletSphereIntersectsCapsule(Vec3f spherePosition, f32 sphereRadius, BoundingCapsule@ capsule, const f32 visualYOffset = 0.0f)
{
	Vec3f capsulePosition = capsule.getPosition();
	capsulePosition.y += visualYOffset;

	Vec3f bottom;
	Vec3f top;
	capsule.GetWorldSegment(capsulePosition, bottom, top);
	Vec3f closest = capsule.ClosestPointOnSegment(spherePosition, bottom, top);
	const f32 radius = sphereRadius + capsule.Radius;
	return (spherePosition - closest).LengthSquared() <= radius * radius;
}

bool CanBullet3DHit(CBlob@ this, CBlob@ b)
{
	if (b is null)
		return false;

	CShape@ shape = b.getShape();
	CSprite@ sprite = b.getSprite();
	if (shape is null || sprite is null)
		return false;

	const int color = shape.getVars().customData;
	const int blockType = sprite.getFrame();
	const bool isBlock = b.getName() == "block";

	if (b.hasTag("booty") || (isBlock && color <= 0))
		return false;

	if (isBlock || b.hasTag("weapon"))
	{
		if (Block::isSolid(blockType) || (b.getTeamNum() != this.getTeamNum() && (blockType == Block::SHIPCORE || b.hasTag("weapon") || blockType == Block::BOMB || blockType == Block::DOOR)))
			return true;

		if (blockType == Block::SEAT)
		{
			AttachmentPoint@ seat = b.getAttachmentPoint(0);
			CBlob@ occupier = seat is null ? null : seat.getOccupied();
			return occupier !is null && occupier.getName() == "human" && occupier.getTeamNum() != this.getTeamNum();
		}

		return false;
	}

	if (b.getTeamNum() == this.getTeamNum() || b.isAttached())
		return false;

	return b.getName() == "shark" || b.hasTag("player");
}

void HandleBullet3DHit(CBlob@ this, CBlob@ b, Vec3f hitPosition3D)
{
	if (b is null)
		return;

	CSprite@ sprite = b.getSprite();
	if (sprite is null)
		return;

	const int blockType = sprite.getFrame();
	CBlob@ damageTarget = b;

	if (blockType == Block::SEAT)
	{
		AttachmentPoint@ seat = b.getAttachmentPoint(0);
		CBlob@ occupier = seat is null ? null : seat.getOccupied();
		if (occupier !is null && occupier.getName() == "human" && occupier.getTeamNum() != this.getTeamNum() && XORRandom(3) == 0)
		{
			@damageTarget = occupier;
		}
	}

	CPlayer@ owner = this.getDamageOwnerPlayer();
	if (owner !is null)
	{
		CBlob@ blob = owner.getBlob();
		if (blob !is null)
			damageBooty(owner, blob, damageTarget);
	}

	Vec2f hitPosition = Bullet3DXZ(hitPosition3D);
	SendBullet3DHitParticles(this, hitPosition3D, GetBullet3DVelocity(this), GetBullet3DHitMaterial(b));
	this.server_Hit(damageTarget, hitPosition, Vec2f_zero, getDamage(damageTarget, blockType), 0, true);
	this.server_Die();
}

u8 GetBullet3DHitMaterial(CBlob@ hitBlob)
{
	if (hitBlob is null)
		return BulletHitMaterial3D::Rock;

	if (hitBlob.getName() == "human" || hitBlob.getName() == "shark" || hitBlob.hasTag("player"))
		return BulletHitMaterial3D::Rock;

	return BulletHitMaterial3D::Rock;
}

void SendBullet3DHitParticles(CBlob@ this, Vec3f hitPosition3D, Vec3f incomingVelocity, u8 material)
{
	if (!getNet().isServer())
		return;

	if (material == BulletHitMaterial3D::Sand)
	{
		SendParticle3DEvent(Particle3DEvent::SandImpact, hitPosition3D, incomingVelocity, 1.0f, 0, this.getNetworkID());
	}
	else if (material == BulletHitMaterial3D::Water)
	{
		SendParticle3DEvent(Particle3DEvent::WaterSplash, hitPosition3D, incomingVelocity, 0.75f, 0, this.getNetworkID());
	}
	else
	{
		SendParticle3DEvent(Particle3DEvent::BulletHit, hitPosition3D, incomingVelocity, 1.0f, 0, this.getNetworkID());
	}
}

f32 getDamage( CBlob@ hitBlob, int blockType )
{
	if ( blockType == Block::POINTDEFENSE )
		return 0.25f;

	if ( hitBlob.hasTag( "weapon" ) )
		return 0.7f;
		
	if ( blockType == Block::PROPELLER )
		return 0.75f;

	if ( blockType == Block::DOOR )
		return 0.7f;
		
		
	if ( blockType == Block::RAMENGINE )
		return 1.5f;
		
	if ( hitBlob.getName() == "shark" || hitBlob.getName() == "human" )
		return 0.4f;
	
	if ( Block::isBomb( blockType ) )
		return 1.35f;
				
	if ( blockType == Block::SEAT )
		return 0.4f;
		
	return 0.25f;//cores | solids
}

void onDie( CBlob@ this )
{
}

void onSendCreateData( CBlob@ this, CBitStream@ stream )
{
	Vec3f velocity3D = EnsureBullet3DVelocity(this);
	Bullet3DDebug(this, "onSendCreateData vel2d=" + Bullet3DDebugVec2(this.getVelocity()) + " vel3d=" + Bullet3DDebugVec3(velocity3D));
	stream.write_Vec2f(this.getVelocity());
	stream.write_f32(EnsureBullet3DSpawnY(this));
	stream.write_f32(velocity3D.x);
	stream.write_f32(velocity3D.y);
	stream.write_f32(velocity3D.z);
	stream.write_u16(this.exists(BULLET_3D_IGNORE_ID) ? this.get_u16(BULLET_3D_IGNORE_ID) : 0);
}

bool onReceiveCreateData( CBlob@ this, CBitStream@ stream )
{
	Bullet3DDebug(this, "onReceiveCreateData begin");
	Vec2f velocity;
	if (!stream.saferead_Vec2f(velocity))
	{
		warn("Bullet::onReceiveCreateData - missing velocity");
		return false;
	}

	this.setVelocity(velocity);
	f32 spawnY;
	f32 velocityX;
	f32 velocityY;
	f32 velocityZ;
	u16 ignoreID = 0;
	if (stream.saferead_f32(spawnY) && stream.saferead_f32(velocityX) && stream.saferead_f32(velocityY) && stream.saferead_f32(velocityZ))
	{
		Bullet3DDebug(this, "onReceiveCreateData full spawnY=" + spawnY + " vel3d=(" + velocityX + ", " + velocityY + ", " + velocityZ + ")");
		this.set_f32(BULLET_3D_POS_Y, spawnY);
		this.set_f32(BULLET_3D_VEL_X, velocityX);
		this.set_f32(BULLET_3D_VEL_Y, velocityY);
		this.set_f32(BULLET_3D_VEL_Z, velocityZ);
		if (stream.saferead_u16(ignoreID))
		{
			this.set_u16(BULLET_3D_IGNORE_ID, ignoreID);
		}

		Blob3D@ blob3d;
		if (this.get("blob3d", @blob3d) && blob3d !is null)
		{
			Vec3f position = blob3d.getPosition();
			position.y = spawnY;
			blob3d.setPosition(position);
			if (blob3d.shape !is null)
			{
				blob3d.shape.setPosition(position);
			}
			SetBullet3DVelocity(this, Vec3f(velocityX, velocityY, velocityZ));
			if (blob3d.rb !is null)
			{
				blob3d.rb.setVelocity(Vec3f(velocityX, velocityY, velocityZ));
			}
		}
	}
	else
	{
		Bullet3DDebug(this, "onReceiveCreateData fallback vel2d=" + Bullet3DDebugVec2(velocity));
		SetBullet3DVelocity(this, Vec3f(velocity.x, 0.0f, velocity.y));
	}
	return true;
}

Random _sprk_r;
void sparks(Vec2f pos, int amount)
{
	EmitBulletHitParticles3D(Vec3f(pos.x, 8.0f, pos.y), Vec3f(_sprk_r.NextFloat() - 0.5f, 0.0f, _sprk_r.NextFloat() - 0.5f));
}

void onHitBlob( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData )
{
	CSprite@ sprite = hitBlob.getSprite();
	const int blockType = sprite.getFrame();

	if (hitBlob.getName() == "shark"){
		ParticleBloodSplat( worldPoint, true );
		directionalSoundPlay( "BodyGibFall", worldPoint );
	}
	else	if (hitBlob.hasTag("player") && hitBlob.getTeamNum() != this.getTeamNum())
	{
		directionalSoundPlay( "ImpactFlesh", worldPoint );
		ParticleBloodSplat( worldPoint, true );
	}
	else	if (Block::isSolid(blockType) || blockType == Block::SHIPCORE || hitBlob.hasTag("weapon") || blockType == Block::PLATFORM || blockType == Block::SEAT || Block::isBomb( blockType ) || blockType == Block::DOOR)
	{
		directionalSoundPlay( "Ricochet" +  ( XORRandom(3) + 1 ) + ".ogg", worldPoint, 0.50f );
	}
}

void damageBooty( CPlayer@ attacker, CBlob@ attackerBlob, CBlob@ victim )
{
	if ( victim.getName() == "block" )
	{
		const int blockType = victim.getSprite().getFrame();
		u8 teamNum = attacker.getTeamNum();
		u8 victimTeamNum = victim.getTeamNum();
		string attackerName = attacker.getUsername();
		Island@ victimIsle = getIsland( victim.getShape().getVars().customData );

		if ( victimIsle !is null && victimIsle.blocks.length > 3
			&& ( victimIsle.owner != "" || victimIsle.isMothership )
			&& victimTeamNum != teamNum
			&& ( victim.hasTag("propeller") || victim.hasTag("weapon") || blockType == Block::SHIPCORE || Block::isBomb( blockType ) || blockType == Block::SEAT || blockType == Block::DOOR )
			)
		{
			if ( attacker.isMyPlayer() )
				Sound::Play( "Pinball_0", attackerBlob.getPosition(), 0.5f );

			if ( getNet().isServer() )
			{
				CRules@ rules = getRules();
				
				u16 reward = 7;//propellers, seat
				if ( victim.hasTag( "weapon" ) || Block::isBomb( blockType ) )
					reward += 5;
				else if ( blockType == Block::SHIPCORE )
					reward += 10;

				f32 bFactor = ( rules.get_bool( "whirlpool" ) ? 3.0f : 1.0f ) * Maths::Min( 2.5f, Maths::Max( 0.15f,
				( 2.0f * rules.get_u16( "bootyTeam_total" + victimTeamNum ) - rules.get_u16( "bootyTeam_total" + teamNum ) + 1000 )/( rules.get_u32( "bootyTeam_median" ) + 1000 ) ) );
				
				reward = Maths::Round( reward * bFactor );
								
				server_setPlayerBooty( attackerName, server_getPlayerBooty( attackerName ) + reward );
				server_updateTotalBooty( teamNum, reward );
			}
		}
	}
}
