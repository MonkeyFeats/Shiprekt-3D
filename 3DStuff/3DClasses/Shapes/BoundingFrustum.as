#include "TypeEnums.as"
#include "Plane.as";
#include "Shapes3D.as";

shared class BoundingFrustum : BoundingShape
{
    MatrixR matrix();
    Plane bottom;
    Plane far;
    Plane left;
    Plane right;
    Plane near;
    Plane top;
    Vec3f@[] corners;

    int CornerCount = 8;

    BoundingFrustum(MatrixR value)
    {
        this.matrix = value;
        CreatePlanes();
        CreateCorners();
    }

    Plane Bottom
    {
        get { return this.bottom; }
    }

    Plane Far
    {
        get { return this.far; }
    }

    Plane Left
    {
        get { return this.left; }
    }

    MatrixR MatrixR
    {
        get { return this.matrix; }
        set
        {
            this.matrix = value;
            this.CreatePlanes();    // FIXME: The odds are the planes will be used a lot more often than the matrix
        	this.CreateCorners();   // is updated, so this should help performance. I hope ;)
		}
    }

    Plane Near
    {
        get { return this.near; }
    }

    Plane Right
    {
        get { return this.right; }
    }

    Plane Top
    {
        get { return this.top; }
    }

    bool opEquals(BoundingFrustum b)
    {
        //if (object.Equals(a, null))
        //    return (object.Equals(b, null));
        //if (object.Equals(b, null))
        //    return (object.Equals(a, null)); weird

        return this.matrix is b.matrix;
    }

    bool opNotEquals(BoundingFrustum b)
    {
        return (this !is b);
    }

    ContainmentType Contains(BoundingBox box)
    {
        ContainmentType result;
        this.Contains(box, result);
        return result;
    }

    void Contains(BoundingBox box, ContainmentType &out result)
    {
        bool intersects = false;

        PlaneIntersectionType type;
        box.Intersects(near, type);
        if ( type == PlaneIntersectionType::Front )
        {
            result = ContainmentType::None;
            return;
        }
        if ( type == PlaneIntersectionType::Intersecting )
            intersects = true;

        box.Intersects(left, type);
        if ( type == PlaneIntersectionType::Front )
        {
            result = ContainmentType::None;
            return;
        }
        if ( type == PlaneIntersectionType::Intersecting )
            intersects = true;

        box.Intersects(right, type);
        if ( type == PlaneIntersectionType::Front )
        {
            result = ContainmentType::None;
            return;
        }
        if ( type == PlaneIntersectionType::Intersecting )
            intersects = true;

        box.Intersects(top, type);
        if (type == PlaneIntersectionType::Front)
        {
            result = ContainmentType::None;
            return;
        }
        if (type == PlaneIntersectionType::Intersecting)
            intersects = true;

        box.Intersects(bottom, type);
        if (type == PlaneIntersectionType::Front)
        {
            result = ContainmentType::None;
            return;
        }
        if (type == PlaneIntersectionType::Intersecting)
            intersects = true;

        box.Intersects(far, type);
        if (type == PlaneIntersectionType::Front)
        {
            result = ContainmentType::None;
            return;
        }
        if (type == PlaneIntersectionType::Intersecting)
            intersects = true;

        result = intersects ? ContainmentType::Intersects : ContainmentType::Contains;
    }

    // TODO: Implement this
    ContainmentType Contains(BoundingFrustum frustum)
    {
        if (this == frustum)                // We check to see if the two frustums are equal
            return ContainmentType::Contains;// If they are, there's no need to go any further.
        //throw NotImplementedException();
        return ContainmentType::None;
    }

    ContainmentType Contains(BoundingSphere sphere)
    {
        ContainmentType result;
        this.Contains(sphere, result);
        return result;
    }

    void Contains(BoundingSphere sphere, ContainmentType &out result)
    {
        double dist = Dot(bottom.Normal, sphere.transform.Position);
		result = ContainmentType::Contains;
		
		dist += bottom.D;
		if (dist > sphere.Radius)
		{
			result = ContainmentType::None;
			return;
		}
		if (Maths::Abs(dist) < sphere.Radius)
			result = ContainmentType::Intersects;
		
        dist = Dot(top.Normal, sphere.transform.Position);
		dist += top.D;
		if (dist > sphere.Radius)
		{
			result = ContainmentType::None;
			return;
		}
		if (Maths::Abs(dist) < sphere.Radius)
			result = ContainmentType::Intersects;
		
        dist = Dot(near.Normal, sphere.transform.Position);
		dist += near.D;
		if (dist > sphere.Radius)
		{
			result = ContainmentType::None;
			return;
		}
		if (Maths::Abs(dist) < sphere.Radius)
			result = ContainmentType::Intersects;
		
        dist = Dot(far.Normal, sphere.transform.Position);
		dist += far.D;
		if (dist > sphere.Radius)
		{
			result = ContainmentType::None;
			return;
		}
		if (Maths::Abs(dist) < sphere.Radius)
			result = ContainmentType::Intersects;
		
        dist = Dot(left.Normal, sphere.transform.Position);
		dist += left.D;
		if (dist > sphere.Radius)
		{
			result = ContainmentType::None;
			return;
		}
		if (Maths::Abs(dist) < sphere.Radius)
			result = ContainmentType::Intersects;

        dist = Dot(right.Normal, sphere.transform.Position);
		dist += right.D;
		if (dist > sphere.Radius)
		{
			result = ContainmentType::None;
			return;
		}
		if (Maths::Abs(dist) < sphere.Radius)
			result = ContainmentType::Intersects;
    }

    ContainmentType Contains(Vec3f point)
    {
        ContainmentType result;
        this.Contains(point, result);
        return result;
    }

    void Contains(Vec3f point, ContainmentType &out result)
    {
        double val;
        // If a point is on the POSITIVE side of the plane, then the point is not contained within the frustum

        // Check the top
        val = PlaneHelper::ClassifyPoint(point, this.top);
        if (val > 0)
        {
            result = ContainmentType::None;
            return;
        }

        // Check the bottom
        val = PlaneHelper::ClassifyPoint(point, this.bottom);
        if (val > 0)
        {
            result = ContainmentType::None;
            return;
        }

        // Check the left
        val = PlaneHelper::ClassifyPoint(point, this.left);
        if (val > 0)
        {
            result = ContainmentType::None;
            return;
        }

        // Check the right
        val = PlaneHelper::ClassifyPoint(point, this.right);
        if (val > 0)
        {
            result = ContainmentType::None;
            return;
        }

        // Check the near
        val = PlaneHelper::ClassifyPoint(point, this.near);
        if (val > 0)
        {
            result = ContainmentType::None;
            return;
        }

        // Check the far
        val = PlaneHelper::ClassifyPoint(point, this.far);
        if (val > 0)
        {
            result = ContainmentType::None;
            return;
        }

        // If we get here, it means that the point was on the correct side of each plane to be
        // contained. Therefore this point is contained
        result = ContainmentType::Contains;
    }

    bool Equals(BoundingFrustum other)
    {
        return (this == other);
    }

    Vec3f@[] GetCorners()
    {
        return this.corners; //this.corners.Clone();
    }
	
	//void GetCorners(Vec3f[] corners)
    //{
    //    corners = this.corners;//this.corners.CopyTo(corners, 0);
    //}

    //int GetHashCode()
    //{
    //    return this.matrix.GetHashCode();
    //}

    bool Intersects(BoundingBox box)
    {
		bool result = false;
		this.Intersects(box, result);
		return result;
    }

    void Intersects(BoundingBox box, bool &out result)
    {
		ContainmentType containment = ContainmentType::None;
		this.Contains(box, containment);
		result = containment != ContainmentType::None;
	}

    bool Intersects(BoundingFrustum frustum)
    {
        //throw NotImplementedException();
        return false;
    }

    bool Intersects(BoundingSphere sphere)
    {
        //throw NotImplementedException();
        return false;
    }

    void Intersects(BoundingSphere sphere, bool &out result)
    {
        //throw NotImplementedException();
        result = false;
    }

    PlaneIntersectionType Intersects(Plane plane)
    {
        //throw NotImplementedException();
        return PlaneIntersectionType::None;
    }

    void Intersects(Plane plane, PlaneIntersectionType &out result)
    {
        //throw NotImplementedException();
        result = PlaneIntersectionType::None;
    }

    bool Intersects(Ray ray)
    {
        //throw NotImplementedException();
        return false;
    }

    void Intersects(Ray ray, bool &out result)
    {
        //throw NotImplementedException();
        result = false;
    }

    //string ToString()
    //{
    //    StringBuilder sb = StringBuilder(256);
    //    sb.Append("{Near:");
    //    sb.Append(this.near.ToString());
    //    sb.Append(" Far:");
    //    sb.Append(this.far.ToString());
    //    sb.Append(" Left:");
    //    sb.Append(this.left.ToString());
    //    sb.Append(" Right:");
    //    sb.Append(this.right.ToString());
    //    sb.Append(" Top:");
    //    sb.Append(this.top.ToString());
    //    sb.Append(" Bottom:");
    //    sb.Append(this.bottom.ToString());
    //    sb.Append("}");
    //    return sb.ToString();
    //}

    private void CreateCorners()
    {
        this.corners.set_length(8);
        this.corners[0] = IntersectionPoint(this.near, this.left, this.top);
        this.corners[1] = IntersectionPoint(this.near, this.right, this.top);
        this.corners[2] = IntersectionPoint(this.near, this.right, this.bottom);
        this.corners[3] = IntersectionPoint(this.near, this.left, this.bottom);
        this.corners[4] = IntersectionPoint(this.far, this.left, this.top);
        this.corners[5] = IntersectionPoint(this.far, this.right, this.top);
        this.corners[6] = IntersectionPoint(this.far, this.right, this.bottom);
        this.corners[7] = IntersectionPoint(this.far, this.left, this.bottom);
    }
    
    private void CreatePlanes()
    {
        // Pre-calculate the different planes needed
        this.left = Plane(-this.matrix.Array[3] - this.matrix.Array[0], -this.matrix.Array[7] - this.matrix.Array[4],
                              -this.matrix.Array[11] - this.matrix.Array[8], -this.matrix.Array[15] - this.matrix.Array[12]);

        this.right = Plane(this.matrix.Array[0] - this.matrix.Array[3], this.matrix.Array[4] - this.matrix.Array[7],
                               this.matrix.Array[8] - this.matrix.Array[11], this.matrix.Array[12] - this.matrix.Array[15]);

        this.top = Plane(this.matrix.Array[1] - this.matrix.Array[3], this.matrix.Array[5] - this.matrix.Array[7],
                             this.matrix.Array[9] - this.matrix.Array[11], this.matrix.Array[13] - this.matrix.Array[15]);

        this.bottom = Plane(-this.matrix.Array[3] - this.matrix.Array[1], -this.matrix.Array[7] - this.matrix.Array[5],
                                -this.matrix.Array[11] - this.matrix.Array[9], -this.matrix.Array[15] - this.matrix.Array[13]);

        this.near = Plane(-this.matrix.Array[2], -this.matrix.Array[6], -this.matrix.Array[10], -this.matrix.Array[14]);


        this.far = Plane(this.matrix.Array[2] - this.matrix.Array[3], this.matrix.Array[6] - this.matrix.Array[7],
                             this.matrix.Array[10] - this.matrix.Array[11], this.matrix.Array[14] - this.matrix.Array[15]);

        this.NormalizePlane(this.left);
        this.NormalizePlane(this.right);
        this.NormalizePlane(this.top);
        this.NormalizePlane(this.bottom);
        this.NormalizePlane(this.near);
        this.NormalizePlane(this.far);
    }

    private Vec3f IntersectionPoint(Plane a, Plane b, Plane c)
    {
        // Formula used
        //                d1 ( N2 * N3 ) + d2 ( N3 * N1 ) + d3 ( N1 * N2 )
        // P = 	-------------------------------------------------------------------------
        //                             N1 . ( N2 * N3 )
        //
        // Note: N refers to the normal, d refers to the displacement. '.' means dot product. '*' means cross product

        Vec3f v1, v2, v3;
        double f = -Dot(a.Normal, Cross(b.Normal, c.Normal));

        v1 = Cross(b.Normal, c.Normal)*a.D;
        v2 = Cross(c.Normal, a.Normal)*b.D;
        v3 = Cross(a.Normal, b.Normal)*c.D;

        Vec3f vec = Vec3f(v1.x + v2.x + v3.x, v1.y + v2.y + v3.y, v1.z + v2.z + v3.z);
        return vec / f;
    }
    
    private void NormalizePlane(Plane p)
    {
        double factor = 1.0f / p.Normal.Length();
        p.Normal.x *= factor;
        p.Normal.y *= factor;
        p.Normal.z *= factor;
        p.D *= factor;
    }
}