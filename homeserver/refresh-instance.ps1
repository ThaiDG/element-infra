param (
    [Parameter(Mandatory=$true)]
    [string]$AsgPrefix
)

# Check if ENV is set
if (-not $env:ENV -or $env:ENV -eq "") {
    Write-Host "ENV is not set. Using default environment: dev." -ForegroundColor Yellow
    Write-Host -NoNewline "Would you like to continue? [Y/n]: " -ForegroundColor Yellow
    $reply = Read-Host

    if ($reply -eq "" -or $reply -eq "Y" -or $reply -eq "y") {
        $env:ENV = "dev"
        Write-Host "Proceeding with environment: $env:ENV" -ForegroundColor Cyan
    } else {
        while ($true) {
            Write-Host -NoNewline "Would you like to choose environment? [Y/n]: " -ForegroundColor Yellow
            $reply = Read-Host
            if ($reply -eq "" -or $reply -eq "Y" -or $reply -eq "y") {
                Write-Host -NoNewline "Environment: " -ForegroundColor Yellow
                $reply = Read-Host
                if ($reply -ne "dev" -and $reply -ne "staging" -and $reply -ne "prod") {
                    Write-Host "Wrong environment. Please select dev, staging, or prod only!" -ForegroundColor Red
                    continue
                }
                $env:ENV = $reply
                Write-Host "ENV is set to: $env:ENV"
                Write-Host "Proceeding with environment: $env:ENV" -ForegroundColor Green
                break
            } else {
                Write-Host "Aborting initialization." -ForegroundColor Red
                exit 1
            }
        }
    }
} else {
    Write-Host "ENV is set to: $env:ENV"
    Write-Host "Proceeding with environment: $env:ENV" -ForegroundColor Green
}
# Set region and tag key
$region = "ap-southeast-1"
$tagKey = "Name"
$tagValue = "$env:ENV-$AsgPrefix"

Write-Host "Looking up ASG with tag '$tagKey=$tagValue' in region '$region'..." -ForegroundColor Cyan

# Get ASG name based on tag
$asgName = aws autoscaling describe-tags `
    --region $region `
    --filters "Name=key,Values=$tagKey" "Name=value,Values=$tagValue" `
    --query "Tags[0].ResourceId" `
    --output text

if ([string]::IsNullOrWhiteSpace($asgName) -or $asgName -eq "None") {
    Write-Host "No ASG found with tag '$tagKey=$tagValue'" -ForegroundColor Red
    exit 1
}

Write-Host "Found ASG: $asgName" -ForegroundColor Green

# Initiate instance refresh
Write-Host "Starting instance refresh for ASG: $asgName" -ForegroundColor Cyan
aws autoscaling start-instance-refresh `
    --auto-scaling-group-name $asgName `
    --region $region `
    --preferences '{\"MinHealthyPercentage\": 100, \"MaxHealthyPercentage\": 200}'

Write-Host "Refresh initiated successfully!" -ForegroundColor Green
