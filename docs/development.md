# Development and verification

## Prerequisites

The implementation targets Perl 5.10 or newer and requires
`HTML::TreeBuilder` at runtime. Development tests use the additional
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
