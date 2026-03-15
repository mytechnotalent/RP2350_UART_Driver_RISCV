# Chapter 2: Number Systems — Binary, Hexadecimal, and Decimal

## Introduction

Before you can read a single register address or write a single mask, you must be fluent in three number systems: decimal (base 10), binary (base 2), and hexadecimal (base 16).  This is not optional.  Every data sheet, every register description, every assembly instruction uses these interchangeably.

## Decimal (Base 10)

This is the number system you already know.  It uses digits 0 through 9.  Each position is a power of 10.

```
  247 = (2 × 100) + (4 × 10) + (7 × 1)
      = (2 × 10²) + (4 × 10¹) + (7 × 10⁰)
```

## Binary (Base 2)

Computers operate on electricity.  A wire is either carrying a voltage (1) or not (0).  This is the physical basis of binary.

Binary uses only two digits: 0 and 1.  Each position is a power of 2.

```
  Binary: 1101
  = (1 × 8) + (1 × 4) + (0 × 2) + (1 × 1)
  = (1 × 2³) + (1 × 2²) + (0 × 2¹) + (1 × 2⁰)
  = 8 + 4 + 0 + 1
  = 13 in decimal
```

### Bit Positions

We number bit positions starting from 0 on the right:

```
  Bit:     7    6    5    4    3    2    1    0
  Value: 128   64   32   16    8    4    2    1
```

A byte (8 bits) can represent values from 0 (00000000) to 255 (11111111).

### Powers of 2 Table (Memorize This)

| Power | Value | Common Name |
|---:|---:|---|
| 2⁰ | 1 | |
| 2¹ | 2 | |
| 2² | 4 | |
| 2³ | 8 | |
| 2⁴ | 16 | |
| 2⁵ | 32 | |
| 2⁶ | 64 | |
| 2⁷ | 128 | |
| 2⁸ | 256 | |
| 2⁹ | 512 | |
| 2¹⁰ | 1,024 | 1 K |
| 2¹¹ | 2,048 | 2 K |
| 2¹² | 4,096 | 4 K |
| 2¹⁶ | 65,536 | 64 K |
| 2²⁰ | 1,048,576 | 1 M |
| 2³² | 4,294,967,296 | Full 32-bit range |

## Hexadecimal (Base 16)

Binary is verbose.  Writing 32-bit addresses in binary would be 32 characters long.  Hexadecimal solves this by using 16 digits: 0-9 and A-F.

| Hex | Decimal | Binary |
|---:|---:|---:|
| 0 | 0 | 0000 |
| 1 | 1 | 0001 |
| 2 | 2 | 0010 |
| 3 | 3 | 0011 |
| 4 | 4 | 0100 |
| 5 | 5 | 0101 |
| 6 | 6 | 0110 |
| 7 | 7 | 0111 |
| 8 | 8 | 1000 |
| 9 | 9 | 1001 |
| A | 10 | 1010 |
| B | 11 | 1011 |
| C | 12 | 1100 |
| D | 13 | 1101 |
| E | 14 | 1110 |
| F | 15 | 1111 |

**Each hex digit maps exactly to 4 binary bits.**  This is the key insight.

### Converting Binary to Hex

Group bits into chunks of 4 from the right:

```
  Binary:  0100 0000 0111 0000 0000 0000 0000 0000
  Hex:        4    0    7    0    0    0    0    0
  Result: 0x40700000
```

That number is `UART0_BASE`, the base address of the UART0 peripheral on RP2350.

### Converting Hex to Binary

Replace each hex digit with its 4-bit equivalent:

```
  0x1101
  = 0001 0001 0000 0001
```

That is the IMAGE_DEF type value meaning EXE + RISC-V + RP2350.

## Prefixes in Code

In assembly and C, these prefixes identify the base:

| Prefix | Base | Example |
|---|---|---|
| 0x | Hexadecimal | 0x40070000 |
| 0b | Binary | 0b11010110 |
| (none) | Decimal | 112 |

## Size Units in Computing

| Unit | Bits | Bytes |
|---|---:|---:|
| Bit | 1 | 1/8 |
| Nibble | 4 | 1/2 |
| Byte | 8 | 1 |
| Halfword | 16 | 2 |
| Word (RV32) | 32 | 4 |

On a 32-bit RISC-V machine, a "word" is always 32 bits (4 bytes).  Every general-purpose register holds exactly one word.

## Practice Problems

Convert the following (work them out by hand):

1. `0xFF` to decimal
2. `0b10100101` to hex
3. `255` to binary
4. `0x20082000` — what is bit 17?
5. What decimal number is `(1 << 26)`?

### Answers

1. `0xFF = 15×16 + 15 = 255`
2. `0b10100101 = 0xA5`
3. `255 = 0b11111111`
4. `0x20082000 = 0010 0000 0000 1000 0010 0000 0000 0000`, bit 17 = 1
5. `(1 << 26) = 67,108,864 = 0x04000000`

## Chapter Summary

Binary is the language of hardware.  Hex is the shorthand.  Decimal is for humans.  You must be able to convert between all three instantly.  Every address, every register value, every bit mask in this book is a number in one of these three bases.
