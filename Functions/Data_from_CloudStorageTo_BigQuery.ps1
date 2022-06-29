Function CloudStorage-To-BigQuery([string]$LogPath, [string]$Region, [string]$DatasetName, [string]$TableName)
{
    Write-Log $LogPath "Loading dataset of CloudStorage-To-BigQuery: '$TableName'"

    $Concat2 = $DatasetName+"."+$TableName
    echo "The value of Concat:" $Concat2

    echo "location for table:" $Region
    bq --location=$Region load --autodetect --source_format=CSV $Concat2 gs://$BucketName/tempcsv/*.csv
    Start-Sleep -Seconds 30
}
