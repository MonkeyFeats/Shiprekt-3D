#include "HumanCommon.as"
#include "Blob3D.as"

Random _punchr(0xfecc);
const int ANIM_FIRE_RATE = 40;

bool canAnimateShootPistol(CBlob@ blob)
{
	return !blob.hasTag("dead") && blob.get_string("current tool") == "pistol" && blob.get_u32("fire time") + ANIM_FIRE_RATE < getGameTime();
}

void onInit(CSprite@ this)
{
	LoadSprites(this);
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadSprites(this);
}

void LoadSprites(CSprite@ this)
{
	//ensureCorrectRunnerTexture(this, "human", "Player");
}

void onTick( CSprite@ this )
{
	CBlob@ blob = this.getBlob();
	Blob3D@ blob3d; if (!blob.get("blob3d", @blob3d)) { return; }

	const bool solidGround = blob.get_bool("onGround");
	const bool inWater = blob3d.shape !is null && blob3d.shape.inWater;
	Vec3f velocity;
	if (blob3d.rb !is null)
	{
		velocity = blob3d.rb.getVelocity();
	}
	const bool moving = velocity.xz().LengthSquared() > 0.01f || blob.getVelocity().LengthSquared() > 0.01f;

	if (blob.isAttached())
	{
		this.SetAnimation("default");
	}
	else if(solidGround)
	{	
		//if (this.isAnimationEnded())
			//!(this.isAnimation("punch1") || this.isAnimation("punch2") || this.isAnimation("shoot")) )
		{
			if (blob.isKeyPressed( key_action1 ) && canAnimateShootPistol( blob ))
			{
				this.SetAnimation("shoot");
			}
			else if (blob.isKeyPressed( key_action1 ) && (blob.get_string( "current tool" ) == "deconstructor"))
			{
				this.SetAnimation("reclaimloop");
				//this.animation.frame = 1;
			}
			else if (blob.isKeyPressed( key_action1 ) && (blob.get_string( "current tool" ) == "reconstructor"))
			{
				//this.animation.frame = 1;
				this.SetAnimation("repairloop");
			}
			else if (blob.isKeyPressed( key_action1 ) && (blob.get_string( "current tool" ) == "fists"))
			{
				this.SetAnimation("punch");
			}
			else if (moving) {
				this.SetAnimation("walk");
			}
			else {
				this.animation.frame = 0;
				this.SetAnimation("default");
			}
		}
	}
	else if (inWater)
	{
		//if (this.isAnimationEnded() ||
		//	!(this.isAnimation("shoot")) )
		{
			if (moving) {
				this.SetAnimation("swim");
			}
			else {
				this.SetAnimation("float");
			}
		}
	}
	else
	{
		if (moving)
		{
			this.SetAnimation("walk");
		}
		else
		{
			this.animation.frame = 0;
			this.SetAnimation("default");
		}
	}

	this.SetZ( 540.0f );
}
