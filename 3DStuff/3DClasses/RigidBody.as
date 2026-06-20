#include "World.as"
#include "PhysicsEngine.as"

const f32 RIGIDBODY_VELOCITY_DEADZONE = 0.01f;
const f32 RIGIDBODY_VERTICAL_REST_DEADZONE = 0.05f;

shared class RigidBody
{
    Blob3D@ parent;
    float Mass = 60.0;
    float LinearDragScale = 0.3;
    float AngularDragScale = 0.02;
    float GravityScale = 1.0;

    bool FreezePos, FreezePosX, FreezePosY, FreezePosZ = false;
    bool FreezeRot, FreezeRotX, FreezeRotY, FreezeRotZ = false;
    bool UseGravity = false;

    private Vec3f Velocity;
    private Vec3f AngularVelocity;

    Vec3f forceAccumulator;
    private Vec3f torqueAccumulator;

    private Vec3f InertiaTensor;
    private Vec3f LocalCenterOfMass;

    private bool initialized = false;

    
    Vec3f pendingPositionCorrection;
    Vec3f pendingVelocityDisplacement;
    Vec3f pendingVelocityCorrection;

    RigidBody() {

        initialized = false;
        FreezePos = false; FreezePosX = false; FreezePosY = false; FreezePosZ = false; FreezeRot = false; FreezeRotX = false; FreezeRotY = false; FreezeRotZ = false; UseGravity = false;
    }

    void Init(Blob3D@ _parent)
    {
        @parent = _parent;

        if (initialized)
            return;

        PhysicsWorld@ physicsWorld;
        if (getRules().get("physics", @physicsWorld))
        {
            print("registered");
            physicsWorld.RegisterBody(@this);
        }
        initialized = true;

    }

    void RegisterToPhysEngine()
    {
        PhysicsWorld@ physicsWorld;
        if (getRules().get("physics", @physicsWorld))
        {
            print("registered");
            physicsWorld.RegisterBody(@this);
        }
    }

    Vec3f getVelocity() { return Velocity; }
    void setVelocity(Vec3f v) { Velocity = v; }
    // Collision solver writes both because Update() commits pendingVelocityCorrection.
    void setSolvedVelocity(Vec3f v)
    {
        Velocity = v;
        pendingVelocityCorrection = v;
    }

    Vec3f getAngularVelocity() { return AngularVelocity; }
    void setAngularVelocity(Vec3f v)
    {
        if (FreezeRot) return;
        AngularVelocity = v;
    }

    void setMass(float _mass) { Mass = _mass; }
    float getMass() { return Mass; }

    void SetBoxInertia(Vec3f size)
    {
        const float f = Mass / 12.0f;
        InertiaTensor.x = f * (size.y * size.y + size.z * size.z);
        InertiaTensor.y = f * (size.x * size.x + size.z * size.z);
        InertiaTensor.z = f * (size.x * size.x + size.y * size.y);
    }

    Vec3f ScaleByInverseInertia(Vec3f value)
    {
        return Vec3f(
            InertiaTensor.x != 0.0f ? value.x / InertiaTensor.x : value.x / Mass,
            InertiaTensor.y != 0.0f ? value.y / InertiaTensor.y : value.y / Mass,
            InertiaTensor.z != 0.0f ? value.z / InertiaTensor.z : value.z / Mass
        );
    }

    void addForce(Vec3f force)
    {
        forceAccumulator += force;
    }

    void addTorque(Vec3f torque)
    {
        if (FreezeRot) return;
        torqueAccumulator += torque;
    }

    void addImpulse(Vec3f impulse)
    {
       // if (FreezePos) return;
        pendingVelocityCorrection += impulse / Mass;
    }

    void addAngularImpulse(Vec3f angularImpulse)
    {
        if (FreezeRot) return;
        AngularVelocity += ScaleByInverseInertia(angularImpulse);
    }

    void addForceAtLocalPosition(Vec3f force, Vec3f point)
    {
        addForce(force);

        Vec3f r = point - LocalCenterOfMass;
        Vec3f torque = Cross(r, force);
        addTorque(torque);
    }

    void addImpulseAtLocalPosition(Vec3f impulse, Vec3f point)
    {
        addImpulse(impulse);

        Vec3f r = point - LocalCenterOfMass;
        Vec3f angularImpulse = Cross(r, impulse);
        addAngularImpulse(angularImpulse);
    }

    void PreUpdate(float dt)
    {
        //print("forceAccumulator "+ forceAccumulator.toString());
        if (parent is null)
        {
            //print("RigidBody has NULL parent!");
            return;
        }

        // Start with last frame's solved velocity.
        pendingVelocityCorrection += Velocity;

        // -------------------------
        // GRAVITY (as force)
        // -------------------------
        if (UseGravity)
        {
            forceAccumulator += Vec3f(0, -9.81f * Mass * GravityScale, 0);
        }

        // Apply forces once.
        pendingVelocityCorrection += (forceAccumulator / Mass) * dt;
        forceAccumulator = Vec3f();

        // Apply drag once.
        const f32 linearRetain = Maths::Pow( Maths::Clamp(1.0f - LinearDragScale, 0.0f, 1.0f), dt);
        pendingVelocityCorrection *= linearRetain;


        if (pendingVelocityCorrection.LengthSquared() < 0.0000001f)
        {
            pendingVelocityCorrection = Vec3f();
        }
        else
        {
            //print("Velocity "+ Velocity.toString());
            pendingVelocityDisplacement = pendingVelocityCorrection*dt;
        }

        // -------------------------
        // ANGULAR INTEGRATION
        // -------------------------
        Vec3f angularAccel = torqueAccumulator / Mass;
        AngularVelocity += angularAccel * dt;

        torqueAccumulator = Vec3f();

        AngularVelocity *= (1.0f - AngularDragScale);

        parent.transform.Orientation.Rotate(AngularVelocity * dt);
        //print("ppc "+pendingVelocityCorrection.toString());
    }

    void Update(float dt)
    {
        //print("ppc "+pendingPositionCorrection.toString());
        // Apply collision corrections
        if (pendingVelocityCorrection.Length() > 0.0000f)
        {
            Velocity = pendingVelocityCorrection;
        }
        else
        {
            Velocity = Vec3f();
        }

        Vec3f totalPositionCorrection = pendingVelocityDisplacement + pendingPositionCorrection;
        if (totalPositionCorrection.Length() > 0.0000f)
        {
            parent.transform.Position += totalPositionCorrection;
        }

        

        pendingPositionCorrection = Vec3f();
        pendingVelocityDisplacement = Vec3f();
        pendingVelocityCorrection = Vec3f();
    }

    Vec3f getInertia()
    {
        Vec3f size = Vec3f(4,4,4) * 2.0f;
        float f = 1.0f / 12.0f;

        Vec3f t;
        t.x = (size.y*size.y + size.z*size.z) * Mass * f;
        t.y = (size.x*size.x + size.z*size.z) * Mass * f;
        t.z = (size.x*size.x + size.y*size.y) * Mass * f;
        return t;
    }

    Vec3f inverseInertiaTensor()
    {
        return Vec3f(
            InertiaTensor.x != 0.0f ? 1.0f / InertiaTensor.x : 0,
            InertiaTensor.y != 0.0f ? 1.0f / InertiaTensor.y : 0,
            InertiaTensor.z != 0.0f ? 1.0f / InertiaTensor.z : 0
        );
    }

    void SetCenterOfMassOffset(Vec3f _COM) { LocalCenterOfMass = _COM; }
}
