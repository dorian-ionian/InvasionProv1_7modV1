//Builds the wild-monster death line on the server. It is sent to clients as a
//plain string through InvasionProWaveTimer, so the server's monster name overrides apply.
class InvasionWildDeathMessage extends Object;

var array< class<DamageType> > VerbTypes;

static function int VerbIndex(class<DamageType> DT)
{
	local int i;

	for ( i = 0; i < Default.VerbTypes.Length; i++ )
		if ( Default.VerbTypes[i] == DT )
			return i;
	return 0;
}

static function string GetString(optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	local string Msg, KillerName;
	local int p, VerbIdx;

	if ( RelatedPRI_1 == None )
		return "";

	KillerName = "";
	if ( class<Monster>(OptionalObject) != None )
		KillerName = class'MonsterNameTable'.static.GetDisplayName(class<Monster>(OptionalObject));
	if ( KillerName == "" )
		KillerName = "a monster";
	else
		KillerName = "a " $ KillerName;

	VerbIdx = Switch;
	if ( VerbIdx < 0 || VerbIdx >= Default.VerbTypes.Length )
		VerbIdx = 0;
	Msg = Default.VerbTypes[VerbIdx].Default.DeathString;

	p = InStr(Msg, "%o");
	if ( p >= 0 )
		Msg = Left(Msg, p) $ RelatedPRI_1.PlayerName $ Mid(Msg, p + 2);
	p = InStr(Msg, "%k");
	if ( p >= 0 )
		Msg = Left(Msg, p) $ KillerName $ Mid(Msg, p + 2);
	return Msg;
}

defaultproperties
{
	VerbTypes(0)=Class'Engine.DamageType'
	VerbTypes(1)=Class'Engine.Crushed'
	VerbTypes(2)=Class'Engine.Gibbed'
	VerbTypes(3)=Class'Engine.Suicided'
}
