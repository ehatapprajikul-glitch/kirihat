# Deploy Script for Kiri Hat Suite

Write-Host "Starting Build Process..." -ForegroundColor Green

# 1. Build Customer App
Write-Host "Building Customer App..." -ForegroundColor Cyan
Set-Location "customer_app"
flutter clean
flutter pub get
# Build with correct base href for subdirectory
flutter build web --release --base-href "/app/"
if ($LASTEXITCODE -ne 0) { Write-Error "Customer App Build Failed"; exit }
Set-Location ".."

# 1.1 Prepare Dist Directory
Write-Host "Preparing Distribution Directory..." -ForegroundColor Cyan
if (Test-Path "dist") { Remove-Item "dist" -Recurse -Force }
New-Item -ItemType Directory -Path "dist/customer_site" | Out-Null
New-Item -ItemType Directory -Path "dist/customer_site/app" | Out-Null

# 1.2 Copy Static Site
Write-Host "Copying Static Site..." -ForegroundColor Cyan
Copy-Item "static_site/*" "dist/customer_site" -Recurse

# 1.3 Copy App to Subdirectory
Write-Host "Copying App to /app..." -ForegroundColor Cyan
Copy-Item "customer_app/build/web/*" "dist/customer_site/app" -Recurse

# 2. Build Admin Portal
Write-Host "Building Admin Portal..." -ForegroundColor Cyan
Set-Location "admin_portal"
flutter clean
flutter pub get
flutter build web --release
if ($LASTEXITCODE -ne 0) { Write-Error "Admin Portal Build Failed"; exit }
Set-Location ".."

# 3. Deploy
Write-Host "Deploying to Firebase..." -ForegroundColor Cyan
firebase deploy
# Write-Host "Build Complete. Run 'firebase deploy' manually to deploy." -ForegroundColor Yellow

Write-Host "Deployment Complete!" -ForegroundColor Green
