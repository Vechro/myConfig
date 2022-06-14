using namespace System.Management.Automation
using namespace System.Management.Automation.Language

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

New-Alias which Get-Command -Option ReadOnly

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
    [ValidateSet(2015, 2017, 2019, 2022)]
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
  param()

  if ($Global:PreviousDir -eq (Get-Location).Path) {
    Write-Verbose "Set-Env: Skipping same directory"
    return
  } else {
    $Global:PreviousDir = (Get-Location).Path
  }

  # Return if no env file
  if (!(Test-Path ".\.env")) {
    Write-Verbose "No .env file"
    return
  }

  # Read the local env file
  $content = Get-Content ".\.env" -ErrorAction Stop
  Write-Verbose "Parsed .env file"

  # Load the content to environment
  foreach ($line in $content) {

    if ([string]::IsNullOrWhiteSpace($line)) {
      Write-Verbose "Skipping empty line"
      continue
    }

    # Ignore comments
    if ($line.StartsWith("#")) {
      Write-Verbose "Skipping comment: $line"
      continue
    }

    $kvp = $line -split "=", 2
    $key = $kvp[0].Trim()
    $value = $kvp[1].Trim()

    Write-Verbose "$key=$value"

    if ($PSCmdlet.ShouldProcess("environment variable $key", "set value $value")) {
      [Environment]::SetEnvironmentVariable($key, $value, "Process") | Out-Null
    }
  }
}

function Open-Directory {
  <#
    .SYNOPSIS
    Opens provided path in Explorer.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Path
  )
  if ((Get-Item $Path) -is [System.IO.FileInfo]) {
    Split-Path $Path | Invoke-Item
  } else {
    Invoke-Item $Path
  }
}
Set-Alias open Open-Directory -Option ReadOnly

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

  $entries = $PathVariable -split ';'
  $entries
  | ForEach-Object { $_.ToLower() }
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

# https://stackoverflow.com/a/31813329/17977931
function Clear-LastCommand {
  # Remove last entry from Powershell history
  Clear-History -Count 1 -Newest

  # Remove last entry from PSReadLine history
  $HistoryFile = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\$($host.Name)_history.txt"
  $LinesInFile = [System.IO.File]::ReadAllLines($HistoryFile)
  $DesiredLineCount = $LinesInFile.Count - 2

  # Rewrite last line
  $LinesInFile[$DesiredLineCount] = "Clear-LastCommand"

  # Write all lines, except for the last one, back to the file
  [System.IO.File]::WriteAllLines($HistoryFile, $LinesInFile[0..($DesiredLineCount)])
}

Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Alt+w -ScriptBlock { Open-InWsl } -BriefDescription "Open current directory in WSL" -Description "Open current directory in your default WSL distribution"
Set-PSReadLineKeyHandler -Chord Alt+e -ScriptBlock { Invoke-Item . } -BriefDescription "Invoke-Item ." -Description "Open current directory in Explorer"
Set-PSReadLineKeyHandler -Chord Alt+Delete -ScriptBlock { Clear-LastCommand } -BriefDescription "Clear-LastCommand" -Description "Delete last entry from history"

# The Windows terminal does not use UTF-8 by default, the following line changes that
# chcp 65001

$script:bg = [Console]::BackgroundColor;
$script:last = 0;

function Write-DecoratedPromptEnd {
  Write-Host  -NoNewline -ForegroundColor $script:bg

  $script:bg = [System.ConsoleColor]::Black
}

function Write-PromptSegment {
  param(
    [Parameter(
      Position = 0,
      Mandatory,
      ValueFromPipeline,
      ValueFromPipelineByPropertyName
    )][string]$Text,

    [Parameter(Position = 1)][System.ConsoleColor] $Background = [Console]::BackgroundColor,
    [Parameter(Position = 2)][System.ConsoleColor] $Foreground = [System.ConsoleColor]::White
  )

  if (!$script:first) {
    Write-Host  -NoNewline -BackgroundColor $Background -ForegroundColor $script:bg
  } else {
    $script:first = $false
  }

  Write-Host $Text -NoNewline -BackgroundColor $Background -ForegroundColor $Foreground

  $script:bg = $Background;
}

function Get-DecoratedPrompt {
  return $(Get-Location).ToString().Replace($env:USERPROFILE, '~').Replace('\', '  ');
}

function Get-GitBranch {
  $HEAD = Get-Content $(Join-Path $(Get-GitDirectory) HEAD)
  if ($HEAD -like 'ref: refs/heads/*') {
    return $HEAD -replace 'ref: refs/heads/(.*?)', "$1";
  } else {
    return $HEAD.Substring(0, 8);
  }
}

function Write-PromptStatus {
  if ($script:last) {
    Write-PromptSegment ' ✅ ' Green Black
  } else {
    Write-PromptSegment " ❌ $lastexitcode " Red White
  }
}

function Write-PromptUser {
  Write-PromptSegment " $env:USERNAME " Yellow White;
}

function Write-PromptVirtualEnv {
  if ($env:VIRTUAL_ENV) {
    Write-PromptSegment " $(Split-Path $env:VIRTUAL_ENV -Leaf) " Cyan Black
  }
}

function Write-PromptDirectory {
  Write-PromptSegment " $(Get-DecoratedPrompt) " DarkYellow White
}

# Depends on posh-git
function Write-PromptGit {
  if (Get-GitDirectory) {
    Write-PromptSegment "  $(Get-GitBranch) " Blue White
  }
}

function Get-PowerlineGlyphs {
  "                                     "
}

function prompt {
  $script:last = $?;
  $script:first = $true;

  # Write-Host "$(((H)[-1].EndExecutionTime - (H)[-1].StartExecutionTime).Milliseconds) ms" -NoNewline -ForegroundColor Gray

  Write-PromptVirtualEnv
  Write-PromptDirectory
  Write-PromptGit

  Write-DecoratedPromptEnd

  # Load .env if there is one.
  Set-Env

  return ' '
}
