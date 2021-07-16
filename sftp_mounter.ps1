# https://github.com/nimdaus
Param (
    $hostname = "server0000.file-restore.net",
    $port = "22",
    $username = "sftp000000",
    $password = "hunter2", # Obfuscation happens on client
    $bwlimit = "0", # Max bandwidth in KBytes/s, or use a suffix b|k|M|G
    $volname = "DattoRestore", #[Default] is a local mount | For a `Mapped Drive` share specify "\\DattoCloud\FileRestore"
    [bool]$cleanup = "later", # Set to now for component uninstall and removal
    $cache_size = "64M", #[Advanced] Limited use case
    $cache_limit = "2G", #[Advanced] Limited use case
    $buffer_size #[Advanced] Limited use case
)

function Invoke-Cleanup {
    Set-Location -Path "C:\Datto_Restore" | Out-Null
    Start-Process msiexec -wait -WindowStyle Hidden -argumentlist '/i "DattoRestore_winfsp.msi" /q /norestart /l*v C:\temp\ermsinstaller.log'
    Set-Location -Path "C:\" | Out-Null
    Remove-Item "C:\Datto_Restore" -Recurse -Force | Out-Null
    Remove-Item "C:\temp\winfsp_installer.log" -Force | Out-Null
    Remove-Item "C:\temp\rclone.log" -Force | Out-Null
}

if ($cleanup -eq 1) {
    Invoke-Cleanup
    exit
}

try {
    Write-Host "These prerequisites might take a minute..."
    $null = New-Item -ItemType "directory" -Path "C:\Datto_Restore" -Force
    $null = New-Item -ItemType "directory" -Path "C:\temp" -Force
    Set-Location -Path "C:\Datto_Restore"
    Write-Host "Getting File System Proxy..."
    $installed = Get-WmiObject -Class Win32_Product | where Name -match "WinFSP"
    if ($installed -eq $false) {
        $githubLatestRelease = (((Invoke-WebRequest "https://api.github.com/repos/billziss-gh/winfsp/releases/latest") | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern 'msi').Line
        Invoke-WebRequest $githubLatestRelease -OutFile "DattoRestore_winfsp.msi" | Out-Null
        Start-Process msiexec -wait -WindowStyle Hidden -argumentlist '/i "DattoRestore_winfsp.msi" /q /l*v C:\temp\winfsp_installer.log'
    }
    Write-Host "File System Proxy Success!"
    Start-Sleep -s 1
    Write-Host "Getting Mounter..."
    $rclone_check = Get-ChildItem -Filter rclone.exe -LiteralPath "C:\Datto_Restore" -Recurse -Force -File
    if ($rclone_check -eq $false) {
        if ((Get-WmiObject win32_operatingsystem | select osarchitecture).osarchitecture -like "64*") {
            $githubLatestRelease = (((Invoke-WebRequest "https://api.github.com/repos/rclone/rclone/releases/latest") | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern 'windows-amd64').Line
            Invoke-WebRequest $githubLatestRelease -OutFile "DattoRestore_rclone.zip"
        }
        else {
            $githubLatestRelease = (((Invoke-WebRequest "https://api.github.com/repos/rclone/rclone/releases/latest") | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern 'windows-386').Line
            Invoke-WebRequest $githubLatestRelease -OutFile "DattoRestore_rclone.zip" | Out-Null
        }
        Expand-Archive -Force -Path "DattoRestore_rclone.zip" -DestinationPath "C:\Datto_Restore"
    }
    $rclone = Get-ChildItem -Filter rclone.exe -LiteralPath "C:\Datto_Restore" -Recurse -Force -File | Select-Object -ExpandProperty FullName
    Write-Host "Mounter Success!"
    Start-Sleep -s 1
    Write-Host "Configuring..."
    $setup = Start-Process -FilePath $rclone -WindowStyle Hidden -ArgumentList '--config="C:\Datto_Restore\rclone.conf"', "config", "create", "datto", "sftp", "host", "$hostname", "port", "$port", "user", "$username", "pass", "$password", "--log-level INFO", '--log-file="C:\temp\rclone.log"'
    $running = $false
    Write-Host "Mounting..."
    $run = Start-Process -FilePath $rclone -WindowStyle Hidden -PassThru -ArgumentList '--config="C:\Datto_Restore\rclone.conf"', "mount", "datto:", "*", "--vfs-cache-mode full", "--vfs-read-chunk-size $cache_size", "--vfs-read-chunk-size-limit $cache_limit", "$buffer_size", "--read-only", "--volname $volname", "--bwlimit $bwlimit", "--log-level INFO", '--log-file="C:\temp\rclone.log"'
    while ($running = $false) {
        $output = $run.StandardOutput.ReadToEnd()
        if ($output.Contains("The service rclone has been started")) {
            $running = $true
        }
        if ($run.ExitCode -ne 0) {
            Write-Host "Connection Failed :( | See C:\temp\rclone.log for details"
            exit
        }
    }
    Write-Host "Mounted!"
    Write-Host 'Press "Ctrl+C" or close the window to exit...'
    $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown") | OUT-NULL
    $Host.UI.RawUI.FlushInputbuffer()
    Stop-Process -Id $run.Id -Force
    if ($cleanup -eq 1) {
        Invoke-Cleanup
        exit
    }
    exit
}
catch {
    Write-Host "Hmm something went wrong..."
    if ($running -eq $true) {
        Stop-Process -Id $run.Id -Force
    }
    exit
}
