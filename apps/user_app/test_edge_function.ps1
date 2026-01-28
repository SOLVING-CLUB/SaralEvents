# Test Edge Function Directly
# This script tests the edge function using Supabase CLI

Write-Host "Testing Edge Function Directly..." -ForegroundColor Cyan
Write-Host ""

# Change to user_app directory
Set-Location "apps\user_app"

# Test payload
$payload = @{
    userId = "ad73265c-4877-4a94-8394-5c455cc2a012"
    title = "CLI Test Notification"
    body = "Testing edge function directly from PowerShell"
    appTypes = @("user_app")
    data = @{
        type = "test"
    }
} | ConvertTo-Json -Depth 10

Write-Host "Payload:" -ForegroundColor Yellow
Write-Host $payload
Write-Host ""

# Invoke edge function
Write-Host "Invoking edge function..." -ForegroundColor Cyan
npx supabase functions invoke send-push-notification --body $payload

Write-Host ""
Write-Host "✅ Test complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check the response above"
Write-Host "2. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs"
Write-Host "3. Check your device for the notification"
