$ErrorActionPreference = "Stop"

Write-Host "Installing Firebase Functions dependencies..."
Push-Location "firebase/functions"
npm install
npm run build
Pop-Location

Write-Host "Flutter setup requires Flutter SDK installed and available in PATH."
Write-Host "Then run:"
Write-Host "  cd flutter_app"
Write-Host "  flutter pub get"
Write-Host "  flutterfire configure"
