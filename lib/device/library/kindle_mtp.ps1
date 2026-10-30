param([Parameter(Mandatory=$true)][string]$Action, [string]$Source)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$shell = New-Object -ComObject Shell.Application
$devices = @($shell.Namespace(17).Items() | Where-Object { $_.Name -like 'Kindle*' -and $_.IsFolder })
if ($devices.Count -ne 1) { if ($Action -eq 'detect') { Write-Output 'NO'; exit 0 }; throw 'Kindleを1台だけ接続してください' }
$storage = @($devices[0].GetFolder.Items() | Where-Object { $_.Name -eq 'Internal Storage' -and $_.IsFolder })
if ($storage.Count -ne 1) { if ($Action -eq 'detect') { Write-Output 'NO'; exit 0 }; throw 'Kindleの内部ストレージを開けません' }
$items = @($storage[0].GetFolder.Items() | Where-Object { $_.Name -eq 'documents' -and $_.IsFolder })
if ($items.Count -ne 1) { if ($Action -eq 'detect') { Write-Output 'NO'; exit 0 }; throw 'Kindleのdocumentsを開けません' }
if ($Action -eq 'detect') { Write-Output 'YES'; exit 0 }
if ($Action -ne 'copy') { throw '不明な操作です' }
if (!(Test-Path -LiteralPath $Source -PathType Leaf)) { throw '転送元が見つかりません' }
$sourceItem = Get-Item -LiteralPath $Source
function Get-Sha256([string]$path) {
  $stream = [IO.File]::OpenRead($path)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
  finally { $stream.Dispose(); $sha.Dispose() }
}
$hash = Get-Sha256 $Source
# Keep the destination name safely below common MTP filesystem byte limits.
# Text elements keep surrogate pairs and combining characters intact.
function Get-ShortName([string]$name, [string]$extension, [string]$suffix) {
  $stem = [IO.Path]::GetFileNameWithoutExtension($name)
  $limit = 200 - [Text.Encoding]::UTF8.GetByteCount($suffix + $extension)
  if ($limit -lt 1) { throw 'ファイルの拡張子が長すぎます' }
  $result = [Text.StringBuilder]::new()
  $parts = [Globalization.StringInfo]::GetTextElementEnumerator($stem)
  $bytes = 0
  while ($parts.MoveNext()) {
    $part = $parts.GetTextElement()
    $partBytes = [Text.Encoding]::UTF8.GetByteCount($part)
    if ($bytes + $partBytes -gt $limit) { break }
    [void]$result.Append($part)
    $bytes += $partBytes
  }
  return $result.ToString().TrimEnd(' ', '.') + $suffix + $extension
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('narou-mtp-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $docs = $items[0].GetFolder
  $name = $sourceItem.Name
  $suffix = ' [' + $hash.Substring(0, 10) + ']'
  if ([Text.Encoding]::UTF8.GetByteCount($name) -gt 200) {
    $name = Get-ShortName $name $sourceItem.Extension $suffix
  }
  $existing = @($docs.Items() | Where-Object { $_.Name -eq $name })
  if ($existing.Count -gt 0 -and $name -eq $sourceItem.Name) {
    $name = Get-ShortName $name $sourceItem.Extension $suffix
    $existing = @($docs.Items() | Where-Object { $_.Name -eq $name })
  }
  if ($existing.Count -gt 1) { throw '同名ファイルが複数あります' }
  if ($existing.Count -eq 0) {
    $upload = Join-Path $temp $name
    Copy-Item -LiteralPath $Source -Destination $upload
    $docs.CopyHere($upload, 4 + 16 + 1024)
    for ($i = 0; $i -lt 30; $i++) {
      Start-Sleep -Seconds 1
      # Reopen the MTP folder to avoid using a stale Shell folder view.
      $docs = $items[0].GetFolder
      $existing = @($docs.Items() | Where-Object { $_.Name -eq $name })
      if ($existing.Count -eq 1) { break }
    }
  }
  if ($existing.Count -ne 1) { throw ('Kindleへの転送を確認できません: ' + $name + '。接続状態とKindleの空き容量を確認してください') }
  $readback = Join-Path $temp 'readback'
  New-Item -ItemType Directory -Path $readback | Out-Null
  $shell.Namespace($readback).CopyHere($existing[0], 4 + 16 + 1024)
  $copy = Join-Path $readback $name
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if ((Test-Path -LiteralPath $copy) -and (Get-Item -LiteralPath $copy).Length -eq $sourceItem.Length) { break }
  }
  if (!(Test-Path -LiteralPath $copy) -or (Get-Sha256 $copy) -ne $hash) { throw 'Kindleからの読み戻しが元ファイルと一致しません' }
  Write-Output ('Kindle\Internal Storage\documents\' + $name)
} finally {
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  $resolvedTemp = [IO.Path]::GetFullPath($temp)
  if ($resolvedTemp.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedTemp) -match '^narou-mtp-[0-9a-f]{32}$') {
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
