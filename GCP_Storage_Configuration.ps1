    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$false, HelpMessage="ProjectId must be a unique string of 6 to 30 lowercase letters, digits, or hyphens. It must start with a lower case letter, followed by one or more lower case alphanumerical characters that can be separated by hyphens. It cannot have a trailing hyphen")]
        [Alias("P")]
        [ValidatePattern("(?!.*-$)^[a-z][a-z0-9\-]{5,29}$")]
        [ValidateLength(6,30)]
        [String]
        $ProjectId="click2cloud-352106",

        [Parameter(Mandatory=$false, Position=1, ValueFromPipeline=$false, HelpMessage="ServiceAccountId must be between 6 and 30 lowercase letters, digits, or hyphens. It must start with a lower case letter, followed by one or more lower case alphanumerical characters that can be separated by hyphens. It cannot have a trailing hyphen")]
        [Alias("SA")]
        [ValidatePattern("(?!.*-$)^[a-z][a-z0-9\-]{5,29}$")]
        [ValidateLength(6,30)]
        [String]
        $ServiceAccountId="micro12",

        [Parameter(Mandatory=$false, Position=2, ValueFromPipeline=$false, HelpMessage="Region must be one of 'us-central1', 'europe-west1'")]
        [Alias("R")]
        [ValidateSet("us-central1", "europe-west1")]
        [String]
        $Region="us-central1",

        [Parameter(Mandatory=$false, Position=3, ValueFromPipeline=$false, HelpMessage="BucketName must be adhere to the naming conventions outlined at 'https://cloud.google.com/storage/docs/naming-buckets'")]
        [Alias("B")]
        [ValidatePattern("(?!.*-_.$)^[a-z0-9][a-z0-9\-_.]{2,62}[^-_.].*[^-_.]$")]
        [ValidateLength(3,63)]
        [String]
        $BucketName="micro12buc",


        [Parameter(Mandatory=$false, Position=4, ValueFromPipeline=$false, HelpMessage="KeyName must be between 6 and 30 letters, digits, hyphens or underscores. It must start with a lower case letter, followed by one or more alphanumerical characters that can be separated by hyphens or underscores. It cannot have a trailing hyphen or underscore")]
        [Alias("K")]
        [ValidatePattern("^(?!.*\.)(?!.*-_$)^[A-Za-z][A-Za-z0-9\-_]{5,29}[^-_].*[^-_]$")]
        [ValidateLength(6,30)]
        [String]
        $KeyName,

        [Parameter(Mandatory=$false, Position=5, ValueFromPipeline=$false, HelpMessage="Storage Class must be one of 'STANDARD', 'NEARLINE', 'COLDLINE', 'ARCHIVE'")]
        [Alias("SC")]
        [ValidateSet("STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE")]
        [String]
        $StorageClass = "STANDARD",

        [Parameter(Mandatory=$false, Position=6, ValueFromPipeline=$false, HelpMessage="Service Account Key Type must be one of 'p12', 'json'")]
        [Alias("SAK")]
        [ValidateSet("p12", "json")]
        [String]
        $ServiceAccountKeyType = "json",

        [Parameter(Mandatory=$false, Position=7, ValueFromPipeline=$false, HelpMessage="Output Path for Json key and log e.g. C:\CloudM\GCPConfig")]
        [Alias("O")]
        [String]
        $OutputPath = "$($Home)\GCPConfig"

    )

    $ErrorActionPreference = 'Stop'

    Function Write-Log([string]$LogPath, [string]$Message, [bool]$Highlight=$false)
    {
        [string]$Date = Get-Date -Format G

        ("[$($Date)] - " + $Message) | Out-File -FilePath $LogPath -Encoding ASCII -Append

        if (!($NonInteractive)) {

            if($Highlight)
            {
                Write-Host $Message -BackgroundColor Yellow -ForegroundColor Black
            }
            else
            {
                Write-Host $Message
            }
        }
    }

    # Ensure that GoogleCloud module is installed
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

    Function Get-Service-Account([string]$ProjectId, [string]$ServiceAccountId)
    {
        Return "$($ServiceAccountId)@$($ProjectId).iam.gserviceaccount.com"
    }

    Function Get-Storage-Service-Account([string]$ProjectNumber)
    {
        Return "service-$($ProjectNumber)@gs-project-accounts.iam.gserviceaccount.com"
    }

    Function Build-API-List()
    {
        $KMSApis = @(
        "cloudkms.googleapis.com"
        )

        $CloudStorageApis = @(
        "storage-api.googleapis.com",
        "storage-component.googleapis.com",
        "storage.googleapis.com"
        )

        #Ignore for now
        $VaultApis = @(
        "vault.googleapis.com"
        )

        $CombinedApis = $KMSApis + $CloudStorageApis

        Return $CombinedApis
    }

    Function Configure-Apis ([string]$LogPath, [string]$ProjectId, [string]$Region = "us-central1")
    {
        $Apis = Build-API-List

        $ServicesEnabled =  gcloud services list --enabled --format="value(name)"

        if($LastExitCode -ne 0) { Throw "Failed to List Enabled APIs" }

        Foreach ($Api in $Apis) {

            $IsEnabledApiName = $false

            Foreach ($ServiceName in $ServicesEnabled) {

                if($ServiceName.EndsWith($Api)) {

                    $IsEnabledApiName = $true
                    break
                }
            }

            if(!$IsEnabledApiName) {

                Write-Log $LogPath "Enabling Api: '$Api'"

                try {

                    $Operation = gcloud services enable $Api --no-user-output-enabled
                }
                catch
                {
                    Throw "Failed to Enable API: '$Api'"
                }

                if($LastExitCode -ne 0) { Throw "Failed to Enable API: '$Api'" }

                Write-Log $LogPath "Enabled Api: '$Api'"
            }
            else {

                Write-Log $LogPath "Api: '$Api' already Enabled"
            }
        }
    }

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

    Function Configure-KMS ([string]$LogPath, [string]$KeyName, [string]$Region)
    {
        Configure-KMS-KeyRing $LogPath $KeyName $Region

        $KeyUrl = Configure-KMS-Key $LogPath $KeyName $Region

        Return $KeyUrl
    }

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

    # Uploading CSV files into CloudStorage
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


#     Create Dataset in BigQuery
    Function CreateDataset([string]$LogPath, [string]$ProjectId, [string]$DataSetName)
    {
        Write-Log $LogPath "Set Project for: '$ProjectId'"
        gcloud config set project $ProjectId

        Write-Log $LogPath "Creating dataset in BigQuery: '$DatasetName'"
#        New-BqDataset $DataSetName

        echo "Loaction for dataset:" $Region
        bq mk --location=$Region -d $DatasetName
        Start-Sleep -Seconds 30

    }

    #Create Table in BigQuery
    Function CreateTable-BigQuery([string]$LogPath, [string]$DataSetName,[string]$TableName, $Concat)
    {

        Write-Log $LogPath "Creating table in BigQuery: '$TableName'"
#        New-BqTable $TableName -DatasetId $DatasetName

        $Concat = $DatasetName+"."+$TableName
        echo "The value of Concat:" $Concat


        echo "location for table:" $Region
        bq mk --location=$Region -t $Concat
        Start-Sleep -Seconds 30

    }

    # Transferring Data from Cloud storage to BigQuery
    Function CloudStorage-To-BigQuery([string]$LogPath, [string]$Region, [string]$DatasetName, [string]$TableName)
    {
        Write-Log $LogPath "Loading dataset of CloudStorage-To-BigQuery: '$TableName'"

        $Concat2 = $DatasetName+"."+$TableName
        echo "The value of Concat:" $Concat2

        echo "location for table:" $Region
        bq --location=$Region load --autodetect --source_format=CSV $Concat2 gs://$BucketName/tempcsv/*.csv
        Start-Sleep -Seconds 30
    }

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

#    Function Billing-List([string]$LogPath){
#
#        #        ACCOUNT_ID = ""
#
#        $List = gcloud beta billing accounts list --filter=open=true
#
#        #        echo $ACCOUNT_ID
#
#        Return $List
#    }
#

    Function Enable-Billing([string]$LogPath, [string]$ProjectId, [string]$BillingAccount)
    {

        Write-Log $LogPath "Value of Account Id:'$BillingAccount'"

        Write-Log $LogPath "Enable Billing for project:'$ProjectId'"

        gcloud beta billing projects link $ProjectId --billing-account=$BillingAccount
        # 016431-5BB3C4-4BE6C6

    }

    Function Create-OutputPath([string]$OutputPath)
    {
        if(!(Test-Path -Path $OutputPath))
        {
            New-Item -ItemType "directory" -Path $OutputPath | Out-Null
        }
    }

    # Entry point for Script
    Function Configure-GCP-For-Archive ([string]$ProjectId, [string]$ServiceAccountId, [string]$Region, [string]$BucketName, [string]$KeyName, [string]$StorageClass, [string]$ServiceAccountKeyType, [string]$DataSetName, [string]$OutputPath = "$($Home)\GCPConfig")

    {

        Create-OutputPath $OutputPath

        $LogPath = "$($OutputPath)\gcp_config.log"

        Write-Host ""
        Write-Log $LogPath "Configuring GCP for CloudM Archive" $true

#        $BillingAccount = Read-Host -Prompt "Enter the Billing Account ID:"
#        Write-Output "value of billing account id: $BillingAccount"

        $CSVFolderPath = Read-Host -Prompt "Enter your CSV folder path:"
        Write-Output "value of folderpath: $CSVFolderPath"

        $DatasetName = Read-Host -Prompt "Enter your DatasetName:"
        Write-Output "value of dataset: $DatasetName"

        $TableName = Read-Host -Prompt "Enter TableName:"
        Write-Output "value of table name: $TableName"

        Install-Dependencies $LogPath

        # Project
        $ProjectNumber = Configure-Project $LogPath $ProjectId

#        #Billing List
#        Billing-List $LogPath
##        echo $List
#
#        #Enable Billing
#        Enable-Billing $LogPath $ProjectId $BillingAccount


        if($ProjectNumber) {

            # Service Account
            $ServiceAccountClientId = Configure-ServiceAccount $LogPath $ProjectId $ServiceAccountId

            $ServiceAccountEmail = Get-Service-Account $ProjectId $ServiceAccountId

            $ServiceAccountKeyPath = Configure-ServiceAccount-Key $LogPath $ProjectId $ServiceAccountId $ServiceAccountKeyType $OutputPath

            # Enable APIs
            Configure-Apis $LogPath $ProjectId $Region

            $StorageServiceAccountEmail = Get-Storage-Service-Account $ProjectNumber

            $KeyRole = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

            $Roles = @("roles/storage.admin","roles/storage.objectAdmin")
            $ServiceAccounts = @()
            $ServiceAccounts += $ServiceAccountEmail

            if($KeyName) {

                $ServiceAccounts += $StorageServiceAccountEmail
            }

            # Bucket
            $BucketAccessSet = $False
            $BucketUrl = Configure-Bucket $LogPath $ProjectId $BucketName $Region $StorageClass

            #Upload CSV
            Upload-CSV-To-CloudStorage $LogPath $BucketName $CSVFolderPath

            # Create Dataset in BigQuery
            CreateDataset $LogPath $ProjectId $DataSetName

            #Create Table in BigQuery
            CreateTable-BigQuery $LogPath $DatasetName $TableName $Concat

            # load data of CloudStorage-To-BigQuery
            CloudStorage-To-BigQuery $LogPath $Region $DatasetName $TableName

            if($BucketUrl) {

                $LaunchUrl = "https://console.cloud.google.com/storage/settings;tab=project_access?project=$($ProjectId)"

                Write-Log $LogPath "Hack - Launching Browser to attempt propagation of storage service account: $StorageServiceAccountEmail - Url: $LaunchUrl" $true

                Start-Process $LaunchUrl

                $BucketAccessSet = Configure-Bucket-Access $LogPath $BucketUrl $Roles $ServiceAccounts
            }

            $KMSKeyUrl = ""
            $KMSKeyAccessSet = $False

            if($BucketUrl) {

                if($KeyName) {

                    # KMS
                    $KMSKeyUrl = Configure-KMS $LogPath $KeyName $Region $StorageServiceAccountEmail

                    $KMSKeyAccessSet = Configure-KMS-Key-Access $LogPath $KeyName $Region $StorageServiceAccountEmail $KeyRole
                }
            }
            else {

                Write-Log $LogPath "Failed Configuring GCP for CloudM Archive" $true
            }

            Write-Host ""

            Write-Log $LogPath "Service Account and KMS Key details for use in CloudM Archive:" $true

            Write-Host ""
            Write-Log $LogPath "SA Email: $ServiceAccountEmail"
            Write-Log $LogPath "SA Key Path: $ServiceAccountKeyPath"

            if($BucketUrl) {
                Write-Log $LogPath "Bucket Url: $BucketUrl"
            }

            if($KMSKeyUrl) {
                Write-Log $LogPath "KMS Key Path: $KMSKeyUrl"
            }

            if($BucketAccessSet -eq $False) {

                Write-Host ""
                Write-Log $LogPath "Failed to set Service Account roles on Bucket: $BucketUrl. Please manually configure by visiting the Url: https://console.cloud.google.com/storage/browser?project=$($ProjectId)" $true
                Write-Host ""

                Write-Log $LogPath "Service Account permissions to Add:"

                foreach($ServiceAccount in $ServiceAccounts) {

                    $SAText = "Service Account: $ServiceAccount, Roles: " + ($Roles -join ', ')

                    Write-Log $LogPath "$SAText"
                }
                Write-Host ""
            }

            if($KMSKeyUrl -and ($KMSKeyAccessSet -eq $False)) {

                Write-Host ""
                Write-Log $LogPath "Failed to set Service Account role on Key: $KeyName. Please manually configure by visiting the Url: https://console.cloud.google.com/security/kms/key/manage/$($Region)/$($KeyName)/$($KeyName)?project=$($ProjectId)" $true
                Write-Host ""

                Write-Log $LogPath "Service Account permissions to Add:"
                Write-Log $LogPath "Service Account: $StorageServiceAccountEmail, Role: $KeyRole"
                Write-Host ""
            }

            Write-Host ""

            Write-Log $LogPath "Configured GCP for CloudM Archive" $true
        }
        else {

            Write-Log $LogPath "Failed Configuring GCP for CloudM Archive" $true
        }
    }

    Configure-GCP-For-Archive $ProjectId $ServiceAccountId $Region $BucketName $KeyName $StorageClass $ServiceAccountKeyType $OutputPath
