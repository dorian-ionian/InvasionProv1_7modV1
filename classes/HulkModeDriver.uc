//=======================================================
// HulkModeDriver - InvasionProMod bHulkMode server-side
// driver. Rolls the "get angry" chance when an enemy
// monster is damaged (called from ReduceDamage), grows
// hulked monsters smoothly to twice their size, keeps a
// red corona on them, counts down the rage duration, and
// tracks hulk state for damage scaling + kill bonuses.
//=======================================================
class HulkModeDriver extends Info;

var array<Monster> Hulks;          // every hulked monster (index-aligned arrays below)
var array<float> HulkStartScale;   // DrawScale at hulk time (shrink target)
var array<float> HulkTargetScale;  // DrawScale to grow toward
var array<float> HulkOrigRadius;   // CollisionRadius at hulk time
var array<float> HulkOrigHeight;   // CollisionHeight at hulk time
var array<vector> HulkOrigPrepivot;// mesh draw offset at hulk time (scaled with size)
var array<float> HulkOrigHealthMax;// HealthMax at hulk time (revert target)
var array<float> HulkTimeLeft;     // rage seconds remaining (-1 = permanent)
var array<int> HulkState;          // 0 = growing, 1 = active, 2 = shrinking
var array<Actor> HulkCoronas;      // red glow actor per hulk (None if disabled)
var array<vector> HulkLastLoc;     // last location (stuck-hulk detection)
var array<float> HulkStuckTime;    // seconds stuck while having a distant target

function InvasionProMod GetGame()
{
	return InvasionProMod(Level.Game);
}

function bool IsHulked(Monster M)
{
	local int i;

	for ( i = 0; i < Hulks.Length; i++ )
	{
		if ( Hulks[i] == M )
			return true;
	}
	return false;
}

//Friendly monsters (player minions, pets, team monsters) never hulk.
function bool IsFriendlyMonster(Monster M)
{
	local string CN;

	if ( M == None || M.Controller == None )
		return false;
	if ( M.Controller.IsA('FriendlyMonsterController') )
		return true;
	//Class name match for pets (no direct reference - the pets package
	//compiles after this one).
	CN = string(M.Controller.Class.Name);
	if ( Right(CN, Len("PetController")) == "PetController" )
		return true;
	return ( M.GetTeamNum() != 255 );
}

//Rolled from ReduceDamage on every qualifying damage event.
function bool TryHulk(Monster M)
{
	local InvasionProMod G;

	G = GetGame();
	if ( G == None || !G.bHulkMode )
		return false;
	if ( M == None || M.bDeleteMe || M.Health <= 0 )
		return false;
	if ( IsHulked(M) )
		return false;
	if ( IsFriendlyMonster(M) )
		return false;
	//vehicle monsters keep their shell collision/driver logic - skip
	if ( G.IsVehicleMonsterPawn(M) )
		return false;
	//sprite-based monsters are excluded by default - scaling a billboard
	//quad looks wrong and the hitbox never matches the visual anyway
	if ( G.bHulkExcludeSprites && M.DrawType == DT_Sprite )
		return false;
	//admin exclude list (short class name or full path)
	if ( G.IsHulkExcluded(M) )
		return false;
	//bosses are opt-in (already huge / scripted)
	if ( !G.bHulkBosses && ( M.bBoss || G.MonsterIsBoss(M) ) )
		return false;
	if ( FRand() > G.HulkChance )
		return false;
	//giants: skip if the TARGET scale would be too big (a 15x Trex growing to
	//30x embeds in indoor maps -> stuck + undamageable + survives wave-end)
	if ( G.HulkMaxScale > 0 && M.DrawScale * FMax(G.HulkScale, 1.0) > G.HulkMaxScale )
		return false;

	ApplyHulk(M);
	return true;
}

function ApplyHulk(Monster M)
{
	local InvasionProMod G;
	local int i;
	local float NewMax;
	local string HulkText;

	G = GetGame();
	if ( G == None )
		return;

	//speed (movement + jump)
	M.GroundSpeed = M.default.GroundSpeed * G.HulkSpeedMult;
	M.WaterSpeed  = M.default.WaterSpeed * G.HulkSpeedMult;
	M.AirSpeed    = M.default.AirSpeed * G.HulkSpeedMult;
	M.JumpZ       = M.default.JumpZ * G.HulkSpeedMult;

	//health: scale current AND max by the same factor
	NewMax = M.default.HealthMax * G.HulkHealthMult;
	M.HealthMax = NewMax;
	M.Health = Min( int(M.Health * G.HulkHealthMult), int(NewMax) );

	//octave-lower sounds (64 = normal pitch in this engine, 32 = half)
	M.SoundPitch = 32;

	//anger roar (no explicit pitch - uses the monster's low SoundPitch)
	if ( M.ChallengeSound[0] != None || M.ChallengeSound[1] != None
		|| M.ChallengeSound[2] != None || M.ChallengeSound[3] != None )
	{
		M.PlaySound( M.ChallengeSound[Rand(4)], SLOT_Talk, 2.0, true, 1000 );
	}

	//growth tracking (relative to current size - "twice their size")
	i = Hulks.Length;
	Hulks.Length = i + 1;
	HulkStartScale.Length = i + 1;
	HulkTargetScale.Length = i + 1;
	HulkOrigRadius.Length = i + 1;
	HulkOrigHeight.Length = i + 1;
	HulkOrigPrepivot.Length = i + 1;
	HulkOrigHealthMax.Length = i + 1;
	HulkTimeLeft.Length = i + 1;
	HulkState.Length = i + 1;
	HulkCoronas.Length = i + 1;
	HulkLastLoc.Length = i + 1;
	HulkStuckTime.Length = i + 1;
	Hulks[i] = M;
	HulkStartScale[i] = M.DrawScale;
	HulkTargetScale[i] = M.DrawScale * FMax(G.HulkScale, 1.0);
	HulkOrigRadius[i] = M.CollisionRadius;
	HulkOrigHeight[i] = M.CollisionHeight;
	HulkOrigPrepivot[i] = M.Prepivot;
	HulkOrigHealthMax[i] = M.default.HealthMax;
	HulkLastLoc[i] = M.Location;
	HulkStuckTime[i] = 0;
	HulkTimeLeft[i] = -1;
	HulkState[i] = 0;
	if ( G.HulkDuration > 0 )
	{
		HulkTimeLeft[i] = G.HulkDuration;
	}

	//red corona so the hulk reads clearly at a distance
	if ( G.bHulkCorona )
	{
		HulkCoronas[i] = Spawn(class'HulkCorona', M);
		if ( HulkCoronas[i] != None )
		{
			HulkCoronas[i].SetBase(M);
		}
	}

	//announce the rage
	if ( G.bHulkAnnounce )
	{
		//Name is resolved here on the server; clients have no MonsterNamesV1.ini
		HulkText = "A "$class'MonsterNameTable'.static.GetDisplayName(M.Class)$" has become enraged!";
		//the HUD draws this copy with "enraged" in red
		if ( G.WaveTimerActor != None )
		{
			G.WaveTimerActor.AddHulkMessage(HulkText);
		}
	}
}

event Tick(float DeltaTime)
{
	local int i;
	local float S, TS, Rate, SReq;
	local InvasionProMod G;

	G = GetGame();
	if ( G == None )
		return;

	for ( i = Hulks.Length - 1; i >= 0; i-- )
	{
		if ( Hulks[i] == None || Hulks[i].bDeleteMe || Hulks[i].Health <= 0 )
		{
			RemoveHulk(i);
			continue;
		}

		if ( HulkState[i] == 0 ) //growing
		{
			TS = HulkTargetScale[i];
			S = Hulks[i].DrawScale;
			if ( S < TS - 0.01 )
			{
				if ( G.HulkGrowTime > 0 )
				{
					Rate = (TS - HulkStartScale[i]) / G.HulkGrowTime;
					S = FMin( TS, S + Rate * DeltaTime );
				}
				else
				{
					S = TS;
				}
				SReq = S;
				S = SetHulkScale(i, S);
				//ceiling-capped mid-growth = fully grown at the fit size
				if ( S >= TS - 0.01 || S < SReq - 0.01 )
				{
					HulkState[i] = 1;
				}
			}
			else
			{
				HulkState[i] = 1;
			}
		}
		else if ( HulkState[i] == 1 ) //active - count down the rage
		{
			//STRICT ENFORCEMENT: re-assert size + collision every tick while
			//hulked - something can reset pawn collision (native physics runs
			//after our Tick), which makes the feet sink into the floor while
			//the visual stays big.
			SetHulkScale(i, HulkTargetScale[i]);
			if ( HulkTimeLeft[i] >= 0 )
			{
				HulkTimeLeft[i] -= DeltaTime;
				if ( HulkTimeLeft[i] <= 0 )
				{
					HulkState[i] = 2;
				}
			}
		}
		else if ( HulkState[i] == 2 ) //shrinking back to normal
		{
			TS = HulkStartScale[i];
			S = Hulks[i].DrawScale;
			if ( S > TS + 0.01 )
			{
				if ( G.HulkGrowTime > 0 )
				{
					Rate = (HulkTargetScale[i] - TS) / G.HulkGrowTime;
					S = FMax( TS, S - Rate * DeltaTime );
				}
				else
				{
					S = TS;
				}
				SetHulkScale(i, S);
			}
			else
			{
				RevertHulk(i);
				RemoveHulk(i);
			}
		}
	}
}

//Scale mesh AND collision together (collision stays proportional to the
//visual - orig collision was measured at the start scale). UE2 pawn
//Location is the collision cylinder CENTER, so a collision height change
//drifts the cylinder bottom: growing pushes it below the floor (feet sink)
//and shrinking lifts it above (feet float - nothing pulls a walking pawn
//down). Nudge Z by the exact height delta so the bottom never moves.
//Prepivot is the MESH draw offset from the actor center. The draw origin
//must stay at the same FRACTION of the cylinder height for the visual feet
//to track the collision bottom: Prepivot = P0 * S / StartScale (RELATIVE
//scaling). This is correct for EVERY anchor convention - center-anchored
//stock skeletal models, feet-anchored vertex-mesh ports, and everything in
//between. (The old feet-anchored detection branch was only right for models
//whose origin sat EXACTLY at the collision bottom; mid-anchored models got
//their feet pushed below the floor by up to 0.5x their height.) Returns the
//scale actually applied - when a ceiling blocks the headroom the size is
//capped to the free space instead of pushing the head into the ceiling
//(that embeds the monster AND sinks the feet below the floor).
function float SetHulkScale(int i, float S)
{
	local float OldH, NewH, Free, AppliedS;
	local vector Start, End, HitLoc, HitNorm;

	OldH = Hulks[i].CollisionHeight;
	NewH = HulkOrigHeight[i] * S / HulkStartScale[i];
	AppliedS = S;
	if ( NewH >= OldH )
	{
		//growing OR maintaining full size: never push the head INTO a
		//ceiling/arch (that embeds the monster -> stuck AND sinks the feet
		//below the floor when physics pushes it back down). Trace up first;
		//if the headroom is smaller than the (full) desired size, cap the
		//size to the free space - growing stops early, and a hulk that
		//walks under a low arch shrinks to fit instead of embedding.
		Start = Hulks[i].Location + vect(0,0,1) * (OldH - 2);
		End = Hulks[i].Location + vect(0,0,1) * (OldH + (NewH - OldH) + 2);
		if ( Hulks[i].Trace(HitLoc, HitNorm, End, Start, false) != None )
		{
			Free = HitLoc.Z - Start.Z - 2;
			if ( Free < NewH - OldH )
			{
				NewH = OldH + Free;
				if ( NewH < 0.1 )
					NewH = 0.1;
				AppliedS = NewH * HulkStartScale[i] / HulkOrigHeight[i];
			}
		}
	}
	Hulks[i].SetDrawScale(AppliedS);
	//relative prepivot: keeps the draw origin at the same fraction of the
	//collision cylinder, so the visual feet track the collision bottom at
	//ANY scale for ANY model anchor convention
	Hulks[i].Prepivot = HulkOrigPrepivot[i] * (AppliedS / HulkStartScale[i]);
	Hulks[i].SetCollisionSize( HulkOrigRadius[i] * AppliedS / HulkStartScale[i], NewH );
	if ( NewH != OldH )
	{
		Hulks[i].SetLocation( Hulks[i].Location + vect(0,0,1) * (NewH - OldH) );
	}
	if ( HulkCoronas[i] != None )
	{
		HulkCoronas[i].SetDrawScale(AppliedS * 2.0);
	}
	return AppliedS;
}

//Floor re-seat: post-physics pass that traces straight down from a grounded
//hulk and re-seats the collision cylinder bottom on the floor if it has
//drifted (native collision reset, shrink float, knockback). Only walking
//monsters - flyers/swimmers/fallers keep their own motion.
function SnapToFloor(int i)
{
	local Monster M;
	local vector HitLoc, HitNorm, Start, End;
	local float FloorZ, Gap;

	M = Hulks[i];
	if ( M == None || M.Physics != PHYS_Walking )
		return;

	Start = M.Location - vect(0,0,1) * (M.CollisionHeight - 4);
	End = M.Location - vect(0,0,1) * (M.CollisionHeight + 80);
	if ( M.Trace(HitLoc, HitNorm, End, Start, false) != None )
	{
		FloorZ = HitLoc.Z;
		Gap = FloorZ + M.CollisionHeight - M.Location.Z;
		//only correct SMALL drifts (|Gap| <= 10). A gap above 10 means the
		//trace found a floor BELOW a ledge/step/hole (the pawn is
		//legitimately over it and walking physics carries it down) -
		//"correcting" those teleports the pawn DOWN into the ledge
		//face/geometry (embedded -> stuck + undamageable + PlayerCanSeeMe()
		//=true so the wave-end cull never kills it). The v8 clamp at 40
		//still embedded pawns on steps/ledges with drops under 40 units.
		//Small corrections fix the -4 below-floor sink and the 2.15 walking
		//bumps without teleports.
		if ( Gap > 0.1 && Gap <= 10.0 )
		{
			M.SetLocation( M.Location + vect(0,0,1) * Gap );
		}
		else if ( Gap < -0.1 && Gap >= -10.0 )
		{
			M.SetLocation( M.Location + vect(0,0,1) * Gap );
		}
	}
}

//STRICT ENFORCEMENT pass 2: fast repeat that fires AFTER all actor ticks
//(including the pawn's own native physics tick) and re-asserts the hulk
//collision/scale - catches anything that resets pawn collision mid-hulk.
//0.05s = one server frame at the default 20Hz tick rate.
event PostBeginPlay()
{
	Super.PostBeginPlay();
	SetTimer(0.05, true);
}

function Timer()
{
	local int i;
	local float S;
	local InvasionProMod G;

	//WAVE-END WATCHDOG (2026-08-17): the game's own Timer can go quiet
	//(match-end from all lives lost, script error, whatever) - the wave-end
	//force-kill in the game Timer would never fire and monsters stay alive
	//forever ("leftover" wave). This runs on the driver's 0.05s timer,
	//which is independent of the game's Timer and keeps ticking no matter
	//what. Once the wave time limit + grace is up, remove leftover monsters
	//one per second (ForceCullOneMonster rate-limits) so the wave can end.
	//The game Timer does the same (and advances the wave immediately) - this
	//is the safety net.
	G = GetGame();
	if ( G != None && G.bWaveInProgress && G.bWaveTimeLimit
		&& Level.TimeSeconds > G.WaveEndTime + G.WaveEndForceKillDelay )
	{
		G.ForceCullOneMonster();
	}

	for ( i = 0; i < Hulks.Length; i++ )
	{
		if ( Hulks[i] == None || Hulks[i].bDeleteMe || Hulks[i].Health <= 0 )
		{
			RemoveHulk(i);
			continue;
		}

		//STUCK-HULK SWEEP: a monster that lost its controller can never be
		//wave-end-killed (ForceNextWave/CullMonsters/NumHostileMonsters all
		//skip Controller==None) - it would be a permanent leftover. Destroy
		//it. Also destroy hulks that are stuck (distant target, not moving
		//for 10s, and no line of sight to it - typically embedded in geometry
		//after growing indoors). Ranged hulks that stand still with a clear
		//shot are left alone.
		if ( Hulks[i].Controller == None )
		{
			Hulks[i].Destroy();
			RemoveHulk(i);
			continue;
		}
		if ( HulkState[i] != 2 && Hulks[i].Controller.Target != None
			&& VSize(Hulks[i].Controller.Target.Location - Hulks[i].Location) > 400
			&& !Hulks[i].Controller.LineOfSightTo(Hulks[i].Controller.Target) )
		{
			if ( VSize(Hulks[i].Location - HulkLastLoc[i]) < 1.0 )
			{
				HulkStuckTime[i] += 0.05;
			}
			else
			{
				HulkStuckTime[i] = 0;
			}
			if ( HulkStuckTime[i] > 10.0 )
			{
				Hulks[i].Destroy();
				RemoveHulk(i);
				continue;
			}
		}
		else
		{
			HulkStuckTime[i] = 0;
		}
		HulkLastLoc[i] = Hulks[i].Location;

		//fully grown hulks pin to the target; growing/shrinking use the
		//current (mid-interp) visual scale
		if ( HulkState[i] == 1 )
			S = HulkTargetScale[i];
		else
			S = Hulks[i].DrawScale;

		SetHulkScale(i, S);
		SnapToFloor(i);
	}
}

function RevertHulk(int i)
{
	local Monster M;
	local InvasionProMod G;
	local float HulkedMax;

	M = Hulks[i];
	G = GetGame();
	if ( M == None || G == None )
		return;

	//speed back to class defaults
	M.GroundSpeed = M.default.GroundSpeed;
	M.WaterSpeed  = M.default.WaterSpeed;
	M.AirSpeed    = M.default.AirSpeed;
	M.JumpZ       = M.default.JumpZ;

	//health: keep the same proportion, back to the original max
	HulkedMax = HulkOrigHealthMax[i] * G.HulkHealthMult;
	M.HealthMax = HulkOrigHealthMax[i];
	M.Health = Min( int(M.Health * HulkOrigHealthMax[i] / FMax(HulkedMax, 1.0)), int(HulkOrigHealthMax[i]) );

	//sounds back to normal pitch
	M.SoundPitch = 64;

	//mesh draw offset back to normal
	M.Prepivot = HulkOrigPrepivot[i];
}

function RemoveHulk(int i)
{
	local int Last;

	if ( HulkCoronas[i] != None )
	{
		HulkCoronas[i].Destroy();
	}

	Last = Hulks.Length - 1;
	Hulks[i] = Hulks[Last];
	HulkStartScale[i] = HulkStartScale[Last];
	HulkTargetScale[i] = HulkTargetScale[Last];
	HulkOrigRadius[i] = HulkOrigRadius[Last];
	HulkOrigHeight[i] = HulkOrigHeight[Last];
	HulkOrigPrepivot[i] = HulkOrigPrepivot[Last];
	HulkOrigHealthMax[i] = HulkOrigHealthMax[Last];
	HulkTimeLeft[i] = HulkTimeLeft[Last];
	HulkState[i] = HulkState[Last];
	HulkCoronas[i] = HulkCoronas[Last];
	HulkLastLoc[i] = HulkLastLoc[Last];
	HulkStuckTime[i] = HulkStuckTime[Last];
	Hulks.Length = Last;
	HulkStartScale.Length = Last;
	HulkTargetScale.Length = Last;
	HulkOrigRadius.Length = Last;
	HulkOrigHeight.Length = Last;
	HulkOrigPrepivot.Length = Last;
	HulkOrigHealthMax.Length = Last;
	HulkTimeLeft.Length = Last;
	HulkState.Length = Last;
	HulkCoronas.Length = Last;
	HulkLastLoc.Length = Last;
	HulkStuckTime.Length = Last;
}

defaultproperties
{
}
