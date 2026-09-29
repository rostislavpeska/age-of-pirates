# Connector audit trail and uncertain outcomes

Every `sp_remote.js`, `py`, and `later` call now writes a durable JSONL `begin` **before**
sending the request. `Connector` additionally records semantic commands, resources,
save, export, recipes, and quarantined commands. Logging errors stop dispatch; they must
not be suppressed to get a mutation through.

`Connector(project)` logs beside its external `.spp` as `painter_connector_events.jsonl`.
Raw `sp_remote` calls default to `%TEMP%/painter-connector/localhost-60041/events.jsonl`.
Use `SP_CONNECTOR_LOG` or `painter_audit.configure(log_path=..., project=...)` to select
another **external workspace/scratch** log. Never put run logs under runtime assets.

Records include UTC time, session/sequence, client PID, command/arguments (bounded),
operation/parent IDs, endpoint, duration and outcomes. Project/version are attached when
known. The connector reads the remote Painter PID during connection; queued jobs record
their actual remote PID. This distinguishes an app manually opened without remote
scripting from the process owning the endpoint. Scripts are represented by name, length,
and SHA-256, not their bodies. Credentials in keyed arguments are redacted.

Queued jobs carry unique IDs and write `queued`, `running`, `done`/`failed` from inside
Painter. Thus a Painter crash after starting a command leaves a durable `running` record.
The client records `accepted`, observed state transitions, and its final outcome. Even a
fast job has a running record; polling does not have to catch that moment. Remote error
types are recorded; complete tracebacks remain in the raised exception, not the audit log.

| Outcome | Meaning and next action |
| --- | --- |
| `done` | The specific operation returned successfully. Check its postcondition; it is not proof of visual quality. |
| `failed` | An explicit exception occurred. A multi-step operation may already have changed the project. Inspect before retry. |
| `blocked` | Client lock, remote busy state, or quarantine prevented this operation. No automatic retry. |
| `unknown` / unfinished `begin` or `running` | Timeout, connection loss, replaced job, or killed client. The action may have executed. Inspect the owning process and saved/live state before deciding whether to retry. **This does not prove a crash.** |

Inspect the last uncertain command:

```powershell
python .claude/skills/substance-painter-remote/scripts/painter_audit.py "C:/external/project/painter_connector_events.jsonl"
```

The report tolerates a crash-truncated final line. It reports unfinished/unknown operations,
the last event, and recent failed/blocked/unknown commands. Match job ID and remote PID
with Painter's own logs or a process exit before calling an event a confirmed crash. Logs
cannot reconstruct uninstrumented commands executed before installation.

## Concurrency and recovery

A nonblocking OS lease covers a complete queued job, including its completion condition.
Another client/thread fails with `PainterBusyError`; it does not wait and then replay a
mutation. Nested calls on the same client/thread are allowed. A second server-side guard
refuses to overwrite an existing queued/running job or enqueue while the project is busy.
Polling verifies the job ID, so another client's result cannot masquerade as success.

The OS releases the lease if the client dies, but the remote job may continue. Do not clear
`builtins._sp_job` or retry because a client timed out. Inspect the project and the owning
Painter process. Existing scripts which bypass this helper can still interfere; the helper
detects job replacement but cannot stop arbitrary scripts sent by other clients.

Quarantined controls remain blocked: `set_generator_parameter`, `set_opacity`,
`open_resource_picker`, `choose_picker`, `ensure_generator`, `bind_generator`, and the
`menu_action` entry `Add generator`. Do not use logging as permission to retry a known
crashing control. **Every recipe containing a generator or opacity setting is rejected
before its first mutation.** On 2026-09-28, a default Dirt generator path also crashed
Painter PID 53008, without reaching any numeric edit (Windows Application Error 1000,
report a7228145-524e-4b27-9d51-067d915da94c). The earlier numeric-only quarantine was too narrow.

Queued scripts can call `_sp_audit_step('stage.name', 'before')` immediately before a
native action and the same hook with `'after'` only after verified readback. The hook
writes durable job-correlated events from inside Painter. It does not touch Qt or store
widget wrappers. Missing `after` narrows the last entered stage, but is not proof that the
immediately preceding native call caused delayed memory corruption. Adding hooks cannot
recover substeps from old runs. Keep quarantine while investigating in isolation.

## Verification

Run the offline suite; it contacts no Painter instance and deliberately crashes no app:

```powershell
python .claude/skills/substance-painter-remote/scripts/test_painter_audit.py
```

It exercises successful calls/jobs, fsynced pre-dispatch logging, connection reset, timeout,
explicit remote failure, busy/replaced jobs, thread/process contention, quarantine/recipe
preflight, resource/save/export logging, redaction, and truncated-log recovery. Runtime
queue code is executed against a fake Qt event loop. A live read-only smoke check and a
normal authorized save remain appropriate before adopting a new Painter version. This
suite validates instrumentation and guarding, not the safety of undocumented Qt controls.
