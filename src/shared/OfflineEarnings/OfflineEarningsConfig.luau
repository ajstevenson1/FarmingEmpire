--!strict

local OfflineEarningsConfig = {}

OfflineEarningsConfig.maxOfflineSeconds = 72 * 60 * 60
OfflineEarningsConfig.minOfflineSecondsToReward = 5

OfflineEarningsConfig.plateModelName = "OfflineEarningsPlate"
OfflineEarningsConfig.touchPartName = "Touch"
OfflineEarningsConfig.guiName = "RestockGUI"
OfflineEarningsConfig.nameLabelName = "NameLabel"
OfflineEarningsConfig.earningsLabelName = "OfflineEarnings"
OfflineEarningsConfig.displayNameText = "Offline Earnings"

return table.freeze(OfflineEarningsConfig)
