#include "Shapes3D.as"
#include "RigidBody.as"
#include "CustomBlocks.as"

const f32 ROCK_COLLIDER_INSET = 1.5f;
const f32 TERRAIN_GROUND_SLOP = 0.5f;
const f32 TERRAIN_VERTICAL_REST_VELOCITY = 0.05f;
const f32 COLLISION_REST_NORMAL_VELOCITY = 0.05f;
const f32 COLLISION_GROUND_NORMAL_Y = 0.5f;

//void onInit(CRules@ this)
//{
//	PhysicsWorld@ physWorld;
//	this.set("physics", @physWorld);
//}
//
shared class PhysicsWorld
{
    RigidBody@[] Bodies;
    BoundingShape@[] Colliders;

    PhysicsWorld() {}

    void RegisterBody(RigidBody@ body)
    {
        if (body is null) return;
        Bodies.push_back(body);
    }

    void RegisterCollider(BoundingShape@ shape)
    {
        if (shape is null) return;
        Colliders.push_back(shape);
    }

    void RemoveBody(RigidBody@ body)
    {
        for (uint i = 0; i < Bodies.length; i++)
        {
            if (Bodies[i] is body)
            {
                Bodies.erase(i);
                return;
            }
        }
    }

    void RemoveCollider(BoundingShape@ shape)
    {
        for (uint i = 0; i < Colliders.length; i++)
        {
            if (Colliders[i] is shape)
            {
                Colliders.erase(i);
                return;
            }
        }
    }

	void onTick()
	{
        const float dt = 0.125f;
        //print("dt = "+dt);
        if (dt <= 0.0000f) return;
        Step(dt);

	}

	void Step(float dt)
	{
	    IntegrateBodyForces(dt);
	    ResolveTerrain(dt);

	    const int MAX_ITERATIONS = 3;
	    for (int i = 0; i < MAX_ITERATIONS; i++)
	    {
	        bool found;
	        if (!SolveCollisionsAndApply(dt, found))
	            break;
	    }

	    UpdateBodies(dt);

	}

	void IntegrateBodyForces(float dt)
	{
		for (uint i = 0; i < Bodies.length; i++)
		{
			if (Bodies[i] is null)
				continue;

			Bodies[i].PreUpdate(dt);
		}
	}

	void UpdateBodies(float dt)
	{
		for (uint i = 0; i < Bodies.length; i++)
		{
			RigidBody@ body = Bodies[i];
			if (body is null)
				continue;

			body.Update(dt);
			PublishBodyTransform(body);
		}
	}

	void PublishBodyTransform(RigidBody@ body)
	{
		if (body is null || body.parent is null)
			return;

		Blob3D@ blob3d = body.parent;
		if (blob3d.shape !is null)
		{
			blob3d.shape.setPosition(blob3d.transform.Position);
		}

		CBlob@ blob = blob3d.ownerBlob;
		if (blob is null)
			return;

		blob.setPosition(blob3d.getPosition().xz());

		if (!getNet().isServer() || blob.getName() != "human")
			return;

		Vec2f pos = blob3d.getPosition().xz();
		Vec2f oldPos = blob.exists("human 3d net pos") ? blob.get_Vec2f("human 3d net pos") : pos;
		const f32 oldY = blob.exists("human 3d net y") ? blob.get_f32("human 3d net y") : blob3d.getPosition().y;
		blob.set_Vec2f("human 3d net old pos", oldPos);
		blob.set_Vec2f("human 3d net pos", pos);
		blob.set_f32("human 3d net old y", oldY);
		blob.set_f32("human 3d net y", blob3d.getPosition().y);
		blob.set_bool("onGround", blob3d.shape !is null && blob3d.shape.onGround);

		if (getGameTime() % 2 == 0)
		{
			blob.Sync("human 3d net old pos", true);
			blob.Sync("human 3d net pos", true);
			blob.Sync("human 3d net old y", true);
			blob.Sync("human 3d net y", true);
			blob.Sync("onGround", true);
		}
	}

	bool GetCollisionMtv(BoundingShape@ a, BoundingShape@ b, RigidBody@ bodyA, Vec3f &out mtv, Vec3f &out normal)
	{
		mtv = Vec3f();
		normal = Vec3f();
		if (a is null || b is null || b is a || !b.Collides)
			return false;

		if (a.Contains(b, bodyA.pendingPositionCorrection, bodyA.pendingVelocityDisplacement, mtv) == ContainmentType::None)
			return false;

		normal = mtv;
		normal = normal.Normalize();
		return true;
	}

bool SolveCollisionsAndApply(float dt, bool &out foundAny)
{
	foundAny = false;
	CBlob@[] sorted;
	CBlob@[] nearby;

	for (uint i = 0; i < Colliders.length; i++)
	{
		BoundingShape@ a = Colliders[i];

		if (a is null || !a.Collides)
			continue;

		Blob3D@ owner = a.ownerBlob;

		if (owner is null)
			continue;

		CBlob@ blob = owner.ownerBlob;

		if (blob is null)
			continue;

		nearby.clear();
		if (!getMap().getBlobsInRadius( owner.getPosition().xz(), 36.0f, @nearby)) continue;

		sorted.clear();
		sorted = getSorted(nearby, a.getPosition().xz());

		if (!sorted.empty())
		{
			RigidBody@ bodyA = owner.rb;

			if (bodyA is null)
				continue;

			Vec3f accumulatedNormal = Vec3f();
			float accumulatedRestitution = 0.0f;
			uint collisionCount = 0;

			for (uint n = 0; n < sorted.length; n++)
			{
				Blob3D@ otherBlob;

				if (!sorted[n].get("blob3d", @otherBlob))
					continue;

				RigidBody@ bodyB = otherBlob.rb;
				Vec3f mtv;
				Vec3f normal;
				if (GetCollisionMtv(a, otherBlob.shape, bodyA, mtv, normal))
				{
					foundAny = true;
					if (normal.LengthSquared() > 0.000001f)
					{
						accumulatedNormal += normal;
						accumulatedRestitution += (a.Elasticity + otherBlob.shape.Elasticity) * 0.5f;
						collisionCount++;
					}

					ResolvePairPosition(a, otherBlob.shape, bodyA, bodyB, mtv);

					if (bodyB !is null)
					{
						CalculateImpulse(bodyB, -normal, (a.Elasticity + otherBlob.shape.Elasticity) * 0.5f, true);
					}
				}

				if (otherBlob.ExtraShapes.length() > 0)
				{
					otherBlob.SyncExtraShapes();
					for (uint s = 0; s < otherBlob.ExtraShapes.length(); s++)
					{
						BoundingShape@ extraShape = otherBlob.ExtraShapes[s];
						if (!GetCollisionMtv(a, extraShape, bodyA, mtv, normal))
							continue;

						foundAny = true;
						if (normal.LengthSquared() > 0.000001f)
						{
							accumulatedNormal += normal;
							accumulatedRestitution += (a.Elasticity + extraShape.Elasticity) * 0.5f;
							collisionCount++;
						}

						ResolvePairPosition(a, extraShape, bodyA, null, mtv);
					}
				}
			}

			if (collisionCount > 0)
			{
				accumulatedNormal = accumulatedNormal.Normalize();
				MarkShapeGroundedFromCollision(bodyA, accumulatedNormal);
				CalculateImpulse(bodyA, accumulatedNormal, accumulatedRestitution / collisionCount, false);
			}
		}
	}

	return foundAny;
}

    CBlob@[] getSorted( CBlob@[] potentials, Vec2f Pos)
    {
        CBlob@[] sorted;
        if (potentials.length > 0)
        {
            while (potentials.size() > 0)
            {
                f32 closestDist = 999999.9f;
                uint closestIndex = 999;

                for (uint i = 0; i < potentials.length; i++)
                {
                    CBlob @b = potentials[i];
                    Vec2f bpos = b.getPosition();
                    f32 dist = (bpos - Pos).getLength();
                    if (dist < closestDist)
                    {
                        closestDist = dist;
                        closestIndex = i;
                    }
                }               
                if (closestIndex >= 999)
                {
                    break;
                }
                sorted.push_back(potentials[closestIndex]);
                potentials.erase(closestIndex);
            }
        }
        return sorted;
    }


	void ResolvePair(
		BoundingShape@ a,
		BoundingShape@ b,
		RigidBody@ bodyA,
		RigidBody@ bodyB,
		Vec3f mtv)
	{
		bool hasA = bodyA !is null;
		bool hasB = bodyB !is null;

		if (!hasA && !hasB) { print("no bodies"); return; }

		float eA = a.Elasticity;
		float eB = b.Elasticity;
		float restitution = (eA + eB) * 0.5f;

		Vec3f normal = mtv;
		normal = normal.Normalize();

		// Debug MTV
		//print("MTV: " + mtv.toString() + " | normal: " + normal.toString());

		if (hasA && !hasB)
		{
			bodyA.pendingPositionCorrection += mtv;
			CalculateImpulse(bodyA, normal, restitution, false);
		}
		else if (!hasA && hasB)
		{
			bodyB.pendingPositionCorrection -= mtv;
			CalculateImpulse(bodyB, -normal, restitution, true);
		}
		else
		{
			bodyA.pendingPositionCorrection += mtv * 0.5f;
			bodyB.pendingPositionCorrection -= mtv * 0.5f;

			CalculateImpulse(bodyA, normal, restitution, false);
			CalculateImpulse(bodyB, -normal, restitution, true);
		}

		//print("MTV " + mtv.toString());
		//print("Normal " + normal.toString());
		//print("Velocity " + bodyA.getVelocity().toString());
	}

	void ResolvePairPosition(
		BoundingShape@ a,
		BoundingShape@ b,
		RigidBody@ bodyA,
		RigidBody@ bodyB,
		Vec3f mtv)
	{
		bool hasA = bodyA !is null;
		bool hasB = bodyB !is null;

		if (!hasA && !hasB) { print("no bodies"); return; }

		if (hasA && !hasB)
		{
			bodyA.pendingPositionCorrection += mtv;
		}
		else if (!hasA && hasB)
		{
			bodyB.pendingPositionCorrection -= mtv;
		}
		else
		{
			bodyA.pendingPositionCorrection += mtv * 0.5f;
			bodyB.pendingPositionCorrection -= mtv * 0.5f;
		}
	}

//	void CalculateImpulse(RigidBody@ body, Vec3f normal, float restitution, bool bodyb = false)
//	{
//	    Vec3f vel = body.getVelocity();
//
//	    float vn = vel.Dot(normal);
//
//	    if (normal.y > COLLISION_GROUND_NORMAL_Y && vel.y <= COLLISION_REST_NORMAL_VELOCITY && body.parent !is null && body.parent.shape !is null)
//	    {
//	        body.parent.shape.onGround = true;
//	    }
//
//	    if (Maths::Abs(vn) < COLLISION_REST_NORMAL_VELOCITY)
//	    {
//	        vel -= normal * vn;
//	        body.setVelocity(vel);
//	        return;
//	    }
//
//	    if (vn >= 0.0f)
//	        return;
//
//	    restitution = Maths::Clamp(restitution, 0.0f, 1.0f);
//	    vel -= normal * ((1.0f + restitution) * vn);
//
//	    body.setVelocity(vel);
//	}

	void CalculateImpulse(RigidBody@ body, Vec3f normal, float restitution, bool bodyb = false)
	{
	    Vec3f vel = body.pendingVelocityCorrection;
	    if (vel.LengthSquared() <= 0.0000001f)
	    {
	        vel = body.getVelocity();
	    }

	    float vn = vel.Dot(normal);

	    if (vn >= 0.0f)
	        return;

	    restitution = Maths::Clamp(restitution, 0.0f, 1.0f);
	    vel -= normal * ((1.0f + restitution) * vn);

	    body.setSolvedVelocity(vel);
	}

	void MarkShapeGroundedFromCollision(RigidBody@ body, Vec3f normal)
	{
		if (body is null || body.parent is null || body.parent.shape is null)
			return;

		if (normal.y <= COLLISION_GROUND_NORMAL_Y)
			return;

		Vec3f vel = body.pendingVelocityCorrection;
		if (vel.LengthSquared() <= 0.0000001f)
		{
			vel = body.getVelocity();
		}

		if (vel.y <= COLLISION_REST_NORMAL_VELOCITY)
		{
			body.parent.shape.onGround = true;
		}
	}






	void ResolveTerrain(float dt)
    {
	    World@ world;
	    if (!getMap().get("terrainInfo", @world))
	        return;
	
	    for (uint i = 0; i < Bodies.length; i++)
	    {
	        RigidBody@ body = Bodies[i];
	
	        if (body is null) continue;
	
	        Blob3D@ blob3D = body.parent;
	
	
	        Vec3f predictedPosition = blob3D.transform.Position + body.pendingVelocityDisplacement + body.pendingPositionCorrection;
	
	        TerrainChunk@ chunk = world.getChunkWorldPos(predictedPosition / 16);
	
	        if (chunk is null)
	        {
	            CBlob@ ownerBlob = blob3D.ownerBlob;
	            if (ownerBlob !is null && ownerBlob.hasTag("bullet"))
	            {
	                ownerBlob.server_Die();
	            }
	            continue;
	        }
	
	        float groundHeight = chunk.getGroundHeight(predictedPosition);
	
	        Vec3f velocity = body.pendingVelocityCorrection;
	        if (velocity.LengthSquared() <= 0.0000001f)
	        {
	            velocity = body.getVelocity();
	        }
	        const bool movingUp = velocity.y > TERRAIN_VERTICAL_REST_VELOCITY;
	        if (!movingUp && predictedPosition.y <= groundHeight + TERRAIN_GROUND_SLOP)
	        {
	            if (predictedPosition.y < groundHeight)
	            {
	                body.pendingPositionCorrection.y += groundHeight - predictedPosition.y;
	            }
	
	            if (velocity.y < 0 || Maths::Abs(velocity.y) < TERRAIN_VERTICAL_REST_VELOCITY)
	            {
	                velocity.y = 0;
	                body.setSolvedVelocity(velocity);
	            }
	
	            body.parent.shape.onGround = true;
	        }
	        else
	        {
	            body.parent.shape.onGround = false;
	        }

			ResolveMapRockCollision(body, dt);
	    }
    }

	bool IsPhysicsRockTile(int tile)
	{
		return tile == CMap::rock ||
			(tile >= CMap::rock_shore_convex_RU1 && tile <= CMap::rock_shore_diagonal_L1) ||
			(tile >= CMap::rock_sand_border_convex_RU1 && tile <= CMap::rock_sand_border_diagonal_L1) ||
			(tile >= CMap::rock_shoal_border_convex_RU1 && tile <= CMap::rock_shoal_border_diagonal_L1);
	}

	bool IsPhysicsRockAt(CMap@ map, int x, int y)
	{
		if (x < 0 || y < 0 || x >= map.tilemapwidth || y >= map.tilemapheight)
			return false;

		return IsPhysicsRockTile(map.getTile(y * map.tilemapwidth + x).type);
	}

	void GetRockTileBounds(CMap@ map, int x, int y, f32 &out minX, f32 &out minZ, f32 &out maxX, f32 &out maxZ)
	{
		const u32 offset = y * map.tilemapwidth + x;
		Vec2f tileCenter = map.getTileWorldPosition(offset);
		const f32 halfTile = map.tilesize * 0.5f;

		minX = tileCenter.x - halfTile;
		maxX = tileCenter.x + halfTile;
		minZ = tileCenter.y - halfTile;
		maxZ = tileCenter.y + halfTile;

		if (!IsPhysicsRockAt(map, x - 1, y)) minX += ROCK_COLLIDER_INSET;
		if (!IsPhysicsRockAt(map, x + 1, y)) maxX -= ROCK_COLLIDER_INSET;
		if (!IsPhysicsRockAt(map, x, y - 1)) minZ += ROCK_COLLIDER_INSET;
		if (!IsPhysicsRockAt(map, x, y + 1)) maxZ -= ROCK_COLLIDER_INSET;
	}

	void ResolveMapRockCollision(RigidBody@ body, float dt)
	{
		if (body is null || body.parent is null || body.parent.shape is null)
			return;

		BoundingShape@ shape = body.parent.shape;
		if (!shape.Collides)
			return;

		Vec3f shapePredictedPosition = shape.transform.Position + body.getVelocity() * dt + body.pendingPositionCorrection;

		BoundingSphere@ sphere = cast<BoundingSphere@>(shape);
		if (sphere !is null)
		{
			Vec2f mtv;
			if (ResolveSphereVsRockTiles(sphere, shapePredictedPosition, mtv))
			{
				ApplyRockMtv(body, mtv);
			}
			return;
		}

		BoundingCapsule@ capsule = cast<BoundingCapsule@>(shape);
		if (capsule !is null)
		{
			Vec2f mtv;
			if (ResolveCapsuleVsRockTiles(capsule, shapePredictedPosition, mtv))
			{
				ApplyRockMtv(body, mtv);
			}
			return;
		}

		BoundingBox@ box = cast<BoundingBox@>(shape);
		if (box !is null)
		{
			Vec2f mtv;
			if (ResolveBoxVsRockTiles(box, shapePredictedPosition, mtv))
			{
				ApplyRockMtv(body, mtv);
			}
			return;
		}
	}

	bool ResolveSphereVsRockTiles(BoundingSphere@ sphere, Vec3f predictedPosition, Vec2f &out mtv)
	{
		return ResolveCircleVsRockTiles(Vec2f(predictedPosition.x, predictedPosition.z), float(sphere.Radius), mtv);
	}

	bool ResolveCapsuleVsRockTiles(BoundingCapsule@ capsule, Vec3f predictedPosition, Vec2f &out mtv)
	{
		return ResolveCircleVsRockTiles(Vec2f(predictedPosition.x, predictedPosition.z), capsule.Radius, mtv);
	}

	bool ResolveCircleVsRockTiles(Vec2f startCenter, f32 radius, Vec2f &out mtv)
	{
		mtv = Vec2f();
		CMap@ map = getMap();
		if (map is null)
			return false;

		const f32 minX = startCenter.x - radius;
		const f32 maxX = startCenter.x + radius;
		const f32 minZ = startCenter.y - radius;
		const f32 maxZ = startCenter.y + radius;

		Vec2f bestMtv;
		f32 bestDist = 99999999.0f;
		bool found = false;
		Vec2f totalMtv = Vec2f();
		Vec2f center = startCenter;

		for (uint pass = 0; pass < 4; pass++)
		{
			bestDist = 99999999.0f;
			found = false;

			for (int y = GetTileIndex(map, minZ - 16.0f, map.tilemapheight); y <= GetTileIndex(map, maxZ + 16.0f, map.tilemapheight); y++)
			{
				for (int x = GetTileIndex(map, minX - 16.0f, map.tilemapwidth); x <= GetTileIndex(map, maxX + 16.0f, map.tilemapwidth); x++)
				{
					const u32 offset = y * map.tilemapwidth + x;
					if (!IsPhysicsRockTile(map.getTile(offset).type))
						continue;

					f32 tileMinX;
					f32 tileMinZ;
					f32 tileMaxX;
					f32 tileMaxZ;
					GetRockTileBounds(map, x, y, tileMinX, tileMinZ, tileMaxX, tileMaxZ);

					Vec2f tileMtv;
					if (!GetSphereTileMtv(center.x, center.y, radius, tileMinX, tileMinZ, tileMaxX, tileMaxZ, tileMtv))
						continue;

					const f32 dist = tileMtv.x * tileMtv.x + tileMtv.y * tileMtv.y;
					if (dist < bestDist)
					{
						bestDist = dist;
						bestMtv = tileMtv;
						found = true;
					}
				}
			}

			if (!found)
				break;

			totalMtv += bestMtv;
			center += bestMtv;
		}

		if (totalMtv.x != 0.0f || totalMtv.y != 0.0f)
		{
			mtv = totalMtv;
			return true;
		}

		return false;
	}

	bool ResolveBoxVsRockTiles(BoundingBox@ box, Vec3f predictedPosition, Vec2f &out mtv)
	{
		mtv = Vec2f();
		CMap@ map = getMap();
		if (map is null)
			return false;

		Vec2f minFoot;
		Vec2f maxFoot;
		GetBoxFootprint(box, predictedPosition, minFoot, maxFoot);

		Vec2f bestMtv;
		f32 bestDist = 99999999.0f;
		bool found = false;
		Vec2f totalMtv = Vec2f();

		for (uint pass = 0; pass < 4; pass++)
		{
			bestDist = 99999999.0f;
			found = false;

			for (int y = GetTileIndex(map, minFoot.y - 16.0f, map.tilemapheight); y <= GetTileIndex(map, maxFoot.y + 16.0f, map.tilemapheight); y++)
			{
				for (int x = GetTileIndex(map, minFoot.x - 16.0f, map.tilemapwidth); x <= GetTileIndex(map, maxFoot.x + 16.0f, map.tilemapwidth); x++)
				{
					const u32 offset = y * map.tilemapwidth + x;
					if (!IsPhysicsRockTile(map.getTile(offset).type))
						continue;

					f32 tileMinX;
					f32 tileMinZ;
					f32 tileMaxX;
					f32 tileMaxZ;
					GetRockTileBounds(map, x, y, tileMinX, tileMinZ, tileMaxX, tileMaxZ);

					Vec2f tileMtv;
					if (!GetAabbTileMtv(minFoot, maxFoot, tileMinX, tileMinZ, tileMaxX, tileMaxZ, tileMtv))
						continue;

					const f32 dist = tileMtv.x * tileMtv.x + tileMtv.y * tileMtv.y;
					if (dist < bestDist)
					{
						bestDist = dist;
						bestMtv = tileMtv;
						found = true;
					}
				}
			}

			if (!found)
				break;

			totalMtv += bestMtv;
			minFoot += bestMtv;
			maxFoot += bestMtv;
		}

		if (totalMtv.x != 0.0f || totalMtv.y != 0.0f)
		{
			mtv = totalMtv;
			return true;
		}

		return false;
	}

	int GetTileIndex(CMap@ map, f32 worldPos, int mapLimit)
	{
		int index = int(worldPos / map.tilesize);
		if (index < 0)
			return 0;
		if (index >= mapLimit)
			return mapLimit - 1;
		return index;
	}

	bool GetSphereTileMtv(f32 cx, f32 cz, f32 radius, f32 tileX, f32 tileZ, f32 tileMaxX, f32 tileMaxZ, Vec2f &out mtv)
	{
		mtv = Vec2f();
		const f32 closestX = Maths::Clamp(cx, tileX, tileMaxX);
		const f32 closestZ = Maths::Clamp(cz, tileZ, tileMaxZ);
		Vec2f delta(cx - closestX, cz - closestZ);
		const f32 distSq = delta.x * delta.x + delta.y * delta.y;
		const f32 radiusSq = radius * radius;

		if (distSq >= radiusSq)
			return false;

		if (distSq > 0.000001f)
		{
			const f32 dist = Maths::Sqrt(distSq);
			mtv = delta * ((radius - dist) / dist);
			return true;
		}

		const f32 left = cx - tileX;
		const f32 right = tileMaxX - cx;
		const f32 up = cz - tileZ;
		const f32 down = tileMaxZ - cz;
		f32 best = left;
		mtv = Vec2f(-(radius + left), 0.0f);

		if (right < best) { best = right; mtv = Vec2f(radius + right, 0.0f); }
		if (up < best) { best = up; mtv = Vec2f(0.0f, -(radius + up)); }
		if (down < best) { mtv = Vec2f(0.0f, radius + down); }

		return true;
	}

	void GetBoxFootprint(BoundingBox@ box, Vec3f predictedPosition, Vec2f &out minFoot, Vec2f &out maxFoot)
	{
		Vec3f localCenter = (box.Min + box.Max) * 0.5f;
		Vec3f rotatedCenter = localCenter;
		rotatedCenter.rotateXZBy(box.transform.Orientation.x);
		Vec2f center(predictedPosition.x + rotatedCenter.x, predictedPosition.z + rotatedCenter.z);

		Vec2f[] corners = {
			Vec2f(box.Min.x - localCenter.x, box.Min.z - localCenter.z),
			Vec2f(box.Max.x - localCenter.x, box.Min.z - localCenter.z),
			Vec2f(box.Max.x - localCenter.x, box.Max.z - localCenter.z),
			Vec2f(box.Min.x - localCenter.x, box.Max.z - localCenter.z)
		};

		minFoot = Vec2f(99999999.0f, 99999999.0f);
		maxFoot = Vec2f(-99999999.0f, -99999999.0f);

		for (uint i = 0; i < corners.length; i++)
		{
			Vec2f corner = corners[i];
			corner.RotateBy(box.transform.Orientation.x);
			corner += center;
			minFoot.x = Maths::Min(minFoot.x, corner.x);
			minFoot.y = Maths::Min(minFoot.y, corner.y);
			maxFoot.x = Maths::Max(maxFoot.x, corner.x);
			maxFoot.y = Maths::Max(maxFoot.y, corner.y);
		}
	}

	bool GetAabbTileMtv(Vec2f minFoot, Vec2f maxFoot, f32 tileX, f32 tileZ, f32 tileMaxX, f32 tileMaxZ, Vec2f &out mtv)
	{
		mtv = Vec2f();

		if (maxFoot.x <= tileX || minFoot.x >= tileMaxX || maxFoot.y <= tileZ || minFoot.y >= tileMaxZ)
			return false;

		const f32 moveLeft = tileX - maxFoot.x;
		const f32 moveRight = tileMaxX - minFoot.x;
		const f32 moveUp = tileZ - maxFoot.y;
		const f32 moveDown = tileMaxZ - minFoot.y;
		const f32 absLeft = Maths::Abs(moveLeft);
		const f32 absRight = Maths::Abs(moveRight);
		const f32 absUp = Maths::Abs(moveUp);
		const f32 absDown = Maths::Abs(moveDown);
		const f32 absX = Maths::Min(absLeft, absRight);
		const f32 absZ = Maths::Min(absUp, absDown);

		if (absX < absZ)
		{
			if (absLeft < absRight)
			{
				mtv = Vec2f(moveLeft, 0.0f);
			}
			else
			{
				mtv = Vec2f(moveRight, 0.0f);
			}
		}
		else
		{
			if (absUp < absDown)
			{
				mtv = Vec2f(0.0f, moveUp);
			}
			else
			{
				mtv = Vec2f(0.0f, moveDown);
			}
		}

		return true;
	}

	void ApplyRockMtv(RigidBody@ body, Vec2f mtv)
	{
		body.pendingPositionCorrection.x += mtv.x;
		body.pendingPositionCorrection.z += mtv.y;

		Vec3f normal(mtv.x, 0.0f, mtv.y);
		if (normal.LengthSquared() > 0.000001f)
		{
			normal = normal.Normalize();
			CalculateImpulse(body, normal, 0.0f, false);
		}
	}

}
