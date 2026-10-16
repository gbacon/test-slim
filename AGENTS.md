# AGENTS.md — test-slim

## Objective

Complete and maintain `Test::Slim`, a Perl implementation of the FitNesse SLiM protocol.

The primary behavioral specification is the FitNesse SLiM protocol and its upstream acceptance tests. Existing Perl tests establish regression requirements.

Do not rewrite the implementation merely to modernize its style.

## Repository layout

- `lib/Test/Slim/` — protocol implementation
- `bin/perl-slim` — SLiM server entry point
- `bin/test-dev` — established developer/CI test command
- `t/` — Perl unit and regression tests
- `t/lib/` — test fixture implementations
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
```

Perl SLiM server:

```sh
perl -Ilib -It/lib bin/perl-slim 8099
```

FitNesse:

```sh
java -jar /opt/fitnesse/fitnesse.jar -p 8080
```

The container normally starts FitNesse automatically. Do not launch a duplicate server.

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

For a reproducible, baseline-checked run of all 50 upstream SLiM acceptance pages, use:

```sh
bin/test-fitnesse
```

This 50-page individual-page inventory is not the same selection as the complete native `FitNesse.SuiteAcceptanceTests.SuiteSlimTests?suite` responder. The native responder uses suite traversal, Test properties, pruning, legacy wiki headers, and referenced pages; suite context can also affect nested-page results. Do not infer its backend from displayed command labels. Attribute the backend from execution logs plus process or connection evidence. The v20251025 audit and exact page reconciliation are in [`docs/fitnesse-native-suite-audit.md`](docs/fitnesse-native-suite-audit.md) and `docs/fitnesse-native-suite-audit.json`. Keep the existing 50-page gate until a separately scoped native inventory has established page applicability, expected outcomes, backend, and reproducibility.

The runner starts FitNesse and the Perl SLiM listener only when their configured ports are free, verifies FitNesse HTTP readiness and the SLiM protocol greeting, and checks each page's XML execution log for the external Perl connection. It clears generated `MySuite` pages before each page request, compares conformance against `docs/fitnesse-slim-acceptance-baseline.json`, permits the five documented non-conformant pages, and fails on a missing/unexecuted page, a regression, or an unverified Perl connection. It writes detailed per-page output to ignored `.runtime/fitnesse-acceptance-results.json`. Runner settings can be overridden with `TEST_SLIM_FITNESSE_URL`, `TEST_SLIM_HOST`, `TEST_SLIM_PORT`, `TEST_SLIM_PAGE_TIMEOUT`, `TEST_SLIM_TOTAL_TIMEOUT`, `FITNESSE_JAR`, `FITNESSE_HOME`, and `FITNESSE_WIKI_ROOT`. Processes started by the runner are stopped when it exits; pre-existing services are left running.

For the complete native `?suite` selection, run the separate gate:

```sh
bin/test-fitnesse-suite
```

`bin/test-fitnesse-suite` extracts a fresh wiki from `Resources/FitNesseRoot` in the pinned FitNesse JAR, excludes generated `MySuite`, and starts isolated FitNesse and Perl services on temporary ports. It executes `FitNesse.SuiteAcceptanceTests.SuiteSlimTests?suite&format=xml`, checks the JAR/response version, and uses each result's full `pageHistoryLink` plus exact per-page right/wrong/ignored/exception counts against `docs/fitnesse-slim-native-suite-baseline.json`. It also checks suite final counts and positive backend evidence: all execution-log commands must target the runner-owned Perl port with one of the three audited labels and exit 0, and the Perl log must show balanced SLiM request/response traffic. A matching result is a no-regression result against the audited native baseline, not a claim that all selected pages conform to Perl. Known wrong and exception counts remain visible and classified in the baseline. Output and diagnostics are written to ignored `.runtime/fitnesse-native-suite-results.json`, `fitnesse-native-suite-response.xml`, and service logs. Override time limits with `TEST_SLIM_SUITE_TIMEOUT`, `TEST_SLIM_SUITE_TOTAL_TIMEOUT`, and `TEST_SLIM_SUITE_STARTUP_TIMEOUT`; use `TEST_SLIM_SUITE_LOG_DIR` to retain a separate run's artifacts. Baseline edits are never generated automatically: inspect every per-page delta against the upstream page and backend evidence, update the audit and explicit classification, then review the baseline diff. CI runs one native suite pass as a separate gate; run the command twice locally when establishing reproducibility.

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
