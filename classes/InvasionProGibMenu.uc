class InvasionProGibMenu extends GUICustomPropertyPage;

var() Automated moSlider sl_GibSize;
var() Automated moSlider sl_GibAmount;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
	Super.InitComponent(MyController, MyOwner);

	t_WindowTitle.Caption = "Gib Preferences";
	sl_GibSize.Setup(0, 10, false);
	sl_GibAmount.Setup(1, 25, true);
	sl_GibSize.SetComponentValue(class'InvasionProModHud'.default.GibSize);
	sl_GibAmount.SetComponentValue(class'InvasionProModHud'.default.GibAmount);
}

function bool InternalOnClick(GUIComponent Sender)
{
	if(Sender == b_OK)
	{
		class'InvasionProModHud'.default.GibSize = float(sl_GibSize.GetComponentValue());
		class'InvasionProModHud'.default.GibAmount = int(sl_GibAmount.GetComponentValue());
		class'InvasionProModHud'.static.StaticSaveConfig();
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
     sl_GibSize=moSlider'InvasionProv1_7modV1.InvasionProGibMenu.GibSizeSlider'

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
     sl_GibAmount=moSlider'InvasionProv1_7modV1.InvasionProGibMenu.GibAmountSlider'

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
         OnClick=InvasionProGibMenu.InternalOnClick
         OnKeyEvent=CancelButton.InternalOnKeyEvent
     End Object
     b_Cancel=GUIButton'InvasionProv1_7modV1.InvasionProGibMenu.CancelButton'

     Begin Object Class=GUIButton Name=OkButton
         Caption="Save"
         Hint="Click this button to save your gib preferences."
         WinTop=0.573362
         WinLeft=0.242109
         WinWidth=0.178488
         WinHeight=0.094359
         TabOrder=8
         bBoundToParent=True
         bScaleToParent=True
         OnClick=InvasionProGibMenu.InternalOnClick
         OnKeyEvent=OkButton.InternalOnKeyEvent
     End Object
     b_OK=GUIButton'InvasionProv1_7modV1.InvasionProGibMenu.OkButton'

     bRequire640x480=False
     bAllowedAsLast=True
     WinTop=0.078000
     WinLeft=0.010000
     WinWidth=0.724674
     WinHeight=0.659765
     bScaleToParent=True
}
