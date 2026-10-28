# Plugin development guide

Status: design-stage guidance. NotchMaster does not have a published plugin SDK, installable plugin format, or stable API yet.

## What to design now

A good plugin adds one focused capability that fits both a compact glance and an expanded interaction. Describe the user benefit before choosing how it executes.

Prepare a proposal with:

| Topic | Required detail |
| :--- | :--- |
| Purpose | The single task the plugin makes easier. |
| Identity | A proposed stable identifier, display name, author, version, and licence. |
| Compact presentation | The minimum useful status near the notch. |
| Expanded presentation | The action or information that needs more space. |
| Data and permissions | Data sources, requested capabilities, external services, and user consent. |
| Refresh policy | Event-driven updates where possible; explicit polling bounds when necessary. |
| Lifecycle | Startup, disablement, cancellation, resource cleanup, and failure handling. |
| Compatibility | OS requirements and behaviour when hardware or services are unavailable. |
| Privacy | What is stored locally, what leaves the Mac, and how data is removed. |

Open a [plugin proposal](https://github.com/louisboii747/NotchMaster/issues) with these details. No repository template or package extension is required at this stage.

## Proposed host contract

The registry should validate stable plugin identities, detect duplicates, record enabled state, and expose capability and health information. Plugin code should not receive window ownership or unrestricted access to host services as a convenience.

The intended lifecycle is registration, capability review, explicit enablement, active operation, and disablement. An enable request can fail. A disable request must cancel outstanding work, stop observers and timers, release resources, and prevent late results from reactivating the plugin.

Represent user choice, current activity, and failure separately. A plugin can remain installed while disabled or unavailable. Surface a useful explanation when a data source or permission is missing instead of displaying invented values.

## Rendering and concurrency

The initial architectural preference is for the host to render plugin state using controlled presentation contracts. Concrete view and data APIs will be defined during implementation; no Swift protocol is promised by this guide.

Keep window management and UI updates on the main actor. Background work must have explicit isolation, bounded updates, cancellation, and value-based results. Do not transfer AppKit windows or SwiftUI views across concurrency boundaries.

## Execution and distribution

Bundled reference plugins will be used to establish the contract first. Third-party package structure, signing, integrity checks, code execution, process isolation, updates, and permission enforcement remain unresolved.

An in-process Swift module is trusted host code, not an isolation boundary. A future out-of-process design would need a defined IPC protocol and explicit capability enforcement. Neither mechanism is implemented or approved by this document.

Mac App Store delivery must be evaluated separately against the applicable [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/). Do not assume community binary loading is supported in every distribution channel.

## Acceptance criteria for a future plugin

- Provides useful compact and expanded states without assuming a fixed notch size.
- Has stable identity and explicit version compatibility.
- Requests only capabilities it needs and handles denied access.
- Remains responsive when data sources are slow, offline, or missing.
- Stops all work when disabled and handles repeated enable/disable requests safely.
- Respects accessibility preferences and the host's update budget.
- Reports errors and unavailable values honestly.
- Documents its data handling and dependencies.

## When implementation begins

Once the host contract exists, this guide will gain the actual SDK import, manifest schema, reference implementation, build steps, installation path, and compatibility tests. Those interfaces will be documented alongside working code instead of being guessed during repository initialization.
