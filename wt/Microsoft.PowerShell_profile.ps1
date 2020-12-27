Function dial {
  Invoke-Expression "sshfs-win svc \sshfs.kr\root@vech.ro!22 X:"
}

# Due to iex being a default alias for Invoke-Expression I prefer to use this shorthand
# because overwriting a default alias can have unwanted effects on external script execution
Function rex {
  Invoke-Expression "iex.bat -S mix"
}

# Launches iex in separate erlang shell with proper support for UTF-8
Function wex {
  Invoke-Expression "iex.bat --werl -S mix"
}

# Prints formatted documentation for any Elixir function either in the console or the browser
Function exh ([String] $Name = "h", [Switch] $UseBrowser) {
  if ($UseBrowser.IsPresent) {
    $text = Invoke-Expression "elixir -e 'import IEx.Helpers; h $Name'" | Out-String | Show-Markdown -UseBrowser
  }
  else {
    $text = Invoke-Expression "elixir -e 'import IEx.Helpers; h $Name'" | Out-String -Stream
    $text.Split("\n") | ForEach-Object -Process { $_.Trim() } | Out-String | Show-Markdown
  }
}

# Open current directory in explorer
Set-PSReadLineKeyHandler -Key Ctrl+e -ScriptBlock { Invoke-Item . }

# The Windows terminal does not use UTF-8 by default, the following line changes that
chcp 65001

Import-Module posh-git

$script:bg = [Console]::BackgroundColor;
$script:first = $true;
$script:last = 0;

function Write-PromptFancyEnd {
  Write-Host  -NoNewline -ForegroundColor $script:bg

  $script:bg = [System.ConsoleColor]::Black
}

function Write-PromptSegment {
  param(
    [Parameter(
      Position = 0,
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true
    )][string]$Text,

    [Parameter(Position = 1)][System.ConsoleColor] $Background = [Console]::BackgroundColor,
    [Parameter(Position = 2)][System.ConsoleColor] $Foreground = [System.ConsoleColor]::White
  )

  if (!$script:first) {
    Write-Host  -NoNewline -BackgroundColor $Background -ForegroundColor $script:bg
  }
  else {
    $script:first = $false
  }

  Write-Host $Text -NoNewline -BackgroundColor $Background -ForegroundColor $Foreground

  $script:bg = $Background;
}

function Get-FancyDir {
  return $(Get-Location).ToString().Replace($env:USERPROFILE, '~').Replace('\', '  ');
}

function Get-GitBranch {
  $HEAD = Get-Content $(Join-Path $(Get-GitDirectory) HEAD)
  if ($HEAD -like 'ref: refs/heads/*') {
    return $HEAD -replace 'ref: refs/heads/(.*?)', "$1";
  }
  else {
    return $HEAD.Substring(0, 8);
  }
}

function Write-PromptStatus {
  if ($script:last) {
    Write-PromptSegment ' ✅ ' Green Black
  }
  else {
    Write-PromptSegment " ❌ $lastexitcode " Red White
  }
}

function Write-PromptUser {
  if ($global:admin) {
    Write-PromptSegment ' # ADMIN ' Magenta White;
  }
  else {
    Write-PromptSegment " $env:USERNAME " Yellow White;
  }
}

function Write-PromptVirtualEnv {
  if ($env:VIRTUAL_ENV) {
    Write-PromptSegment " $(split-path $env:VIRTUAL_ENV -leaf) " Cyan Black
  }
}

function Write-PromptDir {
  Write-PromptSegment " $(Get-FancyDir) " DarkYellow White
}

# Depends on posh-git
function Write-PromptGit {
  if (Get-GitDirectory) {
    Write-PromptSegment "  $(Get-GitBranch) " Blue White
  }
}

function Reference {
  # Powerline character reference
  Write-Host "                                     "
}

function prompt {
  $script:last = $?;
  $script:first = $true;

  # Write-Host "$(((H)[-1].EndExecutionTime - (H)[-1].StartExecutionTime).Milliseconds) ms" -NoNewline -ForegroundColor Gray

  Write-PromptVirtualEnv
  Write-PromptDir
  Write-PromptGit

  Write-PromptFancyEnd

  return ' '
}Function dial {
  Invoke-Expression "sshfs-win svc \sshfs.kr\root@vech.ro!22 X:"
}

# Open current directory in explorer
Set-PSReadLineKeyHandler -Key Ctrl+e -ScriptBlock { Invoke-Item . }

Import-Module posh-git

$script:bg = [Console]::BackgroundColor;
$script:first = $true;
$script:last = 0;

function Write-PromptFancyEnd {
  Write-Host  -NoNewline -ForegroundColor $script:bg

  $script:bg = [System.ConsoleColor]::Black
}

function Write-PromptSegment {
  param(
    [Parameter(
      Position = 0,
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true
    )][string]$Text,

    [Parameter(Position = 1)][System.ConsoleColor] $Background = [Console]::BackgroundColor,
    [Parameter(Position = 2)][System.ConsoleColor] $Foreground = [System.ConsoleColor]::White
  )

  if (!$script:first) {
    Write-Host  -NoNewline -BackgroundColor $Background -ForegroundColor $script:bg
  }
  else {
    $script:first = $false
  }

  Write-Host $text -NoNewline -BackgroundColor $Background -ForegroundColor $Foreground

  $script:bg = $Background;
}

function Get-FancyDir {
  return $(Get-Location).ToString().Replace($env:USERPROFILE, '~').Replace('\', '  ');
}

function Get-GitBranch {
  $HEAD = Get-Content $(Join-Path $(Get-GitDirectory) HEAD)
  if ($HEAD -like 'ref: refs/heads/*') {
    return $HEAD -replace 'ref: refs/heads/(.*?)', "$1";
  }
  else {
    return $HEAD.Substring(0, 8);
  }
}

function Write-PromptStatus {
  if ($script:last) {
    Write-PromptSegment ' ✅ ' Green Black
  }
  else {
    Write-PromptSegment " ❌ $lastexitcode " Red White
  }
}

function Write-PromptUser {
  if ($global:admin) {
    Write-PromptSegment ' # ADMIN ' Magenta White;
  }
  else {
    Write-PromptSegment " $env:USERNAME " Yellow White;
  }
}

function Write-PromptVirtualEnv {
  if ($env:VIRTUAL_ENV) {
    Write-PromptSegment " $(split-path $env:VIRTUAL_ENV -leaf) " Cyan Black
  }
}

function Write-PromptDir {
  Write-PromptSegment " $(Get-FancyDir) " DarkYellow White
}

# Depends on posh-git
function Write-PromptGit {
  if (Get-GitDirectory) {
    Write-PromptSegment "  $(Get-GitBranch) " Blue White
  }
}

function Reference {
  # Powerline character reference
  Write-Host "                                     "
}

function prompt {
  $script:last = $?;
  $script:first = $true;

  # Write-Host "$(((H)[-1].EndExecutionTime - (H)[-1].StartExecutionTime).Milliseconds) ms" -NoNewline -ForegroundColor Gray

  Write-PromptVirtualEnv
  Write-PromptDir
  Write-PromptGit

  Write-PromptFancyEnd

  return ' '
}