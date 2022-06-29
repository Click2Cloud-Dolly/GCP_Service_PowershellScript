Function Configure-ServiceAccount-Key ([string]$LogPath, [string]$ProjectId, [string]$ServiceAccountId, [string]$ServiceAccountKeyType, [string]$OutputPath)
{
    $ServiceAccountKeyPath = ""

    $ServiceAccountEmail = Get-Service-Account $ProjectId $ServiceAccountId

    Write-Log $LogPath "Creating Service Account Key for: '$ServiceAccountId'"

    Try {

        $ServiceAccountKeyPath = "$($OutputPath)\$($ServiceAccountId)_key.$($ServiceAccountKeyType)"

        gcloud iam service-accounts keys create $ServiceAccountKeyPath --iam-account=$ServiceAccountEmail --key-file-type=$ServiceAccountKeyType --no-user-output-enabled
    }
    catch
    {
        Throw "Failed to Create Service Account Key: '$ServiceAccountId', $_"
    }

    if($LastExitCode -ne 0) { Throw "Failed to Create Service Account Key: '$ServiceAccountId'" }

    Write-Log $LogPath "Created Service Account Key for: '$ServiceAccountId'"

    Return $ServiceAccountKeyPath
}
