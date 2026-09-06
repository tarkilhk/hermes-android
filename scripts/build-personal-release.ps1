param(
    [Parameter(Mandatory = $true)][string]$ToolchainRoot,
    [string]$SigningDirectory = (Join-Path $env:LOCALAPPDATA 'HermesPersonal\signing'),
    [switch]$InitializeSigning
)
$ErrorActionPreference = 'Stop'
# Run Flutter tests before this script, not concurrently: both commands can
# regenerate Android's plugin registry with different dev-dependency settings.
$repository = Split-Path $PSScriptRoot -Parent
$signingRoot = [IO.Path]::GetFullPath($SigningDirectory)
$keystore = Join-Path $signingRoot 'hermes-personal.p12'
$credentialFile = Join-Path $signingRoot 'password.dpapi.xml'
$keytool = Join-Path $ToolchainRoot 'jdk-17\bin\keytool.exe'
$flutter = Join-Path $ToolchainRoot 'flutter\bin\flutter.bat'
$sdk = Join-Path $ToolchainRoot 'android-sdk'
$buildTools = Join-Path $sdk 'build-tools\36.0.0'
foreach ($required in @($keytool, $flutter, (Join-Path $buildTools 'apksigner.bat'))) {
    if (!(Test-Path -LiteralPath $required)) { throw 'Required release tool is missing' }
}
if ($signingRoot.StartsWith($repository + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Signing material must live outside the repository'
}
if ($InitializeSigning) {
    if (Test-Path -LiteralPath $signingRoot) { throw 'Signing directory already exists; refusing to replace any signing material' }
    New-Item -ItemType Directory -Path $signingRoot | Out-Null
    $principal = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $signingRoot /inheritance:r /grant:r "${principal}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not restrict signing-directory permissions' }
    $random = [byte[]]::new(32)
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($random) } finally { $generator.Dispose() }
    $password = ConvertTo-SecureString ([Convert]::ToBase64String($random)) -AsPlainText -Force
    $credential = [PSCredential]::new('hermes-personal', $password)
    # Windows DPAPI binds this to this user/computer. Not a portable backup.
    $credential | Export-Clixml -LiteralPath $credentialFile
    try {
        $env:HERMES_STORE_PASSWORD = $credential.GetNetworkCredential().Password
        & $keytool -genkeypair -keystore $keystore -storetype PKCS12 -alias hermes-personal -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Hermes Personal' -storepass:env HERMES_STORE_PASSWORD -keypass:env HERMES_STORE_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed; do not delete or overwrite partial signing material automatically' }
    } finally { Remove-Item Env:HERMES_STORE_PASSWORD -ErrorAction SilentlyContinue }
}
if (!(Test-Path -LiteralPath $keystore) -or !(Test-Path -LiteralPath $credentialFile)) {
    throw 'Signing material is missing; initialize once with -InitializeSigning'
}
$credential = Import-Clixml -LiteralPath $credentialFile
Push-Location $repository
try {
    $env:JAVA_HOME = Join-Path $ToolchainRoot 'jdk-17'
    $env:ANDROID_SDK_ROOT = $sdk
    $env:HERMES_STORE_FILE = $keystore
    $env:HERMES_STORE_PASSWORD = $credential.GetNetworkCredential().Password
    $env:HERMES_KEY_ALIAS = $credential.UserName
    $env:HERMES_KEY_PASSWORD = $env:HERMES_STORE_PASSWORD
    # Flutter 3.44 skips release-specific plugin regeneration with --no-pub.
    # Keep the pub step so integration_test is excluded from the native registry.
    & $flutter build apk --release --target-platform android-arm64 --split-per-abi --split-debug-info=build/personal-symbols -t lib/main.dart
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
    $apk = Join-Path $repository 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
    $signature = & (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
    $expectedCertificate = (Get-Content (Join-Path $repository 'android\personal-release-certificate.sha256') -Raw).Trim()
    if ($signature -notcontains "Signer #1 certificate SHA-256 digest: $expectedCertificate") {
        throw 'APK was signed with a different key than the personal release identity'
    }
    $signature | Write-Output
    $badging = & (Join-Path $buildTools 'aapt.exe') dump badging $apk
    if ($LASTEXITCODE -ne 0 -or !($badging -match "package: name='com.tarkilhk.hermes.android'")) { throw 'Unexpected APK identity' }
    if ($badging -match '^application-debuggable') { throw 'Release APK is debuggable' }
    $badging | Select-String '^(package:|application-label:|launchable-activity:|native-code:)'
    Write-Output "Verified personal release: $apk"
} finally {
    foreach ($name in @('HERMES_STORE_FILE', 'HERMES_STORE_PASSWORD', 'HERMES_KEY_ALIAS', 'HERMES_KEY_PASSWORD')) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    Pop-Location
}
