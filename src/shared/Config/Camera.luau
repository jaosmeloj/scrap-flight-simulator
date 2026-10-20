--!strict
-- Camera placement (studs). At the top of the ramp and at the launch the camera is put behind the cart, looking
-- down the ramp (the launch axis is world +X); the player can still turn it afterwards.
local Camera = {
	Back = 22, -- behind the cart (toward -X)
	Up = 10, -- above the cart
	LookAhead = 18, -- the point it looks at, in front of the cart
	LookUp = 2,
}

return Camera
