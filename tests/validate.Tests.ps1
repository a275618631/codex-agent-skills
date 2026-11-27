$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("validate-tests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

$script:allOk = $true
$script:passCount = 0
$script:totalCount = 0

function Run-FixtureCase {
    param(
        [string]$Name,
        [bool]$ExpectPass,
        [scriptblock]$Mutate,
        [scriptblock]$CheckOutput = $null
    )
    $script:totalCount++
    $dir = Join-Path $workRoot $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts') -Destination $dir -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'skills') -Destination $dir -Recurse -Force
    foreach ($md in Get-ChildItem -LiteralPath $repoRoot -File -Filter '*.md') {
        Copy-Item -LiteralPath $md.FullName -Destination $dir -Force
    }
    if (Test-Path -LiteralPath (Join-Path $repoRoot 'docs')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot 'docs') -Destination $dir -Recurse -Force
    }
    if ($Mutate) { & $Mutate $dir }
    $validator = Join-Path $dir 'scripts\validate.ps1'
    $out = & pwsh -NoProfile -File $validator 2>&1
    $ec = $LASTEXITCODE
    $txt = ($out | Out-String).Trim()
    $passCond = if ($ExpectPass) { $ec -eq 0 } else { $ec -ne 0 }
    if ($passCond -and $CheckOutput) { $passCond = & $CheckOutput $txt }
    if (-not $passCond) { $script:allOk = $false } else { $script:passCount++ }
    $status = if ($passCond) { 'TEST_OK' } else { 'TEST_FAIL' }
    $firstLine = ($txt -split "\r?\n")[0]
    Write-Output "$status | $($Name.PadRight(36)) | expect_pass=$($ExpectPass.ToString().PadRight(5)) | exit=$ec | $firstLine"
}

try {
    # 1-2: Positive baseline + quoted/multiline/metadata ordering
    Run-FixtureCase -Name 'pos_01_baseline_clean' -ExpectPass $true -Mutate {}
    Run-FixtureCase -Name 'pos_02_quoted_multiline_order' -ExpectPass $true -Mutate {
        param($d)
        $c = "---`nlicense: `"MIT`"`ndescription: >`n  First line and`n  second line.`nmetadata:`n  owner: test-owner`n  ver: `"1.0`"`nname: pr-review-agent`ncompatibility: 'pwsh 7+'`n---`nBody`n"
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value $c -Encoding UTF8
    }

    # 3-14: Core regression cases (name/description/compatibility/secrets/junction/YAML syntax)
    Run-FixtureCase -Name 'neg_01_name_mismatch' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: secret-leak-mismatch-canary`ndescription: valid`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch 'secret-leak-mismatch-canary' }
    Run-FixtureCase -Name 'neg_02_name_uppercase' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: UpperCanary-Name`ndescription: valid`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -cnotmatch 'UpperCanary-Name' }
    Run-FixtureCase -Name 'neg_03_name_65chars' -ExpectPass $false -Mutate {
        param($d)
        $long = ('a' * 65)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: $long`ndescription: valid`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_04_desc_1025chars' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: $('x' * 1025)`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_05_desc_blank' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: `"   `"`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_06_multiline_desc_over1024' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: |`n  $('y' * 600)`n  $('z' * 430)`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_07_duplicate_key' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: first`ndescription: second`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_08_compat_over500' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: ok`ncompatibility: $('c' * 501)`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_09_secret_in_script' -ExpectPass $false -Mutate {
        param($d)
        $sd = Join-Path $d 'skills\pr-review-agent\scripts'
        New-Item -ItemType Directory -Force -Path $sd | Out-Null
        $fake = 'ghp_' + 'synthetic0123456789'
        Set-Content -LiteralPath (Join-Path $sd 'helper.ps1') -Value "`$k = '$fake'" -Encoding UTF8
    } -CheckOutput { param($t) ($t -notmatch 'synthetic0123456789') -and ($t -match 'gh-classic-pat') }
    Run-FixtureCase -Name 'neg_10_junction_escape' -ExpectPass $false -Mutate {
        param($d)
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            $outside = Join-Path $workRoot 'outside_target'
            New-Item -ItemType Directory -Force -Path $outside | Out-Null
            Set-Content -LiteralPath (Join-Path $outside 'outside.txt') -Value 'outside' -Encoding UTF8
            New-Item -ItemType Junction -Path (Join-Path $d 'skills\pr-review-agent\escaped_link') -Target $outside | Out-Null
        } else {
            $outside = Join-Path $workRoot 'outside_target_posix'
            New-Item -ItemType Directory -Force -Path $outside | Out-Null
            New-Item -ItemType SymbolicLink -Path (Join-Path $d 'skills\pr-review-agent\escaped_link') -Target $outside | Out-Null
        }
    }
    Run-FixtureCase -Name 'neg_11_yaml_anchor_rejected' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: &anc valid`n---`n" -Encoding UTF8
    }
    Run-FixtureCase -Name 'neg_12_flow_list_rejected' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: [invalid, flow]`n---`n" -Encoding UTF8
    }

    # 15-22: Boundary & error-redaction extensions
    Run-FixtureCase -Name 'neg_13_yaml_nonstring_type_bool' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: true`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch "'true'" }
    Run-FixtureCase -Name 'neg_14_yaml_nonstring_type_num' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: valid`ncompatibility: 12345`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch '12345' }
    Run-FixtureCase -Name 'neg_15_key_uppercase_redacted' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nNameCanaryKey: pr-review-agent`ndescription: valid`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch 'NameCanaryKey' }
    Run-FixtureCase -Name 'neg_16_docs_root_junction_escape' -ExpectPass $false -Mutate {
        param($d)
        $outside = Join-Path $workRoot 'outside_docs'
        New-Item -ItemType Directory -Force -Path $outside | Out-Null
        Set-Content -LiteralPath (Join-Path $outside 'leak.md') -Value '# clean doc' -Encoding UTF8
        $docsPath = Join-Path $d 'docs'
        if (Test-Path -LiteralPath $docsPath) { Remove-Item -LiteralPath $docsPath -Recurse -Force }
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            New-Item -ItemType Junction -Path $docsPath -Target $outside | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $docsPath -Target $outside | Out-Null
        }
    }
    Run-FixtureCase -Name 'neg_17_yaml_num_scientific' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: valid`ncompatibility: 1.5e-3`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch '1\.5e-3' }
    Run-FixtureCase -Name 'neg_18_yaml_num_hex_0x' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: valid`ncompatibility: 0xDEAD`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch '0xDEAD' }
    Run-FixtureCase -Name 'neg_19_yaml_num_dotinf' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: valid`ncompatibility: -.inf`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch '-\.inf' }
    Run-FixtureCase -Name 'neg_20_yaml_num_leading_dot' -ExpectPass $false -Mutate {
        param($d)
        Set-Content -LiteralPath (Join-Path $d 'skills\pr-review-agent\SKILL.md') -Value "---`nname: pr-review-agent`ndescription: valid`ncompatibility: .75`n---`n" -Encoding UTF8
    } -CheckOutput { param($t) $t -notmatch '\.75' }

    Write-Output "VALIDATE_TESTS_PASSED=$script:passCount/$script:totalCount ALL_OK=$script:allOk"
}
finally {
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if (-not $script:allOk) { exit 1 }
