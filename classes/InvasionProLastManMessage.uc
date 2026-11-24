class InvasionProLastManMessage extends LocalMessage;

#exec AUDIO IMPORT NAME="LastOneAliveVO" FILE="..\InvasionProv1_7modV1\Sounds\lastonealive.wav" GROUP="Announcer"

static function string GetString(optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	return "LAST ONE ALIVE!";
}

static function ClientReceive( PlayerController P, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject )
{
	Super.ClientReceive(P, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

	if(P.ViewTarget != None)
		P.ViewTarget.PlaySound(Sound'InvasionProv1_7modV1.Announcer.LastOneAliveVO', SLOT_None, 384.0,,,,false);
}

defaultproperties
{
	bIsSpecial=True
	bIsUnique=True
	bFadeMessage=True
	bIsConsoleMessage=False
	Lifetime=5
	DrawColor=(R=255,G=0,B=0,A=255)
	DrawPivot=DP_MiddleMiddle
	PosX=0.500000
	StackMode=SM_Down
	PosY=0.220000
	FontSize=0
}
