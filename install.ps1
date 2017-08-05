﻿Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host " __    __ _ _    _    _     "
Write-Host "/ / /\ \ (_) | _(_)  (_)___ "
Write-Host "\ \/  \/ / | |/ / |  | / __|"
Write-Host " \  /\  /| |   <| |_ | \__ \"
Write-Host "  \/  \/ |_|_|\_\_(_)/ |___/"
Write-Host "                   |__/     "
Write-Host "   < INSTALL >`n"

$VERSION = "1.0.4"

$curPath = Read-Host -Prompt 'Full path where Wiki.js should be installed (e.g. C:\wiki)'
$downloader = New-Object System.Net.WebClient
$7zip = "$curPath\7za.exe"

Set-Location -Path $curPath

Write-Host $7zip
Write-Host $curPath

function Gunzip-Item {
    param (
      [string]$params
     )

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($7zip, $params)
    $process.StartInfo.WorkingDirectory = $PSScriptRoot
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()

    switch ($exitCode) {
    0 { break }
    1 { throw "Error: Some files could not be extracted" }
    2 { throw "Error: 7-Zip encountered a fatal error while extracting the files" }
    7 { throw "Error: 7-Zip command line error" }
    8 { throw "Error: 7-Zip out of memory" }
    255 { throw "Error: Extraction cancelled by the user" }
    default { throw "Error: 7-Zip signalled an unknown error (code $exitCode)" }
  }
}

function Fix-PowerShellOutputRedirectionBug {
  $poshMajorVerion = $PSVersionTable.PSVersion.Major

  if ($poshMajorVerion -lt 4) {
    try{
      # http://www.leeholmes.com/blog/2008/07/30/workaround-the-os-handles-position-is-not-what-filestream-expected/ plus comments
      $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
      $objectRef = $host.GetType().GetField("externalHostRef", $bindingFlags).GetValue($host)
      $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetProperty"
      $consoleHost = $objectRef.GetType().GetProperty("Value", $bindingFlags).GetValue($objectRef, @())
      [void] $consoleHost.GetType().GetProperty("IsStandardOutputRedirected", $bindingFlags).GetValue($consoleHost, @())
      $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
      $field = $consoleHost.GetType().GetField("standardOutputWriter", $bindingFlags)
      $field.SetValue($consoleHost, [Console]::Out)
      [void] $consoleHost.GetType().GetProperty("IsStandardErrorRedirected", $bindingFlags).GetValue($consoleHost, @())
      $field2 = $consoleHost.GetType().GetField("standardErrorWriter", $bindingFlags)
      $field2.SetValue($consoleHost, [Console]::Error)
    } catch {
      Write-Output "Unable to apply redirection fix."
    }
  }
}

Fix-PowerShellOutputRedirectionBug

Write-Host "[1/6] Fetching 7zip helper... " -ForegroundColor Cyan -NoNewline
$downloader.DownloadFile("https://wiki.js.org/7za.exe", "$PSScriptRoot\7za.exe")
Write-Host "OK" -ForegroundColor White

Write-Host "[2/6] Fetching latest build... " -ForegroundColor Cyan -NoNewline
$downloader.DownloadFile("https://github.com/Requarks/wiki/releases/download/v$VERSION/wiki-js.tar.gz", "$PSScriptRoot\wiki-js.tar.gz")
Write-Host "OK" -ForegroundColor White

Write-Host "[3/6] Fetching dependencies... " -ForegroundColor Cyan -NoNewline
$downloader.DownloadFile("https://github.com/Requarks/wiki/releases/download/v$VERSION/node_modules.tar.gz", "$PSScriptRoot\node_modules.tar.gz")
Write-Host "OK" -ForegroundColor White

Write-Host "[4/6] Extracting app files... " -ForegroundColor Cyan -NoNewline
Gunzip-Item "e -y wiki-js.tar.gz"
Gunzip-Item "x -y wiki-js.tar"
Write-Host "OK" -ForegroundColor White

Write-Host "[5/6] Extracting dependencies... " -ForegroundColor Cyan -NoNewline
If(!(test-path "node_modules")){
    New-Item -ItemType Directory -Force -Path "node_modules" | Out-Null
}
Gunzip-Item "e -y node_modules.tar.gz"
Gunzip-Item "x -y -o`"node_modules`" node_modules.tar"
Write-Host "OK" -ForegroundColor White

Write-Host "[6/6] Creating config file... " -ForegroundColor Cyan -NoNewline
If(!(test-path "config.yml")){
    Rename-Item config.sample.yml config.yml
    Write-Host "OK"
} else {
    Write-Host "SKIP (already exists)" -ForegroundColor White
}

Write-Host "[6/6] Removing installation files... " -ForegroundColor Cyan -NoNewline
Remove-Item -Path * -Include *.tar.gz, *.tar, *.exe

Write-Host "`nInstallation Complete`n" -ForegroundColor Green

Write-Host "- Launch configuration wizard: " -NoNewline
Write-Host "node wiki configure" -ForegroundColor Yellow
Write-Host "- Start Wiki.js server: " -NoNewline
Write-Host "node wiki start" -ForegroundColor Yellow