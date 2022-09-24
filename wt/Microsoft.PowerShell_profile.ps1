Import-Module posh-git
Import-Module PSReadLine

# Tests if given command exists
# Adapted from https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
function Test-CommandExists ([string] $command) {
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'stop'
  try { if (Get-Command $command) { $true } }
  catch { $false }
  finally { $ErrorActionPreference = $oldPreference }
}

function Mount-ExternalFileSystem {
  [CmdletBinding()]
  param(
    [string]
    $Address = "vech.ro",
    [Parameter(Mandatory, Position = 0)]
    [ValidateRange(0, 65535)]
    [int]
    $Port
  )
  Invoke-Expression "sshfs-win svc \sshfs.kr\$Address!$Port X:"
}

function Add-BuildTools {
  <#
    .SYNOPSIS
    Enables Visual Studio Build Tools in current session.
  #>
  [CmdletBinding()]
  param(
    [ValidateSet(2017, 2019, 2022)]
    [int]
    $Year = 2022
  )

  $BuildToolsPath = "C:\Program Files (x86)\Microsoft Visual Studio\$Year\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

  if (Test-Path -Path $BuildToolsPath) {
    cmd.exe /c "call `"$BuildToolsPath`" && set > %temp%\vcvars.txt"

    Get-Content "$env:temp\vcvars.txt" | ForEach-Object {
      if ($_ -match "^(.*?)=(.*)$") {
        Set-Content "env:\$($matches[1])" $matches[2]
      }
    }
  } else {
    throw "Could not find `"$BuildToolsPath`", are you sure you have VS Build Tools $Year installed?"
  }
}

# Adapted from https://github.com/rajivharris/Set-PsEnv
function Set-Env {
  <#
    .SYNOPSIS
    Parses and sets env variables from .env file in current working directory.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(ValueFromPipeline)]
    [string] $EnvFile = '.\.env'
  )

  $Content = Get-Content $EnvFile -ErrorAction Stop
  Write-Verbose "Parsed .env file"

  # Load the content to environment
  foreach ($Line in $Content) {
    if ([string]::IsNullOrWhiteSpace($Line)) {
      Write-Verbose "Skipping empty line"
      continue
    }
    if ($Line.StartsWith("#")) {
      Write-Verbose "Skipping comment: $Line"
      continue
    }
    $Key, $Value = $Line -split "=", 2 | ForEach-Object Trim
    Write-Verbose "$Key=$Value"
    if ($PSCmdlet.ShouldProcess("Environment variable $Key", "Set value $Value")) {
      [Environment]::SetEnvironmentVariable($Key, $Value, "Process") | Out-Null
    }
  }
}

function Open-Directory {
  <#
    .SYNOPSIS
    Opens provided path in Explorer/Finder.
  #>
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)]
    [string] $Path = '.'
  )
  if ([IO.Directory]::exists($Path)) {
    Invoke-Item $Path
  } else {
    [IO.Path]::GetDirectoryName($Path) | Invoke-Item
  }
}

function Open-InWsl {
  <#
    .SYNOPSIS
    Opens current working directory in your default WSL distribution.
  #>
  Start-Process pwsh.exe '-Command', {
    wsl --cd "$PWD"
    Read-Host
  }
}

function Debug-EnvPath {
  <#
    .SYNOPSIS
    Inspects provided PATH variable for errors.
    .OUTPUTS
    Table of erroneous PATH entries with error type.
  #>
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)]
    [string] $PathVariable = $env:PATH
  )
  $PathVariable -split [IO.Path]::PathSeparator
  | ForEach-Object ToLower
  | Group-Object
  | ForEach-Object { if (!(Test-Path -Path $_.Name)) {
      [PSCustomObject]@{
        Directory = if ($_.Name -eq '') { "'$_.Name'" } else { $_.Name }
        Type      = "Invalid"
        Count     = $_.Count
      }
    } elseif ($_.Count -gt 1) {
      [PSCustomObject]@{
        Directory = $_.Name
        Type      = "Duplicate"
        Count     = $_.Count
      }
    } }
  | Format-Table
}

function Clear-LastHistoryEntry {
  <#
    .SYNOPSIS
    Removes last entry from PowerShell history.
  #>
  $HistorySavePath = (Get-PSReadLineOption).HistorySavePath
  (Get-Content $HistorySavePath -Tail 2).Split([Environment]::NewLine) | Select-Object -First 1 | Clear-HistoryEntry
}

function Clear-HistoryEntry {
  <#
    .SYNOPSIS
    Removes all history entries matching the argument exactly.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Entry
  )
  Clear-History -CommandLine $Entry
  $HistorySavePath = (Get-PSReadLineOption).HistorySavePath
  Get-Content $HistorySavePath | Where-Object { $_ -ne $Entry } | Set-Content $HistorySavePath
}

Set-Alias which Get-Command -Option ReadOnly
Set-Alias open Open-Directory -Option ReadOnly

Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Alt+w -ScriptBlock { Open-InWsl } -BriefDescription "Open current directory in WSL" -Description "Open current directory in your default WSL distribution"
Set-PSReadLineKeyHandler -Chord Alt+e -ScriptBlock { Invoke-Item . } -BriefDescription "Invoke-Item ." -Description "Open current directory in Explorer/Finder"
Set-PSReadLineKeyHandler -Chord Alt+Delete -ScriptBlock { Clear-LastCommand } -BriefDescription "Clear-LastCommand" -Description "Delete last entry from history"

# The Windows terminal does not use UTF-8 by default, the following line changes that
# chcp 65001

Invoke-Expression (&starship init powershell)
fnm env --use-on-cd | Out-String | Invoke-Expression