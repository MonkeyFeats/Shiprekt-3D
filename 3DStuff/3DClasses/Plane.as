#include "TypeEnums.as";
#include "Vec3f.as";
#include "Vec4f.as";
#include "BoundingBox.as"
#include "BoundingSphere.as"
#include "BoundingFrustum.as"

namespace PlaneHelper
{
    shared double ClassifyPoint(Vec3f point, Plane plane)
    {
        return point.x * plane.Normal.x + point.y * plane.Normal.y + point.z * plane.Normal.z + plane.D;
    }

    /// Returns the perpendicular distance from a point to a plane
    shared double PerpendicularDistance(Vec3f point, Plane plane)
    {
        // dist = (ax + by + cz + d) / sqrt(a*a + b*b + c*c)
        return double(Maths::Abs((plane.Normal.x * point.x + plane.Normal.y * point.y + plane.Normal.z * point.z)
                                / Maths::Sqrt(plane.Normal.x * plane.Normal.x + plane.Normal.y * plane.Normal.y + plane.Normal.z * plane.Normal.z)));
    }
}

shared class Plane
{
    Vec3f Normal;
    double D;

    Plane(Vec4f value)
    {
        Normal = Vec3f(value.x, value.y, value.z);
        D = value.w;
    }

    Plane(Vec3f normal, double d)
    {
        Normal = normal;
        D = d;
    }

    Plane(Vec3f a, Vec3f b, Vec3f c)
    {
        Vec3f ab = b - a;
        Vec3f ac = c - a;

        Vec3f cross = ab.Cross(ac);
        Normal = cross.Normalize();
        D = -Normal.Dot(a);
    }

    Plane(double a, double b, double c, double d) 
    {
        Normal.x = a;
        Normal.y = b;
        Normal.z = c;
        D = d;
    }

    double Dot(Vec4f value)
    {
        return ((((this.Normal.x * value.x) + (this.Normal.y * value.y)) + (this.Normal.z * value.z)) + (this.D * value.w));
    }

    double DotCoordinate(Vec3f value)
    {
        return ((((this.Normal.x * value.x) + (this.Normal.y * value.y)) + (this.Normal.z * value.z)) + this.D);
    }   

    double DotNormal(Vec3f value)
    {
        return (((this.Normal.x * value.x) + (this.Normal.y * value.y)) + (this.Normal.z * value.z));
    }    

    //Plane Transform(Plane plane, Quaternion rotation)
    //{
    //    throw NotImplementedException();
    //}
    //Plane Transform(Plane plane, MatrixR matrix)
    //{
    //    throw NotImplementedException();
    //}

    void Normalize()
    {
        double factor;
        Vec3f normal = Normal;
        Normal = Normal.Normalize();
        factor = Maths::Sqrt(Normal.x * Normal.x + Normal.y * Normal.y + Normal.z * Normal.z) /
                Maths::Sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z);
        D = D * factor;
    }    

    bool opEquals(Plane other)
    {
        return (this == other);
    }
    bool opNotEquals(Plane other)
    {
        return this != other;
    }   

    //int GetHashCode()
    //{
    //    return Normal.GetHashCode() ^ D.GetHashCode();
    //}

    PlaneIntersectionType Intersects(BoundingBox box)
    {
        return box.Intersects(this);
    }
    void Intersects(BoundingBox box, PlaneIntersectionType &out result)
    {
        result = Intersects(box);
    }

    PlaneIntersectionType Intersects(BoundingFrustum frustum)
    {
        return frustum.Intersects(this);
    }

    PlaneIntersectionType Intersects(BoundingSphere sphere)
    {
        return sphere.Intersects(this);
    }
    void Intersects(BoundingSphere sphere, PlaneIntersectionType &out result)
    {
        result = Intersects(sphere);
    }

    

    void DotNormal(Vec3f value, double &out result)
    {
        result = ((this.Normal.x * value.x) + (this.Normal.y * value.y)) + (this.Normal.z * value.z);
    }

    void Dot(Vec4f value, double &out result)
    {
        result = (((this.Normal.x * value.x) + (this.Normal.y * value.y)) + (this.Normal.z * value.z)) + (this.D * value.w);
    }

    void DotCoordinate(Vec3f value, double &out result)
    {
        result = (((this.Normal.x * value.x) + (this.Normal.y * value.y)) + (this.Normal.z * value.z)) + this.D;
    } 

    //string ToString()
    //{
    //    return string.Format("{{Normal:{0} D:{1}}}", Normal, D);
    //}
}

void Normalize(Plane value, Plane &out result)
{
    double factor;
    result.Normal = value.Normal.Normalize();
    factor = Maths::Sqrt(result.Normal.x * result.Normal.x + result.Normal.y * result.Normal.y + result.Normal.z * result.Normal.z) /
            Maths::Sqrt(value.Normal.x * value.Normal.x + value.Normal.y * value.Normal.y + value.Normal.z * value.Normal.z);
    result.D = value.D * factor;
}

//void Transform(Plane plane, Quaternion rotation, Plane &out result)
//{
//    throw NotImplementedException();
//}
//
//void Transform(Plane plane, MatrixR matrix, Plane &out result)
//{
//    throw NotImplementedException();
//}