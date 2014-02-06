--------------------------------------------------------------------------------
--[[
Dusk Engine Component: Tile Culling

Manages displayed tiles for tile layers in a map.
--]]
--------------------------------------------------------------------------------

local tileculling = {}

--------------------------------------------------------------------------------
-- Localize
--------------------------------------------------------------------------------
local require = require

local editQueue = require("Dusk.dusk_core.misc.editqueue")
local screen = require("Dusk.dusk_core.misc.screen")

local newEditQueue = editQueue.new
local math_abs = math.abs
local math_ceil = math.ceil

--------------------------------------------------------------------------------
-- Add Tile Culling to a Map
--------------------------------------------------------------------------------
function tileculling.addTileCulling(map)
	local divTileWidth, divTileHeight = 1 / map.data.tileWidth, 1 / map.data.tileHeight

	local culling = {
		layer = {}
	}

	------------------------------------------------------------------------------
	-- Load Layers
	------------------------------------------------------------------------------
	for layer, i in map.tileLayers() do
		if layer.tileCullingEnabled then
			local layerCulling = {
				prev = {l = 0, r = 0, t = 0, b = 0},
				now = {l = 0, r = 0, t = 0, b = 0},
				update = function() end -- Make simple placeholder to keep from rehashing - every little bit of speed gain counts!
			}

			local layerEdits = newEditQueue()
			layerEdits.setTarget(layer)

			--------------------------------------------------------------------------
			-- Update Culling
			--------------------------------------------------------------------------
			layerCulling.update = function()
				local nl, nr, nt, nb = layerCulling.updatePositions()
				local pl, pr, pt, pb = layerCulling.prev.l, layerCulling.prev.r, layerCulling.prev.t, layerCulling.prev.b

				-- Difference between current positions and previous positions
				-- This is used to tell which direction the layer has moved
				local lDiff = nl - pl
				local rDiff = nr - pr
				local tDiff = nt - pt
				local bDiff = nb - pb

				if lDiff > 0 then
					layerEdits.add(pl, nl, pt, pb, "er")
				elseif lDiff < 0 then
					layerEdits.add(pl, nl, nt, nb, "dr")
				end

				if rDiff < 0 then
					layerEdits.add(pr, nr, pt, pb, "el")
				elseif rDiff > 0 then
					layerEdits.add(pr, nr, nt, nb, "dl")
				end

				if tDiff > 0 then
					layerEdits.add(nl, nr, pt, layerCulling.now.t, "eb")
				elseif tDiff < 0 then
					layerEdits.add(nl, nr, pt, layerCulling.now.t, "db")
				end

				if bDiff < 0 then
					layerEdits.add(nl, nr, pb, layerCulling.now.b, "et")
				elseif bDiff > 0 then
					layerEdits.add(nl, nr, pb, layerCulling.now.b, "dt")
				end

				--[[
				-- Guard against tile "leaks"
				if lDiff > 0 and tDiff > 0 then
					layerEdits.add(pl, nl, pt, nt, "e")
				end

				if rDiff < 0 and tDiff > 0 then
					layerEdits.add(nr, pr, pt, nt, "e")
				end

				if lDiff > 0 and bDiff < 0 then
					layerEdits.add(pl, nl, nb, pb, "e")
				end

				if rDiff < 0 and bDiff < 0 then
					layerEdits.add(nr, pr, nb, pb, "e")
				end
				--]]

				layerEdits.execute()
			end

			--------------------------------------------------------------------------
			-- Update Positions
			--------------------------------------------------------------------------
			layerCulling.updatePositions = function()
				local l, t = layer:contentToLocal(screen.left, screen.top)
				local r, b = layer:contentToLocal(screen.right, screen.bottom)

				-- Calculate left/right/top/bottom to the nearest tile
				-- We expand each position by one to hide the drawing and erasing
				l = math_ceil(l * divTileWidth) + 1
				r = math_ceil(r * divTileWidth) - 1
				t = math_ceil(t * divTileHeight) + 1
				b = math_ceil(b * divTileHeight) - 1

				-- Update previous position to be equal to current position
				-- Don't create a new table because overwriting the previous one is faster
				layerCulling.prev.l = layerCulling.now.l
				layerCulling.prev.r = layerCulling.now.r
				layerCulling.prev.t = layerCulling.now.t
				layerCulling.prev.b = layerCulling.now.b
				
				-- Reset current position
				layerCulling.now.l = l
				layerCulling.now.r = r
				layerCulling.now.t = t
				layerCulling.now.b = b

				return l, r, t, b
			end


			layer._updateTileCulling = layerCulling.update

			culling.layer[i] = layerCulling
		end
	end

	return culling
end

return tileculling