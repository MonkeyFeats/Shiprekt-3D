#include "MathsHelper.as"
#include "Matrix.as"

shared class Vec3f
{
    double x;
    double y;
    double z;

    Vec3f()
    {
        this.x = 0;
        this.y = 0;
        this.z = 0;
    }
   
    Vec3f(double x, double y, double z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    Vec3f(double value)
    {
        this.x = value;
        this.y = value;
        this.z = value;
    }

    Vec3f(Vec2f value, double z)
    {
        this.x = value.x;
        this.y = value.y;
        this.z = z;
    }

    /// my shid ///

    Vec2f xz() {return Vec2f(x,z);}
    Vec2f zx() {return Vec2f(z,x);}
    Vec2f xy() {return Vec2f(x,y);}
    Vec2f yz() {return Vec2f(y,z);}

    Vec3f set(double &in InX, double &in InY, double &in InZ) { x = InX; y = InY; z = InZ; return Vec3f(x, y, z);}
    Vec3f set(Vec3f &in In) { x = In.x; y = In.y; z = In.z; return Vec3f(x, y, z);}

    Vec3f xzRotateBy2(const float &in amount, Vec3f around = Vec3f())
    {
        Vec2f vec = Vec2f(this.x, this.z).RotateBy(amount, around.xz());   
        return Vec3f(vec.x,y,vec.y);
    }

    Vec3f yzRotateBy2(const float &in amount)
    {
        Vec2f vec = Vec2f(this.y, this.z).RotateBy(amount);
        return Vec3f(x,vec.x,vec.y);
    }

    double AngleWithDegrees(Vec3f other)
    {
        return AngleWithRadians(other) * 180.0f / Maths::Pi;
    }

    double AngleWithRadians(Vec3f other)
    {
        Vec3f vec1 = this; 
        vec1.Normalize();

        Vec3f vec2 = other; 
        vec2.Normalize();

        return Maths::ACos(vec1.DotProd(vec2));
    }

//    broken
//    Vec3f RotateTowards(Vec3f target, float maxRadiansDelta, float maxMagnitudeDelta)
//    {
//        // replicates Unity Vector3.RotateTowards
//        Vec3f current = this;
//        Vec3f targetVec = target;
//
//        float delta =  current.AngleWithRadians(target);
//        float magDiff = target.Length() - current.Length();
//        float sign = MathsHelper::Sign(magDiff);
//        float maxMagDelta = Maths::Min(maxMagnitudeDelta, Maths::Abs(magDiff));
//        float diff = Maths::Min(1.0f, maxRadiansDelta / delta);
//        return Lerp(current.Normalize(), targetVec.Normalize(), diff) * (current.Length() + maxMagDelta*sign);
//    }

    Vec3f rotatedXZBy(f64 degrees)
    {
        degrees /= 90;
        f64 cs = Maths::Cos(degrees);
        f64 sn = Maths::Sin(degrees);
        return Vec3f((x*cs - z*sn), y, (x*sn + z*cs));
    }

    void rotateXZBy(f64 degrees, const Vec3f &in center=Vec3f())
    {
        degrees *= Maths::Pi / 180.0f;
        f64 cs = Maths::Cos(degrees);
        f64 sn = Maths::Sin(degrees);
        x -= center.x;
        z -= center.z;
        set((x*cs - z*sn), y, (x*sn + z*cs));
        x += center.x;
        z += center.z;
    }

    Vec3f rotatedXZBy(f64 degrees, const Vec3f &in center=Vec3f())
    {
        Vec3f result = this;
        degrees *= Maths::Pi / 180.0f;
        f64 cs = Maths::Cos(degrees);
        f64 sn = Maths::Sin(degrees);
        result.x -= center.x;
        result.z -= center.z;
        set((x*cs - z*sn), y, (x*sn + z*cs));
        result.x += center.x;
        result.z += center.z;

        return result;
    }

    void rotateXYBy(f64 degrees, const Vec3f &in center=Vec3f())
    {
        degrees *= Maths::Pi / 180.0f;
        f64 cs = Maths::Cos(degrees);
        f64 sn = Maths::Sin(degrees);
        x -= center.x;
        y -= center.y;
        set((x*cs - y*sn), (x*sn + y*cs), z);
        x += center.x;
        y += center.y;
    }

    void rotateYZBy(f64 degrees, const Vec3f &in center=Vec3f())
    {
        degrees *= Maths::Pi / 180.0f;
        f64 cs = Maths::Cos(degrees);
        f64 sn = Maths::Sin(degrees);
        z -= center.z;
        y -= center.y;
        set(x, (y*cs - z*sn), (y*sn + z*cs));
        z += center.z;
        y += center.y;
    }

    void xzRotateBy(const float &in amount)
    {
        Vec2f vec = Vec2f(this.x, this.z).RotateBy(amount);   
        this.x = vec.x;
        this.z = vec.y;
    }

    void xyRotateBy(const float &in amount)
    {
        Vec2f vec = Vec2f(this.x, this.y).RotateBy(amount);   
        this.x = vec.x;
        this.y = vec.y;
    }

    void yzRotateBy(const float &in amount)
    {
        Vec2f vec = Vec2f(this.y, this.z).RotateBy(amount);   
        this.y = vec.x;
        this.z = vec.y;
    }    

    Vec3f Barycentric(Vec3f value1, Vec3f value2, Vec3f value3, double amount1, double amount2) const
    {
        return Vec3f(
            MathsHelper::Barycentric(value1.x, value2.x, value3.x, amount1, amount2),
            MathsHelper::Barycentric(value1.y, value2.y, value3.y, amount1, amount2),
            MathsHelper::Barycentric(value1.z, value2.z, value3.z, amount1, amount2));
    }

    Vec3f CatmullRom(Vec3f value1, Vec3f value2, Vec3f value3, Vec3f value4, double amount) const
    {
        return Vec3f(
            MathsHelper::CatmullRom(value1.x, value2.x, value3.x, value4.x, amount),
            MathsHelper::CatmullRom(value1.y, value2.y, value3.y, value4.y, amount),
            MathsHelper::CatmullRom(value1.z, value2.z, value3.z, value4.z, amount));
    }

    Vec3f Clamp(Vec3f min, Vec3f max) const
    {
        return Vec3f(
            Maths::Clamp(this.x, min.x, max.x),
            Maths::Clamp(this.y, min.y, max.y),
            Maths::Clamp(this.z, min.z, max.z));
    }

    f32 Dot(Vec3f vector2)
    {
        return this.x * vector2.x + this.y * vector2.y + this.z * vector2.z;
    }  

    Vec3f Cross(Vec3f vector2) const
    {
        return Vec3f(this.y * vector2.z - vector2.y * this.z,
                   -(this.x * vector2.z - vector2.x * this.z),
                     this.x * vector2.y - vector2.x * this.y);
    }

    void Cross(Vec3f vector1, Vec3f vector2)
    {
        this = Vec3f(vector1.y * vector2.z - vector2.y * vector1.z,
                   -(vector1.x * vector2.z - vector2.x * vector1.z),
                     vector1.x * vector2.y - vector2.x * vector1.y);
    }

    double DotProd(const Vec3f v2) const {return (x * v2.x  + y * v2.y + z * v2.z);}  
    Vec3f CrossProd(const Vec3f v2) const {return Vec3f(y * v2.z - z * v2.y, z * v2.x - x * v2.z, x * v2.y - y * v2.x);}

    Vec3f Divide(Vec3f value1, Vec3f value2)
    {
        value1.x /= value2.x;
        value1.y /= value2.y;
        value1.z /= value2.z;
        return value1;
    }

    Vec3f Divide(Vec3f value1, double value2)
    {
        double factor = 1 / value2;
        value1.x *= factor;
        value1.y *= factor;
        value1.z *= factor;
        return value1;
    }      

    bool Equals(Vec3f other)
    {
        return (this is other);
    }

    int GetHashCode() //wtf is this
    {
        return int(this.x + this.y + this.z);
    }

    Vec3f Hermite(Vec3f value1, Vec3f tangent1, Vec3f value2, Vec3f tangent2, double amount)
    {
        Vec3f result = Vec3f();
        Hermite(value1, tangent1, value2, tangent2, amount, result);
        return result;
    }

    void Hermite(Vec3f value1, Vec3f tangent1, Vec3f value2, Vec3f tangent2, double amount, Vec3f &out result)
    {
        result.x = MathsHelper::Hermite(value1.x, tangent1.x, value2.x, tangent2.x, amount);
        result.y = MathsHelper::Hermite(value1.y, tangent1.y, value2.y, tangent2.y, amount);
        result.z = MathsHelper::Hermite(value1.z, tangent1.z, value2.z, tangent2.z, amount);
    }

    double Length() const
    {
        return Maths::Sqrt(x*x + y*y + z*z);
    }
    double Length(Vec3f other) const 
    {
        return Maths::Sqrt(this.LengthSquared(other));
    }

    double LengthSquared() const
    {
        return (x*x + y*y + z*z);
    }
    double LengthSquared(Vec3f other) const
    {
        return  (this.x - other.x) * (this.x - other.x) +
                (this.y - other.y) * (this.y - other.y) +
                (this.z - other.z) * (this.z - other.z);
    } 

    bool isBetweenPoints(const Vec3f &in begin, const Vec3f &in end) const
    {
        const float f = (end - begin).LengthSquared();
        return (this-begin).LengthSquared() <= f && (this-end).LengthSquared() <= f;
    } 

    Vec3f Lerp(Vec3f value1, Vec3f value2, double amount)
    {
        return Vec3f(
            Maths::Lerp(value1.x, value2.x, amount),
            Maths::Lerp(value1.y, value2.y, amount),
            Maths::Lerp(value1.z, value2.z, amount));
    }

    void Lerp(Vec3f value1, Vec3f value2, double amount, Vec3f &out result)
    {
        result = Vec3f(
            Maths::Lerp(value1.x, value2.x, amount),
            Maths::Lerp(value1.y, value2.y, amount),
            Maths::Lerp(value1.z, value2.z, amount));
    }

    Vec3f Lerp(Vec3f desired, float t)
    {
        return Vec3f((((1 - t) * this.x) + (t * desired.x)), (((1 - t) * this.y) + (t * desired.y)), (((1 - t) * this.z) + (t * desired.z)));
    }
    

    Vec3f Max(Vec3f value2)
    {
        return Vec3f(
            Maths::Max(this.x, value2.x),
            Maths::Max(this.y, value2.y),
            Maths::Max(this.z, value2.z));
    }    

    Vec3f Min( Vec3f value2)
    {
        return Vec3f(
            Maths::Min(this.x, value2.x),
            Maths::Min(this.y, value2.y),
            Maths::Min(this.z, value2.z));
    }

    Vec3f Multiply(Vec3f value1, Vec3f value2)
    {
        value1.x *= value2.x;
        value1.y *= value2.y;
        value1.z *= value2.z;
        return value1;
    }

    Vec3f Multiply(Vec3f value1, double scaleFactor)
    {
        value1.x *= scaleFactor;
        value1.y *= scaleFactor;
        value1.z *= scaleFactor;
        return value1;
    }

    Vec3f Normalize()
    {
        if (this.Length() == 0) return Vec3f();
        return this * (1.0f / this.Length());
    }

    Vec3f Normalized()
    {
        if (this.Length() == 0) return Vec3f();
        return this * (1.0f / this.Length());
    }

    Vec3f Reflect(Vec3f normal)
    {
    	Vec3f reflectedVector;
    	double dotProduct = ((this.x * normal.x) + (this.y * normal.y)) + (this.z * normal.z);
    	reflectedVector.x = this.x - (2.0f * normal.x) * dotProduct;
    	reflectedVector.y = this.y - (2.0f * normal.y) * dotProduct;
    	reflectedVector.z = this.z - (2.0f * normal.z) * dotProduct;

    	return reflectedVector;
    }
	
    Vec3f SmoothStep(Vec3f value1, Vec3f value2, double amount)
    {
        return Vec3f(
            MathsHelper::SmoothStep(value1.x, value2.x, amount),
            MathsHelper::SmoothStep(value1.y, value2.y, amount),
            MathsHelper::SmoothStep(value1.z, value2.z, amount));
    }

    Vec3f Subtract(Vec3f value1, Vec3f value2)
    {
        value1.x -= value2.x;
        value1.y -= value2.y;
        value1.z -= value2.z;
        return value1;
    }

    void Print()
    {
        print("x: "+x+"; y: "+y+"; z: "+z);
    }

    string toString()
    {
        return "("+x+", "+y+", "+z+")";
    }
    string toStringInt()
    {
        return int(x)+", "+int(y)+", "+int(z);
    }


//    Vec3f Transform(Vec3f position, MatrixR matrix)
//    {
//        Transform(position, matrix, position);
//        return position;
//    }
//
//    void Transform(Vec3f position, MatrixR matrix, Vec3f &out result)
//    {
//        result = Vec3f((position.x * matrix.M11) + (position.y * matrix.M21) + (position.z * matrix.M31) + matrix.M41,
//                             (position.x * matrix.M12) + (position.y * matrix.M22) + (position.z * matrix.M32) + matrix.M42,
//                             (position.x * matrix.M13) + (position.y * matrix.M23) + (position.z * matrix.M33) + matrix.M43);
//    }
//
//    void Transform(Vec3f[] sourceArray, MatrixR matrix, Vec3f[] destinationArray)
//    {
//        //Debug.Assert(destinationArray.Length >= sourceArray.Length, "The destination array is smaller than the source array.");
//        // TODO: Are there options on some platforms to implement a vectorized version of this?
//
//        for (int i = 0; i < sourceArray.size(); i++)
//        {
//            Vec3f position = sourceArray[i];                
//            destinationArray[i] =
//                Vec3f( (position.x*matrix.M11) + (position.y*matrix.M21) + (position.z*matrix.M31) + matrix.M41,
//                       (position.x*matrix.M12) + (position.y*matrix.M22) + (position.z*matrix.M32) + matrix.M42,
//                       (position.x*matrix.M13) + (position.y*matrix.M23) + (position.z*matrix.M33) + matrix.M43);
//        }
//    }

//  // Transforms a vector by a quaternion rotation.
//    Vec3f Transform(Vec3f vec, Quaternion quat)
//    {
//        Vec3f result;
//        Transform(vec, quat, result);
//        return result;
//    }
//
//    // Transforms a vector by a quaternion rotation.    
//    void Transform(Vec3f vec, Quaternion quat, Vec3f &out result)
//    {
//		// This has not been tested
//		// TODO:  This could probably be unrolled so will look into it later
//		MatrixR matrix = quat.ToMatrixR();
//		Transform(vec, matrix, result);
//    }
//
//    Vec3f TransformNormal(Vec3f normal, MatrixR matrix)
//    {
//        TransformNormal(normal, matrix, normal);
//        return normal;
//    }
//
//    void TransformNormal(Vec3f normal, MatrixR matrix, Vec3f &out result)
//    {
//        result = Vec3f((normal.x * matrix.M11) + (normal.y * matrix.M21) + (normal.z * matrix.M31),
//                             (normal.x * matrix.M12) + (normal.y * matrix.M22) + (normal.z * matrix.M32),
//                             (normal.x * matrix.M13) + (normal.y * matrix.M23) + (normal.z * matrix.M33));
//    }

    void opAssign (const Vec3f &in In) { x = In.x; y = In.y; z = In.z; }
    Vec3f opAdd (const Vec3f &in In) const { return Vec3f(x + In.x, y + In.y, z + In.z); }    
    Vec3f opAdd (float In) const { return Vec3f(x + In, y + In, z + In); }
    void opAddAssign (const Vec3f &in In) { x += In.x; y += In.y; z += In.z; }
    void opAddAssign (float In) { x += In; y += In; z += In; }
    Vec3f opSub (const Vec3f &in In) const { return Vec3f(x - In.x, y - In.y, z - In.z); }    
    Vec3f opSub (float In) const { return Vec3f(x - In, y - In, z - In); }
    void opSubAssign (const Vec3f &in In) { x -= In.x; y -= In.y; z -= In.z; }
    Vec3f opMul (const Vec3f &in In) { return Vec3f(x * In.x, y * In.y, z * In.z); }
    Vec3f opMul (float In) const { return Vec3f(x * In, y * In, z * In); }
    void opMulAssign (float In) { x *= In; y *= In; z *= In; }
    Vec3f opNeg() const { return Vec3f(-x, -y, -z); }
    Vec3f opDiv (const Vec3f &in In) const { return Vec3f(x / In.x, y / In.y, z / In.z); }
    Vec3f opDiv (float In) { return Vec3f(x / In, y / In, z / In); }
    void opDivAssign (float In) { x /= In; y /= In; z /= In; }
    bool opEquals (const Vec3f&in In) const { return x == In.x && y == In.y && z == In.z; }
}

shared Vec3f V2toV3(const Vec2f &in In, float height = 0.0f) {return Vec3f(In.x, height, In.y);}
shared Vec2f V3toV2(const Vec3f &in In) { return Vec2f(In.x, In.z); }

float[] Matrix_Multiply(const float[]&in first, const float[]&in second) // inbuilt function is retarded
{
    float[] new(16);
    for(int i = 0; i < 4; i++)
        for(int j = 0; j < 4; j++)
            for(int k = 0; k < 4; k++)
                new[i+j*4] += first[i+k*4] * second[j+k*4];
    return new;
}

shared double Dot(Vec3f vector1, Vec3f vector2)
{
    return vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z;
}

shared void Dot(Vec3f vector1, Vec3f vector2, double &out result)
{
    result = vector1.x * vector2.x + vector1.y * vector2.y + vector1.z * vector2.z;
}

shared Vec3f Cross(Vec3f vector1, Vec3f vector2)
{
    Vec3f result = Vec3f(vector1.y * vector2.z - vector2.y * vector1.z,
                         -(vector1.x * vector2.z - vector2.x * vector1.z),
                         vector1.x * vector2.y - vector2.x * vector1.y);
    return result;
}

shared Vec3f CrossProd(const Vec3f&in v1, const Vec3f&in v2)
{
    return Vec3f(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x);
}

shared void Multiply(Vec3f value1, double scaleFactor, Vec3f &out result)
{
    result.x = value1.x * scaleFactor;
    result.y = value1.y * scaleFactor;
    result.z = value1.z * scaleFactor;
}

shared void Multiply(Vec3f value1, Vec3f value2, Vec3f &out result)
{
    result.x = value1.x * value2.x;
    result.y = value1.y * value2.y;
    result.z = value1.z * value2.z;
}

shared void Normalize(Vec3f value, Vec3f &out result)
{
    double factor = value.Length();
    factor = 1.0f / factor;
    result.x = value.x * factor;
    result.y = value.y * factor;
    result.z = value.z * factor;
}

shared Vec3f Normalize(Vec3f value)
{
    double factor = value.Length();
    factor = 1.0f / factor;
    Vec3f result;
    result.x = value.x * factor;
    result.y = value.y * factor;
    result.z = value.z * factor;
    return result;
}

shared Vec3f Reflect(Vec3f vector, Vec3f normal)
{
    double dotProduct = ((vector.x * normal.x) + (vector.y * normal.y)) + (vector.z * normal.z);
    Vec3f result;
    result.x = vector.x - (2.0f * normal.x) * dotProduct;
    result.y = vector.y - (2.0f * normal.y) * dotProduct;
    result.z = vector.z - (2.0f * normal.z) * dotProduct;
    return result;
}

shared double Length(Vec3f v1, Vec3f v2)
{
    return Maths::Sqrt(v1.LengthSquared(v2));
}

shared double LengthSquared(Vec3f v1, Vec3f v2)
{
    return  (v1.x - v2.x) * (v1.x - v2.x) +
            (v1.y - v2.y) * (v1.y - v2.y) +
            (v1.z - v2.z) * (v1.z - v2.z);
}

shared Vec3f SmoothStep(Vec3f value1, Vec3f value2, double amount)
{
    return Vec3f(
        MathsHelper::SmoothStep(value1.x, value2.x, amount),
        MathsHelper::SmoothStep(value1.y, value2.y, amount),
        MathsHelper::SmoothStep(value1.z, value2.z, amount));
}

shared void Subtract(Vec3f value1, Vec3f value2, Vec3f &out result)
{
    result.x = value1.x - value2.x;
    result.y = value1.y - value2.y;
    result.z = value1.z - value2.z;
}

shared void Max(Vec3f value1, Vec3f value2, Vec3f &out result)
{
    result = Vec3f(
        Maths::Max(value1.x, value2.x),
        Maths::Max(value1.y, value2.y),
        Maths::Max(value1.z, value2.z));
}

shared void Min(Vec3f value1, Vec3f value2, Vec3f &out result)
{
    result = Vec3f(
        Maths::Min(value1.x, value2.x),
        Maths::Min(value1.y, value2.y),
        Maths::Min(value1.z, value2.z));
}
