local runtimeTexture = "customPlates"
local vehShare = "vehshare"
local plateTxd = CreateRuntimeTxd(runtimeTexture)

for plateIndex, _ in pairs({ 1, 2, 3, 4, 5 }) do
	local plateName = "plate0" .. plateIndex
	local plateNormal = "plate0" .. plateIndex .. "_n"

	CreateRuntimeTextureFromImage(plateTxd, plateName, "customplates/streetkings.png")
	AddReplaceTexture(vehShare, plateName, runtimeTexture, plateName)

    CreateRuntimeTextureFromImage(plateTxd, plateNormal, "customplates/customnormal.png")
    AddReplaceTexture(vehShare, plateNormal, runtimeTexture, plateNormal)
end