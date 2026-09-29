# Android attestation execution isolation

## Implemented contract

Outer attestation schema
`parkinsum.android-reminder-run-attestation/4` embeds
`parkinsum.android-reminder-execution-isolation/2`. V4/v2 are hard replacements
for local outer-v3/nested-v1 evidence because the nested exact-key contract now
requires `lease_evidence_sha256`. The runner acquires
cooperative leases, in a fixed order, for two resource kinds:

- `buildOutput` binds the shared Android build-output identity;
- `deviceApplication` binds the selected device plus isolated application ID.

The lease set uses atomically created lock directories, one random 256-bit
owner token, an immutable owner identity, and a periodically refreshed
heartbeat. The public envelope records resource keys and resource-domain-separated
owner-token identities as distinct SHA-256 digests, not raw local paths or the
shared secret token. A release first verifies its token, renames the lock
directory to a token-specific quarantine name, and deletes only that renamed
directory. Stale reclamation likewise renames the observed stale directory
before removal, so a reclaimer cannot recursively delete a newly acquired
canonical lock path.

Linux owner identity uses the kernel boot ID plus `/proc/<pid>/stat` process
start time (`linuxProcStat`). Reclamation is allowed only after the heartbeat is
stale and that identity proves that the recorded process has gone away or the
PID was reused. An unreadable or otherwise inconclusive identity fails closed.
On macOS the Node runner has no stable public process-start-identity API, so
`darwinNoReclaim` never reclaims a stale process owner automatically. An
operator must inspect and remove an abandoned lock deliberately.

Continuous ownership is checked at these nine ordered checkpoints:

1. `acquiredBeforeSourceAndDeviceInspection`
2. `beforeBuild`
3. `afterBuildBeforeStage`
4. `beforeDeviceAbsenceCheck`
5. `beforeFlutterDrive`
6. `afterFlutterDriveBeforePull`
7. `childrenDrainedBeforeDeviceCleanup`
8. `deviceCleanupCompletedWhileOwned`
9. `beforeAttestationPublish`

A passing v4 envelope requires `continuous_ownership_verified`,
`children_drained_before_device_cleanup`, and
`device_cleanup_completed_while_owned` all to be true. Spawned child processes
are retained until their Node `close` event. Every workload command is started
behind a local execution barrier: the wrapper process is first registered in
both lease records and only then releases the target command. Device cleanup
runs while both leases remain owned. The attestation and Markdown stay in
pending files until tracked children drain, the heartbeat stops, and both
resource leases release successfully; only then may `latest.json` promote the
run with `execution_isolation_released: true`. A final-name file without that
promotion record is not accepted as a completed run.

The release path is now one injectable lifecycle coordinator rather than an
ordering convention spread across `main`. Its deterministic tests require
`drain -> stop heartbeat -> release -> final abort check -> publication`.
Release rejection makes zero finalizer calls. A `SIGTERM` injected while drain
or release is blocked produces exit code 143 and makes zero finalizer calls.
The first abort terminates ordinary children while preserving explicitly
bounded package-cleanup work; a second abort or the cleanup grace deadline
escalates to `SIGKILL`. A fast child may skip mutable lease registration only
when the process-identity provider emits the typed vanished-process result;
an unrelated `ENOENT`, including an unavailable Linux boot-identity provider,
remains fail closed.

A current worktree snapshot produced and independently rechecked one passing
local ignored development outer-v4/inner-v4 attestation with nested
execution-isolation-v2 on a dedicated API 36 arm64 emulator. It bound the dirty
source snapshot, isolated application identity, debug integration entrypoint,
byte-identical installed APK, compiled manifest, plugin lock and observed
Android Debug signature. The plugin registry moved from seven pending requests
to zero after cancellation; no notification permission was requested and no
user storage was accessed. All nine checkpoints, the exact private lease
evidence digest, source and device pre/post state, cleanup before release, and
release-before-promotion passed. The isolated application was absent before the
run and removed afterward. The artifact remains emulator-only,
`visible_delivery_verified: false`, `release_eligible: false`, dirty-development
evidence. Historical outer-v3/nested-v1 artifacts remain rejected by the
current validators. No run ID or digest is pinned in tracked documentation
because generated evidence remains local and ignored.

## Crash-consistency boundary and researched successor

The coordinator proves in-process ordering, not storage durability. POSIX
requires one directory operation such as `rename()` to be atomic and
serializable, but explicitly allows a crash to persist only part of a sequence
of writes and directory operations. Node exposes the underlying rename and
file-sync primitives but does not turn the current multi-file sequence into a
transaction. The attestation JSON, Markdown, and `latest.json` pointer are
therefore not yet a crash-atomic group. A process can fail after one final-name
rename and before the completion pointer advances; consumers must continue to
accept only a validated `latest.json` pointer.

The new
`android_attestation_crash_consistent_publication_and_recovery` queue item
requires a versioned promotion receipt, a digest over independently validated
post-release lease evidence, file and directory synchronization on supported
filesystems, deterministic crash and I/O-fault injection at every publication
step, and restart recovery that preserves the previous complete pointer while
quarantining ambiguous remnants. Unsupported filesystem or synchronization
semantics must remain `unverified`; one atomic rename must never be relabelled
as durable release provenance.

The next device-behavior lanes also remain separate from execution isolation.
Android 13+ notification permission has allow, deny, dismiss, upgrade and
restore transitions that can be reproduced with documented ADB commands.
Doze defers ordinary alarms, and exact alarms have separate special-access and
policy constraints. Future artifact-bound tests must exercise these states on
governed physical-device and emulator profiles without silently requesting a
permission, and must keep registry inspection distinct from visible delivery.

## Proof boundary

This is a cooperative single-host protocol. It coordinates only processes that
use this runner and the same lock root. It does not fence an independent
`flutter build`, another tool writing the same output, a detached Gradle daemon
or other descendant that outlives the tracked child-process boundary, a hostile
same-user process, a second host, or failures of the filesystem's promised
directory semantics. PID existence alone is not accepted as identity because a
PID can be reused and permission errors can make liveness inconclusive.

Execution isolation does not prove deterministic or reproducible
source-to-binary provenance. It also does not establish a reviewed production
signer, a production entrypoint, physical-device visible notification delivery,
lock-screen behavior, activation, background execution, or clinical or
regulatory validity.

## Primary sources

- Node.js file-system APIs (`mkdir`, `open`, `rename`, `stat`, `utimes`):
  https://nodejs.org/api/fs.html
- Node.js child-process `close` and process signal semantics:
  https://nodejs.org/api/child_process.html and https://nodejs.org/api/process.html
- POSIX directory-operation atomicity, `mkdir`, `rename`, and `open`:
  https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap04.html,
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/mkdir.html,
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/rename.html, and
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/open.html
- POSIX durability rationale for synchronizing files and containing
  directories around rename:
  https://pubs.opengroup.org/onlinepubs/9799919799/xrat/V4_xbd_chap01.html
- Linux `/proc/<pid>/stat` process start time:
  https://www.kernel.org/doc/html/latest/filesystems/proc.html
- Linux kernel boot ID:
  https://docs.kernel.org/admin-guide/sysctl/kernel.html
- Apple XNU process-information ABI and the private/changeable `libproc` API
  boundary:
  https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/proc_info.h
  and
  https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.h
- Android SELinux process-isolation boundary:
  https://source.android.com/docs/security/features/selinux
- Android notification permission states and ADB test recipes:
  https://developer.android.com/develop/ui/compose/notifications/notification-permission
- Android Doze and alarm behavior:
  https://developer.android.com/training/monitoring-device-state/doze-standby and
  https://developer.android.com/develop/background-work/services/alarms
