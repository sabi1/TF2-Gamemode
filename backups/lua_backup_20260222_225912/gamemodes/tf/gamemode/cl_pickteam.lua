
function TeamSelection()
	-- Legacy fallback command now routes to the new TF2-style team select panel.
	RunConsoleCommand("tf_open_teamselect")
end


concommand.Add("tf_changeteam", TeamSelection)
