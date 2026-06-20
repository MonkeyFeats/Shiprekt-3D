#include "IslandsCommon.as";
#include "HumanCommon.as";
#include "ShapeArrays.as";

SColor col = color_white;
float[] model;
const f32 FLAK_TOPPER_Y_OFFSET = 8.0f;
const f32 BLUEPRINT_BLOCK_SIZE = 16.35f;
const f32 BLUEPRINT_BLOCK_HEIGHT = 16.0f;
const f32 BLUEPRINT_HALF_EXTENT = 8.0f;
const f32 BLUEPRINT_HEIGHT = 16.0f;

bool IsPlacementPreviewBlock(CBlob@ block)
{
	return block !is null
		&& block.getName() == "block"
		&& block.getShape().getVars().customData == -1;
}

void RenderBlueprintVolume(SColor color)
{
	const f32 h = BLUEPRINT_HALF_EXTENT;
	const f32 h2 = BLUEPRINT_HEIGHT;
	Vertex[] vertices = {
		Vertex( h, 0.0f,  h, 0, 0, color), Vertex( h, 0.0f, -h, 1, 0, color), Vertex(-h, 0.0f, -h, 1, 1, color),
		Vertex( h, 0.0f,  h, 0, 0, color), Vertex(-h, 0.0f, -h, 1, 1, color), Vertex(-h, 0.0f,  h, 0, 1, color),

		Vertex( h, h2, 	  h, 0, 0, color), Vertex(-h, 		 h2, -h, 1, 1, color), Vertex( h, h2, -h, 1, 0, color),
		Vertex( h, h2, 	  h, 0, 0, color), Vertex(-h, 		 h2,  h, 0, 1, color), Vertex(-h, h2, -h, 1, 1, color),

		Vertex( h, 0.0f,  h, 0, 0, color), Vertex( h, 	 h2,  h, 0, 1, color), Vertex( h, h2, -h, 1, 1, color),
		Vertex( h, 0.0f,  h, 0, 0, color), Vertex( h, 	 h2, -h, 1, 1, color), Vertex( h, 0.0f, -h, 1, 0, color),

		Vertex(-h, 0.0f,  h, 0, 0, color), Vertex(-h, 	 h2, -h, 1, 1, color), Vertex(-h, h2,  h, 0, 1, color),
		Vertex(-h, 0.0f,  h, 0, 0, color), Vertex(-h, 0.0f, -h, 1, 0, color), Vertex(-h, h2, -h, 1, 1, color),

		Vertex( h, 0.0f, -h, 0, 0, color), Vertex( h, 	 h2, -h, 0, 1, color), Vertex(-h, h2, -h, 1, 1, color),
		Vertex( h, 0.0f, -h, 0, 0, color), Vertex(-h, 	 h2, -h, 1, 1, color), Vertex(-h, 0.0f, -h, 1, 0, color),
	 
		Vertex( h, 0.0f,  h, 0, 0, color), Vertex(-h, 	 h2,  h, 1, 1, color), Vertex( h, h2,  h, 0, 1, color),
		Vertex( h, 0.0f,  h, 0, 0, color), Vertex(-h, 0.0f,  h, 1, 0, color), Vertex(-h, h2,  h, 1, 1, color)
	};

	Render::SetAlphaBlend(true);
	Render::SetBackfaceCull(false);
	Render::RawTriangles("pixel", vertices);
	Render::SetBackfaceCull(true);
	Render::SetAlphaBlend(false);
}

Vertex[] BlueprintBoxVertices()
{
	const f32 h = BLUEPRINT_HALF_EXTENT;
	const f32 h2 = BLUEPRINT_HEIGHT;
	Vertex[] vertices = {
		Vertex( h, 0.0f,  h, 0, 1, color_white),
		Vertex( h, 0.0f, -h, 0, 0, color_white),
		Vertex(-h, 0.0f, -h, 1, 0, color_white),
		Vertex(-h, 0.0f,  h, 1, 1, color_white),
		Vertex( h, h2,  h, 1, 1, color_white),
		Vertex(-h, h2,  h, 0, 1, color_white),
		Vertex(-h, h2, -h, 0, 0, color_white),
		Vertex( h, h2, -h, 1, 0, color_white),
		Vertex( h, 0.0f,  h, 1, 1, color_white),
		Vertex( h, h2,  h, 0, 1, color_white),
		Vertex( h, h2, -h, 0, 0, color_white),
		Vertex( h, 0.0f, -h, 1, 0, color_white),
		Vertex( h, 0.0f, -h, 1, 1, color_white),
		Vertex( h, h2, -h, 0, 1, color_white),
		Vertex(-h, 0.0f, -h, 1, 1, color_white),
		Vertex(-h, h2, -h, 0, 1, color_white),
		Vertex(-h, h2,  h, 0, 0, color_white),
		Vertex(-h, 0.0f,  h, 1, 0, color_white),
		Vertex( h, h2,  h, 0, 0, color_white),
		Vertex( h, 0.0f,  h, 1, 0, color_white)
	};

	return vertices;
}

void ScaleModelAxes(float[] model, f32 xScale, f32 yScale, f32 zScale)
{
	model[0] *= xScale;
	model[1] *= xScale;
	model[2] *= xScale;
	model[4] *= yScale;
	model[5] *= yScale;
	model[6] *= yScale;
	model[8] *= zScale;
	model[9] *= zScale;
	model[10] *= zScale;
}

void SetBlueprintTransform(float[] model, Vec2f blockPos, f32 angleDegrees, f32 yOffset, Vec3f renderRotation)
{
	Matrix::MakeIdentity(model);
	Matrix::SetTranslation(model, blockPos.x, yOffset, blockPos.y);
	Matrix::SetRotationDegrees(model, renderRotation.x, -angleDegrees, renderRotation.z);
	ScaleModelAxes(model, BLUEPRINT_BLOCK_SIZE, BLUEPRINT_BLOCK_HEIGHT, BLUEPRINT_BLOCK_SIZE);
	Render::SetModelTransform(model);
}

void SetBlob3DPreviewTint(Blob3D@ blob3d, SColor color, SMaterial::BlendType blendType)
{
	if (blob3d is null)
	{
		return;
	}

	if (blob3d.HasMesh && blob3d.mesh !is null)
	{
		SMaterial@ material = blob3d.mesh.GetMaterial();
		if (material !is null)
		{
			material.SetAmbientColor(color);
			material.SetDiffuseColor(color);
			//material.SetBlendOperation(blendType);
		}
	}

	for (uint i = 0; i < blob3d.Children.length(); ++i)
	{
		SetBlob3DPreviewTint(blob3d.Children[i], color, blendType);
	}
}

void RenderHeldBlockMesh(CBlob@ block, float[] model, bool blocked)
{
	Blob3D@ blob3d;
	if (!block.get("blob3d", @blob3d) || blob3d is null)
	{
		return;
	}

	const SColor previewTint = blocked ? SColor(255, 255, 35, 35) : SColor(255, 35, 125, 255);
	SetBlob3DPreviewTint(blob3d, previewTint, SMaterial::MAX);

	Vec2f blockPos = block.getPosition();
	blob3d.transform.Position.x = blockPos.x;
	blob3d.transform.Position.y = 0.0f;
	blob3d.transform.Position.z = blockPos.y;
	blob3d.transform.Orientation.x = block.getAngleDegrees();
	blob3d.Render(model);

	SetBlob3DPreviewTint(blob3d, color_white, SMaterial::ADD);
}

void RenderHeldBlockBlueprints(CBlob@ blob, float[] model)
{
	if (!Human::isHoldingBlocks(blob))
	{
		return;
	}

	CBlob@[]@ blocks;
	if (!blob.get("blocks", @blocks))
	{
		return;
	}

	for (uint i = 0; i < blocks.length; ++i)
	{
		CBlob@ block = blocks[i];
		if (block is null)
		{
			continue;
		}

		const bool blocked = block.get_bool("red");
		string outlinename = "BlockOutlineGreen.png";
		SColor blueprintColor = SColor(72, 70, 220, 255);
		if (blocked)
		{
			outlinename = "BlockOutlineRed.png";
			blueprintColor = SColor(72, 255, 55, 55);
		}
		Vec2f blockPos = block.getPosition();

		Blob3D@ blob3d;
		Vec3f renderOffset;
		Vec3f renderRotation;
		if (block.get("blob3d", @blob3d) && blob3d !is null)
		{
			renderOffset = blob3d.renderOffset;
			renderRotation = blob3d.renderRotation;
		}

		SetBlueprintTransform(model, blockPos, block.getAngleDegrees(), renderOffset.y - 0.05f, renderRotation);
		RenderBlueprintVolume(blueprintColor);

		RenderHeldBlockMesh(block, model, blocked);

		SetBlueprintTransform(model, blockPos, block.getAngleDegrees(), renderOffset.y - 0.04f, renderRotation);
		Render::RawTrianglesIndexed(outlinename, BlueprintBoxVertices(), box_IDs);
	}
}

void RenderProps(float dirX, float dirY, f32 waterheight)
{	

	CBlob@[] props;
	getBlobsByTag("prop", @props);
	for(int i = 0; i < props.length; i++)
	{
		CBlob@ prop = props[i];
		if(prop !is null)
		{
			//Render::RawTrianglesIndexed(this.texture, this.v_raw, this.v_i);
			int id = prop.get_u8("ID");
			Matrix::MakeIdentity(model);		

					//	Blob3D@ blob3d;
		//	if (!prop.get("blob3d", @blob3d)) { return; }
		//	{
		//		blob3d.mesh.RenderMeshWithMaterial();
		//		if (blob3d.shape != null)
		//			blob3d.shape.Render();
		//	}					
				

			switch (id)
			{
				//case 14:	// flak topper
				//{					
				//	Matrix::SetTranslation(model, prop.getInterpolatedPosition().x, waterheight + FLAK_TOPPER_Y_OFFSET, prop.getInterpolatedPosition().y);
				//	Matrix::SetRotationDegrees(model, 0 , prop.get_f32("angle") , 0);
				//	Render::SetModelTransform(model);
				//	Render::RawTrianglesIndexed("BlockTextures.png", FlakCannon_Vertices, FlakCannon_IDs);
				//	break;
				//}
				//case 9: // engine blades || 8
				//{					
				//	Vec2f pivot(0.0, 12.0);
				//	pivot.RotateBy(prop.getAngleDegrees());
//
				//	float ang = prop.get_f32("blade angle");
				//	float power = prop.get_f32("power");
				//	bool on = prop.get_bool("on");
//
				//	Matrix::SetTranslation(model, pivot.x+prop.getInterpolatedPosition().x,  -12.55, pivot.y+prop.getInterpolatedPosition().y);
				//	Matrix::SetRotationDegrees(model, ang+90.0f, prop.getAngleDegrees() , 90.0f);
				//	Render::SetModelTransform(model);
				//	Render::RawTrianglesIndexed("BlockTextures.png", Propellerblades_Vertices, Propellerblades_IDs);
//
				//	if (on)
				//	{
				//		Render::SetBackfaceCull(false);
				//		Matrix::SetTranslation(model, pivot.x+prop.getInterpolatedPosition().x,  -12.55, pivot.y+prop.getInterpolatedPosition().y);
				//		//Matrix::SetRotationDegrees(model, 0 , prop.getAngleDegrees() , 0);
				//		Matrix::SetScale(model, 16.0f, 1.0f, 16.0f);
				//		Render::SetModelTransform(model);
				//		Render::RawTrianglesIndexed("water_wake.png", WakePlane_Vertices, Square_IDs());
				//		Render::SetBackfaceCull(true);
				//	}
				//	break;
				//}
				case 48: // bullet
				{					
					break;
				}
				case 56:	// Sunken Treasure
				{
					Matrix::SetTranslation(model, prop.getInterpolatedPosition().x, 0.03, prop.getInterpolatedPosition().y);
					Matrix::SetRotationDegrees(model, 0, prop.getAngleDegrees(), 0);
					Matrix::SetScale(model, 5.0, 1.0, 5.0);
					Render::SetModelTransform(model);
					Render::RawTrianglesIndexed("SunkShip.png", Floor_Vertices, Square_IDs());					
					break;
				}

				case 57:	// Sharky
				{
					Matrix::SetTranslation(model, prop.getInterpolatedPosition().x, -0.85, prop.getInterpolatedPosition().y);
					Matrix::SetRotationDegrees(model, 0, prop.getAngleDegrees(), 0);
					Render::SetModelTransform(model);
					Render::RawTrianglesIndexed("SharkTex.png", shark_bod_Vertices, shark_bod_IDs);

					Vec2f jaw_pivot(0.72, 0);
					jaw_pivot.RotateBy(prop.getAngleDegrees());

					Matrix::SetTranslation(model, jaw_pivot.x+prop.getInterpolatedPosition().x, -0.85-0.21, jaw_pivot.y+prop.getInterpolatedPosition().y);
					Render::SetModelTransform(model);
					Render::RawTrianglesIndexed("SharkTex.png", shark_jaw_Vertices, shark_jaw_IDs);	

					Vec2f tail_pivot(-0.5, 0);
					tail_pivot.RotateBy(prop.getAngleDegrees());

					Matrix::SetTranslation(model, tail_pivot.x+prop.getInterpolatedPosition().x, -0.85, tail_pivot.y+prop.getInterpolatedPosition().y);
					Matrix::SetRotationDegrees(model, 0, prop.getAngleDegrees()+ (Maths::Sin(getGameTime() * 0.15f) * 12), 0);
					Render::SetModelTransform(model);
					Render::RawTrianglesIndexed("SharkTex.png", shark_tail_Vertices, shark_tail_IDs);
					break;
				}
			}
			/*if (objects[id].billboard)
			{
				Matrix::SetTranslation(model, (prop.getInterpolatedPosition().y+prop.getHeight()/2), , (prop.getInterpolatedPosition().x+prop.getWidth()/2));
				Matrix::SetRotationDegrees(model, 0, dir, 0);
			}
			else
			{
				Matrix::SetTranslation(model, prop.getInterpolatedPosition().y, , prop.getInterpolatedPosition().x);
				Matrix::SetRotationDegrees(model, 0, prop.getAngleDegrees(), 0);
			}
			
			Render::SetModelTransform(model);
			objects[id].Draw(prop);
			
			if (id == 0)
			{
				Matrix::MakeIdentity(model);
				Matrix::SetTranslation(model, (prop.getInterpolatedPosition().y+prop.getHeight()/2), , (prop.getInterpolatedPosition().x+prop.getWidth()/2));
				Matrix::SetRotationDegrees(model, 0, prop.get_f32("dir_x")-45, 0);
				Render::SetModelTransform(model);
				Render::RawTrianglesIndexed("look.png", lookV, lookID);
			}*/
		}
	}
}

void RenderPlayers(Vec3f pos, float[] model)
{
	string outlinename = "BlockOutlineGreen.png";
	CBlob@[] blobs;
	getBlobsByName("human", @blobs);
	for(int i = 0; i < blobs.length; i++)
	{CBlob@ blob = blobs[i];
		if(blob !is null)
		{
			Blob3D@ blob3d;
			if (!blob.get("blob3d", @blob3d) || blob3d is null) { continue; }

			Matrix::MakeIdentity(model);

			string currentTool = blob.get_string( "current tool" );
			if ( currentTool == "reconstructor" || currentTool == "deconstructor" )
			{
				CBlob@ mBlob = getMap().getBlobAtPosition( blob.get_Vec2f("aim_pos") );
				if (mBlob !is null)
				{
					if (currentTool == "reconstructor")
					{ outlinename = "BlockOutlineGreen.png"; } 
					else if (currentTool == "deconstructor")
					{ outlinename = "BlockOutlineRed.png"; }
					else 
					{ outlinename = "BlockOutlineWhite.png"; }

					Matrix::SetTranslation(model, blob.getInterpolatedPosition().y/16, 0, blob.getInterpolatedPosition().x/16);
					Matrix::SetScale(model, 1.03, 1.03, 1.03);
					Render::SetModelTransform(model);
					//Render::SetAlphaBlend(true);
					Render::RawTrianglesIndexed( outlinename, box_Vertices, box_IDs);
				}				
			}

			RenderHeldBlockBlueprints(blob, model);

		}
	}
}

