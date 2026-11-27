$ErrorActionPreference = 'Stop'

# Repo-specific compact validator for the fixed 5-skill release package.
# Spec: https://agentskills.io/specification
# Scope: Zero-dependency bounded frontmatter check (not a full YAML 1.2 parser; unsupported syntax fails closed).

$root = Split-Path -Parent $PSScriptRoot
$resolvedRoot = (Resolve-Path -LiteralPath $root).Path
$rootPrefix = $resolvedRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$skillsRoot = Join-Path $resolvedRoot 'skills'
$expected = @(
    'preventive-repair',
    'portable-tool-delivery',
    'workflow-automation-agent',
    'pr-review-agent',
    'output-contract'
)

function Get-SafeRelPath {
    param([Parameter(Mandatory)][string]$TargetPath)
    try { return [IO.Path]::GetRelativePath($resolvedRoot, $TargetPath) } catch { return [IO.Path]::GetFileName($TargetPath) }
}

function Assert-ContainedPath {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Item, [Parameter(Mandatory)][string]$AllowedPrefix)
    if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Symlink or junction is not allowed inside release scope: $(Get-SafeRelPath $Item.FullName)"
    }
    $full = [IO.Path]::GetFullPath($Item.FullName)
    if (-not $full.StartsWith($AllowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes allowed scope: $(Get-SafeRelPath $full)"
    }
}

if (-not (Test-Path -LiteralPath $skillsRoot)) { throw 'skills directory is missing.' }
Assert-ContainedPath -Item (Get-Item -LiteralPath $skillsRoot -Force) -AllowedPrefix $rootPrefix
$resolvedSkillsRoot = (Resolve-Path -LiteralPath $skillsRoot).Path
$skillsPrefix = $resolvedSkillsRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

function Unwrap-BoundedStringScalar {
    param([string]$Raw, [string]$SafePath)
    $v = $Raw.Trim()
    if ($v.Length -eq 0) { throw "Empty scalar value is not allowed: $SafePath" }
    if ($v -match '^[&*!\[\{]') { throw "Unsupported YAML construct in bounded validator: $SafePath" }
    if ($v.StartsWith("'") -and $v.EndsWith("'") -and $v.Length -ge 2) {
        return ($v.Substring(1, $v.Length - 2) -replace "''", "'")
    }
    if ($v.StartsWith('"') -and $v.EndsWith('"') -and $v.Length -ge 2) {
        return ($v.Substring(1, $v.Length - 2) -replace '\\"', '"' -replace '\\\\', '\')
    }
    if ($v.StartsWith("'") -or $v.StartsWith('"')) { throw "Unterminated quoted YAML string: $SafePath" }
    # Reject bare YAML 1.2 Core Schema non-string scalars (bool/null/int/float/sci/hex/oct/inf/nan) without echoing raw value
    $nonStringPattern = '^(?:' +
        'true|false|True|False|TRUE|FALSE|' +
        'null|Null|NULL|~|' +
        '[+-]?(?:\d[\d_]*(?:\.\d[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d[\d_]*)?|' +
        '0x[0-9a-fA-F_]+|0o[0-7_]+|' +
        '[+-]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN)' +
    ')$'
    if ($v -cmatch $nonStringPattern) {
        throw "Unquoted non-string YAML scalar is not valid for string fields (value redacted): $SafePath"
    }
    return $v
}

function Parse-CompactFrontmatter {
    param([string]$Text, [string]$SafePath)
    $clean = if ($Text.StartsWith([char]0xFEFF)) { $Text.Substring(1) } else { $Text }
    $lines = $clean -split "\r?\n"
    if ($lines.Count -lt 3 -or $lines[0].TrimEnd() -cne '---') { throw "Front matter must start on line 1 with '---': $SafePath" }
    $closeIdx = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd() -ceq '---') { $closeIdx = $i; break } }
    if ($closeIdx -le 1) { throw "Missing or empty front matter block: $SafePath" }

    $allowed = @('name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools')
    $fields = @{}
    $fm = $lines[1..($closeIdx - 1)]
    for ($i = 0; $i -lt $fm.Count; $i++) {
        $line = $fm[$i]
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') { continue }
        if ($line -match '^\t' -or $line -match '^\s') { throw "Unexpected indentation or tab in front matter: $SafePath" }
        if ($line -notmatch '^(?<k>[A-Za-z0-9_-]+)\s*:(?<rest>.*)$') { throw "Invalid front matter line syntax: $SafePath" }
        $k = $Matches['k']; $rest = $Matches['rest'].Trim()
        if ($k -cnotin $allowed) { throw "Unsupported or wrongly-cased front matter key (key redacted): $SafePath" }
        if ($fields.ContainsKey($k)) { throw "Duplicate front matter key '$k': $SafePath" }

        if ($k -eq 'metadata' -and $rest -eq '') {
            $map = @{}
            while (($i + 1) -lt $fm.Count -and ($fm[$i + 1] -match '^\s+' -or [string]::IsNullOrWhiteSpace($fm[$i + 1]))) {
                $i++; $sub = $fm[$i]
                if ([string]::IsNullOrWhiteSpace($sub) -or $sub -match '^\s*#') { continue }
                if ($sub -match '^\t' -or $sub -notmatch '^\s+(?<mk>[A-Za-z0-9_.-]+)\s*:(?<mv>.+)$') { throw "Invalid metadata entry syntax: $SafePath" }
                $mk = $Matches['mk']
                if ($map.ContainsKey($mk)) { throw "Duplicate metadata key (key redacted): $SafePath" }
                $map[$mk] = Unwrap-BoundedStringScalar -Raw $Matches['mv'] -SafePath $SafePath
            }
            $fields[$k] = $map; continue
        }
        if ($rest -cmatch '^[|>][+-]?$') {
            $parts = [System.Collections.Generic.List[string]]::new()
            while (($i + 1) -lt $fm.Count -and ($fm[$i + 1] -match '^ +' -or [string]::IsNullOrWhiteSpace($fm[$i + 1]))) {
                $i++; $sub = $fm[$i]
                if ($sub -match '^\t') { throw "Tabs are not allowed in block scalar: $SafePath" }
                $parts.Add($sub.Trim())
            }
            $joined = ($parts -join ' ').Trim()
            if ([string]::IsNullOrWhiteSpace($joined)) { throw "Empty block scalar for '$k': $SafePath" }
            $fields[$k] = $joined; continue
        }
        $fields[$k] = Unwrap-BoundedStringScalar -Raw $rest -SafePath $SafePath
    }
    return $fields
}

$actualDirs = Get-ChildItem -LiteralPath $resolvedSkillsRoot -Directory -Force
foreach ($d in $actualDirs) { Assert-ContainedPath -Item $d -AllowedPrefix $skillsPrefix }
$actual = @($actualDirs | Select-Object -ExpandProperty Name)
if (@(Compare-Object -ReferenceObject $expected -DifferenceObject $actual).Count -gt 0) {
    throw 'Unexpected skill directory set.'
}

# Phase A: Agent Skills spec checks
foreach ($name in $expected) {
    if ($name -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $name.Length -gt 64) { throw "Invalid skill directory name: $name" }
    $file = Join-Path (Join-Path $resolvedSkillsRoot $name) 'SKILL.md'
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing SKILL.md for skill '$name'." }
    Assert-ContainedPath -Item (Get-Item -LiteralPath $file -Force) -AllowedPrefix $skillsPrefix
    $safePath = Get-SafeRelPath $file

    $fm = Parse-CompactFrontmatter -Text (Get-Content -LiteralPath $file -Raw -Encoding UTF8) -SafePath $safePath
    if (-not $fm.ContainsKey('name') -or $fm['name'] -isnot [string] -or $fm['name'] -cne $name -or $fm['name'] -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $fm['name'].Length -gt 64) {
        throw "Invalid or mismatched front matter 'name' for directory '$name' (value redacted): $safePath"
    }
    if (-not $fm.ContainsKey('description') -or $fm['description'] -isnot [string]) { throw "Missing string 'description': $safePath" }
    $descLen = $fm['description'].Trim().Length
    if ($descLen -lt 1 -or $descLen -gt 1024) { throw "Description length ($descLen) must be 1..1024 chars: $safePath" }
    if ($fm.ContainsKey('compatibility')) {
        if ($fm['compatibility'] -isnot [string] -or $fm['compatibility'].Trim().Length -lt 1 -or $fm['compatibility'].Trim().Length -gt 500) {
            throw "Compatibility must be a 1..500 char string: $safePath"
        }
    }
    foreach ($sk in @('license', 'allowed-tools')) {
        if ($fm.ContainsKey($sk) -and ($fm[$sk] -isnot [string] -or [string]::IsNullOrWhiteSpace($fm[$sk]))) {
            throw "Front matter '$sk' must be a non-empty string: $safePath"
        }
    }
    if ($fm.ContainsKey('metadata') -and $fm['metadata'] -isnot [hashtable]) { throw "Front matter 'metadata' must be a mapping: $safePath" }
}

# Phase B: Scoped security scan (skills/ payload + root/docs Markdown; excludes scripts/validate.ps1 itself)
$blockedRules = @(
    @{ Id = 'win-user-path'; Pattern = 'C:\\Users\\' },
    @{ Id = 'mac-user-path'; Pattern = '/Users/' },
    @{ Id = 'auth-json'; Pattern = 'auth\.json' },
    @{ Id = 'history-jsonl'; Pattern = 'history\.jsonl' },
    @{ Id = 'dotenv-ref'; Pattern = '(?<![A-Za-z0-9_])\.env(?:\.[A-Za-z0-9_-]+)?(?![A-Za-z0-9_])' },
    @{ Id = 'token-assign'; Pattern = '(?i)\btoken\s*=\s*\S+' },
    @{ Id = 'password-assign'; Pattern = '(?i)\bpassword\s*=\s*\S+' },
    @{ Id = 'private-key'; Pattern = '-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----' },
    @{ Id = 'gh-classic-pat'; Pattern = 'ghp_[A-Za-z0-9_]{8,}' },
    @{ Id = 'gh-fine-pat'; Pattern = 'github_pat_[A-Za-z0-9_]{8,}' },
    @{ Id = 'slack-token'; Pattern = 'xoxb-[A-Za-z0-9-]{8,}' },
    @{ Id = 'google-api-key'; Pattern = 'AIza[0-9A-Za-z_-]{8,}' }
)
$payloadExts = @('.md', '.ps1', '.sh', '.py', '.yaml', '.yml', '.json', '.toml', '.txt')
$scanTargets = [System.Collections.Generic.List[string]]::new()

foreach ($item in Get-ChildItem -LiteralPath $resolvedSkillsRoot -Recurse -Force) {
    Assert-ContainedPath -Item $item -AllowedPrefix $skillsPrefix
    if (-not $item.PSIsContainer -and ($payloadExts -contains $item.Extension.ToLowerInvariant())) { $scanTargets.Add($item.FullName) }
}
foreach ($md in Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.md' -Force) {
    Assert-ContainedPath -Item $md -AllowedPrefix $rootPrefix
    $scanTargets.Add($md.FullName)
}
$docsDir = Join-Path $resolvedRoot 'docs'
if (Test-Path -LiteralPath $docsDir) {
    Assert-ContainedPath -Item (Get-Item -LiteralPath $docsDir -Force) -AllowedPrefix $rootPrefix
    $docsPrefix = (Resolve-Path -LiteralPath $docsDir).Path.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    foreach ($docItem in Get-ChildItem -LiteralPath $docsDir -Recurse -Force) {
        Assert-ContainedPath -Item $docItem -AllowedPrefix $docsPrefix
        if (-not $docItem.PSIsContainer -and $docItem.Extension.ToLowerInvariant() -eq '.md') { $scanTargets.Add($docItem.FullName) }
    }
}

foreach ($targetPath in $scanTargets) {
    $content = Get-Content -LiteralPath $targetPath -Raw -Encoding UTF8
    $relPath = Get-SafeRelPath $targetPath
    foreach ($rule in $blockedRules) {
        if ($content -match $rule.Pattern) {
            throw "Blocked sensitive pattern [$($rule.Id)] detected in release payload: $relPath"
        }
    }
}

Write-Output "Validation passed: $($expected.Count) skills, compact bounded spec checks, symlink guard, and $($scanTargets.Count) payload files scanned."
