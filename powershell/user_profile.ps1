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

#ZLocation
Import-Module ZLocation

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

Set-Alias g git
Set-Alias gcz 'C:\Program Files\Git\cmd\git.exe cz'
Set-Alias grep findstr
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'
Set-Alias cc 'Set-Clipboard'

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
    param(
        [string]$Path
    )

    $global:LastDirectory = if (-not $global:LastDirectory) { Get-Location } else { $global:LastDirectory }

    if ($Path -eq '-') {
        $temp = Get-Location
        Set-Location $global:LastDirectory
        $global:LastDirectory = $temp
    }
    else {
        $global:LastDirectory = Get-Location
        Set-Location $Path
    }
}

del alias:cd -Force
Set-Alias -Name cd -Value z

function copy-path() {
    (Get-Location).Path | Set-Clipboard
}

Set-Alias -Name cppath -Value copy-path
Set-Alias -Name e -Value explorer

[System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8
