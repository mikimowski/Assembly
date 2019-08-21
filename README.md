# Assembly
Assembly language projects aiming to provide insight into "machine's way of thinking"

## Attack
Assembly x86_64 program which as an argument gets file and checks whether this file satisfies multiple criterias.
File is treated as binary file containing sequence of 32-bit numbers.

Criterias:
- File does not contain number 68020
- File does contain number greater than 68020 but smaller than 2^31
- File does contain five consecutive numbers: 6, 8, 0, 2, 0
- Sum of all numbers in file modulo 2 ^ 32 is equal: 68020

### Compilation
nasm -f elf64 -o attack.o attack.asm
ld --fatal-warnings -o attack attack.o




