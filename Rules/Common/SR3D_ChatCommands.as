// Simple chat processing example.
// If the player sends a command, the server does what the command says.
// You can also modify the chat message before it is sent to clients by modifying text_out
// By the way, in case you couldn't tell, "mat" stands for "material(s)"
//#include "Blob3D.as";

bool onServerProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	if (player is null) return true;
	CBlob@ b = player.getBlob(); if (b is null) return true;
	//Blob3D@ blob; if (!b.get("blob",@blob)) return true;

	string[]@ tokens = text_in.split(" ");
	if (tokens.length > 0 && (tokens[0] == "!debug" || tokens[0] == "!collisiondebug" || tokens[0] == "!debugcollisions" || tokens[0] == "!colliders" || tokens[0] == "!fpscamera" || tokens[0] == "!firstpersoncamera"))
	{
		return true;
	}

	int team = b.getTeamNum();
	Vec2f pos = b.getPosition();
	{
	//	if (text_in == "!g")
	//	{
	//		
	//	}
	//	else 
		if (text_in.substr(0, 1) == "!")
		{
			// otherwise, try to spawn an actor with this name !actor
			string name = text_in.substr(1, text_in.size());
			if (server_CreateBlob(name, team, pos) is null)
			{
				client_AddToChat("blob " + text_in + " not found", SColor(255, 255, 0, 0));
			}
		}
	}

	return true;
}

bool onClientProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	if (text_in == "!debug")
	{
		return true;
	}

	return true;
}
