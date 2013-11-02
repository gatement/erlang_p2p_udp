-module(p2p_client_handler).
-export([terminate/4]).


%% ===================================================================
%% API functions
%% ===================================================================

terminate(_SourcePid, _Socket, ClientId, Reason) ->
    error_logger:info_msg("[~p] process_data_terminate(~p): ~p~n", [?MODULE, ClientId, Reason]).


%% ===================================================================
%% Local Functions
%% ===================================================================

