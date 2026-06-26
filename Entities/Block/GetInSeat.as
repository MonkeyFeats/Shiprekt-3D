#include "BlockCommon.as"
#include "AccurateSoundPlay.as"
#include "Blob3D.as"

const string ATTACHED_SEAT_ID = "attached seat id";

void PlaceDetachedHumanAtSeat(CBlob@ seat, CBlob@ detached)
{
	if (seat is null || detached is null)
	{
		return;
	}

	Blob3D@ seatBlob3d;
	Blob3D@ detachedBlob3d;
	if (!seat.get("blob3d", @seatBlob3d) || seatBlob3d is null || !detached.get("blob3d", @detachedBlob3d) || detachedBlob3d is null)
	{
		return;
	}

	f32 seatYaw = seat.getAngleDegrees();
	if (seat.hasTag("flak") || seat.hasTag("harpoon"))
	{
		seatYaw = seat.get_f32("angle");
	}

	Vec2f exitOffset(12.0f, 0.0f);
	exitOffset.RotateBy(seatYaw);

	Vec3f exitPos = seatBlob3d.getPosition();
	exitPos.x += exitOffset.x;
	exitPos.y += 18.0f;
	exitPos.z += exitOffset.y;

	detachedBlob3d.setPosition(exitPos);
	if (detachedBlob3d.shape !is null)
	{
		detachedBlob3d.shape.setPosition(exitPos);
	}
	if (detachedBlob3d.rb !is null)
	{
		detachedBlob3d.rb.setSolvedVelocity(Vec3f());
	}

	detached.setPosition(exitPos.xz());
	detached.setVelocity(Vec2f_zero);
	detached.getShape().getVars().onground = false;
}

void onInit( CBlob@ this )
{
	this.set_string("seat label", "");
	this.set_u8("seat icon", 0);
	this.addCommandID("get in seat");
	this.Tag("seat");
}

void GetButtonsFor( CBlob@ this, CBlob@ caller )
{
	// Seats are handled by the 3D center-screen raycast prompt in Human.as.
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("get in seat"))
    {
		if ( getNet().isServer() )
		{
			string seatOwner;
			this.get( "playerOwner", seatOwner );
			CBlob@ caller = getBlobByNetworkID( params.read_netid() );
			if (caller is null) { return; }

			this.server_AttachTo(caller, "SEAT");
			caller.set_u16(ATTACHED_SEAT_ID, this.getNetworkID());
			caller.Sync(ATTACHED_SEAT_ID, true);

			Blob3D@ blob3d;
			if (!this.get("blob3d", @blob3d)) { return; }

			Blob3D@ callerBlob3d;
			if (!caller.get("blob3d", @callerBlob3d)) { return; }

			@callerBlob3d.Parent = null;
			Vec3f seatPos = blob3d.getPosition();
			seatPos.y += 16.0f;
			callerBlob3d.setPosition(seatPos);
		}
	}
}

void onAttach( CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint )
{
	attached.set_u16(ATTACHED_SEAT_ID, this.getNetworkID());
	if (getNet().isServer())
	{
		attached.Sync(ATTACHED_SEAT_ID, true);
	}
	directionalSoundPlay( "GetInVehicle.ogg", this.getPosition() );

}

void onDetach( CBlob@ this, CBlob@ detached, AttachmentPoint @attachedPoint )
{
	directionalSoundPlay( "GetInVehicle.ogg", this.getPosition() );
	this.getShape().getVars().onground = true;
	detached.set_u16(ATTACHED_SEAT_ID, 0);
	PlaceDetachedHumanAtSeat(this, detached);
	if (getNet().isServer())
	{
		detached.Sync(ATTACHED_SEAT_ID, true);
	}
}
