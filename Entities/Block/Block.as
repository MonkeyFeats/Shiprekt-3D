#include "IslandsCommon.as"
#include "BlockCommon.as"
#include "MakeDustParticle.as"
#include "AccurateSoundPlay.as"
#include "SAT_Shapes.as"
#include "MeshCache.as"
#include "TeamColour.as"
#include "Particle3D.as"

u8 DAMAGE_FRAMES = 3;
const string BLOCK_3D_DAMAGE_FRAME_KEY = "block 3d damage frame";
const string CORE_CRYSTAL_PARTICLE_TIME_KEY = "core crystal particle time";
const string CORE_CRYSTAL_RENDER_TEAM_KEY = "core crystal render team";
const string CORE_CRYSTAL_TEXTURE_NAME = "BlockTextures.png";
// onInit: called from engine after blob is created with server_CreateBlob()

void onInit( CBlob@ this )
{
	CSprite @sprite = this.getSprite();
	CShape @shape = this.getShape();
	sprite.asLayer().SetLighting( false );
	sprite.SetZ(510.0f);
	//shape.getConsts().net_threshold_multiplier = -1.0f;
	this.SetMapEdgeFlags( u8(CBlob::map_collide_none) | u8(CBlob::map_collide_nodeath) );

	
	Blob3D blob3d(Vec3f(this.getPosition().x, 0, this.getPosition().y), 6, 2.0f);
	if ( blob3d !is null )
	{	
		//@blob3d.rb = RigidBody();
		//blob3d.rb.Init(@blob3d);


		this.set("blob3d", @blob3d);
	}

}

bool Uses3DDamageFrames(const int blockType)
{
	return blockType == Block::SOLID || Block::isPlatform(blockType);
}

u8 Get3DDamageFrame(CBlob@ this)
{
	if (this is null)
		return 0;

	const f32 initHealth = this.getInitialHealth();
	if (initHealth <= 0.0f)
		return 0;

	const f32 healthPercent = Maths::Clamp01(this.getHealth() / initHealth);
	if (healthPercent > 0.75f)
		return 0;
	if (healthPercent > 0.50f)
		return 1;
	if (healthPercent > 0.25f)
		return 2;
	return 3;
}

string Get3DDamageMeshPath(const int blockType, const u8 frame)
{
	if (Block::isPlatform(blockType))
		return frame == 0 ? "Floor.obj" : "FloorDamage" + frame + ".obj";

	return frame == 0 ? "SolidWall.obj" : "SolidWallDamage" + frame + ".obj";
}

string Get3DDamageMeshKey(const int blockType, const u8 frame)
{
	return (Block::isPlatform(blockType) ? "floor" : "solid") + "_damage_" + frame;
}

void Apply3DDamageMesh(CBlob@ this, const u8 frame)
{
	if (this is null)
		return;

	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d) || blob3d is null)
		return;

	const int blockType = Block::getType(this);
	if (!Uses3DDamageFrames(blockType))
		return;

	if (this.exists(BLOCK_3D_DAMAGE_FRAME_KEY) && this.get_u8(BLOCK_3D_DAMAGE_FRAME_KEY) == frame && blob3d.HasMesh)
		return;

	MeshCacheOptions options;
	options.lighting = false;
	SMesh@ mesh = MeshCache::GetOrLoadObj(Get3DDamageMeshKey(blockType, frame), Get3DDamageMeshPath(blockType, frame), options);
	if (mesh is null)
		return;

	@blob3d.mesh = mesh;
	blob3d.HasMesh = true;
	this.set_u8(BLOCK_3D_DAMAGE_FRAME_KEY, frame);
}

void Refresh3DDamageMesh(CBlob@ this)
{
	if (this is null)
		return;

	const int blockType = Block::getType(this);
	if (!Uses3DDamageFrames(blockType))
		return;

	Apply3DDamageMesh(this, Get3DDamageFrame(this));
}

void ApplyBlockObjMaterialSettings(SMesh@ mesh)
{
	if (mesh is null)
		return;

	SMaterial@ meshMaterial = mesh.GetMaterial();
	if (meshMaterial is null)
		return;

	meshMaterial.SetFlag(SMaterial::LIGHTING, false);
	meshMaterial.SetFlag(SMaterial::BILINEAR_FILTER, false);
	meshMaterial.SetLayerBilinearFilter(0, false);
}

void LoadBlockObjMesh(SMesh@ mesh, const string &in objPath)
{
	if (mesh is null)
		return;

	mesh.LoadObjIntoMesh(objPath);
	mesh.SetHardwareMapping(SMesh::STATIC);
	ApplyBlockObjMaterialSettings(mesh);
	mesh.BuildMesh();
}

SColor GetCoreCrystalColor(const int teamNum)
{
	SColor teamColor = getTeamColor(teamNum);
	teamColor.setAlpha(135);
	return teamColor;
}

u8 MixChannelWithWhite(const u8 channel, const f32 whiteMix)
{
	return u8(Maths::Clamp(Maths::Round(Maths::Lerp(f32(channel), 255.0f, whiteMix)), 0, 255));
}

SColor GetCoreCrystalParticleColor(const int teamNum, const u8 alpha, const f32 whiteMix)
{
	SColor color = GetCoreCrystalColor(teamNum);
	return SColor(
		alpha,
		MixChannelWithWhite(color.getRed(), whiteMix),
		MixChannelWithWhite(color.getGreen(), whiteMix),
		MixChannelWithWhite(color.getBlue(), whiteMix)
	);
}

void BuildCoreCrystalColoredMesh(SMesh@ mesh, const int teamNum)
{
	if (mesh is null)
		return;

	Vec3f[] points = {
		Vec3f(0.000000f, 9.000000f, -3.703592f),
		Vec3f(2.679945f, 12.163817f, -1.656297f),
		Vec3f(-1.023648f, 14.119164f, -1.656297f),
		Vec3f(-3.312594f, 9.000000f, -1.656297f),
		Vec3f(-1.023648f, 3.880836f, -1.656297f),
		Vec3f(2.679944f, 5.836182f, -1.656297f),
		Vec3f(3.312594f, 9.000000f, 1.656297f),
		Vec3f(1.023648f, 14.119165f, 1.656297f),
		Vec3f(-2.679945f, 12.163817f, 1.656297f),
		Vec3f(-2.679944f, 5.836182f, 1.656297f),
		Vec3f(1.023648f, 3.880836f, 1.656297f),
		Vec3f(0.000000f, 9.000000f, 3.703592f)
	};
	Vec2f[] uvs = {
		Vec2f(0.106034f, 0.439268f),
		Vec2f(0.087580f, 0.467250f),
		Vec2f(0.002091f, 0.490685f),
		Vec2f(0.012134f, 0.439268f),
		Vec2f(0.002091f, 0.387852f),
		Vec2f(0.087580f, 0.411287f),
		Vec2f(0.069127f, 0.439268f),
		Vec2f(0.059084f, 0.490685f),
		Vec2f(0.030588f, 0.467250f),
		Vec2f(0.030588f, 0.411287f),
		Vec2f(0.059084f, 0.387852f),
		Vec2f(0.049041f, 0.439268f),
		Vec2f(0.116077f, 0.490685f),
		Vec2f(0.126120f, 0.439268f),
		Vec2f(0.116077f, 0.387852f)
	};
	u8[] faces = {
		0, 2, 1, 0, 3, 2, 0, 4, 3, 0, 5, 4, 0, 1, 5,
		1, 2, 7, 2, 3, 8, 3, 4, 9, 4, 5, 10, 5, 1, 6,
		1, 7, 6, 2, 8, 7, 3, 9, 8, 4, 10, 9, 5, 6, 10,
		6, 7, 11, 7, 8, 11, 8, 9, 11, 9, 10, 11, 10, 6, 11
	};
	u8[] faceUVs = {
		0, 12, 1, 0, 13, 12, 0, 14, 13, 0, 5, 14, 0, 1, 5,
		1, 12, 7, 2, 3, 8, 3, 4, 9, 4, 5, 10, 14, 1, 6,
		1, 7, 6, 2, 8, 7, 3, 9, 8, 4, 10, 9, 5, 6, 10,
		6, 7, 11, 7, 8, 11, 8, 9, 11, 9, 10, 11, 10, 6, 11
	};

	SColor crystalColor = GetCoreCrystalColor(teamNum);
	Vertex[] vertices;
	u16[] indices;
	for (uint i = 0; i < faces.length(); i++)
	{
		Vec3f p = points[uint(faces[i])];
		Vec2f uv = uvs[uint(faceUVs[i])];
		vertices.push_back(Vertex(p.x, p.y, p.z, uv.x, uv.y, crystalColor));
		indices.push_back(u16(i));
	}

	mesh.SetVertex(vertices);
	mesh.SetIndices(indices);
	mesh.SetHardwareMapping(SMesh::DYNAMIC);
	mesh.BuildMesh();
	mesh.SetDirty(SMesh::VERTEX_INDEX);
}

void ApplyCoreCrystalMaterial(SMesh@ mesh, const int teamNum)
{
	if (mesh is null)
		return;

	SMaterial@ meshMaterial = SMaterial();
	if (meshMaterial is null)
		return;

	SColor teamColor = GetCoreCrystalColor(teamNum);
	meshMaterial.AddTexture(CORE_CRYSTAL_TEXTURE_NAME, 0);
	meshMaterial.DisableAllFlags();
	meshMaterial.SetFlag(SMaterial::LIGHTING, false);
	meshMaterial.SetFlag(SMaterial::COLOR_MASK, true);
	meshMaterial.SetFlag(SMaterial::COLOR_MATERIAL, true);
	meshMaterial.SetFlag(SMaterial::ZBUFFER, true);
	meshMaterial.SetFlag(SMaterial::ZWRITE_ENABLE, false);
	meshMaterial.SetFlag(SMaterial::FRONT_FACE_CULLING, false);
	meshMaterial.SetFlag(SMaterial::BACK_FACE_CULLING, false);
	//meshMaterial.SetFlag(SMaterial::GOURAUD_SHADING, true);
	meshMaterial.SetFlag(SMaterial::FOG_ENABLE, true);
	meshMaterial.SetFlag(SMaterial::BILINEAR_FILTER, false);
	meshMaterial.SetMaterialType(SMaterial::TRANSPARENT_ADD_COLOR);
	meshMaterial.SetZBufferCompareOperation(SMaterial::LESSEQUAL);
	meshMaterial.SetColorMask(SMaterial::RGB);
	//meshMaterial.SetColorMaterial(SMaterial::DIFFUSE_AND_AMBIENT);
	//meshMaterial.SetBlendOperation(SMaterial::ADD);
	//meshMaterial.SetAmbientColor(teamColor);
	meshMaterial.SetDiffuseColor(teamColor);
	//meshMaterial.SetEmissiveColor(teamColor);
	meshMaterial.SetThickness(2);
	meshMaterial.SetShininess(5);
	meshMaterial.SetLayerBilinearFilter(0, false);
	mesh.SetMaterial(meshMaterial);
}

void LoadCoreCrystalObjMesh(SMesh@ mesh, const int teamNum)
{
	if (mesh is null)
		return;

	BuildCoreCrystalColoredMesh(mesh, teamNum);
	ApplyCoreCrystalMaterial(mesh, teamNum);
}


void RefreshCoreCrystalMaterial(CBlob@ this)
{
	if (this is null || Block::getType(this) != Block::SHIPCORE)
		return;

	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d) || blob3d is null)
		return;

	for (uint i = 0; i < blob3d.Children.length(); ++i)
	{
		Blob3D@ child = blob3d.Children[i];
		if (child !is null && child.Name == "core_crystal")
		{
			LoadCoreCrystalObjMesh(child.mesh, this.getTeamNum());
			this.set_u8(CORE_CRYSTAL_RENDER_TEAM_KEY, this.getTeamNum());
		}
	}
}

void UpdateCoreCrystalAnimation(CBlob@ this, Blob3D@ blob3d)
{
	if (this is null || blob3d is null || Block::getType(this) != Block::SHIPCORE)
		return;

	Blob3D@ crystal = blob3d.getChild("core_crystal");
	if (crystal is null)
		return;

	const u8 teamNum = this.getTeamNum();
	if (!this.exists(CORE_CRYSTAL_RENDER_TEAM_KEY) || this.get_u8(CORE_CRYSTAL_RENDER_TEAM_KEY) != teamNum)
	{
		LoadCoreCrystalObjMesh(crystal.mesh, teamNum);
		this.set_u8(CORE_CRYSTAL_RENDER_TEAM_KEY, teamNum);
	}

	const f32 initHealth = Maths::Max(this.getInitialHealth(), 0.01f);
	const f32 healthPercent = Maths::Clamp01(this.getHealth() / initHealth);
	const f32 damagePercent = 1.0f - healthPercent;
	crystal.LocalTransform.Orientation.x += 1.0f + damagePercent * 6.0f;
	crystal.renderScale = 1.0f + Maths::Sin(getGameTime() * (0.12f + damagePercent * 0.28f)) * (0.025f + damagePercent * 0.10f);
}

void EmitCoreCrystalDamageParticles(CBlob@ this, Vec2f worldPoint, Vec2f velocity, const f32 damage)
{
	if (!getNet().isClient() || this is null || Block::getType(this) != Block::SHIPCORE || damage <= 0.0f)
		return;

	const u32 gameTime = getGameTime();
	if (this.exists(CORE_CRYSTAL_PARTICLE_TIME_KEY) && this.get_u32(CORE_CRYSTAL_PARTICLE_TIME_KEY) == gameTime)
		return;

	this.set_u32(CORE_CRYSTAL_PARTICLE_TIME_KEY, gameTime);

	Vec2f hitPos = worldPoint;
	if (hitPos.LengthSquared() <= 0.01f)
	{
		hitPos = this.getPosition();
	}

	Vec3f origin = GetRenderedParticlePosition(this, hitPos, 11.0f);
	Random random(gameTime * 733 + this.getNetworkID() * 17 + Maths::Round(damage * 31.0f));
	const int count = Maths::Clamp(5 + Maths::Round(damage * 6.0f), 6, 18);
	const f32 power = Maths::Clamp(0.75f + damage * 0.55f, 0.85f, 2.4f);

	for (int i = 0; i < count; i++)
	{
		Vec3f dir(random.NextFloat() - 0.5f, 0.25f + random.NextFloat() * 0.85f, random.NextFloat() - 0.5f);
		if (velocity.LengthSquared() > 0.01f)
		{
			dir.x += velocity.x * 0.025f;
			dir.z += velocity.y * 0.025f;
		}
		dir = dir.Normalize();

		const f32 whiteMix = 0.35f + random.NextFloat() * 0.45f;
		Particle3D@ shard = Particle3D(
			origin + dir * (0.5f + random.NextFloat() * 2.0f),
			dir * (1.4f + random.NextFloat() * 2.2f) * power,
			Vec3f(0.0f, -0.035f, 0.0f),
			12.0f + random.NextFloat() * 10.0f,
			1.6f + random.NextFloat() * 2.0f,
			0.0f,
			GetCoreCrystalParticleColor(this.getTeamNum(), 255, whiteMix),
			GetCoreCrystalParticleColor(this.getTeamNum(), 0, 0.65f)
		);
		shard.damping = 0.90f;
		shard.spin = (random.NextFloat() - 0.5f) * 28.0f;
		shard.stretch = 1.4f + random.NextFloat() * 1.0f;
		shard.facingMode = ParticleFace3D::CameraVelocity;
		EmitParticle3D(shard);
	}
}

//void onRender(CSprite@ this)
//{
//	Blob3D@ blob3d;
//	if (!this.get("blob3d", @blob3d)) { return; }
//	SAT_Shape@ sat_shape;
//	if (this.getBlob().get("SAT_Info", @sat_shape))
// 	sat_shape.Render();
//}

void onTick ( CBlob@ this )
{
	Blob3D@ blob3d;
	if (!this.get("blob3d", @blob3d)) { return; }

	//blob3d.onTick();

	CSprite@ thisSprite = this.getSprite();	
	UpdateCoreCrystalAnimation(this, blob3d);

	if (this.getTickSinceCreated() < 1) //accounts for time after block production
	{
		CRules@ rules = getRules();
		const int blockType = thisSprite.getFrame();
		const bool solid = Block::isSolid(blockType);

		switch (blockType)
		{
			case Block::PLATFORM:
			case Block::PLATFORM2:
			{
				blob3d.Name = "floor";
				Apply3DDamageMesh(this, 0);

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 0, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}
			case Block::RAM:
			case Block::SOLID:
			{				
				blob3d.Name = "solidblob";
				if (blockType == Block::SOLID)
				{
					Apply3DDamageMesh(this, 0);
				}
				else
				{
					LoadBlockObjMesh(blob3d.mesh, "SolidWall.obj");
					blob3d.HasMesh = true;
				}

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 16, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}	
			case Block::SEAT:
			{
				blob3d.Name = "seat";
				LoadBlockObjMesh(blob3d.mesh, "Seat.obj");
				blob3d.HasMesh = true;

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 16, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}
			case Block::COUPLING:
			{
				blob3d.Name = "coupling";
				LoadBlockObjMesh(blob3d.mesh, "Coupling.obj");
				blob3d.HasMesh = true;



				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 0, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}
			case Block::FLAK:
			case Block::HARPOON:
			case Block::CANNON:
			case Block::LAUNCHER:			
			{
				blob3d.Name = "flak";
				LoadBlockObjMesh(blob3d.mesh, "FlakBase.obj");
				blob3d.HasMesh = true;

				Blob3D FlakTopper(Vec3f(0), 6, 2.0f);
				if ( FlakTopper !is null )
				{	
					FlakTopper.Name = "flaktopper";
					LoadBlockObjMesh(FlakTopper.mesh, "FlakTopper.obj");
					FlakTopper.HasMesh = true;
					blob3d.AddChild(@FlakTopper);

					Blob3D FlakBarrel(Vec3f(0), 6, 2.0f);
					if ( FlakBarrel !is null )
					{	
						FlakBarrel.Name = "FlakBarrel";
						LoadBlockObjMesh(FlakBarrel.mesh, "FlakBarrel.obj");
						FlakBarrel.HasMesh = true;
						FlakTopper.AddChild(@FlakBarrel);
					}
				}

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 0, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}
			case Block::DOOR:
			case Block::STATION:
			{
				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 0, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}
			case Block::REPULSOR:
			{

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 16, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}	

			case Block::PROPELLER:	
			case Block::RAMENGINE:
			{				
				blob3d.Name = "propeller";
				LoadBlockObjMesh(blob3d.mesh, "Propeller.obj");
				blob3d.HasMesh = true;

				if (getNet().isClient())
				{
					Blob3D PropellerBlades(Vec3f(0, -8.0, 12.0), 6, 2.0f);
					if ( PropellerBlades !is null )
					{	
						PropellerBlades.Name = "propeller_blades";
						LoadBlockObjMesh(PropellerBlades.mesh, "PropellerBlades.obj");
						PropellerBlades.HasMesh = true;
						PropellerBlades.SpinAroundParentForward = true;
						blob3d.AddChild(@PropellerBlades);
					}
				}

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 16, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				break;
			}			
			case Block::SHIPCORE:
			{
				blob3d.Name = "core";
				LoadBlockObjMesh(blob3d.mesh, "CoreStand.obj");
				blob3d.HasMesh = true;

				Blob3D CoreCrystal();
				if ( CoreCrystal !is null )
				{
					CoreCrystal.Name = "core_crystal";
					LoadCoreCrystalObjMesh(CoreCrystal.mesh, this.getTeamNum());
					this.set_u8(CORE_CRYSTAL_RENDER_TEAM_KEY, this.getTeamNum());
					CoreCrystal.HasMesh = true;
					blob3d.AddChild(@CoreCrystal);
				}

				@blob3d.shape = BoundingBox(Vec3f(-8, -6.8, -8), Vec3f(8, 0, 8), blob3d.transform.Position);
				blob3d.shape.Init(@blob3d);
				blob3d.AddExtraShape(BoundingSphere(5.0f), Vec3f(0.0f, 10.0f, 0.0f));
				break;
			}
			//case BOMB:
			//case POINTDEFENSE:
			//case HARVESTER:
			//case :
			//
			//case MACHINEGUN:
			//case :
			//case :
			//case PROPBLADES1:
			//case PROPBLADES2:
		}

		if (blob3d.shape !is null)
		{
			blob3d.shape.setElasticity(Block::isSolidCollisionBlock(blockType) ? 0.55f : 0.12f);
			blob3d.shape.setFriction(Block::isPlatform(blockType) ? 0.05f : 0.18f);
		}
		for (uint i = 0; i < blob3d.ExtraShapes.length(); i++)
		{
			BoundingShape@ extraShape = blob3d.ExtraShapes[i];
			if (extraShape !is null)
			{
				extraShape.setElasticity(Block::isSolidCollisionBlock(blockType) ? 0.55f : 0.12f);
				extraShape.setFriction(Block::isPlatform(blockType) ? 0.05f : 0.18f);
			}
		}

		//if (Block::isCore(blockType))
		//{
		//	@blob3d.shape = SAT_Shape(this, 8, Vec3f(this.getPosition().x,0,this.getPosition().y), true, this.getMass(), true, this.getTeamNum());
		//}
		//else
		//{
		//	@blob3d.shape = SAT_Shape(this, square_Shape, Vec3f(this.getPosition().x,0,this.getPosition().y), true, 0, this.getMass(), solid, this.getTeamNum());
		//}

		u16 cost = Block::getCost( blockType );
				
		this.set_u8("ID", blockType);
		this.Tag("prop");				
		this.set_u32("cost", cost);
		
		this.set_f32("initial reclaim", this.getHealth());		
		if ( blockType == Block::STATION )
		{
			this.set_f32("current reclaim", 0.0f);
		}
		else
		{
			this.set_f32("current reclaim", this.getHealth());
		}
		
		//Set Owner
		if ( getNet().isServer() )
		{
			CBlob@ owner = getBlobByNetworkID( this.get_u16( "ownerID" ) );    
			if ( owner !is null )
			{
				this.set_string( "playerOwner", owner.getPlayer().getUsername() );
				this.Sync( "playerOwner", true );
			}
		}
	}
	
	//path predicted collisions
	const int color = this.getShape().getVars().customData;
	if ( color > 0 )
	{
		Island@ island = getIsland(color);
		if ( island !is null && !island.isStation )
		{
			//Vec2f vel = this.getVelocity();
			//if (vel.Length() > 0)
			//{
			//	Vec2f pos = this.getPosition();
			//	Vec2f MTV;
	        //    if (sat_shape.checkCollision(vel, MTV))
	        //    {
	        //        this.setPosition((pos + vel)-MTV);
	        //        sat_shape.Pos = V2toV3((pos + vel)-MTV);
	        //    }
	        //    else
	        //    {
	        //        this.setPosition(pos + vel);
	        //        sat_shape.Pos = V2toV3(pos + vel);
	        //    }
			//}			

			//shape.setAngle(-this.getAngleDegrees());

//			Vec2f velnorm = island.vel; 
//			const f32 vellen = velnorm.Normalize();				
//									
//				bool dontHitMore = false;
//			
//				//if( sat_shape.Overlapping )
//				{			
//					CBlob@ o = sat_shape.OtherBlob;
//					if (o !is null)
//					{
//						const int other_color = o.getShape().getVars().customData;
//							
//						if ( color != other_color )
//						{
//							if ( other_color > 0 )
//							{
//								Island@ other_island = getIsland(other_color);
//							
//								if ( other_island !is null )
//								{	
//									//CollisionResponse1( island, other_island, sat_shape);	
//								}
//							}
//						}						
//					}							
//				}
		}

		//blob3d.onTick();
	}

 	// push merged ships away from each other
	if ( this.get_bool( "colliding" ) == true )
		this.set_bool( "colliding", false ); 

	if ( !getNet().isServer() )	//awkward fix for blob team changes wiping up the frame state (rest on islands.as)
	{
		u8 frame = this.get_u8( "frame" );
		if ( thisSprite.getFrame() == 0 && frame != 0 )
			thisSprite.SetFrame( frame );
	}
}

void onChangeTeam(CBlob@ this, const int oldTeam)
{
	RefreshCoreCrystalMaterial(this);
}

// onCollision: called once from the engine when a collision happens; 
// blob is null when it is a tilemap collision

void onCollision( CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1 )
{
	if ( blob is null || this.hasTag( "noCollide" ) || blob.hasTag( "noCollide" ) )	return;

//	SAT_Shape@ sat_shape;
//	if (!this.get("SAT_Info", @sat_shape))
//	return;
//
	f32 this_health = this.getHealth();
	f32 other_health = blob.getHealth();
	f32 this_initialHealth = this.getInitialHealth();
	f32 other_initialHealth = blob.getInitialHealth();
	const int color = this.getShape().getVars().customData;
	const int other_color = blob.getShape().getVars().customData;
	if (color > 0 && other_color > 0 && color != other_color) // block vs block
	{
		Island@ island = getIsland(color);
		Island@ other_island = getIsland(other_color);
	
		const int blockType = this.getSprite().getFrame();
		const bool solid = Block::isSolid(blockType);
		const int other_blockType = blob.getSprite().getFrame();
		const bool other_solid = Block::isSolid(other_blockType);
		bool docking;
		bool ramming;

		if ( getNet().isServer() )
		{
			if ( Block::isPlatform( blockType ) && Block::destroysPlatformOnCollision( other_blockType ) )
			{
				Die( this );
				return;
			}

			if ( Block::isPlatform( other_blockType ) && Block::destroysPlatformOnCollision( blockType ) )
			{
				Die( blob );
				return;
			}
		}
		
		if ( island !is null && other_island !is null )
		{
			if ( island.vel.Length() < 0.01f && other_island.vel.Length() < 0.01f )
				return;
				
			docking = ( blockType == Block::COUPLING || other_blockType == Block::COUPLING ) 
								&& ( ( island.isMothership || other_island.isMothership ) || ( island.isStation || other_island.isStation ) )
								&& this.getTeamNum() == blob.getTeamNum()
								&& ( ( !island.isMothership && island.owner != "" ) || ( !other_island.isMothership && other_island.owner != "" ) );
								
			ramming = ( blockType == Block::RAM || other_blockType == Block::RAM
							|| blockType == Block::RAMENGINE || other_blockType == Block::RAMENGINE
							|| blockType == Block::SEAT || other_blockType == Block::SEAT
							|| blockType == Block::DOOR || other_blockType == Block::DOOR 
							|| blockType == Block::COUPLING || other_blockType == Block::COUPLING );
		}
		else
			docking = false;

		if ( getNet().isServer() && !docking && Block::isRigidHullBlock( blockType ) && Block::isRigidHullBlock( other_blockType ) )
		{
			return;
		}
			
		if ( island !is null && !docking && !ramming )
		{
			bool shouldCollide = true;
			for (uint b_iter = 0; b_iter < island.blocks.length; ++b_iter)
			{
				IslandBlock@ isle_block = island.blocks[b_iter];
				if(isle_block is null) continue;
//
				CBlob@ block = getBlobByNetworkID( isle_block.blobID );
				if(block is null) continue;
				
				if ( block.get_bool( "colliding" ) == true )
					shouldCollide = false;
			}
			
			if ( shouldCollide )
				this.set_bool( "colliding", true );		
			
			if ( this.get_bool( "colliding" ) == true )
			{
				//CollisionResponse1( island, other_island, sat_shape);
			}
		}		
		
		if (getNet().isServer() && !(blockType == Block::STATION || other_blockType == Block::STATION) )
		{
			if ( docking )//force island merge
				getRules().set_bool("dirty islands", true);
			else if ( blockType == Block::COUPLING || other_blockType == Block::COUPLING )//couplings don't deal damage
			{
				if ( blockType == Block::COUPLING )
					Die( this );
				
				if ( other_blockType == Block::COUPLING )
					Die( blob );
			}
			else if ( Block::isRepulsor( blockType ) || Block::isRepulsor( other_blockType ) )//repulsors don't deal damage
			{
				if ( Block::isRepulsor( blockType ) )
					Die( this );
				
				if ( Block::isRepulsor( other_blockType ) )
					Die( blob );
			}
			else
			{
				if ( blockType == Block::RAMENGINE )//ram engines deal slight damage
				{
					if ( blob.hasTag( "weapon" ) ) 
					{
						this.server_Hit( blob, point1, Vec2f_zero, 1.1f, 0, true );
					}
					else if ( other_blockType == Block::PROPELLER || other_blockType == Block::SOLID )
					{
						this.server_Hit( this, point1, Vec2f_zero, 0.45f, 0, true );
					}	
					else if ( other_blockType == Block::PLATFORM )
					{
						Die( blob );
					}				
					else
					{
						this.server_Hit( blob, point1, Vec2f_zero, 1.1f, 0, true );
					}
				}
				
				if ( blockType == Block::DOOR || other_blockType == Block::DOOR )//seats don't deal damage
				{
					if ( blockType == Block::DOOR )
						Die( this );
					
					if ( other_blockType == Block::DOOR )
						Die( blob );
				}
				
				if ( blockType == Block::SEAT || other_blockType == Block::SEAT )//seats don't deal damage
				{
					if ( blockType == Block::SEAT )
						Die( this );
					
					if ( other_blockType == Block::SEAT )
						Die( blob );
				}
//
				
				if ( Block::isBomb( blockType ) || Block::isBomb( other_blockType ) ) //bombs annihilate all
				{
					Die( this );
					Die( blob );
				}
				
				if ( blockType == Block::RAM )//Ram vs all
				{
					if ( other_blockType == Block::SHIPCORE)
					{
						blob.server_Hit( this, point1, Vec2f_zero, other_solid ? 0.75f : 0.37f, 0, true );
						Die( this );
					}
					else if ( other_blockType == Block::PROPELLER )
					{
						blob.server_Hit( this, point1, Vec2f_zero, 0.65f, 0, true );
					}
					else if ( other_blockType == Block::RAMENGINE )
					{
						blob.server_Hit( this, point1, Vec2f_zero, 0.65f, 0, true );
					}
					else if ( other_blockType == Block::SOLID || other_blockType == Block::RAM )
					{
						this.server_Hit( this, point1, Vec2f_zero, 0.65f, 0, true );
						blob.server_Hit( this, point1, Vec2f_zero, 0.65f, 0, true );
					}
					else if ( blob.hasTag( "weapon" ) )
					{
						if ( other_health >= this_health )
						{
							Die( this );
							this.server_Hit( blob, point1, Vec2f_zero, solid ? this_health : this_health/2.0f, 0, true );
						}
						else
						{
							Die( blob );
							blob.server_Hit( this, point1, Vec2f_zero, 2.0f, 0, true );
						}
					}
					else if (!other_solid && other_island !is null)
					{
						this.server_Hit( this, point1, Vec2f_zero, 1.1f, 0, true );
						Die( blob );
					}
					else 
						Die( blob );
				}
			}
		}
	}
	else if (other_color == 0 && color > 0)
	{
		int blockType = this.getSprite().getFrame();
		// solid block vs player
		if (Block::isSolid(blockType))
		{
			Vec2f pos = blob.getPosition();
			
			if ( getNet().isClient() && !blob.isAttached() && blob.getName() == "human" && blob.isMyPlayer() )
			{
				//kill by impact
				Island@ island = getIsland(color);
				if ( island !is null && this.getTeamNum() != blob.getTeamNum() && ( getGameTime() - blob.get_u32( "groundTouch time" ) < 15 )/*longer wasOnGround*/
					&& ( island.vel.LengthSquared() > 4.0f || Maths::Abs(island.angle_vel) > 1.75f || blob.getOldVelocity().LengthSquared() > 9.0f ) )
				{
//
					CPlayer@ player = blob.getPlayer();
					if ( player !is null )
					{
						player.client_ChangeTeam(44);//this makes the sv kill the playerblob (Respawning.as)
						blob.Tag( "dead" );
						CSprite@ sprite = blob.getSprite();
						if ( sprite !is null && !sprite.getVars().gibbed )//to mask the latency a bit
						{
							directionalSoundPlay( "SR_ManDeath" + ( XORRandom(4) + 1 ), pos );
							sprite.Gib();
						}
					}
				}
				
				//set position collision
				//blob.setPosition( pos + normal * -blob.getRadius() * 0.55f );
			}
		}
	}
}

void CollisionResponse1( Island@ island, Island@ other_island, BoundingShape@ shape)
{
	if ( island is null || other_island is null )
		return;
		
	if ( island.mass <= 0 || other_island.mass <= 0 )
		return;
	
	Vec2f velnorm = island.vel; 
	const f32 vellen = velnorm.Normalize();
	Vec2f other_velnorm = other_island.vel; 
	const f32 other_vellen = other_velnorm.Normalize();
	
	Vec2f colvec1 = shape.getPosition().xz() - island.pos;
	Vec2f colvec2 = shape.getPosition().xz() - other_island.pos;
	colvec1.Normalize();
	colvec2.Normalize();

	const f32 veltransfer = 1.0f;
	const f32 veldamp = 1.0f;
	const f32 dirscale = 1.0f;
	f32 reactionScale1 = 1.0f;
	if ( other_island.beached )
		reactionScale1 *= 2;
	f32 reactionScale2 = 1.0f;
	if ( island.beached )
		reactionScale2 *= 2;
	const f32 massratio1 = other_island.mass/(island.mass+other_island.mass);
	const f32 massratio2 = island.mass/(island.mass+other_island.mass);
	island.vel *= veldamp;
	other_island.vel *= veldamp;
	
	if ( other_island.isStation )
	{
		if ( island.beached )
			island.vel += colvec1 * -vellen * dirscale * veltransfer - colvec1*1.0f;
		else
			island.vel += colvec1 * -vellen * dirscale * veltransfer - colvec1*0.4f;
	}
	else
	{
		island.vel += colvec1 * -other_vellen * dirscale * massratio1 * veltransfer * reactionScale1 - colvec1*0.2f;
		other_island.vel += colvec2 * -vellen * dirscale * massratio2 * veltransfer * reactionScale2 - colvec2*0.2f;
	}
}

void onDie(CBlob@ this)
{
	//gib the sprite
	if (this.getShape().getVars().customData > 0)
		this.getSprite().Gib();

	if ( getNet().isClient() )
	{
		//kill humans standing on top. done locally because lag makes server unable to catch the overlapping playerblobs
		int type = this.getSprite().getFrame();
		if ( type != Block::COUPLING && !Block::isRepulsor( type ) )
		{
			CBlob@ localBlob = getLocalPlayerBlob();
			if ( localBlob !is null && localBlob.get_u16( "shipID" ) == this.getNetworkID() )
			{
				CPlayer@ player = localBlob.getPlayer();
				if ( player !is null && localBlob.getDistanceTo( this ) < 6.5f )
				{
					player.client_ChangeTeam(44);//this makes the sv kill the playerblob (Respawning.as)
					localBlob.Tag( "dead" );
					CSprite@ sprite = localBlob.getSprite();
					if ( sprite !is null && !sprite.getVars().gibbed )//to mask the latency a bit
					{
						directionalSoundPlay( "SR_ManDeath" + ( XORRandom(4) + 1 ), localBlob.getPosition() );
						sprite.Gib();
					}
				}
			}
		}
	}
	
	if ( getNet().isServer() && this.hasTag( "seat" ) )
	{
		AttachmentPoint@ seat = this.getAttachmentPoint(0);
		CBlob@ b = seat.getOccupied();
		if ( b !is null )
			b.server_Die();
	}
}

void Die( CBlob@ this )
{
	if(!getNet().isServer()) return;
	
	this.Tag( "noCollide" );
	this.server_Die();
}

//mothership damage alerts
f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	EmitCoreCrystalDamageParticles(this, worldPoint, velocity, damage);

	if ( this.getTeamNum() != hitterBlob.getTeamNum() && isMothership( this ) )
	{
		int teamNum = this.getTeamNum();
		CRules@ rules = getRules();
		
		f32 msDMG = rules.get_f32( "msDMG" + teamNum );
		if ( msDMG < 8.0f )
			getRules().set_f32( "msDMG" + teamNum, msDMG + ( this.hasTag( "mothership" ) ? 5.0f : 1.0f ) * damage );
	}
	
	return damage;
}

//damage layers
void onHealthChange( CBlob@ this, f32 oldHealth )
{
	const int blockType = this.getSprite().getFrame();
	const f32 hp = this.getHealth();
	const f32 initHealth = this.getInitialHealth();
	if (blockType == Block::SHIPCORE && hp < oldHealth)
	{
		EmitCoreCrystalDamageParticles(this, this.getPosition(), Vec2f_zero, oldHealth - hp);
	}

	if ( this.hasTag( "mothership" ) ) return;//has own code
	Refresh3DDamageMesh(this);
	
	if (hp < 0.0f)
		this.server_Die();
	else
	{
		//update reclaim status
		if ( hp < this.get_f32("current reclaim") )
		{
			this.set_f32("current reclaim", hp);
		}
	
		//add damage layers
		f32 step = initHealth / ( DAMAGE_FRAMES + 1 );
		f32 currentStep = Maths::Floor( oldHealth/step ) * step;
		
		if ( hp < currentStep && hp <= initHealth - step && Block::isSolid( blockType ) )
		{
			if ( blockType == Block::RAM )
			{
				const int frame = (oldHealth > initHealth * 0.5f) ? 9 : 10;	
				CSprite@ sprite = this.getSprite();
				CSpriteLayer@ layer = sprite.addSpriteLayer( "dmg"+frame );
				if (layer !is null)
				{
					layer.SetRelativeZ(1+frame);
					layer.SetLighting( false );
					layer.SetFrame(frame);
					layer.RotateBy( XORRandom(4) * 90, Vec2f_zero );
				}
			}
			else if ( blockType != Block::RAMENGINE && blockType != Block::POINTDEFENSE )
			{
				const int frame = (oldHealth > initHealth * 0.5f) ? 5 : 6;	
				CSprite@ sprite = this.getSprite();
				CSpriteLayer@ layer = sprite.addSpriteLayer( "dmg"+frame );
				if (layer !is null)
				{
					layer.SetRelativeZ(1+frame);
					layer.SetLighting( false );
					layer.SetFrame(frame);
					layer.RotateBy( XORRandom(4) * 90, Vec2f_zero );
				}
			}

		    MakeDustParticle( this.getPosition(), "/dust2.png");
	    }
		if ( oldHealth >= initHealth*0.80f )
		{
			CSprite@ sprite = this.getSprite();
			for (uint frame = 0; frame < 11; ++frame)
			{
				sprite.RemoveSpriteLayer("dmg"+frame);
			}
		}
	}
}

void onGib(CSprite@ this)
{
	Vec2f pos = this.getBlob().getPosition();
	MakeDustParticle( pos, "/DustSmall.png");
	directionalSoundPlay( "destroy_wood", pos );
}
// network

void onSendCreateData( CBlob@ this, CBitStream@ stream )
{
	stream.write_u8( Block::getType(this) );
	stream.write_netid( this.get_u16("ownerID") );
}

bool onReceiveCreateData( CBlob@ this, CBitStream@ stream )
{
	u8 type = 0;
	u16 ownerID = 0;

	if (!stream.saferead_u8(type)){
		warn("Block::onReceiveCreateData - missing type");
		return false;	
	}
	if (!stream.saferead_u16(ownerID)){
		warn("Block::onReceiveCreateData - missing ownerID");
		return false;	
	}

	this.getSprite().SetFrame( type );

	CBlob@ owner = getBlobByNetworkID(ownerID);
	if (owner !is null)
	{
	    owner.push( "blocks", @this );
		this.getShape().getVars().customData = -1; // don't push on island
	}

	return true;
}
