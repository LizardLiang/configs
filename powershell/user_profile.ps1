# Prompt
Import-Module posh-git
oh-my-posh init pwsh --config "${HOME}\.config\powershell\lizard.omg.json"  | Invoke-Expression

# Load prompt setting
#function Get-ScriptDirectory { Split-Path $MyInvocation.ScriptName }
#$PROMPT_CONFIG = Join-Path (Get-ScriptDirectory) 'lizard.omg.json'
#oh-my-posh --init --shell pwsh --config $PROMPT_CONFIG | Invoke-Expression

# Icons
Import-Module Terminal-icons

# PSReadline
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'
$env:FZF_DEFAULT_OPTS="--bind 'ctrl-y:execute-silent(echo {} | clip)+abort'"

# Alias
Set-Alias vim nvim
Set-Alias v vim

function ls-less {
  Get-ChildItem $args | less -r
}

Set-Alias -Name lsl -Value ls-less

Set-Alias ll ls

function ls-force {
    Get-ChildItem -Force $args | less -r
}
Set-Alias -Name la -Value ls-force 

$scoopDir = "$env:USERPROFILE\scoop"
$lessPath = "$scoopDir\apps\git\current\usr\bin\less.exe"

Set-Alias g git
Set-Alias gcz 'C:\Program Files\Git\cmd\git.exe cz'
Set-Alias grep findstr
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
Set-Alias less $lessPath
Set-Alias cc 'Set-Clipboard'
Set-Alias c 'claude'

# Git alias
function git-log-graph  { g log --graph --decorate --oneline }
Set-Alias -Name glg -Value git-log-graph

function git-diff { git diff }
Set-Alias -Name gd -Value git-diff

function git-checkout { git checkout $args }
Set-Alias -Name gco -Value git-checkout

function git-fetch { git fetch }
Set-Alias -Name gf -Value git-fetch

function git-pull { git pull $args }
Set-Alias -Name gpl -Value git-pull

del alias:gp -Force
function git-push { git push $args }
Set-Alias -Name gp -Value git-push

function git-branch { git branch $args }
Set-Alias -Name gb -Value git-branch

function git-status { git status }
Set-Alias -Name gs -Value git-status

del alias:gc -Force
function git-commit { git commit $args }
Set-Alias -Name gc -Value git-commit

function back-dir { cd .. }
Set-Alias -Name .. -Value back-dir

Set-Alias -Name lg -Value lazygit

# Utilities
function which ($command) {
  Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# To keep track of the last directory
function Change-Directory {
    # Get the current directory
    $cwd = Get-Location

    # Send OSC 7 escape sequence to update the terminal emulator
    $osc7 = "$([char]27)]7;file://$($cwd.ProviderPath)$([char]7)"
    [console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Host -NoNewline $osc7

    $osc99 = "$([char]27)]99;file://$($cwd.ProviderPath)$([char]9)"
    [console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Host -NoNewline $osc99
}

Set-Alias -Name clang -Value clang64

function copy-path() {
    (Get-Location).Path | Set-Clipboard
}

Set-Alias -Name cppath -Value copy-path
Set-Alias -Name e -Value explorer

[System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Convert Windows shitty path to Unix-like path
function ConvertWindowsDelimiterToUnix {
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$args
  )

  for($i = 0; $i -lt $args.Count; $i++) {
    if(-not $args[$i].Contains('\')) {continue}
    $args[$i] = $args[$i] -replace '\\', '/'
  }

  return $args
}

# Utilities that empower the wsl commands

function wsl-tree {
  $convertedArgs = ConvertWindowsDelimiterToUnix $args
  wsl /home/linuxbrew/.linuxbrew/bin/tree $convertedArgs
}

Set-Alias -Name tree -Value wsl-tree

. $HOME\.config\powershell\env_profile.ps1

Invoke-Expression (& { (zoxide init powershell | Out-String) })

Set-Alias -Name cd -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name cdi -Value __zoxide_zi -Option AllScope -Scope Global -Force

function ai-generate-commit() {
  uv run git-diff --no-add --confirm
}
Set-Alias -Name aigc -Value ai-generate-commit -Scope Global

function Append-LinusRole {
    Get-Content "${HOME}\.config\ai-helpers\prompts\linus-role.md" | Add-Content ".\CLAUDE.md"
    Write-Host "Appended linus-role.md to CLAUDE.md" -ForegroundColor Green
}
Set-Alias alr Append-LinusRole

function Enable-CopilotServer {
    $env:ANTHROPIC_BASE_URL = "http://localhost:4141"
    $env:ANTHROPIC_API_KEY = "sk-dummy"
    Write-Host "Copilot server environment enabled" -ForegroundColor Green
}

function Disable-CopilotServer {
    Remove-Item env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    Write-Host "Copilot server environment disabled" -ForegroundColor Yellow
}

Set-Alias copilot-on Enable-CopilotServer
Set-Alias copilot-off Disable-CopilotServer
