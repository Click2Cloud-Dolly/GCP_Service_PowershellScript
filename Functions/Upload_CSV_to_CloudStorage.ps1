Function Upload-CSV-To-CloudStorage([string]$LogPath, [string]$BucketName, [string]$CSVFolderPath)
{
    Write-Log $LogPath "Uploading dataset into cloud: '$BucketName'"

    if($BucketName -ne 0) {
        Write-Log $LogPath "Uploading CSV: '$BucketName', this may take a few minutes"

        try
        {
            Write-Log $LogPath "The value of CSVFOLDER: '$CSVFolderPath'"

            New-GcsObject -Bucket $BucketName -Folder $CSVFolderPath
            Start-Sleep -Seconds 30
        }
        catch
        {
            Throw "Failed to Upload csv in bucket: '$BucketName', $_"
        }
    }
    else{

        Write-Log $LogPath "Bucket: '$BucketName' Not Exists"
    }
}
