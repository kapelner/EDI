$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Use the runner's standalone UCRT64 MSYS2 installation only to obtain the
# pre-built DLL. Do not add its bin directory to PATH: R package compilation
# must continue to use the matching Rtools toolchain selected by setup-r.
$msysBash = "C:\msys64\usr\bin\bash.exe"
$openBlasDll = "C:\msys64\ucrt64\bin\libopenblas.dll"

if (-not (Test-Path -LiteralPath $msysBash)) {
    throw "GitHub runner MSYS2 bash was not found at $msysBash"
}

Write-Host "Installing the pre-built UCRT64 OpenBLAS runtime"
& $msysBash -lc "pacman --noconfirm --sync --refresh --needed mingw-w64-ucrt-x86_64-openblas"
if ($LASTEXITCODE -ne 0) {
    throw "pacman failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $openBlasDll)) {
    throw "OpenBLAS DLL was not installed at $openBlasDll"
}

$rBin = (& Rscript -e 'cat(normalizePath(R.home("bin"), winslash = "/", mustWork = TRUE))').Trim()
if ($LASTEXITCODE -ne 0 -or -not $rBin) {
    throw "Could not determine R's architecture-specific bin directory"
}

# R.home("bin") is architecture-specific for the standard Windows installer.
# Keep a fallback for any setup-r layout that returns the parent bin directory.
if (-not (Test-Path -LiteralPath (Join-Path $rBin "Rblas.dll"))) {
    $rBin = Join-Path $rBin "x64"
}

$blasTarget = Join-Path $rBin "Rblas.dll"
$lapackTarget = Join-Path $rBin "Rlapack.dll"
foreach ($target in @($blasTarget, $lapackTarget)) {
    if (-not (Test-Path -LiteralPath $target)) {
        throw "R runtime DLL was not found at $target"
    }
    Copy-Item -LiteralPath $target -Destination "$target.reference" -Force
    Copy-Item -LiteralPath $openBlasDll -Destination $target -Force
}

# Keep the DLL under its original name too. This covers OpenBLAS builds whose
# import table refers back to libopenblas.dll while exporting BLAS/LAPACK from
# the two R runtime filenames above.
$openBlasTarget = Join-Path $rBin "libopenblas.dll"
Copy-Item -LiteralPath $openBlasDll -Destination $openBlasTarget -Force

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $openBlasDll).Hash
foreach ($target in @($blasTarget, $lapackTarget, $openBlasTarget)) {
    $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
    if ($targetHash -ne $sourceHash) {
        throw "OpenBLAS copy verification failed for $target"
    }
}

Write-Host "OpenBLAS installed into $rBin (SHA256 $sourceHash)"
& Rscript -e 'm <- matrix(c(1, 2, 3, 4), nrow = 2); stopifnot(identical(crossprod(m), matrix(c(5, 11, 11, 25), nrow = 2))); cat("BLAS/LAPACK smoke check passed\n"); print(extSoftVersion()[c("BLAS", "LAPACK")])'
if ($LASTEXITCODE -ne 0) {
    throw "R failed its post-swap BLAS/LAPACK smoke check"
}
