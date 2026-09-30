--[[
	ReplicatedFirst loading notice (Rojo-managed: src/first).
	Shows a small "Loading" card while the place streams in, then fades out.
	Purely cosmetic; gameplay UI is built by StarterPlayerScripts.Client.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local gui = Instance.new("ScreenGui")
gui.Name = "IronfrontLoading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
frame.Parent = gui

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.5)
label.Size = UDim2.fromOffset(420, 60)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 26
label.TextColor3 = Color3.fromRGB(214, 206, 176)
label.Text = "OPERATION IRONFRONT — deploying…"
label.Parent = frame

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait(0.5)
local info = TweenInfo.new(0.6)
TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(label, info, { TextTransparency = 1 }):Play()
task.wait(0.7)
gui:Destroy()
