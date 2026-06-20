#include "Vec3f.as"
#include "Line3D.as"
#include "Plane.as"
#include "AABB.as"

class Triangle
{
    Vec3f pointA;
    Vec3f pointB;
    Vec3f pointC;

    Triangle() {}
    Triangle(Vec3f v1, Vec3f v2, Vec3f v3) {pointA = v1; pointB = v2; pointC = v3;}

    bool opEquals(const Triangle &in other) const
    {
        return other.pointA == pointA && other.pointB == pointB && other.pointC == pointC;
    }

    bool opNotEquals(const Triangle &in other) const
    {
        return (this!=other);
    }

    bool isTotalInsideBox(const AABB &in box) const
    {
        return (box.isPointInside(pointA) &&
                box.isPointInside(pointB) &&
                box.isPointInside(pointC));
    }

    bool isTotalOutsideBox(const AABB &in box) const
    {
        return ((pointA.x > box.max.x && pointB.x > box.max.x && pointC.x > box.max.x) ||

            (pointA.y > box.max.y && pointB.y > box.max.y && pointC.y > box.max.y) ||
            (pointA.x > box.max.x && pointB.x > box.max.x && pointC.x > box.max.x) ||
            (pointA.x < box.min.x && pointB.x < box.min.x && pointC.x < box.min.x) ||
            (pointA.y < box.min.y && pointB.y < box.min.y && pointC.y < box.min.y) ||
            (pointA.x < box.min.x && pointB.x < box.min.x && pointC.x < box.min.x));
    }

    Vec3f closestPointOnTriangle(const Vec3f& p) const
    {
        const Vec3f rab = Line3D(pointA, pointB).getClosestPoint(p);
        const Vec3f rbc = Line3D(pointB, pointC).getClosestPoint(p);
        const Vec3f rca = Line3D(pointC, pointA).getClosestPoint(p);

        const float d1 = rab.Length(p);
        const float d2 = rbc.Length(p);
        const float d3 = rca.Length(p);

        if (d1 < d2)
            return d1 < d3 ? rab : rca;

        return d2 < d3 ? rbc : rca;
    }

    bool isPointInside(const Vec3f &in p) const
    {
        Vec3f a(pointA.x, pointA.y, pointA.z);
        Vec3f b(pointB.x, pointB.y, pointB.z);
        Vec3f c(pointC.x, pointC.y, pointC.z);
        return (isOnSameSide(p, a, b, c) && isOnSameSide(p, b, a, c) && isOnSameSide(p, c, a, b));
    }

    bool isPointInsideFast(const Vec3f &in p)
    {
         Vec3f a = pointC - pointA;
         Vec3f b = pointB - pointA;
         Vec3f c = p - pointA;

        float dotAA = a.Dot(a);
        float dotAB = a.Dot(b);
        float dotAC = a.Dot(c);
        float dotBB = b.Dot(b);
        float dotBC = b.Dot(c);

        // get coordinates in barycentric coordinate system
         f32 invDenom =  1/(dotAA * dotBB - dotAB * dotAB);
         f32 u = (dotBB * dotAC - dotAB * dotBC) * invDenom;
         f32 v = (dotAA * dotBC - dotAB * dotAC ) * invDenom;

        // We count border-points as inside to keep downward compatibility.
        // Rounding-error also needed for some test-cases.
        return (u > -0.000000001) && (v >= 0) && (u + v < 1.000000001);

    }

    bool getIntersectionWithLimitedLine( Line3D&in line, Vec3f &out outIntersection) const
    {
        return getIntersectionWithLine(line.start, line.getVector(), outIntersection) && outIntersection.isBetweenPoints(line.start, line.end);
    }

    bool getIntersectionWithLine(const Vec3f &in linePoint, const Vec3f &in lineVect, Vec3f &out outIntersection) const
    {
        if (getIntersectionOfPlaneWithLine(linePoint, lineVect, outIntersection))
            return isPointInside(outIntersection);

        return false;
    }

    bool getIntersectionOfPlaneWithLine(const Vec3f &in linePoint, const Vec3f &in lineVect, Vec3f &out outIntersection) const
    {
        Triangle triangle(Vec3f(pointA.x, pointA.y, pointA.z), Vec3f(pointB.x, pointB.y, pointB.z), Vec3f(pointC.x, pointC.y, pointC.z));
        Vec3f normal = triangle.getNormal();
        normal.Normalize();
        float t2;
        t2 = normal.Dot(lineVect);

        if ( t2 == 0 )
            return false;

        float d = triangle.pointA.Dot(normal);
        float t = -(normal.Dot(linePoint) - d) / t2;
        outIntersection = linePoint + (lineVect * t);

        outIntersection.x = outIntersection.x;
        outIntersection.y = outIntersection.y;
        outIntersection.x = outIntersection.z;
        return true;
    }

    Vec3f getNormal() const
    {
        return (pointB - pointA).CrossProd(pointC - pointA);
    }

    bool isFrontFacing(const Vec3f & lookDirection) const
    {
        Vec3f  n = getNormal(); n.Normalize();
        f32 d = n.DotProd(lookDirection);
        return d <= 0.0f;
    }

    Plane getPlane() const
    {
        return Plane();//Plane(pointA, pointB, pointC);
    }

    float getArea() const
    {
        return ((pointB - pointA).Cross(pointC - pointA)).Length() * 0.5f;
    }

    void set(const Vec3f&in a, const Vec3f&in b, const Vec3f&in c)
    {
        pointA = a;
        pointB = b;
        pointC = c;
    }

    bool isOnSameSide(const Vec3f&in p1, const Vec3f&in p2, const Vec3f&in a, const Vec3f&in b) const
    {
        Vec3f bminusa = b - a;
        Vec3f cp1 = bminusa.Cross(p1 - a);
        Vec3f cp2 = bminusa.Cross(p2 - a);
        f64 res = cp1.DotProd(cp2);
        if ( res < 0 )
        {
            // This catches some floating point troubles.
            // Unfortunately slightly expensive and we don't really know the best epsilon for iszero.
            Vec3f cp1 = bminusa.Normalize();
            cp1.Cross((p1 - a).Normalize());
            if ( cp1.x <= 0.000000001 &&  cp1.y <= 0.000000001 &&  cp1.z <= 0.000000001 )
            {
                res = 0.0f;
            }
        }
        return (res >= 0.0f);
    }
};