#include "Vec3f.as"
#include "IslandsCommon.as"
#include "OceanWave.as"

const string PARTICLE_SYSTEM_3D_KEY = "particle_system_3d";
const string PARTICLE_3D_EVENT_CMD = "particle 3d event";

namespace Particle3DEvent
{
    const u8 WaterSplash = 0;
    const u8 Wake = 1;
    const u8 Footstep = 2;
    const u8 BulletHit = 3;
    const u8 SandImpact = 4;
}

namespace Particle3DEventFlags
{
    const u8 ShallowWater = 1;
}

namespace ParticleFace3D
{
    const u8 Camera = 0;          // Full billboard, faces the camera in 3D.
    const u8 CameraYaw = 1;       // Upright billboard, rotates around world Y only.
    const u8 Velocity = 2;        // Plane is built from travel direction and camera side.
    const u8 World = 3;           // Uses the particle rotation as a fixed world-facing quad.
    const u8 CameraVelocity = 4;  // Faces camera, then rolls so its local up follows velocity.
}

shared class Particle3D
{
    Vec3f position;
    Vec3f velocity;
    Vec3f acceleration;
    Vec3f rotation;

    f32 mass = 1.0f;
    f32 age = 0.0f;
    f32 lifetime = 30.0f;
    f32 size = 1.0f;
    f32 startSize = 1.0f;
    f32 endSize = 0.0f;
    f32 damping = 0.98f;
    f32 spin = 0.0f;
    f32 stretch = 1.0f;
    bool segmentedTrail = false;
    bool pointTrail = false;
    bool uniformTrail = false;
    bool tileTrailTexture = false;
    u8 trailSegments = 5;
    f32 trailLength = 18.0f;
    f32 trailGap = 0.28f;
    f32 trailTextureLength = 16.0f;
    u8 maxTrailPoints = 36;
    Vec3f[] trailPoints;

    SColor startColor = SColor(255, 255, 255, 255);
    SColor endColor = SColor(0, 255, 255, 255);

    string textureName = "pixel";
    u8 facingMode = ParticleFace3D::Camera;

    bool IsStatic = false;
    bool persistent = false;

    Particle3D() {}

    Particle3D(Vec3f _position, Vec3f _velocity, Vec3f _acceleration, f32 _lifetime, f32 _startSize, f32 _endSize, SColor _startColor, SColor _endColor)
    {
        position = _position;
        velocity = _velocity;
        acceleration = _acceleration;
        lifetime = Maths::Max(_lifetime, 1.0f);
        startSize = _startSize;
        endSize = _endSize;
        size = _startSize;
        startColor = _startColor;
        endColor = _endColor;
    }

    bool IsAlive()
    {
        return age < lifetime;
    }

    f32 GetLifePercent()
    {
        return Maths::Clamp01(age / lifetime);
    }

    void Update(f32 dt)
    {
        if (IsStatic)
            return;

        age += dt;
        velocity += acceleration * dt;
        velocity *= Maths::Pow(damping, dt);
        position += velocity * dt;
        rotation.z += spin * dt;
        size = Maths::Lerp(startSize, endSize, GetLifePercent());
    }

    SColor GetColor()
    {
        const f32 t = GetLifePercent();
        return SColor(
            Maths::Round(Maths::Lerp(startColor.getAlpha(), endColor.getAlpha(), t)),
            Maths::Round(Maths::Lerp(startColor.getRed(), endColor.getRed(), t)),
            Maths::Round(Maths::Lerp(startColor.getGreen(), endColor.getGreen(), t)),
            Maths::Round(Maths::Lerp(startColor.getBlue(), endColor.getBlue(), t))
        );
    }
};

shared class ParticleSystem3D
{
    Particle3D@[] particles;
    uint maxParticles = 256;

    void Clear()
    {
        particles.clear();
    }

    void Add(Particle3D@ particle)
    {
        if (particle is null)
            return;

        if (particles.length() >= maxParticles)
        {
            int removeIndex = 0;
            for (uint i = 0; i < particles.length(); i++)
            {
                if (particles[i] !is null && !particles[i].persistent)
                {
                    removeIndex = i;
                    break;
                }
            }
            particles.removeAt(removeIndex);
        }

        particles.push_back(particle);
    }

    void Update(f32 dt)
    {
        if (particles.length() == 0)
            return;

        for (int i = particles.length() - 1; i >= 0; i--)
        {
            Particle3D@ particle = particles[i];
            if (particle is null)
            {
                particles.removeAt(i);
                continue;
            }

            particle.Update(dt);
            if (!particle.IsAlive())
            {
                particles.removeAt(i);
            }
        }
    }

    void Render(Vec3f cameraPosition)
    {
        if (particles.length() == 0)
            return;

        Render::SetBackfaceCull(false);
        Render::SetAlphaBlend(true);
        Render::SetZBuffer(true, false);

        for (uint i = 0; i < particles.length(); i++)
        {
            Particle3D@ particle = particles[i];
            if (particle is null)
                continue;

            RenderParticle(particle, cameraPosition);
        }

        Render::SetAlphaBlend(false);
        Render::SetZBuffer(true, true);
        SetMirrorAwareRenderBackfaceCull(true);
    }

    Vec3f SafeNormal(Vec3f value, Vec3f fallback)
    {
        if (value.LengthSquared() < 0.0001f)
            return fallback;

        return value.Normalize();
    }

    void RollAxes(Vec3f &right, Vec3f &up, f32 degrees)
    {
        if (degrees == 0.0f)
            return;

        const f32 radians = degrees * (Maths::Pi / 180.0f);
        const f32 c = Maths::Cos(radians);
        const f32 s = Maths::Sin(radians);
        Vec3f oldRight = right;
        Vec3f oldUp = up;
        right = oldRight * c + oldUp * s;
        up = oldUp * c - oldRight * s;
    }

    void GetParticleAxes(Particle3D@ particle, Vec3f cameraPosition, Vec3f &right, Vec3f &up)
    {
        Vec3f toCamera = SafeNormal(cameraPosition - particle.position, Vec3f(0.0f, 0.0f, 1.0f));
        Vec3f worldUp(0.0f, 1.0f, 0.0f);
        switch (particle.facingMode)
        {
            case ParticleFace3D::CameraYaw:
            {
                const f32 cameraYaw = (cameraPosition.xz() - particle.position.xz()).Angle();
                right = Vec3f(1.0f, 0.0f, 0.0f);
                right.xzRotateBy(cameraYaw);
                up = worldUp;
                break;
            }
            case ParticleFace3D::Velocity:
            {
                up = SafeNormal(particle.velocity, worldUp);
                right = SafeNormal(Cross(toCamera, up), Vec3f(1.0f, 0.0f, 0.0f));
                break;
            }
            case ParticleFace3D::World:
            {
                right = Vec3f(1.0f, 0.0f, 0.0f);
                up = worldUp;
                right.xzRotateBy(particle.rotation.y);
                up.yzRotateBy(particle.rotation.x);
                break;
            }
            default:
            {
                right = SafeNormal(Cross(worldUp, toCamera), Vec3f(1.0f, 0.0f, 0.0f));
                up = SafeNormal(Cross(toCamera, right), worldUp);

                if (particle.facingMode == ParticleFace3D::CameraVelocity && particle.velocity.LengthSquared() > 0.0001f)
                {
                    Vec3f travel = particle.velocity.Normalize();
                    f32 travelRight = Dot(travel, right);
                    f32 travelUp = Dot(travel, up);
                    if (Maths::Abs(travelRight) + Maths::Abs(travelUp) > 0.001f)
                    {
                        RollAxes(right, up, -Vec2f(travelRight, travelUp).Angle() + 90.0f);
                    }
                }
            }
        }


        RollAxes(right, up, particle.rotation.z);
    }

    void RenderParticle(Particle3D@ particle, Vec3f cameraPosition)
    {
        const f32 halfSize = particle.size * 0.5f;
        if (halfSize <= 0.0f)
            return;

        if (particle.pointTrail)
        {
            RenderPointTrailParticle(particle, cameraPosition, halfSize);
            return;
        }

        if (particle.segmentedTrail)
        {
            RenderSegmentedTrailParticle(particle, cameraPosition, halfSize);
            return;
        }

        Vec3f right;
        Vec3f up;
        GetParticleAxes(particle, cameraPosition, right, up);

        right *= halfSize;
        up *= halfSize * particle.stretch;

        Vec3f topLeft = particle.position - right + up;
        Vec3f topRight = particle.position + right + up;
        Vec3f bottomRight = particle.position + right - up;
        Vec3f bottomLeft = particle.position - right - up;
        SColor color = particle.GetColor();

        Vertex[] vertices =
        {
            Vertex(bottomRight.x, bottomRight.y, bottomRight.z, 1, 1, color),
            Vertex(bottomLeft.x, bottomLeft.y, bottomLeft.z, 0, 1, color),
            Vertex(topLeft.x, topLeft.y, topLeft.z, 0, 0, color),
            Vertex(bottomRight.x, bottomRight.y, bottomRight.z, 1, 1, color),
            Vertex(topLeft.x, topLeft.y, topLeft.z, 0, 0, color),
            Vertex(topRight.x, topRight.y, topRight.z, 1, 0, color)
        };

        Render::RawTriangles(particle.textureName, vertices);
    }

    void RenderPointTrailParticle(Particle3D@ particle, Vec3f cameraPosition, f32 halfWidth)
    {
        if (particle.trailPoints.length() < 2)
            return;

        SColor baseColor = particle.GetColor();
        Vertex[] vertices;
        f32 tiledDistance = 0.0f;

        for (uint i = 0; i + 1 < particle.trailPoints.length(); i++)
        {
            Vec3f p0 = particle.trailPoints[i];
            Vec3f p1 = particle.trailPoints[i + 1];
            Vec3f travel = p1 - p0;
            const f32 segmentLength = travel.Length();
            if (segmentLength <= 0.001f)
                continue;

            travel = travel / segmentLength;
            Vec3f mid = (p0 + p1) * 0.5f;
            Vec3f toCamera = SafeNormal(cameraPosition - mid, Vec3f(0.0f, 0.0f, 1.0f));
            Vec3f right = SafeNormal(Cross(toCamera, travel), Vec3f(1.0f, 0.0f, 0.0f));
            if (right.LengthSquared() <= 0.0001f)
            {
                right = SafeNormal(Cross(Vec3f(0.0f, 1.0f, 0.0f), travel), Vec3f(1.0f, 0.0f, 0.0f));
            }

            Vec3f tangent0 = i == 0 ? travel : particle.trailPoints[i + 1] - particle.trailPoints[i - 1];
            Vec3f tangent1 = i + 2 >= particle.trailPoints.length() ? travel : particle.trailPoints[i + 2] - particle.trailPoints[i];
            tangent0 = SafeNormal(tangent0, travel);
            tangent1 = SafeNormal(tangent1, travel);
            Vec3f toCamera0 = SafeNormal(cameraPosition - p0, toCamera);
            Vec3f toCamera1 = SafeNormal(cameraPosition - p1, toCamera);
            Vec3f right0Axis = SafeNormal(Cross(toCamera0, tangent0), right);
            Vec3f right1Axis = SafeNormal(Cross(toCamera1, tangent1), right);
            if (right0Axis.LengthSquared() <= 0.0001f)
            {
                right0Axis = right;
            }
            if (right1Axis.LengthSquared() <= 0.0001f)
            {
                right1Axis = right;
            }

            const f32 t0 = particle.trailPoints.length() <= 1 ? 0.0f : f32(i) / f32(particle.trailPoints.length() - 1);
            const f32 t1 = f32(i + 1) / f32(particle.trailPoints.length() - 1);
            const f32 v0 = particle.tileTrailTexture ? tiledDistance / Maths::Max(particle.trailTextureLength, 1.0f) : t0;
            tiledDistance += segmentLength;
            const f32 v1 = particle.tileTrailTexture ? tiledDistance / Maths::Max(particle.trailTextureLength, 1.0f) : t1;
            const f32 taper0 = particle.uniformTrail ? 1.0f : Maths::Lerp(0.22f, 1.0f, t0);
            const f32 taper1 = particle.uniformTrail ? 1.0f : Maths::Lerp(0.22f, 1.0f, t1);
            const f32 alpha0Value = Maths::Clamp(f32(baseColor.getAlpha()) * (particle.uniformTrail ? 1.0f : t0), 0.0f, 255.0f);
            const f32 alpha1Value = Maths::Clamp(f32(baseColor.getAlpha()) * (particle.uniformTrail ? 1.0f : t1), 0.0f, 255.0f);
            SColor color0(u8(Maths::Round(alpha0Value)), baseColor.getRed(), baseColor.getGreen(), baseColor.getBlue());
            SColor color1(u8(Maths::Round(alpha1Value)), baseColor.getRed(), baseColor.getGreen(), baseColor.getBlue());

            Vec3f side0 = right0Axis * halfWidth * taper0;
            Vec3f side1 = right1Axis * halfWidth * taper1;
            Vec3f left0 = p0 - side0;
            Vec3f right0 = p0 + side0;
            Vec3f left1 = p1 - side1;
            Vec3f right1 = p1 + side1;

            vertices.push_back(Vertex(right1.x, right1.y, right1.z, 1, v1, color1));
            vertices.push_back(Vertex(left1.x, left1.y, left1.z, 0, v1, color1));
            vertices.push_back(Vertex(left0.x, left0.y, left0.z, 0, v0, color0));
            vertices.push_back(Vertex(right1.x, right1.y, right1.z, 1, v1, color1));
            vertices.push_back(Vertex(left0.x, left0.y, left0.z, 0, v0, color0));
            vertices.push_back(Vertex(right0.x, right0.y, right0.z, 1, v0, color0));
        }

        Render::RawTriangles(particle.textureName, vertices);
    }

    void RenderSegmentedTrailParticle(Particle3D@ particle, Vec3f cameraPosition, f32 halfWidth)
    {
        Vec3f travel = SafeNormal(particle.velocity, Vec3f(0.0f, 0.0f, 1.0f));
        Vec3f toCamera = SafeNormal(cameraPosition - particle.position, Vec3f(0.0f, 0.0f, 1.0f));
        Vec3f right = SafeNormal(Cross(toCamera, travel), Vec3f(1.0f, 0.0f, 0.0f));
        if (right.LengthSquared() <= 0.0001f)
        {
            right = SafeNormal(Cross(Vec3f(0.0f, 1.0f, 0.0f), travel), Vec3f(1.0f, 0.0f, 0.0f));
        }

        uint segments = particle.trailSegments;
        if (segments < 1)
            segments = 1;

        const f32 totalLength = Maths::Max(particle.trailLength, 1.0f);
        const f32 stepLength = totalLength / f32(segments);
        const f32 gap = Maths::Clamp(particle.trailGap, 0.0f, 0.82f);
        const f32 segmentInset = stepLength * gap * 0.5f;
        SColor baseColor = particle.GetColor();
        Vertex[] vertices;

        for (uint i = 0; i < segments; i++)
        {
            const f32 d0 = stepLength * f32(i) + segmentInset;
            const f32 d1 = stepLength * f32(i + 1) - segmentInset;
            if (d1 <= d0)
                continue;

            const f32 t0 = d0 / totalLength;
            const f32 t1 = d1 / totalLength;
            const f32 taper0 = Maths::Lerp(1.0f, 0.28f, t0);
            const f32 taper1 = Maths::Lerp(1.0f, 0.28f, t1);
            const f32 alpha0Value = Maths::Clamp(f32(baseColor.getAlpha()) * (1.0f - t0 * 0.75f), 0.0f, 255.0f);
            const f32 alpha1Value = Maths::Clamp(f32(baseColor.getAlpha()) * (1.0f - t1 * 0.75f), 0.0f, 255.0f);
            SColor color0(u8(Maths::Round(alpha0Value)), baseColor.getRed(), baseColor.getGreen(), baseColor.getBlue());
            SColor color1(u8(Maths::Round(alpha1Value)), baseColor.getRed(), baseColor.getGreen(), baseColor.getBlue());

            Vec3f p0 = particle.position + travel * d0;
            Vec3f p1 = particle.position + travel * d1;
            Vec3f side0 = right * halfWidth * taper0;
            Vec3f side1 = right * halfWidth * taper1;
            Vec3f left0 = p0 - side0;
            Vec3f right0 = p0 + side0;
            Vec3f left1 = p1 - side1;
            Vec3f right1 = p1 + side1;

            vertices.push_back(Vertex(right1.x, right1.y, right1.z, 1, t1, color1));
            vertices.push_back(Vertex(left1.x, left1.y, left1.z, 0, t1, color1));
            vertices.push_back(Vertex(left0.x, left0.y, left0.z, 0, t0, color0));
            vertices.push_back(Vertex(right1.x, right1.y, right1.z, 1, t1, color1));
            vertices.push_back(Vertex(left0.x, left0.y, left0.z, 0, t0, color0));
            vertices.push_back(Vertex(right0.x, right0.y, right0.z, 1, t0, color0));
        }

        Render::RawTriangles(particle.textureName, vertices);
    }
};

ParticleSystem3D@ GetParticleSystem3D()
{
    CRules@ rules = getRules();
    if (rules is null)
        return null;

    ParticleSystem3D@ system;
    if (rules.get(PARTICLE_SYSTEM_3D_KEY, @system) && system !is null)
        return system;

    ParticleSystem3D newSystem;
    rules.set(PARTICLE_SYSTEM_3D_KEY, @newSystem);
    rules.get(PARTICLE_SYSTEM_3D_KEY, @system);
    return system;
}

void UpdateParticleSystem3D(f32 dt)
{
    ParticleSystem3D@ system = GetParticleSystem3D();
    if (system !is null)
    {
        system.Update(dt);
    }
}

void RenderParticleSystem3D(Vec3f cameraPosition)
{
    ParticleSystem3D@ system = GetParticleSystem3D();
    if (system !is null)
    {
        system.Render(cameraPosition);
    }
}

void EmitParticle3D(Particle3D@ particle)
{
    ParticleSystem3D@ system = GetParticleSystem3D();
    if (system !is null)
    {
        system.Add(particle);
    }
}

void RegisterParticle3DNetworkCommands(CRules@ rules)
{
    if (rules !is null)
    {
        rules.addCommandID(PARTICLE_3D_EVENT_CMD);
    }
}

void EmitParticle3DEventLocal(const u8 particleType, Vec3f position, Vec3f velocity, const f32 power = 1.0f, const u8 flags = 0)
{
    if (!getNet().isClient())
        return;

    if (particleType == Particle3DEvent::WaterSplash)
    {
        EmitWaterSplashParticles3D(position, velocity, power);
    }
    else if (particleType == Particle3DEvent::Wake)
    {
        EmitWakeParticles3D(position, velocity, power);
    }
    else if (particleType == Particle3DEvent::Footstep)
    {
        EmitFootstepParticles3D(position, (flags & Particle3DEventFlags::ShallowWater) != 0);
    }
    else if (particleType == Particle3DEvent::BulletHit)
    {
        EmitBulletHitParticles3D(position, velocity);
    }
    else if (particleType == Particle3DEvent::SandImpact)
    {
        EmitSandImpactParticles3D(position, velocity, power);
    }
}

void SendParticle3DEvent(const u8 particleType, Vec3f position, Vec3f velocity, const f32 power = 1.0f, const u8 flags = 0, const u16 sourceBlobID = 0)
{
    if (!getNet().isServer())
        return;

    CRules@ rules = getRules();
    if (rules is null)
        return;

    CBitStream params;
    params.write_u8(particleType);
    params.write_u8(flags);
    params.write_u16(sourceBlobID);
    params.write_f32(position.x);
    params.write_f32(position.y);
    params.write_f32(position.z);
    params.write_f32(velocity.x);
    params.write_f32(velocity.y);
    params.write_f32(velocity.z);
    params.write_f32(power);
    rules.SendCommand(rules.getCommandID(PARTICLE_3D_EVENT_CMD), params);
}

void EmitReplicatedParticle3DEvent(CBlob@ sourceBlob, const u8 particleType, Vec3f position, Vec3f velocity, const f32 power = 1.0f, const u8 flags = 0)
{
    if (sourceBlob !is null && sourceBlob.isMyPlayer())
    {
        EmitParticle3DEventLocal(particleType, position, velocity, power, flags);
    }

    u16 sourceBlobID = 0;
    if (sourceBlob !is null)
    {
        sourceBlobID = sourceBlob.getNetworkID();
    }
    SendParticle3DEvent(particleType, position, velocity, power, flags, sourceBlobID);
}

void HandleParticle3DEventCommand(CRules@ rules, CBitStream@ params)
{
    u8 particleType;
    u8 flags;
    u16 sourceBlobID;
    f32 posX;
    f32 posY;
    f32 posZ;
    f32 velX;
    f32 velY;
    f32 velZ;
    f32 power;
    if (!params.saferead_u8(particleType)
        || !params.saferead_u8(flags)
        || !params.saferead_u16(sourceBlobID)
        || !params.saferead_f32(posX) || !params.saferead_f32(posY) || !params.saferead_f32(posZ)
        || !params.saferead_f32(velX) || !params.saferead_f32(velY) || !params.saferead_f32(velZ)
        || !params.saferead_f32(power))
    {
        return;
    }

    CBlob@ sourceBlob = null;
    if (sourceBlobID != 0)
    {
        @sourceBlob = getBlobByNetworkID(sourceBlobID);
    }
    if (sourceBlob !is null && sourceBlob.isMyPlayer())
    {
        return;
    }

    EmitParticle3DEventLocal(particleType, Vec3f(posX, posY, posZ), Vec3f(velX, velY, velZ), power, flags);
}

Vec3f GetRenderedParticlePosition(CBlob@ anchor, Vec2f pos, f32 height = 8.0f)
{
    Vec3f origin(pos.x, height, pos.y);
    if (!getNet().isClient() || anchor is null || anchor.getShape().getVars().customData <= 0)
    {
        return origin;
    }

    Island@ island = getIsland(anchor.getShape().getVars().customData);
    if (island is null)
    {
        return origin;
    }

    Vec2f worldOffset = pos - island.pos;
    origin.y = GetIslandWaveVisualY(island, worldOffset) + height;
    return origin;
}

void EmitMuzzleParticles3D(Vec3f origin, Vec3f forward, Vec2f seedPos, f32 power = 1.0f)
{
    if (!getNet().isClient())
        return;

    forward = forward.Normalize();
    origin += forward * (6.0f * power);

    Random random(getGameTime() * 997 + Maths::Round(seedPos.x * 3.0f) + Maths::Round(seedPos.y * 7.0f));

    for (int i = 0; i < 6; i++)
    {
        Vec3f dir = forward;
        dir.xzRotateBy((random.NextFloat() - 0.5f) * 18.0f);
        dir.y += (random.NextFloat() - 0.35f) * 0.20f;

        Particle3D@ flash = Particle3D(
            origin + dir * (random.NextFloat() * 2.0f),
            dir * (2.5f + random.NextFloat() * 2.5f) * power,
            Vec3f(0.0f, 0.015f, 0.0f),
            7.0f + random.NextFloat() * 4.0f,
            (6.0f + random.NextFloat() * 4.0f) * power,
            0.1f,
            SColor(255, 255, 235, 110),
            SColor(0, 255, 80, 10)
        );
        flash.damping = 0.90f;
        flash.spin = (random.NextFloat() - 0.5f) * 20.0f;
        flash.stretch = 1.8f;
        flash.facingMode = ParticleFace3D::CameraVelocity;
        EmitParticle3D(flash);
    }

    for (int i = 0; i < 10; i++)
    {
        Vec3f dir = forward;
        dir.xzRotateBy((random.NextFloat() - 0.5f) * 45.0f);
        dir.y += 0.08f + random.NextFloat() * 0.18f;

        Particle3D@ smoke = Particle3D(
            origin,
            dir * (0.75f + random.NextFloat() * 0.9f) * power,
            Vec3f(0.0f, 0.018f, 0.0f),
            18.0f + random.NextFloat() * 12.0f,
            (4.0f + random.NextFloat() * 2.0f) * power,
            (10.0f + random.NextFloat() * 7.0f) * power,
            SColor(140, 150, 145, 135),
            SColor(0, 75, 78, 86)
        );
        smoke.damping = 0.96f;
        smoke.spin = (random.NextFloat() - 0.5f) * 6.0f;
        smoke.facingMode = ParticleFace3D::Camera;
        EmitParticle3D(smoke);
    }
}

void EmitMuzzleParticles3D(Vec2f pos, float angle, f32 power = 1.0f)
{
    Vec3f forward(1.0f, 0.0f, 0.0f);
    forward.xzRotateBy(angle);
    forward.z = -forward.z;
    EmitMuzzleParticles3D(Vec3f(pos.x, 8.0f, pos.y), forward, pos, power);
}

void EmitMuzzleParticles3D(CBlob@ anchor, Vec2f pos, float angle, f32 power = 1.0f, f32 height = 8.0f)
{
    Vec3f forward(1.0f, 0.0f, 0.0f);
    forward.xzRotateBy(angle);
    forward.z = -forward.z;

    Vec3f origin = GetRenderedParticlePosition(anchor, pos, height);
    Vec3f ahead = GetRenderedParticlePosition(anchor, pos + forward.xz() * 16.0f, height);
    Vec3f renderForward = ahead - origin;
    if (renderForward.LengthSquared() <= 0.001f)
    {
        renderForward = forward;
    }

    EmitMuzzleParticles3D(origin, renderForward, pos, power);
}

void EmitBulletHitParticles3D(Vec3f hitPosition, Vec3f incomingVelocity)
{
    if (!getNet().isClient())
        return;

    Vec3f impactDir = incomingVelocity;
    if (impactDir.LengthSquared() <= 0.001f)
    {
        impactDir = Vec3f(0.0f, 0.0f, 1.0f);
    }
    impactDir = impactDir.Normalize();

    Random random(getGameTime() * 613 + Maths::Round(hitPosition.x * 5.0f) + Maths::Round(hitPosition.z * 11.0f));

    for (int i = 0; i < 10; i++)
    {
        Vec3f dir = impactDir * -(0.55f + random.NextFloat() * 0.75f);
        dir.xzRotateBy((random.NextFloat() - 0.5f) * 135.0f);
        dir.y += (random.NextFloat() - 0.15f) * 0.9f;
        if (dir.LengthSquared() <= 0.001f)
        {
            dir = Vec3f(0.0f, 1.0f, 0.0f);
        }
        dir = dir.Normalize();

        Particle3D@ spark = Particle3D(
            hitPosition + dir * (0.4f + random.NextFloat() * 1.3f),
            dir * (1.7f + random.NextFloat() * 2.8f),
            Vec3f(0.0f, -0.045f, 0.0f),
            8.0f + random.NextFloat() * 7.0f,
            2.2f + random.NextFloat() * 2.4f,
            0.0f,
            SColor(255, 255, 225, 95),
            SColor(0, 255, 75, 15)
        );
        spark.damping = 0.88f;
        spark.spin = (random.NextFloat() - 0.5f) * 24.0f;
        spark.stretch = 2.4f + random.NextFloat() * 0.9f;
        spark.facingMode = ParticleFace3D::CameraVelocity;
        EmitParticle3D(spark);
    }

    for (int i = 0; i < 5; i++)
    {
        Vec3f dir = impactDir * -(0.15f + random.NextFloat() * 0.35f);
        dir.xzRotateBy((random.NextFloat() - 0.5f) * 180.0f);
        dir.y += 0.08f + random.NextFloat() * 0.28f;

        Particle3D@ dust = Particle3D(
            hitPosition,
            dir * (0.45f + random.NextFloat() * 0.8f),
            Vec3f(0.0f, 0.008f, 0.0f),
            14.0f + random.NextFloat() * 10.0f,
            2.5f + random.NextFloat() * 1.5f,
            6.0f + random.NextFloat() * 4.0f,
            SColor(120, 120, 115, 110),
            SColor(0, 65, 65, 70)
        );
        dust.damping = 0.95f;
        dust.spin = (random.NextFloat() - 0.5f) * 8.0f;
        dust.facingMode = ParticleFace3D::Camera;
        EmitParticle3D(dust);
    }
}

void EmitSandImpactParticles3D(Vec3f hitPosition, Vec3f incomingVelocity, f32 power = 1.0f)
{
    if (!getNet().isClient())
        return;

    Vec3f impactDir = incomingVelocity.LengthSquared() > 0.001f ? incomingVelocity.Normalize() : Vec3f(0.0f, -1.0f, 0.0f);
    Random random(getGameTime() * 431 + Maths::Round(hitPosition.x * 9.0f) + Maths::Round(hitPosition.z * 5.0f));
    const int count = Maths::Max(3, Maths::Round(7 * power));
    for (int i = 0; i < count; i++)
    {
        Vec3f dir = impactDir * -(0.25f + random.NextFloat() * 0.4f);
        dir.xzRotateBy((random.NextFloat() - 0.5f) * 150.0f);
        dir.y = Maths::Abs(dir.y) + 0.12f + random.NextFloat() * 0.35f;
        dir = dir.Normalize();

        Particle3D@ sand = Particle3D(
            hitPosition + Vec3f(0.0f, 0.3f, 0.0f),
            dir * (0.65f + random.NextFloat() * 1.2f) * power,
            Vec3f(0.0f, -0.035f, 0.0f),
            13.0f + random.NextFloat() * 9.0f,
            2.0f + random.NextFloat() * 1.7f,
            5.0f + random.NextFloat() * 3.0f,
            SColor(135, 210, 188, 126),
            SColor(0, 170, 145, 95)
        );
        sand.damping = 0.92f;
        sand.spin = (random.NextFloat() - 0.5f) * 8.0f;
        sand.facingMode = ParticleFace3D::Camera;
        EmitParticle3D(sand);
    }
}

void EmitWaterSplashParticles3D(Vec3f hitPosition, Vec3f incomingVelocity, f32 power = 1.0f)
{
    if (!getNet().isClient())
        return;

    const f32 visualWaterY = GetOceanVisualWaterHeight(hitPosition);
    if (hitPosition.y < visualWaterY)
    {
        hitPosition.y = visualWaterY + 0.2f;
    }

    Random random(getGameTime() * 719 + Maths::Round(hitPosition.x * 2.0f) + Maths::Round(hitPosition.z * 13.0f));
    const int drops = Maths::Max(4, Maths::Round(8 * power));
    for (int i = 0; i < drops; i++)
    {
        Vec3f dir(random.NextFloat() - 0.5f, 0.45f + random.NextFloat() * 0.7f, random.NextFloat() - 0.5f);
        dir = dir.Normalize();
        Particle3D@ drop = Particle3D(
            hitPosition,
            dir * (0.8f + random.NextFloat() * 1.9f) * power,
            Vec3f(0.0f, -0.055f, 0.0f),
            10.0f + random.NextFloat() * 8.0f,
            1.8f + random.NextFloat() * 1.4f,
            0.0f,
            SColor(175, 170, 225, 255),
            SColor(0, 110, 170, 220)
        );
        drop.damping = 0.91f;
        drop.stretch = 1.7f;
        drop.facingMode = ParticleFace3D::CameraVelocity;
        EmitParticle3D(drop);
    }

    Particle3D@ ring = Particle3D(
        hitPosition + Vec3f(0.0f, 0.04f, 0.0f),
        Vec3f(),
        Vec3f(),
        18.0f,
        5.0f * power,
        18.0f * power,
        SColor(115, 145, 210, 255),
        SColor(0, 105, 175, 225)
    );
    ring.facingMode = ParticleFace3D::World;
    ring.stretch = 0.08f;
    ring.damping = 1.0f;
    EmitParticle3D(ring);
}

void EmitWakeParticles3D(Vec3f origin, Vec3f flow, f32 power = 1.0f)
{
    if (!getNet().isClient())
        return;

    const f32 visualWaterY = GetOceanVisualWaterHeight(origin);
    if (origin.y < visualWaterY + 0.15f)
    {
        origin.y = visualWaterY + 0.15f;
    }

    Random random(getGameTime() * 337 + Maths::Round(origin.x) + Maths::Round(origin.z * 3.0f));
    Vec3f wakeVel = flow.LengthSquared() > 0.001f ? flow.Normalize() : Vec3f(0.0f, 0.0f, 1.0f);
    Particle3D@ foam = Particle3D(
        origin + Vec3f((random.NextFloat() - 0.5f) * 2.5f, 0.25f, (random.NextFloat() - 0.5f) * 2.5f),
        wakeVel * (0.45f + random.NextFloat() * 0.65f) * power,
        Vec3f(),
        22.0f + random.NextFloat() * 10.0f,
        7.0f + random.NextFloat() * 4.0f,
        22.0f + random.NextFloat() * 10.0f,
        SColor(175, 220, 240, 255),
        SColor(0, 130, 175, 210)
    );
    foam.facingMode = ParticleFace3D::CameraVelocity;
    foam.stretch = 0.36f;
    foam.damping = 0.96f;
    EmitParticle3D(foam);
}

void EmitFootstepParticles3D(Vec3f origin, bool shallowWater)
{
    if (!getNet().isClient())
        return;

    if (shallowWater)
    {
        EmitWaterSplashParticles3D(origin, Vec3f(0.0f, -0.5f, 0.0f), 0.45f);
        return;
    }

    EmitSandImpactParticles3D(origin, Vec3f(0.0f, -0.5f, 0.0f), 0.42f);
}

void EmitFireplaceSmokeParticles3D(Vec3f origin, f32 power = 1.0f)
{
    if (!getNet().isClient())
        return;

    Random random(getGameTime() * 173 + Maths::Round(origin.x * 4.0f) + Maths::Round(origin.z * 7.0f));
    Particle3D@ smoke = Particle3D(
        origin + Vec3f((random.NextFloat() - 0.5f) * 2.0f, 0.0f, (random.NextFloat() - 0.5f) * 2.0f),
        Vec3f((random.NextFloat() - 0.5f) * 0.12f, 0.22f + random.NextFloat() * 0.15f, (random.NextFloat() - 0.5f) * 0.12f) * power,
        Vec3f(0.0f, 0.006f, 0.0f),
        65.0f + random.NextFloat() * 35.0f,
        5.0f + random.NextFloat() * 3.0f,
        20.0f + random.NextFloat() * 9.0f,
        SColor(95, 115, 105, 100),
        SColor(0, 55, 58, 65)
    );
    smoke.damping = 0.985f;
    smoke.spin = (random.NextFloat() - 0.5f) * 2.0f;
    smoke.facingMode = ParticleFace3D::Camera;
    EmitParticle3D(smoke);
}

void EmitTreasureRayParticles3D(Vec3f origin, f32 power = 1.0f)
{
    if (!getNet().isClient())
        return;

    Random random(getGameTime() * 251 + Maths::Round(origin.x * 6.0f) + Maths::Round(origin.z * 2.0f));
    Particle3D@ ray = Particle3D(
        origin + Vec3f((random.NextFloat() - 0.5f) * 6.0f, 10.0f + random.NextFloat() * 8.0f, (random.NextFloat() - 0.5f) * 6.0f),
        Vec3f(0.0f, 0.035f + random.NextFloat() * 0.025f, 0.0f),
        Vec3f(),
        70.0f + random.NextFloat() * 30.0f,
        5.0f * power,
        7.0f * power,
        SColor(42, 255, 238, 150),
        SColor(0, 255, 230, 120)
    );
    ray.facingMode = ParticleFace3D::CameraYaw;
    ray.stretch = 8.0f + random.NextFloat() * 5.0f;
    ray.damping = 1.0f;
    EmitParticle3D(ray);
}
