const string target_player_id = "target_player_id";

void onInit(CBlob@ this)
{
	this.addCommandID("shoot");

	this.set_bool("attacking", false);
	this.set_u16(target_player_id, 0);

	// init arm sprites
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ arm = sprite.addSpriteLayer("arm", "DefenseTurret_gun", 48, 32);
	this.Tag("builder always hit");

	if (arm !is null)
	{
		Animation@ anim = arm.addAnimation("defaultarm", 0, false);
		arm.SetOffset(Vec2f(-8.0f, -11.0f));
		arm.SetRelativeZ(100.0f);

		arm.animation.frame = 2;
	}

	this.getShape().SetRotationsAllowed(false);

	sprite.SetZ(20.0f);
}


void onTick(CBlob@ this)
{
	u16 target = this.get_u16(target_player_id); //target's netid

	CBlob@ targetblob = getBlobByNetworkID(this.get_u16(target_player_id)); //target's blob

	this.getCurrentScript().tickFrequency = 20;

	if (this.get_u16(target_player_id) == 0) // don't have a target
	{		
		@targetblob = getNewTarget( this, true, true);
		if (targetblob !is null)
		{
			this.set_u16(target_player_id, targetblob.getNetworkID());	
		}
	}
	else // i got a target
	{
		if (targetblob !is null)
		{
			this.getCurrentScript().tickFrequency = 1;

			f32 distance;
			const bool visibleTarget = isVisible(this, targetblob, distance);
			if (visibleTarget && distance < 580.0f)
			{
				if (getGameTime() % 11 == 0)
				{
					this.SendCommand(this.getCommandID("shoot"));
				}
			}

			LoseTarget(this, targetblob);

			if (XORRandom(110) == 0)
			{
				this.set_u16(target_player_id, 0);
			}
		}
	}

	//angle
	f32 angle = getAimAngle(this);
	CSprite@ sprite = this.getSprite();
	CSpriteLayer@ arm = sprite.getSpriteLayer("arm");

	if (arm !is null)
	{
		bool facing_left = sprite.isFacingLeft();
		//f32 rotation = angle * (facing_left ? -1 : 1);

		arm.ResetTransform();
		arm.SetFacingLeft(facing_left);
		arm.RotateBy(angle, Vec2f(facing_left ? -9.0f : 8.0f, 7.0f));
	}
}

void OnFire(CBlob@ this)
{
	CBlob@ bullet = server_CreateBlobNoInit("bulletheavy");
	if (bullet !is null)
	{
		bullet.Init();

		bullet.set_f32("bullet_damage_body", 0.22f);
		bullet.set_f32("bullet_damage_head", 0.28f);
		bullet.IgnoreCollisionWhileOverlapped(this);
		bullet.server_setTeamNum(this.getTeamNum());
		Vec2f pos_ = this.getPosition()-Vec2f(0.0f, 7.0f);
		bullet.setPosition(pos_);

		f32 angle = getAimAngle(this);
		angle += ((XORRandom(512) - 256) / 105.0f);
		Vec2f vel = Vec2f(560.0f / 16.5f * (this.isFacingLeft() ? -1 : 1), 0.0f).RotateBy(angle);
		bullet.setVelocity(vel);

		if (isClient())
		{
			ParticleAnimated("SmallExplosion3", (pos_) + vel*0.6, getRandomVelocity(0.0f, XORRandom(40) * 0.01f, this.isFacingLeft() ? 90 : 270) + Vec2f(0.0f, -0.05f), float(XORRandom(360)), 0.6f + XORRandom(50) * 0.01f, 2 + XORRandom(3), XORRandom(70) * -0.00005f, true);
		}

		if (this.isFacingLeft())
		{
			ParticleAnimated("Muzzleflashflip", pos_ - Vec2f(0.0f, 3.0f) + vel*0.15, getRandomVelocity(0.0f, XORRandom(3) * 0.01f, 90) + Vec2f(0.0f, -0.05f), angle, 0.1f + XORRandom(3) * 0.01f, 2 + XORRandom(2), -0.15f, false);
		}
		else
		{
			ParticleAnimated("Muzzleflashflip", pos_ + Vec2f(0.0f, 3.0f) + vel*0.15, getRandomVelocity(0.0f, XORRandom(3) * 0.01f, 270) + Vec2f(0.0f, -0.05f), angle + 180, 0.1f + XORRandom(3) * 0.01f, 2 + XORRandom(2), -0.15f, false);
		}

		makeGibParticle(
		"EmptyShellSmall",               // file name
		this.getPosition() + Vec2f(0.0f, -6),                 // position
		Vec2f((this.isFacingLeft() ? 1 : -1)*2+XORRandom(2),-1.0f),           // velocity
		0,                                  // column
		0,                                  // row
		Vec2f(16, 16),                      // frame size
		0.2f,                               // scale?
		0,                                  // ?
		"ShellCasing",                      // sound
		this.get_u8("team_color"));         // team number

		this.getSprite().PlaySound("DefenseTurretShoot.ogg", 1.3f, 0.90f + XORRandom(15) * 0.01f);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shoot"))
	{
		OnFire(this);
	}
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}


bool LoseTarget(CBlob@ this, CBlob@ targetblob)
{
	if (XORRandom(16) == 0 && targetblob.hasTag("dead"))
	{
		this.set_u16(target_player_id, 0);

		return true;
	}
	return false;
}

CBlob@ getNewTarget(CBlob @blob, const bool seeThroughWalls = false, const bool seeBehindBack = false)
{
	CBlob@[] players;
	getBlobsByTag("player", @players);
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ potential = players[i];
		Vec2f pos2 = potential.getPosition();
		f32 distance;
		if (potential !is blob && blob.getTeamNum() != potential.getTeamNum()
		        && (pos2 - pos).getLength() < 3500.0f
		        && (seeBehindBack || Maths::Abs(pos.x - pos2.x) < 40.0f || (blob.isFacingLeft() && pos.x > pos2.x) || (!blob.isFacingLeft() && pos.x < pos2.x))
		        && !potential.hasTag("dead") && !potential.hasTag("migrant")
		        && (XORRandom(30) == 0 || isVisible(blob, potential, distance))
		   )
		{
			blob.set_Vec2f("last pathing pos", potential.getPosition());
			return potential;
		}
	}
	return null;
}

bool isVisible(CBlob@ blob, CBlob@ targetblob, f32 &out distance)
{
	Vec2f col;
	bool visible = !getMap().rayCastSolid(blob.getPosition(), targetblob.getPosition() + targetblob.getVelocity() * 5.0f, col);
	distance = (blob.getPosition() - col).getLength();
	return visible;
}

f32 getAimAngle(CBlob@ this)
{
	CBlob@ targetblob = getBlobByNetworkID(this.get_u16(target_player_id)); //target's blob

	f32 angle = 0;
	bool facing_left = this.isFacingLeft();

	bool failed = true;

	if (targetblob !is null)
	{
		Vec2f aim_vec = (this.getPosition() - Vec2f(0.0f, 10.0f)) - (targetblob.getPosition() + Vec2f(0.0f, -4.0f) + targetblob.getVelocity() * 5.0f);

		if ((!facing_left && aim_vec.x < 0) ||
		        (facing_left && aim_vec.x > 0))
		{

			angle = (-(aim_vec).getAngle() + 180.0f);
			if (facing_left)
			{
				angle += 180;
			}
		}
		else
		{
			this.SetFacingLeft(!facing_left);
		}
	}

	return angle;
}