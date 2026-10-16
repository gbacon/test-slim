# FitNesse acceptance transport migration findings

## Status

Both acceptance runners now accept `--transport pipe|tcp`. Pipe is the selected
default as requested; TCP remains an explicit, real-listener mode. The isolated
TCP runs preserve both committed baselines. The pipe runs are **not yet a passing
replacement gate**. Their deviations are reported and cause nonzero exits; no
baseline was regenerated or weakened.

The runners extract the pinned v20251025 wiki to a temporary FitNesseRoot and
start an isolated FitNesse HTTP service. TCP mode also starts and probes an
isolated Perl listener. Pipe mode writes temporary root-level FitNesse runner
defaults naming the repository's absolute `bin/perl-slim`, `%m`, and port `1`,
and does not start a Perl TCP listener. These defaults let nested PageDriver
requests reach the live FitNesse instance and launch Perl children. The native
suite request also supplies the verified `COMMAND_PATTERN`, `TEST_RUNNER`, and
`SLIM_PORT` URL overrides. Page-local runner configuration remains effective in
the individual-page mode.

The previously verified `fitnesse.jar -c` URL form still launches the Perl child
for an ordinary page. It is not used by these runners: a nested PageDriver probe
from `-c` mode attempted an HTTP request to the configured FitNesse port and
received `Connection refused`. The long-lived HTTP service is required for the
existing nested-request fixtures. The same command-pattern, runner, and port
variables are supplied on the suite request URL and as temporary root defaults
for nested requests.

Commands:

```sh
bin/test-fitnesse --transport pipe
bin/test-fitnesse --transport tcp
bin/test-fitnesse-suite --transport pipe
bin/test-fitnesse-suite --transport tcp
```

The mode is printed at startup. Pipe attribution requires the exact Perl child
command, port argument `1`, and exit status zero; the native verifier also
accepts the audited `remote_debug` label only when the logged command is still
the exact Perl child. TCP attribution requires the owned listener's address and
balanced protocol request/response trace.

## Observed pipe results

The final individual pipe run selected all 50 pages. 49 returned parseable
results and all 49 identified the Perl child; one result was incomplete, so the
gate exited 1. The two startup checks using uppercase `SLIM` labels are now
attributed case-insensitively and do not count as Java backends.
Parsed totals before the incomplete page were 365 right, 6 wrong, 2 ignored,
and 0 exceptions. The committed TCP baseline is 373/7/2/0.

The incomplete page is
`TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.PartiallyWorking_SettingSlimFlags`.
Its real FitNesse command was:

```text
/workspaces/test-slim/bin/perl-slim -v -s 1 1
```

`bin/perl-slim` currently accepts only a port argument and exits 255 with its
usage message for these forwarded `SLIM_FLAGS`. FitNesse therefore produced no
primary page counts. This is not counted as a pass or converted into an expected
fixture exception. A pinned Java child-process control for the same unmodified
page completed with 7 right, 0 wrong, 0 ignored, and 12 exceptions, exit code 0.
The prior TCP baseline for the Perl service is 9/0/0/0 because that execution
used a separately managed listener and did not launch a child with these flags.
Correctly reproducing the page in pipe mode requires an explicit decision and
implementation for the server's `-v`/`-s` command-line behavior and per-command
timeout semantics; silently discarding the flags would make the test appear to
pass without testing its stated behavior.

The individual pipe run also changed
`TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket`
from 3/1/0/0 to 4/0/0/0. Its nested page requests TCP port 8099 and expects no
server there. Pipe mode correctly starts no external Perl listener, so the
connection failure is observed as intended. This is a transport/environment
difference; starting a listener solely to restore the old wrong assertion
would falsify that test condition.

The native pipe run selected all 93 pages and positively attributed three
FitNesse child-process commands to Perl. It exited 1 on these exact per-page
deviations from the committed TCP baseline:

| Page | TCP baseline (R/W/I/E) | Pipe observed (R/W/I/E) | Evidence |
|---|---:|---:|---|
| `ScenarioLibraryTestSuite.ScenariosOnlyInSlimTests` | 2/0/0/0 | 1/1/0/0 | Nested page assertion `should not contain "brother content"` fails under the HTTP nested-request context. |
| `TestExceptionIsDisplayed.ParameterConversionExceptions` | 3/14/0/0 | 2/15/0/0 | One additional nested-page rendering assertion is wrong; the Perl child completed normally. |
| `TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.A_TimeoutAsSlimHeaderNotReceived` | 2/2/0/0 | 3/1/0/0 | Child pipe runner supplies the header that the page's deliberately broken startup configuration expects to miss. |
| `TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket` | 3/1/0/0 | 4/0/0/0 | No TCP listener occupies the page's target port in pipe mode. |
| `TestSystemSlimSuite.ManualStartofSlimService` | 2/2/0/0 | 4/0/0/0 | Child launch overrides the page's manually-started service condition. |

Native pipe totals were 540 right, 44 wrong, 5 ignored, and 315 exceptions,
versus the committed TCP baseline of 538/46/5/315. The native runner did not
accept these changed counts. `SLIM:remote_debug:<Perl runner>` is accepted only
alongside the exact logged Perl command and exit 0; it is not treated as Java
backend evidence.

## TCP verification

`bin/test-fitnesse --transport tcp` exited 0: 50/50 pages, 45 conformant, 373
right, 7 wrong, 2 ignored, 0 exceptions, no regressions, and zero server
crashes. All 50 execution logs identified the isolated external Perl listener.

`bin/test-fitnesse-suite --transport tcp` exited 0: 93/93 pages, 538 right, 46
wrong, 5 ignored, 315 exceptions. The Perl listener logged 724 requests with
matching responses; three execution logs identified the listener.

## Decision needed before making pipe the passing gate

The demonstrated pipe differences are not protocol framing failures. They arise
from startup flags and environmental assumptions in test-system acceptance
pages, plus nested-page behavior under the isolated FitNesse context. The runner
keeps these differences visible and returns nonzero. Do not approve a new pipe
baseline until each changed page's intended test-system behavior is reviewed;
do not restore the TCP baseline by adding a fake listener, filtering the flags,
or rewriting assertions. Until the `SLIM_FLAGS` behavior and the five native
page deltas have a correct disposition, the existing TCP gates remain the only
verified baseline gates even though pipe is available as the requested default.
