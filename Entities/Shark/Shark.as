#include "WaterEffects.as"
#include "Booty.as"
#include "AccurateSoundPlay.as"
#include "HumanCommon.as"
#include "Blob3D.as"
#include "Camera3D.as"
#include "SharkCommon.as"

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
	InitSharkState(this);

	SetupSharkBlob3D(this);

	this.SetMapEdgeFlags( u8(CBlob::map_collide_up) |
	u8(CBlob::map_collide_down) |
	u8(CBlob::map_collide_sides) );
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
		child.renderScale = SharkVars::render_scale;
		child.transform.Orientation.y = localRotation.x;
		child.transform.Orientation.x = localRotation.y;
		child.transform.Orientation.z = localRotation.z;
		shark.AddChild(@child);
	}
}

Vec3f SharkScaledOffset(f32 x, f32 y, f32 z)
{
	return Vec3f(x * SharkVars::render_scale, y * SharkVars::render_scale, z * SharkVars::render_scale);
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

void SetSharkTailPose(Blob3D@ shark, f32 yaw, f32 pitch)
{
	if (shark is null)
		return;

	Blob3D@ tail = shark.getChild(SHARK_TAIL_CHILD);
	if (tail !is null)
	{
		tail.LocalTransform.Orientation.x = yaw;
		tail.LocalTransform.Orientation.y = pitch;
	}
}

void UpdateSharkChildren(Blob3D@ shark, f32 pitch, f32 tailYaw, f32 tailPitch)
{
	SetSharkChildPitch(shark, SHARK_JAW_CHILD, pitch);
	SetSharkChildPitch(shark, SHARK_TAIL_CHILD, pitch);
	SetSharkTailPose(shark, tailYaw, pitch + tailPitch);
}

void SetupSharkMeshes(Blob3D@ blob3d)
{
	if (blob3d is null || !getNet().isClient())
		return;

	blob3d.Name = "shark_body";
	LoadSharkObjMesh(blob3d.mesh, "SharkBody.obj");
	blob3d.HasMesh = true;
	blob3d.renderScale = SharkVars::render_scale;
	blob3d.renderOffset = SharkScaledOffset(0.0f, SharkVars::body_y_offset, 0.0f);
	AddSharkChild(blob3d, SHARK_JAW_CHILD, "SharkJaw.obj", SharkScaledOffset(0.0f, -6.104f, 21.235f), Vec3f(0.0f, 0.0f, 0.0f));
	AddSharkChild(blob3d, SHARK_TAIL_CHILD, "SharkTail.obj", SharkScaledOffset(0.0f, 0.0f, -14.479f), Vec3f(0.0f, 0.0f, 0.0f));
}

void SetupSharkBlob3D(CBlob@ this)
{
	Blob3D blob3d(this, Shark3DPosition(this), this.getTeamNum(), this.getHealth());
	if (blob3d !is null)
	{
		SharkInfo@ info = GetSharkInfo(this);
		SetupSharkMeshes(@blob3d);
		blob3d.transform.Orientation.x = info.yaw;
		blob3d.transform.Orientation.y = info.pitch;
		UpdateSharkChildren(@blob3d, info.pitch, info.tail_yaw, info.tail_pitch);
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
	SharkInfo@ info = GetSharkInfo(this);
	blob3d.setPosition(position);
	blob3d.transform.Orientation.x = info.yaw;
	blob3d.transform.Orientation.y = info.pitch;
	blob3d.renderOffset = SharkScaledOffset(0.0f, SharkVars::body_y_offset, 0.0f);
	UpdateSharkChildren(blob3d, info.pitch, info.tail_yaw, info.tail_pitch);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID(camera_sync_cmd))
	{
		HandleCamera(this, params, !canSend(this));
		ImportSharkCameraState(this, GetSharkInfo(this));
	}
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void onTick( CBlob@ this )
{
	this.SetVisible(false);
	StoreOldSharkState(this);
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
		UpdatePlayerSharkMovement(this);
		UpdateSharkBlob3D(this);

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
			SharkInfo@ info = GetSharkInfo(this);
			info.dir_x += dir.x;
			info.dir_y = Maths::Clamp(info.dir_y + dir.y, -65, 65);

			PublishSharkRenderState(this, info);
			c.setMousePosition(ScrMid);

			//Vec2f dir2 =  Vec2f((1080.0f/((1+dirY)%360))+8.0f,0); // i cant do math dont judge
			//Vec2f aimPos = this.getPosition() - dir2.RotateBy(dirX);
    		//this.set_Vec2f("aim_pos", aimPos);
		}
		if(getGameTime() % 2 == 0)
		{
			PublishSharkRenderState(this, GetSharkInfo(this));
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
