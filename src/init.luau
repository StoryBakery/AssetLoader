--[[
	AssetLoader 모듈은 이미지 에셋의 로딩과 언로딩을 소비자 수 기반으로 관리합니다.
	여러 AssetLoader 인스턴스가 동일한 이미지 에셋을 참조할 수 있으며,
	전체 소비자 수에 따라 실제 이미지 로딩(ImageLabel 생성) 및 해제(ImageLabel 파괴)가 이루어집니다.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Maid = require("../roblox_packages/Maid") -- Maid 모듈의 경로를 알맞게 수정해주세요.

local imageLayerCollector = Instance.new("ScreenGui") do
	imageLayerCollector.DisplayOrder = -2^31
	imageLayerCollector.IgnoreGuiInset = true
end

if RunService:IsStudio() and RunService:IsRunning() then
	imageLayerCollector.Parent = nil -- game:GetService("CoreGui")
else
	imageLayerCollector.Parent = Players.LocalPlayer.PlayerGui
end

local AssetLoader = {}
AssetLoader.__index = AssetLoader
AssetLoader.__type = "AssetLoader"

local consumerCountsByAssetId = {} :: { [string]: number }
local loadedImageLabelsById = {} :: { [string]: ImageLabel }

local imagePreloadContainer

local function loadImageGlobally(imageId: string)
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = imageId
	imageLabel.Image = imageId
	imageLabel.Size = UDim2.fromOffset(1, 1)
	imageLabel.BackgroundTransparency = 1
	imageLabel.ImageTransparency = 1
	imageLabel.Parent = imageLayerCollector

	loadedImageLabelsById[imageId] = imageLabel
end

local function unloadImageGlobally(imageId: string)
	local imageLabel = loadedImageLabelsById[imageId]
	imageLabel:Destroy()
	loadedImageLabelsById[imageId] = nil
end

--#region Constructors

export type AssetLoader = typeof(setmetatable({} :: {
	IsDestroyed: boolean,
	Maid: Maid.Maid,
	
	ImageIdSet: {[string]: true},
}, AssetLoader))

export type AssetLoaderParams = {
	ImageIds: { string }?,
}
function AssetLoader.new(params: AssetLoaderParams?): AssetLoader
	local self = setmetatable({}, AssetLoader)

	self.IsDestroyed = false
	self.Maid = Maid.new()
	self.ImageIdSet = {} :: { [string]: true }

	if params and params.ImageIds then
		self:LoadImageIds(params.ImageIds)
	end

	return self
end

--#region Methods

-- AssetLoader 인스턴스를 파괴하고, 관리하던 모든 이미지의 소비자 수를 감소시킵니다.
function AssetLoader:Destroy()
	if self.IsDestroyed then
		return
	end
	self.IsDestroyed = true

	-- 이 로더가 소비하던 모든 이미지에 대해 소비 중단 처리
	local idsToUnload = {}
	for imageId, _ in self.ImageIdSet do
		self:UnloadImageId(imageId)
	end

	table.clear(self.ImageIdSet)

	self.Maid:Destroy()
end

function AssetLoader:LoadImageId(imageId: string)
	if self.IsDestroyed then
		return
	end

	-- 이미 이 로더 인스턴스가 해당 ID를 관리 중이면 중복 로드 방지
	if self.ImageIdSet[imageId] then
		return
	end

	self.ImageIdSet[imageId] = true

	local currentGlobalConsumers = consumerCountsByAssetId[imageId] or 0
	consumerCountsByAssetId[imageId] = currentGlobalConsumers + 1

	if consumerCountsByAssetId[imageId] == 1 then
		-- 첫 번째 소비자일 경우 전역적으로 이미지 로드
		loadImageGlobally(imageId)
	end
end

-- 여러 이미지 ID들을 로드합니다.
function AssetLoader:LoadImageIds(imageIds: { string })
	if self.IsDestroyed then
		return
	end
	
	for _, imageId in ipairs(imageIds) do
		self:LoadImageId(imageId)
	end
end

-- 특정 이미지 ID를 이 AssetLoader 인스턴스의 관리 목록에서 제거하고, 전역 소비자 수를 업데이트합니다.
function AssetLoader:UnloadImageId(imageId: string)
	if self.IsDestroyed then
		return
	end
	
	if not self.ImageIdSet[imageId] then
		return
	end

	self.ImageIdSet[imageId] = nil

	local currentGlobalConsumers = consumerCountsByAssetId[imageId]
	if currentGlobalConsumers then
		consumerCountsByAssetId[imageId] = currentGlobalConsumers - 1
		if consumerCountsByAssetId[imageId] <= 0 then
			unloadImageGlobally(imageId)
			consumerCountsByAssetId[imageId] = nil 
		end
	end
end

-- 여러 이미지 ID들을 언로드합니다.
function AssetLoader:UnloadImageIds(imageIds: { string })
	if self.IsDestroyed then
		return
	end
	for _, imageId in ipairs(imageIds) do
		self:UnloadImageId(imageId)
	end
end

return AssetLoader

