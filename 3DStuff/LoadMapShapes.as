#include "SAT_Shapes.as";
#include "Camera3D.as";

const f32 ROCK_COLLIDER_DEBUG_INSET = 1.5f;

Vertex[] mountain_Vertices;
u16[] mountain_IDs;
Vertex[] rockCollider_Vertices;
u16[] rockCollider_IDs;

SMesh@ RocksMesh = SMesh();
SMaterial@ RockMat = SMaterial();
SMesh@ RockColliderMesh = SMesh();
SMaterial@ RockColliderMat = SMaterial();

u16[] FlipTriangleWinding(const u16[]&in ids)
{
	u16[] flipped;
	flipped.set_length(ids.length());

	for (uint i = 0; i < ids.length(); i += 3)
	{
		if (i + 2 >= ids.length())
		{
			flipped[i] = ids[i];
			continue;
		}

		flipped[i] = ids[i];
		flipped[i + 1] = ids[i + 2];
		flipped[i + 2] = ids[i + 1];
	}

	return flipped;
}

bool IsRockShapeTile(int tile)
{
	return tile == CMap::rock ||
		(tile >= CMap::rock_shore_convex_RU1 && tile <= CMap::rock_shore_diagonal_L1) ||
		(tile >= CMap::rock_sand_border_convex_RU1 && tile <= CMap::rock_sand_border_diagonal_L1) ||
		(tile >= CMap::rock_shoal_border_convex_RU1 && tile <= CMap::rock_shoal_border_diagonal_L1);
}

void GetRockColliderDebugBounds(CMap@ map, int x, int y, f32 &out minX, f32 &out minZ, f32 &out maxX, f32 &out maxZ)
{
	const u32 offset = y * map.tilemapwidth + x;
	Vec2f center = map.getTileWorldPosition(offset);
	const f32 half = map.tilesize * 0.5f;

	minX = center.x - half;
	maxX = center.x + half;
	minZ = center.y - half;
	maxZ = center.y + half;

	if (!IsRockShapeTile(GetMapTileOrWater(map, x - 1, y))) minX += ROCK_COLLIDER_DEBUG_INSET;
	if (!IsRockShapeTile(GetMapTileOrWater(map, x + 1, y))) maxX -= ROCK_COLLIDER_DEBUG_INSET;
	if (!IsRockShapeTile(GetMapTileOrWater(map, x, y - 1))) minZ += ROCK_COLLIDER_DEBUG_INSET;
	if (!IsRockShapeTile(GetMapTileOrWater(map, x, y + 1))) maxZ -= ROCK_COLLIDER_DEBUG_INSET;
}

void AddRockColliderDebugBox(f32 minX, f32 minZ, f32 maxX, f32 maxZ)
{
	const f32 minY = -8.0f;
	const f32 maxY = 80.0f;
	const SColor col = SColor(180, 0, 255, 255);
	const u16 base = u16(rockCollider_Vertices.length());

	rockCollider_Vertices.push_back(Vertex(minX, minY, minZ, 0, 0, col));
	rockCollider_Vertices.push_back(Vertex(maxX, minY, minZ, 1, 0, col));
	rockCollider_Vertices.push_back(Vertex(maxX, minY, maxZ, 1, 1, col));
	rockCollider_Vertices.push_back(Vertex(minX, minY, maxZ, 0, 1, col));
	rockCollider_Vertices.push_back(Vertex(minX, maxY, minZ, 0, 0, col));
	rockCollider_Vertices.push_back(Vertex(maxX, maxY, minZ, 1, 0, col));
	rockCollider_Vertices.push_back(Vertex(maxX, maxY, maxZ, 1, 1, col));
	rockCollider_Vertices.push_back(Vertex(minX, maxY, maxZ, 0, 1, col));

	const u16[] ids = {
		0, 1, 2, 0, 2, 3,
		4, 6, 5, 4, 7, 6,
		0, 4, 5, 0, 5, 1,
		1, 5, 6, 1, 6, 2,
		2, 6, 7, 2, 7, 3,
		3, 7, 4, 3, 4, 0
	};

	for (uint i = 0; i < ids.length(); i++)
	{
		rockCollider_IDs.push_back(base + ids[i]);
	}
}

int GetMapTileOrWater(CMap@ map, int x, int y)
{
	if (x < 0 || y < 0 || x >= map.tilemapwidth || y >= map.tilemapheight)
	{
		return CMap::water;
	}

	return map.getTile(y * map.tilemapwidth + x).type;
}

bool IsRockEdge(CMap@ map, int x, int y)
{
	return !IsRockShapeTile(GetMapTileOrWater(map, x, y));
}

int GetPlainRockShapeTile(CMap@ map, u32 offset)
{
	const int x = offset % map.tilemapwidth;
	const int y = offset / map.tilemapwidth;

	const bool R = IsRockEdge(map, x + 1, y);
	const bool U = IsRockEdge(map, x, y - 1);
	const bool L = IsRockEdge(map, x - 1, y);
	const bool D = IsRockEdge(map, x, y + 1);
	const bool RU = IsRockEdge(map, x + 1, y - 1);
	const bool LU = IsRockEdge(map, x - 1, y - 1);
	const bool LD = IsRockEdge(map, x - 1, y + 1);
	const bool RD = IsRockEdge(map, x + 1, y + 1);

	if (R && U && L && D) return CMap::rock_sand_border_island1;
	if (RU && LU && LD && RD && !R && !U && !L && !D) return CMap::rock_sand_border_cross1;
	if (R && U && D) return CMap::rock_sand_border_peninsula_R1;
	if (R && U && L) return CMap::rock_sand_border_peninsula_U1;
	if (U && L && D) return CMap::rock_sand_border_peninsula_L1;
	if (L && D && R) return CMap::rock_sand_border_peninsula_D1;
	if (RU && LU && D && !R && !U && !L) return CMap::rock_sand_border_T_D1;
	if (RU && L && RD && !R && !U && !D) return CMap::rock_sand_border_T_L1;
	if (U && RD && LD && !R && !L && !D) return CMap::rock_sand_border_T_U1;
	if (R && LU && LD && !U && !L && !D) return CMap::rock_sand_border_T_R1;
	if (R && LU && !U && !L && !LD && !D) return CMap::rock_sand_border_panhandleL_R1;
	if (U && LD && !R && !L && !D && !RD) return CMap::rock_sand_border_panhandleL_U1;
	if (L && RD && !R && !RU && !U && !D) return CMap::rock_sand_border_panhandleL_L1;
	if (RU && D && !R && !U && !LU && !L) return CMap::rock_sand_border_panhandleL_D1;
	if (R && LD && !U && !LU && !L && !D) return CMap::rock_sand_border_panhandleR_R1;
	if (U && RD && !R && !L && !LD && !D) return CMap::rock_sand_border_panhandleR_U1;
	if (RU && L && !R && !U && !D && !RD) return CMap::rock_sand_border_panhandleR_L1;
	if (LU && D && !R && !RU && !U && !L) return CMap::rock_sand_border_panhandleR_D1;
	if (RU && LU && RD && !R && !U && !L && !LD && !D) return CMap::rock_sand_border_split_RU1;
	if (RU && LU && LD && !R && !U && !L && !D && !RD) return CMap::rock_sand_border_split_LU1;
	if (LU && LD && RD && !R && !RU && !U && !L && !D) return CMap::rock_sand_border_split_LD1;
	if (RU && LD && RD && !R && !U && !LU && !L && !D) return CMap::rock_sand_border_split_RD1;
	if (RU && RD && !R && !U && !LU && !L && !LD && !D) return CMap::rock_sand_border_choke_R1;
	if (RU && LU && !R && !U && !L && !LD && !D && !RD) return CMap::rock_sand_border_choke_U1;
	if (LU && LD && !R && !RU && !U && !L && !D && !RD) return CMap::rock_sand_border_choke_L1;
	if (LD && RD && !R && !RU && !U && !LU && !L && !D) return CMap::rock_sand_border_choke_D1;
	if (U && D) return CMap::rock_sand_border_strip_H1;
	if (R && L) return CMap::rock_sand_border_strip_V1;
	if (L && LU && U && RD) return CMap::rock_sand_border_bend_LU1;
	if (R && RU && U && LD) return CMap::rock_sand_border_bend_RU1;
	if (R && RD && D && LU) return CMap::rock_sand_border_bend_RD1;
	if (L && LD && D && RU) return CMap::rock_sand_border_bend_LD1;
	if (RU && LD && !R && !U && !LU && !L && !D && !RD) return CMap::rock_sand_border_diagonal_R1;
	if (LU && RD && !R && !RU && !U && !L && !LD && !D) return CMap::rock_sand_border_diagonal_L1;
	if (R && !U && !LU && !L && !LD && !D) return CMap::rock_sand_border_straight_R1;
	if (U && !R && !L && !LD && !D && !RD) return CMap::rock_sand_border_straight_U1;
	if (L && !R && !RU && !U && !D && !RD) return CMap::rock_sand_border_straight_L1;
	if (D && !R && !RU && !U && !LU && !L) return CMap::rock_sand_border_straight_D1;
	if (R && U) return CMap::rock_sand_border_convex_RU1;
	if (L && U) return CMap::rock_sand_border_convex_LU1;
	if (L && D) return CMap::rock_sand_border_convex_LD1;
	if (R && D) return CMap::rock_sand_border_convex_RD1;
	if (RU) return CMap::rock_sand_border_concave_RU1;
	if (LU) return CMap::rock_sand_border_concave_LU1;
	if (LD) return CMap::rock_sand_border_concave_LD1;
	if (RD) return CMap::rock_sand_border_concave_RD1;

	return CMap::rock;
}

void LoadMapShapes(CMap@ map)
{
	Map_SAT_Shapes shapes();
	map.set("Map_SAT_Info", @shapes);	

	Map_SAT_Shapes map_shapes();
	mountain_Vertices.clear();
	mountain_IDs.clear();
	rockCollider_Vertices.clear();
	rockCollider_IDs.clear();

	const uint tileCount = map.tilemapwidth * map.tilemapheight;

    RocksMesh.SetHardwareMapping(SMesh::DYNAMIC);  

	u16 lastID = 0;

	for (u32 offset = 0; offset < tileCount; ++offset)
	{
		TileType tile = map.getTile(offset).type;
		int shapeTile = tile;
		if (tile == CMap::rock)
		{
			shapeTile = GetPlainRockShapeTile(map, offset);
		}
		else if (tile >= CMap::rock_shore_convex_RU1 && tile <= CMap::rock_shore_diagonal_L1)
		{
			shapeTile = CMap::rock_sand_border_convex_RU1 + (tile - CMap::rock_shore_convex_RU1);
		}
		else if (tile >= CMap::rock_shoal_border_convex_RU1 && tile <= CMap::rock_shoal_border_diagonal_L1)
		{
			shapeTile = CMap::rock_sand_border_convex_RU1 + (tile - CMap::rock_shoal_border_convex_RU1);
		}

		Vec2f pos_off = map.getTileWorldPosition(offset);
		Vec2f tile_center = pos_off;
		pos_off /= 16;

		if (IsRockShapeTile(tile))
		{
			const int tileX = int(offset % map.tilemapwidth);
			const int tileY = int(offset / map.tilemapwidth);
			f32 colliderMinX;
			f32 colliderMinZ;
			f32 colliderMaxX;
			f32 colliderMaxZ;
			GetRockColliderDebugBounds(map, tileX, tileY, colliderMinX, colliderMinZ, colliderMaxX, colliderMaxZ);
			AddRockColliderDebugBox(colliderMinX, colliderMinZ, colliderMaxX, colliderMaxZ);
		}

		switch (shapeTile)
		{
			case CMap::rock:
			{
				for (uint i = 0; i < Rock_island_Vertices.length; i++) {
					Vertex v = Rock_island_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }

				for (uint i = 0; i < Rock_island_IDs.length; i++) {
					mountain_IDs.push_back( lastID+Rock_island_IDs[i] ); }

				lastID += Rock_island_Vertices.length;
				map_shapes.PushAShape(full_rock_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_island1: 
			{
				for (uint i = 0; i < Rock_island_Vertices.length; i++) {
					Vertex v = Rock_island_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_island_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_island_IDs[i] ); }

				lastID += Rock_island_Vertices.length;
				map_shapes.PushAShape(island_Shape, tile_center, offset, 0);
			}break;

			//four way crossing
			case CMap::rock_sand_border_cross1:
			{				
				for (uint i = 0; i < Rock_cross_Vertices.length; i++) {
					Vertex v = Rock_cross_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_cross_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_cross_IDs[i] ); }
										
				lastID += Rock_cross_Vertices.length;				
				map_shapes.PushAShape(cross_Shape, tile_center, offset, 0);
			}break;		
		
			//peninsula shorelines
			case CMap::rock_sand_border_peninsula_R1:
			{				
				for (uint i = 0; i < Rock_peninsula_Vertices.length; i++) {
					Vertex v = Rock_peninsula_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_peninsula_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_peninsula_IDs[i] ); }
										
				lastID += Rock_peninsula_Vertices.length;
				map_shapes.PushAShape(peninsula_Shape, tile_center, offset, 270);
			}break;	

			case CMap::rock_sand_border_peninsula_U1:
			{				
				for (uint i = 0; i < Rock_peninsula_Vertices.length; i++) {
					Vertex v = Rock_peninsula_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_peninsula_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_peninsula_IDs[i] ); }
										
				lastID += Rock_peninsula_Vertices.length;
				map_shapes.PushAShape(peninsula_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_peninsula_L1:
			{				
				for (uint i = 0; i < Rock_peninsula_Vertices.length; i++) {
					Vertex v = Rock_peninsula_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_peninsula_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_peninsula_IDs[i] ); }
										
				lastID += Rock_peninsula_Vertices.length;
				map_shapes.PushAShape(peninsula_Shape, tile_center, offset,90);
			}break;

			case CMap::rock_sand_border_peninsula_D1: 
			{				
				for (uint i = 0; i < Rock_peninsula_Vertices.length; i++) {
					Vertex v = Rock_peninsula_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_peninsula_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_peninsula_IDs[i] ); }
										
				lastID += Rock_peninsula_Vertices.length;				
				map_shapes.PushAShape(peninsula_Shape, tile_center, offset, 180);
			}break;	
				
			//three way T crossings	
			case CMap::rock_sand_border_T_D1:
			{				
				for (uint i = 0; i < Rock_tee_Vertices.length; i++) {
					Vertex v = Rock_tee_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }//
				for (uint i = 0; i < Rock_tee_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_tee_IDs[i] ); }

					lastID += Rock_tee_Vertices.length;
				map_shapes.PushAShape(tee_Shape, tile_center, offset, 180);
			}break;

			case CMap::rock_sand_border_T_L1:
			{				
				for (uint i = 0; i < Rock_tee_Vertices.length; i++) {
					Vertex v = Rock_tee_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }//
				for (uint i = 0; i < Rock_tee_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_tee_IDs[i] ); }

				lastID += Rock_tee_Vertices.length;
				map_shapes.PushAShape(tee_Shape, tile_center, offset, 90);
			}	break;

			case CMap::rock_sand_border_T_U1:
			{				
				for (uint i = 0; i < Rock_tee_Vertices.length; i++) {
					Vertex v = Rock_tee_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }//
				for (uint i = 0; i < Rock_tee_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_tee_IDs[i] ); }	

				lastID += Rock_tee_Vertices.length;
				map_shapes.PushAShape(tee_Shape, tile_center, offset);
			}break;

			case CMap::rock_sand_border_T_R1:
			{				
				for (uint i = 0; i < Rock_tee_Vertices.length; i++) {
					Vertex v = Rock_tee_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }//
				for (uint i = 0; i < Rock_tee_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_tee_IDs[i] ); }	

				lastID += Rock_tee_Vertices.length;
				map_shapes.PushAShape(tee_Shape, tile_center, offset, 270);
			}break;
				
			//left handed panhandle
			case CMap::rock_sand_border_panhandleL_R1:
			{		
				for (uint i = 0; i < Rock_panhandle_L_Vertices.length; i++) {
					Vertex v = Rock_panhandle_L_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_panhandle_L_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_panhandle_L_IDs[i] ); }
//
				lastID += Rock_panhandle_L_Vertices.length;
				map_shapes.PushAShape(panhandle_l_Shape, tile_center, offset, 270);
			}break;	

			case CMap::rock_sand_border_panhandleL_U1:
			{				
				for (uint i = 0; i < Rock_panhandle_L_Vertices.length; i++) {
					Vertex v = Rock_panhandle_L_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_panhandle_L_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_panhandle_L_IDs[i] ); }

				lastID += Rock_panhandle_L_Vertices.length;
				map_shapes.PushAShape(panhandle_l_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_panhandleL_L1:
			{				
				for (uint i = 0; i < Rock_panhandle_L_Vertices.length; i++) {
					Vertex v = Rock_panhandle_L_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_panhandle_L_IDs.length; i++) {			
					mountain_IDs.push_back( lastID+Rock_panhandle_L_IDs[i] ); }

					lastID += Rock_panhandle_L_Vertices.length;
				map_shapes.PushAShape(panhandle_l_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_panhandleL_D1:
			{				
				for (uint i = 0; i < Rock_panhandle_L_Vertices.length; i++) {
					Vertex v = Rock_panhandle_L_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	
//
				for (uint i = 0; i < Rock_panhandle_L_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_panhandle_L_IDs[i] ); }

					lastID += Rock_panhandle_L_Vertices.length;
				map_shapes.PushAShape(panhandle_l_Shape, tile_center, offset, 180);
			}break;
				
			//right handed panhandle
			case CMap::rock_sand_border_panhandleR_R1:
			{	
					for (uint i = 0; i < Rock_panhandle_R_Vertices.length; i++) {
					Vertex v = Rock_panhandle_R_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_panhandle_R_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_panhandle_R_IDs[i] ); }

					lastID += Rock_panhandle_R_Vertices.length;
				map_shapes.PushAShape(panhandle_r_Shape, tile_center, offset, 270);
			}break;

			case CMap::rock_sand_border_panhandleR_U1:
			{				
					for (uint i = 0; i < Rock_panhandle_R_Vertices.length; i++) {
					Vertex v = Rock_panhandle_R_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_panhandle_R_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_panhandle_R_IDs[i] ); }

					lastID += Rock_panhandle_R_Vertices.length;				
				map_shapes.PushAShape(panhandle_r_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_panhandleR_L1:
			{				
					for (uint i = 0; i < Rock_panhandle_R_Vertices.length; i++) {
					Vertex v = Rock_panhandle_R_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_panhandle_R_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_panhandle_R_IDs[i] ); }

					lastID += Rock_panhandle_R_Vertices.length;
				map_shapes.PushAShape(panhandle_r_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_panhandleR_D1:
			{				
					for (uint i = 0; i < Rock_panhandle_R_Vertices.length; i++) {
					Vertex v = Rock_panhandle_R_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_panhandle_R_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_panhandle_R_IDs[i] ); }

					lastID += Rock_panhandle_R_Vertices.length;
				map_shapes.PushAShape(panhandle_r_Shape, tile_center, offset, 180);
			}break;
				
			//splitting strips
			case CMap::rock_sand_border_split_RU1:
			{	
				for (uint i = 0; i < Rock_split_Vertices.length; i++) {
					Vertex v = Rock_split_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_split_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_split_IDs[i] ); }

					lastID += Rock_split_Vertices.length;
				map_shapes.PushAShape(split_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_split_LU1:
			{			
				for (uint i = 0; i < Rock_split_Vertices.length; i++) {
					Vertex v = Rock_split_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_split_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_split_IDs[i] ); }

					lastID += Rock_split_Vertices.length;
				map_shapes.PushAShape(split_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_split_LD1:
			{
				for (uint i = 0; i < Rock_split_Vertices.length; i++) {
					Vertex v = Rock_split_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_split_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_split_IDs[i] ); }

					lastID += Rock_split_Vertices.length;
				map_shapes.PushAShape(split_Shape, tile_center, offset, 180);
			}break;

			case CMap::rock_sand_border_split_RD1:
			{
				for (uint i = 0; i < Rock_split_Vertices.length; i++) {
					Vertex v = Rock_split_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_split_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_split_IDs[i] ); }

					lastID += Rock_split_Vertices.length;
				map_shapes.PushAShape(split_Shape, tile_center, offset, 270);
			}break;
				
			//choke points
			case CMap::rock_sand_border_choke_R1:
			{
				for (uint i = 0; i < Rock_choke_Vertices.length; i++) {
					Vertex v = Rock_choke_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_choke_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_choke_IDs[i] ); }

					lastID += Rock_choke_Vertices.length;
				map_shapes.PushAShape(choke_Shape, tile_center, offset, 270);
			}break;
			case CMap::rock_sand_border_choke_U1:
			{
				for (uint i = 0; i < Rock_choke_Vertices.length; i++) {
					Vertex v = Rock_choke_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_choke_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_choke_IDs[i] ); }

					lastID += Rock_choke_Vertices.length;
				map_shapes.PushAShape(choke_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_choke_L1:
			{
				for (uint i = 0; i < Rock_choke_Vertices.length; i++) {
					Vertex v = Rock_choke_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_choke_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_choke_IDs[i] ); }

					lastID += Rock_choke_Vertices.length;
				map_shapes.PushAShape(choke_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_choke_D1:
			{
				for (uint i = 0; i < Rock_choke_Vertices.length; i++) {
					Vertex v = Rock_choke_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_choke_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_choke_IDs[i] ); }

					lastID += Rock_choke_Vertices.length;
				map_shapes.PushAShape(choke_Shape, tile_center, offset, 180);
			}break;
				
			//strip shorelines
			case CMap::rock_sand_border_strip_H1:
			{

				for (uint i = 0; i < Rock_strip_Vertices.length; i++) {
					Vertex v = Rock_strip_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_strip_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_strip_IDs[i] ); }

					lastID += Rock_strip_Vertices.length;
				map_shapes.PushAShape(strip_Shape, tile_center, offset, 0);
			}break;
			case CMap::rock_sand_border_strip_V1:
			{
				for (uint i = 0; i < Rock_strip_Vertices.length; i++) {
					Vertex v = Rock_strip_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_strip_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_strip_IDs[i] ); }

					lastID += Rock_strip_Vertices.length;
				map_shapes.PushAShape(strip_Shape, tile_center, offset, 90);
			}break;

			//bend shorelines
			case CMap::rock_sand_border_bend_LU1:
			{
				for (uint i = 0; i < Rock_bend_Vertices.length; i++) {
					Vertex v = Rock_bend_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_bend_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_bend_IDs[i] ); }

				lastID += Rock_bend_Vertices.length;
				map_shapes.PushAShape(bend_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_bend_RU1:
			{
				for (uint i = 0; i < Rock_bend_Vertices.length; i++) {
					Vertex v = Rock_bend_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_bend_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_bend_IDs[i] ); }

					lastID += Rock_bend_Vertices.length;
				map_shapes.PushAShape(bend_Shape, tile_center, offset);
			}break;

			case CMap::rock_sand_border_bend_RD1:
			{
				for (uint i = 0; i < Rock_bend_Vertices.length; i++) {
					Vertex v = Rock_bend_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_bend_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_bend_IDs[i] ); }

					lastID += Rock_bend_Vertices.length;
				map_shapes.PushAShape(bend_Shape, tile_center, offset,270);	
			}break;

			case CMap::rock_sand_border_bend_LD1:
			{
				for (uint i = 0; i < Rock_bend_Vertices.length; i++) {
					Vertex v = Rock_bend_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_bend_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_bend_IDs[i] ); }

					lastID += Rock_bend_Vertices.length;
				map_shapes.PushAShape(bend_Shape, tile_center, offset,180);
			}break;

			//diagonal choke points
			case CMap::rock_sand_border_diagonal_R1:
			{
				for (uint i = 0; i < Rock_diagonal_Vertices.length; i++) {
					Vertex v = Rock_diagonal_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_diagonal_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_diagonal_IDs[i] ); }

				lastID += Rock_diagonal_Vertices.length;				
				map_shapes.PushAShape(diagonal_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_diagonal_L1:
			{
				for (uint i = 0; i < Rock_diagonal_Vertices.length; i++) {
					Vertex v = Rock_diagonal_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_diagonal_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_diagonal_IDs[i] ); }

				lastID += Rock_diagonal_Vertices.length;
				map_shapes.PushAShape(diagonal_Shape, tile_center, offset, 90);	
			}break;

			//straight edge shorelines
			case CMap::rock_sand_border_straight_R1:
			{
				for (uint i = 0; i < Rock_straight_Vertices.length; i++) {
					Vertex v = Rock_straight_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_straight_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_straight_IDs[i] ); }

				lastID += Rock_straight_Vertices.length;
				map_shapes.PushAShape(straight_Shape, tile_center, offset, 270);
			}break;

			case CMap::rock_sand_border_straight_U1:
			{
				for (uint i = 0; i < Rock_straight_Vertices.length; i++) {
					Vertex v = Rock_straight_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_straight_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_straight_IDs[i] ); }

				lastID += Rock_straight_Vertices.length;
				map_shapes.PushAShape(straight_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_straight_L1:
			{
				for (uint i = 0; i < Rock_straight_Vertices.length; i++) {
					Vertex v = Rock_straight_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_straight_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_straight_IDs[i] ); }

				lastID += Rock_straight_Vertices.length;
				map_shapes.PushAShape(straight_Shape, tile_center, offset,90);
			}break;

			case CMap::rock_sand_border_straight_D1:
			{
				for (uint i = 0; i < Rock_straight_Vertices.length; i++) {
					Vertex v = Rock_straight_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_straight_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_straight_IDs[i] ); }

				lastID += Rock_straight_Vertices.length;
				map_shapes.PushAShape(straight_Shape, tile_center, offset,180);
			}break;
				
			//convex shorelines
			case CMap::rock_sand_border_convex_LU1:
			{
				//RocksMesh.LoadObjIntoMesh("RockCorner1.obj");

				for (uint i = 0; i < Rock_Corner_Vertices.length; i++) {
					Vertex v = Rock_Corner_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); 
				}

				for (uint i = 0; i < Rock_Corner_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_Corner_IDs[i] );
            	}

					lastID += Rock_Corner_Vertices.length;
					map_shapes.PushAShape(corner_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_convex_RU1:
			{	
				for (uint i = 0; i < Rock_Corner_Vertices.length; i++) {
					Vertex v = Rock_Corner_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_Corner_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_Corner_IDs[i] ); }

				lastID += Rock_Corner_Vertices.length;
				map_shapes.PushAShape(corner_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_convex_RD1:
			{
				for (uint i = 0; i < Rock_Corner_Vertices.length; i++) {
					Vertex v = Rock_Corner_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_Corner_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_Corner_IDs[i] ); }

				lastID += Rock_Corner_Vertices.length;
				map_shapes.PushAShape(corner_Shape, tile_center, offset, 270);
			}break;

			case CMap::rock_sand_border_convex_LD1:
			{
				for (uint i = 0; i < Rock_Corner_Vertices.length; i++) {
					Vertex v = Rock_Corner_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_Corner_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_Corner_IDs[i] ); }

				lastID += Rock_Corner_Vertices.length;
				map_shapes.PushAShape(corner_Shape, tile_center, offset, 180);
			}break;
				
			//concave shorelines		
			case CMap::rock_sand_border_concave_RU1:
			{
				for (uint i = 0; i < Rock_concave_Vertices.length; i++) {
					Vertex v = Rock_concave_Vertices[i];
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_concave_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_concave_IDs[i] ); }

				lastID += Rock_concave_Vertices.length;
				map_shapes.PushAShape(concave_Shape, tile_center, offset, 0);
			}break;

			case CMap::rock_sand_border_concave_LU1:
			{
				for (uint i = 0; i < Rock_concave_Vertices.length; i++) {
					Vertex v = Rock_concave_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(90);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_concave_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_concave_IDs[i] ); }

				lastID += Rock_concave_Vertices.length;
				map_shapes.PushAShape(concave_Shape, tile_center, offset, 90);
			}break;

			case CMap::rock_sand_border_concave_LD1:
			{
				for (uint i = 0; i < Rock_concave_Vertices.length; i++) {
					Vertex v = Rock_concave_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(180);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_concave_IDs.length; i++) {			
					mountain_IDs.push_back(lastID+Rock_concave_IDs[i] ); }

				lastID += Rock_concave_Vertices.length;
				map_shapes.PushAShape(concave_Shape, tile_center, offset, 180);
			}break;

			case CMap::rock_sand_border_concave_RD1:
			{
				for (uint i = 0; i < Rock_concave_Vertices.length(); i++) {
					Vertex v = Rock_concave_Vertices[i];
					Vec2f np(v.x,v.z);
					np.RotateBy(270);
					v.x = np.x; v.z = np.y;
					v.x += pos_off.y; v.z += pos_off.x;
					mountain_Vertices.push_back( v ); }	

				for (uint i = 0; i < Rock_concave_IDs.length(); i++) {			
					mountain_IDs.push_back(lastID+Rock_concave_IDs[i] ); }

				lastID += Rock_concave_Vertices.length();
				map_shapes.PushAShape(concave_Shape, tile_center, offset, 270);
			}break;

		}	
	}
	map.set("Map_SAT_Info", @map_shapes);
 
 	if (mountain_Vertices.length() > 0)
 	{	 		
		for (uint i = 0; i < mountain_Vertices.length(); i++)
		{
			Vertex v = mountain_Vertices[i];
			f32 mapX = v.z;
			v.z = v.x * 16.0f;
			v.x = mapX * 16.0f;
			v.y *= 16.0f;
			mountain_Vertices[i] = v;
		}

		RocksMesh.SetVertex(mountain_Vertices);
	    RocksMesh.SetIndices(FlipTriangleWinding(mountain_IDs)); 
 
	   	RocksMesh.BuildMesh();
	    RocksMesh.SetDirty(SMesh::VERTEX_INDEX);

	    RockMat.AddTexture("StoneTexture.png", 0);

	    RockMat.DisableAllFlags();
	    RockMat.SetFlag(SMaterial::COLOR_MASK, true);
	    RockMat.SetFlag(SMaterial::ZBUFFER, true);
	    RockMat.SetFlag(SMaterial::ZWRITE_ENABLE, true);
	    SetMirrorAwareMaterialCulling(RockMat, true);
	    RockMat.SetMaterialType(SMaterial::SOLID);
	    //RockMat.SetFlag(SMaterial::LIGHTING, true);
	    //RockMat.SetEmissiveColor(SColor(255,255,0,180));
	    RocksMesh.SetMaterial(RockMat);
	}

	if (rockCollider_Vertices.length() > 0)
	{
		RockColliderMesh.SetVertex(rockCollider_Vertices);
		RockColliderMesh.SetIndices(rockCollider_IDs);
		RockColliderMesh.BuildMesh();
		RockColliderMesh.SetDirty(SMesh::VERTEX_INDEX);

		RockColliderMat.DisableAllFlags();
		RockColliderMat.SetFlag(SMaterial::COLOR_MASK, true);
		RockColliderMat.SetFlag(SMaterial::ZBUFFER, true);
		RockColliderMat.SetFlag(SMaterial::ZWRITE_ENABLE, false);
		SetMirrorAwareMaterialCulling(RockColliderMat, false);
		RockColliderMat.SetFlag(SMaterial::WIREFRAME, true);
		RockColliderMat.SetMaterialType(SMaterial::TRANSPARENT_VERTEX_ALPHA);
		RockColliderMesh.SetMaterial(RockColliderMat);
	}
}

const Vec2f[] peninsula_Shape =  
  { Vec2f(-4.0f,  8.0f),
	Vec2f(-4.0f, -2.0f),
	Vec2f(-2.0f, -4.0f),
	Vec2f( 2.0f, -4.0f),
	Vec2f( 4.0f, -2.0f),
	Vec2f( 4.0f,  8.0f)};

const Vec2f[] full_rock_Shape =
{	Vec2f(-8.0f,-8.0f),
	Vec2f( 8.0f,-8.0f),
	Vec2f( 8.0f, 8.0f),
	Vec2f(-8.0f, 8.0f)};

const Vec2f[] concave_Shape = 
{  Vec2f(-8.0f,-8.0f),
   Vec2f( 4.0f,-8.0f),
   Vec2f( 8.0f,-4.0f),
   Vec2f( 8.0f, 8.0f),
   Vec2f(-8.0f, 8.0f)};

const Vec2f[] corner_Shape = 
{   
	Vec2f(-8.0f, 8.0f),
	Vec2f(-8.0f,-4.0f),
	Vec2f(-1.0f,-3.0f),
	Vec2f( 3.0f, 1.0f),
	Vec2f( 4.0f, 8.0f)};

const Vec2f[] straight_Shape = 
{	Vec2f(-8.0f,-4.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 8.0f),
	Vec2f(-8.0f, 8.0f)};

const Vec2f[] diagonal_Shape =
{	Vec2f(-8.0f,-8.0f),
	Vec2f( 4.0f,-8.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 8.0f),
	Vec2f(-4.0f, 8.0f),
	Vec2f(-8.0f, 4.0f)};

const Vec2f[] bend_Shape = 
{   Vec2f(-4.0f, 8.0f),
	Vec2f(-8.0f, 4.0f),
	Vec2f(-8.0f,-4.0f),
	Vec2f(-1.0f,-3.0f),
	Vec2f( 3.0f, 1.0f),
	Vec2f( 4.0f, 8.0f)};

const Vec2f[] strip_Shape = 
{	Vec2f(-8.0f,-4.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 4.0f),
	Vec2f(-8.0f, 4.0f)};

const Vec2f[] choke_Shape = 
{	Vec2f(-8.0f,-4.0f),
 	Vec2f(-4.0f,-8.0f),
	Vec2f( 4.0f,-8.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 8.0f),
	Vec2f(-8.0f, 8.0f)};

const Vec2f[] split_Shape = 
{	Vec2f(-8.0f,-4.0f),
	Vec2f(-4.0f,-8.0f),
	Vec2f( 4.0f,-8.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 4.0f),
	Vec2f( 4.0f, 8.0f),
	Vec2f(-8.0f, 8.0f)};

const Vec2f[] panhandle_r_Shape = 
{	Vec2f(-8.0f, 8.0f),
	Vec2f(-8.0f,-4.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 4.0f),
	Vec2f( 4.0f, 8.0f)};

const Vec2f[] panhandle_l_Shape = 
{	Vec2f(-4.0f, 8.0f),
	Vec2f(-8.0f, 4.0f),
	Vec2f(-8.0f,-4.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 8.0f)};

const Vec2f[] cross_Shape = 
{	Vec2f(-8.0f,-4.0f),
	Vec2f(-4.0f,-8.0f),
	Vec2f( 4.0f,-8.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 4.0f),
	Vec2f( 4.0f, 8.0f),
	Vec2f(-4.0f, 8.0f),
	Vec2f(-8.0f, 4.0f)};

const Vec2f[] island_Shape = 
{	Vec2f(-6.0f, -3.0f),
	 Vec2f(-3.0f, -6.0f),
	 Vec2f( 3.0f, -6.0f),
	 Vec2f( 6.0f, -3.0f),
	 Vec2f( 6.0f,  3.0f),
	 Vec2f( 3.0f,  6.0f),
	 Vec2f(-3.0f,  6.0f),
	 Vec2f(-6.0f,  3.0f)};

const Vec2f[] tee_Shape = 
{	Vec2f(-8.0f,-4.0f),
	Vec2f( 8.0f,-4.0f),
	Vec2f( 8.0f, 4.0f),
	Vec2f( 4.0f, 8.0f),
	Vec2f(-4.0f, 8.0f),
	Vec2f(-8.0f, 4.0f)};
