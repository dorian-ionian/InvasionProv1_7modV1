//Replicated carrier for the HUD wave-time display.
//Spawned server-side by InvasionProMod.PostBeginPlay. The parent package's
//InvasionProGameReplicationInfo has no wave-end-time field (and the parent
//package is not recompiled), so this tiny Info actor carries the seconds
//remaining in the current wave to all clients. An INT countdown (not an
//absolute timestamp) is replicated so client/server clock skew cannot make
//the HUD read wrong.
class InvasionProWaveTimer extends Info;

var int WaveSecondsLeft;   //replicated: whole seconds left in the current wave (0 when none)
var bool bWaveInProgress;  //replicated: a wave is currently running
var bool bWaveTimeLimit;   //replicated: waves are ended by the time limit

//Wild-monster death lines, built on the server (so monster name overrides apply)
//and drawn by each client's HUD. A ring buffer of the last 4 lines; DeathMsgCount
//is the total ever written, so the client can tell which lines are new.
var string DeathMsg[4];    //replicated
var int DeathMsgCount;     //replicated

//Latest hulk announcement ("A <name> has become enraged!"), built on the server.
//Sent as a string so clients do not need the monster name table to draw it.
var string HulkMsg;        //replicated
var int HulkMsgCount;      //replicated

replication
{
	reliable if( Role == ROLE_Authority )
		WaveSecondsLeft, bWaveInProgress, bWaveTimeLimit, DeathMsg, DeathMsgCount, HulkMsg, HulkMsgCount;
}

function AddWildDeathMessage(string Msg)
{
	DeathMsg[DeathMsgCount % 4] = Msg;
	DeathMsgCount++;
}

function AddHulkMessage(string Msg)
{
	HulkMsg = Msg;
	HulkMsgCount++;
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();

	if( Role == ROLE_Authority )
	{
		SetTimer(0.5, true);
	}
}

simulated function Timer()
{
	local InvasionProMod G;

	if( Role != ROLE_Authority )
	{
		return;
	}

	G = InvasionProMod(Level.Game);
	if( G == None )
	{
		return;
	}

	bWaveTimeLimit = G.bWaveTimeLimit;
	bWaveInProgress = G.bWaveInProgress;

	if( G.bWaveInProgress && G.bWaveTimeLimit )
	{
		WaveSecondsLeft = int(G.WaveEndTime - Level.TimeSeconds + 0.5);
	}
	else
	{
		WaveSecondsLeft = 0;
	}
}

defaultproperties
{
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=5.0
}
