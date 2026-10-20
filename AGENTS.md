# AGENTS.md — test-slim

## Objective

Complete and maintain `Test::FitNesse::Slim`, a Perl implementation of the FitNesse SLiM protocol.

The primary behavioral specification is the FitNesse SLiM protocol and its upstream acceptance tests. Existing Perl tests establish regression requirements.

Do not rewrite the implementation merely to modernize its style.

## Repository layout

- `lib/Test/FitNesse/Slim/` — protocol implementation
- `bin/perl-slim` — SLiM server entry point
- `bin/test-dev` — established developer/CI test command
- `bin/test-install` — build/install/archive smoke test with external fixture and FitNesse
- `bin/check-docs` — POD syntax/rendering and Markdown local-link checks
- `t/` — Perl unit and regression tests
- `t/lib/` — test fixture implementations
- `examples/` — standalone fixture and FitNesse example page
- `docs/index.md` — documentation map
- `.devcontainer/` — Codespaces and container configuration
- `.github/workflows/` — CI
- `FitNesseRoot/` — local FitNesse wiki data, Git-ignored
- `tools/` — local tools, Git-ignored

Inspect the current tree before relying on these descriptions.

## Initial procedure

1. Read the implementation, tests, dependency manifests, and CI configuration.
2. Run `bin/test-dev` and record the baseline.
3. Verify the development container and FitNesse installation.
4. Start FitNesse and the Perl SLiM server.
5. Run the upstream SLiM acceptance suite.
6. Produce a machine-readable baseline of acceptance results.
7. Identify the next smallest independently testable missing behavior.

Do not assume previously reported test results remain current.

## Development commands

Unit and regression tests:

```sh
bin/test-dev
bin/check-docs
prove -v t/pod.t t/pod-coverage.t
bin/test-install
```

`bin/test-install` requires the pinned FitNesse JAR and tests the release
archive from an isolated install prefix. It runs the installed executable
from outside the checkout with a fixture copied outside the distribution
and checks pipe, TCP, and FitNesse-managed pipe execution.

The business-oriented installed-distribution example is available as
`bin/test-example-order-management` (pipe default) or
`bin/test-example-order-management --transport tcp`. It executes the example
suite and disposable wiki-only authoring checks; see
`examples/order-management/README.md`.

Perl SLiM server:

```sh
perl -Ilib -It/lib bin/perl-slim 8099
```

FitNesse:

```sh
java -jar /opt/fitnesse/fitnesse.jar -p 8080
```

The container normally starts FitNesse automatically. Do not launch a duplicate server.

`bin/perl-slim` accepts FitNesse's `-v` verbose flag and `-s <seconds>` per-statement timeout option before its port. Port `1` selects v0.5 stdin/stdout pipes; other valid ports start the TCP listener. Both transports send `Slim -- V0.5` for the pinned FitNesse release.

## Engineering requirements

- Add a failing regression test before fixing an observed defect.
- Preserve existing passing tests.
- Prefer focused changes with minimal behavioral scope.
- Use the existing Perl coding conventions unless a change is justified.
- Avoid introducing dependencies without a clear need.
- Keep the container build compatible with GitHub Actions.
- Do not modify upstream acceptance expectations to conceal failures.
- Do not count fixture-loading failures as protocol failures without investigating them.
- Do not count passing fixture stubs as proof of complete protocol behavior.
- Do not globally stringify references or coerce arbitrary scalar values into booleans.
- Preserve protocol-correct exception formatting.
- Treat Unicode and binary transport behavior as regression-sensitive.

## Known protocol concerns

### Malformed transport and serialized input

`bin/perl-slim` accepts six-or-more-digit byte-length prefixes. The configurable frame cap defaults to 64 MiB and is set with `TEST_SLIM_MAX_FRAME_BYTES` (allowed range 1 byte to 1 GiB). The parser also limits nesting to 128 lists, decoded elements to 1,000,000 per request, each item to 16,777,216 UTF-16 code units, and the decimal outer prefix to 32 digits. These are defensive Perl policies, not SLiM protocol requirements. A full request is deserialized before execution. Invalid framing, malformed serialized data, strict UTF-8 errors, truncation, and limit violations close only the affected connection; no recovery response is defined for them. A validly serialized malformed instruction uses the standard `MALFORMED_INSTRUCTION` exception response. Clean EOF at a frame boundary ends the Perl session. See [`docs/slim-protocol-malformed-input.md`](docs/slim-protocol-malformed-input.md) before changing these boundaries.

### Encoding

The SLiM socket frame length counts transmitted bytes. SLiM list-string lengths follow Java UTF-16 code-unit semantics. These must not be conflated.

### Symbols

Symbols may contain Perl object references. Exact-symbol substitution must preserve the original reference and object identity. Embedded-symbol interpolation is a separate operation.

### Null and booleans

Preserve distinctions between `undef`, numeric zero, empty strings, and boolean results. Serialization should follow the protocol without applying unsafe global conversions.

### Fixture resolution

Support graceful class and method names, imports, constructor arguments, and object-instance reuse.

For method dispatch, an actor's own method takes priority. Otherwise, registered library fixtures are searched from newest to oldest.

### Outstanding regression coverage

The library-resolution test currently needs explicit cases for:

- Actor method precedence over a library method
- Most recently registered library precedence
- Missing method after exhausting libraries
- Appropriate exception reporting

## Acceptance-test strategy

Begin with:

`FitNesse/SuiteAcceptanceTests/SuiteSlimTests`

Work from focused leaf pages toward broader suites.

Maintain a results inventory containing:

- Page name
- Passed assertions
- Failed assertions
- Exceptions
- Root cause
- Associated regression test
- Implementation status

Distinguish missing fixtures, unsupported features, and actual defects.

Previously investigated areas include symbol manipulation, raw symbol contents, expression evaluation, and library resolution. Verify their current status.

### Running FitNesse acceptance tests programmatically

FitNesse runs automatically in the Codespace on port 8080.

The development environment configures FitNesse to connect to the external Perl SLiM server on `127.0.0.1:8099`. Do not assume FitNesse's built-in Java SLiM implementation is being tested.

Start the Perl server if it is not already running:

```sh
perl -Ilib -It/lib bin/perl-slim 8099
```

Run an individual acceptance page through FitNesse's HTTP interface:

```sh
curl -sS \
  'http://127.0.0.1:8080/FitNesse.SuiteAcceptanceTests.SuiteSlimTests.SlimSymbols.NamingConvention?test&format=xml'
```

Run the full SLiM acceptance suite by replacing the page path with `FitNesse.SuiteAcceptanceTests.SuiteSlimTests` and using the appropriate suite responder.

Determine the response format and extract assertion counts, exceptions, and failure details. Do not treat HTTP success as test success.

Confirm that test requests reach the Perl server. If necessary, inspect its output or temporarily stop it to verify that the acceptance test fails.

Do not modify upstream acceptance pages to manufacture passing results.

Record the acceptance-test baseline before implementing additional features.

The individual and native acceptance runners accept `--transport pipe|tcp`; pipe is their selected default, and TCP remains available as an explicitly selected external listener mode. Reviewed startup-page expectations are transport-specific where a managed child and external socket listener establish different test preconditions. For example:

```sh
bin/test-fitnesse --transport tcp
bin/test-fitnesse --transport pipe
bin/test-fitnesse-suite --transport tcp
bin/test-fitnesse-suite --transport pipe
```

Both transports are regression gates: pipe mode positively attributes the FitNesse-managed Perl child, while TCP verifies the external listener and balanced request trace. Known pipe-specific results are recorded separately in the machine-readable baselines and explained in [`docs/fitnesse-acceptance-pipe-migration.md`](docs/fitnesse-acceptance-pipe-migration.md). Never regenerate either baseline from an unreviewed run.

This 50-page individual-page inventory is not the same selection as the complete native `FitNesse.SuiteAcceptanceTests.SuiteSlimTests?suite` responder. The native responder uses suite traversal, Test properties, pruning, legacy wiki headers, and referenced pages; suite context can also affect nested-page results. Do not infer its backend from displayed command labels. Attribute the backend from execution logs plus process or connection evidence. The v20251025 audit and exact page reconciliation are in [`docs/fitnesse-native-suite-audit.md`](docs/fitnesse-native-suite-audit.md) and `docs/fitnesse-native-suite-audit.json`. Keep the existing 50-page gate until a separately scoped native inventory has established page applicability, expected outcomes, backend, and reproducibility.

The individual runner extracts a fresh pinned wiki, starts isolated FitNesse and (in TCP mode) Perl services, and clears generated `MySuite` pages before each request. It compares both conformance and exact per-page assertion tuples with `docs/fitnesse-slim-acceptance-baseline.json`, and verifies the actual runner command for the selected transport. It writes detailed per-page output and logs to transport-specific ignored `.runtime/` files. FitNesse ports and timeouts are allocated by the runner; `FITNESSE_JAR`, `TEST_SLIM_PAGE_TIMEOUT`, and `TEST_SLIM_TOTAL_TIMEOUT` remain configurable. Processes and temporary wiki roots owned by the runner are cleaned up at exit.

For the complete native `?suite` selection, run the separate gate:

```sh
bin/test-fitnesse-suite
```

`bin/test-fitnesse-suite` uses the same transport selector and isolated wiki/service lifecycle. It executes `FitNesse.SuiteAcceptanceTests.SuiteSlimTests?suite&format=xml`, checks the JAR/response version, compares each full `pageHistoryLink` and all four counts against `docs/fitnesse-slim-native-suite-baseline.json`, and verifies backend attribution from execution logs plus the TCP request trace or exact Perl child command. A matching result means no regression against the selected transport's reviewed baseline, not complete SLiM conformance. Diagnostics remain under ignored `.runtime/`.

The isolated and native inventories are intentionally separate. Generate their exact set comparison and pinned-wiki pruning evidence with `bin/report-fitnesse-coverage`; review [`docs/fitnesse-acceptance-coverage.md`](docs/fitnesse-acceptance-coverage.md) and its JSON manifest. After all four gates have run, `bin/report-fitnesse-matrix` compares isolated/native by pipe/TCP, retains per-page differences, and fails on missing reports, pages, or unreviewed baseline mismatches. CI runs both reports and keeps each transport's artifacts in a separate `.runtime/` file.

Do not merely transliterate Java code to Perl. Use a native Perl style, not verbose, architecture astronautics, FooFactoryFactoryFactory nonsense that is typical to Java cargo culting. Do not write Python or FORTRAN in Perl either. Look for opportunities to exploit Perl's strengths in the design. Write like a Perl expert who is not trying to show off.

Always look for opportunities to refactor in ways that incrementally improve the design:

- Remove duplication
- Use Perl's functional-paradigm features tastefully
- We are not afraid of punctuation
- Use closures and metaprogramming where they express the design cleanly

Use good Perl style: https://perldoc.perl.org/perlstyle

To the extent possible, keep the code clean with regard to `use strict` and `use warnings`.

## Autonomy and reporting

Work independently through small, testable increments. Commit each coherent change with a descriptive message.

Before a substantial architectural change, document the proposed change and why the existing design cannot reasonably support the required behavior.

Never commit credentials, generated wiki state, temporary logs, or downloaded dependencies.

After each work unit, report (with a copy to `/tmp/codex-results.md`):

- Behavior implemented
- Tests added
- Tests run and results
- Acceptance pages affected
- Remaining blockers
- Perl regression results
- Affected FitNesse acceptance results
- Acceptance coverage: number of upstream pages passing out of 50
- Engine reliability: number of server crashes or protocol failures
- Before-and-after list of individual page statuses, not just aggregate totals to make regressions visible even when the overall pass count increases

After each work unit, update DESIGN.md to document the existing design. CRITICAL: The design must remain simple! If the design begins appearing overengineered, look for opportunities to make incremental improvements that improve the design by simplifying, removing duplication, stratifying layers, and so on.

## Definition of done

The implementation is complete when:

1. The agreed supported FitNesse SLiM acceptance suite passes.
2. Perl regression tests pass.
3. CI passes.
4. The Codespaces environment rebuilds successfully from committed configuration.
5. Remaining unsupported behaviors are documented.
6. No passing results depend on concealing failures or weakening assertions.
