
#include "Vec3f.as"
#include "TypeEnums.as"
#include "BoundingBox.as"
#include "BoundingFrustum.as"
#include "Matrix.as"
#include "Plane.as"
#include "Ray.as"
#include "Shapes3D.as"

#include "ShapeArrays.as"

shared class BoundingSphere : BoundingShape
{
    double Radius;

    SMesh@ SphereMesh = SMesh();
    SMaterial@ SphereMat = SMaterial();
    BoundingShape@ hitsphere;

    BoundingSphere(){}

    BoundingSphere(double _radius)
    {
        this.Radius = _radius;
        UpdateAttributes(SColor(150, 0, 255, 0));

        @hitsphere = BoundingSphere(this.transform.Position, 1.0);
    }

    BoundingSphere(Vec3f _Position, double _radius)
    {
        super(_Position);
        this.Radius = _radius;
        UpdateAttributes(SColor(150, 0, 255, 0));
    }

    void UpdateAttributes(SColor col) override
    {
        Vertex[] _Verts = Sphere_Vertices();

        for(uint i = 0; i < _Verts.size(); i++)
        {
            Vertex sv = _Verts[i];
            _Verts[i] = Vertex( (sv.x*Radius), (sv.y*Radius), (sv.z*Radius), sv.u, sv.v, col);
        }

        u16[] ids = Sphere_IDs();

        SphereMesh.SetVertex(_Verts);
        SphereMesh.SetIndices(ids); 
        SphereMesh.BuildMesh();
        SphereMesh.SetDirty(SMesh::VERTEX_INDEX);

        SphereMat.DisableAllFlags();
        SphereMat.SetFlag(SMaterial::COLOR_MASK, true);
        SphereMat.SetFlag(SMaterial::ZBUFFER, true);
        SphereMat.SetFlag(SMaterial::ZWRITE_ENABLE, false);
        SphereMat.SetFlag(SMaterial::BACK_FACE_CULLING, false);
        SphereMat.SetMaterialType(SMaterial::TRANSPARENT_VERTEX_ALPHA );
        SphereMat.SetFlag(SMaterial::WIREFRAME, true);
        //SphereMat.SetFlag(SMaterial::LIGHTING, true);
        //SphereMat.SetEmissiveColor(SColor(255,255,0,180));
        SphereMesh.SetMaterial(SphereMat);
    }

    void Render() override
    { 
        model.SetTranslation(this.getPosition());
        model.setRotationDegrees(-this.transform.Orientation.x,0,0);
       //Matrix::SetRotationDegrees(model.Array, 0 , this.Angle.x , 0);

        Render::SetModelTransform(model.Array);
        SphereMesh.RenderMeshWithMaterial();  

        if (hitsphere !is null)
        hitsphere.Render(); 
    }


    BoundingSphere Transform(MatrixR matrix)
    {
        BoundingSphere sphere();
        sphere.setPosition(this.getPosition());
        sphere.Radius = this.Radius * double(Maths::Sqrt(double(Maths::Max(((matrix.Array[0] * matrix.Array[0]) + (matrix.Array[1] * matrix.Array[1])) + (matrix.Array[2] * matrix.Array[2]), Maths::Max(((matrix.Array[4] * matrix.Array[4]) + (matrix.Array[5] * matrix.Array[5])) + (matrix.Array[6] * matrix.Array[6]), ((matrix.Array[8] * matrix.Array[8]) + (matrix.Array[9] * matrix.Array[9])) + (matrix.Array[10] * matrix.Array[10]))))));
        return sphere;
    }

    void Transform(MatrixR matrix, BoundingSphere &out result)
    {
        result.setPosition(this.getPosition());
        result.Radius = this.Radius * double(Maths::Sqrt(double(Maths::Max(((matrix.Array[0] * matrix.Array[0]) + (matrix.Array[1] * matrix.Array[1])) + (matrix.Array[2] * matrix.Array[2]), Maths::Max(((matrix.Array[4] * matrix.Array[4]) + (matrix.Array[5] * matrix.Array[5])) + (matrix.Array[6] * matrix.Array[6]), ((matrix.Array[8] * matrix.Array[8]) + (matrix.Array[9] * matrix.Array[9])) + (matrix.Array[10] * matrix.Array[10]))))));
    }

//    ContainmentType Contains(BoundingBox@ box, Vec3f Vel, Vec3f &out MTV) override
//    {
//        Vec3f omin = (box.Position+box.Min);
//        Vec3f omax = (box.Position+box.Max);
//
//        //check if all corner is in sphere
//        bool inside = true;
//        Vec3f@[] corners = box.GetCorners();
//
//        //for(int i = 0; i < corners.length(); i++)
//        //{
//        //    Vec3f corner = corners[i];
//        //    if (this.Contains(corner) == ContainmentType::None)
//        //    {
//        //        inside = false;
//        //        break;
//        //    }
//        //}
//
//        //if (inside)
//        //    return ContainmentType::Contains;
//
//        //check if the distance from sphere Position to cube face < radius
//        double dmin = 0;          
//
//        if (Position.x < omin.x)
//        {
//			dmin += (Position.x - omin.x)*(Position.x - omin.x);
//        }
//		else if (Position.x > omax.x)
//        {
//			dmin += (Position.x - omax.x)*(Position.x - omax.x);
//        }
//
//		if (Position.y < omin.y)
//        {
//			dmin += (Position.y - omin.y)*(Position.y - omin.y);
//        }
//		else if (Position.y > omax.y)
//        {
//			dmin += (Position.y - omax.y)*(Position.y - omax.y);
//        }
//
//		if (Position.z < omin.z)
//        {
//			dmin += (Position.z - omin.z)*(Position.z - omin.z);
//        }
//		else if (Position.z > omax.z)
//        {
//			dmin += (Position.z - omax.z)*(Position.z - omax.z);
//        }
//
//		if (dmin <= (Radius*Radius))
//        {
//            double overlap = ((Radius*Radius)-(dmin));
//            print("overlap "+overlap);
//            Vec3f mtvAxis = (Position-box.Position).Normalize(); 
//            //mtvAxis.Normalize();
//            mtvAxis.Print();
//            MTV = mtvAxis*overlap;
//
//            return ContainmentType::Intersects;
//        }
//        
//        //else null
//        return ContainmentType::None;
//
//    }

       //Vec3f localPosition = box.transform.TransformByInverse(this.getPosition());
       //Vec3f localClosestPoint = localPosition.Clamp(box.Min, box.Max); // ContactPosition
       //Vec3f ContactPosition = box.transform.Transform(localClosestPoint);
       //hitsphere.transform.Position = ContactPosition;
       //Vec3f offset = this.getPosition() - ContactPosition;

    ContainmentType Contains(BoundingBox@ box, Vec3f Vel, Vec3f &out MTV) override
    {
        //Vec3f localPosition = box.transform.TransformByInverse(this.getPosition());
        Vec3f localPosition = this.getPosition() - box.getPosition();
        //un-rotate 
        localPosition.rotateXZBy( -box.transform.Orientation.x);    
        Vec3f localClosestPoint = localPosition.Clamp(box.Min, box.Max); 
        //re-rotate    
        localClosestPoint.rotateXZBy( box.transform.Orientation.x);

        Vec3f ContactPosition = box.getPosition()+(localClosestPoint);

        hitsphere.transform.Position = ContactPosition;

        Vec3f offset = this.getPosition() - ContactPosition;
        float offsetLength = offset.LengthSquared();

        if (offsetLength > (Radius*Radius))
        {
            return ContainmentType::None;
        }

        //intersecting the box.
        if (offsetLength > MathsHelper::Epsilon)
        {            
            offsetLength = float(Maths::Sqrt(offsetLength));

            Vec3f Normal = offset/offsetLength;
            double depth = Radius - offsetLength;
            Normal.Normalize();
            MTV = Normal*depth;
            return ContainmentType::Intersects;
        }
        // else //Inside of the box.
        //{
            
            Vec3f Normal;
            double depth;
            Vec3f penetrationDepths;
            penetrationDepths.x = localClosestPoint.x < 0 ? localClosestPoint.x + box.Min.x : box.Max.x - localClosestPoint.x;
            penetrationDepths.y = localClosestPoint.y < 0 ? localClosestPoint.y + box.Min.y : box.Max.y - localClosestPoint.y;
            penetrationDepths.z = localClosestPoint.z < 0 ? localClosestPoint.z + box.Min.z : box.Max.z - localClosestPoint.z;
            if (penetrationDepths.x < penetrationDepths.y && penetrationDepths.x < penetrationDepths.z)
            {
                Normal = localClosestPoint.x > 0 ? Vec3f(1,0,0) : Vec3f(-1,0,0); 
                depth = penetrationDepths.x;
            }
            else if (penetrationDepths.y < penetrationDepths.z)
            {
                Normal = localClosestPoint.y > 0 ? Vec3f(0,1,0) : Vec3f(0,-1,0); 
                depth = penetrationDepths.y;
            }
            else
            {
                Normal = localClosestPoint.z > 0 ? Vec3f(0,0,-1) : Vec3f(0,0,1); 
                depth = penetrationDepths.x;
            }
            Normal = box.transform.Orientation.Transform(Normal);
            depth += Radius;
            MTV = Normal*depth;
            return ContainmentType::Contains;
        //}
        //return ContainmentType::None;
    }

//void sphereCollisionResponse(Sphere *a, Sphere *b)
//{
//    Vector3 U1x,U1y,U2x,U2y,V1x,V1y,V2x,V2y;
//
//
//    float m1, m2, x1, x2;
//    Vector3 v1temp, v1, v2, v1x, v2x, v1y, v2y, x(a->pos - b->pos);
//
//    x.normalize();
//    v1 = a->vel;
//    x1 = x.dot(v1);
//    v1x = x * x1;
//    v1y = v1 - v1x;
//    m1 = a->mass;
//
//    x = x*-1;
//    v2 = b->vel;
//    x2 = x.dot(v2);
//    v2x = x * x2;
//    v2y = v2 - v2x;
//    m2 = b->mass;
//
//    a->vel = Vector3( v1x*(m1-m2)/(m1+m2) + v2x*(2*m2)/(m1+m2) + v1y );
//    b->vel = Vector3( v1x*(2*m1)/(m1+m2) + v2x*(m2-m1)/(m1+m2) + v2y );
//}
//
    ContainmentType Contains(BoundingFrustum frustum)
    {
        //check if all corner is in sphere
        bool inside = true;

        Vec3f@[] corners = frustum.corners;

        for(int i = 0; i < corners.length(); i++)
        {
            Vec3f corner = corners[i];
            if (this.Contains(corner) == ContainmentType::None)
            {
                inside = false;
                break;
            }
        }
        if (inside)
            return ContainmentType::Contains;

        //check if the distance from sphere Position to frustrum face < radius
        double dmin = 0;
        //TODO : calcul dmin

        if (dmin <= Radius * Radius)
            return ContainmentType::Intersects;

        //else null
        return ContainmentType::None;
    }

    ContainmentType Contains(BoundingSphere sphere)
    {
        double val = (sphere.getPosition()-getPosition()).Length();

        if (val > sphere.Radius + Radius)
            return ContainmentType::None;

        else if (val <= Radius - sphere.Radius)
            return ContainmentType::Contains;

        else
            return ContainmentType::Intersects;
    }

    void Contains(BoundingSphere@ sphere, int &out result)
    {
        result = Contains(sphere);
    }

    ContainmentType Contains(Vec3f point)
    {
        double distance = (point-getPosition()).Length();

        if (distance > this.Radius)
            return ContainmentType::None;

        else if (distance < this.Radius)
            return ContainmentType::Contains;

        return ContainmentType::Intersects;
    }

    void Contains(Vec3f point, ContainmentType &out result)
    {
        result = Contains(point);
    }    

    //int GetHashCode()
    //{
    //    return this.Position.GetHashCode() + this.Radius.GetHashCode();
    //}

    bool Intersects(BoundingBox box)
    {
		return box.Intersects(this);
    }

    //bool Intersects(BoundingFrustum frustum)
    //{
    //    if (frustum is null)
    //        throw NullReferenceException();
    //    throw NotImplementedException();
    //}

    //bool Intersects(BoundingSphere sphere)
    //{
    //    double val = (sphere.Position-Position).Length();
	//	if (val > sphere.Radius + Radius)
	//		return false;
	//	return true;
    //}

    //bool Intersects(BoundingSphere sphere)
    //{
	//	return Intersects(sphere);
    //}

    PlaneIntersectionType Intersects(Plane plane)
    {
		double distance = plane.Normal.Dot(this.getPosition()) + plane.D;
		if (distance > this.Radius)
			return PlaneIntersectionType::Front;
		if (distance < -this.Radius)
			return PlaneIntersectionType::Back;
		//else it intersect
		return PlaneIntersectionType::Intersecting;
    }

    void Intersects(Plane plane, PlaneIntersectionType &out result)
    { result = Intersects(plane); }

    bool Intersects(Ray ray)
    { return ray.Intersects(this); }

    void Intersects(Ray ray, bool &out result)
    { result = this.Intersects(ray); }

    bool Equals(BoundingSphere other)
    { return this.getPosition() == other.getPosition() && this.Radius == other.Radius; }
    
    bool opEquals(BoundingSphere a, BoundingSphere b)
    { return a.Equals(b); }

    bool opNotEquals(BoundingSphere a, BoundingSphere b)
    { return !a.Equals(b); }

}

BoundingSphere CreateFromBoundingBox(BoundingBox@ box)
{
    // Find the Position of the box.
    Vec3f Position = Vec3f((box.Min.x + box.Max.x) / 2.0f,
                           (box.Min.y + box.Max.y) / 2.0f,
                           (box.Min.z + box.Max.z) / 2.0f);

    // Find the distance between the Position and one of the corners of the box.
    double radius = (Position-box.Max).Length();
    return BoundingSphere(Position, radius);
}

//BoundingSphere CreateFromFrustum(BoundingFrustum@ frustum)
//{
//    return CreateFromPoints(frustum.GetCorners());
//}

BoundingSphere CreateFromPoints(Vec3f[] points)
{
    if (points.size() < 8)
    {
        warn("CreateFromPoints, needs more points");
    }

    double radius = 0;
    Vec3f Position = Vec3f();
    // First, we'll find the Position of gravity for the point 'cloud'.
    int num_points = points.size(); // The number of points (there MUST be a better way to get this instead of counting the number of points one by one?)
    
    for (int i = 0; i < num_points; ++i)
    {
        Vec3f v = points[i];
        Position += v;    // If we actually kthe number of points, we'd get better accuracy by adding v / num_points.
    }
    
    Position /= num_points;

    // Calculate the radius of the needed sphere (it equals the distance between the Position and the point further away).
    for (int i = 0; i < num_points; ++i)
    {
        Vec3f v  = points[i];
        double distance = (v - Position).Length();
        
        if (distance > radius)
            radius = distance;
    }

    return BoundingSphere(Position, radius);
}

BoundingSphere CreateMerged(BoundingSphere original, BoundingSphere additional)
{
    Vec3f oPositionToaPosition = (additional.getPosition() - original.getPosition());
    double distance = oPositionToaPosition.Length();
    if (distance <= original.Radius + additional.Radius)//intersect
    {
        if (distance <= original.Radius - additional.Radius)//original contain additional
            return original;
        if (distance <= additional.Radius - original.Radius)//additional contain original
            return additional;
    }

    //else find Position of sphere and radius
    double leftRadius = Maths::Max(original.Radius - distance, additional.Radius);
    double Rightradius = Maths::Max(original.Radius + distance, additional.Radius);
    oPositionToaPosition += (oPositionToaPosition * (2 * distance)) / (leftRadius - Rightradius);//oPositionToResultPosition
    
    BoundingSphere result = BoundingSphere();
    result.transform.Position = original.getPosition() + oPositionToaPosition;
    result.Radius = (leftRadius + Rightradius) / 2;
    return result;
}
