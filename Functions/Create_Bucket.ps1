Function Configure-Bucket ([string]$LogPath, [string]$ProjectId, [string]$BucketName, [string]$Region, [string]$StorageClass)
{
    $Buckets = $null

    Try {

        $Buckets = gsutil ls -p $($ProjectId) gs://

        if($LastExitCode -ne 0) { Throw "Failed to Get Buckets in Project: '$ProjectId'" }
    }
    catch
    {
        Write-Log $LogPath "No Existing Buckets for: '$($ProjectId)', $_"
    }

    $BucketExists = $false

    $BucketToCreate = "gs://$($BucketName)"

    if($Buckets -ne $null) {

        Foreach ($Bucket in $Buckets) {

            if($Bucket.StartsWith($BucketToCreate)) {

                Write-Log $LogPath "Bucket: $($BucketName) Exists for: '$($ProjectId)'"
                $BucketExists = $true
                break
            }
        }
    }

    if(!$BucketExists) {

        Try {

            gsutil mb -p $($ProjectId) -l $($Region) -c $StorageClass -b on $BucketToCreate

            if($LastExitCode -ne 0) { Throw "Failed to Create Bucket: '$BucketToCreate' in Project: '$ProjectId'" }

            Start-Sleep -Seconds 30
        }
        catch
        {
            if($_.Exception.Message.StartsWith("Creating $BucketToCreate")) {
                Write-Log $LogPath "Created Bucket: '$($BucketName)'"
            }
            else {

                Write-Log $LogPath "Failed Creating Bucket for: '$($BucketName)', $_"
                Throw $_
            }
        }
    }
    else {
        Write-Log $LogPath "Bucket: '$BucketToCreate' Already Exists"

        Throw "Bucket: '$BucketToCreate' Already Exists"
    }

    Return $BucketToCreate
}
