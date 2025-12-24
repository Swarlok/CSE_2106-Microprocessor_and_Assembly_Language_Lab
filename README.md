# CSE 2106 - Microprocessor and Assembly Language Lab

## Assignment 2: PayrollSys-32
ARM-based employee payroll and salary processing system for **2nd Year 1st Semester 2025, Batch 30, CSE, University of Dhaka.**

## Overview
The project implements a miniature payroll pipeline on ARM (Thumb) assembly. It loads attendance, overtime, and performance data into RAM and builds employee records. The pipeline runs payroll calculations and sorts employees by net salary. It also produces department summaries and emits a UART payslip demo.

## Repository Layout
* `Assignment-2/Assignment-2_Solution.s`: complete ARM assembly solution with all payroll modules.
* `Assignment-2/Assignment-2.pdf`: assignment handout/specification.
* `Assignment-2/Assignment-2_Report.pdf`: written report for the assignment.

## Key Features (from `Assignment-2_Solution.s`)
* **Test data bootstrapping**: copies attendance logs, OT hours, and performance scores from ROM tables into RAM.
* **Employee table initialization**: populates base salary, grade, department, bank account, and pointer metadata.
* **Payroll pipeline** (per employee):
  * Load attendance and count presents/absences.
  * Apply leave deductions when attendance falls below the minimum.
  * Compute overtime pay and allowances.
  * Calculate tax, bonus, and final net salary.
* **Sorting & summaries**:
  * Sort employees by net salary to `0x20005000`.
  * Produce departmental totals (HR, Admin, IT).
* **UART output**: demo payslip emission for employee 0 using `TX_Buffer`.

## Memory Map Highlights
* Employee records base: `0x20000000` (`NUM_EMPS = 5`, each `EMP_SIZE = 64` bytes).
* Attendance logs: `0x20001000 + i * 0x100`.
* OT hours: `0x20002000`.
* Sorted employees destination: `0x20005000`.
* Performance scores: `0x20006000`.
* UART registers: `UART0_DR = 0x4000C000`, `UART0_FR = 0x4000C018`.
* UART TX FIFO flag: `UART_TXFF_BIT = 0x20`.

## Hardware Requirements
* Provide SRAM coverage for these addresses (~24 KB starting at `0x20000000`). Verify using your board's data sheet or linker script.
* Map UART0 (or equivalent) at `0x4000C000`; adjust constants in the assembly file if your MCU differs.

## How to Run
1. Open `Assignment-2_Solution.s` (in the `Assignment-2` directory) in an ARMv7-M/Thumb-2 toolchain (e.g., Keil uVision 5 or an ARM Cortex-M simulator).
2. Build/assemble and load to a Cortex-M target or emulator (see Memory Map Highlights for the required SRAM layout).
3. Start execution at `__main`. Inspect RAM for:
   * Employee records at `0x20000000`.
   * Sorted list at `0x20005000`.
   * Department totals exported via `Total_IT`, `Total_HR`, and `Total_Admin`.
4. Connect UART0 (or simulated UART) to view the demo payslip emitted from `TX_Buffer`.

## Notes
* The code uses ARM Thumb instructions and is organized into labeled modules (`Mod0`-`Mod11`) for clarity.
* Constants, offsets, and structure layouts are defined at the top of `Assignment-2_Solution.s` for reference while debugging.
