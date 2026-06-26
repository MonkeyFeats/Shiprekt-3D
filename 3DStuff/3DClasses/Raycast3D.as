#include "Camera3D.as"
#include "BoundingBox.as"
#include "BoundingSphere.as"
#include "BoundingCapsule.as"
#include "PhysicsEngine.as"
#include "Transform.as"
#include "Vec3f.as"

namespace Raycast3D
{
	const f32 INTERACT_RAY_DISTANCE = 160.0f;
	const f32 INTERACT_PLAYER_DISTANCE = 48.0f;
	const f32 BUILD_RAY_DISTANCE = 512.0f;
	const f32 PLACEMENT_PLANE_Y = 0.0f;
	const f32 CAMERA_RAY_START_FORWARD_OFFSET = 0.0f;
	const f32 FIRST_PERSON_RAY_EYE_HEIGHT = 16.0f;
	const f32 BLOCK_RAY_START_EPSILON = 0.25f;
	const f32 EPSILON = 0.00001f;

	shared class Ray3D
	{
		Vec3f origin;
		Vec3f direction;

		Ray3D() {}

		Ray3D(Vec3f _origin, Vec3f _direction)
		{
			origin = _origin;
			direction = _direction.Normalize();
		}

		Vec3f GetPoint(const f32 distance)
		{
			return origin + direction * distance;
		}
	}

	shared class RaycastHit3D
	{
		bool hit = false;
		f32 distance = 0.0f;
		Vec3f point;
		Vec3f normal;
		CBlob@ blob;
		BoundingShape@ shape;

		RaycastHit3D()
		{
			Clear();
		}

		void Clear()
		{
			hit = false;
			distance = 0.0f;
			point = Vec3f();
			normal = Vec3f();
			@blob = null;
			@shape = null;
		}

		void Set(Ray3D ray, const f32 _distance, Vec3f _normal)
		{
			hit = true;
			distance = _distance;
			point = ray.GetPoint(_distance);
			normal = _normal.Normalize();
			@blob = null;
			@shape = null;
		}
	}

	shared Vec3f CameraForward(Camera3D@ camera)
	{
		if (camera is null)
		{
			return Vec3f();
		}

		return camera.getDirection();
	}

	shared Vec3f GetCameraAimOrigin(Camera3D@ camera)
	{
		if (camera is null)
		{
			return Vec3f();
		}

		Vec3f origin = camera.getPosition();
		Blob3D@ target = camera.getTarget();
		if (target is null)
		{
			return origin;
		}

		Vec3f off = camera.pos_offset;
		Vec3f rotation = target.transform.Orientation.getXYZ();
		off.yzRotateBy(rotation.y);
		off.xzRotateBy(rotation.x);
		origin.y = target.getPosition().y + off.y;
		return origin;
	}

	shared bool IsFirstPersonRayCameraEnabled()
	{
		CRules@ rules = getRules();
		return rules is null || !rules.exists("first person camera enabled") || rules.get_bool("first person camera enabled");
	}

	shared Vec3f GetLocalCameraAimOrigin(CBlob@ caller, Camera3D@ camera)
	{
		if (caller !is null && caller.isMyPlayer() && !caller.isAttached() && IsFirstPersonRayCameraEnabled())
		{
			Blob3D@ blob3d;
			if (caller.get("blob3d", @blob3d) && blob3d !is null)
			{
				return blob3d.getRenderPosition() + Vec3f(0.0f, FIRST_PERSON_RAY_EYE_HEIGHT, 0.0f);
			}
		}

		return GetCameraAimOrigin(camera);
	}

	shared f32 GetBuildPlaneY(CBlob@ builder)
	{
		if (builder is null)
		{
			return PLACEMENT_PLANE_Y;
		}

		Blob3D@ blob3d;
		if (builder.get("blob3d", @blob3d) && blob3d !is null)
		{
			return blob3d.getPosition().y;
		}

		return PLACEMENT_PLANE_Y;
	}

	shared bool GetLocalCameraRay(CBlob@ caller, Ray3D &out ray)
	{
		if (caller is null || !caller.isMyPlayer())
		{
			return false;
		}

		CPlayer@ player = caller.getPlayer();
		if (player is null)
		{
			return false;
		}

		Camera3D@ camera;
		if (!player.get("Camera3D", @camera) || camera is null)
		{
			return false;
		}

		Vec3f direction = CameraForward(camera);
		if (direction.LengthSquared() <= EPSILON)
		{
			return false;
		}

		ray = Ray3D(GetLocalCameraAimOrigin(caller, camera) + direction.Normalize() * CAMERA_RAY_START_FORWARD_OFFSET, direction);
		return true;
	}

	shared bool GetLocalCameraRay(CBlob@ caller, Vec3f &out origin, Vec3f &out direction)
	{
		Ray3D ray;
		if (!GetLocalCameraRay(caller, ray))
		{
			return false;
		}

		origin = ray.origin;
		direction = ray.direction;
		return true;
	}

	shared bool RaycastPlane(Ray3D ray, Vec3f planePoint, Vec3f planeNormal, const f32 maxDistance, RaycastHit3D &out hit)
	{
		hit.Clear();

		Vec3f normal = planeNormal.Normalize();
		const f32 denominator = normal.Dot(ray.direction);
		if (Maths::Abs(denominator) < EPSILON)
		{
			return false;
		}

		const f32 distance = normal.Dot(planePoint - ray.origin) / denominator;
		if (distance < 0.0f || distance > maxDistance)
		{
			return false;
		}

		hit.Set(ray, distance, normal);
		return true;
	}

	shared bool RaycastYPlane(Ray3D ray, const f32 planeY, const f32 maxDistance, RaycastHit3D &out hit)
	{
		return RaycastPlane(ray, Vec3f(0.0f, planeY, 0.0f), Vec3f(0.0f, 1.0f, 0.0f), maxDistance, hit);
	}

	shared bool RaycastYPlane(Vec3f origin, Vec3f direction, const f32 planeY, const f32 maxDistance, f32 &out distance)
	{
		Ray3D ray(origin, direction);
		RaycastHit3D hit;
		if (!RaycastYPlane(ray, planeY, maxDistance, hit))
		{
			return false;
		}

		distance = hit.distance;
		return true;
	}

	shared Vec3f RotateByTransformEuler(Vec3f value, Vec3f rotation)
	{
		value.xyRotateBy(rotation.z);
		value.yzRotateBy(rotation.y);
		value.xzRotateBy(rotation.x);
		return value;
	}

	shared Vec3f InverseRotateByTransformEuler(Vec3f value, Vec3f rotation)
	{
		value.xzRotateBy(-rotation.x);
		value.yzRotateBy(-rotation.y);
		value.xyRotateBy(-rotation.z);
		return value;
	}

	shared void UpdateBlobRaycastTransform(CBlob@ blob, Blob3D@ blob3d)
	{
		if (blob is null || blob3d is null)
		{
			return;
		}

		if (SyncExistingIslandBlockRaycastTransform(blob, blob3d))
		{
			return;
		}

		Vec2f pos = blob.getInterpolatedPosition();
		blob3d.transform.Position.x = pos.x;
		blob3d.transform.Position.y = 0.0f;
		blob3d.transform.Position.z = pos.y;
		blob3d.transform.Orientation.x = blob.getAngleDegrees();
		blob3d.transform.Orientation.y = 0.0f;
		blob3d.transform.Orientation.z = 0.0f;
		blob3d.renderOffset = Vec3f();
		blob3d.renderRotation = Vec3f();

		if (blob3d.shape !is null)
		{
			Vec3f renderRotation = blob3d.getInheritedRenderRotation();
			blob3d.shape.transform.Position = blob3d.getRenderPosition();
			blob3d.shape.transform.Orientation.x = blob3d.transform.Orientation.x;
			blob3d.shape.transform.Orientation.y = renderRotation.x;
			blob3d.shape.transform.Orientation.z = renderRotation.z;
		}
	}

	shared bool SyncExistingIslandBlockRaycastTransform(CBlob@ blob, Blob3D@ blob3d)
	{
		if (blob is null || blob3d is null || blob.getName() != "block")
		{
			return false;
		}

		if (blob.getShape().getVars().customData <= 0)
		{
			return false;
		}

		if (blob3d.shape !is null)
		{
			Vec3f renderRotation = blob3d.getInheritedRenderRotation();
			blob3d.shape.transform.Position = blob3d.getRenderPosition();
			blob3d.shape.transform.Orientation.x = blob3d.transform.Orientation.x;
			blob3d.shape.transform.Orientation.y = renderRotation.x;
			blob3d.shape.transform.Orientation.z = renderRotation.z;
		}

		return true;
	}

	shared bool RaycastBoundingBox(Ray3D ray, BoundingBox@ box, const f32 maxDistance, RaycastHit3D &out hit)
	{
		hit.Clear();
		if (box is null)
		{
			return false;
		}

		Vec3f rotation = box.transform.Orientation.getXYZ();
		Vec3f localOrigin = InverseRotateByTransformEuler(ray.origin - box.transform.Position, rotation);
		Vec3f localDirection = InverseRotateByTransformEuler(ray.direction, rotation);

		f32 tMin = 0.0f;
		f32 tMax = maxDistance;
		Vec3f localNormal;
		f32 nextTMin;
		f32 nextTMax;
		Vec3f nextNormal;

		if (!Slab(localOrigin.x, localDirection.x, box.Min.x, box.Max.x, Vec3f(1.0f, 0.0f, 0.0f), tMin, tMax, localNormal, nextTMin, nextTMax, nextNormal)) return false;
		tMin = nextTMin; tMax = nextTMax; localNormal = nextNormal;
		if (!Slab(localOrigin.y, localDirection.y, box.Min.y, box.Max.y, Vec3f(0.0f, 1.0f, 0.0f), tMin, tMax, localNormal, nextTMin, nextTMax, nextNormal)) return false;
		tMin = nextTMin; tMax = nextTMax; localNormal = nextNormal;
		if (!Slab(localOrigin.z, localDirection.z, box.Min.z, box.Max.z, Vec3f(0.0f, 0.0f, 1.0f), tMin, tMax, localNormal, nextTMin, nextTMax, nextNormal)) return false;
		tMin = nextTMin; tMax = nextTMax; localNormal = nextNormal;

		Vec3f worldNormal = RotateByTransformEuler(localNormal, rotation);
		hit.Set(ray, tMin, worldNormal);
		@hit.shape = box;
		return true;
	}

	shared bool RaycastBoundingBox(Vec3f origin, Vec3f direction, BoundingBox@ box, const f32 maxDistance, f32 &out distance)
	{
		Ray3D ray(origin, direction);
		RaycastHit3D hit;
		if (!RaycastBoundingBox(ray, box, maxDistance, hit))
		{
			return false;
		}

		distance = hit.distance;
		return true;
	}

	shared bool RaycastBoundingSphere(Ray3D ray, BoundingSphere@ sphere, const f32 maxDistance, RaycastHit3D &out hit)
	{
		hit.Clear();
		if (sphere is null)
		{
			return false;
		}

		Vec3f offset = ray.origin - sphere.transform.Position;
		const f32 a = ray.direction.Dot(ray.direction);
		const f32 b = 2.0f * offset.Dot(ray.direction);
		const f32 c = offset.Dot(offset) - sphere.Radius * sphere.Radius;
		const f32 discriminant = b * b - 4.0f * a * c;
		if (discriminant < 0.0f || Maths::Abs(a) < EPSILON)
		{
			return false;
		}

		const f32 sqrtDiscriminant = Maths::Sqrt(discriminant);
		const f32 invDenominator = 1.0f / (2.0f * a);
		f32 distance = (-b - sqrtDiscriminant) * invDenominator;
		if (distance < 0.0f)
		{
			distance = (-b + sqrtDiscriminant) * invDenominator;
		}

		if (distance < 0.0f || distance > maxDistance)
		{
			return false;
		}

		Vec3f point = ray.GetPoint(distance);
		hit.Set(ray, distance, point - sphere.transform.Position);
		@hit.shape = sphere;
		return true;
	}

	shared bool RaycastBoundingSphere(Vec3f origin, Vec3f direction, BoundingSphere@ sphere, const f32 maxDistance, f32 &out distance)
	{
		Ray3D ray(origin, direction);
		RaycastHit3D hit;
		if (!RaycastBoundingSphere(ray, sphere, maxDistance, hit))
		{
			return false;
		}

		distance = hit.distance;
		return true;
	}

	shared bool RaycastLocalSphere(Vec3f origin, Vec3f direction, Vec3f center, const f32 radius, const f32 maxDistance, f32 &out distance, Vec3f &out normal)
	{
		Vec3f offset = origin - center;
		const f32 a = direction.Dot(direction);
		const f32 b = 2.0f * offset.Dot(direction);
		const f32 c = offset.Dot(offset) - radius * radius;
		const f32 discriminant = b * b - 4.0f * a * c;
		if (discriminant < 0.0f || Maths::Abs(a) < EPSILON)
		{
			return false;
		}

		const f32 sqrtDiscriminant = Maths::Sqrt(discriminant);
		const f32 invDenominator = 1.0f / (2.0f * a);
		f32 t = (-b - sqrtDiscriminant) * invDenominator;
		if (t < 0.0f)
		{
			t = (-b + sqrtDiscriminant) * invDenominator;
		}

		if (t < 0.0f || t > maxDistance)
		{
			return false;
		}

		Vec3f point = origin + direction * t;
		normal = (point - center).Normalize();
		if (normal.LengthSquared() <= EPSILON)
		{
			normal = Vec3f(0.0f, 1.0f, 0.0f);
		}
		distance = t;
		return true;
	}

	shared bool RaycastBoundingCapsule(Ray3D ray, BoundingCapsule@ capsule, const f32 maxDistance, RaycastHit3D &out hit)
	{
		hit.Clear();
		if (capsule is null)
		{
			return false;
		}

		Vec3f rotation = capsule.transform.Orientation.getXYZ();
		Vec3f localOrigin = InverseRotateByTransformEuler(ray.origin - capsule.transform.Position, rotation);
		Vec3f localDirection = InverseRotateByTransformEuler(ray.direction, rotation);

		bool found = false;
		f32 bestDistance = maxDistance;
		Vec3f bestNormal;

		const f32 a = localDirection.x * localDirection.x + localDirection.z * localDirection.z;
		const f32 b = 2.0f * (localOrigin.x * localDirection.x + localOrigin.z * localDirection.z);
		const f32 c = localOrigin.x * localOrigin.x + localOrigin.z * localOrigin.z - capsule.Radius * capsule.Radius;
		const f32 disc = b * b - 4.0f * a * c;
		if (disc >= 0.0f && Maths::Abs(a) > EPSILON)
		{
			const f32 sqrtDisc = Maths::Sqrt(disc);
			const f32 invDenominator = 1.0f / (2.0f * a);
			for (uint i = 0; i < 2; i++)
			{
				const f32 t = ((i == 0 ? -b - sqrtDisc : -b + sqrtDisc) * invDenominator);
				if (t < 0.0f || t > bestDistance)
				{
					continue;
				}

				const f32 y = localOrigin.y + localDirection.y * t;
				if (y < capsule.GetBottomY() || y > capsule.GetTopY())
				{
					continue;
				}

				Vec3f point = localOrigin + localDirection * t;
				Vec3f normal(point.x, 0.0f, point.z);
				normal = normal.Normalize();
				if (normal.LengthSquared() <= EPSILON)
				{
					continue;
				}

				bestDistance = t;
				bestNormal = normal;
				found = true;
			}
		}

		f32 capDistance;
		Vec3f capNormal;
		if (RaycastLocalSphere(localOrigin, localDirection, Vec3f(0.0f, capsule.GetBottomY(), 0.0f), capsule.Radius, bestDistance, capDistance, capNormal))
		{
			bestDistance = capDistance;
			bestNormal = capNormal;
			found = true;
		}
		if (RaycastLocalSphere(localOrigin, localDirection, Vec3f(0.0f, capsule.GetTopY(), 0.0f), capsule.Radius, bestDistance, capDistance, capNormal))
		{
			bestDistance = capDistance;
			bestNormal = capNormal;
			found = true;
		}

		if (!found)
		{
			return false;
		}

		Vec3f worldNormal = RotateByTransformEuler(bestNormal, rotation);
		hit.Set(ray, bestDistance, worldNormal);
		@hit.shape = capsule;
		return true;
	}

	shared bool RaycastBoundingCapsule(Vec3f origin, Vec3f direction, BoundingCapsule@ capsule, const f32 maxDistance, f32 &out distance)
	{
		Ray3D ray(origin, direction);
		RaycastHit3D hit;
		if (!RaycastBoundingCapsule(ray, capsule, maxDistance, hit))
		{
			return false;
		}

		distance = hit.distance;
		return true;
	}

	shared bool RaycastPhysicsColliders(Ray3D ray, const f32 maxDistance, CBlob@ ignore, RaycastHit3D &out closestHit)
	{
		closestHit.Clear();
		closestHit.distance = maxDistance;

		PhysicsWorld@ physicsWorld;
		if (!getRules().get("physics", @physicsWorld) || physicsWorld is null)
		{
			return false;
		}

		bool found = false;
		for (uint i = 0; i < physicsWorld.Colliders.length; i++)
		{
			BoundingShape@ shape = physicsWorld.Colliders[i];
			if (shape is null || !shape.Collides)
			{
				continue;
			}

			CBlob@ ownerBlob = null;
			if (shape.ownerBlob !is null)
			{
				@ownerBlob = shape.ownerBlob.ownerBlob;
			}
			if (ownerBlob is ignore)
			{
				continue;
			}

			RaycastHit3D hit;
			BoundingBox@ box = cast<BoundingBox@>(shape);
			if (box !is null && RaycastBoundingBox(ray, box, maxDistance, hit) && hit.distance < closestHit.distance)
			{
				@hit.blob = ownerBlob;
				closestHit = hit;
				found = true;
				continue;
			}

			BoundingSphere@ sphere = cast<BoundingSphere@>(shape);
			if (sphere !is null && RaycastBoundingSphere(ray, sphere, maxDistance, hit) && hit.distance < closestHit.distance)
			{
				@hit.blob = ownerBlob;
				closestHit = hit;
				found = true;
				continue;
			}

			BoundingCapsule@ capsule = cast<BoundingCapsule@>(shape);
			if (capsule !is null && RaycastBoundingCapsule(ray, capsule, maxDistance, hit) && hit.distance < closestHit.distance)
			{
				@hit.blob = ownerBlob;
				closestHit = hit;
				found = true;
			}
		}

		return found;
	}

	shared bool RaycastPhysicsColliders(Vec3f origin, Vec3f direction, const f32 maxDistance, CBlob@ ignore, f32 &out hitDistance)
	{
		RaycastHit3D hit;
		if (!RaycastPhysicsColliders(Ray3D(origin, direction), maxDistance, ignore, hit))
		{
			hitDistance = maxDistance;
			return false;
		}

		hitDistance = hit.distance;
		return true;
	}

	shared bool RaycastBlockTarget(Ray3D ray, const f32 maxDistance, CBlob@ ignore, RaycastHit3D &out closestHit)
	{
		return RaycastBlockTarget(ray, 0.0f, maxDistance, ignore, closestHit);
	}

	shared bool RaycastBlockTarget(Ray3D ray, const f32 minDistance, const f32 maxDistance, CBlob@ ignore, RaycastHit3D &out closestHit)
	{
		closestHit.Clear();
		closestHit.distance = maxDistance;

		CBlob@[] blocks;
		if (!getBlobsByName("block", @blocks))
		{
			return false;
		}

		bool found = false;
		for (uint i = 0; i < blocks.length; ++i)
		{
			CBlob@ block = blocks[i];
			if (!IsRaycastBlockCandidate(block, ignore))
			{
				continue;
			}

			Blob3D@ blob3d;
			if (!block.get("blob3d", @blob3d) || blob3d is null || blob3d.shape is null)
			{
				continue;
			}
			UpdateBlobRaycastTransform(block, blob3d);

			RaycastHit3D hit;
			BoundingBox@ box = cast<BoundingBox@>(blob3d.shape);
			if (box !is null && RaycastBoundingBox(ray, box, maxDistance, hit) && hit.distance >= minDistance && hit.distance < closestHit.distance)
			{
				@hit.blob = block;
				@hit.shape = blob3d.shape;
				closestHit = hit;
				found = true;
			}

			BoundingSphere@ sphere = cast<BoundingSphere@>(blob3d.shape);
			if (sphere !is null && RaycastBoundingSphere(ray, sphere, maxDistance, hit) && hit.distance >= minDistance && hit.distance < closestHit.distance)
			{
				@hit.blob = block;
				@hit.shape = blob3d.shape;
				closestHit = hit;
				found = true;
			}

			BoundingCapsule@ capsule = cast<BoundingCapsule@>(blob3d.shape);
			if (capsule !is null && RaycastBoundingCapsule(ray, capsule, maxDistance, hit) && hit.distance >= minDistance && hit.distance < closestHit.distance)
			{
				@hit.blob = block;
				@hit.shape = blob3d.shape;
				closestHit = hit;
				found = true;
			}

			if (blob3d.ExtraShapes.length() > 0)
			{
				blob3d.SyncExtraShapes();
				for (uint s = 0; s < blob3d.ExtraShapes.length(); s++)
				{
					BoundingShape@ extraShape = blob3d.ExtraShapes[s];
					if (extraShape is null || !extraShape.Collides)
						continue;

					BoundingBox@ extraBox = cast<BoundingBox@>(extraShape);
					if (extraBox !is null && RaycastBoundingBox(ray, extraBox, maxDistance, hit) && hit.distance >= minDistance && hit.distance < closestHit.distance)
					{
						@hit.blob = block;
						@hit.shape = extraShape;
						closestHit = hit;
						found = true;
						continue;
					}

					BoundingSphere@ extraSphere = cast<BoundingSphere@>(extraShape);
					if (extraSphere !is null && RaycastBoundingSphere(ray, extraSphere, maxDistance, hit) && hit.distance >= minDistance && hit.distance < closestHit.distance)
					{
						@hit.blob = block;
						@hit.shape = extraShape;
						closestHit = hit;
						found = true;
						continue;
					}

					BoundingCapsule@ extraCapsule = cast<BoundingCapsule@>(extraShape);
					if (extraCapsule !is null && RaycastBoundingCapsule(ray, extraCapsule, maxDistance, hit) && hit.distance >= minDistance && hit.distance < closestHit.distance)
					{
						@hit.blob = block;
						@hit.shape = extraShape;
						closestHit = hit;
						found = true;
					}
				}
			}
		}

		return found;
	}

	shared bool RaycastBlockTarget(Vec3f origin, Vec3f direction, const f32 maxDistance, CBlob@ ignore, u16 &out hitID, f32 &out hitDistance)
	{
		RaycastHit3D hit;
		if (!RaycastBlockTarget(Ray3D(origin, direction), maxDistance, ignore, hit))
		{
			hitID = 0;
			hitDistance = maxDistance;
			return false;
		}

		hitID = hit.blob !is null ? hit.blob.getNetworkID() : 0;
		hitDistance = hit.distance;
		return true;
	}

	shared bool RaycastBlocks(Vec3f origin, Vec3f direction, const f32 maxDistance, CBlob@ ignore, f32 &out hitDistance)
	{
		u16 hitID;
		return RaycastBlockTarget(origin, direction, maxDistance, ignore, hitID, hitDistance);
	}

	shared bool GetBuildPlaneHit(CBlob@ builder, RaycastHit3D &out planeHit, bool &out blockedByBlock)
	{
		blockedByBlock = false;
		planeHit.Clear();

		Ray3D ray;
		if (!GetLocalCameraRay(builder, ray))
		{
			return false;
		}

		if (!RaycastYPlane(ray, GetBuildPlaneY(builder), BUILD_RAY_DISTANCE, planeHit))
		{
			return false;
		}

		RaycastHit3D blockHit;
		const f32 blockMaxDistance = Maths::Max(0.0f, planeHit.distance - 0.05f);
		blockedByBlock = RaycastBlockTarget(ray, BLOCK_RAY_START_EPSILON, blockMaxDistance, builder, blockHit);
		return true;
	}

	shared bool HitsBlob(CBlob@ caller, CBlob@ target, const f32 maxRayDistance)
	{
		if (caller is null || target is null)
		{
			return false;
		}

		if ((target.getPosition() - caller.getPosition()).Length() > INTERACT_PLAYER_DISTANCE)
		{
			return false;
		}

		Ray3D ray;
		if (!GetLocalCameraRay(caller, ray))
		{
			return false;
		}

		Blob3D@ blob3d;
		if (!target.get("blob3d", @blob3d) || blob3d is null || blob3d.shape is null)
		{
			return false;
		}
		UpdateBlobRaycastTransform(target, blob3d);

		RaycastHit3D hit;
		BoundingBox@ box = cast<BoundingBox@>(blob3d.shape);
		if (box !is null)
		{
			return RaycastBoundingBox(ray, box, maxRayDistance, hit);
		}

		BoundingSphere@ sphere = cast<BoundingSphere@>(blob3d.shape);
		if (sphere !is null)
		{
			return RaycastBoundingSphere(ray, sphere, maxRayDistance, hit);
		}

		BoundingCapsule@ capsule = cast<BoundingCapsule@>(blob3d.shape);
		return capsule !is null && RaycastBoundingCapsule(ray, capsule, maxRayDistance, hit);
	}

	shared bool GetInteractTarget(CBlob@ caller, u16 &out targetID, string &out promptLabel)
	{
		targetID = 0;
		promptLabel = "";

		if (caller is null)
		{
			return false;
		}

		Ray3D ray;
		if (!GetPlayerAimRay(caller, ray))
		{
			return false;
		}

		RaycastHit3D hit;
		if (!RaycastBlockTarget(ray, BLOCK_RAY_START_EPSILON, INTERACT_RAY_DISTANCE, caller, hit) || hit.blob is null)
		{
			return false;
		}

		CBlob@ block = hit.blob;
		if ((block.getPosition() - caller.getPosition()).Length() > INTERACT_PLAYER_DISTANCE || !CanRayInteract(caller, block))
		{
			return false;
		}

		targetID = block.getNetworkID();
		promptLabel = GetInteractLabel(block);
		return true;
	}

	shared bool GetSeatTarget(CBlob@ caller, u16 &out seatID, string &out seatLabel)
	{
		return GetInteractTarget(caller, seatID, seatLabel);
	}

	shared bool GetPlayerAimRay(CBlob@ builder, Ray3D &out ray)
	{
		if (GetLocalCameraRay(builder, ray))
		{
			return true;
		}

		return GetPlayerBodyAimRay(builder, ray);
	}

	shared bool GetPlayerAimRay(CBlob@ builder, Vec3f &out origin, Vec3f &out direction)
	{
		Ray3D ray;
		if (!GetPlayerAimRay(builder, ray))
		{
			return false;
		}

		origin = ray.origin;
		direction = ray.direction;
		return true;
	}

	shared bool GetPlayerBodyAimRay(CBlob@ builder, Ray3D &out ray)
	{
		if (builder is null)
		{
			return false;
		}

		Blob3D@ blob3d;
		if (!builder.get("blob3d", @blob3d) || blob3d is null)
		{
			return false;
		}

		Vec2f forward = Vec2f(1.0f, 0.0f).RotateBy(blob3d.transform.Orientation.x + 90.0f);
		f32 pitchRadians = blob3d.transform.Orientation.y * Maths::Pi / 180.0f;
		Vec3f direction = Vec3f(
			forward.x * Maths::Cos(pitchRadians),
			-Maths::Sin(pitchRadians),
			forward.y * Maths::Cos(pitchRadians)
		);

		if (direction.LengthSquared() <= EPSILON)
		{
			return false;
		}

		ray = Ray3D(V2toV3(builder.getPosition(), 16.0f), direction);
		return true;
	}

	shared bool GetPlayerBodyAimRay(CBlob@ builder, Vec3f &out origin, Vec3f &out direction)
	{
		Ray3D ray;
		if (!GetPlayerBodyAimRay(builder, ray))
		{
			return false;
		}

		origin = ray.origin;
		direction = ray.direction;
		return true;
	}

	shared bool GetBuildPlaneAim(CBlob@ builder, Vec2f &out aimPos, bool &out blockedByBlock)
	{
		RaycastHit3D hit;
		if (!GetBuildPlaneHit(builder, hit, blockedByBlock))
		{
			return false;
		}

		aimPos = hit.point.xz();
		return true;
	}

	shared bool GetCameraGridPlaneAim(CBlob@ builder, Vec2f &out aimPos)
	{
		RaycastHit3D hit;
		bool blockedByBlock;
		if (!GetBuildPlaneHit(builder, hit, blockedByBlock))
		{
			return false;
		}

		aimPos = hit.point.xz();
		return true;
	}

	shared bool CanRayInteract(CBlob@ caller, CBlob@ target)
	{
		if (caller is null || target is null
			|| target.getShape().getVars().customData <= 0
			|| target.hasAttached())
		{
			return false;
		}

		if (target.hasTag("flak"))
		{
			return target.getTeamNum() == caller.getTeamNum();
		}

		if (target.hasTag("harpoon"))
		{
			return target.getTeamNum() == caller.getTeamNum();
		}

		if (target.exists("seatEnabled"))
		{
			return false;
		}

		const uint blockType = target.getSprite().getFrame();
		return target.hasTag("control") || blockType == 2;
	}

	shared string GetInteractLabel(CBlob@ target)
	{
		if (target is null)
		{
			return "";
		}

		if (target.hasTag("flak"))
		{
			return "Control Flak";
		}

		if (target.hasTag("harpoon"))
		{
			return "Control Harpoon";
		}

		string label = target.get_string("seat label");
		if (label != "")
		{
			return "enter " + label;
		}

		return "enter seat";
	}

	shared bool IsRaycastBlockCandidate(CBlob@ block, CBlob@ ignore)
	{
		if (block is null || block is ignore || block.isAttached() || block.hasTag("disabled"))
		{
			return false;
		}

		return block.getShape().getVars().customData >= 0;
	}

	shared bool Slab(const f32 origin, const f32 direction, const f32 min, const f32 max, Vec3f axis, const f32 tMinIn, const f32 tMaxIn, Vec3f normalIn, f32 &out tMinOut, f32 &out tMaxOut, Vec3f &out normalOut)
	{
		f32 tMin = tMinIn;
		f32 tMax = tMaxIn;
		Vec3f normal = normalIn;

		if (Maths::Abs(direction) < EPSILON)
		{
			tMinOut = tMin;
			tMaxOut = tMax;
			normalOut = normal;
			return origin >= min && origin <= max;
		}

		f32 t1 = (min - origin) / direction;
		f32 t2 = (max - origin) / direction;
		Vec3f n = -axis;
		if (t1 > t2)
		{
			f32 temp = t1;
			t1 = t2;
			t2 = temp;
			n = axis;
		}

		if (t1 > tMin)
		{
			tMin = t1;
			normal = n;
		}
		tMax = Maths::Min(tMax, t2);
		tMinOut = tMin;
		tMaxOut = tMax;
		normalOut = normal;
		return tMin <= tMax;
	}
}
