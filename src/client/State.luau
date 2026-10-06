-- Shared client state.
return {
	profile = nil, -- server profile snapshot
	phase = nil, -- current match phase payload (nil in lobby)
	queue = nil, -- queued mode name
	queuedAt = 0,
	lastMode = nil, -- last queued mode, for auto-requeue
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
