# Validation on real data

Counts below were produced by running the tool on public data, not on the synthetic samples in `examples/`.

## Corpus
nvm-sh/nvm at commit `09e620c`: 439 shell files.

## Result
389 findings: 331 SHL011 (low), 50 SHL004, 5 SHL007 and 3 SHL002 (high).

## What the real data exposed (all fixed, with regression tests)
- `rm -rf "$DIR"/*` was not distinguished from a guarded expansion. A bare quoted variable now passes only when it is not followed by `/`, and `${DIR:?}` guards pass.
- The SHL004 pattern now covers options before the variable (`rm -rf -- "$DIR"/x`).

## Limits
The SHL004 findings are heuristics. A reviewer should confirm that the variable can really be empty.
