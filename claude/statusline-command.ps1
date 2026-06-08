# Claude Code status line with ASCII context window chart
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ESC = [char]27
function ansi($code) { return "$ESC[${code}m" }

$RESET       = ansi '0'
$C_USER      = ansi '36'   # Cyan   — user@host:dir
$C_GIT       = ansi '33'   # Yellow — git branch
$C_MODEL     = ansi '35'   # Magenta — model name
$C_TIME      = ansi '37'   # Light gray — timestamp
$C_CTX_LABEL = ansi '32'   # Green — ctx label/bar/percentage
$C_CTX_EMPTY = ansi '90'   # Dark gray — context bar empty
$C_5H        = ansi '33'   # Yellow — 5h rate limit
$C_7D        = ansi '35'   # Magenta — 7d rate limit
$C_TOK       = ansi '96'   # Cyan bright — token counts
$C_SEP       = ansi '90'   # Dark gray — separators
$C_STAGED    = ansi '32'   # Green — staged changes
$C_UNSTAGED  = ansi '31'   # Red — unstaged changes
$C_PUSH      = ansi '33'   # Yellow — commits to push
$C_PULL      = ansi '36'   # Cyan — commits to pull

function Make-Bar {
    param($pct, $fillColor)
    $pctInt = [math]::Round([double]$pct, 0)
    $filled = [math]::Floor($pctInt * 10 / 100)
    if ($filled -lt 0)  { $filled = 0  }
    if ($filled -gt 10) { $filled = 10 }
    $empty = 10 - $filled
    $bar = ''
    for ($i = 0; $i -lt $filled; $i++) { $bar += "${fillColor}▰" }
    for ($i = 0; $i -lt $empty;  $i++) { $bar += "${C_CTX_EMPTY}▱" }
    return $bar
}

function Format-Tokens {
    param($n)
    if ($n -ge 1000) { return "$([math]::Round($n / 1000.0, 1))k" }
    return "$n"
}

try {
    $inputData = [Console]::In.ReadToEnd() | ConvertFrom-Json

    $userName  = $env:USERNAME
    $hostName  = $env:COMPUTERNAME
    $dir       = $inputData.workspace.current_dir
    $model     = $inputData.model.display_name
    $timestamp = Get-Date -Format 'HH:mm:ss'

    $remaining = $inputData.context_window.remaining_percentage
    $used      = $inputData.context_window.used_percentage
    $totalIn   = $inputData.context_window.total_input_tokens
    $totalOut  = $inputData.context_window.total_output_tokens

    $sep = "${C_SEP}|${RESET}"

    # Line 1: user@host:dir | model | timestamp
    [Console]::WriteLine("${C_USER}${userName}@${hostName}:${dir}${RESET} $sep ${C_MODEL}${model}${RESET} $sep ${C_TIME}${timestamp}${RESET}")

    # Line 2: ctx | 5h | 7d | tokens (only when context data is available)
    if ($null -ne $remaining -and $null -ne $used) {
        $ctxBar = Make-Bar $used $C_CTX_LABEL
        $remInt = [math]::Round([double]$remaining, 0)
        $line2  = "${C_CTX_LABEL}ctx:[${ctxBar}${C_CTX_LABEL}] ${remInt}%${RESET}"

        $fivePct = $inputData.rate_limits.five_hour.used_percentage
        if ($null -ne $fivePct) {
            $bar5    = Make-Bar $fivePct $C_5H
            $fiveInt = [math]::Round([double]$fivePct, 0)
            $line2  += " $sep ${C_5H}5h:[${bar5}${C_5H}] ${fiveInt}%${RESET}"
        }

        $weekPct = $inputData.rate_limits.seven_day.used_percentage
        if ($null -ne $weekPct) {
            $bar7    = Make-Bar $weekPct $C_7D
            $weekInt = [math]::Round([double]$weekPct, 0)
            $line2  += " $sep ${C_7D}7d:[${bar7}${C_7D}] ${weekInt}%${RESET}"
        }

        if ($null -ne $totalIn -and $null -ne $totalOut) {
            $inFmt  = Format-Tokens $totalIn
            $outFmt = Format-Tokens $totalOut
            $line2 += " $sep ${C_TOK}in:${inFmt} out:${outFmt}${RESET}"
        }

        [Console]::WriteLine($line2)
    }

    # Line 3: git status (only inside a git repo)
    if ($dir -and (Test-Path $dir)) {
        Push-Location $dir
        try {
            git rev-parse --git-dir 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $branch = git -c core.useReplaceRefs=false rev-parse --abbrev-ref HEAD 2>$null
                if (-not $branch) { $branch = 'unknown' }

                $staged   = @(git -c core.useReplaceRefs=false diff --cached --name-only 2>$null).Count
                $unstaged = @(git -c core.useReplaceRefs=false diff --name-only 2>$null).Count

                $ahead  = 0
                $behind = 0
                $remote = git -c core.useReplaceRefs=false rev-parse --abbrev-ref '@{upstream}' 2>$null
                if ($remote) {
                    $aheadStr  = git -c core.useReplaceRefs=false rev-list --count '@{upstream}..HEAD' 2>$null
                    $behindStr = git -c core.useReplaceRefs=false rev-list --count 'HEAD..@{upstream}' 2>$null
                    if ($aheadStr)  { $ahead  = [int]$aheadStr  }
                    if ($behindStr) { $behind = [int]$behindStr }
                }

                $gitLine  = "${C_GIT}branch:${branch}${RESET}"
                $gitLine += " $sep ${C_STAGED}staged:${staged}${RESET}"
                $gitLine += " $sep ${C_UNSTAGED}unstaged:${unstaged}${RESET}"
                $gitLine += " $sep ${C_PUSH}push:${ahead}${RESET}"
                $gitLine += " $sep ${C_PULL}pull:${behind}${RESET}"

                [Console]::WriteLine($gitLine)
            }
        } catch { } finally {
            Pop-Location
        }
    }
} catch {
    [Console]::WriteLine("StatusLine Error: $_")
}
