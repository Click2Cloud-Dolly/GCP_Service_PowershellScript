Function Configure-KMS-Key-Access ([string]$LogPath, [string]$KeyName, [string]$Region, [string]$StorageServiceAccountEmail, [string] $Role)
{
    Write-Log $LogPath "Adding Role for Service Account: $StorageServiceAccountEmail to Key: '$KeyName'"

    $KMSKeyAccessSet = $True

    $RetryCount = 1
    $RetryMax = 10
    $IAMSuccess = $False

    do {

        Try {

            gcloud kms keys add-iam-policy-binding $KeyName --keyring=$KeyName --location=$Region --member=serviceAccount:$StorageServiceAccountEmail --role=$Role --no-user-output-enabled

            if($LastExitCode -eq 0) {

                $IAMSuccess = $True
            }
        }
        catch
        {
            Write-Log $LogPath "Failed to add Role: '$Role' for Service Account: '$StorageServiceAccountEmail' to Key: '$KeyName', $_"
        }

        if($IAMSuccess -eq $False) {

            Write-Log $LogPath "Failed to add Role: '$Role' for Service Account: '$StorageServiceAccountEmail' to Key: '$KeyName', RetryCount: '$RetryCount' - Retrying"

            Start-Sleep -Seconds 20
        }

        $RetryCount = $RetryCount + 1

    } while (($IAMSuccess -eq $False) -and ($RetryCount -le $RetryMax))


    if($IAMSuccess -eq $False) {

        $KMSKeyAccessSet = $False

        Write-Log $LogPath "Exceeded Retry Count when adding Role: $Role for Service Account: $StorageServiceAccountEmail to Key: '$KeyName'"
    }

    if($KMSKeyAccessSet) {

        Write-Log $LogPath "Added Role for Service Account: $StorageServiceAccountEmail to Key: '$KeyName'"
    }

    Return $KMSKeyAccessSet
}
