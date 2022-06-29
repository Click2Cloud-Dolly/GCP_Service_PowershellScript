Function Configure-KMS-Key ([string]$LogPath,[string]$KeyName, [string]$Region)
{
    $Keys = gcloud kms keys list --keyring=$KeyName --location=$Region --format="value(name)"

    if($LastExitCode -ne 0) { Throw "Failed to List Key s" }

    $KeyExists = $false

    Foreach ($Key in $Keys) {

        $Index = $Key.LastIndexOf('/')

        if($Index -gt -1) {

            $ExistingKeyId = $Key.Substring($Index+1)

            if($ExistingKeyId -eq $KeyName) {

                $KeyExists = $true
                break
            }
        }
    }

    if(!$KeyExists) {

        Write-Log $LogPath "Creating Key : '$KeyName', this may take a few minutes"

        Try {

            gcloud kms keys create $KeyName --keyring=$KeyName --location=$Region --purpose=encryption --no-user-output-enabled
        }
        catch
        {
            Throw "Failed to Create Key : '$KeyName', $_"
        }

        if($LastExitCode -ne 0) { Throw "Failed to Create Key : '$KeyName'" }

        Write-Log $LogPath "Created Key : '$KeyName'"

        $KeyUrl = ""

        Try {

            $RetrievedKey = gcloud kms keys describe $KeyName --keyring=$KeyName --location=$Region --format="json" | ConvertFrom-Json

            if($RetrievedKey -ne $null) {

                $KeyUrl = $RetrievedKey.name
            }
        }
        catch
        {
            Throw "Failed to Retrieve Key: '$KeyName', $_"
        }

        if($LastExitCode -ne 0) { Throw "Failed to Retrieve Key: '$KeyName'" }

        Return $KeyUrl
    }
    else {

        Write-Log $LogPath "Key : '$KeyName already exists"

        Throw "Key Already Exists: '$KeyName, Try again with another KeyName"
    }
}
