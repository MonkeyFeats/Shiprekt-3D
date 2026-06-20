namespace Block
{
	const int size = 16;

	enum Type 
	{
		PLATFORM = 0,
		PLATFORM2 = 1,
		SEAT = 2,
		SOLID = 3,
		COUPLING = 4,		
		RAM = 5,	
		DOOR = 6,
		REPULSOR = 7,
		PROPELLER = 8,
		RAMENGINE = 9,
		BOMB = 10,
		POINTDEFENSE = 11,
		HARVESTER = 12,
		HARPOON = 13,
		FLAK = 14,
		MACHINEGUN = 15,
		CANNON = 16,
		LAUNCHER = 17,

		PROPBLADES1 = 18,
		PROPBLADES2 = 19,

		STATION = 22,
		SHIPCORE = 23
	};
					
	shared class Weights
	{
		f32 mothership;
		f32 wood;
		f32 ram;
		f32 solid;
		f32 door;
		f32 propeller;
		f32 ramEngine;
		f32 seat;
		f32 cannon;
		f32 station;
		f32 harvester;
		f32 harpoon;
		f32 machinegun;
		f32 flak;
		f32 pointDefense;
		f32 launcher;
		f32 bomb;
		f32 coupling;
		f32 repulsor;
	}
	
	Weights@ queryWeights( CRules@ this )
	{
		ConfigFile cfg;
		if ( !cfg.loadFile( "SHRKTVars.cfg" ) ) 
			return null;
		
		print( "** Getting Weights from cfg" );
		Block::Weights w;

		w.mothership = cfg.read_f32( "w_mothership" );
		w.wood = cfg.read_f32( "w_wood" );
		w.ram = cfg.read_f32( "w_ram" );
		w.solid = cfg.read_f32( "w_solid" );
		w.door = cfg.read_f32( "w_door" );
		w.propeller = cfg.read_f32( "w_propeller" );
		w.ramEngine = cfg.read_f32( "w_ramEngine" );
		w.seat = cfg.read_f32( "w_seat" );
		w.cannon = cfg.read_f32( "w_cannon" );
		w.harvester = cfg.read_f32( "w_harvester" );
		w.harpoon = cfg.read_f32( "w_harpoon" );
		w.machinegun = cfg.read_f32( "w_machinegun" );
		w.flak = cfg.read_f32( "w_flak" );
		w.pointDefense = cfg.read_f32( "w_pointDefense" );
		w.launcher = cfg.read_f32( "w_launcher" );
		w.bomb = cfg.read_f32( "w_bomb" );
		w.coupling = cfg.read_f32( "w_coupling" );
		w.repulsor = cfg.read_f32( "w_repulsor" );

		this.set( "weights", w );
		return @w;
	}
	
	Weights@ getWeights( CRules@ this )
	{
		Block::Weights@ w;
		this.get( "weights", @w );
		
		if ( w is null )
			@w = Block::queryWeights( this );

		return w;
	}
	
	shared class Costs
	{
		u16 station;
		u16 wood;
		u16 ram;
		u16 solid;
		u16 door;
		u16 propeller;
		u16 ramEngine;
		u16 seat;
		u16 cannon;
		u16 harvester;
		u16 harpoon;
		u16 machinegun;
		u16 flak;
		u16 pointDefense;
		u16 launcher;
		u16 bomb;
		u16 coupling;
		u16 repulsor;
	}
	
	Costs@ queryCosts( CRules@ this )
	{
		ConfigFile cfg;
		if ( !cfg.loadFile( "SHRKTVars.cfg" ) ) 
			return null;
		
		print( "** Getting Costs from cfg" );
		Block::Costs c;
		
		c.station = 100;
		c.wood = cfg.read_u16( "cost_wood" );
		c.ram = cfg.read_u16( "cost_ram" );
		c.solid = cfg.read_u16( "cost_solid" );
		c.door = cfg.read_u16( "cost_door" );
		c.propeller = cfg.read_u16( "cost_propeller" );
		c.ramEngine = cfg.read_u16( "cost_ramEngine" );
		c.seat = cfg.read_u16( "cost_seat" );
		c.cannon = cfg.read_u16( "cost_cannon" );
		c.harvester = cfg.read_u16( "cost_harvester" );
		c.harpoon = cfg.read_u16( "cost_harpoon" );
		c.machinegun = cfg.read_u16( "cost_machinegun" );
		c.flak = cfg.read_u16( "cost_flak" );
		c.pointDefense = cfg.read_u16( "cost_pointDefense" );
		c.launcher = cfg.read_u16( "cost_launcher" );
		c.bomb = cfg.read_u16( "cost_bomb" );
		c.coupling = cfg.read_u16( "cost_coupling" );
		c.repulsor = cfg.read_u16( "cost_repulsor" );

		this.set( "costs", c );
		return @c;
	}
	
	Costs@ getCosts( CRules@ this )
	{
		Block::Costs@ c;
		this.get( "costs", @c );
		
		if ( c is null )
			@c = Block::queryCosts( this );
			
		return c;
	}
	
	bool isSolid( const uint blockType )
	{
		return (blockType == Block::SOLID || blockType == Block::PROPELLER || blockType == Block::RAMENGINE || blockType == Block::RAM || blockType == Block::POINTDEFENSE);
	}

	bool isPlatform( const uint blockType )
	{
		return (blockType == Block::PLATFORM || blockType == Block::PLATFORM2);
	}

	bool isSolidCollisionBlock( const uint blockType )
	{
		return (Block::isSolid(blockType) || blockType == Block::SHIPCORE || blockType == Block::STATION || blockType == Block::DOOR);
	}

	bool destroysPlatformOnCollision( const uint blockType )
	{
		return (blockType == Block::SOLID || blockType == Block::RAM || blockType == Block::RAMENGINE || blockType == Block::SHIPCORE);
	}

	bool isRigidHullBlock( const uint blockType )
	{
		return (Block::isSolid(blockType) || blockType == Block::SHIPCORE);
	}

	bool isCore( const uint blockType )
	{
		return (blockType == Block::SHIPCORE);
	}

	bool isDoor( const uint blockType )
	{ 
		return (blockType == Block::DOOR);
	}

	bool isBomb( const uint blockType )
	{
		return (blockType >= 19 && blockType <= 21);
	}
	
	bool isRepulsor( const uint blockType )
	{
		return (blockType >= 28 && blockType <= 30);
	}

	bool isType( CBlob@ blob, const uint blockType )
	{
		return (blob.getSprite().getFrame() == blockType);
	}

	uint getType( CBlob@ blob )
	{
		return blob.getSprite().getFrame();
	}

	f32 getWeight ( const uint blockType )
	{
		CRules@ rules = getRules();
		
		Weights@ w = Block::getWeights( rules );

		if ( w is null )
		{
			warn( "** Couldn't get Weights!" );
			return 0;
		}
		
		switch(blockType)		
		{
			case Block::PROPELLER:
				return w.propeller;
			break;
			case Block::RAMENGINE:
				return w.ramEngine;
			break;
			case Block::SOLID:
				return w.solid;
			break;
			case Block::DOOR:
				return w.door;
			break;
			case Block::RAM:
				return w.ram;
			break;
			case Block::PLATFORM:
				return w.wood;
			break;
			case Block::CANNON:
				return w.cannon;
			break;
			case Block::HARVESTER:
				return w.harvester;
			break;
			case Block::HARPOON:
				return w.harpoon;
			break;
			case Block::MACHINEGUN:
				return w.machinegun;
			break;
			case Block::FLAK:
				return w.flak;
			break;
			case Block::POINTDEFENSE:
				return w.pointDefense;
			break;
			case Block::LAUNCHER:
				return w.launcher;
			break;
			case Block::SEAT:
				return w.seat;
			break;
			case Block::COUPLING:
				return w.coupling;
			break;
			case Block::REPULSOR:
				return w.repulsor;
			break;
			case Block::BOMB:
				return w.bomb;
			break;			
		}
	
		return blockType == SHIPCORE ? w.mothership : w.wood;
	}

	f32 getWeight ( CBlob@ blob )
	{
		return getWeight( getType(blob) );
	}
	
	u16 getCost ( const uint blockType )
	{
		CRules@ rules = getRules();
		
		Costs@ c = Block::getCosts( rules );

		if ( c is null )
		{
			warn( "** Couldn't get Costs!" );
			return 0;
		}
		
		switch(blockType)		
		{
			case Block::STATION:
				return c.station;
			break;
			case Block::PROPELLER:
				return c.propeller;
			break;
			case Block::RAMENGINE:
				return c.ramEngine;
			break;
			case Block::SOLID:
				return c.solid;
			break;
			case Block::DOOR:
				return c.door;
			break;
			case Block::RAM:
				return c.ram;
			break;
			case Block::PLATFORM:
				return c.wood;
			break;
			case Block::CANNON:
				return c.cannon;
			break;
			case Block::HARVESTER:
				return c.harvester;
			break;
			case Block::HARPOON:
				return c.harpoon;
			break;
			case Block::MACHINEGUN:
				return c.machinegun;
			break;
			case Block::FLAK:
				return c.flak;
			break;
			case Block::POINTDEFENSE:
				return c.pointDefense;
			break;
			case Block::LAUNCHER:
				return c.launcher;
			break;
			case Block::SEAT:
				return c.seat;
			break;
			case Block::COUPLING:
				return c.coupling;
			break;	
			case Block::REPULSOR:
				return c.repulsor;
			break;
			case Block::BOMB:
				return c.bomb;
			break;			
		}
	
		return 0;
	}

	const f32 BUTTON_RADIUS_FLOOR = 12;
	const f32 BUTTON_RADIUS_SOLID = 20;

};
