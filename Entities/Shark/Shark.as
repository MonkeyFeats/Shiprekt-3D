#include "WaterEffects.as"
#include "Booty.as"
#include "AccurateSoundPlay.as"
#include "HumanCommon.as"
#include "Blob3D.as"
#include "Camera3D.as"

const f32 SHARK_SPEED = 4.5f;
const f32 SHARK_CRUISE_SPEED = 1.2f;
const f32 SHARK_COAST = 0.94f;
const f32 SHARK_VERTICAL_SPEED = 3.4f;
const f32 SHARK_CRUISE_VERTICAL_SPEED = 0.8f;
const f32 SHARK_ACCEL = 0.18f;
const f32 SHARK_TURN_SPEED = 7.5f;
const f32 SHARK_PITCH_TURN_SPEED = 5.0f;
const f32 SHARK_MIN_INPUT_SPEED_FACTOR = 0.12f;
const f32 SHARK_DASH_SPEED = 9.0f;
const f32 SHARK_DASH_VERTICAL_SPEED = 4.0f;
const f32 SHARK_DASH_DURATION = 12.0f;
const f32 SHARK_DASH_COOLDOWN = 36.0f;
const f32 SHARK_TAIL_BASE_AMP = 4.0f;
const f32 SHARK_TAIL_SPEED_AMP = 14.0f;
const f32 SHARK_TAIL_DASH_AMP = 22.0f;
const f32 SHARK_TAIL_BASE_FREQ = 0.16f;
const f32 SHARK_TAIL_SPEED_FREQ = 0.09f;
const f32 SHARK_TAIL_DASH_FREQ = 0.32f;
const f32 SHARK_CAMERA_HEIGHT = 12.0f;
const f32 SHARK_MIN_HEIGHT = -18.0f;
const f32 SHARK_MAX_HEIGHT = 40.0f;
const f32 SHARK_RENDER_SCALE = 1.0f;
const f32 SHARK_BODY_Y_OFFSET = -0.85f;
const string SHARK_JAW_CHILD = "shark_jaw";
const string SHARK_TAIL_CHILD = "shark_tail";

void onInit( CBlob@ this )
{
	//find target to swim towards
	this.set_Vec2f("target", getTargetVel( this ) * 0.5f);
	
	this.set_bool("retreating", false);

	CSprite@ sprite = this.getSprite();
	sprite.SetZ(-10.0f);
	sprite.ReloadSprites(0,0); //always blue
	sprite.SetAnimation("out");
	this.SetVisible(false);

	this.set_u8("ID", 57);
	this.Untag("prop");

	this.addCommandID(camera_sync_cmd);
	this.set_f32("dir_x", 0.0f);
	this.set_f32("dir_y", 0.0f);
	this.set_f32("old_dir_x", 0.0f);
	this.set_f32("old_dir_y", 0.0f);
	this.set_f32("shark_yaw", 0.0f);
	this.set_f32("shark_pitch", 0.0f);
	this.set_f32("old_shark_yaw", 0.0f);
	this.set_f32("old_shark_pitch", 0.0f);
	this.set_f32("shark_tail_phase", 0.0f);
	this.set_f32("shark_tail_yaw", 0.0f);
	this.set_f32("old_shark_tail_yaw", 0.0f);
	this.set_f32("shark_dash_ticks", 0.0f);
	this.set_f32("shark_dash_cooldown", 0.0f);
	this.set_f32("eye height", -0.15f);
	this.set_f32("FOV", 12.0f);
	this.set_f32("shark_y", SHARK_CAMERA_HEIGHT);
	this.set_f32("old_shark_y", SHARK_CAMERA_HEIGHT);
	this.set_f32("shark_vel_y", 0.0f);

	SetupSharkBlob3D(this);
	
	this.SetMapEdgeFlags( u8(CBlob::map_collide_up) |
	u8(CBlob::map_collide_down) |
	u8(CBlob::map_collide_sides) );
}

Vec3f Shark3DPosition(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	return Vec3f(pos.x, this.get_f32("shark_y"), pos.y);
}

f32 SharkYaw(CBlob@ this)
{
	return this.get_f32("shark_yaw");
}

f32 SharkPitch(CBlob@ this)
{
	return this.get_f32("shark_pitch");
}

f32 SharkCameraYaw(CBlob@ this)
{
	return -this.get_f32("dir_x");
}

Vec3f SharkDirection(f32 yaw, f32 pitch)
{
	Vec3f forward(0.0f, 0.0f, 1.0f);
	forward.yzRotateBy(pitch);
	forward.xzRotateBy(yaw);
	return forward.Normalize();
}

Vec3f SharkBodyDirection(CBlob@ this)
{
	return SharkDirection(SharkYaw(this), SharkPitch(this));
}

f32 NormalizeAngle(f32 angle)
{
	while (angle > 180.0f) angle -= 360.0f;
	while (angle < -180.0f) angle += 360.0f;
	return angle;
}

f32 ApproachAngle(f32 current, f32 target, f32 amount)
{
	f32 delta = NormalizeAngle(target - current);
	delta = Maths::Clamp(delta, -amount, amount);
	return NormalizeAngle(current + delta);
}

f32 SharkInputYawOffset(bool forward, bool back, bool left, bool right)
{
	if (forward)
	{
		if (left) return 45.0f;
		if (right) return -45.0f;
		return 0.0f;
	}

	if (back)
	{
		if (left) return 135.0f;
		if (right) return -135.0f;
		return 180.0f;
	}

	if (left) return 90.0f;
	if (right) return -90.0f;
	return 0.0f;
}

Vec3f SharkInputDirection(CBlob@ this, bool forward, bool back, bool left, bool right)
{
	f32 targetYaw = SharkCameraYaw(this) + SharkInputYawOffset(forward, back, left, right);
	f32 targetPitch = 0.0f;

	if (forward)
	{
		targetPitch = this.get_f32("dir_y");
	}
	else if (back)
	{
		targetPitch = -this.get_f32("dir_y");
	}

	return SharkDirection(targetYaw, Maths::Clamp(targetPitch, -65.0f, 65.0f));
}

void SteerShark(CBlob@ this, bool forward, bool back, bool left, bool right)
{
	if (!forward && !back && !left && !right)
		return;

	f32 yaw = SharkYaw(this);
	f32 pitch = SharkPitch(this);
	f32 targetYaw = SharkCameraYaw(this) + SharkInputYawOffset(forward, back, left, right);
	f32 targetPitch = 0.0f;

	if (forward)
	{
		targetPitch = this.get_f32("dir_y");
	}
	else if (back)
	{
		targetPitch = -this.get_f32("dir_y");
	}

	this.set_f32("shark_yaw", ApproachAngle(yaw, targetYaw, SHARK_TURN_SPEED));
	this.set_f32("shark_pitch", ApproachAngle(pitch, Maths::Clamp(targetPitch, -65.0f, 65.0f), SHARK_PITCH_TURN_SPEED));
}

void ApplySharkMeshSettings(SMesh@ mesh)
{
	if (mesh is null)
		return;

	SMaterial@ material = mesh.GetMaterial();
	if (material is null)
		return;

	material.AddTexture("RGB_Alpha.png", 0);
	material.SetFlag(SMaterial::LIGHTING, false);
	material.SetFlag(SMaterial::BILINEAR_FILTER, false);
	material.SetLayerBilinearFilter(0, false);
	material.SetMaterialType(SMaterial::SOLID);
	mesh.SetMaterial(material);
}

void LoadSharkObjMesh(SMesh@ mesh, const string &in objPath)
{
	if (mesh is null)
		return;

	mesh.LoadObjIntoMesh(objPath);
	mesh.SetHardwareMapping(SMesh::STATIC);
	ApplySharkMeshSettings(mesh);
	mesh.BuildMesh();
}

void AddSharkChild(Blob3D@ shark, const string &in name, const string &in objPath, Vec3f localPosition, Vec3f localRotation)
{
	if (shark is null)
		return;

	Blob3D child(localPosition, shark.getTeamNum(), 1.0f);
	if (child !is null)
	{
		child.Name = name;
		LoadSharkObjMesh(child.mesh, objPath);
		child.HasMesh = true;
		child.renderScale = SHARK_RENDER_SCALE;
		child.transform.Orientation.y = localRotation.x;
		child.transform.Orientation.x = localRotation.y;
		child.transform.Orientation.z = localRotation.z;
		shark.AddChild(@child);
	}
}

Vec3f SharkScaledOffset(f32 x, f32 y, f32 z)
{
	return Vec3f(x * SHARK_RENDER_SCALE, y * SHARK_RENDER_SCALE, z * SHARK_RENDER_SCALE);
}

void SetSharkChildPitch(Blob3D@ shark, const string &in childName, f32 pitch)
{
	if (shark is null)
		return;

	Blob3D@ child = shark.getChild(childName);
	if (child !is null)
	{
		child.LocalTransform.Orientation.y = pitch;
	}
}

void SetSharkTailYaw(Blob3D@ shark, f32 yaw)
{
	if (shark is null)
		return;

	Blob3D@ tail = shark.getChild(SHARK_TAIL_CHILD);
	if (tail !is null)
	{
		tail.LocalTransform.Orientation.x = yaw;
	}
}

void UpdateSharkChildren(Blob3D@ shark, f32 pitch, f32 tailYaw)
{
	SetSharkChildPitch(shark, SHARK_JAW_CHILD, pitch);
	SetSharkChildPitch(shark, SHARK_TAIL_CHILD, pitch);
	SetSharkTailYaw(shark, tailYaw);
}

void UpdateSharkTail(CBlob@ this, f32 speedFactor, f32 dashFactor)
{
	f32 phase = this.get_f32("shark_tail_phase");
	phase += SHARK_TAIL_BASE_FREQ + SHARK_TAIL_SPEED_FREQ * speedFactor + SHARK_TAIL_DASH_FREQ * dashFactor;

	f32 amp = SHARK_TAIL_BASE_AMP + SHARK_TAIL_SPEED_AMP * speedFactor + SHARK_TAIL_DASH_AMP * dashFactor;
	this.set_f32("shark_tail_phase", phase);
	this.set_f32("shark_tail_yaw", Maths::Sin(phase) * amp);
}

void SetupSharkMeshes(Blob3D@ blob3d)
{
	if (blob3d is null || !getNet().isClient())
		return;

	blob3d.Name = "shark_body";
	LoadSharkObjMesh(blob3d.mesh, "SharkBody.obj");
	blob3d.HasMesh = true;
	blob3d.renderScale = SHARK_RENDER_SCALE;
	blob3d.renderOffset = SharkScaledOffset(0.0f, SHARK_BODY_Y_OFFSET, 0.0f);
	AddSharkChild(blob3d, SHARK_JAW_CHILD, "SharkJaw.obj", SharkScaledOffset(0.0f, -6.104f, 21.235f), Vec3f(0.0f, 0.0f, 0.0f));
	AddSharkChild(blob3d, SHARK_TAIL_CHILD, "SharkTail.obj", SharkScaledOffset(0.0f, 0.0f, -14.479f), Vec3f(0.0f, 0.0f, 0.0f));
}

void SetupSharkBlob3D(CBlob@ this)
{
	Blob3D blob3d(this, Shark3DPosition(this), this.getTeamNum(), this.getHealth());
	if (blob3d !is null)
	{
		SetupSharkMeshes(@blob3d);
		blob3d.transform.Orientation.x = SharkYaw(this);
		blob3d.transform.Orientation.y = SharkPitch(this);
		UpdateSharkChildren(@blob3d, SharkPitch(this), this.get_f32("shark_tail_yaw"));
		this.set("blob3d", @blob3d);
	}
}

void UpdateSharkBlob3D(CBlob@ this)
{
	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d) || blob3d is null)
	{
		SetupSharkBlob3D(this);
		return;
	}

	Vec3f position = Shark3DPosition(this);
	blob3d.setPosition(position);
	blob3d.transform.Orientation.x = SharkYaw(this);
	blob3d.transform.Orientation.y = SharkPitch(this);
	blob3d.renderOffset = SharkScaledOffset(0.0f, SHARK_BODY_Y_OFFSET, 0.0f);
	UpdateSharkChildren(blob3d, SharkPitch(this), this.get_f32("shark_tail_yaw"));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID(camera_sync_cmd))
	{
		HandleCamera(this, params, !canSend(this));
	}
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void onTick( CBlob@ this )
{
	this.SetVisible(false);
	this.set_f32("old_dir_x", this.get_f32("dir_x"));
	this.set_f32("old_dir_y", this.get_f32("dir_y"));
	this.set_f32("old_shark_y", this.get_f32("shark_y"));
	this.set_f32("old_shark_yaw", SharkYaw(this));
	this.set_f32("old_shark_pitch", SharkPitch(this));
	this.set_f32("old_shark_tail_yaw", this.get_f32("shark_tail_yaw"));
	UpdateSharkBlob3D(this);

	Vec2f pos = this.getPosition();	
	CMap@ map = getMap();
	Tile tile = map.getTile( pos );
	bool onLand = map.isTileBackgroundNonEmpty( tile ) || map.isTileSolid( tile );
	
	if ( onLand )
		this.set_bool("retreating", true);

	if (this.getPlayer() is null)
	{
		u32 ticktime = (getGameTime() + this.getNetworkID());

		if(ticktime % 5 == 0 && //check each 5 ticks
			this.hasTag("vanish") && //read tag
			getGameTime() > this.get_u32("vanishtime")) //compare time
		{
			this.Tag("no gib");
			this.server_Die();
			return;
		}
		if( ticktime % 40 == 0 )
		{
			this.set_Vec2f("target", getTargetVel( this ));
		}
		
		if ( !this.get_bool("retreating") )
			MoveTo( this, this.get_Vec2f("target") );
		else
		{
			MoveTo( this, -this.get_Vec2f("target") );
			this.Tag("vanish");
		}
	}
	else
	{		
		// player
		Vec2f vel = this.getVelocity() * SHARK_COAST;
		f32 velY = this.get_f32("shark_vel_y") * SHARK_COAST;
		const bool forward = this.isKeyPressed(key_up);
		const bool back = this.isKeyPressed(key_down);
		const bool left = this.isKeyPressed(key_left);
		const bool right = this.isKeyPressed(key_right);
		const bool moving = forward || back || left || right;

		SteerShark(this, forward, back, left, right);

		Vec3f bodyForward = SharkBodyDirection(this);
		f32 dashTicks = Maths::Max(0.0f, this.get_f32("shark_dash_ticks") - 1.0f);
		f32 dashCooldown = Maths::Max(0.0f, this.get_f32("shark_dash_cooldown") - 1.0f);
		bool canDash = this.isKeyJustPressed(key_action1) && dashCooldown <= 0.0f;
		if (this.isMyPlayer())
		{
			canDash = canDash && !getHUD().hasButtons() && !getHUD().hasMenus();
		}
		if (canDash)
		{
			dashTicks = SHARK_DASH_DURATION;
			dashCooldown = SHARK_DASH_COOLDOWN;
			vel += Vec2f(bodyForward.x, bodyForward.z) * (SHARK_DASH_SPEED * 0.65f);
			velY += bodyForward.y * (SHARK_DASH_VERTICAL_SPEED * 0.65f);
		}

		f32 dashFactor = Maths::Clamp01(dashTicks / SHARK_DASH_DURATION);
		f32 inputSpeedFactor = 0.0f;
		if (moving)
		{
			Vec3f inputDirection = SharkInputDirection(this, forward, back, left, right);
			inputSpeedFactor = Maths::Clamp01((bodyForward.Dot(inputDirection) + 0.15f) / 1.15f);
			inputSpeedFactor = SHARK_MIN_INPUT_SPEED_FACTOR + (1.0f - SHARK_MIN_INPUT_SPEED_FACTOR) * inputSpeedFactor * inputSpeedFactor;
		}

		f32 targetSpeed = SHARK_CRUISE_SPEED + SHARK_SPEED * inputSpeedFactor + SHARK_DASH_SPEED * dashFactor;
		f32 targetVerticalSpeed = SHARK_CRUISE_VERTICAL_SPEED + SHARK_VERTICAL_SPEED * inputSpeedFactor + SHARK_DASH_VERTICAL_SPEED * dashFactor;
		Vec2f targetVel = Vec2f(bodyForward.x, bodyForward.z) * targetSpeed;
		f32 targetVelY = bodyForward.y * targetVerticalSpeed;
		vel += (targetVel - vel) * SHARK_ACCEL;
		velY += (targetVelY - velY) * SHARK_ACCEL;
		f32 speedFactor = Maths::Clamp01((vel.getLength() + Maths::Abs(velY)) / (SHARK_CRUISE_SPEED + SHARK_SPEED + SHARK_DASH_SPEED));
		UpdateSharkTail(this, speedFactor, dashFactor);
		this.set_f32("shark_dash_ticks", dashTicks);
		this.set_f32("shark_dash_cooldown", dashCooldown);

		this.setVelocity( vel );
		this.set_f32("shark_y", Maths::Clamp(this.get_f32("shark_y") + velY, SHARK_MIN_HEIGHT, SHARK_MAX_HEIGHT));
		this.set_f32("shark_vel_y", velY);

		this.setAngleDegrees( SharkYaw(this) );
		UpdateSharkBlob3D(this);

		//Vec2f pos = this.getPosition();	
		// water effect
		//if( (getGameTime() + this.getNetworkID()) % 9 == 0){
		//	MakeWaterWave(pos, Vec2f_zero, -angle + (_anglerandom.NextRanged(100) > 50 ? 180 : 0)); 
		//}

		//MoveTo( this, vel );

		if (this.isMyPlayer())
		{
			ManageCamera(this);	

		    if (getHUD().hasButtons())
		    {
		        if (this.isKeyJustPressed(key_action1))
		        {
				    CGridMenu @gmenu;
				    CGridButton @gbutton;
				    this.ClickGridMenu(0, gmenu, gbutton); 
			    }
			}
		}
		this.getSprite().SetAnimation("default");
	}
	
}

void ManageCamera(CBlob@ this)
{
	//if(this.isMyPlayer() && getNet().isClient())
	//{
		CControls@ c = getControls();
		Driver@ d = getDriver();
		bool ctrl = c.isKeyJustPressed(KEY_LCONTROL);
		if(ctrl){ this.set_bool("stuck", !this.get_bool("stuck")); this.Sync("stuck", true);}
		if(!this.get_bool("stuck") && d !is null && c !is null && !c.isMenuOpened() && !getHUD().hasButtons() && !getHUD().hasMenus())
		{
			Vec2f ScrMid = Vec2f(f32(d.getScreenWidth()) / 2, f32(d.getScreenHeight()) / 2);
			Vec2f dir = (c.getMouseScreenPos() - ScrMid)/10;
			float dirX = this.get_f32("dir_x");
			float dirY = this.get_f32("dir_y");
			dirX += dir.x;
			dirY = Maths::Clamp(dirY+dir.y,-65,65);

			this.set_f32("dir_x", dirX);
			this.set_f32("dir_y", dirY);
			c.setMousePosition(ScrMid);

			//Vec2f dir2 =  Vec2f((1080.0f/((1+dirY)%360))+8.0f,0); // i cant do math dont judge
    		//Vec2f aimPos = this.getPosition() - dir2.RotateBy(dirX);	
    		//this.set_Vec2f("aim_pos", aimPos);
		}
		if(getGameTime() % 2 == 0)
		{
			SyncCamera(this);
		}
	//}
}

//sprite update
void onTick( CSprite@ this )
{
	CBlob@ blob = this.getBlob();

	if(this.isAnimation("out") && this.isAnimationEnded())
		this.SetAnimation("default");

	if( blob.hasTag("vanish"))
		this.SetAnimation("in");
}

Random _anglerandom(0x9090); //clientside

void MoveTo( CBlob@ this, Vec2f moveVel )
{	
	
}

Vec2f getTargetVel( CBlob@ this )
{
	CBlob@[] blobsInRadius;
	Vec2f pos = this.getPosition();
	Vec2f target = this.getVelocity();
	int humansInWater = 0;
	if (getMap().getBlobsInRadius( pos, 150.0f, @blobsInRadius ))
	{
		f32 maxDistance = 9999999.9f;
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (!b.isOnGround() && b.getName() == "human")
			{
				humansInWater++;
				f32 dist = (pos - b.getPosition()).getLength();
				if (dist < maxDistance)
				{
					target = b.getPosition() - pos;
					maxDistance = dist;
				}
			}
		}
	}

	if (humansInWater == 0)
	{
		this.Tag("vanish");
		this.set_u32("vanishtime", getGameTime() + 15);
	}

	target.Normalize();
	return target;
}

void onDie( CBlob@ this )
{
	MakeWaterParticle(this.getPosition(), Vec2f_zero); 
}

void onCollision( CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1 )
{
	if (blob is null) {
		return;
	}

	if ( blob.getName() == "human" && !blob.get_bool( "onGround" ) )
	{
		MakeWaterParticle(point1, Vec2f_zero); 
		directionalSoundPlay( "ZombieBite", point1 );		
		blob.server_Die();
		this.server_Die();
	}
}

void onSetPlayer( CBlob@ this, CPlayer@ player )
{
	this.Untag( "vanish" );
	if (player !is null && player.isMyPlayer()) // setup camera to follow
	{
		CCamera@ camera = getCamera();
		camera.setRotation(0);
		camera.mousecamstyle = 1; // follow
		camera.targetDistance = 1.0f; // zoom factor
		camera.posLag = 5; // lag/smoothen the movement of the camera
		this.SetMinimapVars("GUI/Minimap/MinimapIcons.png", 0, Vec2f(8,8));
		client_AddToChat( "You are a shark now." );

		Camera3D@ camera3d;
		if (player.get("Camera3D", @camera3d) && camera3d !is null)
		{
			Blob3D@ blob3d;
			if (this.get("blob3d", @blob3d) && blob3d !is null)
			{
				camera3d.setTarget(blob3d);
			}
		}
	}
}


f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	if ( this.getHealth() - damage <= 0 && hitterBlob.getName() == "bullet" )
	{
		CPlayer@ owner = hitterBlob.getDamageOwnerPlayer();
		if ( owner !is null )
		{
			string pName = owner.getUsername();
			if ( owner.isMyPlayer() )
				directionalSoundPlay( "coinpick.ogg", worldPoint, 0.75f );

			if ( getNet().isServer() )
				server_setPlayerBooty( pName, server_getPlayerBooty( pName ) + 10 );
		}
	}
	
	return damage;
}
