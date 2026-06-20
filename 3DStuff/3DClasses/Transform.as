
shared class RigidTransform
{
    Vec3f Position;
    Quaternion Orientation;
    //Vec3f Scale;

    RigidTransform(Vec3f position, Quaternion orientation)
    {
        Position = position;
        Orientation = orientation;
    }

    RigidTransform(Vec3f position)
    {
        Position = position;
        Orientation = Quaternion();
    }

    RigidTransform(Quaternion orienation)
    {
        Position = Vec3f();
        Orientation = orienation;
    }

    RigidTransform(RigidTransform@ other)
    {
        Position = other.Position;
        Orientation = other.Orientation;
    }

    /// Gets the orientation matrix created from the orientation of the rigid transform.
    MatrixR OrientationMatrix
    {
        get
        {
            MatrixR toReturn;
            toReturn.CreateFromQuaternion(Orientation);
            return toReturn;
        }
    }

    /// Gets the 4x4 matrix created from the rigid transform.
    MatrixR Matrix
    {
        get
        {
            MatrixR toReturn;
            toReturn.CreateFromQuaternion(Orientation);
            toReturn.Translation = Position;
            return toReturn;
        }
    }  

    ///Gets a blank identity
    RigidTransform Identity
    {
        get
        {
            return RigidTransform(
                Vec3f(0,0,0),
                Quaternion()
            );
        }
    }
    /// Gets a copy of the rigid transform.
    RigidTransform GetIdentity 
    {
        get
        {
            RigidTransform t = RigidTransform(Position, Orientation);
            return t;
        }
    }



    Vec3f Forward()
    {
        return Orientation.Transform(Vec3f(0,0,1));
    }

    Vec3f Right()
    {
        return Orientation.Transform(Vec3f(1,0,0));
    }

    Vec3f Up()
    {
        return Orientation.Transform(Vec3f(0,1,0));
    }

//    RigidTransform Lerp(RigidTransform target, float t)
//    {
//        RigidTransform result;
//
//        result.Position =
//            Position.Lerp(target.Position, t);
//
//        result.Orientation =
//            Orientation.Slerp(target.Orientation, t);
//
//        return result;
//    }

    /// Inverts a rigid transform.
    void Invert(RigidTransform transform, RigidTransform &out inverse)
    {
        Vec3f pos;
        inverse.Orientation.Conjugate(transform.Orientation);
        inverse.Orientation.Transform(transform.Position, pos);
        inverse.Position = -pos;
    }

    /// Concatenates a rigid transform with another rigid transform.
    void Multiply(RigidTransform a, RigidTransform b, RigidTransform &out combined)
    {
        Vec3f intermediate;
        b.Orientation.Transform(a.Position, intermediate);
        combined.Position = intermediate + b.Position;
        a.Orientation.Concatenate(b.Orientation, combined.Orientation);

    }

    /// Concatenates a rigid transform with another rigid transform's inverse.
    void MultiplyByInverse(RigidTransform a, RigidTransform b, RigidTransform &out combinedTransform)
    {
        Invert(b, combinedTransform);
        Multiply(a, combinedTransform, combinedTransform);
    }

    /// Transforms a position by a rigid transform.
    void Transform(Vec3f position, RigidTransform transform, Vec3f &out result)
    {
        Vec3f intermediate = transform.Orientation.Transform(position);
        result = intermediate+transform.Position;
    }

    RigidTransform Transform(RigidTransform local)
    {
        RigidTransform result;

        result.Position =
            Position + Orientation.Transform(local.Position);

        Orientation.Concatenate(
            local.Orientation,
            result.Orientation
        );

        return result;
    }

    /// Transforms a position by a rigid transform's inverse.
    void TransformByInverse(Vec3f position, RigidTransform transform, Vec3f &out result)
    {
        Quaternion orientation;
        orientation.Conjugate(transform.Orientation);
        Vec3f intermediate = position-transform.Position;
        orientation.Transform(intermediate, result);
    }

    RigidTransform TransformByInverse(RigidTransform world)
    {
        RigidTransform result;

        Quaternion inv;
        inv.Conjugate(Orientation);

        Vec3f offset = world.Position - Position;
        result.Position = inv.Transform(offset);

        inv.Concatenate(
            world.Orientation,
            result.Orientation
        );

        return result;
    }

    Vec3f Transform(Vec3f position)
    {
        Vec3f intermediate = this.Orientation.Transform(position);
        return intermediate + this.Position;
    }
    Vec3f TransformByInverse(Vec3f position)
    {
        Quaternion orientation();
        Vec3f intermediate = position-this.Position;
        orientation.Conjugate(this.Orientation);
        return orientation.Transform(intermediate);
    }


}
