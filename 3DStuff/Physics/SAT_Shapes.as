//SAT_Shapes2D ~ Monkey_Feats
//note: if you are being sucked into your shape, your winding order is the wrong way, reverse your Vertices array.

#include "ShapeArrays.as";
#include "Vec3f.as";

class SAT_Shape
{
	CBlob@ OwnerBlob = null;
	CBlob@ OtherBlob = null;
	SAT_Shape@ otherShape;
	CMap@ Map;
	Vec2f[] Vertices;
	float Radius;
	int Type;
	Vec3f Pos, Old_Pos, interpolated_Pos;
	Vec3f Vel;
	float Angle;
	bool isStatic;
	bool Collides;
	bool Attached;
	bool Overlapping;
	Vec2f Displacement;

	float Elasticity;
	float Friction;
	float Mass;

	f32 GroundHeight;
	bool OnGround;
	int Team;

	SAT_Shape() {}

	// polygon
	SAT_Shape(CBlob@ _owner, Vec2f[] _verts, Vec3f _pos, bool _isStatic, float _radius, float _mass, bool _collides, int _team, float _angle) //, float _elas, float _fric) 
	{ 
		@Map = getMap();
		@OwnerBlob = _owner;
		Vertices.set_length(_verts.length);
		Vertices = _verts;
		Radius = _radius;
		Angle = 0; this.setAngle(_angle);	

		Overlapping = false;

		Pos =_pos; Old_Pos =_pos;
		
		isStatic = _isStatic;
		Collides = _collides;
		Type = 0;
		Team = _team;
		//Elasticity = _elas;
		//Friction = _fric;
		Mass = _mass;
	}

	// polygon
	SAT_Shape(CBlob@ _owner, Vec2f[] _verts, Vec3f _pos, bool _isStatic, float _radius, float _mass, bool _collides, int _team) //, float _elas, float _fric) 
	{ 
		@Map = getMap();
		@OwnerBlob = _owner;
		Vertices.set_length(_verts.length);
		Vertices = _verts;
		Radius = _radius;
		Angle = 0;

		Overlapping = false;

		Pos =_pos; Old_Pos =_pos;
		isStatic = _isStatic;
		Collides = _collides;
		Type = 0;
		Team = _team;
		//Elasticity = _elas;
		//Friction = _fric;
		Mass = _mass;
	}

	// circle
	SAT_Shape(CBlob@ _owner, float _radius, Vec3f _pos, bool _isStatic, float _mass, bool _collides, int _team) //, float _elas, float _fric) 
	{
		@Map = getMap();
		@OwnerBlob = _owner;
		Radius = _radius;

		Pos =_pos; Old_Pos =_pos;
		isStatic = _isStatic;
		Collides = _collides;
		Type = 1;
		Team = _team;
		//Elasticity = _elas;
		//Friction = _fric;
		Mass = _mass;
	}

	void setVelocity(const Vec3f &in _vel) { Vel = _vel; }
	void AddVelocity(Vec3f &in _vel) { Vel.opAddAssign(_vel);}
	void AddJumpForce(const float &in _force) { this.Vel.y += _force; }
	void setAngle(float _angle) 
	{ 
		float rot = Angle - _angle;
		//if (rot!=0)
		{
		 	for (int i = 0; i < Vertices.length; i++) Vertices[i].RotateBy(rot);
		 	Angle = _angle;
		}
	}

	bool GetShapeAtPosition(Vec3f rayPos)
	{ 		
		if (Collides)
		if ((rayPos.x) == (Pos.x) && (rayPos.z) == (Pos.y))
		return true;
		return false; 
	}

	bool checkCollision(Vec2f &in Velin, Vec2f &out totalMTV)
	{		
		if (this.isStatic) return false; // only physical objects should test anything 
		//Overlapping = false;
		//if (otherShape !is null) otherShape.Overlapping = false;
		SAT_Shape@ sat_shape_other;
		uint ovelapCount = 0;

		Map_SAT_Shapes@ map_shapes;
		if (!Map.get("Map_SAT_Info", @map_shapes))
		{
			return false;
		}
		u32 ThisOffset = Map.getTileOffset(Pos.xz());
		u32 mapWidth = Map.tilemapwidth;

		u32[] TileOffsets = // change this to velocity direction?
		{
			u32( ThisOffset-mapWidth), // up
			u32( ThisOffset-mapWidth+1), // up-right	
			u32( ThisOffset+1), // right
			u32( ThisOffset+mapWidth+1), // down-right
			u32( ThisOffset+mapWidth), // down
			u32( ThisOffset+mapWidth-1), // down-left
			u32( ThisOffset-1), // left
			u32( ThisOffset-mapWidth-1)  // up-left
		};		

		Vec2f MTV;

		for (uint i = 0; i < TileOffsets.length; i++)
		{						
			u32 Offset = TileOffsets[i];

			if (!Map.get("SAT_Info"+ThisOffset, @sat_shape_other) && !Map.get("SAT_Info"+Offset, @sat_shape_other))
			continue;
			if (@sat_shape_other == this || !sat_shape_other.Collides || !this.Collides)
			continue;

			@otherShape = sat_shape_other;

			if (!otherShape.Collides || !this.Collides) // for overlapping test
			{
				switch (Type)
				{
					case 0: // this is a polygon
					switch (otherShape.Type)
					{
						case 0: if (Poly_Poly(otherShape, Velin, MTV)) ovelapCount++;break;// other is polygon
						case 1: if (otherShape.PointInsidePolygon(otherShape.Pos.xz(), Vertices, Pos.xz())) ovelapCount++; break;// other is circle			
					} 
					break;

					case 1: // this is a circle
					switch (otherShape.Type)
					{
						case 0: if (PointInsidePolygon(Pos.xz(), otherShape.Vertices, otherShape.Pos.xz())) ovelapCount++; break;// other is polygon
						case 1: if (Circle_vs_Circle(otherShape, Velin, MTV)) ovelapCount++; break;// other is circle			
					}
					break;
				}
			}
			else
			{
				switch (Type)
				{
					case 0: // this is a polygon
					switch (otherShape.Type)
					{
						case 0: if(Poly_Poly(otherShape, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;} // other is polygon
						case 1: if(otherShape.Circle_Line(this, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;}// other is circle				
					} 
					break;

					case 1: // this is a circle
					switch (otherShape.Type)
					{
						case 0: if(Circle_Line(otherShape, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;}// other is polygon
						case 1: if(Circle_vs_Circle(otherShape, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;}// other is circle			
					}
					break;
				}
			}	
		}

		const int color = Team;

		CBlob@[] sorted;	
		CBlob@[] blobsInRadius;
		if (getMap().getBlobsInRadius( Pos.xz(), 16, @blobsInRadius ))
		{
			sorted.clear();
			sorted = getSorted(blobsInRadius);
			if (!sorted.empty())
			for (int i = 0; i < sorted.length; i++)
			{
				CBlob@ b = sorted[i];
				if (b !is null)
				{
					if (b.isAttached()) continue;
					if (!b.get("SAT_Info", @sat_shape_other)) continue; @otherShape = sat_shape_other;

					//{ if (Team == otherShape.Team ) continue;}

					if (@otherShape == this) continue;

					if (!otherShape.Collides || !this.Collides)
					{	
						switch (Type)
						{
							case 0: // this is a polygon
							switch (otherShape.Type)
							{
								case 0: Overlapping = Poly_Poly(otherShape, Velin, MTV);break;// other is polygon
								case 1: Overlapping = otherShape.Circle_Line(this, Velin, MTV);break;// other is circle				
							} 
							break;

							case 1: // this is a circle
							switch (otherShape.Type)
							{
								case 0: {Overlapping = (PointInsidePolygon(Pos.xz(), otherShape.Vertices, otherShape.Pos.xz())); break;}// other is polygon
								case 1: {Overlapping = Circle_vs_Circle(otherShape, Velin, MTV); break;}// other is circle			
							}
							break;
						}
					}
					else
					{
						switch (Type)
						{
							case 0: // this is a polygon
							switch (otherShape.Type)
							{
								case 0: if (Poly_Poly(otherShape, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;} // other is polygon
								case 1: if (otherShape.PointInsidePolygon(otherShape.Pos.xz(), this.Vertices, this.Pos.xz())) {totalMTV+=MTV; ovelapCount++; break;} // other is circle			
							} 
							break;
//
							case 1: // this is a circle
							switch (otherShape.Type)
							{
								case 0: if (Circle_Line(otherShape, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;} // other is polygon
								case 1: if (Circle_vs_Circle(otherShape, Velin, MTV)) {totalMTV+=MTV; ovelapCount++; break;} // other is circle			
							}
							break;
						}

						if (Overlapping)
						{
							if (!otherShape.isStatic) // && otherShape.Collides
							{
								MTV /= 2; //otherShape.Pos += (MTV/2)+Velocity;}
							}
						}
					}								
				}
			}			
		}

		return (ovelapCount > 0 || Overlapping);
	}

	CBlob@[] getSorted( CBlob@[] potentials)
	{
		CBlob@[] sorted;
		if (potentials.length > 0)
		{
			while (potentials.size() > 0)
			{
				f32 closestDist = 999999.9f;
				uint closestIndex = 999;

				for (uint i = 0; i < potentials.length; i++)
				{
					CBlob @b = potentials[i];
					Vec2f bpos = b.getPosition();
					f32 dist = (bpos - Pos.xz()).getLength();
					if (dist < closestDist)
					{
						closestDist = dist;
						closestIndex = i;
					}
				}				
				if (closestIndex >= 999)
				{
					break;
				}
				sorted.push_back(potentials[closestIndex]);
				potentials.erase(closestIndex);
			}
		}
		return sorted;
	}

	Vec2f[] getEdgeNormals(Vec2f Sign, Vec2f Pos, Vec2f[] verts)
	{
		Vec2f[] Normals; Normals.set_length(verts.length);
		for (int i = 0; i < verts.length; i++)
		{
			Vec2f p1 = Pos+verts[i];
			Vec2f p2 = Pos+verts[(i + 1) % verts.length];
			Vec2f edge = p1.opSub(p2);
			Vec2f normal = Vec2f(edge.x*Sign.x, edge.y*Sign.y);
			normal.Normalize();

			Normals[i] = normal;
		}
		return Normals;
	}

	Vec2f ProjectOntoAxis(Vec2f Pos, Vec2f[] verts, Vec2f axis)
	{
		float min = 99999999;
		float max = -99999999;
		for (int i = 0; i < verts.length; i++)
		{
			float proj = ((Pos.x + verts[i].x) * axis.x) + ((Pos.y + verts[i].y) * axis.y);		
			min = Maths::Min(min, proj); max = Maths::Max(max, proj);	
		}
		return Vec2f(min,max);
	}

	bool Poly_Poly(SAT_Shape@ poly2, Vec2f Velin, Vec2f &out MTV)
	{
		float overlap = 999999;
		Vec2f minPentratedAxis;
		Vec2f Sign = Vec2f(this.Pos.x+Velin.x > poly2.Pos.x ? 1:-1, this.Pos.z+Velin.y > poly2.Pos.z ? 1:-1);

		Vec2f[] Axes = getEdgeNormals( Sign, this.Pos.xz()+Velin ,this.Vertices);
		Vec2f[] Axes2 = getEdgeNormals(Sign, poly2.Pos.xz(), poly2.Vertices);
		//putting all into one array
		Axes.set_length(Axes.length+Axes2.length);	
		for (int i = 0; i < poly2.Vertices.length; i++)
		Axes[this.Vertices.length + i] = Axes2[i];

		for (int i = 0; i < Axes.length; i++)
		{
			Vec2f Axis = Axes[i];
			// Work out min and max 1D points for Vertices
			Vec2f minmax1 = ProjectOntoAxis( this.Pos.xz()+Velin , this.Vertices, Axis);
			Vec2f minmax2 = ProjectOntoAxis(poly2.Pos.xz() ,poly2.Vertices, Axis);
			float p1min = minmax1.x; 
			float p1max = minmax1.y;
			float p2min = minmax2.x; 
			float p2max = minmax2.y;

			if (p1min > p2max || p2min > p1max)
			return false;			
			// Calculate actual overlap along projected axis, and store the minimum
			float o = ( Maths::Min(p1max, p2max) - Maths::Max(p1min, p2min) );
			if (o < overlap)	
			{
				overlap = o;
				minPentratedAxis = Axis;
			}		
		}
		// If we got here, the objects have collided, set displacement by overlap along the vector
		MTV = minPentratedAxis.opMul(overlap);
		return MTV != Vec2f_zero;
	}

	bool Circle_vs_Circle(SAT_Shape@ poly2, Vec2f Velin, Vec2f &out MTV)
	{
		Vec2f VelPos = Pos.xz()+Velin;
		float Distance = Maths::Max(0.0001,(VelPos - poly2.Pos.xz()).Length());
		float Overlap = Distance-(Radius+poly2.Radius);
		if (Overlap >= 0) return false;

		MTV = Vec2f((VelPos.x - poly2.Pos.x)/(Distance), (VelPos.y - poly2.Pos.z)/(Distance))*Overlap;		
		return true;
	}

	float DotProd(Vec2f p1, Vec2f p2)
	{
		return (p1.x * p2.x) + (p1.y * p2.y);
	}

	Vec2f Reflect(Vec2f vector, Vec2f normal)
	{
	    return vector - normal*2 * DotProd(vector, normal);
	}

	bool Circle_Line(SAT_Shape@ poly2, Vec2f Velin, Vec2f &out MTV)
	{
		float overlap = 999999;
		Vec2f minPentratedAxis;
		
		for (int i = 0; i < poly2.Vertices.length; i++)
		{
			Vec2f p1 = poly2.Pos.xz() + poly2.Vertices[i];
			Vec2f p2 = poly2.Pos.xz() + poly2.Vertices[(i + 1) % poly2.Vertices.length];			

			float distance = getDistanceToLine(p1, p2, Pos.xz()+Velin);

			if (distance < Radius)
			{
				float o = (distance-Radius);
				if (o < overlap)	
				{
					overlap = o;
					Vec2f edge = p1-p2;
					Vec2f normal = Vec2f(edge.y, -edge.x);			
					normal.Normalize();
					minPentratedAxis = normal;
				}
			}				
		}
		MTV = minPentratedAxis.opMul(-overlap);			
		return MTV != Vec2f_zero;
	}

	bool PointInPolygon( Vec2f point, SAT_Shape@ poly )
	{
		Vec2f p1, p2;
		bool inside = false;
		Vec2f oldPoint = poly.Pos.xz() + poly.Vertices[poly.Vertices.length - 1]; 

		for (int i = 0; i < poly.Vertices.length; i++)
		{
			Vec2f newPoint = poly.Pos.xz() + poly.Vertices[i];

			if (newPoint.x > oldPoint.x)
			{ p1 = oldPoint; p2 = newPoint; }
			else 
			{ p1 = newPoint; p2 = oldPoint; }	

			Vec2f PolyEdge = p2.opSub(p1);
			Vec2f CircleEdge = point.opSub(p1);

			if ((newPoint.x < point.x) == (point.x <= oldPoint.x) && 
				(CircleEdge.y * PolyEdge.x) < (PolyEdge.y * CircleEdge.x))
			{
				inside = true;
			}	
			oldPoint = newPoint;
		} 
		return inside;
	}

	bool PointInsidePolygon( Vec2f Point, Vec2f[] polyVerts, Vec2f polyPos )
	{
	    double minX = polyPos.x+polyVerts[0].x;
	    double maxX = polyPos.x+polyVerts[0].x;
	    double minY = polyPos.y+polyVerts[0].y;
	    double maxY = polyPos.y+polyVerts[0].y;

	    for ( int i = 1 ; i < polyVerts.length ; i++ )
	    {
	        Vec2f q = polyPos+polyVerts[ i ];
	        minX = Maths::Min( q.x, minX );
	        maxX = Maths::Max( q.x, maxX );
	        minY = Maths::Min( q.y, minY );
	        maxY = Maths::Max( q.y, maxY );
	    }

	    if ( Point.x < minX || Point.x > maxX || Point.y < minY || Point.y > maxY )
	    {
	        return false;
	    }

	    bool inside = false;
	    for ( int i = 0, j = polyVerts.length - 1 ; i < polyVerts.length ; j = i++ )
	    {
	    	Vec2f pvi = polyPos + polyVerts[ i ];
	    	Vec2f pvj = polyPos + polyVerts[ j ];
	        if ( ( pvi.y > Point.y ) != ( pvj.y > Point.y ) &&
	             Point.x < ( pvj.x - pvi.x ) * ( Point.y - pvi.y ) / ( pvj.y - pvi.y ) + pvi.x )
	        {
	            inside = !inside;
	        }
	    }

	    return inside;
	}

	bool PointInsideSquare(Vec2f point, SAT_Shape@ poly)
	{
		u8 insideCount = 0;
		for (int i = 0; i < poly.Vertices.length; i++)
		{
			Vec2f polyCorner = poly.Vertices[i];

			if (Maths::Abs(point.x-poly.Pos.x) < Maths::Abs(polyCorner.x) && Maths::Abs(point.y-poly.Pos.y) < Maths::Abs(polyCorner.y))
			{ insideCount++; }
			
		} 
		if (insideCount == 4)
		return true;

		return false;
	}

	float Dot(Vec2f p1, Vec2f p2)
	{
		return (p1.x * p2.x) + (p1.y * p2.y);
	}

	void Render()
	{
		return;
		const f32 scalex = getDriver().getResolutionScaleFactor();
		const f32 zoom = getCamera().targetDistance * scalex;
		SColor col = Overlapping ? SColor(255,255,0,0) : color_white;

		if (Type == 0 || Type == 2) // poly
		{
			for (int i = 0; i < Vertices.length; i++)
			{
				Vec2f p1 = Vertices[i];
				Vec2f p2 = Vertices[(i + 1) % Vertices.length];
				GUI::DrawLine(Pos.xz()+p1, Pos.xz()+p2, col);
			}
		}
		else //circle
		{
			GUI::DrawCircle(getDriver().getScreenPosFromWorldPos(Pos.xz()), (Radius*2)*zoom, col);

			if (otherShape !is null)
			GUI::DrawLine(Pos.xz(), Pos.xz()+(Vec2f(0,Radius).RotateBy((Pos.xz()-(otherShape.Pos.xz())).Angle()-90)), col);
		}

	}
};

class Map_SAT_Shapes
{
	SAT_Shape[] shapes;	
	Map_SAT_Shapes(){}

	void PushAShape(Vec2f[] _verts, Vec2f _pos, u32 shapeNum)
	{
		SAT_Shape shape(null, _verts, Vec3f(_pos.x,0,_pos.y), true, 0.0, 0.0, true, -1);
		shapes.push_back(shape);

		getMap().set("SAT_Info"+shapeNum, @shape);
	}

	void PushAShape(Vec2f[] _verts, Vec2f _pos, u32 shapeNum, float _angle)
	{
		SAT_Shape shape(null, _verts, Vec3f(_pos.x,0,_pos.y), true, 0.0, 0.0, true, -1, _angle);
		shapes.push_back(shape);

		getMap().set("SAT_Info"+shapeNum, @shape);
	}

	void Render()
	{
		return;
		for (int i = 0; i < shapes.length; i++)
		{
			shapes[i].Render();
		}
	}
};