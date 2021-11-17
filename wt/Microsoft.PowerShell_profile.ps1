using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# Tests if given command exists
# Adapted from https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
function Test-CommandExists ([string] $command) {
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = 'stop'
  try { if (Get-Command $command) { $true } }
  catch { $false }
  finally { $ErrorActionPreference = $oldPreference }
}

New-Alias which Get-Command

function Mount-ExternalFileSystem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline)]
    [ValidateRange(0, 65535)]
    [int]
    $Port
  )
  Invoke-Expression "sshfs-win svc \sshfs.kr\vech.ro!$Port X:"
}

function Add-BuildTools {
  cmd.exe /c "call `"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat`" && set > %temp%\vcvars.txt"

  Get-Content "$env:temp\vcvars.txt" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
      Set-Content "env:\$($matches[1])" $matches[2]
    }
  }
}

# Credit to https://github.com/rajivharris/Set-PsEnv
function Set-Env {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
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

# Due to iex being a default alias for Invoke-Expression I prefer to use this shorthand
# because overwriting a default alias can have unwanted effects on external script execution
function rex {
  Invoke-Expression "iex.bat -S mix"
}

# Launches iex in separate erlang shell with proper support for UTF-8
function wex {
  Invoke-Expression "iex.bat --werl -S mix"
}

# Defines markdown rendered Elixir help depending on if you have glow installed or not
if (Test-CommandExists "glow") {
  # Prints documentation formatted with Glow for any Elixir function either in the console or the browser
  function exh ([string] $Name = "h", [switch] $UseBrowser) {
    if ($UseBrowser.IsPresent) {
      Invoke-Expression "elixir -e 'import IEx.Helpers; h $Name'" | Out-String | Show-Markdown -UseBrowser
    } else {
      Invoke-Expression "elixir -e 'import IEx.Helpers; h $Name'" | Out-String | glow - -w 70
    }
  }
} else {
  # Prints documentation formatted with native Powershell functions for any Elixir function either in the console or the browser
  function exh ([string] $Name = "h", [switch] $UseBrowser) {
    if ($UseBrowser.IsPresent) {
      Invoke-Expression "elixir -e 'import IEx.Helpers; h $Name'" | Out-String | Show-Markdown -UseBrowser
    } else {
      $text = Invoke-Expression "elixir -e 'import IEx.Helpers; h $Name'" | Out-String -Stream
      $text.Split("\n") | ForEach-Object -Process { $_.Trim() } | Out-String | Show-Markdown
    }
  }
}

# Open parent of given directory in explorer
function open {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline)]
    [string] $Path
  )
  Split-Path -Parent $Path | Invoke-Item
}

Import-Module posh-git

# Open current directory in explorer when pressing Ctrl+E
Set-PSReadLineKeyHandler -Key Ctrl+e -ScriptBlock { Invoke-Item . }

Set-PSReadLineOption -EditMode Windows -PredictionSource History -PredictionViewStyle ListView

# The Windows terminal does not use UTF-8 by default, the following line changes that
# chcp 65001

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
  } else {
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
  if ($global:admin) {
    Write-PromptSegment ' # ADMIN ' Magenta White;
  } else {
    Write-PromptSegment " $env:USERNAME " Yellow White;
  }
}

function Write-PromptVirtualEnv {
  if ($env:VIRTUAL_ENV) {
    Write-PromptSegment " $(Split-Path $env:VIRTUAL_ENV -Leaf) " Cyan Black
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

function Get-PowerlineReference {
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

  # Load .env if there is one.
  Set-Env

  return ' '
}

# Rustup completions
Register-ArgumentCompleter -Native -CommandName 'rustup' -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)

  $commandElements = $commandAst.CommandElements
  $command = @(
    'rustup'
    for ($i = 1; $i -lt $commandElements.Count; $i++) {
      $element = $commandElements[$i]
      if ($element -isnot [StringConstantExpressionAst] -or
        $element.StringConstantType -ne [StringConstantType]::BareWord -or
        $element.Value.StartsWith('-')) {
        break
      }
      $element.Value
    }) -join ';'

  $completions = @(switch ($command) {
      'rustup' {
        [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Enable verbose output')
        [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Enable verbose output')
        [CompletionResult]::new('-q', 'q', [CompletionResultType]::ParameterName, 'Disable progress output')
        [CompletionResult]::new('--quiet', 'quiet', [CompletionResultType]::ParameterName, 'Disable progress output')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('dump-testament', 'dump-testament', [CompletionResultType]::ParameterValue, 'Dump information about the build')
        [CompletionResult]::new('show', 'show', [CompletionResultType]::ParameterValue, 'Show the active and installed toolchains or profiles')
        [CompletionResult]::new('install', 'install', [CompletionResultType]::ParameterValue, 'Update Rust toolchains')
        [CompletionResult]::new('uninstall', 'uninstall', [CompletionResultType]::ParameterValue, 'Uninstall Rust toolchains')
        [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Update Rust toolchains and rustup')
        [CompletionResult]::new('check', 'check', [CompletionResultType]::ParameterValue, 'Check for updates to Rust toolchains')
        [CompletionResult]::new('default', 'default', [CompletionResultType]::ParameterValue, 'Set the default toolchain')
        [CompletionResult]::new('toolchain', 'toolchain', [CompletionResultType]::ParameterValue, 'Modify or query the installed toolchains')
        [CompletionResult]::new('target', 'target', [CompletionResultType]::ParameterValue, 'Modify a toolchain''s supported targets')
        [CompletionResult]::new('component', 'component', [CompletionResultType]::ParameterValue, 'Modify a toolchain''s installed components')
        [CompletionResult]::new('override', 'override', [CompletionResultType]::ParameterValue, 'Modify directory toolchain overrides')
        [CompletionResult]::new('run', 'run', [CompletionResultType]::ParameterValue, 'Run a command with an environment configured for a given toolchain')
        [CompletionResult]::new('which', 'which', [CompletionResultType]::ParameterValue, 'Display which binary will be run for a given command')
        [CompletionResult]::new('doc', 'doc', [CompletionResultType]::ParameterValue, 'Open the documentation for the current toolchain')
        [CompletionResult]::new('self', 'self', [CompletionResultType]::ParameterValue, 'Modify the rustup installation')
        [CompletionResult]::new('set', 'set', [CompletionResultType]::ParameterValue, 'Alter rustup settings')
        [CompletionResult]::new('completions', 'completions', [CompletionResultType]::ParameterValue, 'Generate tab-completion scripts for your shell')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;dump-testament' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;show' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('active-toolchain', 'active-toolchain', [CompletionResultType]::ParameterValue, 'Show the active toolchain')
        [CompletionResult]::new('home', 'home', [CompletionResultType]::ParameterValue, 'Display the computed value of RUSTUP_HOME')
        [CompletionResult]::new('profile', 'profile', [CompletionResultType]::ParameterValue, 'Show the current profile')
        [CompletionResult]::new('keys', 'keys', [CompletionResultType]::ParameterValue, 'Display the known PGP keys')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;show;active-toolchain' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;show;home' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;show;profile' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;show;keys' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;show;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;install' {
        [CompletionResult]::new('--profile', 'profile', [CompletionResultType]::ParameterName, 'profile')
        [CompletionResult]::new('--no-self-update', 'no-self-update', [CompletionResultType]::ParameterName, 'Don''t perform self-update when running the `rustup install` command')
        [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Force an update, even if some components are missing')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;uninstall' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;update' {
        [CompletionResult]::new('--no-self-update', 'no-self-update', [CompletionResultType]::ParameterName, 'Don''t perform self update when running the `rustup update` command')
        [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Force an update, even if some components are missing')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;check' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;default' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;toolchain' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List installed toolchains')
        [CompletionResult]::new('install', 'install', [CompletionResultType]::ParameterValue, 'Install or update a given toolchain')
        [CompletionResult]::new('uninstall', 'uninstall', [CompletionResultType]::ParameterValue, 'Uninstall a toolchain')
        [CompletionResult]::new('link', 'link', [CompletionResultType]::ParameterValue, 'Create a custom toolchain by symlinking to a directory')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;toolchain;list' {
        [CompletionResult]::new('-v', 'v', [CompletionResultType]::ParameterName, 'Enable verbose output with toolchain information')
        [CompletionResult]::new('--verbose', 'verbose', [CompletionResultType]::ParameterName, 'Enable verbose output with toolchain information')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;toolchain;install' {
        [CompletionResult]::new('--profile', 'profile', [CompletionResultType]::ParameterName, 'profile')
        [CompletionResult]::new('-c', 'c', [CompletionResultType]::ParameterName, 'Add specific components on installation')
        [CompletionResult]::new('--component', 'component', [CompletionResultType]::ParameterName, 'Add specific components on installation')
        [CompletionResult]::new('-t', 't', [CompletionResultType]::ParameterName, 'Add specific targets on installation')
        [CompletionResult]::new('--target', 'target', [CompletionResultType]::ParameterName, 'Add specific targets on installation')
        [CompletionResult]::new('--no-self-update', 'no-self-update', [CompletionResultType]::ParameterName, 'Don''t perform self update when running the`rustup toolchain install` command')
        [CompletionResult]::new('--force', 'force', [CompletionResultType]::ParameterName, 'Force an update, even if some components are missing')
        [CompletionResult]::new('--allow-downgrade', 'allow-downgrade', [CompletionResultType]::ParameterName, 'Allow rustup to downgrade the toolchain to satisfy your component choice')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;toolchain;uninstall' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;toolchain;link' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;toolchain;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;target' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List installed and available targets')
        [CompletionResult]::new('add', 'add', [CompletionResultType]::ParameterValue, 'Add a target to a Rust toolchain')
        [CompletionResult]::new('remove', 'remove', [CompletionResultType]::ParameterValue, 'Remove a target from a Rust toolchain')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;target;list' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('--installed', 'installed', [CompletionResultType]::ParameterName, 'List only installed targets')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;target;add' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;target;remove' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;target;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;component' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List installed and available components')
        [CompletionResult]::new('add', 'add', [CompletionResultType]::ParameterValue, 'Add a component to a Rust toolchain')
        [CompletionResult]::new('remove', 'remove', [CompletionResultType]::ParameterValue, 'Remove a component from a Rust toolchain')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;component;list' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('--installed', 'installed', [CompletionResultType]::ParameterName, 'List only installed components')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;component;add' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('--target', 'target', [CompletionResultType]::ParameterName, 'target')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;component;remove' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('--target', 'target', [CompletionResultType]::ParameterName, 'target')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;component;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;override' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('list', 'list', [CompletionResultType]::ParameterValue, 'List directory toolchain overrides')
        [CompletionResult]::new('set', 'set', [CompletionResultType]::ParameterValue, 'Set the override toolchain for a directory')
        [CompletionResult]::new('unset', 'unset', [CompletionResultType]::ParameterValue, 'Remove the override toolchain for a directory')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;override;list' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;override;set' {
        [CompletionResult]::new('--path', 'path', [CompletionResultType]::ParameterName, 'Path to the directory')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;override;unset' {
        [CompletionResult]::new('--path', 'path', [CompletionResultType]::ParameterName, 'Path to the directory')
        [CompletionResult]::new('--nonexistent', 'nonexistent', [CompletionResultType]::ParameterName, 'Remove override toolchain for all nonexistent directories')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;override;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;run' {
        [CompletionResult]::new('--install', 'install', [CompletionResultType]::ParameterName, 'Install the requested toolchain if needed')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;which' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;doc' {
        [CompletionResult]::new('--toolchain', 'toolchain', [CompletionResultType]::ParameterName, 'Toolchain name, such as ''stable'', ''nightly'', or ''1.8.0''. For more information see `rustup help toolchain`')
        [CompletionResult]::new('--path', 'path', [CompletionResultType]::ParameterName, 'Only print the path to the documentation')
        [CompletionResult]::new('--alloc', 'alloc', [CompletionResultType]::ParameterName, 'The Rust core allocation and collections library')
        [CompletionResult]::new('--book', 'book', [CompletionResultType]::ParameterName, 'The Rust Programming Language book')
        [CompletionResult]::new('--cargo', 'cargo', [CompletionResultType]::ParameterName, 'The Cargo Book')
        [CompletionResult]::new('--core', 'core', [CompletionResultType]::ParameterName, 'The Rust Core Library')
        [CompletionResult]::new('--edition-guide', 'edition-guide', [CompletionResultType]::ParameterName, 'The Rust Edition Guide')
        [CompletionResult]::new('--nomicon', 'nomicon', [CompletionResultType]::ParameterName, 'The Dark Arts of Advanced and Unsafe Rust Programming')
        [CompletionResult]::new('--proc_macro', 'proc_macro', [CompletionResultType]::ParameterName, 'A support library for macro authors when defining new macros')
        [CompletionResult]::new('--reference', 'reference', [CompletionResultType]::ParameterName, 'The Rust Reference')
        [CompletionResult]::new('--rust-by-example', 'rust-by-example', [CompletionResultType]::ParameterName, 'A collection of runnable examples that illustrate various Rust concepts and standard libraries')
        [CompletionResult]::new('--rustc', 'rustc', [CompletionResultType]::ParameterName, 'The compiler for the Rust programming language')
        [CompletionResult]::new('--rustdoc', 'rustdoc', [CompletionResultType]::ParameterName, 'Generate documentation for Rust projects')
        [CompletionResult]::new('--std', 'std', [CompletionResultType]::ParameterName, 'Standard library API documentation')
        [CompletionResult]::new('--test', 'test', [CompletionResultType]::ParameterName, 'Support code for rustc''s built in unit-test and micro-benchmarking framework')
        [CompletionResult]::new('--unstable-book', 'unstable-book', [CompletionResultType]::ParameterName, 'The Unstable Book')
        [CompletionResult]::new('--embedded-book', 'embedded-book', [CompletionResultType]::ParameterName, 'The Embedded Rust Book')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;self' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('update', 'update', [CompletionResultType]::ParameterValue, 'Download and install updates to rustup')
        [CompletionResult]::new('uninstall', 'uninstall', [CompletionResultType]::ParameterValue, 'Uninstall rustup.')
        [CompletionResult]::new('upgrade-data', 'upgrade-data', [CompletionResultType]::ParameterValue, 'Upgrade the internal data format.')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;self;update' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;self;uninstall' {
        [CompletionResult]::new('-y', 'y', [CompletionResultType]::ParameterName, 'y')
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;self;upgrade-data' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;self;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;set' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('default-host', 'default-host', [CompletionResultType]::ParameterValue, 'The triple used to identify toolchains when not specified')
        [CompletionResult]::new('profile', 'profile', [CompletionResultType]::ParameterValue, 'The default components installed')
        [CompletionResult]::new('help', 'help', [CompletionResultType]::ParameterValue, 'Prints this message or the help of the given subcommand(s)')
        break
      }
      'rustup;set;default-host' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;set;profile' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;set;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;completions' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
      'rustup;help' {
        [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Prints help information')
        [CompletionResult]::new('-V', 'V', [CompletionResultType]::ParameterName, 'Prints version information')
        [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Prints version information')
        break
      }
    })

  $completions.Where{ $_.CompletionText -like "$wordToComplete*" } |
  Sort-Object -Property ListItemText
}