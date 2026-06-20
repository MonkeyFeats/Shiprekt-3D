#include "EmotesCommon.as";

void onInit(CBlob@ blob)
{
	blob.addCommandID("emote");
	blob.set_string("emote", "");
	blob.set_u32("emotetime", 0);
	EnsureEmotesLoaded();
}

void onTick(CBlob@ blob)
{
	blob.getCurrentScript().tickFrequency = 30;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("emote") && isServer())
	{
		CPlayer@ p = getNet().getActiveCommandPlayer();
		if (p is null) return;

		CBlob@ b = p.getBlob();
		if (b is null || b !is this) return;

		if (this.isInInventory())
		{
			CBlob@ inventoryblob = this.getInventoryBlob();
			if (inventoryblob !is null && inventoryblob.getName() == "crate" && inventoryblob.exists("emote"))
			{
				inventoryblob.set_string("emote", b.get_string("emote"));
				inventoryblob.Sync("emote", true);
				inventoryblob.set_u32("emotetime", b.get_u32("emotetime"));
				inventoryblob.Sync("emotetime", true);
			}
		}
	}
}
