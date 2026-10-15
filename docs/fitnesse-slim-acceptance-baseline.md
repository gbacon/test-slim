# FitNesse SLiM acceptance baseline

Updated 2026-10-15 on `codex/complete-slim`, after automatic SlimHelperLibrary actor-stack support. The installed FitNesse distribution is v20251025.

FitNesse ran all pages against the external Perl SLiM server at `127.0.0.1:8099`. Every page response identified `fitnesse.slim.SlimService` and the external connection; all 50 returned HTTP 200. The Perl server exited zero times.

## Perl tests

`bin/test-dev`: **PASS**, 26 files and 307 tests. Four known TODO-marked failures remain (three boilerplate checks and one Unicode-return case). The 19 focused SlimHelperLibrary regressions cover executor construction, dispatch precedence, nested actor-stack behavior, object identity, state isolation, empty-stack errors, and upstream TestSlim stringification.

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

## Current acceptance results

The page-by-page XML inventory reports **26 conformant pages and 24 non-conformant pages**. Raw page assertion totals are **251 right, 59 wrong, 2 ignored, and 177 exceptions**. All 50 pages completed through the external Perl service at `127.0.0.1:8099`; the listener stayed alive with zero server exits. `ChainWithInstanceTest` and `LibrarySuite.HowToAddFixturesWithParametersToTheLibrary` are newly conformant. All 24 pages that passed before this increment remain conformant.

The earlier PageDriver, ResponseExaminer, and query-fixture increments remain part of this baseline. Compared with the immediately prior inventory, this increment adds two conformant pages, reduces wrong assertions from 60 to 59, and reduces exceptions from 192 to 177; the two ignored SetContextValue cells are unchanged and its outer assertions pass. All 50 final responses came from the configured external Perl SLiM server on port 8099, with zero server exits. The current page results, failure evidence, and full before-and-after status comparison are stored in the [machine-readable JSON inventory](fitnesse-slim-acceptance-baseline.json).

Failure classifications group 24 pages by primary cause: 1 confirmed engine gap, 19 fixture gaps, 3 harness or nested-setup limitations, and 1 environment-limited page. These categories do not imply 24 independent protocol defects. StopSuite, StopTest, and StopTestInSuiteSetUp execute nested suites and expose missing `ConstructorThrows`/generated fixture classes; those are fixture gaps, not PageDriver failures. The custom rendering and comparator pages receive HTTP responses but their root-level nested pages do not receive all outer suite plugin/comparator setup. The remaining startup-timeout harness page receives a 200 response without the expected dead-runner message. Response inspection now works; the remaining `IgnoredTestsShouldColorGray`, `TestDetailedDiff`, and `TestExceptionIsDisplayed` failures are caused by missing target fixtures or methods.

The previously committed baseline’s aggregate 17-right/14-wrong/19-exception values were page outcome markers (one marker per page), not assertion totals from page XML. They remain useful for historical page classification, but should not be subtracted from the current raw assertion totals. The JSON records this distinction. Historical verification snapshots in the JSON retain their original counts and identify their corresponding increment.

## Per-page results

| Page | Right | Wrong | Ignored | Exceptions | Conformance | Current root cause |
|---|---:|---:|---:|---:|---|---|
| `BaseLineDecisionTable.ComparatorsAreSupported` | 10 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `BaseLineDecisionTable.MakingTheBaselineTableTheDefaultDecisionTable` | 7 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `BaseLineDecisionTable.ScenariosAreSupported` | 10 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `BaseLineDecisionTable.TestFailuresAreMarked` | 8 | 0 | 0 | 0 | conformant | ResponseExaminer extracts nested assertion counts and rendered result cells; all outer checks pass. The embedded test intentionally contains two wrong and two ignored cells, which the outer page verifies. |
| `BaseLineDecisionTable` | 17 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ChainWithInstanceTest` | 7 | 0 | 0 | 0 | conformant | Automatic SlimHelperLibrary getFixture, pushFixture, and popFixture restore the exact actor instance and state. |
| `CustomTableRenderingAddedByPluginTest` | 5 | 1 | 0 | 0 | harness_limited | The nested page runs, but FitNesse output reports Could not find class MyUseCase/MyFixture. The custom alias/rendering setup from the outer suite is not available to this root-level HTTP test page. |
| `DefineAliasInPluginTest` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `DefineAliasTest` | 8 | 0 | 0 | 67 | fixture_gap | AddUpChange is absent; NO_INSTANCE scriptTableActor messages cascade after the fixture constructor fails. |
| `HashTableTests.HashTableWithHtmlContent` | 0 | 0 | 0 | 2 | fixture_gap | Hash input conversion works, but hash_is and echo_and_log fixture methods are absent. |
| `HashTableTests.ShouldReturnHashTable` | 0 | 1 | 0 | 0 | engine_gap | The Perl hashref is returned as HASH(0x...), a process-specific pointer string rather than a FitNesse-compatible hash value. |
| `HybridDecisionTable.ImplementDynamicDecisionTableWithHybridTable` | 0 | 0 | 0 | 25 | fixture_gap | AddUpChange is absent, so hybrid getter/setter dispatch is not reached. |
| `IgnoredTestsShouldColorGray` | 3 | 4 | 0 | 0 | fixture_gap | ResponseExaminer now runs. The nested page still cannot exercise its expected stop-and-ignore flow because the `ConstructorThrows` fixture is missing. |
| `LibrarySuite.HowToAddFixturesWithParametersToTheLibrary` | 5 | 0 | 0 | 0 | conformant | Automatic getFixture makes the actor available as a library; all outer checks pass. |
| `LibrarySuite.LastLibraryPreceedsEarlierLibraryTest` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpAndPageTest` | 1 | 0 | 0 | 2 | fixture_gap | LibraryInSetUp and setup-library call tracking are absent. |
| `LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpTest` | 0 | 0 | 0 | 2 | fixture_gap | LibraryInSetUp and setup-library call tracking are absent. |
| `LibrarySuite.OneLibraryTest` | 1 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `QueryTableSuite.SetContextValue` | 4 | 0 | 2 | 0 | conformant | SplitFixture rows match and the SLiM 0.4 assign instruction transfers the selected values into symbols; two query-table symbol cells are intentionally ignored. |
| `QueryTableSuite.TestMatching` | 27 | 0 | 0 | 0 | conformant | SplitFixture query rows pass ordered, subset, multi-column, regex, and numeric comparator matching. |
| `ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables` | 6 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ScenarioTestSuite.ScenarioWithOutputParametersInScripts` | 4 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ScenarioTestSuite.ScriptSubclassUsedForDecisionTable` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `ScenarioTestSuite.UsingConstructorArgumentsFromDecisionTablesInScenarios` | 8 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `SegregationOfRequirementsAndImplementation` | 12 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `SlimSymbols.NamingConvention` | 5 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `SlimSymbols.SlimSymbolManipulation` | 18 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `StopSuite` | 2 | 4 | 0 | 0 | fixture_gap | The nested suite request runs successfully, then fails because its generated TestPageA/TestPageB tables resolve as missing classes; the first missing stopper fixture is ConstructorThrows. |
| `StopTest` | 3 | 3 | 0 | 0 | fixture_gap | The nested suite request runs successfully, then fails because ConstructorThrows and TableNeverToBeExecuted fixture classes are absent. |
| `StopTestInSuiteSetUp` | 2 | 5 | 0 | 0 | fixture_gap | The nested suite request runs successfully, then fails because ConstructorThrows and its generated setup/page table fixtures are absent. |
| `TableTableSuite.SymbolsInTableTableManagedByTheFixture` | 0 | 1 | 0 | 9 | fixture_gap | TableTableIncFirstCol and TestQuery.echo_int are absent. |
| `TestChineseWords` | 0 | 0 | 0 | 1 | fixture_gap | EchoScript.echo_to_stdout is absent, so Unicode stdout behavior is not reached. |
| `TestComparators` | 26 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestCustomComparators` | 1 | 2 | 0 | 0 | harness_limited | The nested response is retrieved, but its output lacks the expected glob comparison; the root-level nested test does not receive the outer suite CustomComparators setup. |
| `TestCustomConverter` | 0 | 0 | 0 | 17 | fixture_gap | TestSlimWithConverter and its converter-control fixture methods are absent; this run does not establish an engine defect. |
| `TestDetailedDiff` | 1 | 21 | 0 | 0 | fixture_gap | ResponseExaminer extracts the nested response. The `DetailedDiff` fixture is absent, so expected detailed-diff output is not produced. |
| `TestExceptionIsDisplayed` | 4 | 15 | 0 | 0 | fixture_gap | ResponseExaminer inspects the nested response. The page remains blocked by missing `DecisionTableExecuteThrows`, `ConstructorThrows`, and `TestSlim` exception methods. |
| `TestOrderedQueryWithDuplicateRows` | 14 | 0 | 0 | 0 | conformant | DuplicateRows returns both upstream phase orders while preserving repeated setup and teardown rows. |
| `TestPageWithInclude` | 0 | 0 | 0 | 2 | fixture_gap | EchoFixture.set_name and name are absent. |
| `TestScriptTable` | 2 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestScriptTableDisplayParameterValue` | 3 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestSequentialArgumentProcessing` | 0 | 0 | 0 | 23 | fixture_gap | TestSlim.concatenate_three_args is absent, so semicolon argument expansion is not assessed. |
| `TestSubsetQuery` | 11 | 0 | 0 | 0 | conformant | DuplicateRows passes empty, complete, and reordered subset cases with duplicate values in the query result. |
| `TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.B_TimeoutAsSlimServerDiesBeforeConnecting` | 2 | 1 | 0 | 0 | harness_limited | PageDriver retrieves a 200 response, but the body does not contain the expected dead-test-runner message; the child test runner setup behavior remains unverified. |
| `TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket` | 3 | 1 | 0 | 0 | environment_limited | The test expects port 8099 unbound, but the inventory server occupies it; content_matches and PageDriver support are also missing. |
| `TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.NotWorking_SettingSlimTimeout` | 0 | 0 | 0 | 3 | fixture_gap | The page documents that slim.timeout alone does not enforce command limits, but the Sleep fixture is absent. |
| `TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.PartiallyWorking_SettingSlimFlags` | 0 | 0 | 0 | 22 | fixture_gap | Sleep and EchoFixture timer methods are absent; stated timeout/teardown behavior is not exercised. |
| `TestSystemSlimSuite.TimeoutInSlimTestSystem` | 4 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |
| `TestTryingParameterizationIsntTooGreedy` | 0 | 0 | 0 | 2 | fixture_gap | LoginDialogDriver and its login method are absent, so scenario selection is not assessed. |
| `TestTwoIdenticalTablesOnPageDontConflict` | 1 | 0 | 0 | 0 | conformant | The acceptance page completed with no wrong assertions or exceptions through the external Perl SLiM server. |

## Next increment

## Remaining dependency ranking

Before this increment, the stop and exception fixture set had the largest raw reach at five pages (`StopSuite`, `StopTest`, `StopTestInSuiteSetUp`, `IgnoredTestsShouldColorGray`, and `TestExceptionIsDisplayed`), but it spans several page-specific fixtures. The automatic SlimHelperLibrary was the most cohesive engine-provided helper family: its methods affected `ChainWithInstanceTest`, `DefineAliasTest`, and `LibrarySuite.HowToAddFixturesWithParametersToTheLibrary`. It made two pages conformant and reduced `DefineAliasTest` from 73 to 67 exceptions; that page now reaches its expected actor and remains blocked by the missing `AddUpChange` fixture. Its missing-actor messages cascade after fixture construction fails.

The next three coherent increments by expected page reach are the stop/exception fixture set (five pages), `AddUpChange` (two pages), and `LibraryInSetUp` behavior (two pages). Hash-table return and fixture behavior also touches two pages, split between a fixture gap and a confirmed engine gap. The JSON inventory keeps this ranking and the before-and-after status of each of the 50 pages.
