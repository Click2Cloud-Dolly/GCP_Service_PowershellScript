Function Configure-Project ([string]$LogPath, [string]$ProjectId)
{
    $ProjectNumber = ""

    Write-Log $LogPath "Configuring Project: '$ProjectId'"

    $Projects = gcloud projects list --filter $ProjectId --format=json | ConvertFrom-Json

    if($LastExitCode -ne 0) { Throw "Failed to List Projects" }

    if($Projects.Length -eq 0) {

        Write-Log $LogPath "Creating Project: '$ProjectId', this may take a few minutes"

        try {

            gcloud projects create $ProjectId --set-as-default --no-user-output-enabled

            Start-Sleep -Seconds 30
        }
        catch
        {
            Throw "Failed to Create Project: '$ProjectId', $_"
        }

        if($LastExitCode -ne 0) { Throw "Failed to Create Project: '$ProjectId'" }

        Write-Log $LogPath "Created Project: '$ProjectId'"

    }
    else {

        Write-Log $LogPath "Project: '$ProjectId' Already Exists"

        $CurrentProject = gcloud config get-value project

        if ($CurrentProject -ne $ProjectId) {

            Write-Log $LogPath "Switching to Project: '$ProjectId'"

            gcloud config set project $ProjectId --no-user-output-enabled

            Write-Log $LogPath "Switched to Project: '$ProjectId'"
        }
    }

    Try {

        $RetrievedProject = gcloud projects describe $ProjectId --format="json" | ConvertFrom-Json

        if($RetrievedProject -ne $null) {

            $ProjectNumber = $RetrievedProject.projectNumber
        }
    }
    catch
    {
        Throw "Failed to Configure Project: '$ProjectId', $_"
    }

    if($LastExitCode -ne 0) { Throw "Failed to Configure Project: '$ProjectId'" }

    Write-Log $LogPath "Configured Project: '$ProjectId'"

    Return $ProjectNumber
}
