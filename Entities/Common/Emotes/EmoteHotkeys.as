#include "EmotesCommon.as";

string[] emoteBinds;

void onInit(CBlob@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";

	CPlayer@ me = getLocalPlayer();
	if (me !is null)
	{
		emoteBinds = readEmoteBindings(me);
	}
}

void onTick(CBlob@ this)
{
	CRules@ rules = getRules();
	if (rules.hasTag("reload emotes"))
	{
		rules.Untag("reload emotes");
		onInit(this);
	}

	if (emoteBinds.length < 18)
	{
		CPlayer@ me = getLocalPlayer();
		if (me !is null)
		{
			emoteBinds = readEmoteBindings(me);
		}
	}

	if (emoteBinds.length < 18 || getHUD().hasMenus())
	{
		return;
	}

	CControls@ controls = getControls();
	if (controls is null)
	{
		return;
	}

	for (uint i = 0; i < 9; i++)
	{
		if (controls.isKeyJustPressed(KEY_NUMPAD1 + i))
		{
			set_emote(this, emoteBinds[9 + i]);
			break;
		}
	}

	if (controls.ActionKeyPressed(AK_BUILD_MODIFIER))
	{
		return;
	}

	for (uint i = 0; i < 9; i++)
	{
		if (controls.isKeyJustPressed(KEY_KEY_1 + i))
		{
			set_emote(this, emoteBinds[i]);
			break;
		}
	}
}
