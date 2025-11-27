local M = {}
local job_id = nil

-- Default configuration
local config = {
	theme = nil, -- Fallback theme (used if specific light/dark not set)
	dark_theme = nil, -- Specific theme for dark mode
	light_theme = nil, -- Specific theme for light mode
}

-- Helper: Determine which colorscheme name to use
local function get_target_scheme(mode)
	if mode == "dark" and config.dark_theme then
		return config.dark_theme
	elseif mode == "light" and config.light_theme then
		return config.light_theme
	else
		return config.theme
	end
end

-- Core Logic: Apply the changes
local function apply(mode)
	-- 1. Always set the background (vital for single-theme setups)
	vim.o.background = mode

	if mode == "dark" and config.dark_theme then
		vim.cmd("colorscheme " .. config.dark_theme)
	elseif mode == "light" and config.light_theme then
		vim.cmd("colorscheme " .. config.light_theme)
	end
end

-- Job Handler: Process gsettings output
local function on_event(_, data, _)
	local output = table.concat(data, "")
	-- Clean whitespace
	output = output:gsub("%s+", "")

	vim.schedule(function()
		if string.find(output, "dark") then
			vim.o.background = "dark"
		else
			vim.o.background = "light"
		end
	end)
end

function M.setup(user_opts)
	-- Merge user config
	config = vim.tbl_deep_extend("force", config, user_opts or {})

	-- Sanity check: is gsettings installed?
	if vim.fn.executable("gsettings") == 0 then
		vim.notify("gnome-theme: gsettings not found. Auto-switching disabled.", vim.log.levels.WARN)
		return
	end

	-- 1. INITIAL STATE: Get current setting synchronously
	local initial_mode = "light" -- Default assumption
	local current_sys = vim.fn.system("gsettings get org.gnome.desktop.interface color-scheme")

	if current_sys and string.find(current_sys, "dark") then
		initial_mode = "dark"
	end

	local theme_name = get_target_scheme(initial_mode)
	if theme_name then
		vim.cmd("colorscheme " .. theme_name)
	end
	apply(initial_mode)

	-- 2. MONITOR: Start background job
	if job_id then
		vim.fn.jobstop(job_id)
	end

	job_id = vim.fn.jobstart({ "gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme" }, {
		on_stdout = on_event,
		on_stderr = function() end,
		detach = true,
	})
end

return M
