# Development and verification

## Prerequisites

The declared minimum is Perl 5.36.0. The full development and FitNesse
acceptance suites have been exercised locally with Perl 5.40.1. CI targets
the Perl 5.36 release line with development tests, a build and installation,
and installed-service checks on Linux and macOS.
Runtime use requires `HTML::TreeBuilder`. Development tests use the additional
requirements listed under test dependencies in `Build.PL` and `cpanfile`.
FitNesse acceptance gates require the pinned FitNesse v20251025 JAR at
`/opt/fitnesse/fitnesse.jar` or at the path in `FITNESSE_JAR`.

## Test commands

Run the Perl suite and documentation checks with:

```sh
bin/test-dev
bin/check-docs
```

Build, install, and exercise the release archive with:

```sh
bin/test-install
```

That gate builds from `MANIFEST`, installs into a temporary prefix, runs
the installed executable from outside the checkout with a fixture copied
to a separate directory, checks pipe and TCP sessions, and tests the
installed process through FitNesse using the pinned JAR.

Run all acceptance combinations and reports with:

```sh
bin/test-fitnesse --transport pipe
bin/test-fitnesse --transport tcp
bin/test-fitnesse-suite --transport pipe
bin/test-fitnesse-suite --transport tcp
bin/report-fitnesse-coverage
bin/report-fitnesse-matrix
```

The separate business-oriented installed-distribution example is checked by:

```sh
bin/test-example-order-management
bin/test-example-order-management --transport tcp
```

It runs nine example pages, verifies their exact results, and performs
wiki-only authoring exercises in an isolated temporary FitNesse root. The
pipe run is part of CI; the TCP form is available for local transport checks.

The isolated runner executes its deliberate 50-page inventory one page at
a time. The native runner executes FitNesse's 93-page suite responder.
Each runner validates exact per-page counts and confirms the selected
Perl backend. Pipe and TCP have distinct reviewed expectations for
startup tests because they establish different process preconditions.

## Results and failures

Acceptance logs, raw responses, and per-transport result files are written
to the ignored `.runtime/` directory. A missing result, child-process
failure, wrong backend, count change, or inventory change fails the gate
and requires investigation before any baseline change.

GitHub Actions runs the Perl tests and pipe acceptance gates, the native
pipe suite, both TCP acceptance gates, and coverage/matrix reports. It also
runs `bin/test-install` so the packaged executable is exercised from an
independent prefix. Report CI conclusions only after inspecting the
actual workflow run.

The exact 50-page and 93-page populations, their intersection, and the
different evidence each mode provides are documented in
[acceptance coverage](fitnesse-acceptance-coverage.md).

The main workflow also runs the development and installed-distribution gates
on macOS 15 with Perl 5.36. A separate, manually dispatched Windows workflow
uses Strawberry Perl 5.36 for exploratory package and transport checks. Windows
is not a declared supported platform; its results do not replace the Linux or
macOS gates.

Windows does not support Perl `select` polling on ordinary child-process
pipes. The full `t/pipe-transport.t` integration test uses `IO::Select` to
drain `IPC::Open3` pipes and remains part of Linux/macOS development testing.
For cross-platform transport smoke checks, `t/portable-transport-smoke.t` uses
`IPC::Run` with a complete prebuilt pipe request and bounded execution, then
uses `IO::Select` only for a single TCP socket session. It checks the v0.5
greeting, exact framed fixture results, `bye`, child exit, and module paths.
The manually dispatched Windows workflow also retains the previously verified
PowerShell checkout-pipe probe until the Perl replacement has run on a native
Windows runner. The portable installed-distribution check uses the installed
runner and modules plus an external fixture; it does not establish that
FitNesse itself launches Perl on Windows.
