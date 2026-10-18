# Usability audit

## Scope and method

`bin/test-example-order-management` performs repeatable authoring exercises
against a disposable FitNesse root. It adds a preferred-pricing boundary
row, adds an inventory boundary row, selects a different customer and adds
an expected order row to a query, creates a workflow page from existing
operations, enters an invalid quantity, and changes an expected price to
force a visible failure. The runner restores all edited pages and removes the
temporary page even when an exercise fails.

These checks establish that the wiki edits execute and that FitNesse reports
the resulting assertions. They are not a substitute for sessions with
business analysts or other nontechnical authors. No such participants were
available for this audit.

## Role-based findings

### Business analyst

Pricing and inventory boundaries are added as plain decision-table rows.
The domain is expressed in business terms, and currency uses familiar
decimal notation. A page can be extended without Perl edits when an existing
fixture operation covers the behavior. The import setup and the required
interposed words in script-table rows are FitNesse syntax details that need
an example or author guidance.

### QA analyst

Decision tables cover inclusive boundaries and rejected cases. Script checks
assert business rejection as `false` plus a message rather than relying on an
unexpected exception. Query expectations compare complete records and make
unordered matching clear; the replenishment page uses an ordered query
because priority order is meaningful. The runner verified that omitting an
expected inventory row produces a query mismatch, while adding expected
orders for another customer passes without fixture changes. Deliberately
changing a pricing expectation produced one wrong assertion localized to the
price cell.

### Product owner

Page titles and prose state the behavior under review. A reader can follow a
draft order through reservation and submission and see the expected status.
The fixture still uses business identifiers such as SKU and customer ID;
authors need the example's small data catalogue to interpret those values.

### Perl maintainer

Pricing and store rules are independent of FitNesse. Fixtures are thin
adapters with explicit method signatures. Query adapters translate an array
of hash records into FitNesse query rows. This is a small amount of
FitNesse-specific shaping, but it keeps Perl data structures out of wiki
cells and avoids a demonstration-only hash-literal language. The wiki script
phrases contain connector cells (`quantity`, `to order`) needed to form
unambiguous fixture method names; that is the clearest usability friction
found in the script interface.

## Structured-data ergonomics

| Operation | Wiki form | Perl representation and adapter | Finding |
|---|---|---|---|
| Supply a simple record | Decision-table columns or script arguments | Fixture maps named cells to a hash-based domain record | Practical for flat records; authors do not write hash syntax |
| Supply an order with items | One script action per item, with a generated order symbol | Order hash owns an array of line-item hashes | Readable for workflows; no nested literal is needed |
| Return records | Query table with named headings | Array reference of hash references, mapped to `[field, value]` pairs | Natural in Perl; adapter has to translate to FitNesse's query shape |
| Compare without row order | `Query:` | Query result rows matched as a set by FitNesse | Good for inventory and order records where display order is irrelevant |
| Compare with row order | `Ordered query:` | Array order from the fixture is meaningful | Appropriate for replenishment priority |
| Reuse generated value | `$order` FitNesse symbol in later script actions | String order identifier; no Perl reference crosses into the wiki | Straightforward and hides object identity |
| Reference an individual record field | No direct field-access syntax used | Fixture exposes a business operation or query column | Awkward for arbitrary field traversal without expressions |
| Missing, null, and empty values | Blank query cells are wildcards; empty and null inputs are not interchangeable in the wiki | Perl distinguishes `undef`, `''`, and empty arrays, subject to FitNesse table semantics | The current suite avoids ambiguous blank cells; a dedicated authoring convention would be needed |
| Invalid input | A table row supplies zero quantity and checks a rejection message | Fixture returns false and stores a domain-level message | Understandable when business-invalid values remain type-valid inputs |

## Expression requirements

The examples below are concrete authoring needs, not a proposal to implement
an expression engine in this project.

| Priority | Natural author expression | Need | Current behavior and minimum useful semantics |
|---:|---|---|---|
| 1 | `quantity * unit price - discount + shipping` | Recalculate an expected order total | FitNesse v20251025 evaluates backtick expressions through its Nashorn JavaScript integration on the FitNesse side; Perl SLiM preserves expression text. For money, an optional facility would need explicit decimal/integer-cent rules and checked arithmetic, not JavaScript floating point. |
| 2 | `$expectedTotal` or ``$`order.total` `` | Compare an actual result with a previously stored result or a field | Ordinary symbol reuse is already supported. Field access uses Java-side expression evaluation; the smallest useful cross-language feature would be explicit named field extraction from declared record values, with missing-field behavior specified. |
| 3 | ``$`lines[0].sku` `` | Check a particular line in a returned order | Java evaluates indexing and property/member access in FitNesse; Perl does not. This overlaps structured-record access and could be met by a narrowly defined table operation rather than general expressions. |
| 4 | `available >= requested && customerEligible` | Express combined business conditions | Nashorn evaluates the current syntax in FitNesse. The demo instead reports the two business decisions through named fixture methods, which is more readable and avoids cross-backend coercion rules. |

The expression compatibility audit documents the Java implementation and its
Java object semantics in detail. The order suite shows that most ordinary
checks can avoid expressions by returning named business values and reusing
symbols. The remaining high-value gap is structured field access for a value
already returned to a table author. Any future feature should be opt-in and
have bounded, explicit semantics; unrestricted Perl `eval` would be unsafe
and would not reproduce Java/Nashorn behavior.

## Collection requirements

The suite needs arrays and hashes, both of which Perl already represents
naturally. Unordered query matching is handled by FitNesse, and ordered
priority results are represented by array order. Inventory membership uses
ordinary domain lookups; order submission models FIFO or priority as a
business rule rather than requiring Java `Queue` conversion. No Set, Queue,
nested-generic, or additional collection protocol support was needed.

## Conclusion

The suite provides a workable interface for flat business decisions,
multi-step workflows, generated identifiers, and record queries. Reusable
operations let authors add examples without changing Perl. The main limits
are FitNesse script-table method-name construction, setup/import syntax, and
the lack of a simple portable way to inspect a field of an already returned
structured value. Human usability remains unverified until nontechnical
authors use the pages.
