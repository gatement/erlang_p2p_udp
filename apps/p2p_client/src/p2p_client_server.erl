-module(p2p_client_server).
-behaviour(gen_server).
%% API
-export([start_link/0]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {
                client_id,
                keep_alive_timer,
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

init([]) ->
    {ok, KeepAliveTimer} = application:get_env(keep_alive_timer),
    State = #state{
        keep_alive_timer = KeepAliveTimer
    },

    error_logger:info_msg("[~p] was started.~n", [?MODULE]),
    {ok, State, 0}.


handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


handle_cast(_Msg, State) ->
    %error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


handle_info({tcp, _Socket, RawData}, State) ->
    %error_logger:info_msg("[~p] received tcp data: ~p~n", [?MODULE, RawData]),
    dispatch(handle_data, RawData, State);

handle_info({tcp_closed, _Socket}, State) ->
    %error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {stop, tcp_closed, State};

handle_info(timeout, #state{socket = Socket0} = State) ->    
    case Socket0 of
        undefined ->
            do_nothing;
        Socket ->
            do_heardbeat
    end;

handle_info({send_tcp_data, Data}, #state{socket = Socket} = State) ->
    %error_logger:info_msg("[~p] send to socket ~p with data: ~p~n", [?MODULE, Socket, Data]),
    gen_tcp:send(Socket, Data),
    {noreply, State, State#state.keep_alive_timer};

handle_info({stop, Reason}, State) ->
    %error_logger:info_msg("[~p] process ~p was stopped: ~p~n", [?MODULE, erlang:self(), Reason]),
    {stop, Reason, State};
    
handle_info(_Msg, State) ->
    %error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, _Msg]),
    {noreply, State, State#state.keep_alive_timer}.


terminate(Reason, State) ->
    %error_logger:info_msg("[~p] ~p was terminated with reason: ~p.~n", [?MODULE, State#state.socket, Reason]),
    dispatch(terminate, State, Reason),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Local Functions
%% ===================================================================

dispatch(handle_data, RawData, State) ->
    handle_packages(State#state{client_id = ClientId}, RawData);

dispatch(terminate, State, Reason) ->
    #state{callback = Callback, socket = Socket, client_id = ClientId} = State,
    Callback:terminate(erlang:self(), Socket, ClientId, Reason),
    ok.


handle_packages(State, <<>>) ->
    {noreply, State, State#state.keep_alive_timer};

handle_packages(State, RawData) ->
    #state{
        socket = Socket, 
        callback = Callback, 
        client_id = ClientId} = State,

    <<TypeCode:1/binary, DataLen:16/integer, _/binary>> = RawData,
    PackData = binary:part(RawData, 3, DataLen), 

    Result = case TypeCode of
        <<16#01>> -> 
            Callback:process_data_online(erlang:self(), Socket, PackData, ClientId),
            ok;

        <<16#02>> -> 
            Callback:process_data_offline(erlang:self(), Socket, PackData, ClientId),
            disconnect;

        <<16#03>> -> 
            Callback:process_data_publish(erlang:self(), Socket, PackData, ClientId),
            ok;

        <<16#04>> -> 
            error_logger:info_msg("[~p] is pingging (~p)~n", [ClientId, erlang:self()]),
            gen_tcp:send(Socket, <<16#03, 16#02>>),
            ok
    end,

    case Result of
        disconnect ->
            {stop, disconnected, State};

        ok ->
            RestRawData = binary:part(RawData, 3 + DataLen, erlang:byte_size(RawData) - 3 - DataLen),
            handle_packages(State, RestRawData)
    end.

