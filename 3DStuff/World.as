#include "Vec3f.as";
#include "TerrainGen.as";

const float ChunkSize = 48.0f;
//const float tUnit = 0.5f; //texture unit

shared class World
{
	CMap@ map = getMap();	
	uint32 mapWidth = map.tilemapwidth*map.tilesize;
	uint32 mapHeight = 32;
	uint32 mapDepth = map.tilemapheight*map.tilesize;
	uint32 mapWidthDepth = (mapWidth * mapDepth);
	uint32 mapSize = mapWidthDepth * mapHeight;

	uint32 chunksWidth = Maths::Ceil(map.tilemapwidth/ChunkSize);
	uint32 chunksHeight = 0;
	uint32 chunksDepth = Maths::Ceil(map.tilemapheight/ChunkSize);	
	uint32 chunksCount = (chunksWidth * chunksDepth);

	TerrainChunk[] Chunks;	

	Vertex[] edgewall_Vertices;
	u16[] edgewall_IDs;	
	SMesh@ EdgeWallMesh = SMesh();
	SMaterial@ EdgeWallMat = SMaterial();

	World()
	{	
		for (int chunkZ = 0; chunkZ < chunksDepth; chunkZ++)
		for (int chunkX = 0; chunkX < chunksWidth; chunkX++)
		{
			TerrainChunk chunk(this, chunkX, chunkZ, ChunkSize);
			Chunks.push_back(chunk);
		}
		
		//CreateMapEdgeWalls(map, chunksWidth, chunksDepth);
	}

	void CreateMapEdgeWalls(CMap@ map ,int chunksWidth, int chunksDepth)
	{		
		edgewall_Vertices.clear();
		edgewall_IDs.clear();

		edgewall_Vertices.push_back(Vertex(0,-64, chunksWidth,	chunksWidth,0,		SColor(150, 255,255,255)));
		edgewall_Vertices.push_back(Vertex(0, 64, chunksWidth,	chunksWidth,128,	SColor(150, 255,255,255)));
		edgewall_Vertices.push_back(Vertex(0, 64, 0,		0,128,					SColor(150, 255,255,255)));
		edgewall_Vertices.push_back(Vertex(0,-64, 0,		0,0,					SColor(150, 255,255,255)));

		edgewall_IDs = Square_IDs();

		EdgeWallMesh.SetVertex(edgewall_Vertices);
		EdgeWallMesh.SetIndices(edgewall_IDs); 
		EdgeWallMesh.BuildMesh();
		EdgeWallMesh.SetDirty(SMesh::VERTEX_INDEX);

		EdgeWallMat.AddTexture("NoGoZone.png", 0);
		EdgeWallMat.DisableAllFlags();
		EdgeWallMat.SetFlag(SMaterial::COLOR_MASK, true);
		EdgeWallMat.SetFlag(SMaterial::ZBUFFER, true);
		EdgeWallMat.SetFlag(SMaterial::ZWRITE_ENABLE, true);
		EdgeWallMat.SetFlag(SMaterial::BACK_FACE_CULLING, true);
		EdgeWallMat.SetFlag(SMaterial::GOURAUD_SHADING, true);
    	EdgeWallMat.SetMaterialType(SMaterial::TRANSPARENT_ALPHA_CHANNEL );
		EdgeWallMesh.SetMaterial(EdgeWallMat);
	}

    TerrainChunk@ getChunk(int x, int y, int z)
    {
        if(!inChunkBounds(x, z)) return null;
        int index = z*chunksWidth + x;
        TerrainChunk@ chunk = @Chunks[index];
        return @chunk;
    }

    TerrainChunk@ getChunkWorldPos(Vec3f pos)
    {
        if(!inWorldBounds(pos.x, pos.z)) return null;
    	pos.x = int(pos.x/ChunkSize); pos.z = int(pos.z/ChunkSize);
        if(!inChunkBounds(pos.x, pos.z)) return null;
    	
        int index = pos.z * chunksWidth + pos.x;

        //print(""+index);
        TerrainChunk@ chunk = @Chunks[index];
        return @chunk;
    }   

    bool inWorldBounds(int x, int z)
    {
        if(x<0 || z<0 || x>=map.tilemapwidth || z>=map.tilemapheight) return false;
        return true;
    }
    
    bool inChunkBounds(int x, int z)
    {
        if(x<0 || z<0 || x>=chunksWidth || z>=chunksDepth) return false;
        return true;
    }

    void clearVisibility()
    {
        for(int i = 0; i < chunksCount; i++)
        {
            Chunks[i].visible = false;
        }
    }

    //bool isTileSolid(int x, int y, int z)
    //{
    //    if(!inWorldBounds(x, y, z)) return false;
    //    return Blocks[map[y][z][x]].solid;
    //}
    //bool isTileSolidOrOOB(int x, int y, int z)
    //{
    //    if(!inWorldBounds(x, y, z)) return true;
    //    return Blocks[map[y][z][x]].solid;
    //}

	void Render()
	{
		EdgeWallMesh.RenderMeshWithMaterial();
		for(uint i = 0; i < Chunks.size(); i++)
		{
			TerrainChunk@ chunk = Chunks[i];
			
			//if (!chunk.visible) continue; 
			chunk.TerrainMesh.RenderMeshWithMaterial(); 
			chunk.GrassMesh.RenderMeshWithMaterial();
			chunk.PalmsMesh.RenderMeshWithMaterial();

			//chunk.TriMesh.RenderMeshWithMaterial();
		}
		
	}
}
