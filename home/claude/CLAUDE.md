# Response style

Write all text in Simplified Technical English (ASD-STE100). This applies to messages to the user, plans, code comments, and design documents.

# Code rules

Each line: smell → fix. "OK:" = legitimate exception. `[ctx]` = judgment call, not absolute.

## Feature envy
Behavior lives with the data it reads. Move logic to the type whose fields it uses.
- Method loops over/reads an associated struct and computes a value (charge, points) from several of its fields, using no host state → method on that struct. OK: plain counts or summing one getter. [ctx] Host state needed (loyalty discount): coordinate at host, still delegate pieces.
- Method branches on an associated object's type-code/enum → delegate to the classifying type, pass variable inputs as args. [ctx] Skip if it creates a cyclic dependency.
- Static util computes from a single primitive domain arg (month→quarter, day→weekend), formats a primitive code to string, or indexes a static table by primitive → make the concept an enum/struct; put behavior (incl. `Display`, the table) on it. OK: pure math (`abs`, `clamp`); translation needing locale/context; global hardware/perf tables.
- Stateless service or static helper computes purely from one entity's fields → instance method on the entity (or trait, for polymorphism). OK: ownerless math (`max(a,b)`). [ctx] Heavy service deps (db, global config) required.
- Method's only non-local input is an associated config/type object's rate/factor → move calc onto that object. OK: calc needs host's own state (balances, history).
- Client does field arithmetic on a library type (date rollover) → extension trait on the foreign type. OK: plain construction/serialization.
- Loop checks item field against local start/end with `&&`/`||` → `Range` type with `contains`. OK: equality or single-constant checks.
- Strategy reads 3+ fields of its context → accept only needed params or a cohesive struct. OK: generic operators (comparators).
- Orchestrator reads A's fields, computes, pushes to B → entity produces its own events/entries; coordinator routes. [ctx] Thin fetch+serialize controllers fine.
- Helper builds a map/vec solely from one struct's fields → the struct builds it. OK: reflection-based generic serializer.
- Method takes a heavy struct (`Employee` w/ ssn) but reads 2 fields → narrow trait of just those. [ctx] Pass-through coordinators, persistence mappers.
- Hand-written field-by-field assembler between parallel types → `From`/`Into` on the target. [ctx] Complex protocol/versioned transforms.

## Comments
Comment only the *why* the code cannot show. Else: delete, rename, or encode in types.

Delete:
- Narration of adjacent code; trailing `//` restating the statement; 3+ consecutive statements each with a translating comment → delete; group into blank-line paragraphs, ≤1 intent comment each. Keep: domain invariants, hardware quirks, units/protocol field names on packed fields.
- Commented-out code → delete (VCS). OK: doc-test examples.
- Author/date/history headers → delete (VCS). OK: legally required license header at line 1, once per file, never per item.
- Doc comments on private helpers restating the signature → delete, or `//` if an invariant matters.
- `// ====` banners, boxed/leader-dot alignment, caps/underline comment hierarchies, `} // end if` → delete; split the file/function instead.
- Docs restating: trivial getter name, param names/types ("`title` – the title"), `new()`/`Default` ("creates a new X"), field name in English, std trait impls (`Clone`, `Debug`) → delete. Keep only if adding units, ranges, stability, caching, spawned threads, locks, custom semantics (`Display` masking).
- Historical narrative/RFC essays (>3 sentences) in API docs → one-sentence contract reference; history to design docs/commits.
- "Just in case / not used yet / future expansion" code + comment → delete both.
- HTML tags in comments → Markdown/plain. [ctx] Javadoc codebases.
- Vague `TODO`/`FIXME` → `TODO(owner): action, issue #N`. [ctx] Non-standard markers (`FIX`, `TBD`, `!!!`, `NEED TO`) → `TODO:`/`FIXME:`.
- Venting ("hack", "garbage", blame) → objective constraint, or fix the code. [ctx] OK: dry warning + ticket link.

Fix the code:
- Comment covers a bad name (`process`, `handle`, `clean`) → rename (`enforce_response_byte_limit`), drop comment.
- Comment explains a >5-line block or complex condition → extract function named after the comment.
- Comment explains math over `i`,`j` → rename iterators to domain terms.
- Magic numbers with trivia comment, or comment restating the literals → named constants + comment mapping each to a domain concept. OK: spec/RFC/datasheet section citations.
- Prose "must not be zero / must be positive" → `NonZero*` type or `assert!` at entry.
- Prose "call X before Y" → typestate (`fn init(self) -> Configured`).
- CAPS warnings about ordering/lifetime/destruction → encode in lifetimes/types. OK: `// SAFETY:` on `unsafe` for invariants the compiler can't express.
- Alignment/layout warnings over manual byte math → `#[repr(align(N))]`.
- Units in prose ("in ms") → `Duration`/unit types. [ctx] FFI/serde boundaries: `latency_ms` name + doc is the limit.
- `>>`/`<<` with "divide by 2" comment → `/`,`*`. [ctx] OK: registers, hashing, codecs.
- Raw bit offsets with comments → `bitflags!` named constants.
- Empty `Err` arm with "handled elsewhere / defaults loaded" → do the recovery in the arm.
- Multi-line description of tuple/map shape → one line (`// Category -> (score, weight)`) or named struct.
- Business rule/number repeated in comments across files → one named constant/policy fn, referenced by name.
- Comment restating a foreign file's config/limit → reference the shared constant path (`pool::DEFAULT_SIZE`).

Make correct:
- Comment contradicts code → fix or delete.
- Identical docs on adjacent items (copy-paste) → make each accurate.
- "always returns X" on a fn with panics/timeouts/branches → list every exit path.
- Public doc describing private fields/algorithms/threads → `//` in the body; doc = contract only.
- Endline comment on `for`/`if`/`match` header meant for the block → block comment above.
- Constructor spawns threads/runtime loops → doc the lifecycle ("runs until `shutdown()`") or require explicit `run()`.
- Upstream-bug workaround → issue link + assertion/test that fails once upstream fixes it.
- Hardcoded sleep/retry → the exact constraint ("reset takes 40ms, manual §4.2", race, issue ID).
- Comment on a conditional translating names/operators → domain rationale, or extract a named predicate.

## Robustness theater
Validate once at the boundary; trust types inside; fail fast on corruption; let errors propagate.
- Internal helpers re-check range/null/invariants a constructor or entry boundary already guarantees on every path → delete; `debug_assert!` to document is fine. "Private" ≠ trusted; the invariant must hold on every reaching path. [ctx] Mandatory: public/network boundaries; paths where mutation or another entry can invalidate.
- Builder and constructor both validate → constructor only. Caller and method both check state eligibility → one place (method returns error, or asserts). [ctx] db-consistency cases.
- `path.exists()` before `File::open`, `i < len` before `.get(i)` → call and handle the `Result`/`Option` (TOCTOU + redundancy).
- Error arm that only logs then returns the same error → remove; log once at a central boundary. [ctx] OK when adding local context (`map_err(|e| AppError::UserContext(id, e))`).
- Side effects inside `assert!`/`debug_assert!` (iterator advance, counter++) → evaluate outside, assert the binding; release builds skip it.
- `#![allow(warnings)]`, `allow(unused_must_use)`, commented-out asserts → fix the cause; handle `Result` with `?`/`match`. [ctx] Narrow lint on legacy ok.
- `_ =>` on an internal closed enum → list every variant so new ones fail to compile. [ctx] OK for open external integer codes.
- `lock()` `Err` → default value → `.expect()`/propagate; poison = corrupted shared state.
- `.unwrap()`/`.expect()` on logging/audit/telemetry `Result` → degrade (`if let Err(e) = write_audit_log(..) { eprintln!(..) }`); never fail the business op for diagnostics.
- `.clone()`/`.to_owned()` in getters on internal read-only data → return `&T`/`&str`.
- `Option` fn returns `Some(Default)` on invalid input → `None`.
- Slice/substring API returning `Err` on out-of-range → clamp (`min(len, n)`), Python-slice semantics. [ctx] Strict checks stay for security-critical low-level buffers.

## Tests
Test behavior through public contracts; every test asserts; every test is hermetic.
- Mostly mocks, little production logic run → separate I/O from pure logic; test logic with plain values, I/O with real/fake impls at integration scope.
- `verify()`/`times()`/ordering on getters/queries/reads → assert returned values/state. Keep interaction checks only for the side effect itself (delete, socket write) or an explicit "must not read" contract.
- Hand-written stub/fake drifting from real impl → contract tests run against both.
- Asserting exact fields/format of a collaborator's output in the subject's test → assert only the subject's own transformation (or the message it sends).
- `sleep()` to wait for async/threads → tight poll loop with generous max timeout, or channels/wakeups. OK: timing benchmarks.
- Mutating globals/env/files/db/singletons without guaranteed restore → per-test resources; else scoped RAII guard/teardown on every exit path, serialize concurrent observers.
- Test B needs test A run first → self-contained tests, pass data explicitly. OK: sequential steps inside one integration test.
- Absolute paths, usernames, IPs, wall clock, TZ → `env!("CARGO_MANIFEST_DIR")`, mock clock, injected env.
- One test per production method, names mirroring methods → given-when-then behaviors over public contracts.
- Huge object-graph setup for a simple calc → extract pure functions over simple values.
- Zero assertions → assert return/state. [ctx] "Doesn't panic" tests: still prefer outcome checks.
- Tests for getters/setters/derives/std behavior, coverage as a target → delete; use mutation testing to prove tests fail when logic changes. [ctx]
- Exact-string asserts on timestamps, paths, formatted messages → assert the stable invariant (`contains("User logged in")`) or domain assertion helpers.
- `#[ignore]` without issue link → fix now, or delete test + obsolete code. OK: `#[ignore] // TODO(issue-1204): ...` temporarily.
- Only happy paths → test min/max/off-by-one, empty, invalid input, injected faults. [ctx]

## Invalid states & primitives
Make illegal states unrepresentable; parse once at the boundary into types.
- Several `Option` fields where exactly one must be set, or disjoint lifecycle phases (`completion_date` + `rejection_reason`) → data-carrying enum with exactly each state's payload, incl. initial state; shared/historical data outside the enum; transitions via methods. [ctx] OK: independent optionals (`theme`, `timezone`); history preserved across phases.
- Multiple `is_*` bools for exclusive states; bools + `Option`s with temporal dependencies ("status soup") → one enum (`Priced { amount }`). OK: additive flags (`case_sensitive`, `use_regex`).
- `None` meaning several things (not enabled / not requested / not ready) → enum per state.
- Known domain attributes in `serde_json::Value`, `HashMap<String,_>`, JSONB/EAV, read via string keys → typed structs (memory) and typed columns + migrations (db); keep truly dynamic metadata separate. OK: user-defined schemas, document/analytics stores, raw webhook audit logs. A Rust struct doesn't constrain stored rows; columns don't give compile-time safety — do both.
- `HashMap<String,String>` as an entity → struct. OK: config stores, caches, dynamic indexes.
- Tuple/array positions for distinct attributes (`.0`, `arr[1]`), even same-typed → named struct; distinct field types if same-type swaps must be impossible. OK: uniform math vectors `(x,y,z)`.
- Consecutive same-type params with different roles (`name, seat`), or several `_id: u64` from different ID spaces → distinct newtypes per role/entity (aliases and same-primitive struct fields don't stop swaps). OK: `(row, col)`, `(x, y)`, two IDs from one space (`are_matching(id1, id2)`).
- Money as `f32`/`f64` → integer minor units or decimal + currency code. `amount` beside `currency` fields → one `Money` value object. OK: physical measurements; denormalized analytics tables.
- `quantity`/`count` as raw int with domain bounds → validated newtype, private ctor. OK: collection sizes/indices.
- Physical values (`temp`, `speed`, `weight`) and durations (`timeout_ms: u64`) as raw numbers → unit types / `Duration`. OK: abstract scalars; cycle-counted driver loops.
- `start`/`end`, `min`/`max` as separate fields → `Range` type enforcing order in ctor. OK: unrelated timestamps.
- `-1`, `0`, `""`, `9999-12-31` for missing/error → `Option`/`Result`. OK: C/UNIX return codes at FFI.
- Closed state/kind/role sets as strings or int codes; repeated `if status == "X"` dispatch → enum, convert at protocol boundary, exhaustive match or strategy. OK: display names; runtime user-defined categories; merely logging/forwarding an external code.
- `id: String` for UUIDs → UUID newtype. OK: human-entered IDs (username, barcode).
- Composite IDs split/sliced/regexed in domain logic; `email`/`url`/`ip`/`phone` as unvalidated `String` → parse+validate once at input boundary into a type with private repr; typed components where structure is used, opaque validated wrapper where only validity matters; block bypass via other ctors/mutation/deserialize; format at output. OK: parsing in controllers/DTO layer; formatting for logs/UI; free text (bio, comments, address); opaque IDs never decomposed.
- `password`/`secret`/`token: String` → secret type redacting `Debug`/`Display`/serialization. OK: config reader at startup.
- File paths as `String` → `Path`/`PathBuf`. OK: CLI arg parsing at entry.

## Naming & semantic ambiguity
- Inclusive upper bound named `stop`/`end` → `last`. Half-open: `begin`/`end`, not `start`/`stop`. [ctx] Symmetric pairs only: `begin/end`, `first/last`, `min/max`, `locked/unlocked`; never `begin`+`last`, `min`+`limit`.
- `_limit`/`_threshold` without direction → `MAX_`/`MIN_` prefix.
- `num_x`/`x_num` → `x_count`/`x_total` for tallies, `x_index`/`x_id` for positions. [ctx]
- `length`/`size`/`limit` on strings → `max_bytes`/`char_count`; byte-slicing by char count panics on UTF-8.
- Custom `filter` method/variable → `select`/`keep` or `reject`/`discard`. [ctx] OK: std `Iterator::filter`.
- Bare-verb bools (`read_password`, `validate_order`) → `is_`/`has_`/`should_`/`can_`.
- Negative bools (`not_ready`, `disabled`, `invalid`), esp. under `!` → positive form (`is_ready`).
- `bool` methods named `clear`/`set`/`empty`/`close` → queries `is_clear()`, actions `wipe_`/`try_clear`.
- Range overlap via endpoint inequality chains → `!(a.end <= b.begin || a.begin >= b.end)`.
- `Option<Vec<T>>` where `None` = no items → empty `Vec`; `Result` if fetch can fail. OK: `None` is a distinct state (cache miss, denied).
- Entity (has `id`) deriving `PartialEq` on all fields → `eq` compares ID only. Value object (`Money`, `Name`) compared by pointer → derive structural `PartialEq`. OK: `ptr::eq` on entities as identity shortcut.
- `HashMap`/`HashSet` iteration feeding strings, lists, files, serialized payloads, signatures, test asserts → sort deterministically or `BTreeMap`; keep serialized shape (don't turn object into sorted array); canonicalize nested values fully for signatures. OK: internal lookups; order-insensitive consumers; self-canonicalizing serializers.
- Args where one mutates what another reads (`f(inc(&mut n), n + 2)`) → bind each to a variable first.
- Fn returns `T` but panics/`unwrap`s/indexes `[0]` on valid inputs → `Option`/`Result` (total function).
