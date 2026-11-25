class InvasionProPlayerPrefsMenu extends GUICustomPropertyPage;

var() Automated moSlider sl_GibSize;
var() Automated moSlider sl_GibAmount;
var() Automated moSlider sl_InteractionSize;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
	Super.InitComponent(MyController, MyOwner);

	t_WindowTitle.Caption = "Player Preferences";
	sl_GibSize.Setup(0, 10, false);
	sl_GibAmount.Setup(1, 25, true);
	sl_InteractionSize.Setup(0.5, 2.0, false);
	sl_GibSize.SetComponentValue(class'DorianRPGInvServerSettings'.default.GibSize);
	sl_GibAmount.SetComponentValue(class'DorianRPGInvServerSettings'.default.GibAmount);
	sl_InteractionSize.SetComponentValue(class'DorianRPGInvServerSettings'.default.InteractionScale);
}

function bool InternalOnClick(GUIComponent Sender)
{
	if(Sender == b_OK)
	{
		class'DorianRPGInvServerSettings'.default.GibSize = float(sl_GibSize.GetComponentValue());
		class'DorianRPGInvServerSettings'.default.GibAmount = int(sl_GibAmount.GetComponentValue());
		class'DorianRPGInvServerSettings'.default.InteractionScale = float(sl_InteractionSize.GetComponentValue());
		class'DorianRPGInvServerSettings'.static.StaticSaveConfig();
	}

	Controller.CloseMenu(false);
	return true;
}

defaultproperties
{
     Begin Object Class=moSlider Name=GibSizeSlider
         MaxValue=10.000000
         SliderCaptionStyleName="TextLabel"
         Caption="Gib Size Multiplier:"
         OnCreateComponent=GibSizeSlider.InternalOnCreateComponent
         Hint="Scales monster gibs from 0x to 10x. Client only."
         WinTop=0.200000
         WinLeft=0.100000
         WinWidth=0.800000
         WinHeight=0.060000
         TabOrder=1
         bBoundToParent=True
         bScaleToParent=True
     End Object
     sl_GibSize=moSlider'InvasionProv1_7modV1.InvasionProPlayerPrefsMenu.GibSizeSlider'

     Begin Object Class=moSlider Name=GibAmountSlider
         MaxValue=25.000000
         SliderCaptionStyleName="TextLabel"
         Caption="Gib Amount Multiplier:"
         OnCreateComponent=GibAmountSlider.InternalOnCreateComponent
         Hint="Multiplies the number of monster gibs from 1x to 25x. Client only."
         WinTop=0.320000
         WinLeft=0.100000
         WinWidth=0.800000
         WinHeight=0.060000
         TabOrder=2
         bBoundToParent=True
         bScaleToParent=True
     End Object
     sl_GibAmount=moSlider'InvasionProv1_7modV1.InvasionProPlayerPrefsMenu.GibAmountSlider'

     Begin Object Class=moSlider Name=InteractionSizeSlider
         MaxValue=2.000000
         MinValue=0.500000
         SliderCaptionStyleName="TextLabel"
         Caption="Interaction Text/Bar Size:"
         OnCreateComponent=InteractionSizeSlider.InternalOnCreateComponent
         Hint="Scales the monster and teammate health bars and text from 0.5x to 2x. Client only."
         WinTop=0.440000
         WinLeft=0.100000
         WinWidth=0.800000
         WinHeight=0.060000
         TabOrder=3
         bBoundToParent=True
         bScaleToParent=True
     End Object
     sl_InteractionSize=moSlider'InvasionProv1_7modV1.InvasionProPlayerPrefsMenu.InteractionSizeSlider'

     Begin Object Class=GUIButton Name=CancelButton
         Caption="Cancel"
         Hint="Click this button to close without saving."
         WinTop=0.573362
         WinLeft=0.627835
         WinWidth=0.178488
         WinHeight=0.094359
         TabOrder=9
         bBoundToParent=True
         bScaleToParent=True
         OnClick=InvasionProPlayerPrefsMenu.InternalOnClick
         OnKeyEvent=CancelButton.InternalOnKeyEvent
     End Object
     b_Cancel=GUIButton'InvasionProv1_7modV1.InvasionProPlayerPrefsMenu.CancelButton'

     Begin Object Class=GUIButton Name=OkButton
         Caption="Save"
         Hint="Click this button to save your player preferences."
         WinTop=0.573362
         WinLeft=0.242109
         WinWidth=0.178488
         WinHeight=0.094359
         TabOrder=8
         bBoundToParent=True
         bScaleToParent=True
         OnClick=InvasionProPlayerPrefsMenu.InternalOnClick
         OnKeyEvent=OkButton.InternalOnKeyEvent
     End Object
     b_OK=GUIButton'InvasionProv1_7modV1.InvasionProPlayerPrefsMenu.OkButton'

     bRequire640x480=False
     bAllowedAsLast=True
     WinTop=0.078000
     WinLeft=0.010000
     WinWidth=0.724674
     WinHeight=0.659765
     bScaleToParent=True
}
