erlang-p2p
==========

UDP base peer to peer communication.

## Compile

   run "./rebar get-deps & ./rebar co"

## Example files

   cli.config.example

   cli.example

   ser.config.example

   ser.example

## Usage

   1) open server via run "./ser" (configure file is "./ser.config")

   2) on peer1 machine, run "./cli" (configure file is "./cli.config")

      p2p_client:online("Peer1Name").
      
   3) on peer2 machine, run "./cli"

      p2p_client:online("Peer2Name").

      p2p_client:connect_to_peer("Peer1Name").

   4) happy to send msg via the p2p channel

      p2p_client:send_msg("Msg").
