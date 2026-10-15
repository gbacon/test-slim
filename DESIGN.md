# Current design

`Test::Slim` has three small execution layers. `Test::Slim::Server` reads and writes framed SLiM messages over a socket. `Test::Slim::List` handles SLiM list values and lengths, including recursive nested statements and zero-length string items. `Test::Slim::ListExecutor` turns each decoded statement into a `Test::Slim::Statement` call.

`Test::Slim::Statement` routes protocol operations to `Test::Slim::StatementExecutor`. The statement executor owns imported class prefixes, actor instances, registered library instances, and symbols. It resolves graceful class and method names, constructs fixtures, substitutes symbols, converts HTML table arguments where appropriate, dispatches actor methods before searching libraries newest-first, and formats results or SLiM exceptions.

Perl tests use fixtures under `t/lib/`. FitNesse acceptance pages live in the locally installed wiki tree (ignored by Git) and connect through the Perl server on port 8099. The acceptance inventory and the current observed failure groups are recorded in [`docs/fitnesse-slim-acceptance-baseline.md`](docs/fitnesse-slim-acceptance-baseline.md).
