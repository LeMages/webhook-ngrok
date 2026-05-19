$ErrorActionPreference = "Stop"

if (-not $env:REPO_URL) { throw "Missing REPO_URL" }
if (-not $env:DEPLOY_DIR) { throw "Missing DEPLOY_DIR" }
if (-not $env:TARGET_BRANCH) { $env:TARGET_BRANCH = "main" }

Write-Host "== Deploy started =="
Write-Host "Repo:   $env:REPO_URL"
Write-Host "Dir:    $env:DEPLOY_DIR"
Write-Host "Branch: $env:TARGET_BRANCH"

$deployDir = $env:DEPLOY_DIR

if (-not (Test-Path "$deployDir\.git")) {
    Write-Host "Cloning..."
    git clone --branch $env:TARGET_BRANCH $env:REPO_URL $deployDir
} else {
    Write-Host "Pulling latest..."
    git -C $deployDir fetch --all
    git -C $deployDir checkout $env:TARGET_BRANCH
    git -C $deployDir pull --ff-only
}

# The React app lives in the `app/` subfolder of the repo
$appDir = Join-Path $deployDir "app"
if (-not (Test-Path $appDir)) {
    throw "App directory not found: $appDir"
}

Write-Host "Installing dependencies in $appDir..."
Set-Location $appDir

# On Windows, npm is a .cmd shim — Start-Process needs the full name with extension.
# `npm install` synchronously is fine via direct invocation.
npm install

# Read package.json directly (more reliable than parsing `npm run` output)
$pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
$scriptNames = $pkg.scripts.PSObject.Properties.Name

# Resolve npm.cmd path explicitly to avoid "not a valid Win32 application" errors.
$npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
if (-not $npmCmd) { $npmCmd = "npm.cmd" }

Write-Host "Starting app..."
if ($scriptNames -contains "dev") {
    # Vite
    Start-Process -FilePath $npmCmd -ArgumentList "run","dev","--","--host","0.0.0.0" `
        -WorkingDirectory $appDir `
        -RedirectStandardOutput "app.log" -RedirectStandardError "app.err.log"
    Write-Host "Started with: npm run dev"
}
elseif ($scriptNames -contains "start") {
    # Create React App
    Start-Process -FilePath $npmCmd -ArgumentList "run","start" `
        -WorkingDirectory $appDir `
        -RedirectStandardOutput "app.log" -RedirectStandardError "app.err.log"
    Write-Host "Started with: npm run start"
}
else {
    throw "No start/dev script found in package.json"
}

Write-Host "== Deploy done =="