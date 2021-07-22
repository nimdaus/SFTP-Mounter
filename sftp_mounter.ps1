# https://github.com/nimdaus
Param (
    $hostname = "server0000.file-restore.net",
    $port = "22",
    $username = "sftp000000",
    $password = "hunter2", # Obfuscation happens on client
    $bwlimit = "0", # Max bandwidth in KBytes/s, or use a suffix b|k|M|G
    $volname = "DattoRestore", #[Default] is a local mount | For a `Mapped Drive` share specify "\\DattoCloud\FileRestore"
    [bool]$cleanup = $false, # Set to true for auto component uninstall and removal
    $cache_size = "64M", #[Advanced] Limited use case
    $cache_limit = "2G" #[Advanced] Limited use case
)

function Invoke-Cleanup {
    Set-Location -Path "C:\Datto_Restore" | Out-Null
    Start-Process msiexec -wait -WindowStyle Hidden -argumentlist '/i "DattoRestore_winfsp.msi" /q /norestart /l*v C:\temp\ermsinstaller.log'
    Set-Location -Path "C:\" | Out-Null
    Remove-Item "C:\Datto_Restore" -Recurse -Force | Out-Null
    Remove-Item "C:\temp\winfsp_installer.log" -Force | Out-Null
    Remove-Item "C:\temp\rclone.log" -Force | Out-Null
	Remove-Item "C:\temp\config.log" -Force | Out-Null
    Remove-Item "C:\temp\rclone.log" -Force | Out-Null
    Remove-Item "C:\temp\rclone.log" -Force | Out-Null
    Remove-Item "C:\temp\rclone.log" -Force | Out-Null
}

if ($cleanup -eq $true) {
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
    if ($installed -eq $null) {
        $githubLatestRelease = (((Invoke-WebRequest "https://api.github.com/repos/billziss-gh/winfsp/releases/latest") | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern 'msi').Line
        Invoke-WebRequest $githubLatestRelease -OutFile "DattoRestore_winfsp.msi"
        Start-Process msiexec -wait -WindowStyle Hidden -argumentlist '/i "DattoRestore_winfsp.msi" /q /l*v C:\temp\winfsp_installer.log'
    }
    Write-Host "File System Proxy Success!"
    Start-Sleep -s 1
    Write-Host "Getting Mounter..."
    $rclone_check = Get-ChildItem -Filter rclone.exe -LiteralPath "C:\Datto_Restore" -Recurse -Force -File
    if ($rclone_check -eq $null) {
        if ((Get-WmiObject win32_operatingsystem | select osarchitecture).osarchitecture -like "64*") {
            $githubLatestRelease = (((Invoke-WebRequest "https://api.github.com/repos/rclone/rclone/releases/latest") | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern 'windows-amd64').Line
            Invoke-WebRequest $githubLatestRelease -OutFile "DattoRestore_rclone.zip"
        }
        else {
            $githubLatestRelease = (((Invoke-WebRequest "https://api.github.com/repos/rclone/rclone/releases/latest") | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern 'windows-386').Line
            Invoke-WebRequest $githubLatestRelease -OutFile "DattoRestore_rclone.zip"
        }
        Expand-Archive -Force -Path "DattoRestore_rclone.zip" -DestinationPath "C:\Datto_Restore"
    }
    $rclone = Get-ChildItem -Filter rclone.exe -LiteralPath "C:\Datto_Restore" -Recurse -Force -File | Select-Object -ExpandProperty FullName
	if ($rclone -eq $null) {
		Write-Warning -Message "Rclone Not Found"
		exit
	}
	Start-Sleep -s 1
    Write-Host "Mounter Success!"
    Start-Sleep -s 1
    Write-Host "Configuring..."
    $config = Start-Process -FilePath $rclone -WindowStyle Hidden -RedirectStandardOutput "C:\temp\config_output.log" -RedirectStandardError "C:\temp\config_error.log"-ArgumentList '--config="C:\Datto_Restore\rclone.conf"', "config", "create", "datto", "sftp", "host", "$hostname", "port", "$port", "user", "$username", "pass", "$password", "--log-level INFO", '--log-file="C:\temp\rclone.log"'
	Write-Host "Mounting..."
    $mount = Start-Process -FilePath $rclone -WindowStyle Hidden -PassThru -RedirectStandardOutput "C:\temp\mount_output.log" -RedirectStandardError "C:\temp\mount_error.log" -ArgumentList '--config="C:\Datto_Restore\rclone.conf"', "mount", "datto:", "*", "--vfs-cache-mode full", "--vfs-read-chunk-size $cache_size", "--vfs-read-chunk-size-limit $cache_limit", "--read-only", "--volname $volname", "--bwlimit $bwlimit", "--log-level INFO", '--log-file="C:\temp\rclone.log"'
	$mounted = $false
	while ($mounted -eq $false) {
		Start-Sleep -s 2
		$m = Get-Content -Path "C:\temp\rclone.log" | Select-String -Pattern 'The service rclone has been started.'
		if ($m.Matches) { 
			$mounted = $true
			Write-Host "Mounted!"
		}
    }
	$response = read-host "Enter q to unmount and exit"
	while ($response -ne "q") {
		if ($response -eq "q") {
			Stop-Process -Id $mount.Id -Force
		}
	}
}
catch {
    Write-Warning -Message "Hmm something went wrong...`r`nCheck logs in C:\temp\"
	$string_err = $_ | Out-String
	$string_err | Out-File 'C:\temp\sftp_error.log' -Append
}
finally {
	if ($mounted -eq $true) {
		Stop-Process -Id $mount.Id -Force
    }
    exit
}
