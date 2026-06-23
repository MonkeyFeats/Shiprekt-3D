
// set camera on local player
// this just sets the target, specific camera vars are usually set in StandardControls.as

#define CLIENT_ONLY

#include "Camera3D.as"
#include "Spectator.as"

int deathTime = 0;
Vec3f deathLock;
int helptime = 0;
bool spectatorTeam;
Vec2f ArbitraryMouseOffset = Vec2f(2.5f, 2.5f);
const f32 FIRST_PERSON_EYE_HEIGHT = 16.0f;
const f32 THIRD_PERSON_SEAT_OFFSET_X = 0.0f;
const f32 THIRD_PERSON_SEAT_OFFSET_Y = 20.0f;
const f32 THIRD_PERSON_SEAT_OFFSET_Z = -40.0f;

void onInit(CRules@ this)
{	
	Reset(this);
	getCamera().targetDistance = 0.5f;
	EnsureCamera3D(getLocalPlayer());
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void Reset(CRules@ this)
{
	//SetTargetPlayer(null);
	//CCamera@ camera = getCamera();
//
	//if (camera !is null)
	//{
	//	camera.setTarget(null);
	//}

	helptime = 0;
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	EnsureCamera3D(player);
}

Camera3D@ EnsureCamera3D(CPlayer@ player)
{
	if (player is null)
	{
		return null;
	}

	Camera3D@ camera;
	if (player.get("Camera3D", @camera) && camera !is null)
	{
		return @camera;
	}

	Camera3D newCamera();
	if (newCamera !is null)
	{
		player.set("Camera3D", @newCamera);
	}

	return @newCamera;
}

void onSetPlayer(CRules@ this, CBlob@ blob, CPlayer@ player)
{	
	//if (player !is null && player is getLocalPlayer())
	//{
	//	Blob3D@ blob3D; getLocalPlayerBlob().get("blob3d", @blob3D);
	//	Camera3D@ camera; player.get("Camera3D", @camera);
	//	if (camera !is null && blob3D !is null)
	//	{
	//		print("target set");
	//		//camera.setPosition(blob3D.getPosition()+camera.pos_offset);
	//		camera.setTarget(@blob3D);
	//		//camera.mousecamstyle = 1; // follow
	//	}
	//}
}

void onTick(CRules@ this)
{
	CPlayer@ player = getLocalPlayer();
	if(player !is null)
	{
		Camera3D@ camera = EnsureCamera3D(player);
		if (camera !is null)
		{
			if (getLocalPlayerBlob() !is null)
			{
				FollowTarget(this, getLocalPlayerBlob());
			}
			else
			{
				const int diffTime = deathTime - getGameTime();				
				if (!spectatorTeam && diffTime > 0) // death effect
				{
					////lock camera
					camera.setPosition(deathLock);
					////zoom in for a bit
					//const float zoom_target = 2.0f;
					//const float zoom_speed = 5.0f;
					//camera.targetDistance = Maths::Min(zoom_target, camera.targetDistance + zoom_speed * getRenderDeltaTime());
				}
				else
				{
					Spectator(this);
				}
			}
		}				
	}


	//CPlayer@ player = getLocalPlayer();
	//if(player !is null)
	//{
	//	Camera3D@ camera; player.get("Camera3D", @camera);
	//	if (camera !is null)
	//	{	
	//		camera.onTick();
	//	}
	//}
}

//change to spectator cam on team change
void onPlayerChangedTeam(CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam)
{
	CBlob@ playerBlob = player is null ? null : player.getBlob();
	if (newteam == this.getSpectatorTeamNum() && getLocalPlayer() is player)
	{
		if (playerBlob !is null)
		{
			//Blob3D@ playerBlob3D; playerBlob.get("blob3d", @playerBlob3D);
			Camera3D@ camera; player.get("Camera3D", @camera);
			if (camera !is null && playerBlob !is null)
			{	
				spectatorTeam = true;
				camera.setTarget(null);
				if (playerBlob !is null)
				{
					playerBlob.ClearButtons();
					playerBlob.ClearMenus();
		
					//camera.setPosition(playerBlob3D.getPosition());
					deathTime = getGameTime();		
				}
			}
		}
	}
	else if (getLocalPlayer() is player)
	{
		spectatorTeam = false;

		//CBlob@ playerBlob = player.getBlob();
		//if (playerBlob !is null)
		//{
		//	Blob3D@ playerBlob3D; 
		//	if (playerBlob.get("blob3d", @playerBlob3D))
		//	{
		//		Camera3D@ camera; 
		//		if (player.get("Camera3D", @camera))
		//		{
		//			camera.setPosition(playerBlob3D.getPosition());
		//		}
		//	}
		//}
	}

}

//Change to spectator cam on death
void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	Camera3D@ camera; victim.get("Camera3D", @camera);
	CBlob@ victimBlob = victim !is null ? victim.getBlob() : null;
	CBlob@ attackerBlob = attacker !is null ? attacker.getBlob() : null;

	Blob3D@ victimBlob3D; victimBlob.get("blob3d", @victimBlob3D);
	if (victimBlob3D is null) return;
	
	//Player died to someone
	if (camera !is null && victim is getLocalPlayer())
	{
		//Player killed themselves
		if (victim is attacker || attacker is null)
		{
			camera.setTarget(null);
			if (victimBlob !is null)
			{
				victimBlob.ClearButtons();
				victimBlob.ClearMenus();

				deathLock = victimBlob3D.getPosition();
				SetTargetPlayer(null);

			}
			deathTime = getGameTime() + 2 * getTicksASecond();

		}
		else
		{
			if (victimBlob !is null)
			{
				victimBlob.ClearButtons();
				victimBlob.ClearMenus();
			}

			if (attackerBlob !is null)
			{
				Blob3D@ attackerBlob3D; attackerBlob.get("blob3d", @attackerBlob3D);
				if (attackerBlob3D !is null)
				{
					SetTargetPlayer(attackerBlob3D.getPlayer());
					deathLock = victimBlob3D.getPosition();
				}
			}
			else
			{
				camera.setTarget(null);
			}
			deathTime = getGameTime() + 2 * getTicksASecond();
		}
	}
}

void onRender(CRules@ this)
{
		
	if (getLocalPlayerBlob() !is null)
    {
		GUI::SetFont("menu");

		Blob3D@ blob3d;
		if (getLocalPlayerBlob().get("blob3d", @blob3d))  
		{		    
	    	//debug stuff
			Vec3f pos = blob3d.getPosition();
			GUI::DrawText("Pos = "+pos.toString(), Vec2f(0, 16), color_white);

			if (blob3d.rb !is null)
			{
				Vec3f vel = blob3d.rb.getVelocity();
				GUI::DrawText("Vel = "+vel.toString(), Vec2f(0, 32), color_white);
			}
	    }	

		if (targetPlayer() !is null)
		{
			GUI::DrawText(
				getTranslatedString("Following {CHARACTERNAME} ({USERNAME})")
				.replace("{CHARACTERNAME}", targetPlayer().getCharacterName())
				.replace("{USERNAME}", targetPlayer().getUsername()),
				Vec2f(getScreenWidth() / 2 - 90, getScreenHeight() * (0.2f)),
				Vec2f(getScreenWidth() / 2 + 90, getScreenHeight() * (0.2f) + 30),
				SColor(0xffffffff), true, true
			);
		}
	}

	int time = getGameTime();
	if (!spectatorTeam || !u_showtutorial)
	{
		//reset help so it shows upon joining spec
		//or re-enabling help
		helptime = time;
		return;
	}

	GUI::SetFont("menu");

	const int endTime1 = helptime + (getTicksASecond() * 12);
	const int endTime2 = helptime + (getTicksASecond() * 24);

	string text = "";

	if (time < endTime1)
	{
		text = "You can use the movement keys.";
	}
	else if (time < endTime2)
	{
		text = "If you click on a player the camera will follow them.\nSimply press the movement keys or click again to stop following a player.";
	}

	if (text != "")
	{
		//translate
		text = getTranslatedString(text);
		//position post translation so centering works properly
		Vec2f ul, lr;
		ul = Vec2f(getScreenWidth() / 2.0, 3.0 * getScreenHeight() / 4);
		Vec2f size;
		GUI::GetTextDimensions(text, size);
		ul -= size * 0.5;
		lr = ul + size;
		//wiggle up and down
		f32 wave = Maths::Sin(getGameTime() / 10.0f) * 5.0f;
		ul.y += wave;
		lr.y += wave;
		//draw
		GUI::DrawButtonPressed(ul - Vec2f(10, 10), lr + Vec2f(10, 10));
		GUI::DrawText(text, ul, SColor(0xffffffff));
	}	
}

f32 zoomTarget = 1.0f;
float timeToScroll = 0.0f;

bool justClicked = false;
string _targetPlayer;
bool waitForRelease = false;

CPlayer@ targetPlayer()
{
	return getPlayerByUsername(_targetPlayer);
}

void SetTargetPlayer(CPlayer@ p)
{
	_targetPlayer = "";
	if(p is null) return;
	_targetPlayer = p.getUsername();
}

void Spectator(CRules@ this)
{
	if (this.isGameOver() && this.hasScript("PostGameMapVotes"))
	{
		return; //prevent camera movement while map voting
	}

	CControls@ controls = getControls();
	CPlayer@ player = getLocalPlayer();
	if(player !is null)
	{
		Camera3D@ camera; player.get("Camera3D", @camera);
		if (camera !is null && controls !is null)
		{
		    if(this.get_bool("set new target"))
		    {
		        string newTarget = this.get_string("new target");
		        _targetPlayer = newTarget;
		        if(targetPlayer() !is null)
		        {
		            waitForRelease = true;
		            this.set_bool("set new target", false);
		        }
		    }

		    if(isWindowActive() && isWindowFocused() && Menu::getMainMenu() is null && !getHUD().hasButtons())
			{	

				Vec2f ScrMid = getDriver().getScreenCenterPos();

				if ((controls.getMouseScreenPos() - ScrMid).Length() < 1.5)
				{ controls.setMousePosition(ScrMid); }
				else
				{ controls.setMousePosition(Vec2f_lerp(controls.getMouseScreenPos(), ScrMid, 0.75)); }	

				Vec3f dir = camera.getRotation();
				Vec2f adjustment = (controls.getMouseScreenPos() - ScrMid);				
				dir.x += adjustment.x*.2;
				dir.y = Maths::Clamp(dir.y-(adjustment.y*.2),-90,90);

				Vec3f pos;
				//Move the camera using the action movement keys
				if (controls.ActionKeyPressed(AK_MOVE_LEFT))
				{
					pos.x -= 5;
					SetTargetPlayer(null);
				}
				if (controls.ActionKeyPressed(AK_MOVE_RIGHT))
				{
					pos.x += 5;
					SetTargetPlayer(null);
				}
				if (controls.ActionKeyPressed(AK_MOVE_UP))
				{
					pos.z += 5;
					SetTargetPlayer(null);
				}
				if (controls.ActionKeyPressed(AK_MOVE_DOWN))
				{
					pos.z -= 5;
					SetTargetPlayer(null);
				}
				if(controls.isKeyPressed(KEY_SPACE))
				{
					pos.y += 5;
					SetTargetPlayer(null);
				}
				if(controls.isKeyPressed(KEY_LSHIFT))
				{
					pos.y -= 5;
					SetTargetPlayer(null);
				}

				pos.xzRotateBy(dir.x);
				
			    if(controls.isKeyJustReleased(KEY_LBUTTON))
			    {
			        waitForRelease = false;
			    }				    			

				//Click on players to track them
				if (controls.isKeyJustPressed(KEY_LBUTTON))
				{
					Vec3f vec = Vec3f(0,0,99999999);
					vec.yzRotateBy( camera.getRotation().y);
					vec.xzRotateBy( camera.getRotation().x);
			
					Ray ray(camera.getPosition(), camera.getPosition()+vec);
					
				//	CBlob@[] players;
				//	SetTargetPlayer(null);
				//	getBlobsByTag("player", @players);
				//	for (uint i = 0; i < players.length; i++)
				//	{
				//		CBlob@ blob = players[i];
				//		Blob3D@ blob3D; blob.get("blob3d", @blob3D);
				//		if (!blob.get("blob3d", @blob3D)) { continue; }
//
				//		Vec3f bpos = blob3D.getInterpolatedPosition();
//
				//		if (camera.getTarget() !is blob3D)
				//		{
				//			if (blob3D.shape !is null)
				//			{
				//				if (blob3D.shape.Intersects(ray))
				//				{
				//					//print("set player to track: " + (blob.getPlayer() is null ? "null" : blob.getPlayer().getUsername()));
				//					SetTargetPlayer(blob.getPlayer());
				//					camera.setTarget(blob3D);
				//					camera.setPosition(blob3D.getInterpolatedPosition());
				//					print("yo");
				//					blob3D.shape.UpdateAttributes(SColor(255,255,0,0));
				//					return;
				//				}
				//				else
				//				{
				//					blob3D.shape.UpdateAttributes(SColor(150,0,255,0));
				//				}	
				//			}
				//		}
				//	}
				}

				if (targetPlayer() !is null)
				{
					Blob3D@ targetblob3D;				 
					if (targetPlayer().getBlob().get("blob3d", @targetblob3D))
					{
						if (camera.getTarget() !is targetblob3D)
						{
							camera.setTarget(targetblob3D);
						}
					}					
				}
				else
				{
					camera.setTarget(null);
				}

				//set specific zoom if we have a target
				if (camera.getTarget() !is null)
				{
					//camera.mousecamstyle = 1;
					//camera.mouseFactor = 0.5f;
					return;
				}

				//Don't go to far off the map boundaries
				//CMap@ map = getMap();
				//if (map !is null)
				//{
				//	f32 borderMarginX = map.tilesize * 2 / zoomTarget;
				//	f32 borderMarginY = map.tilesize * 2 / zoomTarget;
				
				//	if (pos.x < borderMarginX)
				//	{
				//		pos.x = borderMarginX;
				//	}
				//	if (pos.y < borderMarginY)
				//	{
				//		pos.y = borderMarginY;
				//	}
				//	if (pos.x > map.tilesize * map.tilemapwidth - borderMarginX)
				//	{
				//		pos.x = map.tilesize * map.tilemapwidth - borderMarginX;
				//	}
				//	if (pos.y > map.tilesize * map.tilemapheight - borderMarginY)
				//	{
				//		pos.y = map.tilesize * map.tilemapheight - borderMarginY;
				//	}
				//}
				camera.setPosition(camera.getPosition()+pos);
				camera.setRotation(-dir);
			}
		}
	}
}

void FollowTarget(CRules@ this, CBlob@ lp)
{
	CPlayer@ player = getLocalPlayer();
	if(player !is null)
	{
		Camera3D@ camera;
		player.get("Camera3D", @camera);
		if (camera is null) { return; }	


		CBlob@ localBlob = getLocalPlayerBlob();
		Blob3D@ blob3d;
		if (localBlob is null) { return; }
		if (!localBlob.get("blob3d", @blob3d) || blob3d is null)
		{
			Vec2f fallbackPos = localBlob.getInterpolatedPosition();
			Vec3f fallbackDir(localBlob.get_f32("dir_x"), localBlob.get_f32("dir_y"), 0.0f);
			camera.setTarget(null);
			camera.setPosition(Vec3f(fallbackPos.x, FIRST_PERSON_EYE_HEIGHT, fallbackPos.y));
			camera.setRotation(fallbackDir);
			return;
		}

		const bool firstPersonCamera = IsFirstPersonCameraEnabled(this) && localBlob.getName() != "shark";
		if (firstPersonCamera && !localBlob.isAttached())
		{
			camera.setTarget(null);
			Vec3f dir = blob3d.transform.Orientation.getXYZ();
			Vec3f eyePos = blob3d.getRenderPosition() + Vec3f(0.0f, FIRST_PERSON_EYE_HEIGHT, 0.0f);
			camera.setPosition(eyePos);
			camera.setRotation(dir);

		    if(isWindowActive() && isWindowFocused() && Menu::getMainMenu() is null && !getHUD().hasButtons() && !player.getBlob().get_bool( "build menu open" ))
			{
				CControls@ controls = getControls();

				Vec2f ScrMid = getDriver().getScreenCenterPos();
				ScrMid += ArbitraryMouseOffset; 
				Vec2f mouseDistDelta = controls.getMouseScreenPos() - getDriver().getScreenCenterPos();

				if (mouseDistDelta.Length() < 1.5)
				{ controls.setMousePosition(ScrMid); }
				else
				{ controls.setMousePosition(Vec2f_lerp(controls.getMouseScreenPos(), ScrMid, 0.75)); }	
			}

			return;
		}

		const bool sharkCamera = localBlob.getName() == "shark";
		camera.pos_offset = sharkCamera ? Vec3f(0.0f, 28.0f, -86.0f) : Vec3f(THIRD_PERSON_SEAT_OFFSET_X, THIRD_PERSON_SEAT_OFFSET_Y, THIRD_PERSON_SEAT_OFFSET_Z);
	    Blob3D@ targetblob3D = camera.getTarget();
		if (sharkCamera)
		{
			if (targetblob3D !is blob3d)
			{
				camera.setTarget(@blob3d);
			}
			@targetblob3D = blob3d;
		}
		else if (targetblob3D is null)
		{
			camera.setTarget(@blob3d);
			@targetblob3D = blob3d;
		}

	    if (targetblob3D !is null)
	    {
			Vec3f off = camera.pos_offset;
			Vec3f dir = targetblob3D.transform.Orientation.getXYZ();
			if (sharkCamera)
			{
				dir.x = -localBlob.get_f32("dir_x");
				dir.y = localBlob.get_f32("dir_y");
				dir.z = 0.0f;
			}
			camera.setRotation(-dir);
			off.yzRotateBy(dir.y);
			off.xzRotateBy(dir.x);

		    if(isWindowActive() && isWindowFocused() && Menu::getMainMenu() is null && !getHUD().hasButtons() && !player.getBlob().get_bool( "build menu open" ))
			{
				CControls@ controls = getControls();

				Vec2f ScrMid = getDriver().getScreenCenterPos();
				ScrMid += ArbitraryMouseOffset; 
				Vec2f mouseDistDelta = controls.getMouseScreenPos() - getDriver().getScreenCenterPos();

				if (mouseDistDelta.Length() < 1.5)
				{ controls.setMousePosition(ScrMid); }
				else
				{ controls.setMousePosition(Vec2f_lerp(controls.getMouseScreenPos(), ScrMid, 0.75)); }	
			}	

			Vec3f targetPosition = targetblob3D.getRenderPosition();
			if (sharkCamera)
			{
				Vec2f sharkPosition = localBlob.getInterpolatedPosition();
				f32 sharkY = Maths::Lerp(localBlob.get_f32("old_shark_y"), localBlob.get_f32("shark_y"), getRules().get_f32("interFrameTime"));
				targetPosition = Vec3f(sharkPosition.x, sharkY, sharkPosition.y);
			}
			Vec3f desiredPos = targetPosition + off;
			Vec3f currentPos = camera.getPosition();
			currentPos = sharkCamera ? desiredPos : currentPos + (desiredPos - currentPos) * 0.15f; //lerp for smoothing

			camera.setPosition(currentPos);			
		}
	}
}
