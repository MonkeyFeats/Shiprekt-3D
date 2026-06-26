
//#define CLIENT_ONLY

#include "Vec3f.as"
//#include "Vec4f.as"
//#include "Ray.as"

#include "RenderConsts.as"
#include "CustomMap.as"
#include "LoadMapShapes.as"
#include "World.as"
#include "IslandsCommon.as"
#include "Blob3D.as"
#include "Matrix.as";
#include "Billboard3D.as"
#include "EmoteBillboard3D.as"
#include "Particle3D.as"
#include "Camera3D.as"
#include "CollisionDebug.as"
#include "Tree.as"
#include "RenderHUDstuff.as"
#include "OceanWater.as"
#include "Raycast3D.as"

const string sync_id = "mapvote: sync";
const string BULLET_BILLBOARD_KEY = "bullet_billboard3d";
const f32 CAMERA_2D_ROTATION_OFFSET = 180.0f;

f32 wave1  = -0.15;
f32 wave2 = -0.15;

SMesh@ SkyMesh = SMesh();

World@ world;
Root@ tree;
bool mapShapesLoaded = false;

Tool@ tool; 
Telescope@ scope; 
Compass@ compass; 
OceanWater@ Ocean;

void onInit(CRules@ this)
{
	Render::addScript(Render::layer_postworld, "Client.as", "threedee", 1.0f); // on layer_postworld because staging is/was having issues with z ordering
	Render::addScript(Render::layer_prehud, "Client.as", "hud", 2.0f);
	Render::addScript(Render::layer_posthud, "Client.as", "crosshair", 100.0f);
	if(tool !is null)
		tool = Tool();
	
	this.addCommandID(sync_id);
	RegisterParticle3DNetworkCommands(this);

	SkyMesh.LoadObjIntoMesh("skydome.obj");
	SkyMesh.SetHardwareMapping(SMesh::STATIC);	
	SMaterial@ SkyMeshMaterial = SkyMesh.GetMaterial();
	SkyMeshMaterial.SetFlag(SMaterial::LIGHTING, false);
	SkyMeshMaterial.SetFlag(SMaterial::ZBUFFER, false);
	SkyMeshMaterial.SetFlag(SMaterial::ZWRITE_ENABLE, false);
	SkyMeshMaterial.SetFlag(SMaterial::BACK_FACE_CULLING, false);
	SkyMeshMaterial.SetFlag(SMaterial::FOG_ENABLE, false);
	SkyMesh.BuildMesh();

 	@compass = Compass(); 
 	@Ocean = OceanWater();
	EnsureClient3DWorld();
}

void onRestart(CRules@ this)
{
	@world = null;
	@tree = null;
	mapShapesLoaded = false;
}

void onTick(CRules@ this)
{
	this.set_f32("interGameTime", getGameTime());
	this.set_f32("interFrameTime", 0);

	Ocean.Update();
	UpdateParticleSystem3D(1.0f);
	EnsureClient3DWorld();

	CPlayer@ p = getLocalPlayer();
	if(p !is null)
	{
		Camera3D@ camera;
		p.get("Camera3D", @camera);
		if (camera is null) { return; }
	   	    
		// CCam, for sounds
		Vec3f cameraPos = camera.getPosition();
		getCamera().setPosition(Vec2f(cameraPos.x, cameraPos.z));
		getCamera().setRotation(camera.getRotation().x + CAMERA_2D_ROTATION_OFFSET);

	    compass.SetAngle(-camera.getRotation().x/360);
	}

	//if (tree is null) return;
	//tree.CheckChunkVisibillty();	
}

const Vertex[] underwater_plane = 
{
	Vertex(-1,-5,  0.011f, 0,0,	SColor(130, 3, 30, 80)),
	Vertex( 1,-5,  0.011f, 1,0,	SColor(130, 3, 30, 80)),
	Vertex( 1, 0,  0.011f, 1,1,	SColor(130, 3, 30, 80)),
	Vertex(-1, 0,  0.011f, 0,1,	SColor(130, 3, 30, 80))
};


void hud(int id)
{
	CPlayer@ p = getLocalPlayer();
	if(p !is null)
	{
		Render::SetTransformScreenspace();	
		compass.RenderCompass();
		DrawShipWaveDebugHud();

		//CBlob@ b = p.getBlob();
		//if(b !is null)
		//{	
		//	string currentTool = b.get_string( "current tool" );	
//
	   // 	if (currentTool == "telescope" )
	   // 	{
	   // 		if ( (b.getSprite().getFrame() - 22) == 2)  
		//    	{
		//    		scope.DrawScope();		    		
		//    	} 
	   // 		else
	   // 		{
	   // 			tool.DrawTool(b.getTeamNum(), false);
	   // 		}
	   // 		 
	   // 	}
	   // 	else
	   // 	{
	   //     	tool.DrawTool(b.getTeamNum(), true);	        	
	   // 	}
		//}
	}
}

void crosshair(int id)
{
	Vec2f center = getDriver().getScreenCenterPos();
	const f32 gap = 3.0f;
	const f32 length = 10.0f;
	SColor shadow(180, 0, 0, 0);
	SColor color(255, 80, 220, 255);

	GUI::DrawLine2D(center + Vec2f(-length, 1), center + Vec2f(-gap, 1), shadow);
	GUI::DrawLine2D(center + Vec2f(gap, 1), center + Vec2f(length, 1), shadow);
	GUI::DrawLine2D(center + Vec2f(1, -length), center + Vec2f(1, -gap), shadow);
	GUI::DrawLine2D(center + Vec2f(1, gap), center + Vec2f(1, length), shadow);

	GUI::DrawLine2D(center + Vec2f(-length, 0), center + Vec2f(-gap, 0), color);
	GUI::DrawLine2D(center + Vec2f(gap, 0), center + Vec2f(length, 0), color);
	GUI::DrawLine2D(center + Vec2f(0, -length), center + Vec2f(0, -gap), color);
	GUI::DrawLine2D(center + Vec2f(0, gap), center + Vec2f(0, length), color);

	if (IsCollisionDebugEnabled(getRules()))
	{
		DrawAimDebugText(center);
	}
}

string DebugF(f32 value)
{
	return "" + (Maths::Round(value * 100.0f) * 0.01f);
}

string DebugV2(Vec2f value)
{
	return "(" + DebugF(value.x) + ", " + DebugF(value.y) + ")";
}

string DebugV3(Vec3f value)
{
	return "(" + DebugF(value.x) + ", " + DebugF(value.y) + ", " + DebugF(value.z) + ")";
}

string DebugBlobLabel(CBlob@ blob)
{
	if (blob is null)
	{
		return "none";
	}

	CSprite@ sprite = blob.getSprite();
	const int frame = sprite is null ? -1 : sprite.getFrame();
	return blob.getName() + " #" + blob.getNetworkID() + " f" + frame;
}

void DrawAimDebugLine(string text, Vec2f pos, SColor color)
{
	GUI::DrawText(text, pos + Vec2f(1, 1), SColor(220, 0, 0, 0));
	GUI::DrawText(text, pos, color);
}

bool RaycastDebugWaveSurface(CBlob@ blob, Raycast3D::Ray3D ray, Raycast3D::RaycastHit3D &out hit)
{
	Island@ island = getIsland(blob);
	if (island is null)
	{
		return Raycast3D::RaycastYPlane(ray, Raycast3D::GetBuildPlaneY(blob), Raycast3D::BUILD_RAY_DISTANCE, hit);
	}

	Vec3f planePoint(island.pos.x, GetIslandWaveVisualY(island, Vec2f_zero), island.pos.y);
	Vec3f planeNormal(-island.waveSlopeX, 1.0f, -island.waveSlopeZ);
	return Raycast3D::RaycastPlane(ray, planePoint, planeNormal, Raycast3D::BUILD_RAY_DISTANCE, hit);
}

bool GetDebugBuildSurfaceHit(CBlob@ blob, Raycast3D::Ray3D ray, Raycast3D::RaycastHit3D &out surfaceHit, bool &out blockedByBlock, Raycast3D::RaycastHit3D &out blockerHit)
{
	blockedByBlock = false;
	blockerHit.Clear();
	if (!RaycastDebugWaveSurface(blob, ray, surfaceHit))
	{
		return false;
	}

	const f32 blockMaxDistance = Maths::Max(0.0f, surfaceHit.distance - 0.05f);
	blockedByBlock = Raycast3D::RaycastBlockTarget(ray, Raycast3D::BLOCK_RAY_START_EPSILON, blockMaxDistance, blob, blockerHit);
	return true;
}

void DrawAimDebugText(Vec2f center)
{
	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
	{
		return;
	}

	GUI::SetFont("menu");

	CControls@ controls = getControls();
	Vec2f mouse = controls is null ? center : controls.getMouseScreenPos();
	Vec2f textPos = center + Vec2f(18, 18);
	const f32 lineHeight = 14.0f;
	u8 line = 0;
	SColor textColor(255, 240, 250, 255);
	SColor warnColor(255, 255, 160, 80);

	DrawAimDebugLine("screen center " + DebugV2(center), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("aim cursor   " + DebugV2(mouse) + "  delta " + DebugV2(mouse - center), textPos + Vec2f(0, lineHeight * line++), textColor);

	Raycast3D::Ray3D ray;
	if (!Raycast3D::GetLocalCameraRay(blob, ray))
	{
		DrawAimDebugLine("ray: no local camera ray", textPos + Vec2f(0, lineHeight * line++), warnColor);
		return;
	}

	DrawAimDebugLine("ray origin   " + DebugV3(ray.origin), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("ray dir      " + DebugV3(ray.direction), textPos + Vec2f(0, lineHeight * line++), textColor);

	CPlayer@ player = blob.getPlayer();
	Camera3D@ camera;
	if (player !is null && player.get("Camera3D", @camera) && camera !is null)
	{
		DrawAimDebugLine("camera pos  " + DebugV3(camera.getPosition()), textPos + Vec2f(0, lineHeight * line++), textColor);
	}

	Blob3D@ player3d;
	if (blob.get("blob3d", @player3d) && player3d !is null)
	{
		Vec3f eyePos = player3d.getRenderPosition() + Vec3f(0.0f, 16.0f, 0.0f);
		DrawAimDebugLine("render eye  " + DebugV3(eyePos) + " d " + DebugV3(ray.origin - eyePos), textPos + Vec2f(0, lineHeight * line++), textColor);
	}

	Raycast3D::RaycastHit3D blockHit;
	if (Raycast3D::RaycastBlockTarget(ray, Raycast3D::BLOCK_RAY_START_EPSILON, Raycast3D::BUILD_RAY_DISTANCE, blob, blockHit) && blockHit.blob !is null)
	{
		DrawAimDebugLine("block hit   " + DebugV3(blockHit.point) + " d " + DebugF(blockHit.distance) + " " + DebugBlobLabel(blockHit.blob), textPos + Vec2f(0, lineHeight * line++), textColor);
	}
	else
	{
		DrawAimDebugLine("block hit   none", textPos + Vec2f(0, lineHeight * line++), warnColor);
	}

	Raycast3D::RaycastHit3D planeHit;
	const bool hitsPlane = RaycastDebugWaveSurface(blob, ray, planeHit);
	if (hitsPlane)
	{
		DrawAimDebugLine("surface hit " + DebugV3(planeHit.point) + " d " + DebugF(planeHit.distance), textPos + Vec2f(0, lineHeight * line++), textColor);
	}
	else
	{
		DrawAimDebugLine("surface hit none", textPos + Vec2f(0, lineHeight * line++), warnColor);
	}

	bool blockedByBlock = false;
	Raycast3D::RaycastHit3D buildHit;
	Raycast3D::RaycastHit3D blockerHit;
	const bool hasBuildHit = GetDebugBuildSurfaceHit(blob, ray, buildHit, blockedByBlock, blockerHit);
	if (hasBuildHit)
	{
		DrawAimDebugLine("build hit    " + DebugV3(buildHit.point) + (blockedByBlock ? " blocked by " + DebugBlobLabel(blockerHit.blob) + " d " + DebugF(blockerHit.distance) : ""), textPos + Vec2f(0, lineHeight * line++), blockedByBlock ? warnColor : textColor);
	}
	else
	{
		DrawAimDebugLine("build hit    none", textPos + Vec2f(0, lineHeight * line++), warnColor);
	}

	Vec3f placementPoint(
		blob.get_f32("placement point x"),
		blob.get_f32("placement point y"),
		blob.get_f32("placement point z")
	);
	DrawAimDebugLine("stored place " + DebugV3(placementPoint), textPos + Vec2f(0, lineHeight * line++), textColor);
	if (hitsPlane)
	{
		DrawAimDebugLine("place-plane d " + DebugV3(placementPoint - planeHit.point), textPos + Vec2f(0, lineHeight * line++), textColor);
	}

	CBlob@ refBlob = getIslandBlob(blob);
	Island@ island = getIsland(blob);
	if (refBlob !is null && island !is null && island.centerBlock !is null)
	{
		f32 angle = island.centerBlock.getAngleDegrees();
		f32 refBAngle = refBlob.getAngleDegrees();
		while (refBAngle > angle + 45.0f) refBAngle -= 90.0f;
		while (refBAngle < angle - 45.0f) refBAngle += 90.0f;

		Vec2f islandPos = refBlob.getPosition();
		Vec2f localAim = placementPoint.xz() - islandPos;
		localAim.RotateBy(-refBAngle);
		Vec2f snappedLocal = SnapToGrid(localAim);
		Vec2f localDelta = localAim - snappedLocal;
		Vec2f snappedWorld = snappedLocal;
		snappedWorld.RotateBy(refBAngle);
		snappedWorld += islandPos;

		DrawAimDebugLine("snap world   " + DebugV2(snappedWorld), textPos + Vec2f(0, lineHeight * line++), textColor);
		DrawAimDebugLine("snap delta   " + DebugV2(localDelta), textPos + Vec2f(0, lineHeight * line++), Maths::Abs(localDelta.x) > 4.0f || Maths::Abs(localDelta.y) > 4.0f ? warnColor : textColor);
	}
}

void threedee(int id)
{
	CRules@ rules = getRules();

	rules.set_f32("interFrameTime", Maths::Clamp01(rules.get_f32("interFrameTime")+getRenderApproximateCorrectionFactor()));
	rules.add_f32("interGameTime", getRenderApproximateCorrectionFactor());	

	CPlayer@ p = getLocalPlayer();
	if(p !is null)
	{		
		Camera3D@ camera;
		p.get("Camera3D", @camera);
		if (camera is null) { return; }
		EnsureClient3DWorld();
		if (world is null) { return; }			

		camera.render_update();		
			
		Render::SetAlphaBlend(false);
		Render::SetZBuffer(true, true);
		Render::ClearZ();
		SetMirrorAwareRenderBackfaceCull(true);

		Matrix::MakeIdentity(model);
        Render::SetModelTransform(model);

		Render::SetTransform(model, camera.view.Array, camera.projection.Array);

		Render::SetFog(SColor(0xff3c4455), SMesh::LINEAR, 500.0, 800.0, 0.0, false, true);

		Matrix::MakeIdentity(model);
		Render::SetModelTransform(model);

		SkyMesh.RenderMeshWithMaterial();

		world.Render();
		RocksMesh.RenderMeshWithMaterial();
		if (IsCollisionDebugEnabled(rules))
		{
			RockColliderMesh.RenderMeshWithMaterial();
		}

		//for(int i = 0; i < world.Chunks.size(); i++)
		{
			//TerrainChunk@ chunk = world.Chunks[i];
			//chunk.box.Render();

			//tree.shape.Render();
			//tree.BRxz.shape.Render();
			//tree.BRx1z.shape.Render();
			//tree.BRxz1.shape.Render();
			//tree.BRx1z1.shape.Render();
		}

		//for(int i = 0; i < world.Chunks.size(); i++)
		//{
		//	TerrainChunk@ chunk = world.Chunks[i];
		//	world.Chunks[i].shape.Render();
		//}	

		//Island[]@ islands;
		//if ( getRules().get("islands", @islands ) )
		//{				
		//	for ( uint i = 0; i < islands.length(); ++i )
		//	{
		//		Matrix::MakeIdentity(model);
		//		Render::SetModelTransform(model);
////
		//		Island @isle = islands[i];
		//		if ( isle.isMothership && isle.centerBlock !is null )
		//		{
		//			isle.RenderIslands(camera.getPosition(), model, wave1);
		//		}
		//		else
		//		{
		//			isle.RenderIslands(camera.getPosition(), model, wave1);
		//		}
		//	}
		//}

		Matrix::MakeIdentity(model);
        Render::SetModelTransform(model);
		RenderProps(camera.getRotation().x, camera.getRotation().z, wave1);
		RenderBlob3DMeshes(model);
		RenderPlayerBillboards(camera.getPosition(), model);
		RenderEmoteBillboards(camera.getPosition(), model);
		RenderPlayers(camera.getPosition(), model);	
		Matrix::MakeIdentity(model);
        Render::SetModelTransform(model);
		Ocean.Render();	
		RenderCoreCrystalsLate(model);
		MatrixR inverseView(camera.view.Array);
		inverseView.Invert();
		RenderBulletBillboards(inverseView.Right, inverseView.Up, model);

		Matrix::MakeIdentity(model);
        Render::SetModelTransform(model);
		//Render::SetFog(SColor(0x00000000), SMesh::LINEAR, 99999.0, 100000.0, 0.0, false, false);
		RenderParticleSystem3D(camera.getPosition());
		Render::SetFog(SColor(0xff3c4455), SMesh::LINEAR, 500.0, 800.0, 0.0, false, true);
		DrawRaycastDebug();
		DrawShipWaveSampleDebug();
		//Render::SetAmbientLight(SColor(255, 10, 20, 255)); //does nothing that I can see - would be good for day cycles

	//	CBlob@[] palms;
	//	getBlobsByName( "palmtree", @palms );
	//	for ( u8 i = 0; i < palms.length; i++ )
	//	{
	//		CBlob@ palm = palms[i];
//
	//		Blob3D@ pblob3d;			
	//		if (!palm.get("blob3d", @pblob3d)) { return; }
	//		pblob3d.shape.Render();
	//	}	

	}
}

void DrawShipWaveSampleDebug()
{
	CRules@ rules = getRules();
	if (rules is null || rules.get_bool(SHIP_WAVE_VISUALS_DISABLED) || (g_debug == 0 && !rules.get_bool(SHIP_WAVE_SAMPLE_DEBUG)))
	{
		return;
	}

	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
	{
		return;
	}

	Island@ island = getIsland(blob);
	if (island is null || island.centerBlock is null)
	{
		return;
	}

	Vec3f islandCenter(island.pos.x, GetOceanWaterHeight(V2toV3(island.pos)), island.pos.y);
	Vec3f samplePos = GetShipWaveSamplePosition(island.pos);
	Vec3f sampleWater(samplePos.x, GetOceanWaterHeight(samplePos), samplePos.z);
	Vec3f sampleRest(samplePos.x, GetOceanRestWaterHeight(), samplePos.z);

	DrawDebugSegment(islandCenter, sampleWater, SColor(255, 255, 80, 255), 0.32f);
	DrawDebugSegment(sampleRest, sampleWater, SColor(255, 80, 255, 80), 0.28f);
	DrawDebugCross(sampleWater, SColor(255, 255, 240, 40), 5.0f);
	DrawDebugCross(sampleRest, SColor(180, 80, 255, 80), 3.0f);
}

void DrawShipWaveDebugHud()
{
	CRules@ rules = getRules();
	if (rules is null || (g_debug == 0 && !rules.get_bool(SHIP_WAVE_SAMPLE_DEBUG)))
	{
		return;
	}

	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
	{
		return;
	}

	GUI::SetFont("menu");

	Vec2f textPos(14, 72);
	const f32 lineHeight = 14.0f;
	u8 line = 0;
	SColor textColor(255, 240, 250, 255);
	SColor warnColor(255, 255, 170, 80);

	GUI::DrawRectangle(Vec2f(8, 66), Vec2f(760, 294), SColor(150, 0, 0, 0));
	DrawAimDebugLine("ship wave debug  toggle: !wave debug  offset: !wave x+/x-/y+/y-/z+/z-", textPos + Vec2f(0, lineHeight * line++), textColor);

	Island@ island = getIsland(blob);
	if (island is null || island.centerBlock is null)
	{
		DrawAimDebugLine("island: none for local player", textPos + Vec2f(0, lineHeight * line++), warnColor);
		return;
	}

	Vec3f samplePos = GetShipWaveSamplePosition(island.pos);
	const int sampleVertex = GetOceanWaterVertexIndex(samplePos);
	const f32 waterHeight = GetOceanWaterHeight(samplePos);
	const f32 restHeight = GetOceanRestWaterHeight();
	const f32 waterDelta = waterHeight - restHeight;
	const f32 liveBob = Maths::Clamp(waterDelta * SHIP_WAVE_BOB_SCALE, -SHIP_WAVE_MAX_BOB, SHIP_WAVE_MAX_BOB);
	const f32 impliedScale = Maths::Abs(waterDelta) > 0.001f ? island.waveYOffset / waterDelta : 0.0f;
	const f32 centerVisualY = SHIP_WAVE_BASE_Y_OFFSET + island.waveYOffset;

	DrawAimDebugLine("sample offset xyz  " + DebugV3(Vec3f(rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_X), rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_Y), rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_Z))) + "  vertex " + sampleVertex, textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("bob scale/max      " + DebugF(SHIP_WAVE_BOB_SCALE) + " / " + DebugF(SHIP_WAVE_MAX_BOB) + "  amp " + DebugF(OCEAN_WAVE_AMPLITUDE * 16.0f), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("island pos/angle   " + DebugV2(island.pos) + "  angle " + DebugF(island.angle), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("sample world xyz   " + DebugV3(samplePos), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("water/rest/delta   " + DebugF(waterHeight) + " / " + DebugF(restHeight) + " / " + DebugF(waterDelta), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("target/smooth bob  " + DebugF(liveBob) + " -> " + DebugF(island.waveYOffset) + "  lag " + DebugF(island.waveYOffset - liveBob), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("cached bob/slopes  " + DebugF(island.waveYOffset) + "  sx " + DebugF(island.waveSlopeX) + "  sz " + DebugF(island.waveSlopeZ) + "  implied " + DebugF(impliedScale), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("center visual y    base " + DebugF(SHIP_WAVE_BASE_Y_OFFSET) + " + bob = " + DebugF(centerVisualY), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawAimDebugLine("center 2d/interp   " + DebugV2(island.centerBlock.getPosition()) + " / " + DebugV2(island.centerBlock.getInterpolatedPosition()) + "  island d " + DebugV2(island.centerBlock.getPosition() - island.pos), textPos + Vec2f(0, lineHeight * line++), textColor);
	DrawShipGridDriftDebug(island, textPos + Vec2f(0, lineHeight * line++), textColor);

	Blob3D@ center3d;
	if (island.centerBlock.get("blob3d", @center3d) && center3d !is null)
	{
		DrawAimDebugLine("center raw/render  " + DebugV3(center3d.getPosition()) + " -> " + DebugV3(center3d.getRenderPosition()) + "  off " + DebugV3(center3d.renderOffset), textPos + Vec2f(0, lineHeight * line++), textColor);
		DrawAimDebugLine("center tilt/yaw    tilt " + DebugV3(center3d.renderRotation) + "  yaw " + DebugF(center3d.transform.Orientation.x), textPos + Vec2f(0, lineHeight * line++), textColor);
	}
	else
	{
		DrawAimDebugLine("center blob3d      missing", textPos + Vec2f(0, lineHeight * line++), warnColor);
	}

	Blob3D@ player3d;
	if (blob.get("blob3d", @player3d) && player3d !is null)
	{
		Vec2f playerLocal = player3d.transform.Position.xz() - island.pos;
		DrawAimDebugLine("player raw/render  " + DebugV3(player3d.getPosition()) + " -> " + DebugV3(player3d.getRenderPosition()) + "  off " + DebugV3(player3d.renderOffset), textPos + Vec2f(0, lineHeight * line++), textColor);
		DrawAimDebugLine("player island xz   " + DebugV2(playerLocal), textPos + Vec2f(0, lineHeight * line++), textColor);
	}
	else
	{
		DrawAimDebugLine("player blob3d      missing", textPos + Vec2f(0, lineHeight * line++), warnColor);
	}
}

void DrawShipGridDriftDebug(Island@ island, Vec2f pos, SColor color)
{
	if (island is null)
	{
		return;
	}

	f32 worstBlob3D = 0.0f;
	f32 worstCBlob = 0.0f;
	f32 worstInterp = 0.0f;
	u16 worstBlob3DID = 0;
	u16 worstCBlobID = 0;
	u16 worstInterpID = 0;

	for (uint i = 0; i < island.blocks.length; ++i)
	{
		IslandBlock@ isleBlock = island.blocks[i];
		if (isleBlock is null)
		{
			continue;
		}

		CBlob@ block = getBlobByNetworkID(isleBlock.blobID);
		if (block is null)
		{
			continue;
		}

		Vec2f offset = isleBlock.offset;
		offset.RotateBy(island.angle);
		Vec2f expected = island.pos + offset;

		Blob3D@ blob3d;
		if (block.get("blob3d", @blob3d) && blob3d !is null)
		{
			const f32 blob3DError = (blob3d.getPosition().xz() - expected).Length();
			if (blob3DError > worstBlob3D)
			{
				worstBlob3D = blob3DError;
				worstBlob3DID = isleBlock.blobID;
			}
		}

		const f32 cblobError = (block.getPosition() - expected).Length();
		if (cblobError > worstCBlob)
		{
			worstCBlob = cblobError;
			worstCBlobID = isleBlock.blobID;
		}

		const f32 interpError = (block.getInterpolatedPosition() - expected).Length();
		if (interpError > worstInterp)
		{
			worstInterp = interpError;
			worstInterpID = isleBlock.blobID;
		}
	}

	DrawAimDebugLine("grid drift max     b3d " + DebugF(worstBlob3D) + " #" + worstBlob3DID + "  cblob " + DebugF(worstCBlob) + " #" + worstCBlobID + "  interp " + DebugF(worstInterp) + " #" + worstInterpID, pos, color);
}

void RenderCoreCrystalsLate(float[] model)
{
	Render::SetAlphaBlend(true);
	Render::SetZBuffer(true, false);
	Render::SetBackfaceCull(false);

	CBlob@[] blobs;
	getBlobs(@blobs);

	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob is null || IsPlacementPreviewBlock(blob))
			continue;

		Blob3D@ blob3d;
		if (!blob.get("blob3d", @blob3d) || blob3d is null)
			continue;

		Blob3D@ crystal = blob3d.getChild("core_crystal");
		if (crystal is null)
			continue;

		RefreshShipBlockTransformForRender(blob, blob3d);
		SMaterial@ material = crystal.mesh.GetMaterial();
		if (material !is null)
		{
			material.SetFlag(SMaterial::ZBUFFER, true);
			material.SetFlag(SMaterial::ZWRITE_ENABLE, false);
			//material.SetZBufferCompareOperation(SMaterial::LESSEQUAL);
			material.SetFlag(SMaterial::FRONT_FACE_CULLING, !Is3DCameraHorizontallyMirrored());
			material.SetFlag(SMaterial::BACK_FACE_CULLING, Is3DCameraHorizontallyMirrored());
		}
		crystal.Render(model);

		if (material !is null)
		{
			material.SetFlag(SMaterial::FRONT_FACE_CULLING, Is3DCameraHorizontallyMirrored());
			material.SetFlag(SMaterial::BACK_FACE_CULLING, !Is3DCameraHorizontallyMirrored());
		}
		crystal.Render(model);

		if (material !is null)
		{
			material.SetFlag(SMaterial::FRONT_FACE_CULLING, false);
			material.SetFlag(SMaterial::BACK_FACE_CULLING, false);
		}
	}

	Render::SetAlphaBlend(false);
	Render::SetZBuffer(true, true);
	SetMirrorAwareRenderBackfaceCull(true);
}

void RenderBlob3DMeshes(float[] model)
{
	CBlob@[] blobs;
	getBlobs(@blobs);

	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob is null)
			continue;

		if (IsPlacementPreviewBlock(blob))
			continue;

		Blob3D@ blob3d;
		if (!blob.get("blob3d", @blob3d) || blob3d is null)
			continue;

		RefreshShipBlockTransformForRender(blob, blob3d);
		blob3d.Render(model);

		if (IsCollisionDebugEnabled(getRules()))
		{
			blob3d.RenderCollisionShapes();
		}
	}
}

bool EnsureClient3DWorld()
{
	if (world !is null)
	{
		return true;
	}

	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0)
	{
		return false;
	}

	if (!mapShapesLoaded)
	{
		LoadMapShapes(map);
		mapShapesLoaded = true;
	}

	World@ _world;
	if (!map.get("terrainInfo", @_world) || _world is null)
	{
		return false;
	}

	@world = _world;

	Root _tree(world.mapWidth, world.mapHeight, world.mapDepth);
	if (_tree !is null)
	{
		@tree = _tree;
	}

	return true;
}

void RefreshShipBlockTransformForRender(CBlob@ blob, Blob3D@ blob3d)
{
	if (blob is null || blob3d is null || blob.getName() != "block")
	{
		return;
	}

	const int color = blob.getShape().getVars().customData;
	if (color <= 0)
	{
		return;
	}

	Island@ island = getIsland(color);
	if (island is null)
	{
		return;
	}

	const u16 id = blob.getNetworkID();
	for (uint i = 0; i < island.blocks.length; ++i)
	{
		IslandBlock@ isleBlock = island.blocks[i];
		if (isleBlock is null || isleBlock.blobID != id)
		{
			continue;
		}

		Vec2f offset = isleBlock.offset;
		offset.RotateBy(island.angle);
		Vec2f blockPos = island.pos + offset;
		const f32 worldAngle = island.angle + isleBlock.angle_offset;
		const f32 blockY = GetIslandWaveVisualY(island, offset);
		Vec3f blockPos3D(blockPos.x, blockY, blockPos.y);

		blob3d.setPosition(blockPos3D);
		blob3d.transform.Orientation.x = worldAngle;
		blob3d.transform.Orientation.y = 0.0f;
		blob3d.transform.Orientation.z = 0.0f;
		blob3d.renderOffset = Vec3f();
		blob3d.renderRotation = GetIslandWaveVisualRotation(island);

		if (blob3d.shape !is null)
		{
			blob3d.shape.setPosition(blob3d.getPosition());
			blob3d.shape.transform.Orientation.x = worldAngle;
			blob3d.shape.transform.Orientation.y = blob3d.renderRotation.x;
			blob3d.shape.transform.Orientation.z = blob3d.renderRotation.z;
		}
		blob3d.SyncExtraShapes();
		return;
	}
}

Billboard3D@ EnsureHumanBillboard(CBlob@ blob)
{
	Billboard3D@ billboard;
	if (blob.get(HUMAN_BILLBOARD_KEY, @billboard) && billboard !is null)
	{
		return billboard;
	}

	Billboard3D newBillboard("PlayerMale.png", 16.0f, 20.0f);
	blob.set(HUMAN_BILLBOARD_KEY, @newBillboard);
	blob.get(HUMAN_BILLBOARD_KEY, @billboard);
	return billboard;
}

void RenderPlayerBillboards(Vec3f cameraPosition, float[] model)
{
	CBlob@[] players;
	getBlobsByName("human", @players);

	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ blob = players[i];
		if (blob is null)
			continue;

		if (blob.isMyPlayer() && !blob.isAttached() && IsFirstPersonCameraEnabled(getRules()))
			continue;

		Blob3D@ blob3d;
		if (!blob.get("blob3d", @blob3d) || blob3d is null)
			continue;

		Billboard3D@ billboard = EnsureHumanBillboard(blob);
		if (billboard is null)
			continue;

		f32 entityYaw = blob3d.transform.Orientation.x;
		if (blob.isAttached())
		{
			entityYaw = -blob.get_f32("human seat render yaw");
		}

		billboard.Render(blob, blob3d.getRenderPosition(), entityYaw, cameraPosition, model);
	}
}

Billboard3D@ EnsureBulletBillboard(CBlob@ blob)
{
	Billboard3D@ billboard;
	if (blob.get(BULLET_BILLBOARD_KEY, @billboard) && billboard !is null)
	{
		return billboard;
	}

	Billboard3D newBillboard();
	newBillboard.Setup("Bullet.png", 4.8f, 4.8f, 1, 1, true, false);
	blob.set(BULLET_BILLBOARD_KEY, @newBillboard);
	blob.get(BULLET_BILLBOARD_KEY, @billboard);
	return billboard;
}

void RenderBulletBillboards(Vec3f cameraRight, Vec3f cameraUp, float[] model)
{
	CBlob@[] bullets;
	getBlobsByName("bullet", @bullets);
	Render::SetBackfaceCull(false);
	Render::SetAlphaBlend(true);
	Render::SetZBuffer(true, false);

	for (uint i = 0; i < bullets.length; i++)
	{
		CBlob@ bullet = bullets[i];
		if (bullet is null)
			continue;

		Blob3D@ blob3d;
		if (!bullet.get("blob3d", @blob3d) || blob3d is null)
			continue;

		Billboard3D@ billboard = EnsureBulletBillboard(bullet);
		if (billboard is null)
			continue;

		billboard.RenderFacingCameraAxes(blob3d.getRenderPosition(), cameraRight, cameraUp, model);
	}

	Render::SetZBuffer(true, true);
	Render::SetAlphaBlend(false);
	SetMirrorAwareRenderBackfaceCull(true);
}

EmoteBillboard3D@ EnsureEmoteBillboard(CBlob@ blob, const string &in textureName)
{
	EmoteBillboard3D@ billboard;
	if (blob.get(EMOTE_BILLBOARD_KEY, @billboard) && billboard !is null)
	{
		return billboard;
	}

	EmoteBillboard3D newBillboard(textureName);
	blob.set(EMOTE_BILLBOARD_KEY, @newBillboard);
	blob.get(EMOTE_BILLBOARD_KEY, @billboard);
	return billboard;
}

void RenderEmoteBillboards(Vec3f cameraPosition, float[] model)
{
	CBlob@[] players;
	getBlobsByName("human", @players);

	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ blob = players[i];
		if (blob is null || !is_emote(blob))
		{
			continue;
		}

		Blob3D@ blob3d;
		if (!blob.get("blob3d", @blob3d) || blob3d is null)
		{
			continue;
		}

		Emote@ emote = getEmote(blob.get_string("emote"));
		if (emote is null || emote.pack is null)
		{
			continue;
		}

		EmoteBillboard3D@ billboard = EnsureEmoteBillboard(blob, emote.pack.filePath);
		if (billboard is null)
		{
			continue;
		}

		Vec3f emotePos = blob3d.getRenderPosition();
		emotePos.y += 28.0f;
		billboard.Render(emote, emotePos, cameraPosition, model);
	}
}

void DrawRaycastDebug()
{
	if (!IsCollisionDebugEnabled(getRules()))
	{
		return;
	}

	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
	{
		return;
	}

	Raycast3D::Ray3D ray;
	if (!Raycast3D::GetLocalCameraRay(blob, ray))
	{
		return;
	}

	Raycast3D::RaycastHit3D planeHit;
	bool hitsPlane = RaycastDebugWaveSurface(blob, ray, planeHit);
	Raycast3D::RaycastHit3D blockHit;
	bool hitsBlock = Raycast3D::RaycastBlockTarget(ray, Raycast3D::BLOCK_RAY_START_EPSILON, Raycast3D::BUILD_RAY_DISTANCE, blob, blockHit);
	Vec3f end = hitsBlock ? blockHit.point : (hitsPlane ? planeHit.point : ray.GetPoint(96.0f));

	DrawDebugSegment(ray.origin, end, SColor(255, 20, 220, 255), 0.35f);
	if (hitsBlock)
	{
		DrawDebugCross(blockHit.point, SColor(255, 255, 30, 220), 3.5f);
	}
	if (hitsPlane)
	{
		DrawDebugCross(planeHit.point, SColor(255, 255, 80, 20), 2.5f);
		DrawPlacementGridDebug(blob, planeHit.point);
	}
}

Vec3f DebugGridPoint(Vec2f gridCenter, Vec2f localOffset, f32 angle, f32 y)
{
	localOffset.RotateBy(angle);
	Vec2f world = gridCenter + localOffset;
	return Vec3f(world.x, y, world.y);
}

void DrawDebugWireCube(Vec2f gridCenter, f32 angle, f32 bottomY, SColor color, f32 thickness)
{
	const f32 half = 8.0f;
	const f32 topY = bottomY + 16.0f;

	Vec3f b0 = DebugGridPoint(gridCenter, Vec2f(-half, -half), angle, bottomY);
	Vec3f b1 = DebugGridPoint(gridCenter, Vec2f( half, -half), angle, bottomY);
	Vec3f b2 = DebugGridPoint(gridCenter, Vec2f( half,  half), angle, bottomY);
	Vec3f b3 = DebugGridPoint(gridCenter, Vec2f(-half,  half), angle, bottomY);
	Vec3f t0 = DebugGridPoint(gridCenter, Vec2f(-half, -half), angle, topY);
	Vec3f t1 = DebugGridPoint(gridCenter, Vec2f( half, -half), angle, topY);
	Vec3f t2 = DebugGridPoint(gridCenter, Vec2f( half,  half), angle, topY);
	Vec3f t3 = DebugGridPoint(gridCenter, Vec2f(-half,  half), angle, topY);

	DrawDebugSegment(b0, b1, color, thickness);
	DrawDebugSegment(b1, b2, color, thickness);
	DrawDebugSegment(b2, b3, color, thickness);
	DrawDebugSegment(b3, b0, color, thickness);
	DrawDebugSegment(t0, t1, color, thickness);
	DrawDebugSegment(t1, t2, color, thickness);
	DrawDebugSegment(t2, t3, color, thickness);
	DrawDebugSegment(t3, t0, color, thickness);
	DrawDebugSegment(b0, t0, color, thickness);
	DrawDebugSegment(b1, t1, color, thickness);
	DrawDebugSegment(b2, t2, color, thickness);
	DrawDebugSegment(b3, t3, color, thickness);
}

void DrawPlacementGridDebug(CBlob@ blob, Vec3f hitPoint)
{
	CBlob@ refBlob = getIslandBlob(blob);
	Island@ island = getIsland(blob);
	if (refBlob is null || island is null || island.centerBlock is null)
	{
		return;
	}

	f32 angle = island.centerBlock.getAngleDegrees();
	f32 refBAngle = refBlob.getAngleDegrees();
	while (refBAngle > angle + 45.0f) refBAngle -= 90.0f;
	while (refBAngle < angle - 45.0f) refBAngle += 90.0f;

	Vec2f islandPos = refBlob.getPosition();
	Vec2f localHit = hitPoint.xz() - islandPos;
	localHit.RotateBy(-refBAngle);
	Vec2f snappedHit = SnapToGrid(localHit);

	for (int x = -3; x <= 3; x++)
	{
		for (int z = -3; z <= 3; z++)
		{
			Vec2f localCell = snappedHit + Vec2f(x * 16.0f, z * 16.0f);
			Vec2f worldCell = localCell;
			worldCell.RotateBy(refBAngle);
			worldCell += islandPos;

			SColor color(190, 60, 180, 255);
			f32 thickness = 0.22f;
			if (x == 0 && z == 0)
			{
				color = SColor(235, 80, 255, 255);
				thickness = 0.32f;
			}
			DrawDebugWireCube(worldCell, refBAngle, hitPoint.y, color, thickness);
		}
	}
}

void DrawDebugSegment(Vec3f start, Vec3f end, SColor color, f32 thickness)
{
	Vec3f dir = (end - start).Normalize();
	Vec3f side = Cross(dir, Vec3f(0, 1, 0));
	if (side.LengthSquared() < 0.001f)
	{
		side = Vec3f(1, 0, 0);
	}
	side = side.Normalize() * thickness;

	Vertex[] vertices = {
		Vertex(start.x + side.x, start.y + side.y, start.z + side.z, 0, 0, color),
		Vertex(start.x - side.x, start.y - side.y, start.z - side.z, 1, 0, color),
		Vertex(end.x - side.x, end.y - side.y, end.z - side.z, 1, 1, color),
		Vertex(start.x + side.x, start.y + side.y, start.z + side.z, 0, 0, color),
		Vertex(end.x - side.x, end.y - side.y, end.z - side.z, 1, 1, color),
		Vertex(end.x + side.x, end.y + side.y, end.z + side.z, 0, 1, color)
	};

	Render::SetBackfaceCull(false);
	Render::SetZBuffer(false, false);
	Render::RawTriangles("pixel", vertices);
	Render::SetZBuffer(true, true);
	SetMirrorAwareRenderBackfaceCull(true);
}

void DrawDebugCross(Vec3f center, SColor color, f32 size)
{
	DrawDebugSegment(center - Vec3f(size, 0, 0), center + Vec3f(size, 0, 0), color, 0.25f);
	DrawDebugSegment(center - Vec3f(0, 0, size), center + Vec3f(0, 0, size), color, 0.25f);
	DrawDebugSegment(center - Vec3f(0, size, 0), center + Vec3f(0, size, 0), color, 0.25f);
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	CBitStream params;
	u16 id = player.getNetworkID();
	params.write_u16(id);
	this.SendCommand(this.getCommandID(sync_id), params);	
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{		
	if (cmd == this.getCommandID(PARTICLE_3D_EVENT_CMD))
	{
		HandleParticle3DEventCommand(this, params);
		return;
	}

	if (cmd == this.getCommandID(sync_id))
	{	
		u16 id = params.read_u16();
		CPlayer@ player = getPlayerByNetworkId(id);
		if (player !is null && player.isMyPlayer())
		{				
			EnsureClient3DWorld();
			//SetUpTree();
			//for(int i = 0; i < world.Chunks.size(); i++)
			//{
			//	DrawHitbox(world.Chunks[i].shape, 0xffffffff);
			//}
		}
	}
}
