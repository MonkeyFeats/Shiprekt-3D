#include "Quaternion.as"
//
shared class Quaternion
{
    double x;
    double y;
    double z;
    double w;

    private Quaternion QIdentity
    {
        get { return  Quaternion(0, 0, 0, 1);}
    }
    //Quaternion Identity
    //{ get { return Qidentity; } }

    Quaternion()
    {
        this.x = 0;
        this.y = 0;
        this.z = 0;
        this.w = 1;
    }

    Quaternion(double x, double y, double z, double w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    Quaternion(Vec3f vectorPart, double scalarPart)
    {
        this.x = vectorPart.x;
        this.y = vectorPart.y;
        this.z = vectorPart.z;
        this.w = scalarPart;
    } 

    Vec3f getXYZ() { return Vec3f(x,y,z); }

    Vec3f getEuler()
    {
        float sqx = x*x;
        float sqy = y*y;
        float sqz = z*z;
        float sqw = w*w;

        float unit = sqx + sqy + sqz + sqw;
        float test = x*y + z*w;

        Vec3f euler;
        euler.y = Maths::ATan2(2*y*w - 2*x*z, sqx - sqy - sqz + sqw);
        euler.z = Maths::ASin(2*test/unit);
        euler.x = Maths::ATan2(2*x*w - 2*y*z, -sqx + sqy - sqz + sqw);
        return euler;
    }

    void Transform(Vec3f v, Vec3f &out result)
    {
        //This operation is an optimized-down version of v' = q * v * q^-1.
        //The expanded form would be to treat v as an 'axis only' quaternion
        //and perform standard quaternion multiplication.  Assuming q is normalized,
        //q^-1 can be replaced by a conjugation.
        float x2 = this.x + this.x;
        float y2 = this.y + this.y;
        float z2 = this.z + this.z;
        float xx2 = this.x * x2;
        float xy2 = this.x * y2;
        float xz2 = this.x * z2;
        float yy2 = this.y * y2;
        float yz2 = this.y * z2;
        float zz2 = this.z * z2;
        float wx2 = this.w * x2;
        float wy2 = this.w * y2;
        float wz2 = this.w * z2;
        //Defer the component setting since they're used in computation.
        float transformedX = v.x * (1.0f - yy2 - zz2) + v.y * (xy2 - wz2) + v.z * (xz2 + wy2);
        float transformedY = v.x * (xy2 + wz2) + v.y * (1.0f - xx2 - zz2) + v.z * (yz2 - wx2);
        float transformedZ = v.x * (xz2 - wy2) + v.y * (yz2 + wx2) + v.z * (1.0f - xx2 - yy2);
        result.x = transformedX;
        result.y = transformedY;
        result.z = transformedZ;
    } 

    Vec3f Transform(Vec3f v)
    {
        Vec3f result;
        float x2 = this.x + this.x;
        float y2 = this.y + this.y;
        float z2 = this.z + this.z;
        float xx2 = this.x * x2;
        float xy2 = this.x * y2;
        float xz2 = this.x * z2;
        float yy2 = this.y * y2;
        float yz2 = this.y * z2;
        float zz2 = this.z * z2;
        float wx2 = this.w * x2;
        float wy2 = this.w * y2;
        float wz2 = this.w * z2;
        //Defer the component setting since they're used in computation.
        float transformedX = v.x * (1.0f - yy2 - zz2) + v.y * (xy2 - wz2) + v.z * (xz2 + wy2);
        float transformedY = v.x * (xy2 + wz2) + v.y * (1.0f - xx2 - zz2) + v.z * (yz2 - wx2);
        float transformedZ = v.x * (xz2 - wy2) + v.y * (yz2 + wx2) + v.z * (1.0f - xx2 - yy2);
        result.x = transformedX;
        result.y = transformedY;
        result.z = transformedZ;
        return result;
    } 

    Vec3f TransformX(float inx)
    {
        Vec3f result;
        float y2 = this.y + this.y;
        float z2 = this.z + this.z;
        float xy2 = this.x * y2;
        float xz2 = this.x * z2;
        float yy2 = this.y * y2;
        float zz2 = this.z * z2;
        float wy2 = this.w * y2;
        float wz2 = this.w * z2;
        float transformedX = inx * (1.0f - yy2 - zz2);
        float transformedY = inx * (xy2 + wz2);
        float transformedZ = inx * (xz2 - wy2);
        result.x = transformedX;
        result.y = transformedY;
        result.z = transformedZ;
        return result;
    }

    Vec3f TransformY(float iny)
    {
        Vec3f result;
        float x2 = this.x + this.x;
        float y2 = this.y + this.y;
        float z2 = this.z + this.z;
        float xx2 = this.x * x2;
        float xy2 = this.x * y2;
        float yz2 = this.y * z2;
        float zz2 = this.z * z2;
        float wx2 = this.w * x2;
        float wz2 = this.w * z2;
        //Defer the component setting since they're used in computation.
        float transformedX = iny * (xy2 - wz2);
        float transformedY = iny * (1.0f - xx2 - zz2);
        float transformedZ = iny * (yz2 + wx2);
        result.x = transformedX;
        result.y = transformedY;
        result.z = transformedZ;
        return result;
    }

    /// Transforms a vector using a quaternion. Specialized for 0,0,z vectors.
    Vec3f TransformZ(float inz)
    {
        Vec3f result;
        float x2 = this.x + this.x;
        float y2 = this.y + this.y;
        float z2 = this.z + this.z;
        float xx2 = this.x * x2;
        float xz2 = this.x * z2;
        float yy2 = this.y * y2;
        float yz2 = this.y * z2;
        float wx2 = this.w * x2;
        float wy2 = this.w * y2;
        //Defer the component setting since they're used in computation.
        float transformedX = inz * (xz2 + wy2);
        float transformedY = inz * (yz2 - wx2);
        float transformedZ = inz * (1.0f - xx2 - yy2);
        result.x = transformedX;
        result.y = transformedY;
        result.z = transformedZ;
        return result;
    }

    // Multiplies two quaternions together in opposite order.
    Quaternion Concatenate(Quaternion value2)
    {
        Quaternion quaternion;
        double x = value2.x;
        double y = value2.y;
        double z = value2.z;
        double w = value2.w;
        double num4 = this.x;
        double num3 = this.y;
        double num2 = this.z;
        double num = this.w;
        double num12 = (y * num2) - (z * num3);
        double num11 = (z * num4) - (x * num2);
        double num10 = (x * num3) - (y * num4);
        double num9 = ((x * num4) + (y * num3)) + (z * num2);
        quaternion.x = ((x * num) + (num4 * w)) + num12;
        quaternion.y = ((y * num) + (num3 * w)) + num11;
        quaternion.z = ((z * num) + (num2 * w)) + num10;
        quaternion.w = (w * num) - num9;
        return quaternion;
    }

    Quaternion Concatenate(Quaternion value1, Quaternion value2)
    {
        Quaternion quaternion;
        double x = value2.x;
        double y = value2.y;
        double z = value2.z;
        double w = value2.w;
        double num4 = value1.x;
        double num3 = value1.y;
        double num2 = value1.z;
        double num = value1.w;
        double num12 = (y * num2) - (z * num3);
        double num11 = (z * num4) - (x * num2);
        double num10 = (x * num3) - (y * num4);
        double num9 = ((x * num4) + (y * num3)) + (z * num2);
        quaternion.x = ((x * num) + (num4 * w)) + num12;
        quaternion.y = ((y * num) + (num3 * w)) + num11;
        quaternion.z = ((z * num) + (num2 * w)) + num10;
        quaternion.w = (w * num) - num9;
        return quaternion;

    }

    void Concatenate(Quaternion@ value1, Quaternion value2, Quaternion &out result)
    {
        double x = value2.x;
        double y = value2.y;
        double z = value2.z;
        double w = value2.w;
        double num4 = value1.x;
        double num3 = value1.y;
        double num2 = value1.z;
        double num = value1.w;
        double num12 = (y * num2) - (z * num3);
        double num11 = (z * num4) - (x * num2);
        double num10 = (x * num3) - (y * num4);
        double num9 = ((x * num4) + (y * num3)) + (z * num2);
        result.x = ((x * num) + (num4 * w)) + num12;
        result.y = ((y * num) + (num3 * w)) + num11;
        result.z = ((z * num) + (num2 * w)) + num10;
        result.w = (w * num) - num9;
    }

    Quaternion Conjugate(Quaternion value)
    {
        Quaternion quaternion( -value.x, -value.y, -value.z, value.w);
        return quaternion;
    }

    Quaternion CreateFromAxisAngle(Vec3f axis, float angle)
    {
        float halfAngle = angle * .5f;
        float s = float(Maths::Sin(halfAngle));
        Quaternion quaternion;
        quaternion.x = axis.x * s;
        quaternion.y = axis.y * s;
        quaternion.z = axis.z * s;
        quaternion.w = float(Maths::Cos(halfAngle));
        return quaternion;
    }

    void CreateFromAxisAngle(Vec3f@ axis, float angle, Quaternion &out result)
    {
        float halfAngle = angle * .5f;
        float s = float(Maths::Sin(halfAngle));
        result.x = axis.x * s;
        result.y = axis.y * s;
        result.z = axis.z * s;
        result.w = float(Maths::Cos(halfAngle));
    }

    void CreateFromRotationMatrixR(MatrixR@ matrix, Quaternion &out result)
    {
        double num8 = (matrix.Array[0] + matrix.Array[5]) + matrix.Array[10];
        if (num8 > 0.0f)
        {
            double num = Maths::Sqrt((num8 + 1.0f));
            result.w = num * 0.5f;
            num = 0.5f / num;
            result.x = (matrix.Array[6] - matrix.Array[9]) * num;
            result.y = (matrix.Array[8] - matrix.Array[2]) * num;
            result.z = (matrix.Array[1] - matrix.Array[4]) * num;
        }
        else if ((matrix.Array[0] >= matrix.Array[5]) && (matrix.Array[0] >= matrix.Array[10]))
        {
            double num7 = Maths::Sqrt((((1.0f + matrix.Array[0]) - matrix.Array[5]) - matrix.Array[10]));
            double num4 = 0.5f / num7;
            result.x = 0.5f * num7;
            result.y = (matrix.Array[1] + matrix.Array[4]) * num4;
            result.z = (matrix.Array[2] + matrix.Array[8]) * num4;
            result.w = (matrix.Array[6] - matrix.Array[9]) * num4;
        }
        else if (matrix.Array[5] > matrix.Array[10])
        {
            double num6 = Maths::Sqrt((((1.0f + matrix.Array[5]) - matrix.Array[0]) - matrix.Array[10]));
            double num3 = 0.5f / num6;
            result.x = (matrix.Array[4] + matrix.Array[1]) * num3;
            result.y = 0.5f * num6;
            result.z = (matrix.Array[9] + matrix.Array[6]) * num3;
            result.w = (matrix.Array[8] - matrix.Array[2]) * num3;
        }
        else
        {
            double num5 = Maths::Sqrt((((1.0f + matrix.Array[10]) - matrix.Array[0]) - matrix.Array[5]));
            double num2 = 0.5f / num5;
            result.x = (matrix.Array[8] + matrix.Array[2]) * num2;
            result.y = (matrix.Array[9] + matrix.Array[6]) * num2;
            result.z = 0.5f * num5;
            result.w = (matrix.Array[1] - matrix.Array[4]) * num2;
        }

    }

    Quaternion CreateFromYawPitchRoll(double yaw, double pitch, double roll)
    {
        Quaternion q;
        CreateFromYawPitchRoll(yaw,pitch,roll,q);
        return q;
    }

    void CreateFromYawPitchRoll(double yaw, double pitch, double roll, Quaternion &out result)
    {
        double halfRoll = roll * 0.5;
        double halfPitch = pitch * 0.5;
        double halfYaw = yaw * 0.5;

        double sinRoll = Maths::Sin(halfRoll);
        double sinPitch = Maths::Sin(halfPitch);
        double sinYaw = Maths::Sin(halfYaw);

        double cosRoll = Maths::Cos(halfRoll);
        double cosPitch = Maths::Cos(halfPitch);
        double cosYaw = Maths::Cos(halfYaw);

        double cosYawCosPitch = cosYaw * cosPitch;
        double cosYawSinPitch = cosYaw * sinPitch;
        double sinYawCosPitch = sinYaw * cosPitch;
        double sinYawSinPitch = sinYaw * sinPitch;

        result.x = float(cosYawSinPitch * cosRoll + sinYawCosPitch * sinRoll);
        result.y = float(sinYawCosPitch * cosRoll - cosYawSinPitch * sinRoll);
        result.z = float(cosYawCosPitch * sinRoll - sinYawSinPitch * cosRoll);
        result.w = float(cosYawCosPitch * cosRoll + sinYawSinPitch * sinRoll);
    }

    /// Computes the angle change represented by a normalized quaternion.
    float GetAngleFromQuaternion( Quaternion q )
    {
        float qw = Maths::Abs(q.w);
        if (qw > 1)
            return 0;
        return 2 * Maths::ACos(qw);
    }

    /// Computes the axis angle representation of a normalized quaternion.
    void GetAxisAngleFromQuaternion( Quaternion q, Vec3f &out axis, float &out angle)
    {        
        float qx = q.x;
        float qy = q.y;
        float qz = q.z;
        float qw = q.w;
        if (qw < 0)
        {
            qx = -qx;
            qy = -qy;
            qz = -qz;
            qw = -qw;
        }
        if (qw > 1 - 1e-6)
        {
            axis = Vec3f(0,1,0);
            angle = 0;
        }
        else
        {
            angle = 2 * Maths::ACos(qw);
            float denominator = 1.0 / Maths::Sqrt(1.0 - qw * qw);
            axis.x = qx * denominator;
            axis.y = qy * denominator;
            axis.z = qz * denominator;
        }
    }

    /// Computes the quaternion rotation between two normalized vectors.
    void GetQuaternionBetweenNormalizedVectors( Vec3f v1, Vec3f v2, Quaternion &out q)
    {
        float dot = v1.Dot(v2);        
        //For non-normal vectors, the multiplying the axes length squared would be necessary:
        //float w = dot + (float)Maths::Sqrt(v1.LengthSquared() * v2.LengthSquared());
        if (dot < -0.9999f) //parallel, opposing direction
        {
            //If this occurs, the rotation required is ~180 degrees.
            //The problem is that we could choose any perpendicular axis for the rotation. It's not uniquely defined.
            //The solution is to pick an arbitrary perpendicular axis.
            //Project onto the plane which has the lowest component magnitude.
            //On that 2d plane, perform a 90 degree rotation.
            float absX = Maths::Abs(v1.x);
            float absY = Maths::Abs(v1.y);
            float absZ = Maths::Abs(v1.z);
            if (absX < absY && absX < absZ)
                q = Quaternion(0, -v1.z, v1.y, 0);
            else if (absY < absZ)
                q = Quaternion(-v1.z, 0, v1.x, 0);
            else
                q = Quaternion(-v1.y, v1.x, 0, 0);
        }
        else
        {
            Vec3f axis = v1.Cross(v2);
            q = Quaternion(axis.x, axis.y, axis.z, dot + 1);
        }
        q.Normalize();
    }

    //The following two functions are highly similar, but it's a bit of a brain teaser to phrase one in terms of the other.
    //Providing both simplifies things.

    /// Computes the rotation from the start orientation to the end orientation such that end = QuaternionEx.Concatenate(start, relative).
    void GetRelativeRotation( Quaternion start, Quaternion end, Quaternion &out relative)
    {
        Quaternion startInverse = Conjugate(start);
        relative.Concatenate( startInverse, end);
    }

    /// Transforms the rotation into the local space of the target basis such that rotation = QuaternionEx.Concatenate(localRotation, targetBasis)
    void GetLocalRotation( Quaternion rotation, Quaternion targetBasis, Quaternion &out localRotation)
    {
        Quaternion basisInverse = Conjugate(targetBasis);
        localRotation.Concatenate( rotation, basisInverse);
    }

    Quaternion Divide(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        double x = quaternion1.x;
        double y = quaternion1.y;
        double z = quaternion1.z;
        double w = quaternion1.w;
        double num14 = (((quaternion2.x * quaternion2.x) + (quaternion2.y * quaternion2.y)) + (quaternion2.z * quaternion2.z)) + (quaternion2.w * quaternion2.w);
        double num5 = 1.0f / num14;
        double num4 = -quaternion2.x * num5;
        double num3 = -quaternion2.y * num5;
        double num2 = -quaternion2.z * num5;
        double num = quaternion2.w * num5;
        double num13 = (y * num2) - (z * num3);
        double num12 = (z * num4) - (x * num2);
        double num11 = (x * num3) - (y * num4);
        double num10 = ((x * num4) + (y * num3)) + (z * num2);
        quaternion.x = ((x * num) + (num4 * w)) + num13;
        quaternion.y = ((y * num) + (num3 * w)) + num12;
        quaternion.z = ((z * num) + (num2 * w)) + num11;
        quaternion.w = (w * num) - num10;
        return quaternion;

    }

    void Divide(Quaternion@ quaternion1, Quaternion quaternion2, Quaternion &out result)
    {
        double x = quaternion1.x;
        double y = quaternion1.y;
        double z = quaternion1.z;
        double w = quaternion1.w;
        double num14 = (((quaternion2.x * quaternion2.x) + (quaternion2.y * quaternion2.y)) + (quaternion2.z * quaternion2.z)) + (quaternion2.w * quaternion2.w);
        double num5 = 1.0f / num14;
        double num4 = -quaternion2.x * num5;
        double num3 = -quaternion2.y * num5;
        double num2 = -quaternion2.z * num5;
        double num = quaternion2.w * num5;
        double num13 = (y * num2) - (z * num3);
        double num12 = (z * num4) - (x * num2);
        double num11 = (x * num3) - (y * num4);
        double num10 = ((x * num4) + (y * num3)) + (z * num2);
        result.x = ((x * num) + (num4 * w)) + num13;
        result.y = ((y * num) + (num3 * w)) + num12;
        result.z = ((z * num) + (num2 * w)) + num11;
        result.w = (w * num) - num10;

    }


    double Dot(Quaternion quaternion1, Quaternion quaternion2)
    {
        return ((((quaternion1.x * quaternion2.x) + (quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (quaternion1.w * quaternion2.w));
    }


    void Dot(Quaternion@ quaternion1, Quaternion quaternion2, double &out result)
    {
        result = (((quaternion1.x * quaternion2.x) + (quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (quaternion1.w * quaternion2.w);
    }

    bool opEquals(Quaternion other)
    {
        return ((((this.x == other.x) && (this.y == other.y)) && (this.z == other.z)) && (this.w == other.w));
    }

    //int GetHashCode()
    //{
    //    return (((this.x.GetHashCode() + this.y.GetHashCode()) + this.z.GetHashCode()) + this.w.GetHashCode());
    //}

    void Inverse()
    {
        double LengthSquared = this.LengthSquared();
        this.x *= -LengthSquared;
        this.y *= -LengthSquared;
        this.z *= -LengthSquared;
        this.w *=  LengthSquared;
    }

    double Length()
    {
        return Maths::Sqrt(this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w);
    }

    double LengthSquared()
    {
        return (this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w);
    }

    void Normalize(Quaternion &out toReturn)
    {
        float inverse = (1.0f / this.Length());
        toReturn.x *= inverse;
        toReturn.y *= inverse;
        toReturn.z *= inverse;
        toReturn.w *= inverse;
    }

    Quaternion Lerp(Quaternion quaternion1, Quaternion quaternion2, double amount)
    {
        double num = amount;
        double num2 = 1.0f - num;
        Quaternion quaternion = Quaternion();
        double num5 = (((quaternion1.x * quaternion2.x) + (quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (quaternion1.w * quaternion2.w);
        if (num5 >= 0.0f)
        {
            quaternion.x = (num2 * quaternion1.x) + (num * quaternion2.x);
            quaternion.y = (num2 * quaternion1.y) + (num * quaternion2.y);
            quaternion.z = (num2 * quaternion1.z) + (num * quaternion2.z);
            quaternion.w = (num2 * quaternion1.w) + (num * quaternion2.w);
        }
        else
        {
            quaternion.x = (num2 * quaternion1.x) - (num * quaternion2.x);
            quaternion.y = (num2 * quaternion1.y) - (num * quaternion2.y);
            quaternion.z = (num2 * quaternion1.z) - (num * quaternion2.z);
            quaternion.w = (num2 * quaternion1.w) - (num * quaternion2.w);
        }
        double num4 = (((quaternion.x * quaternion.x) + (quaternion.y * quaternion.y)) + (quaternion.z * quaternion.z)) + (quaternion.w * quaternion.w);
        double num3 = 1.0f / (Maths::Sqrt(num4));
        quaternion.x *= num3;
        quaternion.y *= num3;
        quaternion.z *= num3;
        quaternion.w *= num3;
        return quaternion;
    }


    void Lerp(Quaternion@ quaternion1, Quaternion quaternion2, double amount, Quaternion &out result)
    {
        double num = amount;
        double num2 = 1.0f - num;
        double num5 = (((quaternion1.x * quaternion2.x) + (quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (quaternion1.w * quaternion2.w);
        if (num5 >= 0.0f)
        {
            result.x = (num2 * quaternion1.x) + (num * quaternion2.x);
            result.y = (num2 * quaternion1.y) + (num * quaternion2.y);
            result.z = (num2 * quaternion1.z) + (num * quaternion2.z);
            result.w = (num2 * quaternion1.w) + (num * quaternion2.w);
        }
        else
        {
            result.x = (num2 * quaternion1.x) - (num * quaternion2.x);
            result.y = (num2 * quaternion1.y) - (num * quaternion2.y);
            result.z = (num2 * quaternion1.z) - (num * quaternion2.z);
            result.w = (num2 * quaternion1.w) - (num * quaternion2.w);
        }
        double num4 = (((result.x * result.x) + (result.y * result.y)) + (result.z * result.z)) + (result.w * result.w);
        double num3 = 1.0f / (Maths::Sqrt(num4));
        result.x *= num3;
        result.y *= num3;
        result.z *= num3;
        result.w *= num3;

    }


    Quaternion Slerp(Quaternion quaternion1, Quaternion quaternion2, double amount)
    {
        double num2;
        double num3;
        Quaternion quaternion;
        double num = amount;
        double num4 = (((quaternion1.x * quaternion2.x) + (quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (quaternion1.w * quaternion2.w);
        bool flag = false;
        if (num4 < 0.0f)
        {
            flag = true;
            num4 = -num4;
        }
        if (num4 > 0.999999f)
        {
            num3 = 1.0f - num;
            num2 = flag ? -num : num;
        }
        else
        {
            double num5 = Maths::ACos(num4);
            double num6 = (1.0 / Maths::Sin(num5));
            num3 = (Maths::Sin(((1.0f - num) * num5))) * num6;
            num2 = flag ? ((-Maths::Sin((num * num5))) * num6) : ((Maths::Sin((num * num5))) * num6);
        }
        quaternion.x = (num3 * quaternion1.x) + (num2 * quaternion2.x);
        quaternion.y = (num3 * quaternion1.y) + (num2 * quaternion2.y);
        quaternion.z = (num3 * quaternion1.z) + (num2 * quaternion2.z);
        quaternion.w = (num3 * quaternion1.w) + (num2 * quaternion2.w);
        return quaternion;
    }


    void Slerp(Quaternion@ quaternion1, Quaternion quaternion2, double amount, Quaternion &out result)
    {
        double num2;
        double num3;
        double num = amount;
        double num4 = (((quaternion1.x * quaternion2.x) + (quaternion1.y * quaternion2.y)) + (quaternion1.z * quaternion2.z)) + (quaternion1.w * quaternion2.w);
        bool flag = false;
        if (num4 < 0.0f)
        {
            flag = true;
            num4 = -num4;
        }
        if (num4 > 0.999999f)
        {
            num3 = 1.0f - num;
            num2 = flag ? -num : num;
        }
        else
        {
            double num5 = Maths::ACos(num4);
            double num6 = (1.0 / Maths::Sin(num5));
            num3 = (Maths::Sin(((1.0f - num) * num5))) * num6;
            num2 = flag ? ((-Maths::Sin((num * num5))) * num6) : ((Maths::Sin((num * num5))) * num6);
        }
        result.x = (num3 * quaternion1.x) + (num2 * quaternion2.x);
        result.y = (num3 * quaternion1.y) + (num2 * quaternion2.y);
        result.z = (num3 * quaternion1.z) + (num2 * quaternion2.z);
        result.w = (num3 * quaternion1.w) + (num2 * quaternion2.w);
    }


    Quaternion Subtract(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        quaternion.x = quaternion1.x - quaternion2.x;
        quaternion.y = quaternion1.y - quaternion2.y;
        quaternion.z = quaternion1.z - quaternion2.z;
        quaternion.w = quaternion1.w - quaternion2.w;
        return quaternion;
    }


    void Subtract(Quaternion@ quaternion1, Quaternion quaternion2, Quaternion &out result)
    {
        result.x = quaternion1.x - quaternion2.x;
        result.y = quaternion1.y - quaternion2.y;
        result.z = quaternion1.z - quaternion2.z;
        result.w = quaternion1.w - quaternion2.w;
    }


    Quaternion Multiply(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        double x = quaternion1.x;
        double y = quaternion1.y;
        double z = quaternion1.z;
        double w = quaternion1.w;
        double num4 = quaternion2.x;
        double num3 = quaternion2.y;
        double num2 = quaternion2.z;
        double num = quaternion2.w;
        double num12 = (y * num2) - (z * num3);
        double num11 = (z * num4) - (x * num2);
        double num10 = (x * num3) - (y * num4);
        double num9 = ((x * num4) + (y * num3)) + (z * num2);
        quaternion.x = ((x * num) + (num4 * w)) + num12;
        quaternion.y = ((y * num) + (num3 * w)) + num11;
        quaternion.z = ((z * num) + (num2 * w)) + num10;
        quaternion.w = (w * num) - num9;
        return quaternion;
    }


    Quaternion Multiply(Quaternion quaternion1, double scaleFactor)
    {
        Quaternion quaternion;
        quaternion.x = quaternion1.x * scaleFactor;
        quaternion.y = quaternion1.y * scaleFactor;
        quaternion.z = quaternion1.z * scaleFactor;
        quaternion.w = quaternion1.w * scaleFactor;
        return quaternion;
    }


    void Multiply(Quaternion@ quaternion1, double scaleFactor, Quaternion &out result)
    {
        result.x = quaternion1.x * scaleFactor;
        result.y = quaternion1.y * scaleFactor;
        result.z = quaternion1.z * scaleFactor;
        result.w = quaternion1.w * scaleFactor;
    }


    void Multiply(Quaternion@ quaternion1, Quaternion quaternion2, Quaternion &out result)
    {
        double x = quaternion1.x;
        double y = quaternion1.y;
        double z = quaternion1.z;
        double w = quaternion1.w;
        double num4 = quaternion2.x;
        double num3 = quaternion2.y;
        double num2 = quaternion2.z;
        double num = quaternion2.w;
        double num12 = (y * num2) - (z * num3);
        double num11 = (z * num4) - (x * num2);
        double num10 = (x * num3) - (y * num4);
        double num9 = ((x * num4) + (y * num3)) + (z * num2);
        result.x = ((x * num) + (num4 * w)) + num12;
        result.y = ((y * num) + (num3 * w)) + num11;
        result.z = ((z * num) + (num2 * w)) + num10;
        result.w = (w * num) - num9;
    }


    Quaternion Negate(Quaternion quaternion)
    {
        Quaternion quaternion2;
        quaternion2.x = -quaternion.x;
        quaternion2.y = -quaternion.y;
        quaternion2.z = -quaternion.z;
        quaternion2.w = -quaternion.w;
        return quaternion2;
    }


    void Negate(Quaternion@ quaternion, Quaternion &out result)
    {
        result.x = -quaternion.x;
        result.y = -quaternion.y;
        result.z = -quaternion.z;
        result.w = -quaternion.w;
    }


    void Normalize()
    {
        double num2 = (((this.x * this.x) + (this.y * this.y)) + (this.z * this.z)) + (this.w * this.w);
        double num = 1.0f / (Maths::Sqrt(num2));
        this.x *= num;
        this.y *= num;
        this.z *= num;
        this.w *= num;
    }

    Quaternion Normalize(Quaternion quaternion)
    {
        Quaternion quaternion2;
        double num2 = (((quaternion.x * quaternion.x) + (quaternion.y * quaternion.y)) + (quaternion.z * quaternion.z)) + (quaternion.w * quaternion.w);
        double num = 1.0f / (Maths::Sqrt(num2));
        quaternion2.x = quaternion.x * num;
        quaternion2.y = quaternion.y * num;
        quaternion2.z = quaternion.z * num;
        quaternion2.w = quaternion.w * num;
        return quaternion2;
    }


    void Normalize(Quaternion@ quaternion, Quaternion &out result)
    {
        double num2 = (((quaternion.x * quaternion.x) + (quaternion.y * quaternion.y)) + (quaternion.z * quaternion.z)) + (quaternion.w * quaternion.w);
        double num = 1.0f / (Maths::Sqrt(num2));
        result.x = quaternion.x * num;
        result.y = quaternion.y * num;
        result.z = quaternion.z * num;
        result.w = quaternion.w * num;
    }


    Quaternion opAdd(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        quaternion.x = quaternion1.x + quaternion2.x;
        quaternion.y = quaternion1.y + quaternion2.y;
        quaternion.z = quaternion1.z + quaternion2.z;
        quaternion.w = quaternion1.w + quaternion2.w;
        return quaternion;
    }


    Quaternion opDiv(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        double x = quaternion1.x;
        double y = quaternion1.y;
        double z = quaternion1.z;
        double w = quaternion1.w;
        double num14 = (((quaternion2.x * quaternion2.x) + (quaternion2.y * quaternion2.y)) + (quaternion2.z * quaternion2.z)) + (quaternion2.w * quaternion2.w);
        double num5 = 1.0f / num14;
        double num4 = -quaternion2.x * num5;
        double num3 = -quaternion2.y * num5;
        double num2 = -quaternion2.z * num5;
        double num = quaternion2.w * num5;
        double num13 = (y * num2) - (z * num3);
        double num12 = (z * num4) - (x * num2);
        double num11 = (x * num3) - (y * num4);
        double num10 = ((x * num4) + (y * num3)) + (z * num2);
        quaternion.x = ((x * num) + (num4 * w)) + num13;
        quaternion.y = ((y * num) + (num3 * w)) + num12;
        quaternion.z = ((z * num) + (num2 * w)) + num11;
        quaternion.w = (w * num) - num10;
        return quaternion;
    }

    bool opEquals(Quaternion quaternion1, Quaternion quaternion2)
    {
        return ((((quaternion1.x == quaternion2.x) && (quaternion1.y == quaternion2.y)) && (quaternion1.z == quaternion2.z)) && (quaternion1.w == quaternion2.w));
    }


    bool opNotEquals(Quaternion quaternion1, Quaternion quaternion2)
    {
        if (((quaternion1.x == quaternion2.x) && (quaternion1.y == quaternion2.y)) && (quaternion1.z == quaternion2.z))
        {
            return (quaternion1.w != quaternion2.w);
        }
        return true;
    }

    Quaternion opMul(Quaternion quaternion2)
    {
        double x = this.x;
        double y = this.y;
        double z = this.z;
        double w = this.w;
        double num4 = quaternion2.x;
        double num3 = quaternion2.y;
        double num2 = quaternion2.z;
        double num = quaternion2.w;
        double num12 = (y * num2) - (z * num3);
        double num11 = (z * num4) - (x * num2);
        double num10 = (x * num3) - (y * num4);
        double num9 = ((x * num4) + (y * num3)) + (z * num2);
        Quaternion q;
        q.x = ((x * num) + (num4 * w)) + num12;
        q.y = ((y * num) + (num3 * w)) + num11;
        q.z = ((z * num) + (num2 * w)) + num10;
        q.w = (w * num) - num9;
        return q;
    }

    Quaternion opMul(double scaleFactor)
    {
        Quaternion q;
        q.x = this.x * scaleFactor;
        q.y = this.y * scaleFactor;
        q.z = this.z * scaleFactor;
        q.w = this.w * scaleFactor;
        return q;
    }

    Quaternion opAdd(Quaternion quaternion2)
    {
        Quaternion q;
        q.x = this.x + quaternion2.x;
        q.y = this.y + quaternion2.y;
        q.z = this.z + quaternion2.z;
        q.w = this.w + quaternion2.w;
        return q;
    }

    Quaternion Add(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        quaternion.x = quaternion1.x + quaternion2.x;
        quaternion.y = quaternion1.y + quaternion2.y;
        quaternion.z = quaternion1.z + quaternion2.z;
        quaternion.w = quaternion1.w + quaternion2.w;
        return quaternion;
    }

    void Add(Quaternion@ quaternion1, Quaternion@ quaternion2, Quaternion &out result)
    {
        result.x = quaternion1.x + quaternion2.x;
        result.y = quaternion1.y + quaternion2.y;
        result.z = quaternion1.z + quaternion2.z;
        result.w = quaternion1.w + quaternion2.w;
    }

    Quaternion opSub(Quaternion quaternion2)
    {
        Quaternion q;
        q.x = this.x - quaternion2.x;
        q.y = this.y - quaternion2.y;
        q.z = this.z - quaternion2.z;
        q.w = this.w - quaternion2.w;
        return q;
    }

    Quaternion Sub(Quaternion quaternion1, Quaternion quaternion2)
    {
        Quaternion quaternion;
        quaternion.x = quaternion1.x - quaternion2.x;
        quaternion.y = quaternion1.y - quaternion2.y;
        quaternion.z = quaternion1.z - quaternion2.z;
        quaternion.w = quaternion1.w - quaternion2.w;
        return quaternion;
    }

    //Quaternion opNeg(Quaternion quaternion)
    //{
    //    Quaternion quaternion2;
    //    quaternion2.x = -quaternion.x;
    //    quaternion2.y = -quaternion.y;
    //    quaternion2.z = -quaternion.z;
    //    quaternion2.w =  quaternion.w;
    //    return quaternion2;
    //}

//    string ToString()
//    {
//        System.Text.StringBuilder sb = System.Text.StringBuilder(32);
//        sb.Append("{X:");
//        sb.Append(this.x);
//        sb.Append(" Y:");
//        sb.Append(this.y);
//        sb.Append(" Z:");
//        sb.Append(this.z);
//        sb.Append(" W:");
//        sb.Append(this.w);
//        sb.Append("}");
//        return sb.ToString();
//    }

    void Rotate(Vec3f angularVelocity)
    {
        float angle = angularVelocity.Length();

        if (angle <= 0.00001f)
            return;

        Vec3f axis = angularVelocity;
        axis.Normalize();

        float halfAngle = angle * 0.5f;

        Quaternion delta(
            axis.x * Maths::Sin(halfAngle),
            axis.y * Maths::Sin(halfAngle),
            axis.z * Maths::Sin(halfAngle),
            Maths::Cos(halfAngle)
        );

        this = delta * this;
        Normalize();
    }

    MatrixR ToMatrixR()
    {
        // source -> http://content.gpwiki.org/index.php/OpenGL:Tutorials:Using_Quaternions_to_represent_rotation#Quaternion_to_MatrixR
        double x2 = this.x * this.x;
        double y2 = this.y * this.y;
        double z2 = this.z * this.z;
        double xy = this.x * this.y;
        double xz = this.x * this.z;
        double yz = this.y * this.z;
        double wx = this.w * this.x;
        double wy = this.w * this.y;
        double wz = this.w * this.z;

        // This calculation would be a lot more complicated for non-unit length quaternions
        // Note: The constructor of MatrixR4 expects the MatrixR in column-major format like expected by
        //   OpenGL
        MatrixR matrix;
        matrix.Array[0] = 1.0f - 2.0f * (y2 + z2);
        matrix.Array[1] = 2.0f * (xy - wz);
        matrix.Array[2] = 2.0f * (xz + wy);
        matrix.Array[3] = 0.0f;

        matrix.Array[4] = 2.0f * (xy + wz);
        matrix.Array[5] = 1.0f - 2.0f * (x2 + z2);
        matrix.Array[6] = 2.0f * (yz - wx);
        matrix.Array[7] = 0.0f;

        matrix.Array[8] = 2.0f * (xz - wy);
        matrix.Array[9] = 2.0f * (yz + wx);
        matrix.Array[10] = 1.0f - 2.0f * (x2 + y2);
        matrix.Array[11] = 0.0f;

        matrix.Array[12] = 2.0f * (xz - wy);
        matrix.Array[13] = 2.0f * (yz + wx);
        matrix.Array[14] = 1.0f - 2.0f * (x2 + y2);
        matrix.Array[15] = 0.0f;

        //return MatrixR4( 1.0f - 2.0f * (y2 + z2), 2.0f * (xy - wz), 2.0f * (xz + wy), 0.0f,
        //      2.0f * (xy + wz), 1.0f - 2.0f * (x2 + z2), 2.0f * (yz - wx), 0.0f,
        //      2.0f * (xz - wy), 2.0f * (yz + wx), 1.0f - 2.0f * (x2 + y2), 0.0f,
        //      0.0f, 0.0f, 0.0f, 1.0f)
        //  }
        return matrix;
    }

    Vec3f Xyz
    {
        get
        {
            return Vec3f(x, y, z);
        }

        set
        {
            x = value.x;
            y = value.y;
            z = value.z;
        }
    }
}


shared Quaternion CreateFromRotationMatrixR(MatrixR matrix)
{
    double num8 = (matrix.Array[0] + matrix.Array[5]) + matrix.Array[10];
    Quaternion quaternion = Quaternion();
    if (num8 > 0.0f)
    {
        double num = Maths::Sqrt((num8 + 1.0f));
        quaternion.w = num * 0.5f;
        num = 0.5f / num;
        quaternion.x = (matrix.Array[6] - matrix.Array[9]) * num;
        quaternion.y = (matrix.Array[8] - matrix.Array[2]) * num;
        quaternion.z = (matrix.Array[1] - matrix.Array[4]) * num;
        return quaternion;
    }
    if ((matrix.Array[0] >= matrix.Array[5]) && (matrix.Array[0] >= matrix.Array[10]))
    {
        double num7 = Maths::Sqrt((((1.0f + matrix.Array[0]) - matrix.Array[5]) - matrix.Array[10]));
        double num4 = 0.5f / num7;
        quaternion.x = 0.5f * num7;
        quaternion.y = (matrix.Array[1] + matrix.Array[4]) * num4;
        quaternion.z = (matrix.Array[2] + matrix.Array[8]) * num4;
        quaternion.w = (matrix.Array[6] - matrix.Array[9]) * num4;
        return quaternion;
    }
    if (matrix.Array[5] > matrix.Array[10])
    {
        double num6 = Maths::Sqrt((((1.0f + matrix.Array[5]) - matrix.Array[0]) - matrix.Array[10]));
        double num3 = 0.5f / num6;
        quaternion.x = (matrix.Array[4] + matrix.Array[1]) * num3;
        quaternion.y = 0.5f * num6;
        quaternion.z = (matrix.Array[9] + matrix.Array[6]) * num3;
        quaternion.w = (matrix.Array[8] - matrix.Array[2]) * num3;
        return quaternion;
    }
    double num5 = Maths::Sqrt((((1.0f + matrix.Array[10]) - matrix.Array[0]) - matrix.Array[5]));
    double num2 = 0.5f / num5;
    quaternion.x = (matrix.Array[8] + matrix.Array[2]) * num2;
    quaternion.y = (matrix.Array[9] + matrix.Array[6]) * num2;
    quaternion.z = 0.5f * num5;
    quaternion.w = (matrix.Array[1] - matrix.Array[4]) * num2;

    return quaternion;

}

shared void Transform(Vec3f v, Quaternion rotation, Vec3f &out result)
{
    //This operation is an optimized-down version of v' = q * v * q^-1.
    //The expanded form would be to treat v as an 'axis only' quaternion
    //and perform standard quaternion multiplication.  Assuming q is normalized,
    //q^-1 can be replaced by a conjugation.
    float x2 = rotation.x + rotation.x;
    float y2 = rotation.y + rotation.y;
    float z2 = rotation.z + rotation.z;
    float xx2 = rotation.x * x2;
    float xy2 = rotation.x * y2;
    float xz2 = rotation.x * z2;
    float yy2 = rotation.y * y2;
    float yz2 = rotation.y * z2;
    float zz2 = rotation.z * z2;
    float wx2 = rotation.w * x2;
    float wy2 = rotation.w * y2;
    float wz2 = rotation.w * z2;
    result.x = v.x * (1.0f - yy2 - zz2) + v.y * (xy2 - wz2) + v.z * (xz2 + wy2);
    result.y = v.x * (xy2 + wz2) + v.y * (1.0f - xx2 - zz2) + v.z * (yz2 - wx2);
    result.z = v.x * (xz2 - wy2) + v.y * (yz2 + wx2) + v.z * (1.0f - xx2 - yy2);
} 

shared Quaternion QuaternionFromEuler(Vec3f euler)
{
    euler.x *= 0.5f;
    euler.y *= 0.5f;
    euler.z *= 0.5f;

    float c1 = Maths::Cos(euler.y);
    float s1 = Maths::Sin(euler.y);
    float c2 = Maths::Cos(euler.z);
    float s2 = Maths::Sin(euler.z);
    float c3 = Maths::Cos(euler.x);
    float s3 = Maths::Sin(euler.x);
    float c1c2 = c1*c2;
    float s1s2 = s1*s2;
    float s1c2 = s1*c2;
    float c1s2 = c1*s2;

    Quaternion q;
    q.w = c1c2*c3 - s1s2*s3;
    q.x = c1c2*s3 + s1s2*c3;
    q.y = s1c2*c3 + c1s2*s3;
    q.z = c1s2*c3 - s1c2*s3;
    return q;
}