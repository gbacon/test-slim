# FitNesse SLiM acceptance baseline

Post-fix baseline date: 2026-10-15. Branch: `codex/complete-slim`. FitNesse v20251025.

FitNesse is configured to use the external Perl SLiM server. Each individual page response identified `fitnesse.slim.SlimService` and `Connection to running SlimService: 127.0.0.1:8099`; FitNesse capitalizes the `testSystem` label differently on four timeout pages.

## Perl baseline

`bin/test-dev`: **PASS**, 19 files, 203 tests. Four existing failures are marked TODO (three boilerplate checks and one Unicode-return case); the harness result is PASS.

## Acceptance baseline

The local wiki has 50 pages marked `Test=true` under `SuiteSlimTests`. Each was requested individually via `?test&format=xml`; all 50 returned HTTP 200 through the external Perl server. Seventeen pages pass and 33 fail. Summed page counts: **17 right, 14 wrong, 0 ignored, 19 exceptions**. All 50 page responses confirmed the external Perl SLiM connection; the Perl server exited on **zero** pages.

## Conformance assessment

The raw FitNesse page totals remain 17 right, 14 wrong, 0 ignored, and 19 exceptions across 50 completed page requests. Seventeen pages have verified conformance; the 33 non-passing outcomes are not 33 independent SLiM defects. Review of each failing page, its parent setup, nested expected assertions, and current Perl fixtures gives this classification:

- 17 verified passes.
- 2 confirmed engine gaps: ChainWithInstanceTest lacks the automatic SlimHelperLibrary actor-stack methods; HashTableTests.ShouldReturnHashTable returns a Perl hashref as HASH(0x...).
- 18 fixture gaps: absent upstream fixture classes or methods prevent those pages from reaching the behavior they describe.
- 12 harness-limited pages: the nested page/suite driver does not execute or fetch rendered nested results; ResponseExaminer and related helpers are also absent.
- 1 environment-limited page: TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket requires port 8099 to be unbound, while the full-inventory runner itself binds the external Perl server there.

The 31 blocked or unassessable pages remain non-passing coverage, never counted as conformant. The JSON inventory carries per-page status and evidence separately from the raw counts.

### Setup and intentional inner outcomes

The inherited SuiteSlimTests/SetUp imports fitnesse.fixtures, registers PageDriver and EchoFixture libraries, and loads the custom alias, rendering, and glob-comparator plugins. LibrarySuite/SetUp adds the library fixture path, and LibraryInSetUpSuite registers its own setup library. The current Perl PageDriver in t/lib/Fitnesse/Fixtures/PageDriver.pm only stores source content and returns a hard-coded 200 from request_page; it does not run a nested test or fetch its result HTML. This explains why outer assertions in page-rendering tests cannot observe the expected FitNesse output.

Several pages intentionally produce wrong cells, exceptions, ignored rows, stopped tests, or timeouts inside an embedded test. BaseLineDecisionTable.TestFailuresAreMarked expects its embedded page to have 8 right, 2 wrong, 2 ignored, and 0 exceptions. TestDetailedDiff expects 25 right, 50 wrong, 1 ignored, and 0 exceptions. TestExceptionIsDisplayed expects 8 right, 1 wrong, 0 ignored, and 18 exceptions. StopSuite, StopTest, and StopTestInSuiteSetUp assert skip markers and teardown output. These are intended inner outcomes; the outer acceptance page must still pass while checking them. Because the page-driver harness fails first, these behaviors remain unverified rather than being counted as engine defects or passing conformance.

### PageDriver and ResponseExaminer dependency investigation

The installed FitNesse v20251025 jar contains `fitnesse.fixtures.PageDriver` and `fitnesse.fixtures.ResponseExaminer`. The shared upstream `SuiteAcceptanceTests/ScenarioLibrary` shows the required path: `given page` creates content through PageDriver; `given test page` marks it as a Test page; `when page ... is tested` calls `request_page` with `?test`; the scenario then starts ResponseExaminer, selects `contents` or `pageHtml`, sets a regex and capture group, and stores the extracted result in `$HTML_Result` or `$HTML_Input`. Other scenarios fetch `?suite`, `?executionLog`, or inspect the last response with `content`, `content_contains`, and `content_matches`. The outer acceptance pages use those values to verify expected inner pass/fail/ignore/exception HTML, including output around intentionally failing assertions.

Upstream's Java implementation uses FitNesse's in-process fixture context: PageDriver delegates page creation and request execution to FitNesse helpers, and ResponseExaminer reads the most recent response and current page from `FitnesseFixtureContext`. This is why a Perl translation cannot use that context directly. Its architecture-compatible equivalent is an HTTP-based test harness under `t/lib/Fitnesse/Fixtures/`: create and mark pages through FitNesse responders, request `?test`/`?suite`/`?executionLog`, save the response body and source page HTML in a small shared harness context, then perform ResponseExaminer's regex extraction over that data. These operations should remain outside `lib/Test/Slim/`.

There is a blocking dependency before that implementation can safely run. An HTTP `?test` request starts a separate FitNesse test execution and therefore a second SLiM client connection while the outer acceptance test's PageDriver call is still waiting. `Test::Slim::Server::run` currently accepts a connection and calls `process` inline; `process` does not return until the current connection ends. The server therefore cannot accept and serve the nested connection during the PageDriver call. A fixture-only implementation would hang until FitNesse times out. This is a harness/server concurrency limitation, not a malformed SLiM frame or a fixture-method resolution defect.

Recommended staged work:

1. Add regression coverage for two simultaneous SLiM clients, and refactor connection execution so each connection has isolated actor/library/symbol state. Add bounded worker handling (or an equivalent concurrency mechanism) so a nested test can complete while the outer client is blocked in an HTTP fixture call. Keep framing and statement semantics unchanged.
2. Implement the minimal Perl PageDriver HTTP operations actually used by the acceptance inventory: create a page, mark a test page, request page/suite/execution-log responders, and retain status/body/source content. Validate page creation and request behavior against FitNesse v20251025 without running nested SLiM yet.
3. Implement ResponseExaminer separately over the retained harness response/page content, including the `contents` and `pageHtml` source types, multiline/dotall regex matching, capture group selection, and no-match behavior. Add focused unit tests with deterministic HTTP responses.
4. Run embedded acceptance pages through the external Perl service, then rerun all 50 pages. Pages that uncover independent missing fixture families remain blocked and must not be reported as harness successes.

The current 50-page raw totals and conformance classifications are unchanged by this investigation: 17 pages pass and 33 fail, with 17 confirmed conformant pages, 2 confirmed engine gaps, 18 fixture gaps, 12 harness-limited pages, and 1 environment-limited page. No nested harness behavior was implemented or newly verified in this increment.

LibrarySuite.HowToAddFixturesWithParametersToTheLibrary also includes an explanatory negative example where a query method is absent; that example is not an outer expected failure. The timeout pages document their stated behavior and caveats, but their missing Sleep fixtures currently prevent meaningful verification. For the no-server test, run the outer Perl endpoint on a different port and leave 8099 unbound; keep the wiki page unchanged.

The confirmed hash result issue is distinct from missing hash-fixture methods: current result XML contains HASH(0x...) for HashFixture.hash. The SLiM protocol carries strings and nested lists, and FitNesse documents hash/map values as fixture data types; this response is a real value-formatting gap. It should get a focused regression before a serialization fix. Upstream references: [SLiM protocol and library lookup](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/SlimProtocol.html), [exception and stop/ignore behavior](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/ExceptionHandling.html), [query-table matching](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/QueryTable.html), [hash/map data types](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/DataTypes.html), [custom converter behavior](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/CustomTypes.html), [scenario matching and output parameters](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/ScenarioTable.html), [sequential script arguments](https://fitnesse.org/FitNesse/UserGuide/WritingAcceptanceTests/SliM/ScriptTable.html), and [custom comparator configuration](https://fitnesse.org/FitNesse/UserGuide/AdministeringFitNesse/ConfigurationFile.html).

A request to `SuiteSlimTests?suite&format=xml` returned HTTP 200 but only five results in the `BaseLineDecisionTable` subtree (0 right, 0 wrong, 0 ignored, 175 exceptions summed). It did not enumerate the 50 test-marked pages. Therefore the page-by-page runs below are the acceptance inventory; the suite-responder response is recorded as a harness selection limitation.

Before the fix, the Perl transcript showed `Can't use string ("[000006:000048:scriptTable_42_0/...") as an ARRAY ref while "strict refs" in use at lib/Test/Slim/ListExecutor.pm line 19.` The frame and nested statement were valid. The list parser consumed the delimiter while taking a zero-length argument, failed nested decoding, and left the encoded statement as a scalar for `ListExecutor` to dereference. `_take_utf16_units` now leaves input untouched when zero units are requested. All four affected pages were rerun, and none terminated the Perl process.

The previous ListExecutor stabilization changed `TestDetailedDiff` from an exception to a wrong assertion because execution continued far enough to expose missing `ResponseExaminer`/`EchoFixture` methods. That classification change was not an assertion improvement. The current increment adds five passing pages: three decision-table pages, `ScenarioWithOutputParametersInDecisionTables`, and `SegregationOfRequirementsAndImplementation`.

## Eg.Division fixture increment

The installed FitNesse `eg.Division` class has a public no-argument constructor, public `double` fields `numerator` and `denominator`, setters `setNumerator(double)` and `setDenominator(double)`, and `quotient()` returning `double`. The Perl fixture in `t/lib/Eg/Division.pm` reproduces that state and API, formats quotient results with Java-compatible double strings (including `10.0`), and returns `NaN` or signed infinity for zero denominators. Focused coverage is in `t/eg-division.t`.

This increment changed the full inventory from 8 to 12 passing pages. Newly passing pages: `BaseLineDecisionTable.ComparatorsAreSupported`, `ScenarioTestSuite.ScenarioWithOutputParametersInScripts`, `ScenarioTestSuite.ScriptSubclassUsedForDecisionTable`, and `ScenarioTestSuite.UsingConstructorArgumentsFromDecisionTablesInScenarios`. `ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables` and `SegregationOfRequirementsAndImplementation` now reach assertion-level failures; both retain `The instance null does not exist` due to scenario actor handling. `BaseLineDecisionTable` still fails because `ShouldIBuyMilk` is a separate missing fixture. These issues remain independent from `Eg.Division`.

## Scenario dispatch and milk fixture increment

The two scenario failures were an executor defect. FitNesse invokes scenario steps on `scriptTableActor`, which is a synthetic actor name without a separately constructed actor instance; Java SLiM resolves those methods through registered library instances. FitNesse also invokes `cloneSymbol` using the reserved `null` target to retrieve the exact symbol value. The Perl executor previously rejected a missing actor before trying libraries and rejected the `null` helper target, producing `The instance scriptTableActor does not exist` and `The instance null does not exist`. It now searches libraries newest-first for missing scenario actors and resolves the null-target `cloneSymbol` call without stringifying or copying the referenced symbol value. The logged `ARRAY(0x...)` text was from `Statement.pm`'s debug `warn` interpolation of an in-memory nested list argument; the incoming frame itself was recursively encoded as a valid SLiM list.

The upstream `ShouldIBuyMilk` behavior is implemented in `t/lib/Fitnesse/Slim/Test/ShouldIBuyMilk.pm`: it remembers cash, remaining pints, and whether the exact string `yes` enables a card; it says `yes` only when no milk remains and either cash is greater than two or the card is enabled. Its optional table lifecycle methods are no-ops. Focused regressions are in `t/library-resolution.t` and `t/should-i-buy-milk.t`.

This increment changes the inventory from 12 to 17 passing pages. Newly passing pages: `BaseLineDecisionTable.MakingTheBaselineTableTheDefaultDecisionTable`, `BaseLineDecisionTable.ScenariosAreSupported`, `BaseLineDecisionTable`, `ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables`, and `SegregationOfRequirementsAndImplementation`. The remaining `BaseLineDecisionTable.TestFailuresAreMarked` failure is independent: its nested test still exercises missing response-examiner/page-driver fixture behavior.

## Per-page results

| Page | Raw Right | Raw Wrong | Raw Ignored | Raw Exceptions | Conformance status | Classification / evidence |
|---|---:|---:|---:|---:|---|---|
| BaseLineDecisionTable.ComparatorsAreSupported | 1 | 0 | 0 | 0 | verified pass | Passes after adding the upstream-compatible Eg.Division fixture. |
| BaseLineDecisionTable.MakingTheBaselineTableTheDefaultDecisionTable | 1 | 0 | 0 | 0 | verified pass | Passes with the upstream-compatible ShouldIBuyMilk fixture. |
| BaseLineDecisionTable.ScenariosAreSupported | 1 | 0 | 0 | 0 | verified pass | Passes with scenario calls dispatched through registered libraries. |
| BaseLineDecisionTable.TestFailuresAreMarked | 0 | 0 | 0 | 1 | harness-limited | The PageDriver lacks make_a_test_page and ResponseExaminer is absent; the observed nested actor error occurs before embedded assertions are verified. |
| BaseLineDecisionTable | 1 | 0 | 0 | 0 | verified pass | Passes with Eg.Division and ShouldIBuyMilk. |
| ChainWithInstanceTest | 0 | 1 | 0 | 0 | confirmed engine gap | Automatic SlimHelperLibrary actor-stack operations getFixture, pushFixture, and popFixture are absent. |
| CustomTableRenderingAddedByPluginTest | 0 | 1 | 0 | 0 | harness-limited | The suite loads the rendering plugin, but PageDriver returns status 200 without fetching generated-page HTML. |
| DefineAliasInPluginTest | 0 | 1 | 0 | 0 | harness-limited | The plugin alias test uses the same PageDriver stub, which inspects source rather than generated-page output. |
| DefineAliasTest | 0 | 0 | 0 | 1 | missing fixture | AddUpChange and implicit SlimHelperLibrary.getFixture are absent; later actor errors cascade. |
| HashTableTests.HashTableWithHtmlContent | 0 | 0 | 0 | 1 | missing fixture | Hash input conversion works, but hash_is and echo_and_log fixture methods are absent. |
| HashTableTests.ShouldReturnHashTable | 0 | 1 | 0 | 0 | confirmed engine gap | The Perl hashref is returned as HASH(0x...), a process-specific pointer string rather than a FitNesse-compatible hash value. |
| HybridDecisionTable.ImplementDynamicDecisionTableWithHybridTable | 0 | 0 | 0 | 1 | missing fixture | AddUpChange is absent, so hybrid getter/setter dispatch is not reached. |
| IgnoredTestsShouldColorGray | 0 | 0 | 0 | 1 | harness-limited | The page intentionally tests StopTest/ignored rendering, but PageDriver cannot execute/fetch the nested page and ResponseExaminer is absent. |
| LibrarySuite.HowToAddFixturesWithParametersToTheLibrary | 0 | 0 | 0 | 1 | missing fixture | Implicit getFixture and EchoFixture.get_string_arg are missing; the page also has an explanatory negative query example. |
| LibrarySuite.LastLibraryPreceedsEarlierLibraryTest | 1 | 0 | 0 | 0 | verified pass | Passes. |
| LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpAndPageTest | 0 | 0 | 0 | 1 | missing fixture | LibraryInSetUp and setup-library call tracking are absent. |
| LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpTest | 0 | 0 | 0 | 1 | missing fixture | LibraryInSetUp and setup-library call tracking are absent. |
| LibrarySuite.OneLibraryTest | 1 | 0 | 0 | 0 | verified pass | Passes. |
| QueryTableSuite.SetContextValue | 0 | 1 | 0 | 0 | missing fixture | SplitFixture is absent, so query rows and symbol values are not tested. |
| QueryTableSuite.TestMatching | 0 | 0 | 0 | 1 | missing fixture | SplitFixture is absent, so query matching behavior is not tested. |
| ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables | 1 | 0 | 0 | 0 | verified pass | Passes after library fallback for scriptTableActor and null-target cloneSymbol support. |
| ScenarioTestSuite.ScenarioWithOutputParametersInScripts | 1 | 0 | 0 | 0 | verified pass | Passes after Eg.Division returns Java-compatible double strings, including integral values such as 10.0. |
| ScenarioTestSuite.ScriptSubclassUsedForDecisionTable | 1 | 0 | 0 | 0 | verified pass | Passes with the new Eg.Division fixture. |
| ScenarioTestSuite.UsingConstructorArgumentsFromDecisionTablesInScenarios | 1 | 0 | 0 | 0 | verified pass | Passes with the new Eg.Division fixture; construction uses the upstream no-argument fixture constructor. |
| SegregationOfRequirementsAndImplementation | 1 | 0 | 0 | 0 | verified pass | Passes after library fallback for scriptTableActor and null-target cloneSymbol support. |
| SlimSymbols.NamingConvention | 1 | 0 | 0 | 0 | verified pass | Passes. |
| SlimSymbols.SlimSymbolManipulation | 1 | 0 | 0 | 0 | verified pass | Passes. |
| StopSuite | 0 | 1 | 0 | 0 | harness-limited | The page deliberately tests StopSuite and teardown, but PageDriver does not run nested suites or fetch result HTML. |
| StopTest | 0 | 1 | 0 | 0 | harness-limited | The page deliberately tests StopTest and teardown, but PageDriver does not run nested suites or fetch result HTML. |
| StopTestInSuiteSetUp | 0 | 1 | 0 | 0 | harness-limited | The page deliberately tests StopTest during SuiteSetUp, but PageDriver does not run nested suites or fetch result HTML. |
| TableTableSuite.SymbolsInTableTableManagedByTheFixture | 0 | 1 | 0 | 0 | missing fixture | TableTableIncFirstCol and TestQuery.echo_int are absent. |
| TestChineseWords | 0 | 0 | 0 | 1 | missing fixture | EchoScript.echo_to_stdout is absent, so Unicode stdout behavior is not reached. |
| TestComparators | 1 | 0 | 0 | 0 | verified pass | Passes. |
| TestCustomComparators | 0 | 1 | 0 | 0 | harness-limited | The suite configures the glob comparator, but PageDriver never fetches the nested TestPage result. |
| TestCustomConverter | 0 | 0 | 0 | 1 | missing fixture | TestSlimWithConverter and its converter-control fixture methods are absent; this run does not establish an engine defect. |
| TestDetailedDiff | 0 | 1 | 0 | 0 | harness-limited | The page deliberately creates mismatches and an ignored result to inspect rendered diffs, but PageDriver/ResponseExaminer cannot extract nested HTML. |
| TestExceptionIsDisplayed | 0 | 0 | 0 | 1 | harness-limited | The page deliberately checks rendered exceptions; PageDriver/ResponseExaminer and nested exception fixtures are missing. |
| TestOrderedQueryWithDuplicateRows | 0 | 0 | 0 | 1 | missing fixture | DuplicateRows is absent, so ordered-query behavior is not reached. |
| TestPageWithInclude | 0 | 0 | 0 | 1 | missing fixture | EchoFixture.set_name and name are absent. |
| TestScriptTable | 1 | 0 | 0 | 0 | verified pass | Passes. |
| TestScriptTableDisplayParameterValue | 1 | 0 | 0 | 0 | verified pass | Passes. |
| TestSequentialArgumentProcessing | 0 | 0 | 0 | 1 | missing fixture | TestSlim.concatenate_three_args is absent, so semicolon argument expansion is not assessed. |
| TestSubsetQuery | 0 | 0 | 0 | 1 | missing fixture | DuplicateRows is absent, so subset-query behavior is not reached. |
| TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.B_TimeoutAsSlimServerDiesBeforeConnecting | 0 | 1 | 0 | 0 | harness-limited | The page deliberately starts an invalid runner and checks nested HTTP output; PageDriver cannot retrieve the response. |
| TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket | 0 | 1 | 0 | 0 | environment-limited | The test expects port 8099 unbound, but the inventory server occupies it; content_matches and PageDriver support are also missing. |
| TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.NotWorking_SettingSlimTimeout | 0 | 0 | 0 | 1 | missing fixture | The page documents that slim.timeout alone does not enforce command limits, but the Sleep fixture is absent. |
| TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.PartiallyWorking_SettingSlimFlags | 0 | 0 | 0 | 1 | missing fixture | Sleep and EchoFixture timer methods are absent; stated timeout/teardown behavior is not exercised. |
| TestSystemSlimSuite.TimeoutInSlimTestSystem | 0 | 1 | 0 | 0 | harness-limited | The page checks timeout output from an embedded test, but Sleep and result retrieval are unavailable; this is not yet an engine verdict. |
| TestTryingParameterizationIsntTooGreedy | 0 | 0 | 0 | 1 | missing fixture | LoginDialogDriver and its login method are absent, so scenario selection is not assessed. |
| TestTwoIdenticalTablesOnPageDontConflict | 1 | 0 | 0 | 0 | verified pass | Passes. |

Exact rendered exception and wrong-assertion snippets for every page are stored in [`fitnesse-slim-acceptance-baseline.json`](fitnesse-slim-acceptance-baseline.json). Missing fixture classes commonly cause later `The instance ... does not exist` messages; those are recorded as cascades under the first missing class rather than independent defects.

## Prioritized implementation plan

1. **Nested acceptance harness prerequisites, then fixtures: concurrent per-connection SLiM execution followed by HTTP PageDriver and ResponseExaminer.** This is the broadest diagnostic and coverage increment: 12 pages inspect embedded test/suite HTML, including failure/exception/ignore rendering, custom plugin rendering, stop behavior, startup handling, and timeout output. It cannot be implemented as fixtures alone: the nested `?test` call creates a second client while the outer fixture command is active, and the current synchronous accept loop cannot service it. First add connection-isolation/concurrency regressions and support; then implement the separate HTTP harness and response extraction stages described above. Some embedded tests also need target fixtures, so this work makes their actual SLiM behavior observable and may expose additional gaps.

2. **Query fixture family: SplitFixture and DuplicateRows.** These named fixtures directly block four pages: both QueryTableSuite pages plus ordered and subset duplicate-row query pages. Reproduce upstream row data, constructor parsing, duplicate ordering, and query methods, then use the unchanged pages to assess query-table matching.

3. **Automatic SlimHelperLibrary actor-stack behavior.** Add the built-in getFixture, pushFixture, and popFixture behavior as an automatic library while preserving object identity. This addresses ChainWithInstanceTest and shared getFixture gaps in alias and parameterized-library coverage. Keep cloneSymbol behavior covered as part of the helper contract rather than adding ordinary methods to TestSlim.

The HashFixture.hash pointer-string response is a confirmed one-page engine gap outside those high-coverage increments. Add a focused regression and fix it as a separate, targeted hash-result conversion increment. AddUpChange, LibraryInSetUp, Echo/TestSlim method gaps, timeout fixtures, and the table-table fixture remain tracked in the per-page classifications and should be selected after the harness and shared query/helper work.
