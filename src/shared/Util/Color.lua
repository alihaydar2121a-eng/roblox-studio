-- Converts {r, g, b} config triples to Color3.
return function(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
