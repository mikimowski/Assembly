# Assembly
Assembly language projects aiming to provide insight into "machine's way of thinking"

## Attack
Assembly x86_64 program which as an argument gets file and checks whether this file satisfies multiple criterias.  
File is treated as a binary file containing sequence of 32-bit numbers.

Criterias:
- File does not contain number 68020
- File does contain number greater than 68020 but smaller than 2^31
- File does contain five consecutive numbers: 6, 8, 0, 2, 0
- Sum of all numbers in file modulo 2 ^ 32 is equal: 68020

### Compilation
nasm -f elf64 -o attack.o attack.asm  
ld --fatal-warnings -o attack attack.o  



## Euron
Assembly x86_64 program simulating euron network.  
Network contains N eurons, labeled from 0 to N-1.  
</br>
Module implements C function:  
uint64_t euron(uint64_t n, char const \*prog);  
prog parameter's is a string which describes set of operations which are performed using stack.  
</br>
Eurons work <b>concurrently</b> - each euron is started by different thread.
