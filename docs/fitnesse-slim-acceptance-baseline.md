# FitNesse SLiM acceptance baseline

Baseline date: 2026-10-15. Branch: `codex/complete-slim`. FitNesse v20251025.

FitNesse is configured to use the external Perl SLiM server. Every individual page response reported `slim:fitnesse.slim.SlimService` and `Connection to running SlimService: 127.0.0.1:8099`.

## Perl baseline

`bin/test-dev`: **PASS**, 17 files, 171 tests. Four existing failures are marked TODO (three boilerplate checks and one Unicode-return case); the harness result is PASS.

## Acceptance baseline

The local wiki has 50 pages marked `Test=true` under `SuiteSlimTests`. Each was requested individually via `?test&format=xml`; all 50 returned HTTP 200 through the external Perl server. Eight pages passed, 42 pages failed. Summed page counts: **8 right, 13 wrong, 0 ignored, 29 exceptions**. Four pages terminated the Perl server during execution and were rerun after restarting it; each has a transport exception in its final response.

A request to `SuiteSlimTests?suite&format=xml` returned HTTP 200 but only five results in the `BaseLineDecisionTable` subtree (0 right, 0 wrong, 0 ignored, 175 exceptions summed). It did not enumerate the 50 test-marked pages. Therefore the page-by-page runs below are the acceptance inventory; the suite-responder response is recorded as a harness selection limitation.

The Perl transcript reproduced this server exit: `Can't use string ("[000006:000048:scriptTable_42_0/...") as an ARRAY ref while "strict refs" in use at lib/Test/Slim/ListExecutor.pm line 19.` FitNesse reports `Could not send/receive data with SUT` on `BaseLineDecisionTable.TestFailuresAreMarked`, `IgnoredTestsShouldColorGray`, `TestDetailedDiff`, and `TestExceptionIsDisplayed`. These four transport failures share one executor crash root cause.

## Per-page results

| Page | Right | Wrong | Ignored | Exceptions | Root cause / classification |
|---|---:|---:|---:|---:|---|
| BaseLineDecisionTable.ComparatorsAreSupported | 0 | 0 | 0 | 1 | Missing Perl fixture Eg.Division; resulting actor calls cascade. |
| BaseLineDecisionTable.MakingTheBaselineTableTheDefaultDecisionTable | 0 | 0 | 0 | 1 | Missing Perl fixture ShouldIBuyMilk; later table actors cascade. |
| BaseLineDecisionTable.ScenariosAreSupported | 0 | 0 | 0 | 1 | Missing scenario-backed fixture behavior; scenario commands do not produce expected actor instances. |
| BaseLineDecisionTable.TestFailuresAreMarked | 0 | 0 | 0 | 1 | Perl SLiM executor crash while processing nested script-table command; subsequent transport exception is cascading. |
| BaseLineDecisionTable | 0 | 0 | 0 | 1 | Missing Perl fixtures (ShouldIBuyMilk, Eg.Division); later actor instance errors cascade. |
| ChainWithInstanceTest | 0 | 1 | 0 | 0 | Missing TestSlim fixture methods get_fixture, push_fixture, and pop_fixture. |
| CustomTableRenderingAddedByPluginTest | 0 | 1 | 0 | 0 | FitNesse plugin/custom-rendering test-harness expectation fails; no Perl fixture load error observed. |
| DefineAliasInPluginTest | 0 | 1 | 0 | 0 | FitNesse plugin alias setup/expectation fails; no Perl fixture load error observed. |
| DefineAliasTest | 0 | 0 | 0 | 1 | Missing alias target fixture(s), causing later actor calls to cascade. |
| HashTableTests.HashTableWithHtmlContent | 0 | 0 | 0 | 1 | Missing hash_is and echo_and_log methods in existing HashFixture/EchoFixture. |
| HashTableTests.ShouldReturnHashTable | 0 | 1 | 0 | 0 | Fixture result does not match expected hash rendering/order. |
| HybridDecisionTable.ImplementDynamicDecisionTableWithHybridTable | 0 | 0 | 0 | 1 | Missing AddUpChange fixture; subsequent decision-table actor errors cascade. |
| IgnoredTestsShouldColorGray | 0 | 0 | 0 | 1 | Perl SLiM executor exits during nested test execution; FitNesse reports transport failure. |
| LibrarySuite.HowToAddFixturesWithParametersToTheLibrary | 0 | 0 | 0 | 1 | Missing TestSlim/EchoFixture methods used by parameterized library fixture test. |
| LibrarySuite.LastLibraryPreceedsEarlierLibraryTest | 1 | 0 | 0 | 0 | Passes. |
| LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpAndPageTest | 0 | 0 | 0 | 1 | Missing LibraryInSetUp fixture and setup-library method. |
| LibrarySuite.LibraryInSetUpSuite.LibraryInSetUpTest | 0 | 0 | 0 | 1 | Missing LibraryInSetUp fixture and setup-library method. |
| LibrarySuite.OneLibraryTest | 1 | 0 | 0 | 0 | Passes. |
| QueryTableSuite.SetContextValue | 0 | 1 | 0 | 0 | Missing SplitFixture; result assertions then fail. |
| QueryTableSuite.TestMatching | 0 | 0 | 0 | 1 | Missing SplitFixture. |
| ScenarioTestSuite.ScenarioWithOutputParametersInDecisionTables | 0 | 0 | 0 | 1 | Missing Eg.Division behavior/methods on the scenario actor. |
| ScenarioTestSuite.ScenarioWithOutputParametersInScripts | 0 | 0 | 0 | 1 | Missing Eg.Division behavior/methods on the scenario actor. |
| ScenarioTestSuite.ScriptSubclassUsedForDecisionTable | 0 | 0 | 0 | 1 | Missing Eg.Division and script actor fixture classes. |
| ScenarioTestSuite.UsingConstructorArgumentsFromDecisionTablesInScenarios | 0 | 0 | 0 | 1 | Missing Eg.Division behavior/methods on the scenario actor. |
| SegregationOfRequirementsAndImplementation | 0 | 0 | 0 | 1 | Missing Eg.Division and its decision-table methods. |
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
| TestDetailedDiff | 0 | 0 | 0 | 1 | Perl SLiM executor exits during nested test execution; FitNesse reports transport failure. |
| TestExceptionIsDisplayed | 0 | 0 | 0 | 1 | Perl SLiM executor exits during nested test execution; FitNesse reports transport failure. |
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

1. **Executor stability (P0):** fix and regression-test the `ListExecutor` nested script-table input-shape crash first. It terminated the Perl process on four pages and can invalidate all later results in an aggregate run. Preserve malformed-command error handling rather than allowing an uncaught process exit.
2. **Core acceptance fixture pack (P1):** add the missing shared fixture families and methods used across pages: `Eg.Division`, `ShouldIBuyMilk`, `AddUpChange`, `DuplicateRows`, `SplitFixture`, `LoginDialogDriver`, and `LibraryInSetUp`; then add the specific actor methods listed in the JSON. This collapses many cascades and covers baseline/decision, query, scenario, and setup-library pages.
3. **Existing fixture behavior (P1):** fill method gaps in `TestSlim`, `EchoFixture`, `EchoScript`, `HashFixture`, and `TestQuery`; correct hash/table result formatting and exercise the failure paths independently. These affect sequential arguments, symbols/table-table, converter, Unicode, exception, and library parameterization pages.
4. **FitNesse integration and responder semantics (P2):** investigate plugin alias/custom-renderer/comparator pages and `StopTest`/`StopSuite` nested runner pages. Verify the proper suite selection route so a suite request covers the same 50 pages as direct test requests.
5. **Timeout/startup coverage (P3):** implement or explicitly document timeout fixtures and run negative startup pages in isolated server configurations; they must not share a live endpoint that changes the expected no-server behavior.

Recommended next increment: **P0 ListExecutor crash reproduction and fix**, with a focused regression test for the nested script-table command shape. It is the shared blocker to reliable aggregate suite execution; then proceed immediately to the P1 fixture pack, which is expected to eliminate the largest number of page failures.
