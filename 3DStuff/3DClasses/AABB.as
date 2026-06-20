
class AABB
{
	Vec3f min;
	Vec3f max;
	Vec3f center;
	Vec3f dim;
	f32 corner; // radius of a sphere, that is outside the box and collides with each corner

	SMesh@ BoxMesh = SMesh();
	SMaterial@ BoxMat = SMaterial();
	
	AABB()
	{
		min = Vec3f(0, 0, 0);
		max = Vec3f(0, 0, 0);
		center = Vec3f(0, 0, 0);
		dim = Vec3f(0, 0, 0);
		
	}
	
	AABB(const Vec3f&in _min, const Vec3f&in _max)
	{
		min = _min;
		max = _max;
		UpdateAttributes();
	}
	
	AABB(const Vec3f&in middle, float range)
	{
		min = middle-range;
		max = middle+range;
		UpdateAttributes();
	}

	AABB opAdd(const Vec3f&in other) { return AABB(min + other, max + other); }
	AABB opSub(const Vec3f&in other) { return AABB(min - other, max - other); }

	void setSize(float range)
	{		
		min = center-range;
		max = center+range;
		UpdateAttributes();
	}

	bool isPointInside(const Vec3f&in p) const
    {
        return (p.x >= min.x && p.x <= max.x &&
            	p.y >= min.y && p.y <= max.y &&
            	p.z >= min.z && p.z <= max.z);
    }

    bool isPointTotalInside(const Vec3f&in p) const
    {
        return (p.x > min.x && p.x < max.x &&
            	p.y > min.y && p.y < max.y &&
            	p.z > min.z && p.z < max.z);
    }
	
	void UpdateAttributes()
	{

		dim.x = Maths::Abs(max.x - min.x);
		dim.y = Maths::Abs(max.y - min.y);
		dim.z = Maths::Abs(max.z - min.z);
		center = dim / 2.0f + min;
		corner = Maths::Pow( Maths::Pow(dim.x, 3) + Maths::Pow(dim.y, 3) + Maths::Pow(dim.z, 3), 1.0f / 3.0f) * 0.6f;

		const Vertex[] _Verts = {
		Vertex( max.x, min.y, min.z,  0, 0, SColor(20, 0, 255, 0)),
		Vertex( max.x, min.y, max.z,  1, 0,	SColor(20, 0, 255, 0)),
		Vertex( min.x, min.y, max.z,  1, 1,	SColor(20, 0, 255, 0)),
		Vertex( min.x, min.y, min.z,  0, 1, SColor(20, 0, 255, 0)),
		Vertex( max.x, max.y, min.z,  0, 1, SColor(20, 0, 255, 0)),
		Vertex( max.x, max.y, max.z,  0, 0,	SColor(20, 0, 255, 0)),
		Vertex( min.x, max.y, max.z,  1, 0,	SColor(20, 0, 255, 0)),
		Vertex( min.x, max.y, min.z,  1, 1, SColor(20, 0, 255, 0))
		};

		const u16[] _IDs= {0,1,3,1,2,3,
					       4,7,5,7,6,5,
					       0,4,1,4,5,1,
					       1,5,2,5,6,2,
					       2,6,3,6,7,3,
					       4,0,7,0,3,7};

		BoxMesh.SetVertex(_Verts);
	    BoxMesh.SetIndices(_IDs); 
	   	BoxMesh.BuildMesh();
	    BoxMesh.SetDirty(SMesh::VERTEX_INDEX);

	    BoxMat.DisableAllFlags();
	    BoxMat.SetFlag(SMaterial::COLOR_MASK, true);
	    BoxMat.SetFlag(SMaterial::ZBUFFER, true);
	    BoxMat.SetFlag(SMaterial::ZWRITE_ENABLE, false);
	    BoxMat.SetFlag(SMaterial::BACK_FACE_CULLING, false);
	    BoxMat.SetMaterialType(SMaterial::TRANSPARENT_VERTEX_ALPHA );
	    BoxMat.SetFlag(SMaterial::WIREFRAME, true);
	    //BoxMat.SetFlag(SMaterial::LIGHTING, true);
	    //BoxMat.SetEmissiveColor(SColor(255,255,0,180));
	    BoxMesh.SetMaterial(BoxMat);		
	}

    void Render()
    { 
    	//BoxMesh.RenderMeshWithMaterial();	
    }
}

bool testAABBAABB(const AABB&in a, const AABB&in b)
{
    if ( a.min.x > b.max.x || a.max.x < b.min.x ) {return false;}
    if ( a.min.y > b.max.y || a.max.y < b.min.y ) {return false;}
    if ( a.min.z > b.max.z || a.max.z < b.min.z ) {return false;}
 
    // We have an overlap
    return true;
};
