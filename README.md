# mini-soc-cache-axi-lite

Mini SoC with Cache and AXI-Lite Interface
Overview

This project implements a mini System-on-Chip (SoC) memory subsystem using SystemVerilog.
It integrates an AXI-Lite slave interface, a direct-mapped write-back cache, a simple memory, and a timer peripheral, connected through a lightweight address-decoded interconnect.

The system demonstrates fundamental SoC concepts including:
1.AXI protocol handshaking
2.Cache hit/miss behavior
3.Cache refill from memory
4.Dirty line write-back
5.Memory-mapped peripheral access
6.Address decoding

The design is verified using a SystemVerilog testbench and simulation waveforms.

Architecture
AXI Master (Testbench)---> AXI-Lite Slave Interface---->Simple Interconnect (Address Decoder)--->1. Cache Controller or 2. Timer Peripheral
                                                                                                          ^
                                                                                                          |
                                                                                                          |
                                                                                                     SImple memory
The AXI slave converts AXI transactions into a simplified internal request bus used by the rest of the system.


Address Map:

Address Range	                           Device
0x00 – 0x7F	                        Cache + Memory
0x80 – 0x8F                        	Timer Peripheral
>0x8F	                            Invalid (DECERR response)

Cache Architecture
The cache is a direct-mapped write-back cache.

Cache parameters
Parameter                                	Value
Cache lines                                	4
Line size                                	4 bytes
Address width	                             8 bits


Address breakdown:
[ Tag | Index | Offset ]
 4 bits 2 bits 2 bits

 
Cache states
The cache controller operates using a small FSM:

IDLE – waiting for CPU request
REFILL – fetching cache line from memory
WRITEBACK – writing dirty line to memory before replacement


Features Implemented
AXI-Lite Slave Interface

Handles the five AXI channels:
1.Write Address (AW)
2.Write Data (W)
3.Write Response (B)
4.Read Address (AR)
5.Read Data (R)

Supports:
Independent address/data channels
Proper handshake logic
DECERR response for invalid addresses


Direct-Mapped Cache
The cache controller implements:

1.Cache hit detection
2.Cache miss handling
3.Line refill from memory
4.Dirty line writeback
5.Byte-level access inside cache line


Simple Memory
A behavioral memory model is used for simulation.

Features:
1.Configurable latency
2.Request/response interface
3.Byte-addressable storage
4.Memory initialized with address values for easy debugging


Timer Peripheral
A simple memory-mapped peripheral accessed through the interconnect.
Addresses 0x80 – 0x8F are routed to the timer instead of cache/memory.


Address-Decoded Interconnect
The interconnect routes requests based on address:

if address < 0x80 → cache
if 0x80 ≤ address < 0x90 → timer
otherwise → decode error
->Responses are multiplexed back to the AXI slave.


Verification
A SystemVerilog testbench generates AXI transactions to verify system behavior.

Test scenarios include:
#test1 : Cache miss + refill
#test2 : Cache hit
#test3 : Peripheral access
#test4 : Cache writeback on eviction
#test5 : Invalid address detection

Simulation waveforms confirm correct operation of:
->AXI handshakes
->Cache FSM transitions
->Memory refill sequence
->Writeback transactions


Example Waveform
The waveform demonstrates:

1.CPU request generation
2.Cache miss detection
3.Memory refill transactions
4.Cache hit response
5.Writeback sequence during cache eviction


Technologies Used:
->SystemVerilog
->AXI-Lite protocol
->RTL design
->Digital cache architecture
->Simulation-based verification
