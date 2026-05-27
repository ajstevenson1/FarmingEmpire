--!strict

local OfflineEarningsConfig = {}

OfflineEarningsConfig.maxOfflineSeconds = 12 * 60 * 60
OfflineEarningsConfig.minOfflineSecondsToReward = 5
OfflineEarningsConfig.offlineMultiplierPerOnlineMultiplier = 2
OfflineEarningsConfig.treeToOfflineCiderConversion = 0.25
OfflineEarningsConfig.exponentialCurveStrength = 1.2

OfflineEarningsConfig.plateModelName = "OfflineEarningsPlate"
OfflineEarningsConfig.touchPartName = "Touch"
OfflineEarningsConfig.guiName = "RestockGUI"
OfflineEarningsConfig.nameLabelName = "NameLabel"
OfflineEarningsConfig.earningsLabelName = "OfflineEarnings"
OfflineEarningsConfig.displayNameText = "Offline Earnings"

return table.freeze(OfflineEarningsConfig)
