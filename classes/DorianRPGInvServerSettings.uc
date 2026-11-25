//Client-side player preferences, saved to DorianRPGInvServerSettings.ini.
//Written by the Player Preferences menu and read by the InvasionPro HUD and TitanRPG.
class DorianRPGInvServerSettings extends Object config(DorianRPGInvServerSettings);

var config float GibSize;           //gib size multiplier, 0-10
var config int GibAmount;           //gib amount multiplier, 1-25 (1 = normal amount)
var config float InteractionScale;  //TitanRPG monster and teammate text/bar size, 0.5-2

defaultproperties
{
	GibSize=1.000000
	GibAmount=1
	InteractionScale=1.000000
}
