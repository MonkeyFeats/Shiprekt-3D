#include "Vec3f.as";
#include "SAT_Shapes.as";

class Shape
{
    Vec3f Position;
    Vec3f Velocity;
    f32 Mass;
    f32 Elasticity;
    f32 GravScale;
    f32 Friction;
    f32 Buoyancy;
    f32 Drag;
    bool Collides;
      
    Shape(Vec3f _Pos)
    {
        Position = _Pos;
    }
}

class Circle : Shapes
{
    f32 Radius;  
    Circle(float _radius)
    {
        Radius = _radius;
    }
}

class Square : Shapes
{
    Vec2f[] Verts;
    Square(float _size)
    {
        Verts.set_length(4);
        Verts[0] = Vec2f(-1,-1)*_size;
        Verts[1] = Vec2f( 1,-1)*_size;
        Verts[2] = Vec2f( 1, 1)*_size;
        Verts[3] = Vec2f(-1, 1)*_size;
    }
}

class Mesh
{
    Vertex[] Vertices;
    u16[] IDs;
   
    Mesh(){}   
    Mesh()
    {
        
    }
}