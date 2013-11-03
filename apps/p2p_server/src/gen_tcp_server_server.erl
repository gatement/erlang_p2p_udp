-module(gen_tcp_server_server).
-behaviour(gen_server).
%% API
-export([start_link/2]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {lsocket, 
                callback, 
                parent, 
                client_id,
                socket,
                ip, 
                port 
               }).

-define(GRACE, 10000).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(Callback, LSocket) ->
    gen_server:start_link(?MODULE, [LSocket, Callback, self()], []).


%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% -- init -------------
init([LSocket, Callback, Parent]) ->
    State = #state{
        lsocket = LSocket, 
        callback = Callback, 
        parent = Parent
    },

    %error_logger:info_msg("[~p] was started.~n", [?MODULE]),
    {ok, State, 0}.


%% -- call -------------
handle_call(_Msg, _From, State) ->
    error_logger:info_msg("[~p] was called: ~p.~n", [?MODULE, _Msg]),
    {reply, ok, State}.


%% -- cast -------------
handle_cast({send_tcp_data, Data}, State) ->
    error_logger:info_msg("[~p] send tcp data: ~p.~n", [?MODULE, Data]),
    gen_tcp:send(State#state.socket, Data),
    {noreply, State};

handle_cast(_Msg, State) ->
    error_logger:info_msg("[~P] was casted: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- info ------------
handle_info({tcp, _Socket, RawData}, State) ->
    error_logger:info_msg("[~p] received tcp data: ~p~n", [?MODULE, RawData]),
    dispatch(handle_data, RawData, State);

handle_info({tcp_closed, _Socket}, State) ->
    %error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, tcp_closed]),
    {stop, tcp_closed, State};

handle_info(timeout, #state{lsocket=LSocket, socket=Socket0, parent=Parent} = State) ->    
    case Socket0 of
        undefined ->
            {ok, Socket} = gen_tcp:accept(LSocket),
            gen_tcp_server_connection_sup:start_child(Parent),

            %% log
            {ok, {Address, Port}} = inet:peername(Socket),
            {ok, ConnectionTimeout} = application:get_env(connection_timout),
            error_logger:info_msg("[~p] connected(~p) ~p:~p~n", [?MODULE, Socket, Address, Port]),
            {noreply, State#state{socket=Socket, ip=Address, port=Port}, ConnectionTimeout}; %% this socket must receive the first message in Timeout seconds
        Socket ->
            %% no first package comming yet
            Ip = State#state.ip,
            Port = State#state.port,
            {ok, ConnectionTimeout} = application:get_env(connection_timout),
            error_logger:info_msg("[~p] disconnected ~p ~p:~p because of the first message doesn't arrive in ~p milliseconds.~n", [?MODULE, Socket, Ip, Port, ConnectionTimeout]),
            {stop, connection_timout, State} %% no message arrived in time so suicide
    end;
    
handle_info(_Msg, State) ->
    error_logger:info_msg("[~p] was infoed: ~p.~n", [?MODULE, _Msg]),
    {noreply, State}.


%% -- terminate ------------
terminate(Reason, State) ->
    %error_logger:info_msg("[~p] ~p was terminated with reason: ~p.~n", [?MODULE, State#state.socket, Reason]),
    dispatch(terminate, State, Reason),
    ok.


%% -- code_change ----------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% ===================================================================
%% Local Functions
%% ===================================================================

dispatch(handle_data, RawData, State) ->
    ClientId = case State#state.client_id of
        undefined ->
            extract_client_id(RawData);
        _ ->
            State#state.client_id 
    end,

    case ClientId of
        error ->
            {stop, online_err, State};
        _ ->
            handle_recved_packages(State#state{client_id=ClientId}, RawData)
    end;

dispatch(terminate, State, Reason) ->
    #state{callback=Callback, socket=Socket, client_id=ClientId} = State,
    Callback:terminate(erlang:self(), Socket, ClientId, Reason),
    ok.


handle_recved_packages(State, <<>>) ->
    {noreply, State};

handle_recved_packages(State, RawData) ->
    #state{
        socket = Socket,
        callback = Callback, 
        client_id = ClientId,
        ip = Ip} = State,

    <<TypeCode:1/binary, DataLen:8/integer, _/binary>> = RawData,
    Payload = binary:part(RawData, 2, DataLen), 

    Result = case TypeCode of
        %% -- online req --------
        <<16#01>> -> 
            Callback:process_data_online(erlang:self(), Socket, ClientId),
            ok;

        %% -- connect1 ----------
        <<16#02>> -> 
            Callback:process_data_connect_to_peer_req(Socket, Payload, ClientId, Ip),
            ok;

        %% -- connect3 ----------
        <<16#04>> -> 
            Callback:process_data_connect_to_peer_res(Socket, Payload, ClientId, Ip),
            ok
    end,

    case Result of
        disconnect ->
            {stop, disconnected, State};

        ok ->
            RestRawData = binary:part(RawData, 2 + DataLen, erlang:byte_size(RawData) - 2 - DataLen),
            handle_recved_packages(State, RestRawData)
    end.

extract_client_id(RawData) ->
    <<TypeCode:1/binary, DataLen:8/integer, _/binary>> = RawData,
    ClientId = case TypeCode of
        <<16#01>> -> 
            erlang:binary_to_list(binary:part(RawData, 2, DataLen));
        _ ->
            error
    end,

    ClientId.
