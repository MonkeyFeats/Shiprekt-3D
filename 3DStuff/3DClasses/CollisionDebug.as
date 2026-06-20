const string COLLISION_DEBUG_ENABLED = "collision debug enabled";

bool IsCollisionDebugEnabled()
{
	return IsCollisionDebugEnabled(getRules());
}

bool IsCollisionDebugEnabled(CRules@ rules)
{
	return rules !is null && rules.get_bool(COLLISION_DEBUG_ENABLED);
}
