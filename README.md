# SEU Mitigation in a Custom 8-Bit FPGA Processor

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

**Author:** Ramavath Vihaan  
**Repository:** https://github.com/TankGuy11/8bit-cpu-seu-mitigation

## Overview

An educational and experimental Verilog platform for evaluating controlled **logical bit-flip faults** in a custom multicycle 8-bit processor. The project compares four implementations:

1. Unprotected baseline processor
2. SECDED error-correcting code (ECC) memory
3. SECDED ECC with memory scrubbing
4. Triple modular redundancy (TMR) with majority voting

The processor has a 256-address by 8-bit logical memory, an eight-operation ALU, and a 16-state control FSM. The physical prototype uses the Sipeed Tang Nano 20K FPGA development board.

> **Scope:** Faults are deliberately injected in simulation; these results are **not** measured cosmic-ray exposure, radiation qualification, or in-orbit reliability predictions. Encoded-memory experiments enumerate faults in one 13-bit SECDED codeword. CPU-level tests exercise faults in one 8-bit RAM data value; in the TMR campaign the fault is confined to one replica.

## Recorded experimental results

The following figures are from the local Icarus Verilog testbench runs reported on 21 November 2026. Reproduce them using the exact source revision and simulator setup when the project files are added.

| Test | Observed result |
| --- | ---: |
| ECC single-bit correct decoded data | 13 / 13 |
| ECC double-bit detected | 78 / 78 |
| Triple-bit faults classified as single | 286 / 286 |
| Triple-bit correct decoded data | 2 / 286 |
| Four-bit faults with silent wrong data | 55 / 715 |
| Scrubber single-bit restored codewords | 13 / 13 |
| Scrubber triple-bit write events | 286 / 286 |
| Scrubber triple-bit original codewords restored | 0 / 286 |
| Scrubber four-bit original codewords restored | 0 / 715 |
| CPU ECC correct under one-bit RAM faults | 8 / 8 |
| CPU ECC correct under two-bit RAM faults | 0 / 28 |
| CPU TMR correct under faults confined to one replica | 36 / 36 |

**Important:** Different metrics measure decoded output, detection flags, actual encoded-word restoration, and output voting. They should not be interpreted as equivalent. The campaign log and complete RTL will be uploaded before the first reproducible release.

## Project structure

```text
src/            Synthesizable Verilog RTL (to be added)
testbench/      Simulation testbenches (to be added)
results/        Captured simulation logs (to be added)
figures/        Architecture figures (to be added)
paper/          Manuscript source and paper (to be added)
docs/           Implementation and experiment notes (to be added)
```

## Reproducing the simulation

**Prerequisites:** Icarus Verilog with `-g2012` support. GTKWave is optional for waveform viewing.

Once all RTL and testbenches are uploaded, compile the campaign by explicitly selecting the desired testbench and excluding conflicting alternative top-level modules. Example for a PowerShell terminal opened at the repository root:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
$files = Get-ChildItem .\src\*.v | Where-Object { $_.Name -notin @('top.v', 'top_fault.v') } | ForEach-Object FullName
iverilog -g2012 -s mitigation_campaign_tb -o build/mitigation_campaign.vvp $files .\testbench\mitigation_campaign_tb.v
if ($LASTEXITCODE -eq 0) {
    vvp build/mitigation_campaign.vvp | Tee-Object -FilePath build/mitigation_results.txt
}
```

The example assumes a single testbench named `testbench/mitigation_campaign_tb.v` and all dependencies in `src/`. Adjust file paths to the committed layout. Capture simulator/tool versions alongside published result logs. Generated `build/` files are ignored by Git.

## Contributing

Issues, forks and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). Please include a test reproducing any change to the fault model or mitigation logic, and avoid changing verified experimental results without documenting the reason.

## License and citation

Software is licensed under the [Apache License 2.0](LICENSE). See [CITATION.cff](CITATION.cff) for software citation metadata. A Zenodo DOI will be added **after** a versioned, archived release exists; no DOI has been assigned yet.
