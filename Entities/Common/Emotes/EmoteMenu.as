#include "EmotesCommon.as"
#include "WheelMenuCommon.as"

#define CLIENT_ONLY

const SColor EMOTE_ICON_BACK_COLOR(0xE2647160);

class EmoteIconWheelMenuEntry : IconWheelMenuEntry
{
	EmoteIconWheelMenuEntry(const string&in p_name)
	{
		super(p_name);
	}

	void render() override
	{
		GUI::DrawIcon(
			"InteractionIconsBackground.png",
			0,
			Vec2f(32,32),
			position + (offset - Vec2f(48,50)),
			scale * 2,
			EMOTE_ICON_BACK_COLOR
		);
		GUI::DrawCircle(position + (offset - Vec2f(0,2)), 23, color_white);

		GUI::DrawIcon(
			texture_name,
			frame,
			frame_size,
			position + (offset - frame_size * 0.5f) * scale * 2.0f,
			scale,
			color_white
		);
	}
};

void onInit(CRules@ rules)
{
	ConfigFile@ cfg = loadEmoteConfig();
	LoadEmotes(rules, cfg);

	WheelMenu@ menu = get_wheel_menu("emotes");
	menu.option_notice = getTranslatedString("Select emote");

	Emote@[] wheelEmotes = getWheelEmotes(rules, cfg);
	for (uint i = 0; i < wheelEmotes.size(); i++)
	{
		Emote@ emote = wheelEmotes[i];
		if (emote is null || emote.pack is null)
		{
			continue;
		}

		EmoteIconWheelMenuEntry entry(emote.token);
		entry.visible_name = getTranslatedString(emote.name);
		entry.texture_name = emote.pack.filePath;
		entry.frame = emote.index;
		entry.frame_size = Vec2f(32.0f, 32.0f);
		entry.scale = 1.0f;
		entry.offset = Vec2f(0.0f, -3.0f);
		menu.entries.push_back(@entry);
	}
}

void onTick(CRules@ rules)
{
	CBlob@ blob = getLocalPlayerBlob();

	if (blob is null)
	{
		set_active_wheel_menu(null);
		return;
	}

	WheelMenu@ menu = get_wheel_menu("emotes");
	WheelMenu@ active = get_active_wheel_menu();

	if (active is menu)
	{
		blob.set_bool("build menu open", true);
	}

	if (blob.isKeyJustPressed(key_bubbles) && active is null)
	{
		set_active_wheel_menu(@menu);
		blob.set_bool("build menu open", true);
		Sound::Play("buttonclick.ogg");
	}
	else if (blob.isKeyJustReleased(key_bubbles) && get_active_wheel_menu() is menu)
	{
		WheelMenuEntry@ selected = menu.get_selected();
		set_emote(blob, selected !is null ? selected.name : "");
		getControls().setMousePosition(getDriver().getScreenCenterPos());
		blob.set_bool("build menu open", false);
		set_active_wheel_menu(null);
	}
	else if (active is menu && !blob.isKeyPressed(key_bubbles))
	{
		getControls().setMousePosition(getDriver().getScreenCenterPos());
		blob.set_bool("build menu open", false);
		set_active_wheel_menu(null);
	}
}
