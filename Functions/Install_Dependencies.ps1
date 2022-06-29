Function Install-Dependencies([string]$LogPath)
{
    Write-Log $LogPath "Ensuring GoogleCloud module..."

    Import-Module GoogleCloud

    try {
        # Test to see if gcloud init has been run
        $CurrentProject = gcloud config get-value project
    }
    catch
    {
        Throw "Google Cloud SDK has not been initialised or your account does not have the required permissions"
    }

    if($CurrentProject) {

        Write-Log $LogPath "Google Cloud SDK has been initialised, Current Project: '$CurrentProject'"
    }
    else
    {
        Throw "Google Cloud SDK has not been initialised"
    }
}
