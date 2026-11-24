class InvasionProHulkMessage extends CriticalEventPlus;

static function DrawPart(Canvas C, out float X, float Y, string Text, color Col)
{
	local float W, H;

	C.DrawColor = Col;
	C.SetPos(X, Y);
	C.DrawText(Text);
	C.TextSize(Text, W, H);
	X += W;
}

static function RenderComplexMessage(
	Canvas Canvas,
	out float XL,
	out float YL,
	optional String MessageString,
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	local color BaseColor, RedCol;
	local float X, Y;
	local int Pos;

	BaseColor = default.DrawColor;
	BaseColor.A = Canvas.DrawColor.A;

	RedCol.R = 255;
	RedCol.G = 0;
	RedCol.B = 0;
	RedCol.A = BaseColor.A;

	X = Canvas.CurX;
	Y = Canvas.CurY;

	//the server sends "A <name> has become enraged!"; only the word enraged is red
	Pos = InStr(MessageString, "enraged");
	if ( Pos < 0 )
	{
		DrawPart(Canvas, X, Y, MessageString, BaseColor);
		return;
	}
	DrawPart(Canvas, X, Y, Left(MessageString, Pos), BaseColor);
	DrawPart(Canvas, X, Y, "enraged", RedCol);
	DrawPart(Canvas, X, Y, Mid(MessageString, Pos + 7), BaseColor);
}

static function string GetString(
	optional int Switch,
	optional PlayerReplicationInfo RelatedPRI_1,
	optional PlayerReplicationInfo RelatedPRI_2,
	optional Object OptionalObject
	)
{
	return "A "$class'MonsterNameTable'.static.GetDisplayName(class<Monster>(OptionalObject))$" has become enraged!";
}

defaultproperties
{
	bIsSpecial=True
	bComplexString=True
	StackMode=SM_Down
	PosY=0.220000
}
