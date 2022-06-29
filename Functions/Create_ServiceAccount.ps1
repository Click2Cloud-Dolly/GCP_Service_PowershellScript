Function Configure-ServiceAccount ([string]$LogPath, [string]$ProjectId, [string]$ServiceAccountId)
{
    $ServiceAccounts = gcloud iam service-accounts list --format="value(name)"

    if($LastExitCode -ne 0) { Throw "Failed to List Service Accounts" }

    $ServiceAccountExists = $false

    Foreach ($ServiceAccount in $ServiceAccounts) {

        $Index = $ServiceAccount.LastIndexOf('/')

        if($Index -gt -1) {

            $ExistingServiceAccountId = $ServiceAccount.Substring($Index+1)

            if($ExistingServiceAccountId.StartsWith($ServiceAccountId)) {

                $ServiceAccountExists = $true
                break
            }
        }
    }

    if(!$ServiceAccountExists) {

        $ServiceAccountEmail = Get-Service-Account $ProjectId $ServiceAccountId

        Write-Log $LogPath "Creating Service Account: '$ServiceAccountId', this may take a few minutes"

        Try {

            gcloud iam service-accounts create $ServiceAccountId --display-name="'$ServiceAccountId'" --project=$ProjectId --no-user-output-enabled

            Start-Sleep -Seconds 30
        }
        catch
        {
            Throw "Failed to Create Service Account: '$ServiceAccountId', $_"
        }

        if($LastExitCode -ne 0) { Throw "Failed to Create Service Account: '$ServiceAccountId'" }

        Write-Log $LogPath "Created Service Account: '$ServiceAccountId'"

    }
    else {

        Write-Log $LogPath "Service Account: '$ServiceAccountId' already exists"

        Throw "Service Account Already Exists: '$ServiceAccountId', Try again with another Account Id"
    }
}
