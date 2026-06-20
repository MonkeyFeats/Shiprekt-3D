#include "BoundingBox.as"

class Root
{
    BoundingBox box;

    Branch@ BRxz;
    Branch@ BRx1z;
    Branch@ BRxz1;
    Branch@ BRx1z1;

    Root(u32 mapWidth, u32 mapHeight, u32 mapDepth)
    {
        box = BoundingBox(Vec3f(0, -16, 0), Vec3f(mapWidth, 16, mapDepth));

        Branch _BRxz(Vec3f(0, -16, 0),                      Vec3f(mapWidth/2, 16, mapDepth/2));
        Branch _BRx1z(Vec3f(mapWidth/2, -16, 0),            Vec3f(mapWidth,   16, mapDepth/2));
        Branch _BRxz1(Vec3f(0, -16, mapDepth/2),            Vec3f(mapWidth/2, 16, mapDepth));
        Branch _BRx1z1(Vec3f(mapWidth/2, -16, mapDepth/2),  Vec3f(mapWidth,   16, mapDepth));

        @BRxz = @_BRxz;
        @BRx1z = @_BRx1z;
        @BRxz1 = @_BRxz1;
        @BRx1z1 = @_BRx1z1;
    }

//   void CheckChunkVisibillty()
//   {
//       BRxz.CheckChunkVisibillty();
//       BRx1z.CheckChunkVisibillty();
//       BRxz1.CheckChunkVisibillty();
//       BRx1z1.CheckChunkVisibillty();
//   }
}

class Branch
{
    bool leaf = false;

    BoundingBox box;

    Branch@ BRxyz;
    Branch@ BRx1yz;
    Branch@ BRxyz1;
    Branch@ BRx1yz1;
    Branch@ BRxy1z;
    Branch@ BRx1y1z;
    Branch@ BRxy1z1;
    Branch@ BRx1y1z1;

    TerrainChunk@ CHxyz;
    TerrainChunk@ CHx1yz;
    TerrainChunk@ CHxyz1;
    TerrainChunk@ CHx1yz1;
    TerrainChunk@ CHxy1z;
    TerrainChunk@ CHx1y1z;
    TerrainChunk@ CHxy1z1;
    TerrainChunk@ CHx1y1z1;

    Branch(){}

    Branch(const Vec3f&in pos_start, const Vec3f&in pos_end)
    {
        box = BoundingBox(pos_start, pos_end);

        if(pos_end.x-pos_start.x <= ChunkSize*2)
        {
            // leaf, fill chunks here

            leaf = true;

            Vec3f chunk_pos_start = pos_start/Vec3f(ChunkSize, ChunkSize, ChunkSize);

            @CHxyz =     world.getChunk(chunk_pos_start.x,   chunk_pos_start.y,   chunk_pos_start.z);
            @CHx1yz =    world.getChunk(chunk_pos_start.x+1, chunk_pos_start.y,   chunk_pos_start.z);
            @CHxyz1 =    world.getChunk(chunk_pos_start.x,   chunk_pos_start.y,   chunk_pos_start.z+1);
            @CHx1yz1 =   world.getChunk(chunk_pos_start.x+1, chunk_pos_start.y,   chunk_pos_start.z+1);
            @CHxy1z =    world.getChunk(chunk_pos_start.x,   chunk_pos_start.y+1, chunk_pos_start.z);
            @CHx1y1z =   world.getChunk(chunk_pos_start.x+1, chunk_pos_start.y+1, chunk_pos_start.z);
            @CHxy1z1 =   world.getChunk(chunk_pos_start.x,   chunk_pos_start.y+1, chunk_pos_start.z+1);
            @CHx1y1z1 =  world.getChunk(chunk_pos_start.x+1, chunk_pos_start.y+1, chunk_pos_start.z+1);
        }
        else
        {
            // not leaf, we can continue

            Vec3f size = (pos_end-pos_start)/2;

            Branch _BRxyz(pos_start,                        pos_start+size           ); @BRxyz = @_BRxyz;
            Branch _BRx1yz(pos_start+size*Vec3f(1,0,0),     pos_end-size*Vec3f(0,1,1)); @BRx1yz = @_BRx1yz;
            Branch _BRxyz1(pos_start+size*Vec3f(0,0,1),     pos_end-size*Vec3f(1,1,0)); @BRxyz1 = @_BRxyz1;
            Branch _BRx1yz1(pos_start+size*Vec3f(1,0,1),    pos_end-size*Vec3f(0,1,0)); @BRx1yz1 = @_BRx1yz1;
            Branch _BRxy1z(pos_start+size*Vec3f(0,1,0),     pos_end-size*Vec3f(1,0,1)); @BRxy1z = @_BRxy1z;
            Branch _BRx1y1z(pos_start+size*Vec3f(1,1,0),    pos_end-size*Vec3f(0,0,1)); @BRx1y1z = @_BRx1y1z;
            Branch _BRxy1z1(pos_start+size*Vec3f(0,1,1),    pos_end-size*Vec3f(1,0,0)); @BRxy1z1 = @_BRxy1z1;
            Branch _BRx1y1z1(pos_start+size,                pos_end                  ); @BRx1y1z1 = @_BRx1y1z1;
        }
    }

//    void CheckChunkVisibillty()
//    {
//        if(camera.frustum.ContainsSphere( box.center-camera.frustum_pos, box.corner))//(camera.frustum.ContainsAABB(box - camera.frustum_pos))
//        {
//            if(leaf)
//            {
//                if(camera.frustum.ContainsSphere( CHxyz.box.center-camera.frustum_pos, CHxyz.box.corner)) CHxyz.visible = true;             else CHxyz.visible = false;
//                if(camera.frustum.ContainsSphere( CHx1yz.box.center-camera.frustum_pos, CHx1yz.box.corner)) CHx1yz.visible = true;          else CHx1yz.visible = false;
//                if(camera.frustum.ContainsSphere( CHxyz1.box.center-camera.frustum_pos, CHxyz1.box.corner)) CHxyz1.visible = true;          else CHxyz1.visible = false;
//                if(camera.frustum.ContainsSphere( CHx1yz1.box.center-camera.frustum_pos, CHx1yz1.box.corner)) CHx1yz1.visible = true;       else CHx1yz1.visible = false;
//                if(camera.frustum.ContainsSphere( CHxy1z.box.center-camera.frustum_pos, CHxy1z.box.corner)) CHxy1z.visible = true;          else CHxy1z.visible = false;
//                if(camera.frustum.ContainsSphere( CHx1y1z.box.center-camera.frustum_pos, CHx1y1z.box.corner)) CHx1y1z.visible = true;       else CHx1y1z.visible = false;
//                if(camera.frustum.ContainsSphere( CHxy1z1.box.center-camera.frustum_pos, CHxy1z1.box.corner)) CHxy1z1.visible = true;       else CHxy1z1.visible = false;
//                if(camera.frustum.ContainsSphere( CHx1y1z1.box.center-camera.frustum_pos, CHx1y1z1.box.corner)) CHx1y1z1.visible = true;    else CHx1y1z1.visible = false;
//            }
//            else
//            {
//                BRxyz.CheckChunkVisibillty();
//                BRx1yz.CheckChunkVisibillty();
//                BRxyz1.CheckChunkVisibillty();
//                BRx1yz1.CheckChunkVisibillty();
//                BRxy1z.CheckChunkVisibillty();
//                BRx1y1z.CheckChunkVisibillty();
//                BRxy1z1.CheckChunkVisibillty();
//                BRx1y1z1.CheckChunkVisibillty();
//            }
//        }
//    }
}