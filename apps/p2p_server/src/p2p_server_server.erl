-module(p2p_server_server).
%% API
-export([start_link/0]).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    {ok, Port} = application:get_env(tcp_port),
    error_logger:info_msg("starting [~p] at port: ~p~n", [?MODULE, Port]),
    gen_tcp_server:start_link(p2p_server, p2p_server_handler, Port).


%% ===================================================================
%% Local Functions
%% ===================================================================
