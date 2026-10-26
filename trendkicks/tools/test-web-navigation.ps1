$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$flutterPath = (Get-Command flutter).Source
$flutterRoot = Split-Path (Split-Path $flutterPath -Parent) -Parent
$targetDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot 'test\canvaskit\chromium'))
if (-not $targetDirectory.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Temporary CanvasKit path is outside the project.'
}
# Flutter 3.47's Windows test server can miss its CanvasKit route due to path
# separators. Its static test directory fallback can serve these SDK-owned files.
$createdFiles = @()
$createdDirectory = -not (Test-Path -LiteralPath $targetDirectory)
$testResult = 1
try {
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    foreach ($fileName in @('canvaskit.js', 'canvaskit.wasm')) {
        $source = Join-Path $flutterRoot "bin\cache\flutter_web_sdk\canvaskit\chromium\$fileName"
        $target = Join-Path $targetDirectory $fileName
        if (Test-Path -LiteralPath $target) { throw "Temporary test asset already exists: $target" }
        Copy-Item -LiteralPath $source -Destination $target
        $createdFiles += $target
    }
    Push-Location $projectRoot
    try {
        flutter test --no-pub --platform chrome test/checkout_navigation_test.dart
        $testResult = $LASTEXITCODE
    } finally { Pop-Location }
} finally {
    foreach ($target in $createdFiles) {
        # Exact files created above, under the verified project directory. No recursion.
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
    }
    if ($createdDirectory -and (Test-Path -LiteralPath $targetDirectory) -and @(Get-ChildItem -LiteralPath $targetDirectory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $targetDirectory
    }
    $parentDirectory = Split-Path $targetDirectory -Parent
    if ((Test-Path -LiteralPath $parentDirectory) -and @(Get-ChildItem -LiteralPath $parentDirectory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $parentDirectory
    }
}
exit $testResult
