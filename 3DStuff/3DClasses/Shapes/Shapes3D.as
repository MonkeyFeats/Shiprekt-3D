#include "TypeEnums.as"
#include "MathsHelper.as"
#include "Vec4f.as"
#include "Quaternion.as"
#include "BoundingSphere.as"
#include "BoundingFrustum.as"
#include "BoundingBox.as"
#include "BoundingCapsule.as"
#include "Ray.as"
#include "Blob3D.as"
#include "World.as"
#include "PhysicsEngine.as"

shared class BoundingShape
{
    u16 netID;
    Blob3D@ ownerBlob;
    MatrixR model();

    RigidTransform transform;

	f32 Friction 		= 0.2;
	f32 Elasticity 		= 0.0;
	f32 Buoyancy 		= 0.5;

    int  Team 		= -1;
    bool Crouching 	= false;
    bool onGround 	= false;
	bool onMap 		= false;
	bool inWater 	= false; //bool old_inwater = false;	
    bool Attached 	= false;
    bool Collides 	= true;
	//bool onladder;
	//bool onwall;
	//bool onceiling;
	//Vec3f groundNormal;

    private bool initialized = false;

	int customData; //island colour in shiprekt

    BoundingShape(){ }
    BoundingShape(Vec3f _pos) { this.transform.Position = _pos; }

    void RegisterToPhysEngine() 
    {    
        PhysicsWorld@ physicsWorld;
        if (getRules().get("physics", @physicsWorld))
        {
            physicsWorld.RegisterCollider(this);
        }
    }

    void Init(Blob3D@ _parent)
    {
        @ownerBlob = _parent;

        if (initialized)
            return;

        PhysicsWorld@ physicsWorld;
        if (getRules().get("physics", @physicsWorld))
        {
            print("registered");
            physicsWorld.RegisterCollider(@this);
        }

        initialized = true;
    }

    void setBlob(Blob3D@ _blob) {@ownerBlob = @_blob;}
    Blob3D@ getBlob() {return @ownerBlob;}

    void setTeamNum(int _team) {Team = _team;}
    int getTeamNum() {return Team;}

	void setPosition(Vec3f &in pos) {this.transform.Position = pos;}
    Vec3f getPosition() {return this.transform.Position;}
    //Vec3f getInterpolatedPosition(float amount = 0.5f) {return old_Position.Lerp(transform.Position, amount);}

    void setDirection(Vec3f &in dir) { transform.Orientation = Quaternion(transform.Orientation.Transform(dir), 1); }
    //void addDirection(Vec3f &in dir) {transform.Orientation +=   transform.Orientation.Transform(dir); }
    void setAngleDegreesX(float &in x)  {transform.Orientation = Quaternion(transform.Orientation.TransformX(x), 1);  }
    void setAngleDegreesY(float &in y)  {transform.Orientation = Quaternion(transform.Orientation.TransformY(y), 1);  }
    void setAngleDegreesZ(float &in z)  {transform.Orientation = Quaternion(transform.Orientation.TransformZ(z), 1);  }
    void setAngleDegrees(float angle) {transform.Orientation.TransformX(angle);}
    float getAngleDegrees() {return transform.Orientation.x;}

    Vec3f getDirection() {return transform.Orientation.getXYZ();}

    //void setRotation(Vec3f _dir) {this.Angle = _dir;}
    //void setRotationsAllowed(bool _does_rotate) {Rotates = _does_rotate;}
	//bool getRotationsAllowed() {return Rotates;}

	//void SetOffset(Vec3f _shape_offset)
	//Vec3f getOffset()
    float getFriction() {return Friction;}
    void setFriction(float _friction) {Friction = _friction;}

	float getElasticity() {return Elasticity;}
	void setElasticity(float _elasticity) {Elasticity = _elasticity;}

	void setCollides(bool _collides) {Collides = _collides;}
	bool doesCollide() {return Collides;}

    bool isAttached() {return Attached;}

	//void getBoundingRect(Vec2f&out topLeft, Vec2f&out bottomRight)
	//void getBoundingBox(Vec3f&out Min, Vec3f&out Max)
    //void PutOnGround(){}
    //void ResolveInsideMapCollision(){}

    void Update()
    {

    }

    void Render() {}

    ContainmentType Contains(BoundingShape@ other, Vec3f Vel, Vec3f &out MTV) 
    {
        BoundingBox@ box = cast<BoundingBox@>(other);
        BoundingSphere@ sphere = cast<BoundingSphere@>(other);
        BoundingCapsule@ capsule = cast<BoundingCapsule@>(other);
        if (box !is null)
        {
            return this.Contains(box, Vel, MTV);
        }
        else if (sphere !is null)
        {
            return this.Contains(sphere, Vel, MTV);
        }
        else if (capsule !is null)
        {
            return this.Contains(capsule, Vel, MTV);
        }
        return ContainmentType::None;
    }

    ContainmentType Contains(BoundingShape@ other, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) 
    {
        BoundingBox@ box = cast<BoundingBox@>(other);
        BoundingSphere@ sphere = cast<BoundingSphere@>(other);
        BoundingCapsule@ capsule = cast<BoundingCapsule@>(other);
        if (box !is null)
        {
            return this.Contains(box, Pos, Vel, MTV);
        }
        else if (sphere !is null)
        {
            return this.Contains(sphere, Pos, Vel, MTV);
        }
        else if (capsule !is null)
        {
            return this.Contains(capsule, Pos, Vel, MTV);
        }
        return ContainmentType::None;
    }

    ContainmentType Contains(BoundingBox@ box, Vec3f Vel, Vec3f &out MTV) {return ContainmentType::None;} //overridden
    ContainmentType Contains(BoundingBox@ box, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) {return ContainmentType::None;} //overridden
    ContainmentType Contains(BoundingSphere@ sphere, Vec3f Vel, Vec3f &out MTV) {return ContainmentType::None;} //overridden
    ContainmentType Contains(BoundingSphere@ sphere, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) {return ContainmentType::None;} //overridden
    ContainmentType Contains(BoundingCapsule@ capsule, Vec3f Vel, Vec3f &out MTV) {return ContainmentType::None;} //overridden
    ContainmentType Contains(BoundingCapsule@ capsule, Vec3f Pos, Vec3f Vel, Vec3f &out MTV) {return ContainmentType::None;} //overridden

    void UpdateAttributes(SColor){};
    bool Intersects(BoundingShape@ ray) {return ray.Intersects(this); }

}
