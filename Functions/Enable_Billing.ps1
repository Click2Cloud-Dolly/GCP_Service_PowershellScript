Function Enable-Billing([string]$LogPath, [string]$ProjectId, [string]$BillingAccount)
{

    Write-Log $LogPath "Value of Account Id:'$BillingAccount'"

    Write-Log $LogPath "Enable Billing for project:'$ProjectId'"

    gcloud beta billing projects link $ProjectId --billing-account=$BillingAccount
    # 016431-5BB3C4-4BE6C6

}
