#include "TypeEnums.as";
#include "Vec3f.as";
#include "Vec4f.as";
#include "BoundingBox.as"
#include "BoundingSphere.as"
#include "BoundingFrustum.as"

shared class Ray
{
    Vec3f Position;
    Vec3f Direction;

    Ray(Vec3f position, Vec3f direction)
    {
        this.Position = position;
        this.Direction = direction;
    }

    bool Equals(Ray other)
    {
        return this.Position == other.Position && this.Direction == other.Direction;
    }

    //int GetHashCode()
    //{
    //    return Position.GetHashCode() ^ Direction.GetHashCode();
    //}

    bool Intersects(BoundingBox box)
    {
        //first test if start in box
           if (Position.x >= box.Min.x
            && Position.x <= box.Max.x
            && Position.y >= box.Min.y
            && Position.y <= box.Max.y
            && Position.z >= box.Min.z
            && Position.z <= box.Max.z)
            return true;// here we concider cube is full and origin is in cube so intersect at origin


        //Second we check each face
        Vec3f maxT = Vec3f(-1.0f);
        //Vec3f minT = Vec3f(-1.0f);
        //calcul intersection with each faces
        if (Position.x < box.Min.x && Direction.x != 0.0f)
            maxT.x = (box.Min.x - Position.x) / Direction.x;
        else if (Position.x > box.Max.x && Direction.x != 0.0f)
            maxT.x = (box.Max.x - Position.x) / Direction.x;
        if (Position.y < box.Min.y && Direction.y != 0.0f)
            maxT.y = (box.Min.y - Position.y) / Direction.y;
        else if (Position.y > box.Max.y && Direction.y != 0.0f)
            maxT.y = (box.Max.y - Position.y) / Direction.y;
        if (Position.z < box.Min.z && Direction.z != 0.0f)
            maxT.z = (box.Min.z - Position.z) / Direction.z;
        else if (Position.z > box.Max.z && Direction.z != 0.0f)
            maxT.z = (box.Max.z - Position.z) / Direction.z;


        //get the maximum maxT
        if (maxT.x > maxT.y && maxT.x > maxT.z)
        {
            if (maxT.x < 0.0f)
                return false;// ray go on opposite of face
            //coordonate of hit point of face of cube
            double coord = Position.z + maxT.x * Direction.z;
            // if hit point coord ( intersect face with ray) is of other plane coord it miss 
            if (coord < box.Min.z || coord > box.Max.z)
                return false;
            coord = Position.y + maxT.x * Direction.y;
            if (coord < box.Min.y || coord > box.Max.y)
                return false;

            //overlap = maxT.x;
            return true;
        }
        if (maxT.y > maxT.x && maxT.y > maxT.z)
        {
            if (maxT.y < 0.0f)
                return false;// ray go on opposite of face
            //coordonate of hit point of face of cube
            double coord = Position.z + maxT.y * Direction.z;
            // if hit point coord ( intersect face with ray) is of other plane coord it miss 
            if (coord < box.Min.z || coord > box.Max.z)
                return false;
            coord = Position.x + maxT.y * Direction.x;
            if (coord < box.Min.x || coord > box.Max.x)
                return false;

            //overlap = maxT.y;
            return true;
        }
        else //Z
        {
            if (maxT.z < 0.0f)
                return false;// ray go on opposite of face
            //coordonate of hit point of face of cube
            double coord = Position.x + maxT.z * Direction.x;
            // if hit point coord ( intersect face with ray) is of other plane coord it miss 
            if (coord < box.Min.x || coord > box.Max.x)
                return false;
            coord = Position.y + maxT.z * Direction.y;
            if (coord < box.Min.y || coord > box.Max.y)
                return false;

            //overlap = maxT.z;
            return true;
        }
        return false;
    }

    //void Intersects(BoundingBox box, double &out result)
    //{
    //    result = Intersects(box);
    //}

    bool Intersects(BoundingFrustum frustum)
    {
        return frustum.Intersects(this);
    }

    bool Intersects(BoundingSphere sphere)
    {
        return this.Intersects(sphere);
    }

    bool Intersects(Plane plane)
    {
        return  this.Intersects(plane);
    }

    void Intersects(Plane plane, double &out result)
    {
        double den = Dot(Direction, plane.Normal);
        if (Maths::Abs(den) < 0.00001f)
        {
            result = 9999999;
            return;
        }

        result = (-plane.D - Dot(plane.Normal, Position)) / den;

        if (result < 0.0f)
        {
            if (result < -0.00001f)
            {
                result = 9999999;
                return;
            }

            result = 0.0f;
        }
    }

    bool Intersects(BoundingSphere sphere, double &out outdistance)
    {
        // Find the vector between where the ray starts the the sphere's centre
        Vec3f difference = sphere.transform.Position - this.Position;

        double differenceLengthSquared = difference.LengthSquared();
        double sphereRadiusSquared = sphere.Radius * sphere.Radius;

        // If the distance between the ray start and the sphere's centre is less than
        // the radius of the sphere, it means we've intersected. N.B. checking the LengthSquared is faster.
        if (differenceLengthSquared < sphereRadiusSquared)
        {
            return false;
        }

        double distanceAlongRay = Dot(this.Direction, difference);
        // If the ray is pointing away from the sphere then we don't ever intersect
        if (distanceAlongRay < 0)
        {
            return false;
        }
        // Next we kinda use Pythagoras to check if we are within the bounds of the sphere
        // if x = radius of sphere
        // if y = distance between ray position and sphere centre
        // if z = the distance we've travelled along the ray
        // if x^2 + z^2 - y^2 < 0, we do not intersect
        double dist = sphereRadiusSquared + distanceAlongRay * distanceAlongRay - differenceLengthSquared;
        outdistance = (dist < 0) ? 0.0f : distanceAlongRay - double(Maths::Sqrt(dist));
        return true;
    }

    bool opNotEquals(Ray a, Ray b)
    {
        return a !is b;
    }

    bool opEquals(Ray a, Ray b)
    {
        return a is b;
    }
}
