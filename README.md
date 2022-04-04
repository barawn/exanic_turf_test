# exanic_turf_test
Test firmware for the ExaNIC X25 to be used for TURF testing

# Overview

This repository uses a combination of other modules to work:

1. alexforencich's verilog-ethernet module for the 10GbE interface to UDP
2. xillybus's PCIe interface for setup/control

# UDP interface

The UDP interface mechanism is fairly straightforward. There's a bit of abusing the UDP source ports, so the receiver
on the other side should use recvfrom in some cases rather than recvmsg.

## Important note

All multibyte values here are stored little-endian because it's just pointless to keep swapping in the PC
and we can freely handle it in the FPGA. So memcpy'ing structs into uint8_t buffers should work fine.

The TURF Ethernet interface consists of a control path and an event path.

## Control path

The control path happens through two ports,  0x5472 and 0x5477. These two ports are 'Tr' and 'Tw' respectively in
2-byte ASCII. They will be referred to as the 'Tr' and 'Tw' ports. To write a value, a packet is sent to the 
'Tw' port (and an acknowledgement returned from the Tw port to the sending port) and to read a value, a packet
is sent to the 'Tr' port (and the value returned from the Tr port to the sending port).

So the basic idea is to create a local UDP socket and bind it (I recommend 'Tx' but it doesn't matter), then sendto
either Tr or Tw (depending on whether you want to read or write) and then listen for a response on the Tx port.
Writes consist solely of a 28-bit address + 4 bit tag and 32-bit data (and are responded to with the address+tag) and 
reads consist of a 28-bit address + 4 bit tag (and are responded to with a 32-bit address and data). Multiple reads can be
included in the same UDP message, however if the message stops before the full data arrives (for instance only 24
bits of the address, then stop) the action is not carried out. The tag is to allow multiple reads to the same address to
be properly sequenced at the return in case they're presented out-of-order at the host PC for some reason (this, of course,
isn't important if multiple requests aren't fired off before reading the acknowledge back).

# Event path

The event path consists of 3 "incoming" ports, 'Tc', 'Ta', 'Tn', and an outgoing port 'Te'.
When the event path is opened by sending an open command to 'Tc', event fragments are sent out (after being set up, see below, and
in programmable MTU sizes) from the 'Te' port to the destination port specified by the open command.

Event fragments consist of a single 64-bit header, consisting of a 20-bit constant identifier, a 10-bit incrementing fragment number, 
a 12-bit tag (bits 31-20) and a 20-bit length (bits 19-0) allowing for full event sizes up to 1 MB, followed by the 
fragment data (up to the MTU size). The source UDP port indicates the position of the fragment in the event. The reason for 
making the header 64-bits is just that the UDP datapath is 64 bits overall. 

Once an event is complete and received correctly, an acknowledgement must be sent to the 'Ta' port, consisting of the 12-bit tag
(in bits 31-20, as before). If an event is *not* received correctly, the 12-bit tag plus length should be sent to the 'Tn' port,
which will retransmit the event. Note that if *none* of the fragments for an event are received, then the tag can be sent with
the maximum event size to read out the event (although extraneous data will be transmitted past the end). Since most events will
consist of many fragments, this is unlikely.

Once an open command is sent to 'Tc', the event path must be prepared before data is sent. To do this, tags must be sent to the
'Ta' port to "prime the pump." The tags to be sent depend on the implementation (specifically the total memory size). For instance,
if 256 MB is available for event buffering, then 256 tags must be sent to the 'Ta' port after opening.

## Efficiency

Ideally the MTU will be set to a large value (8 plus a power of 2 would be smart as well, e.g. 8104) to reduce the packet overhead.
In this case the overall efficiency would be well greater than 99%. Note that if the MTU is not a multiple of 8, the next lowest
multiple of 8 will be used - for example, if 1500 is set, only 1496 bytes will be sent, for an overall efficiency of 96.5%.

Note that this requires setting the network adapter on the host side to receive jumbo frames (9018 bytes).

Also note that events do *not* need to be acknowledged for the next packet to be received. This allows a single process to
receive large numbers of frames without building them into events, and a separate process to take those frames and more slowly
build them into events (and acknowledge them) to avoid packet loss.
