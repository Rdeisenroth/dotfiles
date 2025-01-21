# Install Vesktop via winget
Write-Host "Installing Vesktop..."
winget install --id=Vencord.Vesktop -e --accept-package-agreements --accept-source-agreements

# Check if Scoop is installed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop is not installed. Installing Scoop..."
    # Install Scoop
    Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
} else {
    Write-Host "Scoop is already installed."
}

# Ensure Komorebi and autohotkey are installed
Write-Host "Installing Komorebi and autohotkey..."
scoop install komorebi autohotkey

# Start Komorebi unattended
Write-Host "Starting Komorebi..."
Start-Process -FilePath komorebic -ArgumentList "start --ahk" -NoNewWindow

Write-Host "Komorebi has been started."
