# Chapter 6: The Fetch-Decode-Execute Cycle in Detail

## Introduction

Chapter 1 introduced the fetch-decode-execute cycle as the heartbeat of the CPU.  This chapter breaks it down to the bit level so you understand exactly what happens when the Hazard3 RISC-V core processes each instruction.

## The Cycle Step by Step

### Step 1: FETCH

The CPU reads the Program Counter (PC) register.  The PC holds the address of the next instruction.

The CPU places this address on the memory bus and reads 4 bytes (one word) from that location.

```
  PC = 0x10000100
  CPU reads memory[0x10000100..0x10000103]
  Gets 32-bit instruction word: e.g., 0x40070537
```

**Note**: The C extension allows 16-bit compressed instructions.  When the CPU detects a compressed instruction (lowest 2 bits ≠ 11), it only consumes 2 bytes and advances PC by 2.

### Step 2: DECODE

The CPU examines specific bit fields in the instruction word to determine:
1. What operation to perform (opcode and funct fields)
2. Which registers to read (source registers rs1, rs2)
3. Which register to write (destination register rd)
4. What immediate value is embedded (if any)

RISC-V has a fixed 32-bit instruction format with the opcode always in bits [6:0].

### RISC-V Instruction Formats

There are six instruction formats.  Each arranges the 32-bit instruction word differently:

```
  R-type:  [funct7  | rs2   | rs1 | funct3 | rd    | opcode]
           [31   25 |24  20 |19 15|14   12 |11   7 |6     0]

  I-type:  [imm[11:0]       | rs1 | funct3 | rd    | opcode]
           [31           20 |19 15|14   12 |11   7 |6     0]

  S-type:  [imm[11:5]| rs2  | rs1 | funct3 |imm[4:0]|opcode]
           [31    25 |24  20|19 15|14   12 |11    7 |6     0]

  B-type:  [imm bits | rs2  | rs1 | funct3 |imm bits|opcode]
           [31    25 |24  20|19 15|14   12 |11    7 |6     0]

  U-type:  [imm[31:12]                     | rd    | opcode]
           [31                          12 |11   7 |6     0]

  J-type:  [imm bits                       | rd    | opcode]
           [31                          12 |11   7 |6     0]
```

### Decoding Examples

**Example 1: `add t2, t0, t1`** (R-type)
```
  Opcode:  0110011 (OP - register arithmetic)
  funct3:  000     (ADD)
  funct7:  0000000 (ADD, not SUB)
  rd:      00111   (x7 = t2)
  rs1:     00101   (x5 = t0)
  rs2:     00110   (x6 = t1)
```
The CPU knows to: read t0 and t1, send them to the ALU with ADD operation, write result to t2.

**Example 2: `lw t1, 0x18(t0)`** (I-type)
```
  Opcode:  0000011 (LOAD)
  funct3:  010     (LW - load word)
  rd:      00110   (x6 = t1)
  rs1:     00101   (x5 = t0)
  imm:     000000011000 (0x18 = 24)
```
The CPU knows to: read t0, add 24, use result as memory address, load 4 bytes, write to t1.

**Example 3: `sw a0, 0x00(t0)`** (S-type)
```
  Opcode:  0100011 (STORE)
  funct3:  010     (SW - store word)
  rs1:     00101   (x5 = t0)
  rs2:     01010   (x10 = a0)
  imm:     000000000000 (0x00 = 0)
```
The CPU knows to: read t0, add 0, use result as memory address, write value of a0 to that address.

### Step 3: EXECUTE

The CPU performs the operation determined during decode:
- For arithmetic (add, sub, and, or): the ALU computes the result
- For loads: the memory bus reads from the computed address
- For stores: the memory bus writes to the computed address
- For branches: the ALU compares registers and decides whether to modify PC

### Step 4: WRITE BACK

If the instruction produces a result (loads, arithmetic), it is written to the destination register `rd`.

If the instruction is a store or branch, there is no register write-back.

### Step 5: UPDATE PC

- Normal instructions: PC = PC + 4 (advance to next instruction)
- Compressed instructions: PC = PC + 2
- Branches (taken): PC = PC + sign-extended offset
- Jumps (j, jal): PC = PC + sign-extended offset
- Indirect jumps (jalr, ret): PC = value from register + offset

## Pipeline Concept

Modern CPUs overlap these stages.  While one instruction is executing, the next is being decoded, and the one after that is being fetched:

```
  Cycle:    1     2     3     4     5     6     7
  Instr 1:  FETCH DECODE EXEC  WB
  Instr 2:        FETCH  DECODE EXEC  WB
  Instr 3:               FETCH  DECODE EXEC  WB
  Instr 4:                      FETCH  DECODE EXEC  WB
```

The Hazard3 core in RP2350 uses a pipeline.  This means instructions overlap in execution, achieving higher throughput.

**Pipeline hazards** occur when:
- An instruction needs a register another instruction is still computing (data hazard)
- A branch instruction changes the PC, making fetched instructions invalid (control hazard)

The hardware handles these with stalling and forwarding.  You do not need to manage this manually, but understanding it helps explain why some instruction sequences are faster than others.

## Tracing Through Our Firmware

Let us trace the first few instructions after reset.  The PC starts at the `Reset_Handler` address.

```asm
  # In reset_handler.s:
  call  Init_Stack                               # PC = Reset_Handler address
```

What happens:
1. FETCH: CPU reads 8 bytes (call is two instructions: auipc + jalr)
2. DECODE: auipc sets ra to PC + offset upper bits
3. EXECUTE: compute target address of Init_Stack
4. PC updated to Init_Stack entry point, ra holds return address

```asm
  # In stack.s:
  li    sp, STACK_TOP                            # first instruction of Init_Stack
```

What happens:
1. FETCH: `li` expands to `lui sp, upper20` and `addi sp, sp, lower12`
2. DECODE: `lui` — load upper immediate into sp
3. EXECUTE: sp gets upper 20 bits of 0x20082000
4. FETCH next: `addi sp, sp, lower12`
5. EXECUTE: sp = sp + lower 12 bits, now sp = 0x20082000

```asm
  ret                                            # return from Init_Stack
```

What happens:
1. FETCH: `ret` is actually `jalr zero, ra, 0`
2. DECODE: read ra register, add 0, jump to that address
3. EXECUTE: PC = ra (return address in Reset_Handler)
4. x0 gets the "write" of old PC+4, but x0 ignores all writes

## The Program Counter is Everything

The PC is the master of program execution.  Every instruction either:
- Advances it by 2 or 4 (normal sequential flow)
- Changes it to a new address (branch, jump, call, ret)

When you see the `Reset_Handler` entry point in our linker script, that is the initial PC value the boot ROM loads.  From that point, the PC drives through every single instruction in our boot sequence.

## Practice Problems

1. How many bytes does a normal (non-compressed) RISC-V instruction occupy?
2. What bits in a RISC-V instruction word contain the opcode?
3. After `sw a0, 0(t0)` executes, does any register get written?
4. If PC = 0x10000100 and the current instruction is not a branch, what is the next PC?
5. What does `jalr zero, ra, 0` do?

### Answers

1. 4 bytes (32 bits)
2. Bits [6:0] (the lowest 7 bits)
3. No.  SW is a store instruction — it writes to memory, not to a register.
4. 0x10000104 (PC + 4)
5. It jumps to the address in `ra` + 0 and writes old PC+4 to `zero` (discarded).  This is the `ret` pseudoinstruction.

## Chapter Summary

The fetch-decode-execute cycle reads an instruction from the address in PC, decodes the bit fields to determine the operation and operands, executes it, writes back the result (if any), and advances PC.  RISC-V has six instruction formats (R, I, S, B, U, J) that arrange the 32 bits in fixed patterns.  Modern CPUs pipeline these stages for performance.  The PC drives all program flow.
