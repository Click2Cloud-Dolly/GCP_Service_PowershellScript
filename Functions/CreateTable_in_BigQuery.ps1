Function CreateTable-BigQuery([string]$LogPath, [string]$DataSetName,[string]$TableName, $Concat)
{

    Write-Log $LogPath "Creating table in BigQuery: '$TableName'"
    #        New-BqTable $TableName -DatasetId $DatasetName

    $Concat = $DatasetName+"."+$TableName
    echo "The value of Concat:" $Concat


    echo "location for table:" $Region
    bq mk --location=$Region -t $Concat
    Start-Sleep -Seconds 30

}
