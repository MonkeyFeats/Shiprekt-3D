#include "Ray.as"
#include "Plane.as"
#include "Matrix.as"
#include "Blob3D.as"
#include "Transform.as"
//#include "Tree.as";
//#include "World.as"
//#include "BoundingFrustum.as"

const string FIRST_PERSON_CAMERA_ENABLED = "first person camera enabled";

bool IsFirstPersonCameraEnabled(CRules@ rules)
{
	return rules is null || !rules.exists(FIRST_PERSON_CAMERA_ENABLED) || rules.get_bool(FIRST_PERSON_CAMERA_ENABLED);
}

shared class Camera3D
{
	//u16 ownerPlayerID
	MatrixR view;
	MatrixR projection;

	float fov;
	float z_near;
	float z_far;

    RigidTransform transform();

	Blob3D@ targetBlob;
	float mouseSensitivity;
	float posLag;
	bool locked;
	
	Vec3f pos_offset;

	//BoundingFrustum frustum;	
	
	Camera3D()
	{
		//Matrix::MakeIdentity(view);
		view = MatrixR();
		
		pos_offset = Vec3f(0, 20, -40);
		
		fov = 80;
		z_near = 4.0f;
		z_far = 8192.0f;
		f64 AspectRatio = f64(getDriver().getScreenWidth()) / f64(getDriver().getScreenHeight());

		projection.MakeProjectionMatrixPerspectiveFovLH(fov, AspectRatio, z_near, z_far);
	}

	Blob3D@ getTarget() {return @this.targetBlob;}
	void setTarget(Blob3D@ _blob) {@this.targetBlob = _blob; }
	void setLocked(bool _locked) {this.locked = _locked;}

	void setPosition(Vec3f _pos) {this.transform.Position = _pos;}
	Vec3f getPosition() {return this.transform.Position;}

	//Vec3f getInterpolatedPosition() {return this.old_pos.Lerp(this.pos, getRenderApproximateCorrectionFactor());}

	void setRotation(Vec3f _dir)
	{
		this.transform.Orientation.x = _dir.x;
		this.transform.Orientation.y = _dir.y;
		this.transform.Orientation.z = _dir.z;
	}

	void setRotation(float x, float y, float z)
	{
		this.transform.Orientation.x = x;
		this.transform.Orientation.y = y;
		this.transform.Orientation.z = z;
	}
	Vec3f getRotation() {return this.transform.Orientation.getXYZ();}

	Vec3f getDirection()
	{
		if (this.targetBlob !is null)
		{
			return (this.targetBlob.getRenderPosition() + Vec3f(0.0f, pos_offset.y, 0.0f) - this.getPosition()).Normalize();
		}

		Vec3f forward(0.0f, 0.0f, 1.0f);
		forward.yzRotateBy(getRotation().y);
		forward.xzRotateBy(getRotation().x);
		return forward.Normalize();
	}

	void onTick() {}
	
	void render_update()
	{
		updateSharkCamera();
		updateViewMatrix();
	}

	void updateSharkCamera()
	{
		if (this.targetBlob is null || this.targetBlob.ownerBlob is null || this.targetBlob.ownerBlob.getName() != "shark")
			return;

		CBlob@ shark = this.targetBlob.ownerBlob;
		f32 amount = Maths::Clamp01(getRules().get_f32("interFrameTime"));
		f32 dirDelta = shark.get_f32("dir_x") - shark.get_f32("old_dir_x");
		while (dirDelta > 180.0f) dirDelta -= 360.0f;
		while (dirDelta < -180.0f) dirDelta += 360.0f;

		Vec3f dir;
		dir.x = -(shark.get_f32("old_dir_x") + dirDelta * amount);
		dir.y = Maths::Lerp(shark.get_f32("old_dir_y"), shark.get_f32("dir_y"), amount);
		dir.z = 0.0f;

		Vec3f off = pos_offset;
		off.yzRotateBy(dir.y);
		off.xzRotateBy(dir.x);

		Vec2f sharkPosition = shark.getInterpolatedPosition();
		f32 sharkY = Maths::Lerp(shark.get_f32("old_shark_y"), shark.get_f32("shark_y"), amount);
		this.setPosition(Vec3f(sharkPosition.x, sharkY, sharkPosition.y) + off);
		this.setRotation(-dir);
	}

	void updateViewMatrix()
	{
		if (this.targetBlob !is null)
		{
			if (this.targetBlob.ownerBlob !is null && this.targetBlob.ownerBlob.getName() == "shark")
			{
				CBlob@ shark = this.targetBlob.ownerBlob;
				Vec2f sharkPosition = shark.getInterpolatedPosition();
				f32 sharkY = Maths::Lerp(shark.get_f32("old_shark_y"), shark.get_f32("shark_y"), Maths::Clamp01(getRules().get_f32("interFrameTime")));
				view.CreateLookAt(this.getPosition(), Vec3f(sharkPosition.x, sharkY + pos_offset.y, sharkPosition.y), Vec3f(0,1,0));
			}
			else
			{
				view.CreateLookAt(this.getPosition(), this.targetBlob.getRenderPosition()+Vec3f(0,pos_offset.y,0), Vec3f(0,1,0));
			}
		}
		else
		{
			view.CreateLookAt(getPosition(), getPosition() + getDirection(), Vec3f(0,1,0));
		}	
	}

	Ray GetRayFromScreenPoint(float screenX, float screenY)
    {
    	Driver@ driver = getDriver();
        const f32 Width = driver.getScreenWidth(); 
		const f32 Height = driver.getScreenHeight();
		const f32 ScaleFactorX = driver.getScreenWidthRatio();
		const f32 ScaleFactorY = driver.getScreenHeightRatio();

        // Normalized Device Coordinates Top-Left (-1, 1) to Bottom-Right (1, -1)
        float x = (2.0f * screenX) / (Width / ScaleFactorX) - 1.0f;
        float y = 1.0f - (2.0f * screenY) / (Height / ScaleFactorY);
        float z = 1.0f;
        Vec3f deviceCoords = Vec3f(x, y, z);

        // Clip Coordinates
        Vec4f clipCoords = Vec4f(deviceCoords.x, deviceCoords.y, 1.0f, 1.0f);

        // View Coordinates
        MatrixR invProj = MatrixR(this.projection.Array);
        invProj.Invert();
        Vec4f viewCoords = invProj.Transform(clipCoords);
        viewCoords.z = 1.0f;
        viewCoords.w = 0.0f;

        MatrixR invView = MatrixR(view.Array);
        invView.Invert();
        Vec3f worldCoords = invView.Transform(viewCoords).getXYZ();
        worldCoords = worldCoords.Normalize();

        return Ray(this.transform.Position, worldCoords);
    }
}

float getInterGameTime()
{
	return getRules().get_f32("interGameTime");
}

float getInterFrameTime()
{
	return getRules().get_f32("interFrameTime");
}
