# FitNesse SLiM acceptance baseline

Post-fix baseline date: 2026-10-15. Branch: `codex/complete-slim`. FitNesse v20251025.

FitNesse is configured to use the external Perl SLiM server. Each individual page response identified `fitnesse.slim.SlimService` and `Connection to running SlimService: 127.0.0.1:8099`; FitNesse capitalizes the `testSystem` label differently on four timeout pages.

## Perl baseline

`bin/test-dev`: **PASS**, 19 files, 203 tests. Four existing failures are marked TODO (three boilerplate checks and one Unicode-return case); the harness result is PASS.

## Acceptance baseline

The local wiki has 50 pages marked `Test=true` under `SuiteSlimTests`. Each was requested individually via `?test&format=xml`; all 50 returned HTTP 200 through the external Perl server. Seventeen pages pass and 33 fail. Summed page counts: **17 right, 14 wrong, 0 ignored, 19 exceptions**. All 50 page responses confirmed the external Perl SLiM connection; the Perl server exited on **zero** pages.

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

| Page | Right | Wrong | Ignored | Exceptions | Root cause / classification |
|---|---:|---:|---:|---:|---|
| BaseLineDecisionTable.ComparatorsAreSupported | 1 | 0 | 0 | 0 | Passes after adding the upstream-compatible Eg.Division fixture. |
| BaseLineDecisionTable.MakingTheBaselineTableTheDefaultDecisionTable | 1 | 0 | 0 | 0 | Passes with the upstream-compatible `ShouldIBuyMilk` fixture. |
| BaseLineDecisionTable.ScenariosAreSupported | 1 | 0 | 0 | 0 | Passes with scenario method dispatch through the registered `Eg.Division` library. |
| BaseLineDecisionTable.TestFailuresAreMarked | 0 | 0 | 0 | 1 | Nested acceptance page executes without terminating Perl; missing nested fixture behavior still produces exceptions. |
| BaseLineDecisionTable | 1 | 0 | 0 | 0 | Passes with `Eg.Division` and `ShouldIBuyMilk`. |
| ChainWithInstanceTest | 0 | 1 | 0 | 0 | Missing TestSlim fixture methods get_fixture, push_fixture, and pop_fixture. |
| CustomTableRenderingAddedByPluginTest | 0 | 1 | 0 | 0 | FitNesse plugin/custom-rendering test-harness expectation fails; no Perl fixture load error observed. |
| DefineAliasInPluginTest | 0 | 1 | 0 | 0 | FitNesse plugin alias setup/expectation fails; no Perl fixture load error observed. |
| DefineAliasTest | 0 | 0 | 0 | 1 | Missing alias target fixture(s), causing later actor calls to cascade. |
| HashTableTests.HashTableWithHtmlContent | 0 | 0 | 0 | 1 | Missing hash_is and echo_and_log methods in existing HashFixture/EchoFixture. |
| HashTableTests.ShouldReturnHashTable | 0 | 1 | 0 | 0 | Fixture result does not match expected hash rendering/order. |
| HybridDecisionTable.ImplementDynamicDecisionTableWithHybridTable | 0 | 0 | 0 | 1 | Missing AddUpChange fixture; subsequent decision-table actor errors cascade. |
| IgnoredTestsShouldColorGray | 0 | 0 | 0 | 1 | Missing HashFixture/EchoFixture page-driver methods and ResponseExaminer fixture; server remains alive. |
| LibrarySuite.HowToAddFixturesWithParametersToTheLibrary | 0 | 0 | 0 | 1 | Missing TestSlim/EchoFixture methods used by parameterized library fixture test. |
| LibrarySuite.LastLibraryPreceedsEarlierLibraryTest | 1 | 0 | 0 | 0 | Passes. |
| LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpAndPageTest | 0 | 0 | 0 | 1 | Missing LibraryInSetUp fixture and setup-library method. |
| LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpTest | 0 | 0 | 0 | 1 | Missing LibraryInSetUp fixture and setup-library method. |
| LibrarySuite.OneLibraryTest | 1 | 0 | 0 | 0 | Passes. |
| QueryTableSuite.SetContextValue | 0 | 1 | 0 | 0 | Missing SplitFixture; result assertions then fail. |
| QueryTableSuite.TestMatching | 0 | 0 | 0 | 1 | Missing SplitFixture. |
| ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables | 1 | 0 | 0 | 0 | Passes after resolving synthetic `scriptTableActor` calls through libraries and honoring null-target `cloneSymbol`. |
| ScenarioTestSuite.ScenarioWithOutputParametersInScripts | 1 | 0 | 0 | 0 | Passes after Eg.Division returns Java-compatible double strings, including integral values such as 10.0. |
| ScenarioTestSuite.ScriptSubclassUsedForDecisionTable | 1 | 0 | 0 | 0 | Passes with the new Eg.Division fixture. |
| ScenarioTestSuite.UsingConstructorArgumentsFromDecisionTablesInScenarios | 1 | 0 | 0 | 0 | Passes with the new Eg.Division fixture; construction uses the upstream no-argument fixture constructor. |
| SegregationOfRequirementsAndImplementation | 1 | 0 | 0 | 0 | Passes after resolving synthetic scenario actors and null-target `cloneSymbol` calls. |
| SlimSymbols.NamingConvention | 1 | 0 | 0 | 0 | Passes. |
| SlimSymbols.SlimSymbolManipulation | 1 | 0 | 0 | 0 | Passes. |
| StopSuite | 0 | 1 | 0 | 0 | Nested suite-control harness assertions fail; investigate page-driver/suite responder setup before attributing to SLiM. |
| StopTest | 0 | 1 | 0 | 0 | Nested test-control harness assertions fail; investigate page-driver/suite responder setup before attributing to SLiM. |
| StopTestInSuiteSetUp | 0 | 1 | 0 | 0 | Nested suite setup/test-control harness assertions fail. |
| TableTableSuite.SymbolsInTableTableManagedByTheFixture | 0 | 1 | 0 | 0 | Missing TableTableIncFirstCol and TestQuery.echo_int fixture behavior. |
| TestChineseWords | 0 | 0 | 0 | 1 | Missing EchoScript.echo_to_stdout method. |
| TestComparators | 1 | 0 | 0 | 0 | Passes. |
| TestCustomComparators | 0 | 1 | 0 | 0 | FitNesse custom-comparator page harness expectation fails; investigate comparator registration/fixture setup. |
| TestCustomConverter | 0 | 0 | 0 | 1 | Missing TestSlimWithConverter and converter-oriented EchoFixture methods. |
| TestDetailedDiff | 0 | 1 | 0 | 0 | Missing ResponseExaminer/EchoFixture page methods; now reports wrong assertions instead of a server-crash exception. |
| TestExceptionIsDisplayed | 0 | 0 | 0 | 1 | Missing ResponseExaminer/EchoFixture page methods; nested test reports fixture exceptions without terminating Perl. |
| TestOrderedQueryWithDuplicateRows | 0 | 0 | 0 | 1 | Missing DuplicateRows fixture. |
| TestPageWithInclude | 0 | 0 | 0 | 1 | Missing EchoFixture.set_name/name methods. |
| TestScriptTable | 1 | 0 | 0 | 0 | Passes. |
| TestScriptTableDisplayParameterValue | 1 | 0 | 0 | 0 | Passes. |
| TestSequentialArgumentProcessing | 0 | 0 | 0 | 1 | Missing TestSlim.concatenate_three_args method. |
| TestSubsetQuery | 0 | 0 | 0 | 1 | Missing DuplicateRows fixture. |
| TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.B_TimeoutAsSlimServerDiesBeforeConnecting | 0 | 1 | 0 | 0 | Negative startup test page assertion fails under the running external-server harness; inspect expected startup orchestration. |
| TestSystemSlimSuite.ErrorSituationsDuringSlimServerStartup.C_TimeoutAsNoServerAtGivenSocket | 0 | 1 | 0 | 0 | Negative startup test page needs isolated no-server setup and TestSlim.content_matches helper. |
| TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.NotWorking_SettingSlimTimeout | 0 | 0 | 0 | 1 | Missing Sleep fixture and timeout methods; expected limited-support page may intentionally assert nonworking behavior. |
| TestSystemSlimSuite.HowtoEnforceA_TimelimitPerTestCommand.PartiallyWorking_SettingSlimFlags | 0 | 0 | 0 | 1 | Missing Sleep and timer methods; TearDown currently receives calls to unsupported methods. |
| TestSystemSlimSuite.TimeoutInSlimTestSystem | 0 | 1 | 0 | 0 | Timeout test completes with a timeout marker, but its outer debug-page assertions fail; likely harness expectation/configuration. |
| TestTryingParameterizationIsntTooGreedy | 0 | 0 | 0 | 1 | Missing LoginDialogDriver fixture. |
| TestTwoIdenticalTablesOnPageDontConflict | 1 | 0 | 0 | 0 | Passes. |

Exact rendered exception and wrong-assertion snippets for every page are stored in [`fitnesse-slim-acceptance-baseline.json`](fitnesse-slim-acceptance-baseline.json). Missing fixture classes commonly cause later `The instance ... does not exist` messages; those are recorded as cascades under the first missing class rather than independent defects.

## Failure groups and priority

1. **Executor stability (complete):** zero-length item extraction now leaves the list delimiter in place. Parser and socket-frame regressions cover the nested statement with an empty argument. All four crash pages and all 50 inventory pages completed with zero Perl process exits.
2. **Core acceptance fixture pack (P1):** `Eg.Division` is implemented and now passes four previously failing pages. Add the remaining shared fixture families and methods used across pages: `ShouldIBuyMilk`, `AddUpChange`, `DuplicateRows`, `SplitFixture`, `LoginDialogDriver`, and `LibraryInSetUp`; then add the specific actor methods listed in the JSON. This collapses cascades across baseline/decision, query, and setup-library pages.
3. **Existing fixture behavior (P1):** fill method gaps in `TestSlim`, `EchoFixture`, `EchoScript`, `HashFixture`, and `TestQuery`; correct hash/table result formatting and exercise the failure paths independently. These affect sequential arguments, symbols/table-table, converter, Unicode, exception, and library parameterization pages.
4. **FitNesse integration and responder semantics (P2):** investigate plugin alias/custom-renderer/comparator pages and `StopTest`/`StopSuite` nested runner pages. Verify the proper suite selection route so a suite request covers the same 50 pages as direct test requests.
5. **Timeout/startup coverage (P3):** implement or explicitly document timeout fixtures and run negative startup pages in isolated server configurations; they must not share a live endpoint that changes the expected no-server behavior.

Recommended next increment: implement shared query/table fixtures (`SplitFixture` and `DuplicateRows`), which account for multiple remaining query pages. Follow with `AddUpChange` and the remaining shared `TestSlim`/`EchoFixture` methods. `ShouldIBuyMilk` and scenario actor dispatch are complete.
