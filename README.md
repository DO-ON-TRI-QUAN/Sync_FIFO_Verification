# Synchronous FIFO Design Verification Project

## Overview
A directed-test verification environment for an 8-entry, 8-bit-wide synchronous FIFO (RTL sourced externally, verification self-implemented). This project is intentionally kept simple, built without UVM. Otherwise, SystemVerilog OOP (classes, interfaces, clocking blocks, assertions, functional coverage) was used directly instead.

## Project Structure
```
specs.txt               - informal functional specification, written before any testbench code
vplan.txt               - verification plan: test items, priorities, status, open questions
fifo_interface.sv       - DUT interface, clocking block, concurrent assertions, independent occupancy/wrap tracking
fifo_checker.sv         - reference model (expected-data queue) + comparator + coverage class
synchronous_fifo.sv     - DUT (RTL, lightly patched — see Known Issues / Findings below)
top.sv                  - testbench top: DUT/interface instantiation, directed test tasks, main sequence
```

## Methodology
- **Spec-first**: specs.txt was written describing intended black-box behavior before reading implementation details closely, to avoid writing tests that just mirror the RTL.
- **Vplan as living document**: test items were defined up front, with open questions tracked explicitly and resolved as understanding improved.
- **No monitor/scoreboard-as-component**: given the project small scope, the testbench uses directed tasks that drive the interface and manually keep a reference model in sync, rather than a full driver/monitor/scoreboard architecture. This was a deliberate scope decision.
- **Assertions**: concurrent SVA properties check standing invariants (full/empty correctness, rejected-write/read behavior) independent of any single testcase; immediate checks inside tasks verify scenario-specific and data-level correctness.
- **Functional coverage**: covergroup modeling FIFO occupancy state × operation type (cross coverage), pointer wraparound, and reset-state coverage — derived directly from vplan test items, not run until directed testcases were in place.
- **No randomization used** in this project: covered fully through directed testcases.

## Known Issues / Findings
The original RTL (sourced from a tutorial reference) had two bugs found through this verification process and both had been patched:
1. **Reset did not reliably clear pointers.** Reset logic lived in a separate `always` block from the write/read logic; with no shared priority between blocks, a mid-operation write could race reset within the same clock edge. Fixed by merging into a single priority-based `always` block.
2. **Simultaneous write+read was not independent.** The merged fix above initially used `else if` between write and read, making them mutually exclusive, breaking the specified behavior that both may legally occur in the same cycle. Fixed by separating write and read into independent `if` statements under the reset's `else` branch.

Both were found via assertion failures during directed testing, root-caused using waveform/VCD inspection, and verified fixed by re-running the full test suite afterward.

## Verification Scope
Covered: reset behavior, basic write/read, full/empty flag correctness (including mid-sequence, not just endpoints), FIFO data ordering/integrity, simultaneous read+write across all occupancy states, pointer wraparound (including multiple wraps), boundary full/empty conditions.

Out of scope (see vplan.txt section 4): overflow/underflow error signaling, almost-full/almost-empty flags, multi-clock/async behavior, parameter sweeps.

## How to Run
Simulated on EDA Playground (Synopsys VCS) [here](https://www.edaplayground.com/x/Q4pW)

## Lessons
- Simulation timing semantics (blocking vs. non-blocking, clocking block input/output skew, assertion sampling regions) caused several misleading failures that turned out to be testbench timing bugs, not DUT bugs. Validating the checker/model against simple known-correct scenarios before building further was essential to catching these early rather than later, when they would be buried under more complexity.
- Without a monitor, reference-model state (occupancy, coverage sampling) that depended on tasks remembering to update it manually proved fragile and was a repeated source of bugs, ultimately resolved by deriving that state independently and automatically (clocked directly off observed DUT-facing signals) rather than relying on procedural task discipline.
- Functional coverage caught a genuine testbench sampling-timing bug (coverage sampled after enables were already deasserted) that correctness checks alone had not revealed. This was a good example of coverage validating the testbench's exercising of the DUT, not just the DUT's correctness.


