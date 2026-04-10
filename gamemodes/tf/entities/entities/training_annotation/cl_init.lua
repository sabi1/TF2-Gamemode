local ACTIVE_ANNOTATIONS = ACTIVE_ANNOTATIONS or {}

net.Receive("TF_TrainingAnnotationShow", function()
	local id = net.ReadUInt(16)
	local text = net.ReadString()
	local pos = net.ReadVector()
	local lifetime = math.max(0, net.ReadFloat())

	ACTIVE_ANNOTATIONS[id] = {
		Text = text,
		Pos = pos,
		ExpireTime = CurTime() + lifetime,
	}
end)

net.Receive("TF_TrainingAnnotationHide", function()
	local id = net.ReadUInt(16)
	ACTIVE_ANNOTATIONS[id] = nil
end)

hook.Add("HUDPaint", "TF_TrainingAnnotationsHUD", function()
	local now = CurTime()

	for id, annotation in pairs(ACTIVE_ANNOTATIONS) do
		if not annotation or now >= (annotation.ExpireTime or 0) then
			ACTIVE_ANNOTATIONS[id] = nil
		else
			local screen = annotation.Pos:ToScreen()
			if screen.visible then
				draw.SimpleTextOutlined(
					annotation.Text or "",
					"HudFontSmallBold",
					screen.x,
					screen.y,
					Color(255, 235, 170),
					TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER,
					1,
					Color(40, 24, 12, 220)
				)
			end
		end
	end
end)
