#include "Vec3f.as"

const string HUMAN_BILLBOARD_KEY = "billboard3d";

shared class Billboard3D
{
    SMesh@ mesh = SMesh();
    SMaterial@ material = SMaterial();

    string textureName;
    f32 width = 16.0f;
    f32 height = 20.0f;
    int columns = 12;
    int rows = 24;
    bool zBuffer = true;
    bool zWrite = true;

    int lastFrameRow = -1;
    int lastDirectionFrame = -1;

    Billboard3D() {}

    Billboard3D(const string &in _textureName, f32 _width, f32 _height)
    {
        Setup(_textureName, _width, _height);
    }

    void Setup(const string &in _textureName, f32 _width, f32 _height)
    {
        Setup(_textureName, _width, _height, 12, 24, true, true);
    }

    void Setup(const string &in _textureName, f32 _width, f32 _height, int _columns, int _rows, bool _zBuffer, bool _zWrite)
    {
        textureName = _textureName;
        width = _width;
        height = _height;
        columns = _columns < 1 ? 1 : _columns;
        rows = _rows < 1 ? 1 : _rows;
        zBuffer = _zBuffer;
        zWrite = _zWrite;
        lastFrameRow = -1;
        lastDirectionFrame = -1;

        mesh.SetHardwareMapping(SMesh::DYNAMIC);

        material.AddTexture(textureName, 0);
        material.DisableAllFlags();
        material.SetFlag(SMaterial::COLOR_MASK, true);
        material.SetFlag(SMaterial::ZBUFFER, zBuffer);
        material.SetFlag(SMaterial::ZWRITE_ENABLE, zWrite);
        material.SetFlag(SMaterial::BACK_FACE_CULLING, false);
        material.SetFlag(SMaterial::FOG_ENABLE, true);
        material.SetMaterialType(SMaterial::TRANSPARENT_ALPHA_CHANNEL_REF);
        mesh.SetMaterial(material);

        UpdateMesh(0, 0);
    }

    void UpdateMesh(int frameRow, int directionFrame)
    {
        if (frameRow == lastFrameRow && directionFrame == lastDirectionFrame)
            return;

        lastFrameRow = frameRow;
        lastDirectionFrame = directionFrame;

        const f32 ubit = 1.0f / f32(columns);
        const f32 vbit = 1.0f / f32(rows);
        const f32 halfWidth = width * 0.5f;

        Vertex[] verts =
        {
            Vertex(-halfWidth, 0.0f,  0.0f, directionFrame * ubit,          f32(frameRow + 1) * vbit, color_white),
            Vertex( halfWidth, 0.0f,  0.0f, f32(directionFrame + 1) * ubit, f32(frameRow + 1) * vbit, color_white),
            Vertex( halfWidth, height, 0.0f, f32(directionFrame + 1) * ubit, f32(frameRow) * vbit,     color_white),
            Vertex(-halfWidth, height, 0.0f, directionFrame * ubit,          f32(frameRow) * vbit,     color_white)
        };

        const u16[] ids = {1, 0, 3, 1, 3, 2};

        mesh.SetVertex(verts);
        mesh.SetIndices(ids);
        mesh.BuildMesh();
        mesh.SetDirty(SMesh::VERTEX_INDEX);
    }

    int GetDirectionFrame(f32 entityYaw, f32 cameraYaw)
    {
        f32 relativeYaw = -entityYaw - cameraYaw - 75.0f;
        while (relativeYaw < 0.0f)
        {
            relativeYaw += 360.0f;
        }
        while (relativeYaw >= 360.0f)
        {
            relativeYaw -= 360.0f;
        }

        int directionFrame = int(relativeYaw / 30.0f) % 12;
        if (directionFrame < 0)
            directionFrame += 12;

        return directionFrame;
    }

    void Render(CBlob@ owner, Vec3f position, f32 entityYaw, Vec3f cameraPosition, float[] model)
    {
        if (owner is null)
            return;

        CSprite@ sprite = owner.getSprite();
        if (sprite is null)
            return;

        const f32 cameraYaw = Vec2f(cameraPosition.x - position.x, cameraPosition.z - position.z).Angle();
        const int frameRow = sprite.getFrame() / 12;
        const int directionFrame = GetDirectionFrame(entityYaw, cameraYaw);
        UpdateMesh(frameRow, directionFrame);

        Matrix::MakeIdentity(model);
        Matrix::SetTranslation(model, position.x, position.y, position.z);
        Matrix::SetRotationDegrees(model, 0.0f, -90.0f + cameraYaw, 0.0f);
        Render::SetModelTransform(model);
        mesh.RenderMeshWithMaterial();
    }

    void Render(Vec3f position, Vec3f cameraPosition, float[] model)
    {
        const f32 cameraYaw = Vec2f(cameraPosition.x - position.x, cameraPosition.z - position.z).Angle();
        UpdateMesh(0, 0);

        Matrix::MakeIdentity(model);
        Matrix::SetTranslation(model, position.x, position.y - height * 0.5f, position.z);
        Matrix::SetRotationDegrees(model, 0.0f, -90.0f + cameraYaw, 0.0f);
        Render::SetModelTransform(model);
        mesh.RenderMeshWithMaterial();
    }

    void RenderFacingCamera(Vec3f position, Vec3f cameraPosition, float[] model)
    {
        Vec3f toCamera = cameraPosition - position;
        if (toCamera.LengthSquared() <= 0.001f)
        {
            Render(position, cameraPosition, model);
            return;
        }

        Vec2f yawVec(toCamera.x, toCamera.z);
        const f32 cameraYaw = yawVec.Angle();
        const f32 horizontalDistance = Maths::Max(0.001f, yawVec.Length());
        const f32 cameraPitch = -Maths::ATan2(toCamera.y, horizontalDistance) * 180.0f / Maths::Pi;

        UpdateMesh(0, 0);

        Matrix::MakeIdentity(model);
        Matrix::SetTranslation(model, position.x, position.y - height * 0.5f, position.z);
        Matrix::SetRotationDegrees(model, cameraPitch, -90.0f + cameraYaw, 0.0f);
        Render::SetModelTransform(model);
        mesh.RenderMeshWithMaterial();
    }

    Vec3f SafeNormal(Vec3f value, Vec3f fallback)
    {
        if (value.LengthSquared() < 0.0001f)
            return fallback;

        return value.Normalize();
    }

    void RenderFacingCameraAxes(Vec3f position, Vec3f cameraRight, Vec3f cameraUp, float[] model)
    {
        const f32 halfWidth = width * 0.5f;
        const f32 halfHeight = height * 0.5f;
        if (halfWidth <= 0.0f || halfHeight <= 0.0f)
            return;

        Vec3f right = SafeNormal(cameraRight, Vec3f(1.0f, 0.0f, 0.0f)) * halfWidth;
        Vec3f up = SafeNormal(cameraUp, Vec3f(0.0f, 1.0f, 0.0f)) * halfHeight;

        Vec3f topLeft = position - right + up;
        Vec3f topRight = position + right + up;
        Vec3f bottomRight = position + right - up;
        Vec3f bottomLeft = position - right - up;

        Vertex[] vertices =
        {
            Vertex(bottomRight.x, bottomRight.y, bottomRight.z, 1, 1, color_white),
            Vertex(bottomLeft.x, bottomLeft.y, bottomLeft.z, 0, 1, color_white),
            Vertex(topLeft.x, topLeft.y, topLeft.z, 0, 0, color_white),
            Vertex(bottomRight.x, bottomRight.y, bottomRight.z, 1, 1, color_white),
            Vertex(topLeft.x, topLeft.y, topLeft.z, 0, 0, color_white),
            Vertex(topRight.x, topRight.y, topRight.z, 1, 0, color_white)
        };

        Matrix::MakeIdentity(model);
        Render::SetModelTransform(model);
        Render::RawTriangles(textureName, vertices);
    }
}
