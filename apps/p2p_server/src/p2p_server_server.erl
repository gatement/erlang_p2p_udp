-module(p2p_server_server).
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                socket
               }).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link(?MODULE, [], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% -- init -----------
init([]) ->
    {ok, UdpPort} = application:get_env(udp_port),
    {ok, Socket} = gen_udp:open(UdpPort, [binary]),

    State = #state{
        socket = Socket
    },

    error_logger:info_msg("[~p] was started with state ~p.~n", [?MODULE, State]),
    {ok, State}.


%% -- call -----------
handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


%% -- cast ------------
handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- info -------------
handle_info({udp, _UdpSocket, _PeerIp, _PeerPort, RawData}, State) ->
    error_logger:info_msg("[~p] received udp data: ~p~n", [?MODULE, RawData]),
    %dispatch(handle_data, RawData, State);
    {noreply, State};

handle_info(_Msg, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.

%% -- terminate ---------
terminate(Reason, _State) ->
    error_logger:info_msg("[~p] was terminated with reason: ~p.~n", [?MODULE, Reason]),
    ok.

%% -- code_change -------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Local Functions
%% ===================================================================
