#include "Vec3f.as"
#include "EmotesCommon.as"

const string EMOTE_BILLBOARD_KEY = "emote_billboard3d";

class EmoteBillboard3D
{
	SMesh@ mesh = SMesh();
	SMaterial@ material = SMaterial();

	string textureName = "";
	int lastFrame = -1;

	EmoteBillboard3D() {}

	EmoteBillboard3D(const string &in _textureName)
	{
		Setup(_textureName);
	}

	void Setup(const string &in _textureName)
	{
		textureName = _textureName;
		lastFrame = -1;

		mesh.SetHardwareMapping(SMesh::DYNAMIC);

		material.AddTexture(textureName, 0);
		material.DisableAllFlags();
		material.SetFlag(SMaterial::COLOR_MASK, true);
		material.SetFlag(SMaterial::ZBUFFER, true);
		material.SetFlag(SMaterial::ZWRITE_ENABLE, false);
		material.SetFlag(SMaterial::BACK_FACE_CULLING, false);
		material.SetFlag(SMaterial::FOG_ENABLE, false);
		material.SetMaterialType(SMaterial::TRANSPARENT_ALPHA_CHANNEL_REF);
		mesh.SetMaterial(material);

		UpdateMesh(0);
	}

	void UpdateMesh(int frame)
	{
		if (frame == lastFrame)
		{
			return;
		}

		lastFrame = frame;

		const int columns = 4;
		const int rows = 16;
		const f32 ubit = 1.0f / f32(columns);
		const f32 vbit = 1.0f / f32(rows);
		const int x = frame % columns;
		const int y = frame / columns;
		const f32 halfSize = 5.0f;

		Vertex[] verts =
		{
			Vertex(-halfSize, -halfSize, 0.0f, f32(x) * ubit,     f32(y + 1) * vbit, color_white),
			Vertex( halfSize, -halfSize, 0.0f, f32(x + 1) * ubit, f32(y + 1) * vbit, color_white),
			Vertex( halfSize,  halfSize, 0.0f, f32(x + 1) * ubit, f32(y) * vbit,     color_white),
			Vertex(-halfSize,  halfSize, 0.0f, f32(x) * ubit,     f32(y) * vbit,     color_white)
		};

		const u16[] ids = {1, 0, 3, 1, 3, 2};

		mesh.SetVertex(verts);
		mesh.SetIndices(ids);
		mesh.BuildMesh();
		mesh.SetDirty(SMesh::VERTEX_INDEX);
	}

	void Render(Emote@ emote, Vec3f position, Vec3f cameraPosition, float[] model)
	{
		if (emote is null || emote.pack is null)
		{
			return;
		}

		if (textureName != emote.pack.filePath)
		{
			Setup(emote.pack.filePath);
		}

		UpdateMesh(emote.index);

		const f32 cameraYaw = (cameraPosition.xz() - position.xz()).Angle();

		Matrix::MakeIdentity(model);
		Matrix::SetTranslation(model, position.x, position.y, position.z);
		Matrix::SetRotationDegrees(model, 0.0f, -90.0f + cameraYaw, 0.0f);
		Render::SetModelTransform(model);
		mesh.RenderMeshWithMaterial();
	}
}
