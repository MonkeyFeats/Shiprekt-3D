#include "TypeEnums.as"
#include "MathsHelper.as"
#include "Shapes3D.as"

shared class BoundingCapsule : BoundingShape
{
	f32 Radius;
	f32 Height;

	SMesh@ CapsuleMesh = SMesh();
	SMaterial@ CapsuleMat = SMaterial();

	BoundingCapsule() {}

	BoundingCapsule(f32 _radius, f32 _height)
	{
		Radius = _radius;
		Height = Maths::Max(_height, _radius * 2.0f);
		UpdateAttributes(SColor(150, 0, 255, 0));
	}

	BoundingCapsule(f32 _radius, f32 _height, Vec3f Pos)
	{
		Radius = _radius;
		Height = Maths::Max(_height, _radius * 2.0f);
		this.transform.Position = Pos;
		UpdateAttributes(SColor(150, 0, 255, 0));
	}

	f32 GetBottomY()
	{
		return Radius;
	}

	f32 GetTopY()
	{
		return Maths::Max(Radius, Height - Radius);
	}

	void GetWorldSegment(Vec3f basePosition, Vec3f &out bottom, Vec3f &out top)
	{
		bottom = basePosition + Vec3f(0.0f, GetBottomY(), 0.0f);
		top = basePosition + Vec3f(0.0f, GetTopY(), 0.0f);
	}

	Vec3f ClosestPointOnSegment(Vec3f point, Vec3f a, Vec3f b)
	{
		Vec3f ab = b - a;
		const f32 lenSq = ab.LengthSquared();
		if (lenSq <= 0.000001f)
		{
			return a;
		}

		const f32 t = Maths::Clamp((point - a).Dot(ab) / lenSq, 0.0f, 1.0f);
		return a + ab * t;
	}

	void UpdateAttributes(SColor col) override
	{
		Vertex[] verts;
		u16[] ids;
		f32[] ringYs;
		f32[] ringRadii;

		const uint segments = 16;
		const uint capSteps = 4;
		const f32 bottomY = GetBottomY();
		const f32 topY = GetTopY();

		for (uint i = 0; i <= capSteps; i++)
		{
			const f32 t = -Maths::Pi * 0.5f + (Maths::Pi * 0.5f) * (float(i) / float(capSteps));
			ringYs.push_back(bottomY + Maths::Sin(t) * Radius);
			ringRadii.push_back(Maths::Max(0.0f, Maths::Cos(t) * Radius));
		}

		if (topY > bottomY + 0.001f)
		{
			ringYs.push_back(topY);
			ringRadii.push_back(Radius);
		}

		for (uint i = 1; i <= capSteps; i++)
		{
			const f32 t = (Maths::Pi * 0.5f) * (float(i) / float(capSteps));
			ringYs.push_back(topY + Maths::Sin(t) * Radius);
			ringRadii.push_back(Maths::Max(0.0f, Maths::Cos(t) * Radius));
		}

		for (uint r = 0; r < ringYs.length(); r++)
		{
			for (uint s = 0; s < segments; s++)
			{
				const f32 theta = Maths::Pi * 2.0f * (float(s) / float(segments));
				verts.push_back(Vertex(Maths::Cos(theta) * ringRadii[r], ringYs[r], Maths::Sin(theta) * ringRadii[r], 0, 0, col));
			}
		}

		for (uint r = 0; r + 1 < ringYs.length(); r++)
		{
			for (uint s = 0; s < segments; s++)
			{
				const u16 a = u16(r * segments + s);
				const u16 b = u16(r * segments + ((s + 1) % segments));
				const u16 c = u16((r + 1) * segments + s);
				const u16 d = u16((r + 1) * segments + ((s + 1) % segments));
				ids.push_back(a); ids.push_back(c); ids.push_back(b);
				ids.push_back(b); ids.push_back(c); ids.push_back(d);
			}
		}

		CapsuleMesh.SetVertex(verts);
		CapsuleMesh.SetIndices(ids);
		CapsuleMesh.BuildMesh();
		CapsuleMesh.SetDirty(SMesh::VERTEX_INDEX);

		CapsuleMat.DisableAllFlags();
		CapsuleMat.SetFlag(SMaterial::COLOR_MASK, true);
		CapsuleMat.SetFlag(SMaterial::ZBUFFER, true);
		CapsuleMat.SetFlag(SMaterial::ZWRITE_ENABLE, false);
		CapsuleMat.SetFlag(SMaterial::BACK_FACE_CULLING, false);
		CapsuleMat.SetMaterialType(SMaterial::TRANSPARENT_VERTEX_ALPHA);
		CapsuleMat.SetFlag(SMaterial::WIREFRAME, true);
		CapsuleMesh.SetMaterial(CapsuleMat);
	}

	void Render() override
	{
		model.SetTranslation(this.getPosition());
		model.setRotationDegrees(-this.transform.Orientation.x, -this.transform.Orientation.y, -this.transform.Orientation.z);
		Render::SetModelTransform(model.Array);
		CapsuleMesh.RenderMeshWithMaterial();
	}

	ContainmentType Contains(BoundingBox@ box, Vec3f Vel, Vec3f &out MTV) override
	{
		return ContainsCapsuleBox(box, Vec3f(), Vel, MTV);
	}

	ContainmentType Contains(BoundingBox@ box, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) override
	{
		return ContainsCapsuleBox(box, Pos, Vel, MTV);
	}

	ContainmentType Contains(BoundingSphere@ sphere, Vec3f Vel, Vec3f &out MTV) override
	{
		return ContainsCapsuleSphere(sphere, Vec3f(), Vel, MTV);
	}

	ContainmentType Contains(BoundingSphere@ sphere, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) override
	{
		return ContainsCapsuleSphere(sphere, Pos, Vel, MTV);
	}

	ContainmentType Contains(BoundingCapsule@ capsule, Vec3f Vel, Vec3f &out MTV) override
	{
		return ContainsCapsuleCapsule(capsule, Vec3f(), Vel, MTV);
	}

	ContainmentType Contains(BoundingCapsule@ capsule, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) override
	{
		return ContainsCapsuleCapsule(capsule, Pos, Vel, MTV);
	}

	ContainmentType ContainsCapsuleBox(BoundingBox@ box, Vec3f Pos, Vec3f Vel, Vec3f &out MTV)
	{
		if (box is null)
		{
			return ContainmentType::None;
		}

		Vec3f bottom;
		Vec3f top;
		GetWorldSegment(transform.Position + Pos + Vel, bottom, top);

		Vec3f localBottom = bottom - box.transform.Position;
		Vec3f localTop = top - box.transform.Position;
		localBottom.rotateXZBy(-box.transform.Orientation.x);
		localTop.rotateXZBy(-box.transform.Orientation.x);

		const f32 segX = localBottom.x;
		const f32 segZ = localBottom.z;
		const f32 segMinY = Maths::Min(localBottom.y, localTop.y);
		const f32 segMaxY = Maths::Max(localBottom.y, localTop.y);
		const f32 segmentY = Maths::Clamp((box.Min.y + box.Max.y) * 0.5f, segMinY, segMaxY);

		Vec3f segmentPoint(segX, segmentY, segZ);
		Vec3f boxPoint(
			Maths::Clamp(segmentPoint.x, box.Min.x, box.Max.x),
			Maths::Clamp(segmentPoint.y, box.Min.y, box.Max.y),
			Maths::Clamp(segmentPoint.z, box.Min.z, box.Max.z)
		);

		Vec3f offset = segmentPoint - boxPoint;
		const f32 distSq = offset.LengthSquared();
		const f32 radiusSq = Radius * Radius;
		if (distSq > radiusSq)
		{
			return ContainmentType::None;
		}

		if (distSq > 0.000001f)
		{
			const f32 dist = Maths::Sqrt(distSq);
			Vec3f normal = offset / dist;
			normal.rotateXZBy(box.transform.Orientation.x);
			MTV = normal * (Radius - dist);
			return ContainmentType::Intersects;
		}

		Vec3f normalLocal(-1.0f, 0.0f, 0.0f);
		f32 best = (segX + Radius) - box.Min.x;

		const f32 right = box.Max.x - (segX - Radius);
		if (right < best)
		{
			best = right;
			normalLocal = Vec3f(1.0f, 0.0f, 0.0f);
		}

		const f32 back = (segZ + Radius) - box.Min.z;
		if (back < best)
		{
			best = back;
			normalLocal = Vec3f(0.0f, 0.0f, -1.0f);
		}

		const f32 front = box.Max.z - (segZ - Radius);
		if (front < best)
		{
			best = front;
			normalLocal = Vec3f(0.0f, 0.0f, 1.0f);
		}

		const f32 capsuleMinY = segMinY - Radius;
		const f32 capsuleMaxY = segMaxY + Radius;
		const f32 down = capsuleMaxY - box.Min.y;
		if (down < best)
		{
			best = down;
			normalLocal = Vec3f(0.0f, -1.0f, 0.0f);
		}

		const f32 up = box.Max.y - capsuleMinY;
		if (up < best)
		{
			best = up;
			normalLocal = Vec3f(0.0f, 1.0f, 0.0f);
		}

		if (best <= 0.000001f)
		{
			return ContainmentType::None;
		}

		normalLocal.rotateXZBy(box.transform.Orientation.x);
		MTV = normalLocal * best;
		return ContainmentType::Contains;
	}

	ContainmentType ContainsCapsuleSphere(BoundingSphere@ sphere, Vec3f Pos, Vec3f Vel, Vec3f &out MTV)
	{
		if (sphere is null)
		{
			return ContainmentType::None;
		}

		Vec3f bottom;
		Vec3f top;
		GetWorldSegment(transform.Position + Pos + Vel, bottom, top);

		Vec3f closest = ClosestPointOnSegment(sphere.getPosition(), bottom, top);
		Vec3f offset = closest - sphere.getPosition();
		const f32 radius = Radius + float(sphere.Radius);
		const f32 distSq = offset.LengthSquared();
		if (distSq > radius * radius)
		{
			return ContainmentType::None;
		}

		Vec3f normal;
		f32 dist = 0.0f;
		if (distSq > 0.000001f)
		{
			dist = Maths::Sqrt(distSq);
			normal = offset / dist;
		}
		else
		{
			normal = (transform.Position + Pos + Vel - sphere.getPosition()).Normalize();
			if (normal.LengthSquared() <= 0.000001f)
			{
				normal = Vec3f(1.0f, 0.0f, 0.0f);
			}
		}

		MTV = normal * (radius - dist);
		return ContainmentType::Intersects;
	}

	ContainmentType ContainsCapsuleCapsule(BoundingCapsule@ capsule, Vec3f Pos, Vec3f Vel, Vec3f &out MTV)
	{
		if (capsule is null)
		{
			return ContainmentType::None;
		}

		Vec3f aBottom;
		Vec3f aTop;
		Vec3f bBottom;
		Vec3f bTop;
		GetWorldSegment(transform.Position + Pos + Vel, aBottom, aTop);
		capsule.GetWorldSegment(capsule.transform.Position, bBottom, bTop);

		const f32 aMinY = Maths::Min(aBottom.y, aTop.y);
		const f32 aMaxY = Maths::Max(aBottom.y, aTop.y);
		const f32 bMinY = Maths::Min(bBottom.y, bTop.y);
		const f32 bMaxY = Maths::Max(bBottom.y, bTop.y);

		f32 aY;
		f32 bY;
		if (aMaxY < bMinY)
		{
			aY = aMaxY;
			bY = bMinY;
		}
		else if (bMaxY < aMinY)
		{
			aY = aMinY;
			bY = bMaxY;
		}
		else
		{
			const f32 y = (Maths::Max(aMinY, bMinY) + Maths::Min(aMaxY, bMaxY)) * 0.5f;
			aY = y;
			bY = y;
		}

		Vec3f aPoint(aBottom.x, aY, aBottom.z);
		Vec3f bPoint(bBottom.x, bY, bBottom.z);
		Vec3f offset = aPoint - bPoint;
		const f32 radius = Radius + capsule.Radius;
		const f32 distSq = offset.LengthSquared();
		if (distSq > radius * radius)
		{
			return ContainmentType::None;
		}

		Vec3f normal;
		f32 dist = 0.0f;
		if (distSq > 0.000001f)
		{
			dist = Maths::Sqrt(distSq);
			normal = offset / dist;
		}
		else
		{
			normal = (transform.Position + Pos + Vel - capsule.transform.Position).Normalize();
			if (normal.LengthSquared() <= 0.000001f)
			{
				normal = Vec3f(1.0f, 0.0f, 0.0f);
			}
		}

		MTV = normal * (radius - dist);
		return ContainmentType::Intersects;
	}
}
