std = "lua51"
max_line_length = 120

-- the tests run under plain Lua with a fake client of their own
exclude_files = { "tools/**", "dev/**" }

ignore = {
    "122",  -- setting a field on a frame of the game's
}

globals = {
    "FallensFlyoutsDB",
    "FallensFlyouts_AttachDevTools",
    "FallensFlyouts_OnAddonCompartmentClick",
    "SlashCmdList",
    "SLASH_FALLENSFLYOUTS1",
    "SLASH_FALLENSFLYOUTS2",
    "StaticPopupDialogs",
}
