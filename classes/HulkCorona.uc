//=======================================================
// HulkCorona - red glow sprite attached to a hulked
// monster so it reads clearly at a distance. All
// visuals live in defaultproperties (class defaults are
// applied on clients too when the actor replicates);
// only the scale is driven server-side (DrawScale is a
// replicated property).
//=======================================================
class HulkCorona extends Actor;

defaultproperties
{
	DrawType=DT_Sprite
	Texture=Texture'XEffectMat.Link.link_muz_red'
	Style=STY_Translucent
	bUnlit=True
	AmbientGlow=255
	ScaleGlow=2.0
	DrawScale=3.0
	bReplicateMovement=True
	RemoteRole=ROLE_SimulatedProxy
	bStatic=False
	bNoDelete=False
	bCollideActors=False
	bCollideWorld=False
}
