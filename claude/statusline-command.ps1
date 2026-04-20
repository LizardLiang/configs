# Claude Code Detailed Status Line Script
# Shows: git branch, model, directory, and context usage bar (with color)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ANSI color helpers
$ESC = [char]27
function ansi($code) { return "$ESC[${code}m" }
$RESET  = ansi '0'
$BOLD   = ansi '1'
$DIM    = ansi '2'
# Foreground colors
$FG_GREEN   = ansi '32'
$FG_YELLOW  = ansi '33'
$FG_RED     = ansi '31'
$FG_CYAN    = ansi '36'
$FG_BLUE    = ansi '34'
$FG_WHITE   = ansi '37'
$FG_GRAY    = ansi '90'
$FG_MAGENTA = ansi '35'

try {
    # Read JSON input from stdin
    $inputData = [Console]::In.ReadToEnd() | ConvertFrom-Json

    # Extract information
    $model = $inputData.model.display_name
    $cwd = $inputData.workspace.current_dir
    $projectDir = $inputData.workspace.project_dir

    # Calculate relative path from project root
    $relPath = '.'
    if ($cwd -and $projectDir -and $cwd.StartsWith($projectDir)) {
        $relative = $cwd.Substring($projectDir.Length).TrimStart('\', '/')
        if (-not [string]::IsNullOrEmpty($relative)) { $relPath = $relative }
    } elseif ($cwd) {
        $relPath = Split-Path $cwd -Leaf
    }

    # Calculate context window usage with colored progress bar
    $contextInfo = ''
    if ($null -ne $inputData.context_window -and $null -ne $inputData.context_window.current_usage) {
        $usage = $inputData.context_window.current_usage
        $currentTokens = 0
        if ($null -ne $usage.input_tokens) { $currentTokens += $usage.input_tokens }
        if ($null -ne $usage.cache_creation_input_tokens) { $currentTokens += $usage.cache_creation_input_tokens }
        if ($null -ne $usage.cache_read_input_tokens) { $currentTokens += $usage.cache_read_input_tokens }

        $contextWindowSize = $inputData.context_window.context_window_size

        if ($contextWindowSize -gt 0) {
            $percentage = [math]::Floor(($currentTokens * 100) / $contextWindowSize)

            # Create progress bar (10 segments) using Unicode
            $barLength = 10
            $filled = [math]::Floor(($percentage / 100) * $barLength)
            if ($filled -lt 0) { $filled = 0 }
            if ($filled -gt $barLength) { $filled = $barLength }
            $empty = $barLength - $filled

            $filledBar = "${FG_CYAN}$("▰" * $filled)${RESET}"
            $emptyBar  = "${FG_CYAN}$("▱" * $empty)${RESET}"
            $contextInfo = "${FG_CYAN}ctx${RESET}:[${filledBar}${emptyBar}] ${FG_CYAN}${percentage}%${RESET}"
        }
    }

    # Add total tokens information
    $tokensInfo = ''
    if ($null -ne $inputData.context_window) {
        $totalInput = $inputData.context_window.total_input_tokens
        $totalOutput = $inputData.context_window.total_output_tokens
        if ($null -ne $totalInput -and $null -ne $totalOutput) {
            $formatTokens = {
                param($value)
                if ($value -ge 1000) {
                    return "$([math]::Round($value / 1000, 1))K"
                } else {
                    return "$value"
                }
            }
            $inStr  = & $formatTokens $totalInput
            $outStr = & $formatTokens $totalOutput
            $tokensInfo = "${FG_GRAY}in:${RESET}${inStr} ${FG_GRAY}out:${RESET}${outStr}"
        }
    }

    # Calculate rate limit information with colored progress bars
    $rateLimitInfo = ''
    if ($null -ne $inputData.rate_limits) {
        $parts = @()
        $rlBarLength = 10
        if ($null -ne $inputData.rate_limits.five_hour) {
            $fivePct    = [math]::Round($inputData.rate_limits.five_hour.used_percentage, 0)
            $fiveFilled = [math]::Floor(($fivePct / 100) * $rlBarLength)
            if ($fiveFilled -lt 0) { $fiveFilled = 0 }
            if ($fiveFilled -gt $rlBarLength) { $fiveFilled = $rlBarLength }
            $fiveEmpty  = $rlBarLength - $fiveFilled
            $fiveBar    = "${FG_YELLOW}$("▰" * $fiveFilled)${RESET}${FG_YELLOW}$("▱" * $fiveEmpty)${RESET}"
            $parts += "${FG_YELLOW}5h${RESET}:[${fiveBar}] ${FG_YELLOW}${fivePct}%${RESET}"
        }
        if ($null -ne $inputData.rate_limits.seven_day) {
            $weekPct    = [math]::Round($inputData.rate_limits.seven_day.used_percentage, 0)
            $weekFilled = [math]::Floor(($weekPct / 100) * $rlBarLength)
            if ($weekFilled -lt 0) { $weekFilled = 0 }
            if ($weekFilled -gt $rlBarLength) { $weekFilled = $rlBarLength }
            $weekEmpty  = $rlBarLength - $weekFilled
            $weekBar    = "${FG_MAGENTA}$("▰" * $weekFilled)${RESET}${FG_MAGENTA}$("▱" * $weekEmpty)${RESET}"
            $parts += "${FG_MAGENTA}7d${RESET}:[${weekBar}] ${FG_MAGENTA}${weekPct}%${RESET}"
        }
        if ($parts.Count -gt 0) {
            $rateLimitInfo = $parts -join " ${DIM}|${RESET} "
        }
    }

    # Get git branch
    $gitBranch = ''
    if ($cwd -and (Test-Path $cwd)) {
        Push-Location $cwd
        try {
            $gitInfo = git branch --show-current 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitInfo) {
                $gitBranch = $gitInfo.Trim()
            }
        } catch { }
        Pop-Location
    }

    # Build status line
    # Line 1: branch, model, path
    $line1 = ""
    if ($gitBranch) {
        $line1 += "${FG_BLUE}(${gitBranch})${RESET} "
    }
    $line1 += "${BOLD}${FG_WHITE}${model}${RESET}"

    # Line 2: context bar, tokens, rate limits (only when data is available)
    $line2Parts = @()
    if ($contextInfo -ne '') { $line2Parts += $contextInfo }
    if ($tokensInfo -ne '') { $line2Parts += $tokensInfo }
    if ($rateLimitInfo -ne '') { $line2Parts += $rateLimitInfo }

    # Line 3: relative path
    $line3 = "${DIM}${relPath}${RESET}"

    [Console]::WriteLine($line1)
    if ($line2Parts.Count -gt 0) {
        [Console]::WriteLine($line2Parts -join " ${DIM}|${RESET} ")
    }
    [Console]::WriteLine($line3)
} catch {
    [Console]::WriteLine("StatusLine Error: $_")
}
