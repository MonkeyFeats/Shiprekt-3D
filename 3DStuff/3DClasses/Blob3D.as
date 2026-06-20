
#include "Vec3f.as"
#include "Transform.as"
#include "Shapes3D.as"
#include "RigidBody.as"

//bool hold_frustum = false;

float max_dig_time = 100;
bool block_menu = false;
bool block_menu_created = false;

shared class Blob3D
{
    u16 netID;

    CBlob@ ownerBlob; // reference to CBlob // one day I should remake without, but that means remaking the entire game
    CPlayer@ player;
    BoundingShape@ shape;
    BoundingShape@[] ExtraShapes;
    Vec3f[] ExtraShapeOffsets;
    RigidBody@ rb;
    SMesh@ mesh = SMesh();
    Blob3D@ Parent;
    Blob3D@[] Children;
    string Name;
    bool HasMesh = false;
    bool SpinAroundParentForward = false;
    Vec3f renderOffset;
    Vec3f renderRotation;
    f32 renderScale = 1.0f;

    RigidTransform transform;
    RigidTransform LocalTransform;

    int Team;
    bool Crouching = false;
    bool onGround = false;
    bool Frozen = false;
    bool Attached = false;
    float Health = 2.0f; 
    float MaxHealth = 2.0f;

    int CustomData; //island color in shiprekt

    //Blob3D(){}

    Blob3D(Vec3f _Pos, int _team)
    {
        Team = _team;
        transform.Position = _Pos;  
        @player = null;     
        //setRigidBody();
    }

    Blob3D(Vec3f _Pos, int _team, float _maxhealth)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth;   
        @player = null;     
        //setRigidBody();
    }

    Blob3D(CBlob@ _owner, Vec3f _Pos, int _team, float _maxhealth)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth; 
        @ownerBlob = _owner;  
        //setRigidBody();
    }

    Blob3D(CBlob@ _owner, Vec3f _Pos, int _team, float _maxhealth, BoundingShape@ _shape)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth; 
        @ownerBlob = _owner;
        @_shape.ownerBlob = this;
        @shape = _shape;

    }   

    Blob3D(CBlob@ _owner, Vec3f _Pos, int _team, float _maxhealth, BoundingShape@ _shape, RigidBody@ _rb)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth; 
        @ownerBlob = _owner;
        @_shape.ownerBlob = this;
        @shape = _shape;
        @rb = _rb;

    }

    Blob3D(CBlob@ _owner, CPlayer@ _player, Vec3f _Pos, int _team, float _maxhealth, BoundingShape@ _shape)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth; 
        @ownerBlob = _owner;
        @player = _player;
        @_shape.ownerBlob = this;
        @shape = _shape;
    }

    Blob3D(CBlob@ _owner, CPlayer@ _player, Vec3f _Pos, int _team, float _maxhealth, BoundingShape@ _shape, RigidBody@ _rb)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth; 
        @ownerBlob = _owner;
        @player = _player;
        @_shape.ownerBlob = this;
        @shape = _shape;
        @rb = _rb;
    }
    Blob3D(CBlob@ _owner, CPlayer@ _player, Vec3f _Pos, int _team, float _maxhealth)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth; 
        @ownerBlob = _owner;
        @player = _player;
    }

    Blob3D(Vec3f _Pos, int _team, float _maxhealth, SMesh@ _mesh, BoundingShape@ _shape)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth;
        @mesh = _mesh;
        @shape = _shape;
        HasMesh = _mesh !is null;
    }

    Blob3D(CPlayer@ _player, Vec3f _Pos, int _team, float _maxhealth)
    {
        Team = _team;
        transform.Position = _Pos;
        MaxHealth = Health = _maxhealth;
        @player = _player;
    }

    Blob3D(Vec3f _Pos, int _team, float _maxhealth, BoundingShape@ _shape)
    {
        transform.Position = _Pos;
        Team = _team;
        MaxHealth = Health = _maxhealth;
        @shape = _shape;
    }

    Blob3D(Vec3f _Pos, int _team, float _maxhealth, BoundingShape@ _shape, RigidBody@ _rb)
    {
        transform.Position = _Pos;
        Team = _team;
        MaxHealth = Health = _maxhealth;
        @shape = _shape;
        @_rb.parent = this;
        @rb = _rb;
    }

    void SetPlayer(CPlayer@ _player) {@player = @_player;}
    void SetShape(BoundingShape@ _shape) {@shape = @_shape;}

    void setRigidBody() {
        RigidBody@ _rb = RigidBody();
                        @rb = _rb; }
    RigidBody getRigidBody() {return rb;}

    int getTeamNum() {return this.Team;}
    CPlayer@ getPlayer() {return this.player;};
    void setPlayer(CPlayer@ _player) {@this.player = _player;}
    float getDistanceTo( Vec3f &in otherPos ) {return (transform.Position - otherPos).Length();}

    void setPosition(Vec3f &in pos) {transform.Position = pos;}
    void addPosition(Vec3f &in pos) {transform.Position += pos;}
    Vec3f getPosition() {return transform.Position;}
    Vec3f getVelocity() {return rb.getVelocity();}
    //Vec3f getInterpolatedPosition(float amount = 0.5f) {return old_Position.Lerp(transform.Position, amount);}

    void setDirection(Vec3f &in dir) { transform.Orientation.Transform(dir); }
    //void addDirection(Vec3f &in dir) {transform.Orientation +=   transform.Orientation.Transform(dir); }
    //void addDirectionX(float &in x)  {transform.Orientation.x += transform.Orientation.TransformX(x);  }
    //void addDirectionY(float &in y)  {transform.Orientation.y += transform.Orientation.TransformY(y); }
    //void addDirectionZ(float &in z)  {transform.Orientation.z += transform.Orientation.TransformZ(z); }
    void setAngleDegrees(float angle) {transform.Orientation.TransformX(angle);}
    float getAngleDegrees() {return transform.Orientation.x;}

    Vec3f getDirection() {return transform.Orientation.getXYZ();}
    Vec3f getInterpolatedDirection(float amount = 0.5f) {return transform.Orientation.getXYZ();}

    Vec3f getMayaRotation()
    {
        return Vec3f(transform.Orientation.y, transform.Orientation.x, transform.Orientation.z);
    }

    Vec3f getInheritedRenderOffset()
    {
        Vec3f offset = renderOffset;
        Blob3D@ parent = Parent;
        while (parent !is null)
        {
            offset += parent.renderOffset;
            @parent = parent.Parent;
        }

        return offset;
    }

    Vec3f getInheritedRenderRotation()
    {
        Vec3f rotation = renderRotation;
        Blob3D@ parent = Parent;
        while (parent !is null)
        {
            rotation += parent.renderRotation;
            @parent = parent.Parent;
        }

        return rotation;
    }

    Vec3f getRenderPosition()
    {
        return transform.Position + getInheritedRenderOffset();
    }

    void setMayaRotation(Vec3f rotation)
    {
        transform.Orientation.y = rotation.x;
        transform.Orientation.x = rotation.y;
        transform.Orientation.z = rotation.z;
    }

    Vec3f getLocalMayaRotation()
    {
        return Vec3f(LocalTransform.Orientation.y, LocalTransform.Orientation.x, LocalTransform.Orientation.z);
    }

    void setLocalMayaRotation(Vec3f rotation)
    {
        LocalTransform.Orientation.y = rotation.x;
        LocalTransform.Orientation.x = rotation.y;
        LocalTransform.Orientation.z = rotation.z;
    }

    void setLocalMayaTransform(Vec3f position, Vec3f rotation)
    {
        LocalTransform.Position = position;
        setLocalMayaRotation(rotation);
    }

    //void AddForceAtPosition(Vec3f force, Vec3f pos) {} 

    void Damage(float amount /*, Blob3D@ damager*/) {Health -= amount;}
    void server_Heal(float amount) {Health += amount; if (Health > MaxHealth) Health = MaxHealth;}
    void server_SetHealth(float amount) {Health = amount; if (Health > MaxHealth) Health = MaxHealth;}
    void server_Die() {Health = 0;}

    bool isAttached() {return Parent !is null;}
    void AttachTo(Blob3D@ parent) { @Parent = parent; LocalTransform = parent.transform.TransformByInverse(transform); }

    void AddChild(Blob3D@ child)
    {
        if (child is null)
            return;

        for (uint i = 0; i < Children.length(); i++)
        {
            if (Children[i] is child)
                return;
        }

        @child.Parent = this;
        child.LocalTransform.Position = child.transform.Position;
        child.LocalTransform.Orientation = child.transform.Orientation;
        Children.push_back(@child);
    }

    Blob3D@ getChild(string childName)
    {
        for (uint i = 0; i < Children.length(); i++)
        {
            Blob3D@ child = Children[i];
            if (child !is null && child.Name == childName)
                return child;
        }

        return null;
    }

    void AddExtraShape(BoundingShape@ extraShape, Vec3f localOffset)
    {
        if (extraShape is null)
            return;

        @extraShape.ownerBlob = this;
        ExtraShapes.push_back(extraShape);
        ExtraShapeOffsets.push_back(localOffset);
        SyncExtraShapes();
    }

    void SyncExtraShapes()
    {
        Vec3f basePosition = getRenderPosition();
        Vec3f baseOrientation = transform.Orientation.getXYZ();
        if (shape !is null)
        {
            basePosition = shape.getPosition();
            baseOrientation = shape.transform.Orientation.getXYZ();
        }

        for (uint i = 0; i < ExtraShapes.length(); i++)
        {
            BoundingShape@ extraShape = ExtraShapes[i];
            if (extraShape is null)
                continue;

            Vec3f offset;
            if (i < ExtraShapeOffsets.length())
            {
                offset = ExtraShapeOffsets[i];
            }
            offset.xzRotateBy(baseOrientation.x);
            extraShape.transform.Position = basePosition + offset;
            extraShape.transform.Orientation.x = baseOrientation.x;
            extraShape.transform.Orientation.y = baseOrientation.y;
            extraShape.transform.Orientation.z = baseOrientation.z;
        }
    }

    void UpdateFromParent()
    {
        if (Parent is null)
            return;

        Vec3f offset = LocalTransform.Position;
        offset.xzRotateBy(Parent.transform.Orientation.x);

        transform.Position = Parent.transform.Position + offset;
        transform.Orientation.x = Parent.transform.Orientation.x + LocalTransform.Orientation.x;
        transform.Orientation.y = LocalTransform.Orientation.y;
        transform.Orientation.z = LocalTransform.Orientation.z;
    }

    Vec3f RotateAroundAxis(Vec3f vector, Vec3f axis, f32 degrees)
    {
        const f32 radians = degrees * (Maths::Pi / 180.0f);
        const f32 c = Maths::Cos(radians);
        const f32 s = Maths::Sin(radians);
        const f32 along = axis.Dot(vector);
        return vector * c + Cross(axis, vector) * s + axis * along * (1.0f - c);
    }

    void RenderParentForwardSpin(float[] model)
    {
        Vec3f rotation = getLocalMayaRotation();
        const f32 parentYaw = Parent.transform.Orientation.x;

        Vec3f right(1.0f, 0.0f, 0.0f);
        Vec3f up(0.0f, 1.0f, 0.0f);
        Vec3f forward(0.0f, 0.0f, 1.0f);
        right.xzRotateBy(parentYaw);
        forward.xzRotateBy(parentYaw);

        right = RotateAroundAxis(right, forward, rotation.z);
        up = RotateAroundAxis(up, forward, rotation.z);

        Matrix::MakeIdentity(model);
        model[0] = right.x;   model[1] = right.y;   model[2] = right.z;
        model[4] = up.x;      model[5] = up.y;      model[6] = up.z;
        model[8] = forward.x; model[9] = forward.y; model[10] = forward.z;
        if (renderScale != 1.0f)
        {
            for (uint i = 0; i < 3; i++)
            {
                model[i] *= renderScale;
                model[4 + i] *= renderScale;
                model[8 + i] *= renderScale;
            }
        }
        Vec3f renderPosition = getRenderPosition();
        model[12] = renderPosition.x;
        model[13] = renderPosition.y;
        model[14] = renderPosition.z;
        Render::SetModelTransform(model);
        mesh.RenderMeshWithMaterial();
    }

    void Render(float[] model)
    {
        if (Parent !is null)
        {
            UpdateFromParent();
        }
        else if (ownerBlob !is null && ownerBlob.getName() == "block")
        {
            if (ownerBlob.getShape().getVars().customData <= 0)
            {
                renderOffset = Vec3f();
                renderRotation = Vec3f();
            }
        }
        else if (ownerBlob !is null && shape is null)
        {
            Vec2f blobPosition = ownerBlob.getInterpolatedPosition();
            transform.Position.x = blobPosition.x;
            transform.Position.z = blobPosition.y;
            transform.Orientation.x = ownerBlob.getAngleDegrees();
        }

        if (HasMesh && mesh !is null)
        {
            if (Parent !is null && SpinAroundParentForward)
            {
                RenderParentForwardSpin(model);
            }
            else
            {
                Vec3f rotation = getMayaRotation() + getInheritedRenderRotation();
                if (ownerBlob !is null && ownerBlob.getName() == "human")
                {
                    rotation.x = 0.0f;
                    if (ownerBlob.isAttached() && shape !is null)
                    {
                        rotation.y = shape.transform.Orientation.x - 90.0f;
                    }
                }
                Vec3f renderPosition = getRenderPosition();
                Matrix::MakeIdentity(model);
                Matrix::SetTranslation(model, renderPosition.x, renderPosition.y, renderPosition.z);
                Matrix::SetRotationDegrees(model, rotation.x, -rotation.y, rotation.z);
                if (renderScale != 1.0f)
                {
                    for (uint i = 0; i < 3; i++)
                    {
                        model[i] *= renderScale;
                        model[4 + i] *= renderScale;
                        model[8 + i] *= renderScale;
                    }
                }
                Render::SetModelTransform(model);
                mesh.RenderMeshWithMaterial();
            }
        }

        for (uint i = 0; i < Children.length(); i++)
        {
            Blob3D@ child = Children[i];
            if (child !is null)
            {
                if (child.Name == "core_crystal")
                    continue;

                child.Render(model);
            }
        }
    }

    void RenderCollisionShapes()
    {
        if (Parent !is null)
        {
            UpdateFromParent();
        }

        Vec3f visualRotation = getInheritedRenderRotation();
        if (shape !is null)
        {
            Vec3f oldPosition = shape.transform.Position;
            Vec3f oldOrientation = shape.transform.Orientation.getXYZ();

            shape.transform.Position = getRenderPosition();
            shape.transform.Orientation.x = transform.Orientation.x;
            shape.transform.Orientation.y = visualRotation.x;
            shape.transform.Orientation.z = visualRotation.z;
            shape.Render();

            shape.transform.Position = oldPosition;
            shape.transform.Orientation.x = oldOrientation.x;
            shape.transform.Orientation.y = oldOrientation.y;
            shape.transform.Orientation.z = oldOrientation.z;
        }

        if (ExtraShapes.length() > 0)
        {
            Vec3f basePosition = getRenderPosition();
            Vec3f baseOrientation = transform.Orientation.getXYZ();
            if (shape !is null)
            {
                basePosition = shape.getPosition() + getInheritedRenderOffset();
                baseOrientation = shape.transform.Orientation.getXYZ();
            }

            for (uint i = 0; i < ExtraShapes.length(); i++)
            {
                BoundingShape@ extraShape = ExtraShapes[i];
                if (extraShape !is null)
                {
                    Vec3f oldPosition = extraShape.transform.Position;
                    Vec3f oldOrientation = extraShape.transform.Orientation.getXYZ();

                    Vec3f offset;
                    if (i < ExtraShapeOffsets.length())
                    {
                        offset = ExtraShapeOffsets[i];
                    }
                    offset.xzRotateBy(baseOrientation.x);

                    extraShape.transform.Position = basePosition + offset;
                    extraShape.transform.Orientation.x = baseOrientation.x;
                    extraShape.transform.Orientation.y = visualRotation.x;
                    extraShape.transform.Orientation.z = visualRotation.z;
                    extraShape.Render();

                    extraShape.transform.Position = oldPosition;
                    extraShape.transform.Orientation.x = oldOrientation.x;
                    extraShape.transform.Orientation.y = oldOrientation.y;
                    extraShape.transform.Orientation.z = oldOrientation.z;
                }
            }
        }

        for (uint i = 0; i < Children.length(); i++)
        {
            Blob3D@ child = Children[i];
            if (child !is null)
            {
                child.RenderCollisionShapes();
            }
        }
    }

    bool isStatic() {return Frozen;}

    //void onInit() {}

    void onTick() 
    {
        if (shape is null) return;

        if (Parent !is null)
        {
            transform = Parent.transform.Transform(LocalTransform);
            //shape.onTick();
            //shape.setPosition(transform.Position);
            shape.UpdateAttributes(SColor(255,255,0,255));
        }
        //else if (shape.isStatic()) 
        //{
        //    shape.setPosition(this.transform.Position);
        //    shape.UpdateAttributes(SColor(255,255,0,255));
        //    //return;
        //}         
        else
        {
            //this.setVelocity(shape.Velocity);
            //this.setPosition(shape.getPosition());
            //transform.setPosition(shape.getPosition());
            //shape.onTick();
        }
            shape.UpdateAttributes(SColor(255,255,0,255));
            shape.setPosition(transform.Position);
    }
};
