Function Configure-KMS-KeyRing ([string]$LogPath, [string]$KeyName, [string]$Region)
{
    $KeyRings = gcloud kms keyrings list --location=$Region --format="value(name)"

    if($LastExitCode -ne 0) { Throw "Failed to List Key Rings" }

    $KeyRingExists = $false

    Foreach ($KeyRing in $KeyRings) {

        $Index = $KeyRing.LastIndexOf('/')

        if($Index -gt -1) {

            $ExistingKeyRingId = $KeyRing.Substring($Index+1)

            if($ExistingKeyRingId -eq $KeyName) {

                $KeyRingExists = $true
                break
            }
        }
    }

    if(!$KeyRingExists) {

        Write-Log $LogPath "Creating Key Ring: '$KeyName', this may take a few minutes"

        Try {

            gcloud kms keyrings create $KeyName --location=$Region --no-user-output-enabled

        }
        catch
        {
            Throw "Failed to Create Key Ring: '$KeyName', $_"
        }

        if($LastExitCode -ne 0) { Throw "Failed to Create Key Ring: '$KeyName'" }

        Write-Log $LogPath "Created Key Ring: '$KeyName'"
    }
    else {

        Write-Log $LogPath "Key Ring: '$KeyName already exists"

        Throw "Key Ring Already Exists: '$KeyName, Try again with another KeyName"
    }
}
