#include "OceanWave.as"

class OceanWater
{
    SColor high = SColor(210,90,90,95);
    SColor mid = SColor(210,85,85,90);
    SColor low = SColor(210,70,80,85);

    Vertex[] water_Vertices;
    u16[] water_IDs;

    SMesh@ WaterMesh = SMesh();
    SMaterial@ WaterMat = SMaterial();
    //Noise@ noise = Noise();

    OceanWater()
    {
        WaterMesh.SetHardwareMapping(SMesh::DYNAMIC);

        CMap@ map = getMap();

        const int mapWidth = Maths::Round((map.tilemapwidth+OCEAN_WAVE_CELL_SIZE)/OCEAN_WAVE_CELL_SIZE);
        const int mapHeight = Maths::Round((map.tilemapheight+OCEAN_WAVE_CELL_SIZE)/OCEAN_WAVE_CELL_SIZE);
        const int meshWidth = mapWidth + OCEAN_VISUAL_BORDER_CELLS * 2;
        const int meshHeight = mapHeight + OCEAN_VISUAL_BORDER_CELLS * 2;

        water_Vertices.set_length((meshWidth+1)*(meshHeight+1));
        water_IDs.set_length( (meshWidth) * (meshHeight) * 6);

        uint v = 0;
        uint t = 0;
        for (uint y = 0; y <= meshHeight; y++) {
            const int row = int(y) - OCEAN_VISUAL_BORDER_CELLS;
            for (uint x = 0; x <= meshWidth; x++) {
                const int col = int(x) - OCEAN_VISUAL_BORDER_CELLS;
                water_Vertices[v]= Vertex( row*OCEAN_WAVE_CELL_SIZE*map.tilesize, 0.0, col*OCEAN_WAVE_CELL_SIZE*map.tilesize, col*(OCEAN_WAVE_CELL_SIZE/4), row*(OCEAN_WAVE_CELL_SIZE/4), SColor(230, 50,50,50));
                v++;
            }   
        }
        v = 0;
        for (uint y = 0; y < meshHeight; y++) {
            for (uint x = 0; x < meshWidth; x++) {
                water_IDs[t] =   v;
                water_IDs[t+1] = water_IDs[t+3] = v+1;
                water_IDs[t+2] = water_IDs[t+4] = v+(meshWidth+1);
                water_IDs[t+5] = v+(meshWidth+1)+1;
                v++;
                t+=6;
            }
            v++;
        }   

        WaterMat.AddTexture("Water.png", 0);
        // Normal-map test:
        // WaterMat.AddTexture("NormalWave.png", 1);
        // WaterMat.SetMaterialType(SMaterial::NORMAL_MAP_TRANSPARENT_VERTEX_ALPHA);
        // WaterMat.SetFlag(SMaterial::LIGHTING, true);
        WaterMat.DisableAllFlags();
        WaterMat.SetFlag(SMaterial::COLOR_MASK, true);
        WaterMat.SetFlag(SMaterial::ZBUFFER, true);
        WaterMat.SetFlag(SMaterial::ZWRITE_ENABLE, false);
        WaterMat.SetFlag(SMaterial::BACK_FACE_CULLING, false);
        //WaterMat.SetFlag(SMaterial::ANTI_ALIASING, true);
        WaterMat.SetFlag(SMaterial::BILINEAR_FILTER, true);
        WaterMat.SetLayerBilinearFilter(0, true);
        //WaterMat.SetFlag(SMaterial::ANISOTROPIC_FILTER, true);
        //WaterMat.SetLayerAnisotropicFilter(0, 8);
        WaterMat.SetMaterialType(SMaterial::TRANSPARENT_VERTEX_ALPHA);
       // WaterMat.SetBlendOperation(SMaterial::ADD);
        WaterMat.SetFlag(SMaterial::GOURAUD_SHADING, true);
        //WaterMat.SetFlag(SMaterial::WIREFRAME, true);
        WaterMat.SetFlag(SMaterial::FOG_ENABLE, true);
        WaterMesh.SetMaterial(WaterMat);

        WaterMesh.SetVertex(water_Vertices);
        WaterMesh.SetIndices(water_IDs); 
        WaterMesh.BuildMesh();
        WaterMesh.SetDirty(SMesh::VERTEX_INDEX);
    }


    void Update()
    {
        CMap@ map = getMap();
        if (map is null)
        {
            return;
        }

        const f32 spacing = OCEAN_WAVE_CELL_SIZE * map.tilesize;
        const int mapWidth = Maths::Round((map.tilemapwidth+OCEAN_WAVE_CELL_SIZE)/OCEAN_WAVE_CELL_SIZE);
        const int rowStride = mapWidth + 1;
        for (uint i = 0; i < water_Vertices.length; i++)
        {
            const int row = Maths::Round(water_Vertices[i].x / spacing);
            const int col = Maths::Round(water_Vertices[i].z / spacing);
            f32 h1 = GetOceanWaveDisplacementForVertex(row * rowStride + col);

            water_Vertices[i].y = (OCEAN_START_DEPTH*16)+h1;
            //water_Vertices[i].col = low.getInterpolated_quadratic(mid,high, h1/OCEAN_WAVE_AMPLITUDE);
        }

        WaterMesh.SetVertex(water_Vertices);
        WaterMesh.BuildMesh();
        WaterMesh.SetDirty(SMesh::VERTEX);
    }

    void Render()
    {        
        Matrix::MakeIdentity(model);
        Render::SetModelTransform(model);
        WaterMesh.RenderMeshWithMaterial(); 
    }
    
}
