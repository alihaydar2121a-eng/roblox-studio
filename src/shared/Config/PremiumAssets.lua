--[[
	PremiumAssets
	Hand-modelled Blender assets (assets/premium/…, built by
	scripts/blender/premium/build_premium.py) and where each imported model
	lives in the place. The Ironfront Tools plugin's "Install Assets" button
	uses this table to move 3D-Importer output into
	ReplicatedStorage.ImportedAssets, where WeaponRig / UniformService find it.

	Model   name of the model the 3D Importer creates (= the FBX/GLB file name)
	Path    destination under ReplicatedStorage.ImportedAssets
	Size    expected bounding box in studs (x, y, z) — used to catch a wrong
	        import unit and rescale automatically
	Parts   MeshParts the runtime relies on (warned about when missing)
]]

local PremiumAssets = {}

PremiumAssets.List = {
	{
		Model = "IR7",
		Path = { "Weapons", "CB" },
		Size = { 0.325, 1.238, 2.98 },
		Parts = {
			"Origin", "IR7_accent", "IR7_dark", "IR7_glass_optic", "IR7_gunmetal", "IR7_metal",
			"IR7_olive_mag", "IR7_polymer", "IR7_receiver", "IR7_receiver_optic", "IR7_rubber",
		},
	},
	{
		Model = "Ashford_Head",
		Path = { "Gear", "Alpha", "Head" },
		Size = { 1.485, 1.289, 1.669 },
		Parts = {
			"Origin", "Ashford_Head_band", "Ashford_Head_camoA_v_cover", "Ashford_Head_helmet", "Ashford_Head_helmetDark", "Ashford_Head_helmetDark_v_goggles",
			"Ashford_Head_helmetDark_v_headset", "Ashford_Head_lens_v_goggles", "Ashford_Head_metal", "Ashford_Head_strap", "Ashford_Head_strap_v_cover", "Ashford_Head_strap_v_goggles",
		},
	},
	{
		Model = "Ashford_Torso",
		Path = { "Gear", "Alpha", "Torso" },
		Size = { 2.122, 2.761, 2.099 },
		Parts = {
			"Origin", "Ashford_Torso_band", "Ashford_Torso_camoB", "Ashford_Torso_camoB_v_bedroll", "Ashford_Torso_cloth", "Ashford_Torso_helmetDark",
			"Ashford_Torso_helmetDark_v_antenna", "Ashford_Torso_metal", "Ashford_Torso_pack", "Ashford_Torso_plate", "Ashford_Torso_pouch", "Ashford_Torso_strap",
			"Ashford_Torso_strap_v_bedroll", "Ashford_Torso_vest",
		},
	},
	{
		Model = "Ashford_Arm",
		Path = { "Gear", "Alpha", "Arm" },
		Size = { 1.168, 2.055, 1.14 },
		Parts = {
			"Origin", "Ashford_Arm_band", "Ashford_Arm_cloth", "Ashford_Arm_glove", "Ashford_Arm_knee", "Ashford_Arm_strap",
		},
	},
	{
		Model = "Ashford_Arm_L",
		Path = { "Gear", "Alpha", "Arm_L" },
		Size = { 1.168, 2.055, 1.14 },
		Parts = {
			"Origin", "Ashford_Arm_L_band", "Ashford_Arm_L_cloth", "Ashford_Arm_L_glove", "Ashford_Arm_L_knee", "Ashford_Arm_L_strap",
		},
	},
	{
		Model = "Ashford_Leg",
		Path = { "Gear", "Alpha", "Leg" },
		Size = { 1.204, 2.035, 1.282 },
		Parts = {
			"Origin", "Ashford_Leg_boot", "Ashford_Leg_cloth", "Ashford_Leg_knee", "Ashford_Leg_metal", "Ashford_Leg_sole",
			"Ashford_Leg_strap",
		},
	},
	{
		Model = "Ashford_Leg_L",
		Path = { "Gear", "Alpha", "Leg_L" },
		Size = { 1.205, 2.035, 1.282 },
		Parts = {
			"Origin", "Ashford_Leg_L_boot", "Ashford_Leg_L_cloth", "Ashford_Leg_L_knee", "Ashford_Leg_L_metal", "Ashford_Leg_L_sole",
			"Ashford_Leg_L_strap",
		},
	},
}

function PremiumAssets.find(modelName)
	local lower = string.lower(modelName)
	for _, entry in ipairs(PremiumAssets.List) do
		if string.lower(entry.Model) == lower then
			return entry
		end
	end
	return nil
end

return PremiumAssets
