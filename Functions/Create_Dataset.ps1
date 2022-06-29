Function CreateDataset([string]$LogPath, [string]$ProjectId, [string]$DataSetName)
{
    Write-Log $LogPath "Set Project for: '$ProjectId'"
    gcloud config set project $ProjectId

    Write-Log $LogPath "Creating dataset in BigQuery: '$DatasetName'"
    #        New-BqDataset $DataSetName

    echo "Location for dataset:" $Region
    bq mk --location=$Region -d $DatasetName
    Start-Sleep -Seconds 30

}
