param(
    [Parameter(Position = 0)]
    [string]$File
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if ([string]::IsNullOrWhiteSpace($File)) {
    $File = Read-Host "请拖入一个音频或视频文件，或直接输入完整路径"
}
$File = $File.Trim('"')
if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    Write-Host "找不到文件：$File" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "分类：music / weapon / hit / kill / pickup / warning / boss / ui / ambience / voice / video / other"
$Category = Read-Host "分类 [music]"
if ([string]::IsNullOrWhiteSpace($Category)) { $Category = "music" }

$Role = Read-Host "用途标签，例如 battle_loop / normal_kill / rail_fire"
if ([string]::IsNullOrWhiteSpace($Role)) { $Role = "unclassified" }

$Title = Read-Host "标题（留空则使用文件名）"
$Bpm = Read-Host "BPM（未知直接回车）"
$Bars = Read-Host "小节数（未知直接回车）"
$Tags = Read-Host "附加标签，逗号分隔（可留空）"
$Notes = Read-Host "备注（可留空）"
$LoopAnswer = Read-Host "是否为可循环片段？[y/N]"

$Arguments = @(
    (Join-Path $PSScriptRoot "audio_library.py"),
    "add",
    $File,
    "--category", $Category,
    "--role", $Role
)
if (-not [string]::IsNullOrWhiteSpace($Title)) { $Arguments += @("--title", $Title) }
if (-not [string]::IsNullOrWhiteSpace($Bpm)) { $Arguments += @("--bpm", $Bpm) }
if (-not [string]::IsNullOrWhiteSpace($Bars)) { $Arguments += @("--bars", $Bars) }
if (-not [string]::IsNullOrWhiteSpace($Tags)) { $Arguments += @("--tags", $Tags) }
if (-not [string]::IsNullOrWhiteSpace($Notes)) { $Arguments += @("--notes", $Notes) }
if ($LoopAnswer -match "^(y|yes)$") { $Arguments += "--loop" }

& python @Arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host ""
Write-Host "已更新 catalog.json / catalog.csv / CATALOG.md" -ForegroundColor Green
