# exanic_turf_test
Test firmware for the ExaNIC X25 to be used for TURF testing

# Overview

This repository uses a combination of other modules to work:

1. alexforencich's verilog-ethernet module for the 10GbE interface to UDP
2. xillybus's PCIe interface for setup/control

# Initial Setup

1. Make sure you have Vivado_init.tcl set up as mentioned at http://github.com/barawn/verilog-library-barawn/
2. Obviously make sure you do a recursive clone to pick up the extra submodules.
3. Clone https://github.com/barawn/vivado_custom_ip somewhere.
4. Create a file "barawn_repository" in the project directory (the top of the github repo) containing the directory where that IP repository is.
5. Open Vivado
6. In the Tcl console, go to the cloned repository
7. Source (project name).tcl
8. After it completes without error (*), close the project.
9. Under the cloned repository directory, rename the "project name" folder to "vivado_project" (unless it already is, I can't figure out why it happens)

# UDP interface

The UDP interface mechanism is fairly straightforward. Note that all responses (either control or
event) are buffered and tagged, so recvmmsg can be used to collect multiple incoming packets at
a time if needed.

## Important note

All multibyte values here are stored little-endian because it's just pointless to keep swapping in the PC
and we can freely handle it in the FPGA. So memcpy'ing structs into uint8_t buffers should work fine.

The TURF Ethernet interface consists of a control path and an event path. From the SFC's point of view,
it should bind (listen) to 3 ports - the ports don't matter, but I will refer to them as

* control_in - port to receive control responses
* fragcontrol_in - port to receive fragment ack/nak responses
* fragment_in - port to receive fragments

Again, the specific port numbers are unimportant, as they are specified to the TURF as part of the protocol.

control_in is determined by the source port that the control requests are sent from.
fragcontrol_in is determined by the source port that the fragment ack/nak responses are sent from.
fragment_in is specified in the stream open command.

## Ports on the TURF

The TURF has 5 total open inbound ports. They are all 2-byte ASCII combinations (e.g. 0x5472 = 21618 = 'Tr').

* 'Tr' port - receives read requests
* 'Tw' port - receives write requests
* 'Tc' port - receives control requests (stream open, close, ID)
* 'Ta' port - receives fragment acks
* 'Tn' port - receives fragment nacks

In addition, a range of ports (0x5400-0x543F) are used as the source port for fragments. The ports used are
configurable - by default, only 'T0' (0x5430) is used. 

## Control path

The control path happens through two ports,  0x5472 and 0x5477. These two ports are 'Tr' and 'Tw' respectively in
2-byte ASCII. They will be referred to as the 'Tr' and 'Tw' ports. To write a value, a packet is sent to the 
'Tw' port (and an acknowledgement returned from the Tw port to the sending port) and to read a value, a packet
is sent to the 'Tr' port (and the value returned from the Tr port to the sending port).

So the basic idea is to create a local UDP socket and bind it (I recommend 'Tx' but it doesn't matter), then sendto
either Tr or Tw (depending on whether you want to read or write) and then listen for a response on the Tx port.
Writes consist solely of a 28-bit address + 4 bit tag and 32-bit data (and are responded to with the address+tag) and 
reads consist of a 28-bit address + 4 bit tag (and are responded to with a 32-bit address and data). 

Multiple read/write requests can be sent in a single packet: however, writes will only acknowledge the *first*
request (obviously all read requests will be acknowledged typically, see below). The 4-bit tag used should only 
increment between packets (all requests *in* a packet will be completed in order). Multiple reads in a single packet
should only be used when reads have no effect (see below).

Note that the 4-bit tag should change between packets, because the TURF uses this tag to guard against a lost acknowledge.
If the SFC sends "write 0x1234 to 0x0, tag 0" and the write is carried out (and responded to with "write 0x0, tag 0")
but the acknowledge is lost, the SFC would attempt to re-send that packet (again sending "write 0x1234, tag 0"). The
TURF will then recognize the duplicate packet and skip over the actual transaction, re-sending the acknowledge.

Reads have similar logic, but there is a complication here for multiple read requests.

### Multiple read requests in a single packet

For monitoring/housekeeping information, sending multiple read requests in a single packet can improve efficiency of the
network connection. However, these reads must have no other effect (for instance, reads from a FIFO keyhole which
advance the FIFO pointer should *not* be accessed with a multiple read request), and if no acknowledge is received from
a multiple read packet, the read should just be repeated with a new tag.

The reason for this is that the read request has a similar protection against lost acknowledges: if a read is received
with the same tag to the same address, the transaction is skipped, the rest of the packet is dropped,
and the acknowledge is sent *along with the last read data captured*. That is, if a packet is sent with
"read 0 tag 0, read 1 tag 0, read 2 tag 0" and then the acknowledge is sent ("read 0 tag 0 value 0x1234, read 1 tag 0
value 0x5678, read 2 tag 0 value 0x9ABC") but lost, when the original packet is repeated, the transaction
will be skipped and responded to with "read 0 tag 0 value 0x9ABC", which is obviously incorrect.

Therefore separate functions should be created for single reads (which proceed as send request with tag,
wait for response, if no response repeat send request with same tag) and multiple reads (which proceed as send
request with tag, wait for response, if no response send request with new tag).

Multiple reads are an optimization, however, and do not need to be implemented right away.

## Event path

The event path consists of 3 "incoming" ports, 'Tc', 'Ta', 'Tn', and an outgoing port 'Te'.
When the event path is opened by sending an open command to 'Tc', event fragments are sent out (after being set up, see below, and
in programmable MTU sizes) from the 'Te' port to the destination port specified by the open command.

Event fragments consist of a single 64-bit header. The reason for making the header 64-bits is just that the 
UDP datapath is 64 bits overall. 

Once an event is complete and received correctly, an ack must be sent to the 'Ta' port. If an event is *not* 
received correctly, a nack must be sent to the 'Tn' port which will retransmit the event.

Both the 'ack' and 'nack' structures are designed so the turf_fragment_header_t can be grabbed from any fragment
and used to form it. However a portion of the 'fragment' field is repurposed as a tag and other fields are ignored.

Note that if *none* of the fragments for an event are received, then the tag can be sent with the maximum event size to read out
the event (although extraneous data will be transmitted past the end).  Since most events will consist of many fragments, this is unlikely.

Once an open command is sent to 'Tc', the event path must be prepared before data is sent. To do this, tags must be sent to the
'Ta' port to "prime the pump." The tags to be sent depend on the implementation (specifically the total memory size). For instance,
if 256 MB is available for event buffering, then 256 tags must be sent to the 'Ta' port after opening. In this initialization, the "allow"
field should be **zero** for every tag except the number of events you want to allow in flight at one time (see the "Limiting number of
events in flight" section).

For structures see the TURF ICD in the DocDB.

### Lost confirmation protection

When the Ta port or Tn port receives an acknowledge, it responds to the source with the ack/nack (with only the addr/tag fields filled). 
This is a confirmation the ack/nak was received. To avoid the possibility of a *lost* confirmation, if the Ta or Tn port receive an identical
addr/tag field to the previous request, the ack/nack process will be ignored (for the nack, the event retransmission will already be taking place)
and the acknowledge will be repeated.

If an ack/nack is sent and no confirmation received, the ack/nack should be *resent* with the identical tag.

The purpose of the tag is for the nack port, in the exceedingly-unlikely case of multiple receive errors. If the first event rerequest fails and
the *next* rerequest fails, the tag ensures that the lost confirmation protection will not prevent a third event retry.

Therefore, the tag should be incremented after the confirmation is received.

Note that if multiple addresses are sent to the 'Ta' port in a packet, the confirmation contains only the address/tag of the first. Multiple addresses
sent to the 'Tn' port will be ignored (past the first).

### Example

An example of the event process would look something like this.

```
(initialization section ignored)
TURF 'T0' sends to fragment_in: frag 0 addr 0 len 446464 <8096 bytes of data>
TURF 'T0' sends to fragment_in: frag 1 addr 0 len 446464 <8096 bytes of data>
(repeat above 53 times)
TURF 'T0' sends to fragment_in: frag 55 addr 0 len 446464 <1184 bytes of data>
SFC fragcontrol_in sends to 'Ta': allow 1 tag 0 addr 0
TURF 'Ta' sends to fragcontrol_in: tag 0 addr 0
```

Obviously if a fragment is lost, the final step would be sending tag 0 addr 0 len 446464 to 'Tn', which would
repeat the process. And if the confirmation was lost, the SFC would again send tag 0 addr 0 to 'Ta'.

In addition, the next event receive attempt should end with "tag 1 addr X".

### Limiting number of events in flight

If we allowed unlimited events to be being built and sent, a problem would arise in that the process building events could find it
difficult to determine that an event is *lost* because multiple events would be coming in while it was waiting for the retransmission.
Those new incoming events also would have to wait for their acknowledgements to be sent out, otherwise the "address" ordering
would break (events must be acknowledged with the "addr" ordering that's desired for the readout).

To avoid this (the "firehose from hell" problem), no *new* events will stream out until an ack with "allow" set to 1 is sent to the 'Ta'
port (and once one event streams out, it will wait for the next 'Ta' ack, etc.).

This allows for software to set up in a mode where only *one* event is read out at a time, controlling the event flow. 

### Single event at a time

This example shows only 4 addresses filled (for brevity).

```
SFC fragcontrol_in sends to 'Ta': 
  tag 0 addr 0 allow 0
  tag 0 addr 1 allow 0
  tag 0 addr 2 allow 0
  tag 0 addr 3 allow 1
TURF 'Ta' sends to fragcontrol_in: tag 0 addr 0
  (SFC internally increments 'tag' because an ack was completed)
TURF 'T0' sends to fragment_in: frag 0 addr 0 len 446464 <8096 bytes of data>
(+remaining fragments)
```
At this point, the TURF *stops* sending data because it was allowed to send 1 event and it has sent one event. When the event builds at the
SFC, we have:
```
SFC fragcontrol_in sends to 'Ta': tag 1 addr 0 allow 1
TURF 'Ta' sends to fragcontrol_in: tag 1 addr 0
  (SFC internally increments 'tag' because an ack was completed)
(next event begins streaming)
```

### 2 events at a time (max)

This example shows only 4 addresses filled (for brevity).

```
SFC fragcontrol_in sends to 'Ta': 
  tag 0 addr 0 allow 0
  tag 0 addr 1 allow 0
  tag 0 addr 2 allow 1
  tag 0 addr 3 allow 1
TURF 'Ta' sends to fragcontrol_in: tag 0 addr 0
  (SFC internally increments 'tag' because an ack was completed)
TURF 'T0' sends to fragment_in: frag 0 addr 0 len 446464 <8096 bytes of data>
TURF 'T0' sends to fragment_in: frag 1 addr 0 len 446464 <8096 bytes of data>
(repeat above 53 times)
TURF 'T0' sends to fragment_in: frag 55 addr 0 len 446464 <1184 bytes of data>
(TURF continues to send data since 2 allowed, 1 sent)
TURF 'T0' sends to fragment_in: frag 0 addr 1 len 446464 <8096 bytes of data>
SFC fragcontrol_in sends to 'Ta': tag 1 addr 0 allow 1
TURF 'Ta' sends to fragcontrol_in: tag 1 addr 0
  (SFC internally increments 'tag' because an ack was completed)
  (TURF is now allowed to send 3, and 1 sent)
```

Note that TURF naks *always* are allowed, so in this mode if an event is missed, the event builder can
simply wait until the number of events allowed in flight have been collected (empty the pipeline), issue the
nack to get the missed event again, and then send the required acknowledges to restart the flow.

### Efficiency

Ideally the MTU will be set to a large value (8 plus a power of 2 would be smart as well, e.g. 8104) to reduce the packet overhead.
In this case the overall efficiency would be well greater than 99%. Note that if the MTU is not a multiple of 8, the next lowest
multiple of 8 will be used - for example, if 1500 is set, only 1496 bytes will be sent, for an overall efficiency of 96.5%.

Note that this requires setting the network adapter on the host side to receive jumbo frames (9018 bytes).
