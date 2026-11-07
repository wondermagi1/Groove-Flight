param(
    [Parameter(Position = 0)]
    [string]$Folder
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if ([string]::IsNullOrWhiteSpace($Folder)) {
    $Folder = Read-Host "请拖入一个录音文件夹，或输入完整路径"
}
$Folder = $Folder.Trim('"').TrimEnd('\')
if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Host "找不到文件夹：$Folder" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "分类：auto / music / weapon / hit / kill / pickup / warning / boss / ui / ambience / voice / video / other"
Write-Host "选择 auto 时，脚本会读取子目录名作为分类。"
$Category = Read-Host "分类 [auto]"
if ([string]::IsNullOrWhiteSpace($Category)) { $Category = "auto" }
$RecursiveAnswer = Read-Host "包含子文件夹？[Y/n]"
$Tags = Read-Host "整批标签，逗号分隔（可留空）"

$Arguments = @(
    (Join-Path $PSScriptRoot "audio_library.py"),
    "batch",
    $Folder,
    "--category", $Category
)
if ($RecursiveAnswer -notmatch "^(n|no)$") { $Arguments += "--recursive" }
if (-not [string]::IsNullOrWhiteSpace($Tags)) { $Arguments += @("--tags", $Tags) }

& python @Arguments
exit $LASTEXITCODE
