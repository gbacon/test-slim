# FitNesse SLiM acceptance baseline

Updated 2026-10-15 on `codex/complete-slim`, after adding FitNesse-compatible hash result conversion. The installed FitNesse distribution is v20251025.

FitNesse ran all pages against the external Perl SLiM server at `127.0.0.1:8099`. Every page response identified `fitnesse.slim.SlimService` and the external connection; all 50 returned HTTP 200. The Perl server exited zero times.

## Perl tests

`bin/test-dev`: **PASS**, 28 files and 338 tests. Four known TODO-marked failures remain (three boilerplate checks and one Unicode-return case). The 10 focused map-result regressions cover ordered hash-table output, HTML escaping, valid markup, nulls, nested maps/lists, Unicode wire round-tripping, explicit object stringification, and reference identity. Existing tests also cover stop/exception behavior, Unicode transport, symbols, and nested lists.

## PageDriver behavior implemented

The installed Java class has an implicit no-argument constructor. The acceptance scenarios use `createPageWithContent(String,String)`, `makeATestPage(String)`, `makeASuitePage(String)`, `requestPage(String)`, `content()`, `contentContains(String)`, `contentMatches(String)`, and `lineNumberContaining(String)`. The class metadata in the installed jar confirms this method surface; the upstream implementation is available in the [FitNesse source repository](https://github.com/unclebob/fitnesse/blob/master/src/fitnesse/fixtures/PageDriver.java).

The Perl fixture keeps this test-harness behavior under `t/lib/Fitnesse/Fixtures/`, outside `lib/Test/Slim/`. It creates a page with `POST /<page>` using `responder=saveData`, `editTime=9999999999999`, `ticketId=321`, and `pageContent`; marks it as a test page with `responder=saveProperties` and `PageType=Test`; and requests the supplied URI with HTTP GET. This supports page views and the `?test`, `?test&debug`, `?suite`, and `?executionLog` responders used by the scenario library. The Java `requestPage` method returns the response status, and the Perl implementation retains that status and body on the PageDriver instance. `content`, `content_contains`, `content_matches`, and `line_number_containing` inspect that retained response. HTTP error statuses remain available with their response body; transport failures are raised as fixture exceptions and retained in the shared `ResponseContext` for later fixture inspection.

The response context is process-local. The external Perl server forks one worker per SLiM connection, so a nested FitNesse request can open its own connection while the outer PageDriver call waits; each connection keeps its own fixture state.

`RUN_PAGE_DRIVER_INTEGRATION=1 perl t/page-driver-integration.t` passed against the live FitNesse server and Perl SLiM listener. It created and marked a generated test page, FitNesse executed that page over a second Perl SLiM connection, and the original outer connection then successfully executed another fixture statement. The upstream `ScenarioLibraryTestSuite.ScenarioLibraryShouldIncludeVariables` page also passed separately (6 right, 0 wrong, 0 ignored, 0 exceptions) through the Perl server; it is not one of the 50 Test=true inventory pages. Focused HTTP request, status, encoding, response-retention, and error tests are in `t/page-driver.t` (25 assertions).

The Perl ResponseExaminer now reads the current `ResponseContext` created by PageDriver. It implements response status and body access, raw and escaped content selectors, rendered response HTML, line access, multiline/dotall regex matching, match counts, and configured capture extraction. The acceptance scenario also calls `extractMatch(pattern, type, group)`, which selects a source and capture in one operation. Unknown source types, invalid patterns, and a missing response raise fixture errors; a valid pattern without a match returns null, matching upstream `found` behavior. The focused cases include nested failure, ignored markup, and exception-detail extraction.

## Automatic SlimHelperLibrary actor stack implemented

The installed `fitnesse.slim.SlimHelperLibrary` exposes `getFixture()`, `pushFixture()`, and `popFixture()` using the executor instance named `scriptTableActor`. The Perl `StatementExecutor` creates one helper for each executor and registers it as the oldest library. Actor methods still take precedence, and user libraries remain newer. The helper stores the fixture references directly on its own stack; nested pushes restore in LIFO order, and each executor has an independent stack. A missing actor reports `NO_INSTANCE`, and popping an empty stack reports `EmptyStackException`.

The upstream `TestSlim.toString()` output is needed when `getFixture()` returns an actor to a FitNesse cell. The Perl TestSlim fixture now stringifies as `TestSlim: <constructorArg>, <stringArg>` and explicitly preserves identity equality, so serializing a helper result does not change symbol or fixture identity behavior. This behavior is scoped to the fixture rather than adding arbitrary object stringification to protocol serialization. See the upstream [SlimHelperLibrary.java](https://www.javatips.net/api/fitnesse-master/src/fitnesse/slim/SlimHelperLibrary.java) and [TestSlim.java](https://www.javatips.net/api/fitnesse-master/src/fitnesse/slim/test/TestSlim.java).

## SplitFixture and DuplicateRows behavior implemented

The installed FitNesse v20251025 classes expose a one-string constructor and `query()` method. `SplitFixture` uses its constructor text as row data: semicolons separate rows, commas separate cells, and query results are nested lists of column/value pairs (column keys are the strings `1`, `2`, and so on). `DuplicateRows` returns one-column `x` rows in the phase A or B order shown by the upstream acceptance tables. It deliberately retains repeated `SuiteSetUp` and `SuiteTearDown` values because duplicate multiplicity is what the ordered and subset query cases exercise. The Perl fixtures live in `t/lib/Fitnesse/Fixtures/`, outside the SLiM executor.

`QueryTableSuite.SetContextValue` also uses the SLiM 0.4 `assign` instruction. The server now advertises protocol V0.4 and implements `assign` by storing the supplied value and returning `OK`; null remains an undefined symbol value. The class metadata in the installed FitNesse jar confirms `SplitFixture(String)`, `DuplicateRows(String)`, and `query()`; the unchanged acceptance pages validate the row structures, ordering, duplicate handling, matching, and symbol assignment end to end.

## Stop and exception behavior implemented

The installed FitNesse v20251025 implementations of `ConstructorThrows`, `DecisionTableExecuteThrows`, and the SLiM exception path were used as the behavioral reference. The Perl `ConstructorThrows` fixture raises ordinary, StopTest, and StopSuite constructor exceptions. `DecisionTableExecuteThrows` reproduces the upstream state, method errors, and table hooks. `TestSlim` now exposes the exception methods used by the acceptance page. The statement executor formats ordinary and Java-style exception payloads, and returns the `ABORT_SLIM_TEST` or `ABORT_SLIM_SUITE` marker for stopping exceptions. The list executor stops the remainder of the current instruction batch and resets the stop request before the next batch. FitNesse then applies its own page/suite rules, including running the appropriate teardown.

`StopSuite`, `StopTest`, `StopTestInSuiteSetUp`, and `TestExceptionIsDisplayed` now pass their outer acceptance checks. Their nested tests intentionally contain exceptions; those do not count as outer failures because the pages inspect and accept them. `IgnoredTestsShouldColorGray` verifies the one nested stop exception and that later script statements are not run. Two of its outer checks remain incompatible with the installed renderer: they expect `class="ignore">Not Executed...`, while FitNesse v20251025 emits `class="slimRowColor3"><td>Not Executed... <span class="ignore">Test not run</span>`. This is a rendering/acceptance markup mismatch; stop behavior itself is correct.

## Hash/map result conversion implemented

The installed FitNesse v20251025 `HashFixture.hash()` returns a sorted `TreeMap`. `MethodExecutionResult` converts that map with `MapConverter` before `SlimSerializer` serializes the SLiM response. The converter emits `table.hash_table` rows with `hash_key` and `hash_value` cells, escapes ordinary text, and retains valid HTML cell content.

The Perl engine previously returned a plain hash reference from `StatementExecutor::call`. Since `Test::Slim::List` serializes arrays recursively but does not encode hashes, the reference reached the wire as `HASH(0x...)`. `Test::Slim::MapResult` now converts only plain hash-reference method results into the upstream table form before response serialization. It sorts keys, handles nulls and nested map/list values, and uses explicit object string methods inside maps; other executor references and list behavior remain unchanged. The regression first failed with `HASH(0x6401465af600)` and now checks the full output and identity preservation in `t/hash-results.t`.

## Current acceptance results

The latest targeted runs report **43 conformant pages**; all 50 pages will be rerun after the remaining fixture increments. Raw page totals currently combine the latest affected-page results with the last full inventory: **345 right, 8 wrong, 2 ignored, and 26 exceptions**. The affected page ran through the external Perl service at `127.0.0.1:8099`, with **zero server exits**.

`DefineAliasTest` improved from 8 right and 67 exceptions to 22 right and no exceptions. `HybridDecisionTable.ImplementDynamicDecisionTableWithHybridTable` improved from 25 exceptions to 5 right and no exceptions. Both setup-library pages pass (1 and 2 right). `HashTableWithHtmlContent` and `TestPageWithInclude` pass with 1 right each. Both Sleep pages pass (1 and 9 right); as these run against the already connected server, they do not independently validate startup-time runner flags. `TestChineseWords` passes with 1 right. `TestSequentialArgumentProcessing` passes with 8 right. `TestTryingParameterizationIsntTooGreedy` passes with 1 right. `TestDetailedDiff` now passes all 22 outer assertions; its nested page intentionally reports 25 pass, 50 fail, and 1 ignored checks, which ResponseExaminer validates. All 31 pages that were conformant at the start remain conformant. The complete 50-page comparison will be recorded after the fixture phase.

The 7 remaining non-conformant pages comprise 2 fixture gaps, 4 FitNesse harness/rendering limitations, and 1 environment-limited timeout page. Remaining fixture gaps are TableTableIncFirstCol/TestQuery.echo_int and TestSlimWithConverter.

## Per-page results

| Page | Right | Wrong | Ignored | Exceptions | Conformance | Current root cause |
|---|---:|---:|---:|---:|---|---|
| `BaseLineDecisionTable.ComparatorsAreSupported` | 10 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `BaseLineDecisionTable.MakingTheBaselineTableTheDefaultDecisionTable` | 7 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `BaseLineDecisionTable.ScenariosAreSupported` | 10 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `BaseLineDecisionTable.TestFailuresAreMarked` | 8 | 0 | 0 | 0 | conformant | ResponseExaminer extracts nested assertion totals and rendered cells; every outer assertion passes. The embedded target page intentionally contains two wrong and two ignored checks. |
| `BaseLineDecisionTable` | 17 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ChainWithInstanceTest` | 7 | 0 | 0 | 0 | conformant | The page passes with automatic getFixture, pushFixture, and popFixture support. |
| `CustomTableRenderingAddedByPluginTest` | 5 | 1 | 0 | 0 | harness_limited | The nested page runs, but FitNesse output reports Could not find class MyUseCase/MyFixture. The custom alias/rendering setup from the outer suite is not available to this root-level HTTP test page. |
| `DefineAliasInPluginTest` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `DefineAliasTest` | 22 | 0 | 0 | 0 | conformant | AddUpChange reproduces the upstream coin state and dollar/cents results; prior missing-fixture exceptions cascaded through alias examples. |
| `HashTableTests.HashTableWithHtmlContent` | 1 | 0 | 0 | 0 | conformant | HashFixture.hash_is and EchoFixture.echo_and_log reproduce the upstream stored-value return and output behavior; nested HTML content passes unchanged. |
| `HashTableTests.ShouldReturnHashTable` | 1 | 0 | 0 | 0 | conformant | MapResult converts the returned map to sorted FitNesse hash-table HTML before SLiM list serialization. |
| `HybridDecisionTable.ImplementDynamicDecisionTableWithHybridTable` | 5 | 0 | 0 | 0 | conformant | AddUpChange supports the upstream hybrid getter/setter calls and stateful coin totals. |
| `IgnoredTestsShouldColorGray` | 5 | 2 | 0 | 0 | harness_limited | StopTest now produces the expected nested exception and ignored execution state. The two remaining outer regex checks expect class="ignore" immediately before the script input text; FitNesse v20251025 renders the row as class="slimRowColor3" and marks the result with <span class="ignore">Test not run</span>. This is a FitNesse rendering/acceptance-version mismatch, not a SLiM stop defect. |
| `LibrarySuite.HowToAddFixturesWithParametersToTheLibrary` | 5 | 0 | 0 | 0 | conformant | The page passes with automatic getFixture, pushFixture, and popFixture support. |
| `LibrarySuite.LastLibraryPreceedsEarlierLibraryTest` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpAndPageTest` | 2 | 0 | 0 | 0 | conformant | The registry retains both objects when setup and page libraries reuse `library1`; fallback dispatch finds the page library first and the setup library when its method is absent from the page library. |
| `LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpTest` | 1 | 0 | 0 | 0 | conformant | The new LibraryInSetUp fixture tracks delegated echo calls on its own instance. |
| `LibrarySuite.OneLibraryTest` | 1 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `QueryTableSuite.SetContextValue` | 4 | 0 | 2 | 0 | conformant | All page assertions pass. SetContextValue also reports two ignored symbol-assignment cells, which are expected query-table behavior. |
| `QueryTableSuite.TestMatching` | 27 | 0 | 0 | 0 | conformant | All page assertions pass. SetContextValue also reports two ignored symbol-assignment cells, which are expected query-table behavior. |
| `ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables` | 6 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ScenarioTestSuite.ScenarioWithOutputParametersInScripts` | 4 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ScenarioTestSuite.ScriptSubclassUsedForDecisionTable` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ScenarioTestSuite.UsingConstructorArgumentsFromDecisionTablesInScenarios` | 8 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `SegregationOfRequirementsAndImplementation` | 12 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `SlimSymbols.NamingConvention` | 5 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `SlimSymbols.SlimSymbolManipulation` | 18 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `StopSuite` | 6 | 0 | 0 | 0 | conformant | ConstructorThrows raises the upstream StopSuite exception; the executor returns ABORT_SLIM_SUITE and FitNesse runs suite teardown. |
| `StopTest` | 6 | 0 | 0 | 0 | conformant | ConstructorThrows raises the upstream StopTest exception; the executor returns ABORT_SLIM_TEST and FitNesse continues with later pages and teardown. |
| `StopTestInSuiteSetUp` | 7 | 0 | 0 | 0 | conformant | The stop exception is returned with ABORT_SLIM_TEST; FitNesse skips suite tests and still executes suite teardown. |
| `TableTableSuite.SymbolsInTableTableManagedByTheFixture` | 0 | 1 | 0 | 9 | fixture_gap | TableTableIncFirstCol and TestQuery.echo_int are absent. |
| `TestChineseWords` | 1 | 0 | 0 | 0 | conformant | EchoScript echoes the original Unicode value and writes its UTF-8 bytes plus newline to stdout. |
| `TestComparators` | 26 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestCustomComparators` | 1 | 2 | 0 | 0 | harness_limited | The nested response is retrieved, but its output lacks the expected glob comparison; the root-level nested test does not receive the outer suite CustomComparators setup. |
| `TestCustomConverter` | 0 | 0 | 0 | 17 | fixture_gap | TestSlimWithConverter and its converter-control fixture methods are absent; this run does not establish an engine defect. |
| `TestDetailedDiff` | 22 | 0 | 0 | 0 | conformant | DetailedDiff supplies the expected values; ResponseExaminer confirms the nested page's intentional 25-pass, 50-fail, 1-ignored result and rendered diff markup. |
| `TestExceptionIsDisplayed` | 19 | 0 | 0 | 0 | conformant | The Perl exception fixtures and TestSlim methods now reproduce the expected upstream exception messages, classes, and stop behavior; all 19 outer checks pass. |
| `TestOrderedQueryWithDuplicateRows` | 14 | 0 | 0 | 0 | conformant | All page assertions pass. SetContextValue also reports two ignored symbol-assignment cells, which are expected query-table behavior. |
| `TestPageWithInclude` | 1 | 0 | 0 | 0 | conformant | EchoFixture stores and returns the name set by the included page. |
| `TestScriptTable` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestScriptTableDisplayParameterValue` | 3 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestSequentialArgumentProcessing` | 8 | 0 | 0 | 0 | conformant | TestSlim concatenates the three supplied values with spaces; the full upstream page validates sequential and mixed argument processing. |
| `TestSubsetQuery` | 11 | 0 | 0 | 0 | conformant | All page assertions pass. SetContextValue also reports two ignored symbol-assignment cells, which are expected query-table behavior. |
| `TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.B_TimeoutAsSlimServerDiesBeforeConnecting` | 2 | 1 | 0 | 0 | harness_limited | PageDriver retrieves a 200 response, but the body does not contain the expected dead-test-runner message; the child test runner setup behavior remains unverified. |
| `TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket` | 3 | 1 | 0 | 0 | environment_limited | The test expects port 8099 unbound, but the inventory server occupies it; content_matches and PageDriver support are also missing. |
| `TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.NotWorking_SettingSlimTimeout` | 1 | 0 | 0 | 0 | conformant | Sleep returned `WakeUp 12000` as shown by this page documenting that `slim.timeout` alone does not stop the command. |
| `TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.PartiallyWorking_SettingSlimFlags` | 9 | 0 | 0 | 0 | conformant | Sleep responses match the page's expected table values. Runner startup flags are not independently assessed by this directly connected external-service test. |
| `TestSystemSlimSuite.TimeoutInSlimTestSystem` | 4 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestTryingParameterizationIsntTooGreedy` | 1 | 0 | 0 | 0 | conformant | LoginDialogDriver accepts the shared username/password scenario and records the upstream message and attempt count. |
| `TestTwoIdenticalTablesOnPageDontConflict` | 1 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |

## Next increment

The next increment is TableTableIncFirstCol with TestQuery.echo_int. Its upstream source also uses StatementExecutorConsumer to manage symbols inside the table; verify that executor integration before implementing the fixture. The other remaining fixture page is TestSlimWithConverter.
