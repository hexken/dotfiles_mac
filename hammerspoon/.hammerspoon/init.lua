-- Watch specifically for Netskope Client windows
local netskopeFilter = hs.window.filter.new("Netskope Client")

netskopeFilter:subscribe(hs.window.filter.windowCreated, function(win)
	-- Slight delay (20ms) to ensure UI hierarchy is mounted
	hs.timer.doAfter(0.02, function()
		local app = hs.application.get("Netskope Client")
		if not app then
			return
		end

		local axApp = hs.axuielement.applicationElement(app)
		if not axApp then
			return
		end

		-- Scan for and click the "Accept" button
		local function findAndClickAccept(element)
			if element.AXRole == "AXButton" and element.AXTitle == "Accept" then
				element:performAction("AXPress")
				return true
			end
			for _, child in ipairs(element or {}) do
				if findAndClickAccept(child) then
					return true
				end
			end
			return false
		end

		findAndClickAccept(axApp)
	end)
end)
