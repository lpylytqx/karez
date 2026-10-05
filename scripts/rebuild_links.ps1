# 《坎儿井》素材联接重建脚本
# 在新机器上打开 Godot 工程前，先在本目录（scripts\）运行一次：
#   powershell -ExecutionPolicy Bypass -File rebuild_links.ps1
# 作用：把工程外 ..\assets 下的素材目录挂进工程根，让 res://tiles/... 等路径可用。

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Path
$assets = Join-Path (Split-Path -Parent $proj) "assets"

if (-not (Test-Path $assets)) {
    Write-Error "找不到素材目录：$assets（assets 应与 scripts 同级）"
}

# 目录联接：tiles / buildings / characters / fx / audio / fonts
foreach ($d in @("tiles", "buildings", "characters", "fx", "audio", "fonts")) {
    $link = Join-Path $proj $d
    $target = Join-Path $assets $d
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -eq "Junction") { Write-Output "已存在 junction：$d"; continue }
        Write-Error "目录 $link 已存在且不是 junction，请先处理。"
    }
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Output "创建 junction：$d -> assets\$d"
}

# ui 素材用文件硬链接挂进 scripts\ui（保留已有的 ui\main.gd）
$uiSrc = Join-Path $assets "ui"
$uiDst = Join-Path $proj "ui"
Get-ChildItem $uiSrc -Recurse -Filter "*.png" | ForEach-Object {
    $rel = $_.FullName.Substring($uiSrc.Length + 1)
    $target = Join-Path $uiDst $rel
    $td = Split-Path $target -Parent
    if (-not (Test-Path $td)) { New-Item -ItemType Directory -Force -Path $td | Out-Null }
    if (-not (Test-Path $target)) {
        New-Item -ItemType HardLink -Path $target -Target $_.FullName | Out-Null
        Write-Output "创建硬链接：ui\$rel"
    }
}

Write-Output "素材联接重建完成。现在可用 Godot 打开本工程。"
