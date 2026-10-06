-- Shared client state.
return {
	profile = nil, -- server profile snapshot
	phase = nil, -- current match phase payload (nil in lobby)
	pad = nil, -- pad status while standing on a lobby pad
	inRange = false, -- inside the lobby firing range
	holding = false, -- weapons out (in a match or in the range)
	slot = 1,
	ads = false,
	scoped = false,
	sliding = false,
	dashing = false,
	dashReadyAt = 0,
	menuOpen = false,
	weaponId = nil,
	ammo = 0,
	mag = 0,
	reloading = false,
}
