
#include "Vec3f.as"
#include "Vec4f.as"
//#include "BoundingSphere.as"
//#include "BoundingBox.as"
#include "TypeEnums.as"
#include "Quaternion.as"
#include "Plane.as"

shared class MatrixR//eloaded :)
{ 
    float[] Array;

    MatrixR()
    {
    	Array.set_length(16);
    	this.Array[0]  = 1.0f; this.Array[1]  = 0.0f; this.Array[2]  = 0.0f; this.Array[3]  = 0.0f; 
        this.Array[4]  = 0.0f; this.Array[5]  = 1.0f; this.Array[6]  = 0.0f; this.Array[7]  = 0.0f; 
        this.Array[8]  = 0.0f; this.Array[9]  = 0.0f; this.Array[10] = 1.0f; this.Array[11] = 0.0f; 
        this.Array[12] = 0.0f; this.Array[13] = 0.0f; this.Array[14] = 0.0f; this.Array[15] = 1.0f;
    }

    MatrixR(float m11, float m12, float m13, float m14,
    		float m21, float m22, float m23, float m24, 
    		float m31, float m32, float m33, float m34,
    		float m41, float m42, float m43, float m44)
    {
    	Array.set_length(16);
        this.Array[0] = m11; this.Array[1] = m12; this.Array[2] = m13; this.Array[3] = m14; 
        this.Array[4] = m21; this.Array[5] = m22; this.Array[6] = m23; this.Array[7] = m24; 
        this.Array[8] = m31; this.Array[9] = m32; this.Array[10] = m33; this.Array[11] = m34; 
        this.Array[12] = m41; this.Array[13] = m42; this.Array[14] = m43; this.Array[15] = m44;
    }
    
    MatrixR(float[] _in)
    {
    	Array.set_length(16);
        this.Array[0] = _in[0]; this.Array[1] = _in[1]; this.Array[2] = _in[2]; this.Array[3] = _in[3]; 
        this.Array[4] = _in[4]; this.Array[5] = _in[5]; this.Array[6] = _in[6]; this.Array[7] = _in[7]; 
        this.Array[8] = _in[8]; this.Array[9] = _in[9]; this.Array[10] = _in[10]; this.Array[11] = _in[11]; 
        this.Array[12] = _in[12]; this.Array[13] = _in[13]; this.Array[14] = _in[14]; this.Array[15] = _in[15];
    }

    Vec3f Backward
    {
        get { return Vec3f(-this.Array[8], -this.Array[9], -this.Array[10]); }
        set
        {
            this.Array[8] = -value.x;
            this.Array[9] = -value.y;
            this.Array[10] = -value.z;
        }
    }
    
    Vec3f Down 
    {
        get { return Vec3f(-this.Array[4], -this.Array[5], -this.Array[6]); }
        set
        {
            this.Array[4] = -value.x;
            this.Array[5] = -value.y;
            this.Array[6] = -value.z;
        }
    }

    
    Vec3f Forward
    {
        get { return Vec3f(this.Array[8], this.Array[9], this.Array[10]); }
        set
        {
            this.Array[8] = value.x;
            this.Array[9] = value.y;
            this.Array[10] = value.z;
        }
    }
    
    Vec3f Left
    {
        get { return Vec3f(-this.Array[0], -this.Array[1], -this.Array[2]); }
        set
        {
            this.Array[0] = -value.x;
            this.Array[1] = -value.y;
            this.Array[2] = -value.z;
        }
    }

    
    Vec3f Right
    {
        get { return Vec3f(this.Array[0], this.Array[1], this.Array[2]); }
        set
        {
            this.Array[0] = value.x;
            this.Array[1] = value.y;
            this.Array[2] = value.z;
        }
    }

    
    Vec3f Translation
    {
        get { return Vec3f(this.Array[12], this.Array[13], this.Array[14]); }
        set
        {
            this.Array[12] = value.x;
            this.Array[13] = value.y;
            this.Array[14] = value.z;
        }
    }

    
    Vec3f Up
    {
        get { return Vec3f(this.Array[4], this.Array[5], this.Array[6]); }
        set
        {
            this.Array[4] = value.x;
            this.Array[5] = value.y;
            this.Array[6] = value.z;
        }
    }

    void Add(MatrixR matrix2)
    {
        this.Array[0] = this.Array[0] + matrix2.Array[0];
        this.Array[1] = this.Array[1] + matrix2.Array[1];
        this.Array[2] = this.Array[2] + matrix2.Array[2];
        this.Array[3] = this.Array[3] + matrix2.Array[3];
        this.Array[4] = this.Array[4] + matrix2.Array[4];
        this.Array[5] = this.Array[5] + matrix2.Array[5];
        this.Array[6] = this.Array[6] + matrix2.Array[6];
        this.Array[7] = this.Array[7] + matrix2.Array[7];
        this.Array[8] = this.Array[8] + matrix2.Array[8];
        this.Array[9] = this.Array[9] + matrix2.Array[9];
        this.Array[10] = this.Array[10] + matrix2.Array[10];
        this.Array[11] = this.Array[11] + matrix2.Array[11];
        this.Array[12] = this.Array[12] + matrix2.Array[12];
        this.Array[13] = this.Array[13] + matrix2.Array[13];
        this.Array[14] = this.Array[14] + matrix2.Array[14];
        this.Array[15] = this.Array[15] + matrix2.Array[15];
    }

    void CreateBillboard( Vec3f objectPosition, Vec3f cameraPosition, Vec3f cameraUpVector, Vec3f cameraForwardVector)
    {
        Vec3f vector, vector2, vector3;
	    vector.x = objectPosition.x - cameraPosition.x;
	    vector.y = objectPosition.y - cameraPosition.y;
	    vector.z = objectPosition.z - cameraPosition.z;
	    float num = vector.LengthSquared();
	    if (num < 0.0001f)
	    {
	        vector = -cameraForwardVector;
	    }
	    else
	    {
	        vector.Multiply(vector, float(1.0f / float(Maths::Sqrt(float(num)))));
	    }
	    vector3.Cross(cameraUpVector, vector);
	    vector3.Normalize();
	    vector2.Cross(vector, vector3);
	    this.Array[0] = vector3.x;
	    this.Array[1] = vector3.y;
	    this.Array[2] = vector3.z;
	    this.Array[3] = 0.0f;
	    this.Array[4] = vector2.x;
	    this.Array[5] = vector2.y;
	    this.Array[6] = vector2.z;
	    this.Array[7] = 0.0f;
	    this.Array[8] = vector.x;
	    this.Array[9] = vector.y;
	    this.Array[10] = vector.z;
	    this.Array[11] = 0.0f;
	    this.Array[12] = objectPosition.x;
	    this.Array[13] = objectPosition.y;
	    this.Array[14] = objectPosition.z;
	    this.Array[15] = 1.0f;
    }
    
    void CreateConstrainedBillboard(Vec3f objectPosition, Vec3f cameraPosition, Vec3f rotateAxis, Vec3f cameraForwardVector, Vec3f objectForwardVector)
    {
        float num;
	    Vec3f vector;
	    Vec3f vector2;
	    Vec3f vector3;
	    vector2.x = objectPosition.x - cameraPosition.x;
	    vector2.y = objectPosition.y - cameraPosition.y;
	    vector2.z = objectPosition.z - cameraPosition.z;
	    float num2 = vector2.LengthSquared();
	    if (num2 < 0.0001f)
	    {
	        vector2 = -cameraForwardVector;
	    }
	    else
	    {
	       vector2.Multiply(vector2, float((1.0f / float(Maths::Sqrt(float(num2)))) ));
	    }
	    Vec3f vector4 = rotateAxis;
	    num = Dot(rotateAxis, vector2);
	    if (Maths::Abs(num) > 0.9982547f)
	    {
	        if (objectForwardVector != Vec3f())
	        {
	            vector = objectForwardVector;
	            num = Dot(rotateAxis, vector);
	            if (Maths::Abs(num) > 0.9982547f)
	            {
	                num = ((rotateAxis.x * Forward.x) + (rotateAxis.y * Forward.y)) + (rotateAxis.z * Forward.z);
	                vector = (Maths::Abs(num) > 0.9982547f) ? Right : Forward;
	            }
	        }
	        else
	        {
	            num = ((rotateAxis.x * Forward.x) + (rotateAxis.y * Forward.y)) + (rotateAxis.z * Forward.z);
	            vector = (Maths::Abs(num) > 0.9982547f) ? Right : Forward;
	        }
	        vector3.Cross(rotateAxis, vector);
	        vector3.Normalize();
	        vector.Cross(vector3, rotateAxis);
	        vector.Normalize();
	    }
	    else
	    {
	        vector3.Cross(rotateAxis, vector2);
	        vector3.Normalize();
	        vector.Cross(vector3, vector4 );
	        vector.Normalize();
	    }
	    this.Array[0] = vector3.x;
	    this.Array[1] = vector3.y;
	    this.Array[2] = vector3.z;
	    this.Array[3] = 0.0f;
	    this.Array[4] = vector4.x;
	    this.Array[5] = vector4.y;
	    this.Array[6] = vector4.z;
	    this.Array[7] = 0.0f;
	    this.Array[8] = vector.x;
	    this.Array[9] = vector.y;
	    this.Array[10] = vector.z;
	    this.Array[11] = 0.0f;
	    this.Array[12] = objectPosition.x;
	    this.Array[13] = objectPosition.y;
	    this.Array[14] = objectPosition.z;
	    this.Array[15] = 1.0f;
    }

    void CreateFromAxisAngle(Vec3f axis, float angle)
    {
        float x = axis.x;
	    float y = axis.y;
	    float z = axis.z;
	    float num2 = Maths::Sin(angle);
	    float num = Maths::Cos(angle);
	    float num11 = x * x;
	    float num10 = y * y;
	    float num9 = z * z;
	    float num8 = x * y;
	    float num7 = x * z;
	    float num6 = y * z;
	    this.Array[0] = num11 + (num * (1.0f - num11));
	    this.Array[1] = (num8 - (num * num8)) + (num2 * z);
	    this.Array[2] = (num7 - (num * num7)) - (num2 * y);
	    this.Array[3] = 0.0f;
	    this.Array[4] = (num8 - (num * num8)) - (num2 * z);
	    this.Array[5] = num10 + (num * (1.0f - num10));
	    this.Array[6] = (num6 - (num * num6)) + (num2 * x);
	    this.Array[7] = 0.0f;
	    this.Array[8] = (num7 - (num * num7)) + (num2 * y);
	    this.Array[9] = (num6 - (num * num6)) - (num2 * x);
	    this.Array[10] = num9 + (num * (1.0f - num9));
	    this.Array[11] = 0.0f;
	    this.Array[12] = 0.0f;
	    this.Array[13] = 0.0f;
	    this.Array[14] = 0.0f;
	    this.Array[15] = 1.0f;
    }

    void CreateFromQuaternion(Quaternion quaternion)
    {
        float num9 = quaternion.x * quaternion.x;
	    float num8 = quaternion.y * quaternion.y;
	    float num7 = quaternion.z * quaternion.z;
	    float num6 = quaternion.x * quaternion.y;
	    float num5 = quaternion.z * quaternion.w;
	    float num4 = quaternion.z * quaternion.x;
	    float num3 = quaternion.y * quaternion.w;
	    float num2 = quaternion.y * quaternion.z;
	    float num = quaternion.x * quaternion.w;
	    this.Array[0] = 1.0f - (2.0f * (num8 + num7));
	    this.Array[1] = 2.0f * (num6 + num5);
	    this.Array[2] = 2.0f * (num4 - num3);
	    this.Array[3] = 0.0f;
	    this.Array[4] = 2.0f * (num6 - num5);
	    this.Array[5] = 1.0f - (2.0f * (num7 + num9));
	    this.Array[6] = 2.0f * (num2 + num);
	    this.Array[7] = 0.0f;
	    this.Array[8] = 2.0f * (num4 + num3);
	    this.Array[9] = 2.0f * (num2 - num);
	    this.Array[10] = 1.0f - (2.0f * (num8 + num9));
	    this.Array[11] = 0.0f;
	    this.Array[12] = 0.0f;
	    this.Array[13] = 0.0f;
	    this.Array[14] = 0.0f;
	    this.Array[15] = 1.0f;
    }
	
//	
	void CreateFromYawPitchRoll( float yaw, float pitch, float roll)
	{
		Quaternion quaternion();
	    quaternion.CreateFromYawPitchRoll(yaw, pitch, roll, quaternion);
	    this.CreateFromQuaternion(quaternion);
	}

    void CreateFromYawPitchRoll( Vec3f ypr)
    {
        Quaternion quaternion();
        quaternion.CreateFromYawPitchRoll(ypr.x, ypr.y, ypr.z, quaternion);
        this.CreateFromQuaternion(quaternion);
    }

    void CreateLookAt(Vec3f cameraPosition, Vec3f cameraTarget, Vec3f cameraUpVector)
    {
        Vec3f vector = Normalize(cameraTarget - cameraPosition);
	    Vec3f vector2 = Normalize(Cross(cameraUpVector, vector));
	    Vec3f vector3 = Cross(vector, vector2);
	    this.Array[0] = vector2.x;
	    this.Array[1] = vector3.x;
	    this.Array[2] = vector.x;
	    this.Array[3] = 0.0f;
	    this.Array[4] = vector2.y;
	    this.Array[5] = vector3.y;
	    this.Array[6] = vector.y;
	    this.Array[7] = 0.0f;
	    this.Array[8] = vector2.z;
	    this.Array[9] = vector3.z;
	    this.Array[10] = vector.z;
	    this.Array[11] = 0.0f;
	    this.Array[12] = -Dot(vector2, cameraPosition);
	    this.Array[13] = -Dot(vector3, cameraPosition);
	    this.Array[14] = -Dot(vector, cameraPosition);
	    this.Array[15] = 1.0f;
    }

    void CreateOrthographic(float width, float height, float zNearPlane, float zFarPlane)
    {
	    this.Array[0] = 2.0f / width;
	    this.Array[1] = this.Array[2] = this.Array[3] = 0.0f;
	    this.Array[5] = 2.0f / height;
	    this.Array[4] = this.Array[6] = this.Array[7] = 0.0f;
	    this.Array[10] = 1.0f / (zNearPlane - zFarPlane);
	    this.Array[8] = this.Array[9] = this.Array[11] = 0.0f;
	    this.Array[12] = this.Array[13] = 0.0f;
	    this.Array[14] = zNearPlane / (zNearPlane - zFarPlane);
	    this.Array[15] = 1.0f;
    }
    
    void CreateOrthographicOffCenter(float left, float right, float bottom, float top, float zNearPlane, float zFarPlane)
    {
		this.Array[0] = (2.0f / (right - left));
		this.Array[1] = 0.0f;
		this.Array[2] = 0.0f;
		this.Array[3] = 0.0f;
		this.Array[4] = 0.0f;
		this.Array[5] = (2.0f / (top - bottom));
		this.Array[6] = 0.0f;
		this.Array[7] = 0.0f;
		this.Array[8] = 0.0f;
		this.Array[9] = 0.0f;
		this.Array[10] = (1.0f / (zNearPlane - zFarPlane));
		this.Array[11] = 0.0f;
		this.Array[12] = ((left + right) / (left - right));
		this.Array[13] = ((top + bottom) / (bottom - top));
		this.Array[14] = (zNearPlane / (zNearPlane - zFarPlane));
		this.Array[15] = 1.0f;
	}

    void MakeProjectionMatrixPerspectiveFovLH( f32 fieldOfViewDegrees, f32 aspectRatio, f32 zNear, f32 zFar)
    {
    	f32 fieldOfViewRadians = fieldOfViewDegrees*(Maths::Pi / 180.0f);
        const f32 h = 1.0/(Maths::Tan(fieldOfViewRadians*0.5));        
        const f32 w = (h / aspectRatio);

        this.Array[0] = w;
        this.Array[1] = 0;
        this.Array[2] = 0;
        this.Array[3] = 0;

        this.Array[4] = 0;
        this.Array[5] = h;
        this.Array[6] = 0;
        this.Array[7] = 0;

        this.Array[8] = 0;
        this.Array[9] = 0;
        this.Array[10] = (zFar/(zFar-zNear));
        this.Array[11] = 1;

        this.Array[12] = 0;
        this.Array[13] = 0;
        this.Array[14] = (-zNear*zFar/(zFar-zNear));
        this.Array[15] = 0;
    }

     // Builds a right-handed perspective projection matrix based on a field of view
     void MakeProjectionMatrixPerspectiveFovRH( f32 fieldOfViewDegrees, f32 aspectRatio, f32 zNear, f32 zFar)
     {
     	 f32 fieldOfViewRadians = fieldOfViewDegrees*(Maths::Pi / 180.0f);
         const f32 h = 1.0/(Maths::Tan(fieldOfViewRadians*0.5));
         const f32 w = (h / aspectRatio);

         this.Array[0] = w;
         this.Array[1] = 0;
         this.Array[2] = 0;
         this.Array[3] = 0;
 
         this.Array[4] = 0;
         this.Array[5] = h;
         this.Array[6] = 0;
         this.Array[7] = 0;
 
         this.Array[8] = 0;
         this.Array[9] = 0;
         this.Array[10] = (zFar/(zNear-zFar)); // DirectX version
	     //this.Array[10] = (zFar+zNear/(zNear-zFar)); // OpenGL version
         this.Array[11] = -1;
 
         this.Array[12] = 0;
         this.Array[13] = 0;
         this.Array[14] = (zNear*zFar/(zNear-zFar)); // DirectX version
	     //this.Array[14] = (2.0f*zNear*zFar/(zNear-zFar)); // OpenGL version
         this.Array[15] = 0;
	}

    void MakePerspectiveOffCenter(float left, float right, float bottom, float top, float nearPlaneDistance, float farPlaneDistance)
    {
	    this.Array[0] = (2.0f * nearPlaneDistance) / (right - left);
	    this.Array[1] = this.Array[2] = this.Array[3] = 0.0f;
	    this.Array[5] = (2.0f * nearPlaneDistance) / (top - bottom);
	    this.Array[4] = this.Array[6] = this.Array[7] = 0.0f;
	    this.Array[8] = (left + right) / (right - left);
	    this.Array[9] = (top + bottom) / (top - bottom);
	    this.Array[10] = farPlaneDistance / (nearPlaneDistance - farPlaneDistance);
	    this.Array[11] = -1.0f;
	    this.Array[14] = (nearPlaneDistance * farPlaneDistance) / (nearPlaneDistance - farPlaneDistance);
	    this.Array[12] = this.Array[13] = this.Array[15] = 0.0f;
    }

    void MakeShadowMatrix(const Vec3f light, Plane plane, f32 point)
    {
        plane.Normal.Normalize();
        const f32 d = plane.Normal.Dot(light);
 
        this.Array[ 0] = (-plane.Normal.x * light.x + d);
        this.Array[ 1] = (-plane.Normal.x * light.y);
        this.Array[ 2] = (-plane.Normal.x * light.z);
        this.Array[ 3] = (-plane.Normal.x * point);
 
        this.Array[ 4] = (-plane.Normal.y * light.x);
        this.Array[ 5] = (-plane.Normal.y * light.y + d);
        this.Array[ 6] = (-plane.Normal.y * light.z);
        this.Array[ 7] = (-plane.Normal.y * point);
 
        this.Array[ 8] = (-plane.Normal.z * light.x);
        this.Array[ 9] = (-plane.Normal.z * light.y);
        this.Array[10] = (-plane.Normal.z * light.z + d);
        this.Array[11] = (-plane.Normal.z * point);
 
        this.Array[12] = (-plane.D * light.x);
        this.Array[13] = (-plane.D * light.y);
        this.Array[14] = (-plane.D * light.z);
        this.Array[15] = (-plane.D * point + d);
    }
           
     void setRotationDegrees( Vec3f rotation )
     {
         setRotationRadians( rotation * (Maths::Pi / 180.0f) );
     }

     void setRotationDegrees(  f32 rotationX, f32 rotationY, f32 rotationZ  )
     {
         setRotationRadians( Vec3f(rotationX, rotationY, rotationZ) * (Maths::Pi / 180.0f) );
     }

     void setRotationRadians( f32 rotationX, f32 rotationY, f32 rotationZ )
	 {
	 	setRotationRadians( Vec3f(rotationX, rotationY, rotationZ));
	 }

	 void setRotationRadians( Vec3f rotation )
	 {
	    const f32 cr = Maths::Cos( rotation.y );
	    const f32 sr = Maths::Sin( rotation.y );
	    const f32 cp = Maths::Cos( rotation.x );
	    const f32 sp = Maths::Sin( rotation.x );
	    const f32 cy = Maths::Cos( rotation.z );
	    const f32 sy = Maths::Sin( rotation.z );

	    this.Array[0] = ( cp*cy );
	    this.Array[1] = ( cp*sy );
	    this.Array[2] = ( -sp );

	    const f32 srsp = sr*sp;
	    const f32 crsp = cr*sp;

	    this.Array[4] = ( srsp*cy-cr*sy );
	    this.Array[5] = ( srsp*sy+cr*cy );
	    this.Array[6] = ( sr*cp );

	    this.Array[8] = ( crsp*cy+sr*sy );
	    this.Array[9] = ( crsp*sy-sr*cy );
	    this.Array[10] = ( cr*cp );
	 }

	void SetRotationXDegrees(float degrees) { SetRotationXRadians(degrees* (Maths::Pi / 180.0f)); }
    void SetRotationYDegrees(float degrees) { SetRotationYRadians(degrees* (Maths::Pi / 180.0f)); }
    void SetRotationZDegrees(float degrees) { SetRotationZRadians(degrees* (Maths::Pi / 180.0f)); }

    void SetRotationXRadians(float radians)
    {
        float val1 = Maths::Cos(radians);
		float val2 = Maths::Sin(radians);
		
        this.Array[0] = val1;
        this.Array[2] = -val2;
        this.Array[8] = val2;
        this.Array[10] = val1;
    }

    void SetRotationZRadians(float radians)
    {
		float val1 = Maths::Cos(radians);
		float val2 = Maths::Sin(radians);
		
        this.Array[0] = val1;
        this.Array[1] = val2;
        this.Array[4] = -val2;
        this.Array[5] = val1;
    }

    void SetRotationYRadians(float radians)
    {
    	float val1 = Maths::Cos(radians);
		float val2 = Maths::Sin(radians);
    	this.Array[5] = val1;
        this.Array[6] = val2;
        this.Array[9] = -val2;
        this.Array[10] = val1;
    }

    void rotateVec( Vec3f & vec )
    {
        Vec3f tmp = vec;
        vec.x = tmp.x*this.Array[0] + tmp.y*this.Array[4] + tmp.z*this.Array[8];
        vec.y = tmp.x*this.Array[1] + tmp.y*this.Array[5] + tmp.z*this.Array[9];
        vec.z = tmp.x*this.Array[2] + tmp.y*this.Array[6] + tmp.z*this.Array[10];
    } 

    void SetTranslation(float xPosition, float yPosition, float zPosition)
    {
		this.Array[12] = xPosition;
		this.Array[13] = yPosition;
		this.Array[14] = zPosition;
    }

     void SetTranslation(Vec3f position)
    {
		this.Array[12] = position.x;
		this.Array[13] = position.y;
		this.Array[14] = position.z;
    }

    void InverseX() { this.Array[12] = -this.Array[12]; }
    void InverseY() { this.Array[13] = -this.Array[13]; }
    void InverseZ() { this.Array[14] = -this.Array[14]; }

    void SetTranslationInverse(float xPosition, float yPosition, float zPosition)
    {
		this.Array[12] = -xPosition;
		this.Array[13] = -yPosition;
		this.Array[14] = -zPosition;
    }

     void SetTranslationInverse(Vec3f position)
    {
		this.Array[12] = -position.x;
		this.Array[13] = -position.y;
		this.Array[14] = -position.z;
    }

    void SetScale(float scale)
    {
		this.Array[0] = scale;
		this.Array[5] = scale;
		this.Array[10] = scale;
    }

    void SetScale(float xScale, float yScale, float zScale)
    {
		this.Array[0] = xScale;
		this.Array[1] = 0;
		this.Array[2] = 0;
		this.Array[3] = 0;
		this.Array[4] = 0;
		this.Array[5] = yScale;
		this.Array[6] = 0;
		this.Array[7] = 0;
		this.Array[8] = 0;
		this.Array[9] = 0;
		this.Array[10] = zScale;
		this.Array[11] = 0;
		this.Array[12] = 0;
		this.Array[13] = 0;
		this.Array[14] = 0;
		this.Array[15] = 1;
    }

    void SetScale(Vec3f scales)
    {
        this.Array[0] = scales.x;
		this.Array[1] = 0;
		this.Array[2] = 0;
		this.Array[3] = 0;
		this.Array[4] = 0;
		this.Array[5] = scales.y;
		this.Array[6] = 0;
		this.Array[7] = 0;
		this.Array[8] = 0;
		this.Array[9] = 0;
		this.Array[10] = scales.z;
		this.Array[11] = 0;
		this.Array[12] = 0;
		this.Array[13] = 0;
		this.Array[14] = 0;
		this.Array[15] = 1;
    }

    float Determinant()
    {
        float num22 = this.Array[0];
	    float num21 = this.Array[1];
	    float num20 = this.Array[2];
	    float num19 = this.Array[3];
	    float num12 = this.Array[4];
	    float num11 = this.Array[5];
	    float num10 = this.Array[6];
	    float num9 = this.Array[7];
	    float num8 = this.Array[8];
	    float num7 = this.Array[9];
	    float num6 = this.Array[10];
	    float num5 = this.Array[11];
	    float num4 = this.Array[12];
	    float num3 = this.Array[13];
	    float num2 = this.Array[14];
	    float num = this.Array[15];
	    float num18 = (num6 * num) - (num5 * num2);
	    float num17 = (num7 * num) - (num5 * num3);
	    float num16 = (num7 * num2) - (num6 * num3);
	    float num15 = (num8 * num) - (num5 * num4);
	    float num14 = (num8 * num2) - (num6 * num4);
	    float num13 = (num8 * num3) - (num7 * num4);
	    return ((((num22 * (((num11 * num18) - (num10 * num17)) + (num9 * num16))) - (num21 * (((num12 * num18) - (num10 * num15)) + (num9 * num14)))) + (num20 * (((num12 * num17) - (num11 * num15)) + (num9 * num13)))) - (num19 * (((num12 * num16) - (num11 * num14)) + (num10 * num13))));
    }

    void Divide(MatrixR matrix2)
    {
        this.Array[0] = this.Array[0] / matrix2.Array[0];
	    this.Array[1] = this.Array[1] / matrix2.Array[1];
	    this.Array[2] = this.Array[2] / matrix2.Array[2];
	    this.Array[3] = this.Array[3] / matrix2.Array[3];
	    this.Array[4] = this.Array[4] / matrix2.Array[4];
	    this.Array[5] = this.Array[5] / matrix2.Array[5];
	    this.Array[6] = this.Array[6] / matrix2.Array[6];
	    this.Array[7] = this.Array[7] / matrix2.Array[7];
	    this.Array[8] = this.Array[8] / matrix2.Array[8];
	    this.Array[9] = this.Array[9] / matrix2.Array[9];
	    this.Array[10] = this.Array[10] / matrix2.Array[10];
	    this.Array[11] = this.Array[11] / matrix2.Array[11];
	    this.Array[12] = this.Array[12] / matrix2.Array[12];
	    this.Array[13] = this.Array[13] / matrix2.Array[13];
	    this.Array[14] = this.Array[14] / matrix2.Array[14];
	    this.Array[15] = this.Array[15] / matrix2.Array[15];
    }

    void Divide(MatrixR matrix1, float divider)
    {
        float num = 1.0f / divider;
	    this.Array[0] = this.Array[0] * num;
	    this.Array[1] = this.Array[1] * num;
	    this.Array[2] = this.Array[2] * num;
	    this.Array[3] = this.Array[3] * num;
	    this.Array[4] = this.Array[4] * num;
	    this.Array[5] = this.Array[5] * num;
	    this.Array[6] = this.Array[6] * num;
	    this.Array[7] = this.Array[7] * num;
	    this.Array[8] = this.Array[8] * num;
	    this.Array[9] = this.Array[9] * num;
	    this.Array[10] = this.Array[10] * num;
	    this.Array[11] = this.Array[11] * num;
	    this.Array[12] = this.Array[12] * num;
	    this.Array[13] = this.Array[13] * num;
	    this.Array[14] = this.Array[14] * num;
	    this.Array[15] = this.Array[15] * num;
    }


    bool Equals(MatrixR other)
    {
        return ((((((this.Array[0] == other.Array[0]) && (this.Array[5] == other.Array[5])) && ((this.Array[10] == other.Array[10]) && (this.Array[15] == other.Array[15]))) && (((this.Array[1] == other.Array[1]) && (this.Array[2] == other.Array[2])) && ((this.Array[3] == other.Array[3]) && (this.Array[4] == other.Array[4])))) && ((((this.Array[6] == other.Array[6]) && (this.Array[7] == other.Array[7])) && ((this.Array[8] == other.Array[8]) && (this.Array[9] == other.Array[9]))) && (((this.Array[11] == other.Array[11]) && (this.Array[12] == other.Array[12])) && (this.Array[13] == other.Array[13])))) && (this.Array[14] == other.Array[14]));
    }

    //int GetHashCode()
    //{
    //    return (((((((((((((((this.Array[0].GetHashCode() + this.Array[1].GetHashCode()) + this.Array[2].GetHashCode()) + this.Array[3].GetHashCode()) + this.Array[4].GetHashCode()) + this.Array[5].GetHashCode()) + this.Array[6].GetHashCode()) + this.Array[7].GetHashCode()) + this.Array[8].GetHashCode()) + this.Array[9].GetHashCode()) + this.Array[10].GetHashCode()) + this.Array[11].GetHashCode()) + this.Array[12].GetHashCode()) + this.Array[13].GetHashCode()) + this.Array[14].GetHashCode()) + this.Array[15].GetHashCode());
    //}

    MatrixR Invert()
    {
		float num1 = this.Array[0];
		float num2 = this.Array[1];
		float num3 = this.Array[2];
		float num4 = this.Array[3];
		float num5 = this.Array[4];
		float num6 = this.Array[5];
		float num7 = this.Array[6];
		float num8 = this.Array[7];
		float num9 = this.Array[8];
		float num10 = this.Array[9];
		float num11 = this.Array[10];
		float num12 = this.Array[11];
		float num13 = this.Array[12];
		float num14 = this.Array[13];
		float num15 = this.Array[14];
		float num16 = this.Array[15];
		float num17 = (num11 * num16 - num12 * num15);
		float num18 = (num10 * num16 - num12 * num14);
		float num19 = (num10 * num15 - num11 * num14);
		float num20 = (num9 * num16 - num12 * num13);
		float num21 = (num9 * num15 - num11 * num13);
		float num22 = (num9 * num14 - num10 * num13);
		float num23 = (num6 * num17 - num7 * num18 + num8 * num19);
		float num24 = -(num5 * num17 - num7 * num20 + num8 * num21);
		float num25 = (num5 * num18 - num6 * num20 + num8 * num22);
		float num26 = -(num5 * num19 - num6 * num21 + num7 * num22);
		float num27 = (1.0 / (num1 * num23 + num2 * num24 + num3 * num25 + num4 * num26));
		
		this.Array[0] = num23 * num27;
		this.Array[4] = num24 * num27;
		this.Array[8] = num25 * num27;
		this.Array[12] = num26 * num27;
		this.Array[1] = -(num2 * num17 - num3 * num18 + num4 * num19) * num27;
		this.Array[5] = (num1 * num17 - num3 * num20 + num4 * num21) * num27;
		this.Array[9] = -(num1 * num18 - num2 * num20 + num4 * num22) * num27;
		this.Array[13] = (num1 * num19 - num2 * num21 + num3 * num22) * num27;
		float num28 = (num7 * num16 - num8 * num15);
		float num29 = (num6 * num16 - num8 * num14);
		float num30 = (num6 * num15 - num7 * num14);
		float num31 = (num5 * num16 - num8 * num13);
		float num32 = (num5 * num15 - num7 * num13);
		float num33 = (num5 * num14 - num6 * num13);
		this.Array[2] = (num2 * num28 - num3 * num29 + num4 * num30) * num27;
		this.Array[6] = -(num1 * num28 - num3 * num31 + num4 * num32) * num27;
		this.Array[10] = (num1 * num29 - num2 * num31 + num4 * num33) * num27;
		this.Array[14] = -(num1 * num30 - num2 * num32 + num3 * num33) * num27;
		float num34 = (num7 * num12 - num8 * num11);
		float num35 = (num6 * num12 - num8 * num10);
		float num36 = (num6 * num11 - num7 * num10);
		float num37 = (num5 * num12 - num8 * num9);
		float num38 = (num5 * num11 - num7 * num9);
		float num39 = (num5 * num10 - num6 * num9);
		this.Array[3] = -(num2 * num34 - num3 * num35 + num4 * num36) * num27;
		this.Array[7] = (num1 * num34 - num3 * num37 + num4 * num38) * num27;
		this.Array[11] = -(num1 * num35 - num2 * num37 + num4 * num39) * num27;
		this.Array[15] = (num1 * num36 - num2 * num38 + num3 * num39) * num27;	

        return this;	
    }

    void Lerp(MatrixR matrix2, float amount)
    {
        this.Array[0] = this.Array[0] + ((matrix2.Array[0] - this.Array[0]) * amount);
	    this.Array[1] = this.Array[1] + ((matrix2.Array[1] - this.Array[1]) * amount);
	    this.Array[2] = this.Array[2] + ((matrix2.Array[2] - this.Array[2]) * amount);
	    this.Array[3] = this.Array[3] + ((matrix2.Array[3] - this.Array[3]) * amount);
	    this.Array[4] = this.Array[4] + ((matrix2.Array[4] - this.Array[4]) * amount);
	    this.Array[5] = this.Array[5] + ((matrix2.Array[5] - this.Array[5]) * amount);
	    this.Array[6] = this.Array[6] + ((matrix2.Array[6] - this.Array[6]) * amount);
	    this.Array[7] = this.Array[7] + ((matrix2.Array[7] - this.Array[7]) * amount);
	    this.Array[8] = this.Array[8] + ((matrix2.Array[8] - this.Array[8]) * amount);
	    this.Array[9] = this.Array[9] + ((matrix2.Array[9] - this.Array[9]) * amount);
	    this.Array[10] = this.Array[10] + ((matrix2.Array[10] - this.Array[10]) * amount);
	    this.Array[11] = this.Array[11] + ((matrix2.Array[11] - this.Array[11]) * amount);
	    this.Array[12] = this.Array[12] + ((matrix2.Array[12] - this.Array[12]) * amount);
	    this.Array[13] = this.Array[13] + ((matrix2.Array[13] - this.Array[13]) * amount);
	    this.Array[14] = this.Array[14] + ((matrix2.Array[14] - this.Array[14]) * amount);
	    this.Array[15] = this.Array[15] + ((matrix2.Array[15] - this.Array[15]) * amount);
    }

    void Multiply(MatrixR matrix2)
    {
        float m11 = (((this.Array[0] * matrix2.Array[0]) + (this.Array[1] * matrix2.Array[4])) + (this.Array[2] * matrix2.Array[8])) + (this.Array[3] * matrix2.Array[12]);
        float m12 = (((this.Array[0] * matrix2.Array[1]) + (this.Array[1] * matrix2.Array[5])) + (this.Array[2] * matrix2.Array[9])) + (this.Array[3] * matrix2.Array[13]);
        float m13 = (((this.Array[0] * matrix2.Array[2]) + (this.Array[1] * matrix2.Array[6])) + (this.Array[2] * matrix2.Array[10])) + (this.Array[3] * matrix2.Array[14]);
        float m14 = (((this.Array[0] * matrix2.Array[3]) + (this.Array[1] * matrix2.Array[7])) + (this.Array[2] * matrix2.Array[11])) + (this.Array[3] * matrix2.Array[15]);
        float m21 = (((this.Array[4] * matrix2.Array[0]) + (this.Array[5] * matrix2.Array[4])) + (this.Array[6] * matrix2.Array[8])) + (this.Array[7] * matrix2.Array[12]);
        float m22 = (((this.Array[4] * matrix2.Array[1]) + (this.Array[5] * matrix2.Array[5])) + (this.Array[6] * matrix2.Array[9])) + (this.Array[7] * matrix2.Array[13]);
        float m23 = (((this.Array[4] * matrix2.Array[2]) + (this.Array[5] * matrix2.Array[6])) + (this.Array[6] * matrix2.Array[10])) + (this.Array[7] * matrix2.Array[14]);
        float m24 = (((this.Array[4] * matrix2.Array[3]) + (this.Array[5] * matrix2.Array[7])) + (this.Array[6] * matrix2.Array[11])) + (this.Array[7] * matrix2.Array[15]);
        float m31 = (((this.Array[8] * matrix2.Array[0]) + (this.Array[9] * matrix2.Array[4])) + (this.Array[10] * matrix2.Array[8])) + (this.Array[11] * matrix2.Array[12]);
        float m32 = (((this.Array[8] * matrix2.Array[1]) + (this.Array[9] * matrix2.Array[5])) + (this.Array[10] * matrix2.Array[9])) + (this.Array[11] * matrix2.Array[13]);
        float m33 = (((this.Array[8] * matrix2.Array[2]) + (this.Array[9] * matrix2.Array[6])) + (this.Array[10] * matrix2.Array[10])) + (this.Array[11] * matrix2.Array[14]);
        float m34 = (((this.Array[8] * matrix2.Array[3]) + (this.Array[9] * matrix2.Array[7])) + (this.Array[10] * matrix2.Array[11])) + (this.Array[11] * matrix2.Array[15]);
        float m41 = (((this.Array[12] * matrix2.Array[0]) + (this.Array[13] * matrix2.Array[4])) + (this.Array[14] * matrix2.Array[8])) + (this.Array[15] * matrix2.Array[12]);
        float m42 = (((this.Array[12] * matrix2.Array[1]) + (this.Array[13] * matrix2.Array[5])) + (this.Array[14] * matrix2.Array[9])) + (this.Array[15] * matrix2.Array[13]);
        float m43 = (((this.Array[12] * matrix2.Array[2]) + (this.Array[13] * matrix2.Array[6])) + (this.Array[14] * matrix2.Array[10])) + (this.Array[15] * matrix2.Array[14]);
       	float m44 = (((this.Array[12] * matrix2.Array[3]) + (this.Array[13] * matrix2.Array[7])) + (this.Array[14] * matrix2.Array[11])) + (this.Array[15] * matrix2.Array[15]);
        this.Array[0] =  m11; this.Array[1] =  m12; this.Array[2] =  m13; this.Array[3] =  m14;
		this.Array[4] =  m21; this.Array[5] =  m22; this.Array[6] =  m23; this.Array[7] =  m24;
		this.Array[8] =  m31; this.Array[9] =  m32; this.Array[10] = m33; this.Array[11] = m34;
		this.Array[12] = m41; this.Array[13] = m42; this.Array[14] = m43; this.Array[15] = m44;      
    }

    void Multiply(float factor)
    {
        this.Array[0] = this.Array[0] * factor;
        this.Array[1] = this.Array[1] * factor;
        this.Array[2] = this.Array[2] * factor;
        this.Array[3] = this.Array[3] * factor;
        this.Array[4] = this.Array[4] * factor;
        this.Array[5] = this.Array[5] * factor;
        this.Array[6] = this.Array[6] * factor;
        this.Array[7] = this.Array[7] * factor;
        this.Array[8] = this.Array[8] * factor;
        this.Array[9] = this.Array[9] * factor;
        this.Array[10] = this.Array[10] * factor;
        this.Array[11] = this.Array[11] * factor;
        this.Array[12] = this.Array[12] * factor;
        this.Array[13] = this.Array[13] * factor;
        this.Array[14] = this.Array[14] * factor;
        this.Array[15] = this.Array[15] * factor;
    }

    void Negate()
    {
        this.Array[0] = -this.Array[0];
	    this.Array[1] = -this.Array[1];
	    this.Array[2] = -this.Array[2];
	    this.Array[3] = -this.Array[3];
	    this.Array[4] = -this.Array[4];
	    this.Array[5] = -this.Array[5];
	    this.Array[6] = -this.Array[6];
	    this.Array[7] = -this.Array[7];
	    this.Array[8] = -this.Array[8];
	    this.Array[9] = -this.Array[9];
	    this.Array[10] = -this.Array[10];
	    this.Array[11] = -this.Array[11];
	    this.Array[12] = -this.Array[12];
	    this.Array[13] = -this.Array[13];
	    this.Array[14] = -this.Array[14];
	    this.Array[15] = -this.Array[15];
    }

    bool opEquals(MatrixR matrix1, MatrixR matrix2)
    {
        return (
        matrix1.Array[0] == matrix2.Array[0] &&
        matrix1.Array[1] == matrix2.Array[1] &&
        matrix1.Array[2] == matrix2.Array[2] &&
        matrix1.Array[3] == matrix2.Array[3] &&
        matrix1.Array[4] == matrix2.Array[4] &&
        matrix1.Array[5] == matrix2.Array[5] &&
        matrix1.Array[6] == matrix2.Array[6] &&
        matrix1.Array[7] == matrix2.Array[7] &&
        matrix1.Array[8] == matrix2.Array[8] &&
        matrix1.Array[9] == matrix2.Array[9] &&
        matrix1.Array[10] == matrix2.Array[10] &&
        matrix1.Array[11] == matrix2.Array[11] &&
        matrix1.Array[12] == matrix2.Array[12] &&
        matrix1.Array[13] == matrix2.Array[13] &&
        matrix1.Array[14] == matrix2.Array[14] &&
        matrix1.Array[15] == matrix2.Array[15]                  
        );
    }


    bool opNotEquals(MatrixR matrix1, MatrixR matrix2)
    {
        return (
            matrix1.Array[0] != matrix2.Array[0] ||
            matrix1.Array[1] != matrix2.Array[1] ||
            matrix1.Array[2] != matrix2.Array[2] ||
            matrix1.Array[3] != matrix2.Array[3] ||
            matrix1.Array[4] != matrix2.Array[4] ||
            matrix1.Array[5] != matrix2.Array[5] ||
            matrix1.Array[6] != matrix2.Array[6] ||
            matrix1.Array[7] != matrix2.Array[7] ||
            matrix1.Array[8] != matrix2.Array[8] ||
            matrix1.Array[9] != matrix2.Array[9] ||
            matrix1.Array[10] != matrix2.Array[10] ||
            matrix1.Array[11] != matrix2.Array[11] || 
            matrix1.Array[12] != matrix2.Array[12] ||
            matrix1.Array[13] != matrix2.Array[13] ||
            matrix1.Array[14] != matrix2.Array[14] ||
            matrix1.Array[15] != matrix2.Array[15]                  
            );
    }

    void Subtract(MatrixR matrix2)
    {
        this.Array[0] = this.Array[0] - matrix2.Array[0];
	    this.Array[1] = this.Array[1] - matrix2.Array[1];
	    this.Array[2] = this.Array[2] - matrix2.Array[2];
	    this.Array[3] = this.Array[3] - matrix2.Array[3];
	    this.Array[4] = this.Array[4] - matrix2.Array[4];
	    this.Array[5] = this.Array[5] - matrix2.Array[5];
	    this.Array[6] = this.Array[6] - matrix2.Array[6];
	    this.Array[7] = this.Array[7] - matrix2.Array[7];
	    this.Array[8] = this.Array[8] - matrix2.Array[8];
	    this.Array[9] = this.Array[9] - matrix2.Array[9];
	    this.Array[10] = this.Array[10] - matrix2.Array[10];
	    this.Array[11] = this.Array[11] - matrix2.Array[11];
	    this.Array[12] = this.Array[12] - matrix2.Array[12];
	    this.Array[13] = this.Array[13] - matrix2.Array[13];
	    this.Array[14] = this.Array[14] - matrix2.Array[14];
	    this.Array[15] = this.Array[15] - matrix2.Array[15];
    }

    //string ToString() meh
    //{
    //    return "{" + String.Format("Array[0]:{0} Array[1]:{1} Array[2]:{2} Array[3]:{3}", Array[0], Array[1], Array[2], Array[3]) + "}"
	//		+ " {" + String.Format("Array[4]:{0} Array[5]:{1} Array[6]:{2} Array[7]:{3}", Array[4], Array[5], Array[6], Array[7]) + "}"
	//		+ " {" + String.Format("Array[8]:{0} Array[9]:{1} Array[10]:{2} Array[11]:{3}", Array[8], Array[9], Array[10], Array[11]) + "}"
	//		+ " {" + String.Format("Array[12]:{0} Array[13]:{1} Array[14]:{2} Array[15]:{3}", Array[12], Array[13], Array[14], Array[15]) + "}";
    //}

    Vec4f Transform(Vec4f v)
    {
        float vX = v.x;
        float vY = v.y;
        float vZ = v.z;
        float vW = v.w;

        Vec4f result;
        result.x = vX * this.Array[0] +  vY * this.Array[1] +  vZ * this.Array[2] +  vW * this.Array[3];
        result.y = vX * this.Array[4] +  vY * this.Array[5] +  vZ * this.Array[6] +  vW * this.Array[7];
        result.z = vX * this.Array[8] +  vY * this.Array[9] +  vZ * this.Array[10] + vW * this.Array[11];
        result.w = vX * this.Array[12] + vY * this.Array[13] + vZ * this.Array[14] + vW * this.Array[15];
        return result;
    }
    
    void Transpose()
    {
    	float m11 = this.Array[0];
		float m12 = this.Array[4];
		float m13 = this.Array[8];
		float m14 = this.Array[12];
		float m21 = this.Array[1];
		float m22 = this.Array[5];
		float m23 = this.Array[9];
		float m24 = this.Array[13];
		float m31 = this.Array[2];
		float m32 = this.Array[6];
		float m33 = this.Array[10];
		float m34 = this.Array[14];
		float m41 = this.Array[3];
		float m42 = this.Array[7];
		float m43 = this.Array[11];
		float m44 = this.Array[15];
        this.Array[0]  = m11;
        this.Array[1]  = m12;
        this.Array[2]  = m13;
        this.Array[3]  = m14;
        this.Array[4]  = m21;
        this.Array[5]  = m22;
        this.Array[6]  = m23;
        this.Array[7]  = m24;
        this.Array[8]  = m31;
        this.Array[9]  = m32;
        this.Array[10] = m33;
        this.Array[11] = m34;
        this.Array[12] = m41;
        this.Array[13] = m42;
        this.Array[14] = m43;
        this.Array[15] = m44;
    }
    
    /// Helper method for using the Laplace expansion theorem using two rows expansions to calculate major and 
    /// minor determinants of a 4x4 matrix. This method is used for inverting a matrix.
    void findDeterminants(MatrixR matrix, float &out major, 
                                         float &out minor1, float &out minor2, float &out minor3, float &out minor4, float &out minor5, float &out minor6,
                                         float &out minor7, float &out minor8, float &out minor9, float &out minor10, float &out minor11, float &out minor12)
    {
            float det1 = matrix.Array[0] * matrix.Array[5] - matrix.Array[1] * matrix.Array[4];
            float det2 = matrix.Array[0] * matrix.Array[6] - matrix.Array[2] * matrix.Array[4];
            float det3 = matrix.Array[0] * matrix.Array[7] - matrix.Array[3] * matrix.Array[4];
            float det4 = matrix.Array[1] * matrix.Array[6] - matrix.Array[2] * matrix.Array[5];
            float det5 = matrix.Array[1] * matrix.Array[7] - matrix.Array[3] * matrix.Array[5];
            float det6 = matrix.Array[2] * matrix.Array[7] - matrix.Array[3] * matrix.Array[6];
            float det7 = matrix.Array[8] * matrix.Array[13] - matrix.Array[9] * matrix.Array[12];
            float det8 = matrix.Array[8] * matrix.Array[14] - matrix.Array[10] * matrix.Array[12];
            float det9 = matrix.Array[8] * matrix.Array[15] - matrix.Array[11] * matrix.Array[12];
            float det10 = matrix.Array[9] * matrix.Array[14] - matrix.Array[10] * matrix.Array[13];
            float det11 = matrix.Array[9] * matrix.Array[15] - matrix.Array[11] * matrix.Array[13];
            float det12 = matrix.Array[10] * matrix.Array[15] - matrix.Array[11] * matrix.Array[14];
            
            major = (det1*det12 - det2*det11 + det3*det10 + det4*det9 - det5*det8 + det6*det7);
            minor1 = det1;
            minor2 = det2;
            minor3 = det3;
            minor4 = det4;
            minor5 = det5;
            minor6 = det6;
            minor7 = det7;
            minor8 = det8;
            minor9 = det9;
            minor10 = det10;
            minor11 = det11;
            minor12 = det12;
    }
	
	bool Decompose( Vec3f &out scale, Quaternion &out rotation, Vec3f &out translation)
    {
            translation.x = this.Array[12];
            translation.y = this.Array[13];
            translation.z = this.Array[14];
            
			//float xs = (Maths::Sign(Array[0] * Array[1] * Array[2] * Array[3]) < 0) ? -1.0f : 1.0f;
            //float ys = (Maths::Sign(Array[4] * Array[5] * Array[6] * Array[7]) < 0) ? -1.0f : 1.0f;
			//float zs = (Maths::Sign(Array[8] * Array[9] * Array[10] * Array[11]) < 0) ? -1.0f : 1.0f;  
            float xs = ((Array[0] * Array[1] * Array[2] * Array[3]) < 0) ? -1.0f : 1.0f;
            float ys = ((Array[4] * Array[5] * Array[6] * Array[7]) < 0) ? -1.0f : 1.0f;
			float zs = ((Array[8] * Array[9] * Array[10] * Array[11]) < 0) ? -1.0f : 1.0f; 
                            
            
            scale.x = xs * Maths::Sqrt(this.Array[0] * this.Array[0] + this.Array[1] * this.Array[1] + this.Array[2] * this.Array[2]);
            scale.y = ys * Maths::Sqrt(this.Array[4] * this.Array[4] + this.Array[5] * this.Array[5] + this.Array[6] * this.Array[6]);
            scale.z = zs * Maths::Sqrt(this.Array[8] * this.Array[8] + this.Array[9] * this.Array[9] + this.Array[10] * this.Array[10]);
            
            if (scale.x == 0.0 || scale.y == 0.0 || scale.z == 0.0)
            {
                    rotation = Quaternion(0,0,0,1);
                    return false;
            }

            MatrixR m1 = MatrixR(this.Array[0]/scale.x, Array[1]/scale.x, Array[2]/scale.x, 0,
                   				   this.Array[4]/scale.y, Array[5]/scale.y, Array[6]/scale.y, 0,
                   				   this.Array[8]/scale.z, Array[9]/scale.z, Array[10]/scale.z, 0,
                   				   0, 0, 0, 1);
            
            rotation = CreateFromRotationMatrixR(m1);
            return true;
    }
		
};
