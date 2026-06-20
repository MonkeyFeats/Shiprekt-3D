#include "Vec3f.as"

class Line3D
{
    Vec3f start;
    Vec3f end;

    Line3D() {}
    Line3D(float  xa, float  ya, float  za, float  xb, float  yb, float  zb) { start = Vec3f(xa, ya, za); end = Vec3f(xb, yb, zb);}
    Line3D(const Vec3f &in _start, const Vec3f &in _end) { start = _start; end = _end;}

    // operators
    Line3D opAdd(const Vec3f &in point) const { return Line3D (start + point, end + point); }
    Line3D opAddAssign(const Vec3f &in point) { start += point; end += point; return this; }

    Line3D opSub(const Vec3f &in point) const { return Line3D (start - point, end - point); }
    Line3D opSubAssign(const Vec3f &in point) { start -= point; end -= point; return this; }

    bool opEquals(const Line3D & other) const 
    { return (start==other.start && end==other.end) || (end==other.start && start==other.end);}
    bool opNotEquals(const Line3D & other) const
    { return !(start==other.start && end==other.end) || (end==other.start && start==other.end);}

    // functions
    void setLine(const float &in xa, const float &in ya, const float &in za, const float &in xb, const float &in yb, const float &in zb)
    {start.set(xa, ya, za); end.set(xb, yb, zb);}

    void setLine(Vec3f &in nstart, Vec3f &in nend)
    {start = nstart; end = nend;}

    void setLine(const Line3D &in line)
    {start.set(line.start); end.set(line.end);}

    float Length() { return start.Length(end); } 
    float LengthSquared()  { return start.LengthSquared(end); }
    Vec3f getMiddle()   { return (start + end)/2.0; }
    Vec3f getVector()  { return end - start; }
    Vec3f getVectorNormalized()  { return (end - start).Normalize(); } 

    bool isPointBetweenStartAndEnd(const Vec3f &in point) { return point.isBetweenPoints(start, end); }

    Vec3f getClosestPoint(const Vec3f &in point) 
    {
        Vec3f  c = point - start;
        Vec3f  v = end - start;
        float  d = v.Length();
        v /= d;
        float  t = v.DotProd(c);

        if (t < 0.0)
            return start;
        if (t > d)
            return end;

        v *= t;
        return start + v;
    }

    bool getIntersectionWithSphere(Vec3f sorigin, float sradius, f32 &out outdistance)
    {
        Vec3f  q = sorigin - start;
        float  c = q.Length();
        float  v = q.DotProd(getVector().Normalize());
        float  d = sradius * sradius - (c*c - v*v);

        if (d < 0.0)
            return false;

        outdistance = v - Maths::Sqrt( d );
        return true;
    }    
};

