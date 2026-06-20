#include "SAT_Shapes.as";
#include "BoundingCapsule.as";
#include "CollisionDebug.as";

Random rnd(941527533);
const f32 PALM_CAPSULE_RADIUS = 5.0f;
const f32 PALM_CAPSULE_HEIGHT = 38.0f;
const f32 PALM_TREE_TERRAIN_HEIGHT = 1.2f;

void onInit( CBlob@ this )
{
	Vec3f palmPosition = GetPalmColliderPosition(this);
	SAT_Shape shape(this, 5.0f, palmPosition, true, 5.1f, true, -1);
	this.set("SAT_Info", @shape);

    this.set_u8("ID", 55);
	this.Tag("prop");
	this.setAngleDegrees(rnd.NextRanged(360));
    this.getShape().SetStatic(true);
	this.getSprite().SetZ(550.0f);

	//if (getNet().isServer())
	{
		Blob3D blob3d(this, palmPosition, 6, 2.0f);
		if ( blob3d !is null )
		{	
			@blob3d.shape = BoundingCapsule(PALM_CAPSULE_RADIUS, PALM_CAPSULE_HEIGHT, palmPosition);
			//blob3d.shape.ownerBlob = blob3d;
			//blob3d.shape.SetStatic(true);
			blob3d.shape.Init(@blob3d);

			this.set("blob3d", @blob3d);
			//blob3d.shape.ownerBlob = @blob3d;
		}
	}

	
}
float angle;

f32 PalmTreeHash01(u32 seed)
{
	seed = seed * 1664525 + 1013904223;
	return float(seed % 100) * 0.01f;
}

f32 GetPalmTreeOffsetX(const u32 tileOffset)
{
	return PalmTreeHash01(tileOffset * 2 + 1);
}

f32 GetPalmTreeOffsetZ(const u32 tileOffset)
{
	return PalmTreeHash01(tileOffset * 2 + 2);
}

u32 GetPalmTreeTileOffset(CMap@ map, Vec2f worldPosition)
{
	if (map is null || map.tilesize <= 0)
	{
		return 0;
	}

	int x = int(worldPosition.x / map.tilesize);
	int y = int(worldPosition.y / map.tilesize);
	x = Maths::Clamp(x, 0, map.tilemapwidth - 1);
	y = Maths::Clamp(y, 0, map.tilemapheight - 1);
	return u32(y * map.tilemapwidth + x);
}

Vec3f GetPalmTreeWorldPosition(CMap@ map, const u32 tileOffset)
{
	if (map is null || map.tilemapwidth <= 0 || map.tilemapheight <= 0)
	{
		return Vec3f();
	}

	const int x = int(tileOffset % map.tilemapwidth);
	const int z = int(tileOffset / map.tilemapwidth);
	return Vec3f((x + GetPalmTreeOffsetX(tileOffset)) * map.tilesize, PALM_TREE_TERRAIN_HEIGHT, (z + GetPalmTreeOffsetZ(tileOffset)) * map.tilesize);
}

Vec3f GetPalmColliderPosition(CBlob@ this)
{
	if (this is null)
	{
		return Vec3f();
	}

	Vec3f fallback(this.getPosition().x, 0.0f, this.getPosition().y);
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth <= 0 || map.tilemapheight <= 0)
	{
		return fallback;
	}

	return GetPalmTreeWorldPosition(map, GetPalmTreeTileOffset(map, this.getPosition()));
}

//void onTick(CBlob@ this)
//{
//	SAT_Shape@ sat_shape;
//	if (!this.get("SAT_Info", @sat_shape))
//	return;
//	
//	sat_shape.Update(this.getPosition()+this.getVelocity());
//	this.setPosition(sat_shape.Pos.xy());
//}

void onRender(CSprite@ this)
{
	if (!IsCollisionDebugEnabled())
		return;

	SAT_Shape@ sat_shape;
	if (this.getBlob().get("SAT_Info", @sat_shape))
 	sat_shape.Render();	
}

f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	damage = 0.0f;
	return damage;
}
