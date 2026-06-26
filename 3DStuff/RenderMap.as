#include "IslandsCommon.as"
#include "RenderConsts.as"
const string stonetex_name = "StoneTexture.png";

void RenderMap(Vec2f pos, float[] cam, float dirX, float dirY, float[] proj, f32 eye_height)
{	
	float[] model;
	Matrix::MakeIdentity(model);
	SetMirrorAwareRenderBackfaceCull(true);
	

	CMap@ map = getMap();
	const int mapWidth = map.tilemapwidth;
	const int mapHeight = map.tilemapheight;
	
	for (uint x = 0; x < mapWidth; ++x)
	for (uint y = 0; y < mapHeight; ++y)
	{
		Vec2f mpos(x, y);
		TileType tile = map.getTileFromTileSpace(mpos).type;

		if ( tile != CMap::water)
		{
			switch (tile)
			{
				case 0: break; //nothingness

				//case CMap::sand_inland:
				//case CMap::sand_inland+1:
				//case CMap::sand_inland+2:
				//case CMap::sand_inland+3:
				//case CMap::sand_inland+4:
				//{
				//	Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
				//	Matrix::SetRotationDegrees(model, 0, 0, 0);
				//	Render::SetTransform(model, cam, proj);
				//	Render::RawTrianglesIndexed("SandTexture.png", SandFull1_Vertices, SandFull1_IDs);
				//	break;
				//}

				//case CMap::grass_inland:
				//{
				//	Render::SetBackfaceCull(false);
				//	Matrix::SetTranslation(model, (y)-pos.y, eye_height+0.15, (x)-pos.x+0.5);
				//	Render::SetTransform(model, cam, proj);
				//	Render::RawTrianglesIndexed("grass.png", GrassVertices, GrassFace_IDs);
				//	Render::SetBackfaceCull(true);
				//	break;
				//}	
					
				case CMap::rock_sand_border_convex_LU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, MountainCorner_Vertices, MountainCorner_IDs);
					break;
				}	
				case CMap::rock_sand_border_convex_LD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, MountainCorner_Vertices, MountainCorner_IDs);
					break;
				}	
				case CMap::rock_sand_border_convex_RD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, MountainCorner_Vertices, MountainCorner_IDs);
					break;
				}
				case CMap::rock_sand_border_straight_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_straight_Vertices, Rock_straight_IDs);
					break;
				}		
				case CMap::rock_sand_border_straight_U1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_straight_Vertices, Rock_straight_IDs);
					break;
				}	
				case CMap::rock_sand_border_straight_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_straight_Vertices, Rock_straight_IDs);
					break;
				}	
				case CMap::rock_sand_border_straight_D1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_straight_Vertices, Rock_straight_IDs);
					break;
				}
				case CMap::rock_sand_border_concave_RU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_concave_Vertices, Rock_concave_IDs);
					break;
				}		
				case CMap::rock_sand_border_concave_LU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_concave_Vertices, Rock_concave_IDs);
					break;
				}	
				case CMap::rock_sand_border_concave_LD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_concave_Vertices, Rock_concave_IDs);
					break;
				}	
				case CMap::rock_sand_border_concave_RD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_concave_Vertices, Rock_concave_IDs);
					break;
				}
				case CMap::rock_sand_border_peninsula_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_peninsula_Vertices, Rock_peninsula_IDs);
					break;
				}		
				case CMap::rock_sand_border_peninsula_U1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_peninsula_Vertices, Rock_peninsula_IDs);
					break;
				}	
				case CMap::rock_sand_border_peninsula_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_peninsula_Vertices, Rock_peninsula_IDs);
					break;
				}	
				case CMap::rock_sand_border_peninsula_D1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_peninsula_Vertices, Rock_peninsula_IDs);
					break;
				}
				case CMap::rock_sand_border_strip_H1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_strip_Vertices, Rock_strip_IDs);
					break;
				}		
				case CMap::rock_sand_border_strip_V1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_strip_Vertices, Rock_strip_IDs);
					break;
				}	
				case CMap::rock_sand_border_island1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_island_Vertices, Rock_island_IDs);
					break;
				}				
				case CMap::rock_sand_border_cross1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_cross_Vertices, Rock_cross_IDs);
					break;
				}
				case CMap::rock_sand_border_bend_RU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_bend_Vertices, Rock_bend_IDs);
					break;
				}		
				case CMap::rock_sand_border_bend_LU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_bend_Vertices, Rock_bend_IDs);
					break;
				}	
				case CMap::rock_sand_border_bend_LD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_bend_Vertices, Rock_bend_IDs);
					break;
				}	
				case CMap::rock_sand_border_bend_RD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_bend_Vertices, Rock_bend_IDs);
					break;
				}
				case CMap::rock_sand_border_T_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_tee_Vertices, Rock_tee_IDs);
					break;
				}		
				case CMap::rock_sand_border_T_U1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_tee_Vertices, Rock_tee_IDs);
					break;
				}	
				case CMap::rock_sand_border_T_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_tee_Vertices, Rock_tee_IDs);
					break;
				}
				case CMap::rock_sand_border_T_D1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, -180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_tee_Vertices, Rock_tee_IDs);
					break;
				}
				case CMap::rock_sand_border_choke_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_choke_Vertices, Rock_choke_IDs);
					break;
				}		
				case CMap::rock_sand_border_choke_U1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_choke_Vertices, Rock_choke_IDs);
					break;
				}	
				case CMap::rock_sand_border_choke_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_choke_Vertices, Rock_choke_IDs);
					break;
				}
				case CMap::rock_sand_border_choke_D1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_choke_Vertices, Rock_choke_IDs);
					break;
				}
				case CMap::rock_sand_border_split_RU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_split_Vertices, Rock_split_IDs);
					break;
				}		
				case CMap::rock_sand_border_split_LU1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_split_Vertices, Rock_split_IDs);
					break;
				}	
				case CMap::rock_sand_border_split_LD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_split_Vertices, Rock_split_IDs);
					break;
				}
				case CMap::rock_sand_border_split_RD1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_split_Vertices, Rock_split_IDs);
					break;
				}
				case CMap::rock_sand_border_panhandleL_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_L_Vertices, Rock_panhandle_L_IDs);
					break;
				}		
				case CMap::rock_sand_border_panhandleL_U1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_L_Vertices, Rock_panhandle_L_IDs);
					break;
				}	
				case CMap::rock_sand_border_panhandleL_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_L_Vertices, Rock_panhandle_L_IDs);
					break;
				}
				case CMap::rock_sand_border_panhandleL_D1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_L_Vertices, Rock_panhandle_L_IDs);
					break;
				}


				case CMap::rock_sand_border_panhandleR_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 90, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_R_Vertices, Rock_panhandle_R_IDs);
					break;
				}		
				case CMap::rock_sand_border_panhandleR_U1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 0, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_R_Vertices, Rock_panhandle_R_IDs);
					break;
				}	
				case CMap::rock_sand_border_panhandleR_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_R_Vertices, Rock_panhandle_R_IDs);
					break;
				}
				case CMap::rock_sand_border_panhandleR_D1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_panhandle_R_Vertices, Rock_panhandle_R_IDs);
					break;
				}

				case CMap::rock_sand_border_diagonal_R1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 180, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_diagonal_Vertices, Rock_diagonal_IDs);
					break;
				}		
				case CMap::rock_sand_border_diagonal_L1:
				{
					Matrix::SetTranslation(model, (y)-pos.y+0.5, eye_height, (x)-pos.x+0.5);
					Matrix::SetRotationDegrees(model, 0, 270, 0);
					Render::SetTransform(model, cam, proj);
					Render::RawTrianglesIndexed(stonetex_name, Rock_diagonal_Vertices, Rock_diagonal_IDs);
					break;
				}	
			}

			//if (tile == CMap::rock_sand_border_convex_RU1)
			//{		
			//	uint16 tiletype = (-384+tile); // -384 vanilla tiles
			//	float tileIDx = (tiletype % sprite_columns)*frame_xstep;
			//	float tileIDy = (uint(tiletype/sprite_columns))*frame_ystep;

			//	for (uint i = 0; i < MountainCorner_Vertices.length; ++i)
			//	map_Vertices.push_back(Vertex((pos.y/2)-(MountainCorner_Vertices[i].y/4) ,	0-(MountainCorner_Vertices[i].z/4), (pos.x/2)-(MountainCorner_Vertices[i].x/4), (MountainCorner_Vertices[i].u*tileIDx),(MountainCorner_Vertices[i].v*tileIDy)));			
			//	//map_Vertices.push_back(MountainCorner_Vertices[i]);

			//	for (uint i = 0; i < MoutainCorner_IDs.length; ++i)				
			//	map_IDs.push_back(MoutainCorner_IDs[i]);
			//}
		}			
	}
}
