//Common file for getting forces from a propeller

#include "IslandsCommon.as"
#include "BlockCommon.as"

const f32 HARPOON_SPEED = 0.5f;

void HarpoonForces(CBlob@ this,
					CBlob@ hitBlob,
					 float power,
					 Vec2f &out moveVel,
					 Vec2f &out moveNorm,
					 float &out angleVel)
{
	Island@ movingIsland = getIsland(hitBlob.getShape().getVars().customData);
	if (movingIsland is null)
	{
		moveVel = Vec2f_zero;
		moveNorm = Vec2f_zero;
		angleVel = 0.0f;
		return;
	}

	Vec2f pos = this.getPosition();

	moveVel = -(hitBlob.getPosition() - this.getPosition());
	moveVel.Normalize();
	moveNorm = moveVel;
	const f32 moveSpeed = moveNorm.Normalize();

	// calculate "proper" force

	Vec2f fromCenter = pos - movingIsland.pos;
	f32 fromCenterLen = fromCenter.Normalize();			
	f32 directionMag = Maths::Abs( fromCenter * moveNorm );
	f32 dist = 35.0f;
	f32 harpoonLength = (hitBlob.getPosition() - this.getPosition()).getLength();
	f32 centerMag = (dist - Maths::Min( dist, fromCenterLen ))/dist;
	f32 stretch = Maths::Clamp((harpoonLength - harpoon_grapple_length) / harpoon_grapple_length, 0.0f, 1.0f);
	f32 velCoef = Maths::Clamp(((directionMag + centerMag) * 0.5f + stretch) * Maths::Abs(power), 0.0f, 1.5f);

	moveVel *= velCoef;

	f32 turnDirection = Vec2f(moveNorm.y, -moveNorm.x) * fromCenter;
	f32 angleCoef = (1.0f - velCoef) * (1.0f - directionMag) * turnDirection;
	angleVel = angleCoef * moveSpeed;
}
