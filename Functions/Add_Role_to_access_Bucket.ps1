Function Configure-Bucket-Access ([string]$LogPath, [string]$Bucket, [string[]]$Roles, [string[]]$ServiceAccountEmails)
{
    Write-Log $LogPath "Adding Roles for Service Accounts to Bucket: '$Bucket'"

    $BucketAccessCreated = $True

    Try {

        $OutputDirectory = Split-Path -Path $LogPath

        $IAMFileGetPath = "$OutputDirectory\BucketIAM_Get.json"
        $IAMFileSetPath = "$OutputDirectory\BucketIAM_Set.json"

        gsutil iam get $Bucket > $IAMFileGetPath

        if($LastExitCode -ne 0) { Throw "Failed to Add Roles for Service Accounts to Bucket: '$Bucket'" }

        $Json = Get-Content $IAMFileGetPath | ConvertFrom-Json

        foreach($Role in $Roles) {

            $Properties = @{

                members = @()
                role = $Role
            }

            $IAM = New-Object psobject -Property $Properties;

            foreach($ServiceAccount in $ServiceAccountEmails) {

                $IAM.Members += "serviceAccount:$ServiceAccount"
            }

            $Json.bindings += $IAM
        }

        $Json | ConvertTo-Json -Depth 5 | Out-File -FilePath $IAMFileSetPath -Encoding ASCII -Force

        $RetryCount = 1
        $RetryMax = 10
        $IAMSuccess = $False

        do {

            try {

                gsutil iam set $IAMFileSetPath $Bucket

                if($LastExitCode -eq 0) {

                    $IAMSuccess = $True
                }
            }
            catch
            {
                Write-Log $LogPath "Failed to Add Roles for Service Accounts to Bucket: '$Bucket', $_"
            }

            if($IAMSuccess -eq $False) {

                Write-Log $LogPath "Failed to Add Roles for Service Accounts to Bucket: '$Bucket', RetryCount: '$RetryCount' - Retrying"

                Start-Sleep -Seconds 20
            }

            $RetryCount = $RetryCount + 1

        } while (($IAMSuccess -eq $False) -and ($RetryCount -le $RetryMax))


        if($IAMSuccess -eq $False) {

            Throw "Exceeded Retry Count when Adding Roles for Service Accounts to Bucket: '$Bucket'"
        }
    }
    catch
    {
        $BucketAccessCreated = $False

        Write-Log $LogPath "Failed to Add Roles for Service Accounts to Bucket: '$Bucket', $_"
    }

    if($BucketAccessCreated) {

        Write-Log $LogPath "Added Roles for Service Accounts to Bucket: '$Bucket'"
    }

    Return $BucketAccessCreated
}
