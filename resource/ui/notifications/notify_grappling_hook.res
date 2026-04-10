#base "base_notification.res"

"Resource/UI/notifications/notify_grappling_hook.res"
{
	"Notification_Background"
	{
		"wide"			"430"
		"tall"			"138"
		"image"			"../hud/notification_black"
	}

	"Notification_Icon"
	{
		"visible"		"0"
		"enabled"		"0"
	}

	"Notification_Title"
	{
		"font"			"HudFontSmallBold"
		"xpos"			"16"
		"ypos"			"12"
		"wide"			"398"
		"tall"			"22"
		"textAlignment"	"North-West"
		"labelText"		"#TF_Weapon_GrapplingHook"
	}

	"Notification_Body"
	{
		"font"			"TFDefault"
		"xpos"			"16"
		"ypos"			"40"
		"wide"			"398"
		"tall"			"48"
		"textAlignment"	"North-West"
		"labelText"		"#TF_GrapplingHook_EquipAction"
	}

	"Notification_Help"
	{
		"font"			"TFDefaultSmall"
		"xpos"			"16"
		"ypos"			"96"
		"wide"			"398"
		"tall"			"28"
		"textAlignment"	"North-West"
		"labelText"		"Press [ J ] to ACCEPT. Press [ K ] to DECLINE."
	}
}
