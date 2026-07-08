$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root "dist"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (!(Test-Path -LiteralPath $csc)) {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (!(Test-Path -LiteralPath $csc)) {
    throw "Cannot find .NET Framework csc.exe"
}

if (!(Test-Path -LiteralPath $dist)) {
    New-Item -ItemType Directory -Path $dist | Out-Null
}

$exe = Join-Path $dist "WordRealm.exe"
$source = Join-Path $root "WordRogue.cs"
$wordbank = Join-Path $root "wordbank.json"

& $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 `
    /out:$exe `
    /reference:System.dll `
    /reference:System.Core.dll `
    /reference:System.Drawing.dll `
    /reference:System.Windows.Forms.dll `
    /reference:System.Web.Extensions.dll `
    $source

if ($LASTEXITCODE -ne 0) {
    throw "C# compilation failed with exit code $LASTEXITCODE"
}

Copy-Item -LiteralPath $wordbank -Destination (Join-Path $dist "wordbank.json") -Force

$assets = Join-Path $root "assets"
if (Test-Path -LiteralPath $assets) {
    $distAssets = Join-Path $dist "assets"
    if (Test-Path -LiteralPath $distAssets) {
        Remove-Item -LiteralPath $distAssets -Recurse -Force
    }
    New-Item -ItemType Directory -Path $distAssets | Out-Null
    $runtimeAssets = Join-Path $assets "runtime"
    if (Test-Path -LiteralPath $runtimeAssets) {
        Copy-Item -LiteralPath $runtimeAssets -Destination (Join-Path $distAssets "runtime") -Recurse -Force
    }
    $index = Join-Path $assets "generated\ASSET_INDEX.md"
    if (Test-Path -LiteralPath $index) {
        New-Item -ItemType Directory -Force -Path (Join-Path $distAssets "generated") | Out-Null
        Copy-Item -LiteralPath $index -Destination (Join-Path $distAssets "generated\ASSET_INDEX.md") -Force
    }
}

Write-Host "Built $exe"
