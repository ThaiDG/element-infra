param (
    [Parameter(Mandatory=$true)]
    [string]$AsgPrefix
)

# Set region and tag key
$region = "ap-southeast-1"
$tagKey = "Name"
$tagValue = "dev-$AsgPrefix"

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
    --region $region

Write-Host "Refresh initiated successfully!" -ForegroundColor Green
