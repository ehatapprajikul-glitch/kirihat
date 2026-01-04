Write-Host "Searching for keytool.exe..." -ForegroundColor Cyan
$keytool = Get-ChildItem -Path "C:\Program Files\Android" -Filter "keytool.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($keytool) {
    Write-Host "Found: $($keytool.FullName)" -ForegroundColor Green
    & $keytool.FullName -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA" | Out-File "key_output.txt" -Encoding utf8
    Write-Host "Output saved to key_output.txt" -ForegroundColor Green
}
else {
    Write-Host "Could not find keytool.exe. Is Android Studio installed?" -ForegroundColor Red
}
