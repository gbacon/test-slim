param(
  [Parameter(Mandatory = $true)][string] $PerlPath,
  [Parameter(Mandatory = $true)][string] $RunnerPath,
  [Parameter(Mandatory = $true)][string] $Perl5Lib,
  [int] $TimeoutMilliseconds = 15000
)

$ErrorActionPreference = 'Stop'

function Read-ExactBytes {
  param(
    [System.IO.Stream] $Stream,
    [int] $Length,
    [int] $Timeout
  )

  $bytes = [byte[]]::new($Length)
  $offset = 0
  while ($offset -lt $Length) {
    $readTask = $Stream.ReadAsync($bytes, $offset, $Length - $offset)
    if (-not $readTask.Wait($Timeout)) {
      throw "Timed out after ${Timeout}ms reading pipe process output ($offset/$Length bytes)"
    }
    $count = $readTask.Result
    if ($count -eq 0) {
      throw "Unexpected pipe process EOF ($offset/$Length bytes)"
    }
    $offset += $count
  }
  return ,$bytes
}

function Read-Frame {
  param([System.IO.Stream] $Stream, [int] $Timeout)

  $header = [System.Text.Encoding]::ASCII.GetString((Read-ExactBytes $Stream 7 $Timeout))
  if ($header -notmatch '\A([0-9]{6,}):\z') {
    throw "Invalid SLiM response frame header: $header"
  }
  $length = [int]$Matches[1]
  return [System.Text.Encoding]::ASCII.GetString((Read-ExactBytes $Stream $length $Timeout))
}

if (-not (Test-Path -LiteralPath $PerlPath -PathType Leaf)) { throw "Perl executable not found: $PerlPath" }
if (-not (Test-Path -LiteralPath $RunnerPath -PathType Leaf)) { throw "SLiM runner not found: $RunnerPath" }

$start = [System.Diagnostics.ProcessStartInfo]::new()
$start.FileName = $PerlPath
$start.ArgumentList.Add($RunnerPath)
$start.ArgumentList.Add('1')
$start.WorkingDirectory = (Get-Location).Path
$start.UseShellExecute = $false
$start.RedirectStandardInput = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.Environment['PERL5LIB'] = $Perl5Lib

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $start
$stderrTask = $null
try {
  if (-not $process.Start()) { throw 'Could not start perl-slim child process' }
  # Drain diagnostics concurrently so a fixture or startup error cannot fill
  # the stderr pipe while this script waits for protocol bytes.
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $output = $process.StandardOutput.BaseStream

  $greeting = [System.Text.Encoding]::ASCII.GetString((Read-ExactBytes $output 13 $TimeoutMilliseconds))
  if ($greeting -cne "Slim -- V0.5`n") { throw "Unexpected SLiM greeting: $greeting" }

  # The request imports the external Example::Counter fixture, constructs a
  # typed integer actor, calls a typed method, and reads the resulting value.
  $request = '[000004:000047:[000003:000001:i:000006:import:000007:Example:]:000067:[000005:000001:m:000004:make:000005:actor:000007:Counter:000001:4:]:000073:[000005:000005:added:000004:call:000005:actor:000009:addAmount:000001:3:]:000060:[000004:000005:value:000004:call:000005:actor:000005:value:]:]'
  $requestBytes = [System.Text.Encoding]::ASCII.GetBytes(('000288:' + $request))
  $input = $process.StandardInput.BaseStream
  $input.Write($requestBytes, 0, $requestBytes.Length)
  $input.Flush()

  $response = Read-Frame $output $TimeoutMilliseconds
  $expectedResponse = '[000004:000028:[000002:000001:i:000002:OK:]:000028:[000002:000001:m:000002:OK:]:000031:[000002:000005:added:000001:7:]:000031:[000002:000005:value:000001:7:]:]'
  if ($response -cne $expectedResponse) {
    throw "Unexpected SLiM response. Expected '$expectedResponse', received '$response'"
  }

  $bye = [System.Text.Encoding]::ASCII.GetBytes('000003:bye')
  $input.Write($bye, 0, $bye.Length)
  $input.Flush()
  $process.StandardInput.Close()

  $eofTask = $output.ReadAsync([byte[]]::new(1), 0, 1)
  if (-not $eofTask.Wait($TimeoutMilliseconds)) { throw 'Timed out waiting for pipe stdout to close after bye' }
  if ($eofTask.Result -ne 0) { throw 'Unexpected protocol bytes followed the bye instruction' }
  if (-not $process.WaitForExit($TimeoutMilliseconds)) { throw 'Timed out waiting for perl-slim child to exit after bye' }

  $stderr = $stderrTask.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) {
    throw "perl-slim exited with status $($process.ExitCode); stderr: $stderr"
  }
  if ($stderr.Length -gt 0) { Write-Host "Captured child stderr: $stderr" }
  Write-Host "Verified SLiM v0.5 handshake, framed fixture request/response, bye, and child exit 0 ($RunnerPath)"
}
catch {
  if (-not $process.HasExited) {
    try {
      $process.Kill($true)
      [void]$process.WaitForExit(5000)
    }
    catch { Write-Host "Could not terminate failed child promptly: $_" }
  }
  if ($stderrTask) {
    try {
      if ($stderrTask.Wait(5000)) {
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($stderr.Length -gt 0) { Write-Host "Captured child stderr before failure: $stderr" }
      }
      else { Write-Host 'Timed out draining child stderr after failure' }
    }
    catch { Write-Host "Could not collect child stderr: $_" }
  }
  throw
}
finally {
  if (-not $process.HasExited) {
    $process.Kill($true)
    [void]$process.WaitForExit(5000)
  }
  $process.Dispose()
}
