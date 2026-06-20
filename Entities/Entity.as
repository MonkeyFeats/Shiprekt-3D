#include "Vec3f.as";
 
class Entity
{
    Vec3f Position;
    Vec3f Velocity;
    float Mass;
    string Name;
    int Team;
    //Shapes Shape;
   
    Entity(){}
   
    Entity(Vec3f _Pos, Vec3f _Vel)
    {
        Position = _Pos;
        Velocity = _Vel;
    }
}

class Shape
{
    Vec3f Position;
    Vec3f Velocity;
    Vec3f[] Vertices;
    f32 Radius;
    f32 Mass;
    f32 Elasticity;
    f32 GravScale;
    f32 Friction;
    f32 Buoyancy;
    f32 Drag;
    bool Collides;
   
    Shape(){}
   
    Shape(Vec3f _Pos, Vec3f _Vel)
    {
        Position = _Pos;
        Velocity = _Vel;
    }
}

class Sphere : Shapes
{
    Vec3f Position;
    Vec3f Velocity;
    f32 Radius;
    f32 Mass;
    f32 Elasticity;
    f32 GravScale;
    f32 Friction;
    f32 Buoyancy;
    f32 Drag;
    bool Collides;
   
    Sphere(){}
   
    Sphere(Vec3f _Pos, Vec3f _Vel)
    {
        Position = _Pos;
        Velocity = _Vel;
    }
}

class Mesh : Shapes
{
    Vec3f Position;
    Vec3f Velocity;
    Vec3f[] Vertices;
    f32 Mass;
    f32 Elasticity;
    f32 GravScale;
    f32 Friction;
    f32 Buoyancy;
    f32 Drag;
    bool Collides;
   
    Mesh(){}
   
    Mesh(Vec3f _Pos, Vec3f _Vel)
    {
        Position = _Pos;
        Velocity = _Vel;
    }
}