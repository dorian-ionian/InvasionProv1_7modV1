//InvasionProMod HUD: stock InvasionProHud plus the remaining wave time,
//drawn directly under the team necro counter (top-left). The wave-time
//data comes from the replicated InvasionProWaveTimer actor spawned by
//InvasionProMod (the parent GRI cannot be extended - parent package is
//not recompiled). Selected via InvasionProMod's HUDType default.
class InvasionProModHud extends InvasionProHud config(User);

var() config bool bDisplayWaveTime;  //toggle for the wave-time readout (User.ini)
var() config float WaveTimePosX;     //screen fraction (0-1) for the readout X - default lines up with the necro digits
var() config float WaveTimePosY;     //screen fraction (0-1) for the readout Y - default sits just below the digits
var() config float GibSize;          //client-only: gib size multiplier, 0-10 (set from the Gib Preferences menu)
var() config int GibAmount;          //client-only: gib amount multiplier, 1-25 (1 = normal amount)
var float NextGibScanTime;           //level time of the next scan for newly spawned gibs
var Actor NewGibs[64];               //gibs scaled in the current scan, given extra copies after the scan
var int NewGibCount;                 //used entries in NewGibs
var InvasionProWaveTimer WaveTimer;  //cached client copy of the replicated carrier
var Font WaveTimeFont;               //cached Font'UT2003Fonts.FontEurostile24' (24px - matches the counter digits)
var InvasionProWaveTimer DeathTimer; //cached client copy of the carrier that holds wild-monster death lines
var int DeathLinesShown;             //how many death lines (DeathMsgCount) this client has already drawn
var int HulkLinesShown;              //how many hulk announcements (HulkMsgCount) this client has already drawn

simulated function ShowTeamScorePassC(Canvas C)
{
	Super.ShowTeamScorePassC(C);

	if( bDisplayWaveTime )
	{
		DrawWaveTime(C);
	}
}

//Friendly monsters only get a health bar when the local player owns TitanRPG
//Medic Awareness (its interaction exists only while the ability is allowed).
function bool HasMedicAwareness()
{
	local int i;

	if( PlayerOwner == None || PlayerOwner.Player == None )
	{
		return false;
	}

	for( i = 0; i < PlayerOwner.Player.LocalInteractions.Length; i++ )
	{
		if( PlayerOwner.Player.LocalInteractions[i] != None && PlayerOwner.Player.LocalInteractions[i].IsA('Interaction_MedicAwareness') )
		{
			return true;
		}
	}
	return false;
}

//Copy of InvasionProHud.DrawMonsterHealth; the health bar is skipped for friendly monsters without Medic Awareness.
simulated function DrawMonsterHealth(Canvas C, Monster M, float Health, float HealthMax, InvasionProMonsterIDInv MonsterInv)
{
	local Vector DrawLocation;
	local Color FinalColor;
	local float HealthPercent;
	local bool bShowBar;

	local bool bFriendlyMonster;

	DrawLocation = C.WorldToScreen(M.Location+(vect(0,0,1)*(M.CollisionHeight+12)));
	if(DrawLocation.Z > 1.0 || M == None || MonsterInv == None || !FastTrace(PawnOwner.Location,M.Location))
	{
		return;
	}

	C.Reset();
	C.Style = ERenderStyle.STY_Normal;
	C.SetPos(DrawLocation.X - (M.CollisionRadius/2), DrawLocation.Y);

	FinalColor.R = 0;
	FinalColor.G = 0;
	FinalColor.B = 0;
	FinalColor.A = 255;

	//TitanRPG summons are not adopted by InvasionPro, so they are recognised by their PRI class
	bFriendlyMonster = MonsterInv.bFriendly || (M.PlayerReplicationInfo != None && M.PlayerReplicationInfo.Class.Name == 'FriendlyPawnPlayerReplicationInfo');
	//Medic Awareness already draws the bar, HP and name of TitanRPG summons, so skip ours to avoid overlapping it
	if(HasMedicAwareness() && M.PlayerReplicationInfo != None && M.PlayerReplicationInfo.Class.Name == 'FriendlyPawnPlayerReplicationInfo')
		return;
	bShowBar = bDisplayMonsterHealthBars && !MonsterInv.bBoss && (!bFriendlyMonster || HasMedicAwareness());
	if(bShowBar)
	{
		HealthPercent = 1.00f * ( Health/HealthMax );

		if(HealthPercent == 0.50)
		{
			FinalColor.R = 255;
			FinalColor.G = 255;
		}
		else if(HealthPercent > 0.50)
		{
			FinalColor.R = 255-(255*HealthPercent);
			FinalColor.G = 255;
		}
		else if(HealthPercent < 0.50)
		{
			FinalColor.R = 255;
			FinalColor.G = 255*HealthPercent;
		}

		C.DrawColor = FinalColor;
		C.DrawRect( Texture'Background_bevel01', 25, 5 );
	}

	if(MonsterInv.MonsterName != "")
	{
		if(MonsterInv.bFriendly)
		{
			M.bScriptPostRender = true;
			if(bDrawPetInfo)
			{
				C.DrawColor = FriendlyMonsterNameColor;
				C.Font = class'UT2MidGameFont'.static.GetMidGameFont( C.ClipX*TestX * HUDScale );
				if(MonsterInv.AuraID > 0)
				{
					C.DrawColor = AuraTextColor;
					C.SetPos(DrawLocation.X - (M.CollisionRadius/2), DrawLocation.Y - 12);
					C.DrawTextClipped(AuraText[MonsterInv.AuraID]);
					C.DrawColor = FriendlyMonsterNameColor;
					C.SetPos(DrawLocation.X - (M.CollisionRadius/2), DrawLocation.Y - 20);
					C.DrawTextClipped(MonsterInv.MonsterName);
				}
				else
				{
					C.DrawColor = FriendlyMonsterNameColor;
					C.SetPos(DrawLocation.X - (M.CollisionRadius/2), DrawLocation.Y - 12);
					C.DrawTextClipped(MonsterInv.MonsterName);
				}
			}
		}
		else
		{
			C.DrawColor = HostileMonsterNameColor;
			C.Font = class'UT2MidGameFont'.static.GetMidGameFont( C.ClipX*TestX * HUDScale );
			C.SetPos(DrawLocation.X - (M.CollisionRadius/2), DrawLocation.Y - 20);
			C.DrawTextClipped(MonsterInv.MonsterName);
		}
	}
}

simulated event PostRender( canvas Canvas )
{
	Super.PostRender(Canvas);
	CheckWildDeathLines();
	CheckHulkLines();

	if( Level.TimeSeconds >= NextGibScanTime )
	{
		NextGibScanTime = Level.TimeSeconds + 0.5;
		ScaleLesserGibs();
	}
}

//Only the Lesser gib pieces are scaled: the parent gibs are hidden. Scaling
//and extra copies happen on clients and standalone games only, so listen and
//dedicated servers never change the replicated gibs. Each gib is tagged once
//after it is scaled; the extra copies are tagged when they are spawned.
simulated function ScaleLesserGibs()
{
	local float F;
	local int Amount, i;
	local InvasionProGibOrganicLesser GL;
	local InvasionProAlienGibOrganicLesser AL;
	local InvasionProMetalGibOrganicLesser ML;

	if( Level.NetMode != NM_Client && Level.NetMode != NM_Standalone )
	{
		return;
	}

	F = class'InvasionProModHud'.default.GibSize;
	Amount = Clamp(class'InvasionProModHud'.default.GibAmount, 1, 25);
	if( F == 1.0 && Amount == 1 )
	{
		return;
	}

	NewGibCount = 0;
	foreach DynamicActors(class'InvasionProv1_7.InvasionProGibOrganicLesser', GL)
	{
		ScaleOneGib(GL, F);
	}
	foreach DynamicActors(class'InvasionProv1_7.InvasionProAlienGibOrganicLesser', AL)
	{
		ScaleOneGib(AL, F);
	}
	foreach DynamicActors(class'InvasionProv1_7.InvasionProMetalGibOrganicLesser', ML)
	{
		ScaleOneGib(ML, F);
	}

	//Extra copies are spawned after the iteration: spawning inside DynamicActors can crash the client.
	if( Amount > 1 )
	{
		for( i = 0; i < NewGibCount; i++ )
		{
			SpawnExtraGibs(NewGibs[i], Amount - 1);
		}
	}
	NewGibCount = 0;
}

simulated function ScaleOneGib(Actor G, float F)
{
	if( G.Tag == 'IPGibSized' )
	{
		return;
	}
	G.Tag = 'IPGibSized';
	G.SetDrawScale(G.DrawScale * F);
	if( NewGibCount < 64 )
	{
		NewGibs[NewGibCount] = G;
		NewGibCount++;
	}
}

//Client-only extra copies of a lesser gib, launched with the same velocity plus a small spread.
simulated function SpawnExtraGibs(Actor G, int Extra)
{
	local int i;
	local Actor C;

	if( G == None )
	{
		return;
	}
	for( i = 0; i < Extra; i++ )
	{
		C = Spawn(G.Class,,, G.Location, G.Rotation);
		if( C == None )
		{
			return;
		}
		C.Tag = 'IPGibSized';
		C.SetDrawScale(G.DrawScale);
		C.Velocity = G.Velocity + VRand() * 100;
	}
}

//Adds any wild-monster death lines the server wrote since the last frame. The
//stock xDeathMessage gives them the green colour and lifetime of a stock death message.
simulated function CheckWildDeathLines()
{
	if( DeathTimer == None || DeathTimer.bDeleteMe )
	{
		DeathTimer = None;
		ForEach AllActors(class'InvasionProWaveTimer', DeathTimer)
		{
			break;
		}
		if( DeathTimer == None )
		{
			return;
		}
		//start from the current count so old lines are not replayed
		DeathLinesShown = DeathTimer.DeathMsgCount;
		HulkLinesShown = DeathTimer.HulkMsgCount;
	}

	//if more than the ring buffer holds was written, skip to the oldest one still kept
	if( DeathTimer.DeathMsgCount - DeathLinesShown > 4 )
	{
		DeathLinesShown = DeathTimer.DeathMsgCount - 4;
	}

	while( DeathLinesShown < DeathTimer.DeathMsgCount )
	{
		AddTextMessage(DeathTimer.DeathMsg[DeathLinesShown % 4], class'xDeathMessage', None);
		DeathLinesShown++;
	}
}

simulated function CheckHulkLines()
{
	if( DeathTimer == None || DeathTimer.bDeleteMe )
	{
		return;
	}
	if( DeathTimer.HulkMsgCount > HulkLinesShown )
	{
		HulkLinesShown = DeathTimer.HulkMsgCount;
		LocalizedMessage(class'InvasionProHulkMessage', 0, None, None, None, DeathTimer.HulkMsg);
	}
}

simulated function DrawWaveTime(Canvas C)
{
	local int Seconds, Minutes, Secs;
	local string TimeText;
	local InvasionProGameReplicationInfo GRI;

	//locate the replicated carrier once (it may not exist client-side yet
	//during the first frames after login/map change)
	if( WaveTimer == None || WaveTimer.bDeleteMe )
	{
		WaveTimer = None;
		ForEach AllActors(class'InvasionProWaveTimer', WaveTimer)
		{
			break;
		}
	}

	if( WaveTimer == None || !WaveTimer.bWaveTimeLimit || !WaveTimer.bWaveInProgress )
	{
		return;
	}

	GRI = InvasionProGameReplicationInfo(PlayerOwner.GameReplicationInfo);

	//boss waves run on the boss timer (already displayed by the stock HUD)
	if( GRI != None && GRI.bBossEncounter )
	{
		return;
	}

	//the readout is anchored under the necro counter - skip it when the
	//counter itself is hidden
	if( GRI != None && ( GRI.bHideNecroPool || !GRI.bTeamNecro || !bDisplayNecroPool ) )
	{
		return;
	}

	Seconds = WaveTimer.WaveSecondsLeft;
	if( Seconds < 0 )
	{
		Seconds = 0;
	}

	if( Seconds <= 0 )
	{
		return;
	}

	Minutes = Seconds / 60;
	Secs = Seconds % 60;
	if( Secs < 10 )
	{
		TimeText = "Wave Time: "$Minutes$":0"$Secs;
	}
	else
	{
		TimeText = "Wave Time: "$Minutes$":"$Secs;
	}

	//24px Eurostile (bigger than the stock mid-game font, matches the
	//necro digits' rendered size). Loaded at runtime like the stock
	//UT2MidGameFont helper does - ucc cannot resolve UT2003Fonts font
	//objects in code (texture package quirk), though they exist.
	if( WaveTimeFont == None )
	{
		WaveTimeFont = Font(DynamicLoadObject("UT2003Fonts.FontEurostile24", class'Font'));
	}
	if( WaveTimeFont == None )
	{
		WaveTimeFont = class'UT2MidGameFont'.static.GetMidGameFont( C.ClipX * HUDScale );
	}
	C.Font = WaveTimeFont;
	C.Style = ERenderStyle.STY_Alpha;
	C.DrawColor = WhiteColor;
	//Left-justified under the team necro counter. Position is per-client
	//tunable in User.ini [InvasionProv1_7modV1.InvasionProModHud]
	//(fraction = pixels / screen size, e.g. 0.01 = 38px X or 22px Y at 4K):
	//   WaveTimePosX=0.010000
	//   WaveTimePosY=0.130000
	C.DrawScreenText( TimeText, WaveTimePosX, WaveTimePosY, DP_UpperLeft );
}

defaultproperties
{
	bDisplayWaveTime=True
	WaveTimePosX=0.010000
	WaveTimePosY=0.130000
	GibSize=1.000000
	GibAmount=1
}
