AREA    |.text|, CODE, READONLY
        THUMB
        EXPORT  __main
		EXPORT  Total_IT
        EXPORT  Total_HR
        EXPORT  Total_Admin

; ------------------------------------------------------------------------
; Constants / Sizes
; ------------------------------------------------------------------------
EMP_BASE_ADDR   EQU 0x20000000
ATT_LOG_ADDR    EQU 0x20001000      ; (not used directly now)
OT_LOG_ADDR     EQU 0x20002000
SORT_DEST_ADDR  EQU 0x20005000
SCORE_ADDR      EQU 0x20006000

EMP_SIZE        EQU 64
NUM_EMPS        EQU 5

; Offsets inside employee struct
OFF_ID          EQU 0
OFF_BASE        EQU 4
OFF_NET         EQU 8
OFF_ALLOW       EQU 12
OFF_OT          EQU 16
OFF_DED         EQU 20
OFF_TAX         EQU 24
OFF_BONUS       EQU 28
OFF_GRADE       EQU 32
OFF_DEPT        EQU 33
OFF_PRESENT     EQU 34

MIN_PRESENT     EQU 22
DEDUCTION_RATE  EQU 300

UART0_DR        EQU 0x4000C000
UART0_FR        EQU 0x4000C018

; ------------------------------------------------------------------------
; MAIN
; ------------------------------------------------------------------------
__main
        ; --- Initialize employee records ---
        BL      Mod1_InitRecords

        MOVS    R4, #0                  ; employee index
        LDR     R5, =EMP_BASE_ADDR      ; pointer to first employee struct

Main_Process_Loop
        CMP     R4, #NUM_EMPS
        BGE     Main_AfterLoop

        ; Pass employee index in R0, struct pointer in R1
        MOV     R0, R4
        MOV     R1, R5
        BL      Mod2_AttendanceLoader

        BL      Mod3_LeaveDeduction
        BL      Mod4_OTCalculation
        BL      Mod5_Allowance
        BL      Mod10_Bonus
        BL      Mod6_TaxCalc
        BL      Mod7_NetSalary

        ADD     R5, R5, #EMP_SIZE       ; move to next employee struct
        ADDS    R4, R4, #1              ; increment employee index
        B       Main_Process_Loop

Main_AfterLoop
        BL      Mod9_DeptSummary
        BL      Mod8_SortEmployees
        BL      Mod11_GeneratePayslip

StopHere
        B       StopHere

; ------------------------------------------------------------------------
; MODULE 1 - Initialize employee table
; ------------------------------------------------------------------------
Mod1_InitRecords
        PUSH    {R4-R7,LR}
        LDR     R4, =EMP_BASE_ADDR

        ; Employee 0
        LDR     R0, =1001
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =50000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_GRADE]
        STRB    R0, [R4, #OFF_DEPT]
        MOVS    R0, #0
        STR     R0, [R4, #OFF_NET]
        STR     R0, [R4, #OFF_ALLOW]
        STR     R0, [R4, #OFF_OT]
        STR     R0, [R4, #OFF_DED]
        STR     R0, [R4, #OFF_TAX]
        STR     R0, [R4, #OFF_BONUS]
        STRB    R0, [R4, #OFF_PRESENT]

        ; Employee 1
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1002
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =40000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #1
        STRB    R0, [R4, #OFF_GRADE]
        STRB    R0, [R4, #OFF_DEPT]

        ; Employee 2
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1003
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =60000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_GRADE]
        STRB    R0, [R4, #OFF_DEPT]

        ; Employee 3
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1004
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =35000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #2
        STRB    R0, [R4, #OFF_GRADE]
        STRB    R0, [R4, #OFF_DEPT]

        ; Employee 4
        ADD     R4, R4, #EMP_SIZE
        LDR     R0, =1005
        STR     R0, [R4, #OFF_ID]
        LDR     R0, =45000
        STR     R0, [R4, #OFF_BASE]
        MOVS    R0, #1
        STRB    R0, [R4, #OFF_GRADE]
        MOVS    R0, #0
        STRB    R0, [R4, #OFF_DEPT]

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 2 - Attendance loader
; Input: R0 = employee index, R1 = pointer to employee struct
; ------------------------------------------------------------------------
Mod2_AttendanceLoader
        PUSH    {R4-R7,LR}

        LDR     R4, =ATT_TABLE          ; base of attendance table

        ; Compute pointer to this employee row
        MOV     R2, R0                   ; index
        MOVS    R3, #32                  ; stride
        MUL     R2, R2, R3
        ADD     R4, R4, R2               ; R4 = pointer to employee row

        MOVS    R5, #0                   ; present counter
        MOVS    R6, #0                   ; day index

CountLoop
        CMP     R6, #32
        BGE     CountDone
        LDRB    R7, [R4, R6]
        ADDS    R5, R5, R7
        ADDS    R6, R6, #1
        B       CountLoop

CountDone
        STRB    R5, [R1, #OFF_PRESENT]   ; store present days

        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 3 - Leave & Deduction
; ------------------------------------------------------------------------
Mod3_LeaveDeduction
        PUSH    {R4-R7,LR}

        LDRB    R0, [R5, #OFF_PRESENT]
        MOVS    R1, #MIN_PRESENT
        CMP     R0, R1
        BCS     NoDed3                 ; present >= MIN

        SUB     R2, R1, R0             ; deficit = MIN - present

        LDR     R3, =DEDUCTION_RATE
        MUL     R3, R2, R3             ; deduction
        STR     R3, [R5, #OFF_DED]

        CMP     R2, #5
        BLE     SkipFlag3
        ; here you could set a flag bit if you add a flags field
SkipFlag3
        B       EndDed3

NoDed3
        MOVS    R3, #0
        STR     R3, [R5, #OFF_DED]

EndDed3
        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 4 - Overtime Calculation
; ------------------------------------------------------------------------
Mod4_OTCalculation
        PUSH    {R4-R7,LR}

        LDR     R6, =OT_TABLE
        ADD     R6, R6, R4              ; one byte per employee (R4 = index)
        LDRB    R0, [R6]                ; hours

        LDRB    R1, [R5, #OFF_GRADE]    ; grade
        CMP     R1, #0
        BEQ     OT_gradeA
        CMP     R1, #1
        BEQ     OT_gradeB
        MOVS    R2, #150                ; grade C
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
; MODULE 5 - Allowance
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

        LDRB    R3, [R5, #OFF_DEPT]     ; dept
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
; MODULE 10 - Bonus engine
; ------------------------------------------------------------------------
Mod10_Bonus
        PUSH    {R4-R7,LR}

        LDR     R6, =SCORE_TABLE
        ADD     R6, R6, R4
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
; MODULE 6 - Tax computation
; ------------------------------------------------------------------------
Mod6_TaxCalc
        PUSH    {R4-R7,LR}

        LDR     R0, [R5, #OFF_BASE]
        LDR     R1, [R5, #OFF_ALLOW]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_OT]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_BONUS]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_DED]
        SUBS    R0, R0, R1              ; gross

        MOVS    R2, #0                  ; default tax

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
; MODULE 7 - Net salary
; ------------------------------------------------------------------------
Mod7_NetSalary
        PUSH    {R4-R7,LR}

        LDR     R0, [R5, #OFF_BASE]
        LDR     R1, [R5, #OFF_ALLOW]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_OT]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_BONUS]
        ADDS    R0, R0, R1
        LDR     R1, [R5, #OFF_TAX]
        SUBS    R0, R0, R1
        LDR     R1, [R5, #OFF_DED]
        SUBS    R0, R0, R1

        STR     R0, [R5, #OFF_NET]
        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; MODULE 8 - Sort employees by net salary (bubble sort)
; ------------------------------------------------------------------------
Mod8_SortEmployees
        PUSH    {R4-R11,LR}

        LDR     R8, =EMP_BASE_ADDR

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
        BGE     SkipSwap8

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
; MODULE 9 - Department salary summary
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
; MODULE 11 - UART payslip generator (stub)
; ------------------------------------------------------------------------
Mod11_GeneratePayslip
        PUSH    {R4-R7,LR}
        LDR     R4, =EMP_BASE_ADDR
        LDR     R0, [R4, #OFF_ID]
        ; TODO: implement UART printing here
        NOP
        POP     {R4-R7,PC}

; ------------------------------------------------------------------------
; DATA AREA
; ------------------------------------------------------------------------
        AREA    |.rodata|, DATA, READONLY
        ALIGN

ATT_TABLE
        ; Employee 0
        DCB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1
        DCB 0
        ; Employee 1
        DCB 1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1
        DCB 0
        ; Employee 2
        DCB 1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        DCB 0
        ; Employee 3
        DCB 0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        DCB 0
        ; Employee 4
        DCB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        DCB 0
		
OT_TABLE        
		DCB     2,0,5,1,3
		
SCORE_TABLE     
		DCB     92,80,70,55,88

        AREA    |.data|, DATA, READWRITE
        ALIGN

Total_IT        DCD     0
Total_HR        DCD     0
Total_Admin     DCD     0


        END
