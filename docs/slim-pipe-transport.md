# SLiM v0.5 stdin/stdout transport

## FitNesse v20251025 contract

The [SLiM protocol guide](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/SlimProtocol.html) defines port `1` as communication over the child's stdin/stdout. FitNesse invokes the configured test runner with the port argument; for this mode the argument is `1`. The child sends the unframed `Slim -- V0.5\n` greeting. Every subsequent message, including `bye`, remains length-prefixed: the outer length counts transmitted bytes, while string lengths inside serialized lists count UTF-16 code units. FitNesse and the child exchange repeated request/response frames until `bye` or pipe closure.

The published guide says FitNesse sends `bye` and the server shuts down. There is no additional version-negotiation message. TCP continues to use the existing `Slim -- V0.4\n` greeting and socket connection behavior. The v0.5 pipe path does not change TCP framing, parsing, response serialization, or executor state.

The guide also specifies output tunneling: child stdout and stderr lines are prefixed with `SOUT ` / `SOUT.` and `SERR ` / `SERR.` respectively, then written to child stderr for reconstruction in FitNesse's execution log.

## Perl implementation

`Test::Slim::Server` now shares one session loop for TCP and pipe transports. The loop takes separate input and output handles, the greeting version, and a transport-ownership flag. TCP calls it with the accepted socket for both directions and V0.4. `run(1)` branches to `run_pipe` before constructing a TCP listener. Pipe mode duplicates the original stdout handle for protocol bytes, switches stdin to binary mode, redirects process fd 1/Perl `STDOUT` to stderr, and enables autoflush on that redirected handle. This keeps fixture Perl output, inherited subprocess/native fd 1 output, and server diagnostics off the protocol pipe. The saved protocol handle is written with the same exact-write routine as TCP.

Each pipe child owns one `ListExecutor` session. It reads and parses an entire framed request before executing it, preserves fixture and symbol state between batches, serializes and writes each response frame, and then waits for the next message. A framed `bye` returns normally and the child exits 0. EOF at a message boundary also returns normally and exits 0. EOF within a prefix or payload, malformed framing, invalid UTF-8, resource-limit violations, or corrupt serialized lists cause a diagnostic on stderr and a nonzero child exit; no response is fabricated for an incomplete/corrupt message. A well-framed malformed instruction still produces the regular `MALFORMED_INSTRUCTION` result and the session can continue. Writes handle partial progress and `EINTR`; pipe mode ignores `SIGPIPE` so a broken output pipe becomes a contained write error and nonzero child exit.

The frame size, decoded-list limits, and strict UTF-8 policy are identical to the TCP path. The pipe transport adds no separate parser, executor, listener, worker, or resource policy.

## Stdout isolation and current limits

The protocol writes only to the duplicated original stdout handle. Before reading or executing instructions, the child redirects fd 1 and Perl's `STDOUT` to stderr. This also redirects ordinary subprocess output that inherits fd 1. `STDERR` and `warn` remain on stderr. A test fixture writes distinct markers to stdout and stderr while the test decodes the following SLiM response frame; the markers appear on stderr and do not contaminate the response.

This is safe stdout isolation, **not complete v0.5 diagnostic tunneling**. Perl does not yet add `SOUT `, `SOUT.`, `SERR `, or `SERR.` prefixes. It does not split multiline writes into first/following-line markers or ask FitNesse to reconstruct separate stdout and stderr sections. Diagnostic and fixture output is passed through as ordinary stderr text. Raw output remains useful in logs, but exact execution-log attribution and multiline fidelity are not claimed. The pipe-mode fixture stdout handle is autoflushed; the protocol handle uses `syswrite` and is not buffered.

## Invocation

For a direct child runner, set a command pattern that expands to the runner executable and pass `SLIM_PORT=1`. FitNesse query values supplied to `-c` override tested page-defined and inherited wiki variables. In this checkout, `PERL5LIB` must include `lib` and `t/lib` so the child can load the server and acceptance fixtures.

```sh
TASK_ROOT=/tmp/test-slim-pipe-smoke
PERL5LIB="$PWD/lib:$PWD/t/lib" java -Dslim.pool.size=1 \
  -jar /opt/fitnesse/fitnesse.jar \
  -d "$TASK_ROOT" -r FitNesseRoot -p 19321 -b "$TASK_ROOT/result.xml" \
  -c 'FitNesse.SuiteAcceptanceTests.SuiteSlimTests.SlimSymbols.NamingConvention?test&format=xml&COMMAND_PATTERN=%25m&TEST_RUNNER=%2Fworkspaces%2Ftest-slim%2Fbin%2Fperl-slim&SLIM_PORT=1'
```

The FitNesse JAR's wiki was extracted into the temporary `TASK_ROOT` before running this command. The tested command exited 0. Its result XML reported FitNesse `v20251025`, test system `slim:/workspaces/test-slim/bin/perl-slim`, command `/workspaces/test-slim/bin/perl-slim 1`, and 5 right, 0 wrong, 0 ignored, 0 exceptions. The Perl child process therefore handled the page using port 1; no external Perl TCP listener was started or used. A second run of `SlimSymbols.SlimSymbolManipulation` used the same child command and passed 18/18 assertions.

The `TEST_RUNNER`-only query override is insufficient under FitNesse's default Java command pattern; `COMMAND_PATTERN=%m` is what makes FitNesse execute the runner path directly. `%m` must be URL-encoded as `%25m`, slashes as `%2F`, and the full URL should remain shell-quoted.

## Automated evidence and TCP compatibility

`prove -lv t/pipe-transport.t` launches `bin/perl-slim 1` as a child with connected pipes. It checks the V0.5 handshake; framed requests/responses; multiple batches and state retention; Unicode; null, empty string, and empty list values; `bye`; clean EOF; truncated and invalid frames; malformed serialized-batch atomicity; `MALFORMED_INSTRUCTION` continuation; fixture stdout/stderr separation; a broken output pipe; and child exit status. Child reads are bounded and test cleanup terminates a hung child.

Existing `t/server.t`, `t/server-frame.t`, `t/server-unicode-frame.t`, `t/server-malformed-input.t`, and the TCP listener tests continue to exercise the socket path. `bin/test-fitnesse` and `bin/test-fitnesse-suite` remain on their established TCP configuration; their 50-page and 93-page regression baselines are not modified by this transport change.

The verified support boundary is v0.5 framed instruction traffic over inherited pipes with stdout isolation. Complete `SOUT`/`SERR` output-tunnel compatibility and migration of acceptance gates to child-process mode remain future work.
