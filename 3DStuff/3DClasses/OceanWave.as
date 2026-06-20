#include "Vec3f.as"

const int OCEAN_WAVE_CELL_SIZE = 16;
const int OCEAN_VISUAL_BORDER_CELLS = 6;
const float OCEAN_WAVE_LENGTH = 48.0f;
const f32 OCEAN_WAVE_AMPLITUDE = 0.6f;
const f32 OCEAN_START_DEPTH = -1.2f;
const f32 OCEAN_WATER_COLLISION_OFFSET = -10.0f;
const string SHIP_WAVE_SAMPLE_OFFSET_X = "ship wave sample offset x";
const string SHIP_WAVE_SAMPLE_OFFSET_Y = "ship wave sample offset y";
const string SHIP_WAVE_SAMPLE_OFFSET_Z = "ship wave sample offset z";
const string SHIP_WAVE_SAMPLE_DEBUG = "ship wave sample debug";

int GetOceanWaterVertexIndex(Vec3f worldPos)
{
    CMap@ map = getMap();
    if (map is null)
    {
        return 0;
    }

    const f32 spacing = OCEAN_WAVE_CELL_SIZE * map.tilesize;
    const int mapWidth = Maths::Round((map.tilemapwidth + OCEAN_WAVE_CELL_SIZE) / OCEAN_WAVE_CELL_SIZE);
    const int mapHeight = Maths::Round((map.tilemapheight + OCEAN_WAVE_CELL_SIZE) / OCEAN_WAVE_CELL_SIZE);
    int row = Maths::Clamp(int(worldPos.x / spacing), 0, mapHeight);
    int col = Maths::Clamp(int(worldPos.z / spacing), 0, mapWidth);
    return row * (mapWidth + 1) + col;
}

f32 GetOceanWaveDisplacementForVertex(const int vertexIndex)
{
    const f32 time = getGameTime() / 5.0f;
    return (-OCEAN_WAVE_AMPLITUDE * Maths::Sin(Maths::Pi * 2.0f * (vertexIndex + time) / OCEAN_WAVE_LENGTH)) * 16.0f;
}

f32 GetOceanWaveDisplacementForGrid(const int row, const int col)
{
    CMap@ map = getMap();
    if (map is null)
    {
        return 0.0f;
    }

    const int mapWidth = Maths::Round((map.tilemapwidth + OCEAN_WAVE_CELL_SIZE) / OCEAN_WAVE_CELL_SIZE);
    return GetOceanWaveDisplacementForVertex(row * (mapWidth + 1) + col);
}

f32 GetOceanWaveDisplacement(Vec3f worldPos)
{
    CMap@ map = getMap();
    if (map is null)
    {
        return 0.0f;
    }

    const f32 spacing = OCEAN_WAVE_CELL_SIZE * map.tilesize;
    const int mapWidth = Maths::Round((map.tilemapwidth + OCEAN_WAVE_CELL_SIZE) / OCEAN_WAVE_CELL_SIZE);
    const int mapHeight = Maths::Round((map.tilemapheight + OCEAN_WAVE_CELL_SIZE) / OCEAN_WAVE_CELL_SIZE);
    const f32 rowF = worldPos.x / spacing;
    const f32 colF = worldPos.z / spacing;
    const int row0 = Maths::Clamp(int(Maths::Floor(rowF)), 0, mapHeight);
    const int col0 = Maths::Clamp(int(Maths::Floor(colF)), 0, mapWidth);
    const int row1 = Maths::Clamp(row0 + 1, 0, mapHeight);
    const int col1 = Maths::Clamp(col0 + 1, 0, mapWidth);
    const f32 rowT = Maths::Clamp(rowF - row0, 0.0f, 1.0f);
    const f32 colT = Maths::Clamp(colF - col0, 0.0f, 1.0f);
    const f32 h00 = GetOceanWaveDisplacementForGrid(row0, col0);
    const f32 h10 = GetOceanWaveDisplacementForGrid(row1, col0);
    const f32 h01 = GetOceanWaveDisplacementForGrid(row0, col1);
    const f32 h11 = GetOceanWaveDisplacementForGrid(row1, col1);
    const f32 h0 = h00 + (h10 - h00) * rowT;
    const f32 h1 = h01 + (h11 - h01) * rowT;
    return h0 + (h1 - h0) * colT;
}

f32 GetOceanWaterHeight(Vec3f worldPos)
{
    return (OCEAN_START_DEPTH * 16.0f) + GetOceanWaveDisplacement(worldPos) + OCEAN_WATER_COLLISION_OFFSET;
}

f32 GetOceanVisualWaterHeight(Vec3f worldPos)
{
    return GetOceanWaterHeight(worldPos) - OCEAN_WATER_COLLISION_OFFSET;
}

f32 GetOceanRestWaterHeight()
{
    return (OCEAN_START_DEPTH * 16.0f) + OCEAN_WATER_COLLISION_OFFSET;
}

Vec3f GetShipWaveSamplePosition(Vec2f worldPos)
{
    CRules@ rules = getRules();
    if (rules is null)
    {
        return V2toV3(worldPos);
    }

    return Vec3f(
        worldPos.x + rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_X),
        rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_Y),
        worldPos.y + rules.get_f32(SHIP_WAVE_SAMPLE_OFFSET_Z)
    );
}
