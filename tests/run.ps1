param(
    [Parameter(Mandatory = $true)][string]$GameScripts,
    [string]$Lua = 'lua'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('nightsword-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fixturePath | Out-Null
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $GameScripts).Path)
try {
    # Read the installed game's implementation; no game files are modified or bundled.
    foreach ($name in @('class.lua', 'components/finiteuses.lua', 'components/repairable.lua',
        'components/repairer.lua', 'components/weapon.lua', 'actions.lua', 'componentactions.lua')) {
        $entry = $archive.GetEntry('scripts/' + $name)
        if ($null -eq $entry) { throw "Missing game script: $name" }
        $destination = Join-Path $fixturePath $name
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination)
    }
    Push-Location (Split-Path $PSScriptRoot)
    try {
        & $Lua 'tests/nightsword_spec.lua' $fixturePath
        if ($LASTEXITCODE -ne 0) { throw "Lua tests failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} finally {
    $archive.Dispose()
    # Delete only this run's freshly created fixture directory under the system temp path.
    $resolvedFixture = [IO.Path]::GetFullPath($fixturePath)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean path outside temp: $resolvedFixture"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
