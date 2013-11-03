erlang-p2p
==========

1. Diagram

                   Server
                    / \
                   /   \
                  /     \
                 /       \
                /         \ 
              TCP         TCP
              /             \
             /               \
            /                 \
           /                   \
          /                     \
       Peer1 <------UDP------> Peer2


2. Protocal
   *. online req (peer -> server): 0x01(prefix), 1B(left len), MyPeerId
   *. online res (server -> peer): 0x01(prefix), 0x01(left len), 0x00(success) | 0x01(fail)
   *. connect 1 (peer1 -> server): 0x02(prefix), 1B(left len), PortH, PortL, TargetPeerId
   *. connect 2 (server -> peer2): 0x03(prefix), 1B(left len), PeerIp1, PeerIp2, PeerIp3, PeerIp4, PortH, PortL, FromPeerId
   *. connect 3 (peer2 -> server): 0x04(perfix), 1B(left len), PortH, PortL, FromPeerId
   *. connect 4 (server -> peer1):
                          success: 0x05(prefix), 0x06(left len), 0x00, PeerIp1, PeerIp2, PeerIp3, PeerIp4, PortH, PortL, TargetPeerId
                             fail: 0x05(prefix), 0x01(left len), 0x01
   *. ping (peer1 <-> peer2)     : 0x06(prefix), 0x01(left len), 0x00 
   *. udp data (peer1 <-> peer2) : 0x07(prefix), 1B(left len), Data


3. Compile
   run "./rebar co"


4. Usage
   1) open server via run "./ser" (configure file is "./local_ser.config")
   2) on peer1 machine, run "./cli" (configure file is "./local_cli.config")
      then "p2p_client:online("Peer1Name")."
   3) on peer2 machine, run "./cli"
      then "p2p_client:online("Peer2Name")."
      then "p2p_client:connect_to_peer("Peer1Name")."
   4) happy to send msg via the p2p channel
      "p2p_client:send_msg("Msg")."

