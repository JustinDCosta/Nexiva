$ErrorActionPreference = "Stop"

Write-Host "Building functions..."
Push-Location "firebase/functions"
npm run build
Pop-Location

Write-Host "Deploying Firebase resources..."
firebase deploy --only functions,firestore:rules,firestore:indexes,hosting --config firebase/firebase.json
