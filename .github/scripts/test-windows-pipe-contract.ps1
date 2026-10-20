param(
  [Parameter(Mandatory = $true)][string] $PerlPath,
  [Parameter(Mandatory = $true)][string] $PipeCheckPath
)

$ErrorActionPreference = 'Stop'
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $temp)
$pwshPath = (Get-Command pwsh).Source

function Invoke-PipeCheck {
  param([string] $Runner, [int] $Timeout = 15000, [string] $PidFile)

  $start = [System.Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $pwshPath
  $start.ArgumentList.Add('-NoProfile')
  $start.ArgumentList.Add('-File')
  $start.ArgumentList.Add($PipeCheckPath)
  $start.ArgumentList.Add('-PerlPath')
  $start.ArgumentList.Add($PerlPath)
  $start.ArgumentList.Add('-RunnerPath')
  $start.ArgumentList.Add($Runner)
  $start.ArgumentList.Add('-Perl5Lib')
  $start.ArgumentList.Add('')
  $start.ArgumentList.Add('-TimeoutMilliseconds')
  $start.ArgumentList.Add([string]$Timeout)
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  if ($PidFile) { $start.Environment['TEST_SLIM_CHILD_PID_FILE'] = $PidFile }

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $start
  try {
    if (-not $process.Start()) { throw 'Could not start pipe-check subprocess' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) {
      $process.Kill($true)
      [void]$process.WaitForExit(5000)
      throw 'Pipe-check subprocess exceeded its 15-second test bound'
    }
    [void]$stdout.GetAwaiter().GetResult()
    $diagnostics = $stderr.GetAwaiter().GetResult()
    return @{ ExitCode = $process.ExitCode; Diagnostics = $diagnostics }
  }
  finally { $process.Dispose() }
}

try {
  $missing = Invoke-PipeCheck (Join-Path $temp 'missing-perl-slim')
  if ($missing.ExitCode -eq 0) { throw 'Missing runner path unexpectedly passed' }
  Write-Host 'Missing runner path is rejected with a nonzero process status'

  $badGreeting = Join-Path $temp 'bad-greeting.pl'
  Set-Content -LiteralPath $badGreeting -Encoding ascii -NoNewline -Value @'
binmode STDOUT;
print "Wrong -- V0.5\n";
sleep 30;
'@
  $greeting = Invoke-PipeCheck $badGreeting
  if ($greeting.ExitCode -eq 0) { throw 'Incorrect greeting unexpectedly passed' }
  Write-Host 'Incorrect greeting is rejected and its child is terminated'

  $badResponse = Join-Path $temp 'bad-response.pl'
  Set-Content -LiteralPath $badResponse -Encoding ascii -NoNewline -Value @'
binmode STDOUT;
binmode STDIN;
print "Slim -- V0.5\n";
print "000002:[]";
sleep 30;
'@
  $response = Invoke-PipeCheck $badResponse
  if ($response.ExitCode -eq 0) { throw 'Incorrect response unexpectedly passed' }
  Write-Host 'Incorrect framed response is rejected and its child is terminated'

  $sleepRunner = Join-Path $temp 'no-greeting.pl'
  Set-Content -LiteralPath $sleepRunner -Encoding ascii -NoNewline -Value @'
open my $pid_file, '>', $ENV{TEST_SLIM_CHILD_PID_FILE} or die $!;
print {$pid_file} $$;
close $pid_file;
sleep 30;
'@
  $pidFile = Join-Path $temp 'child.pid'
  $timeout = Invoke-PipeCheck $sleepRunner 300 $pidFile
  if ($timeout.ExitCode -eq 0) { throw 'Silent child unexpectedly passed the timeout check' }
  if (-not (Test-Path -LiteralPath $pidFile)) { throw 'Timeout child did not record its PID' }
  $childId = [int](Get-Content -LiteralPath $pidFile -Raw)
  $deadline = [DateTime]::UtcNow.AddSeconds(5)
  while ([DateTime]::UtcNow -lt $deadline -and (Get-Process -Id $childId -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 100
  }
  if (Get-Process -Id $childId -ErrorAction SilentlyContinue) {
    throw "Timed-out Perl child $childId was not cleaned up"
  }
  Write-Host 'Handshake timeout is bounded and the child process is reaped'
}
finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
