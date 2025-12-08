AREA    |.text|, CODE, READONLY
        THUMB
        EXPORT  __main
        EXPORT  Total_IT
        EXPORT  Total_HR
        EXPORT  Total_Admin

; ------------------------------------------------------------------------
; CONSTANTS / SIZES
; ------------------------------------------------------------------------
EMP_BASE_ADDR   EQU 0x20000000
ATT_LOG_ADDR    EQU 0x20001000      ; Emp i attendance: 0x20001000 + i*0x100
OT_LOG_ADDR     EQU 0x20002000      ; OT hours table base
SORT_DEST_ADDR  EQU 0x20005000      ; sorted employees base
SCORE_ADDR      EQU 0x20006000      ; performance scores base

EMP_SIZE        EQU 64
NUM_EMPS        EQU 5

; ---------------- Employee structure layout -------------------
; Offset  Field
; 0x00    Employee ID (word)
; 0x04    Name pointer (word)
; 0x08    Base salary (word)
; 0x0C    Grade (byte)
; 0x0D    Dept  (byte)
; 0x10    Bank Account (word)
; 0x14    Attendance pointer (word)
; 0x18    Allowance table pointer (word)
; 0x1C    Present days (byte)
; 0x1D    Flags (byte: bit0=LDEFICIT, bit1=OVERFLOW)
; 0x20    Deduction (word)
; 0x24    OT pay (word)
; 0x28    Allowance (word)
; 0x2C    Bonus (word)
; 0x30    Tax (word)
; 0x34    Net Salary (word)
; ------------------------------------------------------------------------

OFF_ID          EQU 0
OFF_NAMEPTR     EQU 4
OFF_BASE        EQU 8
OFF_GRADE       EQU 12
OFF_DEPT        EQU 13
OFF_BANK        EQU 16
OFF_ATTPTR      EQU 20
OFF_ALLOWPTR    EQU 24
OFF_PRESENT     EQU 28        ; 0x1C
OFF_FLAGS       EQU 29        ; 0x1D
OFF_DED         EQU 32        ; 0x20
OFF_OT          EQU 36        ; 0x24
OFF_ALLOW       EQU 40        ; 0x28
OFF_BONUS       EQU 44        ; 0x2C
OFF_TAX         EQU 48        ; 0x30
OFF_NET         EQU 52        ; 0x34

; Flags bits in OFF_FLAGS
FLAG_LDEFICIT   EQU 0x01
FLAG_OVERFLOW   EQU 0x02

MIN_PRESENT     EQU 22
DEDUCTION_RATE  EQU 300

UART0_DR        EQU 0x4000C000
UART0_FR        EQU 0x4000C018
UART_TXFF_BIT   EQU 0x20      ; TX FIFO full flag bit (bit 5)

; ------------------------------------------------------------------------
; MAIN
; ------------------------------------------------------------------------
__main
        ; --- Initialize test data in RAM (attendance, OT, scores) ---
        BL      Mod0_InitTestData

        ; --- Initialize employee records in memory ---
        BL      Mod1_InitRecords

        ; --- Process each employee through all payroll modules ---
        MOVS    R4, #0                  ; employee index
        LDR     R5, =EMP_BASE_ADDR      ; pointer to first employee struct

Main_Process_Loop
        CMP     R4, #NUM_EMPS
        BGE     Main_AfterLoop

        ; R0 = index, R1 = struct pointer (for Module 2)
        MOV     R0, R4
        MOV     R1, R5
        BL      Mod2_AttendanceLoader

        ; For the rest, R5 is the employee struct pointer, R4 is index
        BL      Mod3_LeaveDeduction
        BL      Mod4_OTCalculation
        BL      Mod5_Allowance
        BL      Mod6_TaxCalc
        BL      Mod7_NetSalary
		BL      Mod10_Bonus

        ADD     R5, R5, #EMP_SIZE       ; move to next employee struct
        ADDS    R4, R4, #1              ; increment employee index
        B       Main_Process_Loop

Main_AfterLoop
		; Sort by net salary and store sorted list at 0x20005000
        BL      Mod8_SortEmployees
		
        ; Departmental summary (from base table)
        BL      Mod9_DeptSummary

        ; UART payslip output (demo: employee 0)
        ;BL      Mod11_GeneratePayslip

StopHere
        B       StopHere

; ------------------------------------------------------------------------
; MODULE 0 – Initialize test data in RAM
; ------------------------------------------------------------------------
; Copies ROM patterns to:
;  - Attendance logs at 0x20001000 + i*0x100 (i=0..4), 32 bytes each (31 days + pad)
;  - OT hours at 0x20002000 (5 bytes)
;  - Scores at 0x20006000 (5 bytes)
; ------------------------------------------------------------------------
Mod0_InitTestData
        PUSH    {R4-R7,LR}

        ; --- Attendance: copy 5 × 32 bytes ---
        LDR     R0, =ATT_TABLE_ROM      ; source in ROM
        LDR     R1, =ATT_LOG_ADDR       ; dest base in RAM
        MOVS    R2, #0                  ; employee index

AttEmpLoop
        CMP     R2, #NUM_EMPS
        BGE     AttDoneAll

        ; dest = ATT_LOG_ADDR + index * 0x100
        MOV     R3, R2
        LSLS    R3, R3, #8              ; *256
        ADD     R4, R1, R3              ; R4 = dest pointer
        MOVS    R5, #32                 ; bytes per employee
        ; src offset = index * 32
        MOV     R6, R2
        LSLS    R6, R6, #5              ; *32
        ADD     R7, R0, R6              ; R7 = source pointer

AttCopyLoop
        CMP     R5, #0
        BEQ     AttNextEmp
        LDRB    R3, [R7], #1
        STRB    R3, [R4], #1
        SUBS    R5, R5, #1
        B       AttCopyLoop

AttNextEmp
        ADDS    R2, R2, #1
        B       AttEmpLoop

AttDoneAll

        ; --- OT hours: copy 5 bytes to 0x20002000 ---
        LDR     R0, =OT_TABLE_ROM
        LDR     R1, =OT_LOG_ADDR
        MOVS    R2, #NUM_EMPS
OTCopyLoop
        CMP     R2, #0
        BEQ     OTDone
        LDRB    R3, [R0], #1
        STRB    R3, [R1], #1
        SUBS    R2, R2, #1
        B       OTCopyLoop
OTDone

        ; --- Scores: copy 5 bytes to 0x20006000 ---
        LDR     R0, =SCORE_TABLE_ROM
        LDR     R1, =SCORE_ADDR
        MOVS    R2, #NUM_EMPS
ScoreCopyLoop
        CMP     R2, #0
        BEQ     ScoreDone
        LDRB    R3, [R0], #1
        STRB    R3, [R1], #1
        SUBS    R2, R2, #1
        B       ScoreCopyLoop
ScoreDone

        POP     {R4-R7,PC}
		
		LTORG

; ------------------------------------------------------------------------
; MODULE 1 – Initialize employee table
; ------------------------------------------------------------------------
Mod1_InitRecords
        PUSH    {R4-R7,LR}
        LDR     R4, =EMP_BASE_ADDR

        ; ------------ Employee 0 ------------
        LDR     R0, =1001
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =Emp0Name
        STR     R0, [R4, #OFF_NAMEPTR]
        LDR     R0, =50000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #0                  ; Grade A (0)
        STRB    R0, [R4, #OFF_GRADE]
        MOVS    R0, #0                  ; Dept IT (0)
        STRB    R0, [R4, #OFF_DEPT]
        LDR     R0, =0x12345678         ; Bank account
        STR     R0, [R4, #OFF_BANK]
        LDR     R0, =ATT_LOG_ADDR       ; Attendance pointer (emp0 base)
        STR     R0, [R4, #OFF_ATTPTR]
        LDR     R0, =AllowTable         ; Allowance table pointer (common)
        STR     R0, [R4, #OFF_ALLOWPTR]

        MOVS    R0, #0
        STRB    R0, [R4, #OFF_PRESENT]
        STRB    R0, [R4, #OFF_FLAGS]
        STR     R0, [R4, #OFF_DED]
        STR     R0, [R4, #OFF_OT]
        STR     R0, [R4, #OFF_ALLOW]
        STR     R0, [R4, #OFF_BONUS]
        STR     R0, [R4, #OFF_TAX]
        STR     R0, [R4, #OFF_NET]

        ; ------------ Employee 1 ------------
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1002
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =Emp1Name
        STR     R0, [R4, #OFF_NAMEPTR]
        LDR     R0, =40000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #1                  ; Grade B
        STRB    R0, [R4, #OFF_GRADE]
        MOVS    R0, #1                  ; Dept HR
        STRB    R0, [R4, #OFF_DEPT]
        LDR     R0, =0x23456789
        STR     R0, [R4, #OFF_BANK]
        ; Attendance pointer: 0x20001000 + 0x100
        LDR     R0, =ATT_LOG_ADDR + 0x100
        STR     R0, [R4, #OFF_ATTPTR]
        LDR     R0, =AllowTable
        STR     R0, [R4, #OFF_ALLOWPTR]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_PRESENT]
        STRB    R0, [R4, #OFF_FLAGS]
        STR     R0, [R4, #OFF_DED]
        STR     R0, [R4, #OFF_OT]
        STR     R0, [R4, #OFF_ALLOW]
        STR     R0, [R4, #OFF_BONUS]
        STR     R0, [R4, #OFF_TAX]
        STR     R0, [R4, #OFF_NET]

        ; ------------ Employee 2 ------------
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1003
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =Emp2Name
        STR     R0, [R4, #OFF_NAMEPTR]
        LDR     R0, =60000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #0                  ; Grade A
        STRB    R0, [R4, #OFF_GRADE]
        MOVS    R0, #0                  ; Dept IT
        STRB    R0, [R4, #OFF_DEPT]
        LDR     R0, =0x3456789A
        STR     R0, [R4, #OFF_BANK]
        LDR     R0, =ATT_LOG_ADDR + 0x200
        STR     R0, [R4, #OFF_ATTPTR]
        LDR     R0, =AllowTable
        STR     R0, [R4, #OFF_ALLOWPTR]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_PRESENT]
        STRB    R0, [R4, #OFF_FLAGS]
        STR     R0, [R4, #OFF_DED]
        STR     R0, [R4, #OFF_OT]
        STR     R0, [R4, #OFF_ALLOW]
        STR     R0, [R4, #OFF_BONUS]
        STR     R0, [R4, #OFF_TAX]
        STR     R0, [R4, #OFF_NET]

        ; ------------ Employee 3 ------------
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1004
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =Emp3Name
        STR     R0, [R4, #OFF_NAMEPTR]
        LDR     R0, =35000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #2                  ; Grade C
        STRB    R0, [R4, #OFF_GRADE]
        MOVS    R0, #2                  ; Dept Admin
        STRB    R0, [R4, #OFF_DEPT]
        LDR     R0, =0x456789AB
        STR     R0, [R4, #OFF_BANK]
        LDR     R0, =ATT_LOG_ADDR + 0x300
        STR     R0, [R4, #OFF_ATTPTR]
        LDR     R0, =AllowTable
        STR     R0, [R4, #OFF_ALLOWPTR]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_PRESENT]
        STRB    R0, [R4, #OFF_FLAGS]
        STR     R0, [R4, #OFF_DED]
        STR     R0, [R4, #OFF_OT]
        STR     R0, [R4, #OFF_ALLOW]
        STR     R0, [R4, #OFF_BONUS]
        STR     R0, [R4, #OFF_TAX]
        STR     R0, [R4, #OFF_NET]

        ; ------------ Employee 4 ------------
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1005
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =Emp4Name
        STR     R0, [R4, #OFF_NAMEPTR]
        LDR     R0, =45000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #1                  ; Grade B
        STRB    R0, [R4, #OFF_GRADE]
        MOVS    R0, #0                  ; Dept IT
        STRB    R0, [R4, #OFF_DEPT]
        LDR     R0, =0x56789ABC
        STR     R0, [R4, #OFF_BANK]
        LDR     R0, =ATT_LOG_ADDR + 0x400
        STR     R0, [R4, #OFF_ATTPTR]
        LDR     R0, =AllowTable
        STR     R0, [R4, #OFF_ALLOWPTR]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_PRESENT]
        STRB    R0, [R4, #OFF_FLAGS]
        STR     R0, [R4, #OFF_DED]
        STR     R0, [R4, #OFF_OT]
        STR     R0, [R4, #OFF_ALLOW]
        STR     R0, [R4, #OFF_BONUS]
        STR     R0, [R4, #OFF_TAX]
        STR     R0, [R4, #OFF_NET]

        POP     {R4-R7,PC}
		
		LTORG

; ------------------------------------------------------------------------
; MODULE 2 – Attendance loader
; Input: R0 = employee index, R1 = pointer to employee struct
; Reads from 0x20001000 + index*0x100, 31 bytes (we have 32 with pad)
; Stores present-day count in OFF_PRESENT
; ------------------------------------------------------------------------
Mod2_AttendanceLoader
        PUSH    {R4-R7,LR}

        ; Compute this employee's attendance block base
        LDR     R4, =ATT_LOG_ADDR
        MOV     R2, R0
        LSLS    R2, R2, #8              ; index * 0x100
        ADD     R4, R4, R2              ; R4 = base of this log

        MOVS    R5, #0                  ; present counter
        MOVS    R6, #0                  ; day index (0..30)

AttLoop
        CMP     R6, #31
        BGE     AttDone
        LDRB    R7, [R4, R6]
        ADDS    R5, R5, R7
        ADDS    R6, R6, #1
        B       AttLoop

AttDone
        STRB    R5, [R1, #OFF_PRESENT]
        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 3 – Leave & Deduction (with LDEFICIT flag)
; ------------------------------------------------------------------------
Mod3_LeaveDeduction
        PUSH    {R4-R7,LR}

        ; Clear LDEFICIT flag by default
        LDRB    R4, [R5, #OFF_FLAGS]
        BIC     R4, R4, #FLAG_LDEFICIT
        STRB    R4, [R5, #OFF_FLAGS]

        LDRB    R0, [R5, #OFF_PRESENT]
        MOVS    R1, #MIN_PRESENT
        CMP     R0, R1
        BCS     NoDed3                 ; present >= MIN

        SUB     R2, R1, R0             ; deficit
        LDR     R3, =DEDUCTION_RATE
        MUL     R3, R2, R3             ; deduction
        STR     R3, [R5, #OFF_DED]

        ; if deficit > 5, set LDEFICIT flag
        CMP     R2, #5
        BLE     EndDed3
        LDRB    R4, [R5, #OFF_FLAGS]
        ORR     R4, R4, #FLAG_LDEFICIT
        STRB    R4, [R5, #OFF_FLAGS]
        B       EndDed3

NoDed3
        MOVS    R3, #0
        STR     R3, [R5, #OFF_DED]

EndDed3
        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 4 – Overtime Calculation (OT hours at 0x20002000)
; ------------------------------------------------------------------------
Mod4_OTCalculation
        PUSH    {R4-R7,LR}

        ; R4 = index (kept from main)
        LDR     R6, =OT_LOG_ADDR
        ADD     R6, R6, R4              ; one byte per employee
        LDRB    R0, [R6]                ; OT hours

        LDRB    R1, [R5, #OFF_GRADE]    ; grade
        CMP     R1, #0
        BEQ     OT_gradeA
        CMP     R1, #1
        BEQ     OT_gradeB
        MOVS    R2, #150                ; Grade C
        B       OT_rate_done
OT_gradeA
        MOVS    R2, #250
        B       OT_rate_done
OT_gradeB
        MOVS    R2, #200
OT_rate_done
        MUL     R3, R0, R2
        STR     R3, [R5, #OFF_OT]

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 5 – Allowance
; HRA = 20% base = base/5
; Medical = 3000
; Transport: IT=5000, HR=4000, Admin=3500
; ------------------------------------------------------------------------
Mod5_Allowance
        PUSH    {R4-R7,LR}

        LDR     R0, [R5, #OFF_BASE]     ; base salary
        MOVS    R1, #5
        MOVS    R2, #0                  ; quotient for /5
Div5_Loop
        CMP     R0, R1
        BLT     Div5_Done
        SUBS    R0, R0, R1
        ADDS    R2, R2, #1
        B       Div5_Loop
Div5_Done
        MOV     R6, R2                  ; HRA = base/5

        LDR     R7, =3000               ; medical

        LDRB    R3, [R5, #OFF_DEPT]     ; dept: 0=IT,1=HR,2=Admin
        CMP     R3, #0
        BEQ     Trans_IT
        CMP     R3, #1
        BEQ     Trans_HR
        LDR     R4, =3500               ; Admin
        B       Trans_Done
Trans_IT
        LDR     R4, =5000
        B       Trans_Done
Trans_HR
        LDR     R4, =4000
Trans_Done
        ADDS    R0, R6, R7
        ADDS    R0, R0, R4
        STR     R0, [R5, #OFF_ALLOW]

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 6 – Tax computation (slabs)
; gross = base + allow + ot + bonus - deduction
; ------------------------------------------------------------------------
Mod6_TaxCalc
        PUSH    {R4-R7,LR}

        LDR     R0, [R5, #OFF_BASE]
        LDR     R1, [R5, #OFF_ALLOW]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_OT]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_DED]
        SUBS    R0, R0, R1              ; R0 = gross

        MOVS    R2, #0                  ; tax default 0

        LDR     R3, =30000
        CMP     R0, R3
        BLE     TaxStore6

        LDR     R3, =60000
        CMP     R0, R3
        BLE     Tax5

        LDR     R3, =120000
        CMP     R0, R3
        BLE     Tax10

        MOVS    R4, #15
        B       TaxCompute6
Tax5
        MOVS    R4, #5
        B       TaxCompute6
Tax10
        MOVS    R4, #10
        B       TaxCompute6

TaxCompute6
        MUL     R2, R0, R4
        MOVS    R6, #100
        MOVS    R7, #0
TC_Loop
        CMP     R2, R6
        BLT     TC_Done
        SUBS    R2, R2, R6
        ADDS    R7, R7, #1
        B       TC_Loop
TC_Done
        MOV     R2, R7

TaxStore6
        STR     R2, [R5, #OFF_TAX]
        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 7 – Net salary (with OVERFLOW_FLAG)
; net = base + allow + ot + bonus - tax - deduction
; ------------------------------------------------------------------------
Mod7_NetSalary
        PUSH    {R4-R7,LR}

        ; Clear OVERFLOW flag initially
        LDRB    R4, [R5, #OFF_FLAGS]
        BIC     R4, R4, #FLAG_OVERFLOW

        ; R0 accumulates net
        LDR     R0, [R5, #OFF_BASE]
        LDR     R1, [R5, #OFF_ALLOW]
        ADDS    R0, R0, R1
        BVC     M7_NoOF1
        ORR     R4, R4, #FLAG_OVERFLOW
M7_NoOF1
        LDR     R1, [R5, #OFF_OT]
        ADDS    R0, R0, R1
        BVC     M7_NoOF2
        ORR     R4, R4, #FLAG_OVERFLOW
M7_NoOF2
        BVC     M7_NoOF3
        ORR     R4, R4, #FLAG_OVERFLOW
M7_NoOF3
        LDR     R1, [R5, #OFF_TAX]
        SUBS    R0, R0, R1
        BVC     M7_NoOF4
        ORR     R4, R4, #FLAG_OVERFLOW
M7_NoOF4
        LDR     R1, [R5, #OFF_DED]
        SUBS    R0, R0, R1
        BVC     M7_NoOF5
        ORR     R4, R4, #FLAG_OVERFLOW
M7_NoOF5

        STR     R0, [R5, #OFF_NET]
        STRB    R4, [R5, #OFF_FLAGS]

        POP     {R4-R7,PC}
		
; ------------------------------------------------------------------------
; MODULE 10 – Bonus engine
; Scores at 0x20006000
; >=90: 25%, 75-89: 15%, 60-74: 8%, else 0
; ------------------------------------------------------------------------
Mod10_Bonus
        PUSH    {R4-R7,LR}

        LDR     R6, =SCORE_ADDR
        ADD     R6, R6, R4              ; R4 = index
        LDRB    R0, [R6]                ; score
        LDR     R1, [R5, #OFF_BASE]     ; base
        MOVS    R2, #0                  ; bonus

        CMP     R0, #90
        BGE     B25
        CMP     R0, #75
        BGE     B15
        CMP     R0, #60
        BGE     B8
        B       Bstore

B25
        MOVS    R3, #25
        B       Bcalc
B15
        MOVS    R3, #15
        B       Bcalc
B8
        MOVS    R3, #8
Bcalc
        MUL     R2, R1, R3
        MOVS    R4, #100
        MOVS    R7, #0
BdivLoop
        CMP     R2, R4
        BLT     BdivDone
        SUBS    R2, R2, R4
        ADDS    R7, R7, #1
        B       BdivLoop
BdivDone
        MOV     R2, R7

Bstore
        STR     R2, [R5, #OFF_BONUS]

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 8 – Sort employees by net salary (descending)
; Copies base table to SORT_DEST_ADDR and sorts there
; ------------------------------------------------------------------------
Mod8_SortEmployees
        PUSH    {R4-R11,LR}

        ; --------- Copy EMP_BASE_ADDR -> SORT_DEST_ADDR first ----------
        LDR     R0, =EMP_BASE_ADDR
        LDR     R1, =SORT_DEST_ADDR
        MOVS    R2, #NUM_EMPS          ; number of employees

CopyEmpLoop
        CMP     R2, #0
        BEQ     CopyDone
        ; copy one employee (64 bytes = 16 words)
        MOVS    R3, #0
CopyEmpWords
        CMP     R3, #(EMP_SIZE/4)
        BGE     CopyEmpNext
        LDR     R6, [R0, R3, LSL #2]
        STR     R6, [R1, R3, LSL #2]
        ADDS    R3, R3, #1
        B       CopyEmpWords
CopyEmpNext
        ADD     R0, R0, #EMP_SIZE
        ADD     R1, R1, #EMP_SIZE
        SUBS    R2, R2, #1
        B       CopyEmpLoop
CopyDone

        ; --------- Bubble sort on SORT_DEST_ADDR ----------
        LDR     R8, =SORT_DEST_ADDR

        MOVS    R9, #0
Outer8
        MOVS    R10, #0
        MOV     R11, R8
Inner8
        CMP     R10, #NUM_EMPS-1
        BGE     EndInner8

        ADD     R0, R11, #0
        ADD     R1, R11, #EMP_SIZE
        LDR     R2, [R0, #OFF_NET]
        LDR     R3, [R1, #OFF_NET]
        CMP     R2, R3
        BGE     SkipSwap8               ; already in order

        ; swap two employee records (64 bytes)
        MOVS    R4, #0
SwapWords8
        CMP     R4, #(EMP_SIZE/4)
        BGE     SwapDone8
        LDR     R5, [R0, R4, LSL #2]
        LDR     R6, [R1, R4, LSL #2]
        STR     R6, [R0, R4, LSL #2]
        STR     R5, [R1, R4, LSL #2]
        ADDS    R4, R4, #1
        B       SwapWords8
SwapDone8

SkipSwap8
        ADD     R11, R11, #EMP_SIZE
        ADDS    R10, R10, #1
        B       Inner8

EndInner8
        ADDS    R9, R9, #1
        CMP     R9, #NUM_EMPS
        BLT     Outer8

        POP     {R4-R11,PC}

; ------------------------------------------------------------------------
; MODULE 9 – Department salary summary
; Sums IT, HR, Admin net salaries and stores in Total_IT/HR/Admin
; ------------------------------------------------------------------------
Mod9_DeptSummary
        PUSH    {R4-R7,LR}

        LDR     R4, =EMP_BASE_ADDR
        MOVS    R5, #0

        MOVS    R6, #0      ; total IT
        MOVS    R7, #0      ; total HR
        MOVS    R3, #0      ; total Admin

SumLoop9
        CMP     R5, #NUM_EMPS
        BGE     SumDone9

        LDRB    R0, [R4, #OFF_DEPT]
        LDR     R1, [R4, #OFF_NET]
        CMP     R0, #0
        BEQ     AddIT9
        CMP     R0, #1
        BEQ     AddHR9
        ADDS    R3, R3, R1
        B       Next9
AddIT9
        ADDS    R6, R6, R1
        B       Next9
AddHR9
        ADDS    R7, R7, R1

Next9
        ADD     R4, R4, #EMP_SIZE
        ADDS    R5, R5, #1
        B       SumLoop9

SumDone9
        LDR     R0, =Total_IT
        STR     R6, [R0]
        LDR     R0, =Total_HR
        STR     R7, [R0]
        LDR     R0, =Total_Admin
        STR     R3, [R0]

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; UART helper: send one character (R0)
; ------------------------------------------------------------------------
UART_SendChar
        PUSH    {R1,LR}
WaitTX
        LDR     R1, =UART0_FR
        LDR     R1, [R1]
        TST     R1, #UART_TXFF_BIT      ; TXFF == 1 => FIFO full
        BNE     WaitTX
        LDR     R1, =UART0_DR
        STR     R0, [R1]
        POP     {R1,PC}

; ------------------------------------------------------------------------
; UART helper: send zero-terminated string (R0 = pointer)
; ------------------------------------------------------------------------
UART_SendString
        PUSH    {R1-R2,LR}
USS_Loop
        LDRB    R1, [R0]
        CMP     R1, #0
        BEQ     USS_Done
        MOV     R2, R1
        MOV     R0, R2
        BL      UART_SendChar
        ADDS    R0, R0, #1
        B       USS_Loop
USS_Done
        POP     {R1-R2,PC}

; ------------------------------------------------------------------------
; Print unsigned int in R0 as decimal using recursion + UDIV
; ------------------------------------------------------------------------
PrintNumber
        PUSH    {R1-R3,LR}

        ; if R0 >= 10: recurse on R0/10
        MOVS    R1, #10
        CMP     R0, R1
        BLT     PN_Base

        UDIV    R2, R0, R1         ; R2 = R0 / 10
        MUL     R3, R2, R1         ; R3 = R2 * 10
        SUBS    R3, R0, R3         ; R3 = remainder
        MOV     R0, R2
        BL      PrintNumber        ; print higher digits
        MOV     R0, R3             ; print last digit
        ADDS    R0, R0, #'0'
        BL      UART_SendChar
        POP     {R1-R3,PC}

PN_Base
        ADDS    R0, R0, #'0'
        BL      UART_SendChar
        POP     {R1-R3,PC}

; ------------------------------------------------------------------------
; MODULE 11 – UART payslip generator
; Prints for employee 0:
;  ID, Net, Tax, Allow, Bonus, Final Pay (= Net + Bonus), each in decimal
; ------------------------------------------------------------------------
Mod11_GeneratePayslip
        PUSH    {R4-R7,LR}

        LDR     R4, =EMP_BASE_ADDR     ; employee 0 struct

        ; -------- Print "ID: " + EmployeeID --------
        LDR     R0, =Str_ID
        BL      UART_SendString
        LDR     R0, [R4, #OFF_ID]
        BL      PrintNumber
        MOVS    R0, #13               ; '\r'
        BL      UART_SendChar
        MOVS    R0, #10               ; '\n'
        BL      UART_SendChar

        ; -------- Net Salary --------
        LDR     R0, =Str_Net
        BL      UART_SendString
        LDR     R0, [R4, #OFF_NET]
        BL      PrintNumber
        MOVS    R0, #13
        BL      UART_SendChar
        MOVS    R0, #10
        BL      UART_SendChar

        ; -------- Tax --------
        LDR     R0, =Str_Tax
        BL      UART_SendString
        LDR     R0, [R4, #OFF_TAX]
        BL      PrintNumber
        MOVS    R0, #13
        BL      UART_SendChar
        MOVS    R0, #10
        BL      UART_SendChar

        ; -------- Allowance --------
        LDR     R0, =Str_Allow
        BL      UART_SendString
        LDR     R0, [R4, #OFF_ALLOW]
        BL      PrintNumber
        MOVS    R0, #13
        BL      UART_SendChar
        MOVS    R0, #10
        BL      UART_SendChar

        ; -------- Bonus --------
        LDR     R0, =Str_Bonus
        BL      UART_SendString
        LDR     R0, [R4, #OFF_BONUS]
        BL      PrintNumber
        MOVS    R0, #13
        BL      UART_SendChar
        MOVS    R0, #10
        BL      UART_SendChar

        ; -------- Final Pay = Net + Bonus --------
        LDR     R0, =Str_Final
        BL      UART_SendString
        LDR     R1, [R4, #OFF_NET]
        LDR     R2, [R4, #OFF_BONUS]
        ADDS    R0, R1, R2
        BL      PrintNumber
        MOVS    R0, #13
        BL      UART_SendChar
        MOVS    R0, #10
        BL      UART_SendChar

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; READONLY DATA (ROM)
; ------------------------------------------------------------------------
        AREA    |.rodata|, DATA, READONLY
        ALIGN

; Employee names (for NamePtr fields)
Emp0Name        DCB "Alice",0
Emp1Name        DCB "Bob",0
Emp2Name        DCB "Charlie",0
Emp3Name        DCB "Diana",0
Emp4Name        DCB "Evan",0

; Dummy allowance table pointer target (not actually used in code logic)
AllowTable      DCD 0,0,0

; Attendance patterns for 5 employees (ROM, 32 bytes each: 31+pad)
ATT_TABLE_ROM
        ; Emp 0 (31 days: mostly present, 1 absence)
        DCB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1
        DCB 0
        ; Emp 1
        DCB 1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1
        DCB 0
        ; Emp 2
        DCB 1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        DCB 0
        ; Emp 3 (more absences early)
        DCB 0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        DCB 0
        ; Emp 4
        DCB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        DCB 0

; OT hours (ROM)
OT_TABLE_ROM
        DCB     2,0,5,1,3

; Scores (ROM)
SCORE_TABLE_ROM
        DCB     92,80,70,55,88

; Strings for UART labels
Str_ID          DCB "ID: ",0
Str_Net         DCB "Net Salary: ",0
Str_Tax         DCB "Tax: ",0
Str_Allow       DCB "Allowance: ",0
Str_Bonus       DCB "Bonus: ",0
Str_Final       DCB "Final Pay: ",0

; ------------------------------------------------------------------------
; READWRITE DATA
; ------------------------------------------------------------------------
        AREA    |.data|, DATA, READWRITE
        ALIGN

Total_IT        DCD     0
Total_HR        DCD     0
Total_Admin     DCD     0

        END
