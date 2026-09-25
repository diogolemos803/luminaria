# Converte as gravações originais (Assets/sons_originais, fora do git — .ogg/.wav do
# Wikimedia Commons) pra WAV PCM 16-bit mono 44,1 kHz, o formato dos sons do app.
# Usa o transcodificador do próprio Windows (Windows.Media.Transcoding, via WinRT) —
# nada pra instalar. Ele NÃO abre .ogg (testado: CanTranscode = false mesmo com o
# "Web Media Extensions" instalado), então pros originais em Ogg Vorbis baixamos a
# versão MP3 que o próprio Wikimedia publica de cada arquivo (Assets/sons_originais/mp3)
# e rodamos este script nas duas pastas.
# Depois disso, scripts/process_alarm_recordings.js corta/normaliza cada som.
#
# Uso: powershell -File scripts/transcode_recordings.ps1 <pasta de origem> <pasta de saída>
param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$OutputDir
)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
$asTaskProgress = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1'
})[0]
function Await($operation, [Type]$resultType) {
    $task = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}
function AwaitProgress($operation, [Type]$progressType) {
    $task = $asTaskProgress.MakeGenericMethod($progressType).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
}

[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime] | Out-Null

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outFolder = Await ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync((Resolve-Path $OutputDir).Path)) ([Windows.Storage.StorageFolder])

foreach ($file in Get-ChildItem -Path $SourceDir -File | Where-Object { $_.Extension -in '.ogg', '.oga', '.wav', '.mp3', '.flac' }) {
    $source = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($file.FullName)) ([Windows.Storage.StorageFile])
    $target = Await ($outFolder.CreateFileAsync($file.BaseName + '.wav', [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])

    $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav([Windows.Media.MediaProperties.AudioEncodingQuality]::High)
    # Só o container WAV/PCM 16-bit: forçar taxa/canais aqui faz o transcodificador
    # recusar (CanTranscode = false). Mono + 44,1 kHz ficam pro process_alarm_recordings.js.

    $transcoder = New-Object Windows.Media.Transcoding.MediaTranscoder
    $prepared = Await ($transcoder.PrepareFileTranscodeAsync($source, $target, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
    if (-not $prepared.CanTranscode) {
        Write-Output "FALHOU $($file.Name): $($prepared.FailureReason)"
        continue
    }
    AwaitProgress ($prepared.TranscodeAsync()) ([double])
    Write-Output "ok $($file.Name) -> $($file.BaseName).wav"
}
