const string WAKE_PROP_BLADES_CHILD = "propeller_blades";

void EmitPropellerWakeParticles3D(CBlob@ propeller, f32 power, u32 gameTime, u8 tickStep)
{
	if (!getNet().isClient() || propeller is null || tickStep == 0 || Maths::Abs(power) <= 0.05f)
	{
		return;
	}

	if ((gameTime + propeller.getNetworkID()) % tickStep != 0)
	{
		return;
	}

	Random random(gameTime * 149 + propeller.getNetworkID() * 17);
	Vec2f propNorm(0.0f, power > 0.0f ? 1.0f : -1.0f);
	propNorm.RotateBy(propeller.getAngleDegrees());

	Vec2f jitter((random.NextFloat() - 0.5f) * 8.0f, (random.NextFloat() - 0.5f) * 8.0f);
	Vec2f wakeSurfacePos = propeller.getPosition() + propNorm * -8.0f + jitter;

	Blob3D@ propeller3D;
	if (propeller.get("blob3d", @propeller3D) && propeller3D !is null)
	{
		Vec3f anchor = propeller3D.getRenderPosition();
		Blob3D@ blades = propeller3D.getChild(WAKE_PROP_BLADES_CHILD);
		if (blades !is null)
		{
			Vec3f localBladeOffset = blades.LocalTransform.Position;
			localBladeOffset.xzRotateBy(propeller3D.transform.Orientation.x);
			anchor += localBladeOffset;
		}

		wakeSurfacePos = anchor.xz() + jitter;
	}

	Vec3f wakePos(wakeSurfacePos.x, GetOceanVisualWaterHeight(Vec3f(wakeSurfacePos.x, 0.0f, wakeSurfacePos.y)) + 0.35f, wakeSurfacePos.y);
	Vec2f wakeFlow = propNorm * (-1.1f + random.NextFloat() * -0.55f);
	EmitWakeParticles3D(wakePos, Vec3f(wakeFlow.x, 0.0f, wakeFlow.y), Maths::Clamp(Maths::Abs(power) * 1.5f, 0.75f, 2.2f));
}
