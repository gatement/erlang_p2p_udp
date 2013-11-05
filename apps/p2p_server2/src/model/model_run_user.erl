-module(model_run_user).
-include("p2p_server.hrl").
-include_lib("stdlib/include/qlc.hrl").
-export([create/1, 
	get/1, 
	get_by_pid/1, 
	delete_by_pid/1, 
	get_count/0
	]).

%% ===================================================================
%% API functions
%% ===================================================================

create(Model) ->
	Fun = fun() ->
		mnesia:write(Model)	  
	end,

	case mnesia:transaction(Fun) of
		{atomic, ok} -> Model;
		_ -> error
	end.


get(Id) ->
	Fun = fun() ->
		mnesia:read(run_user, Id)
	end,

	case mnesia:transaction(Fun) of
        {atomic, []} -> undefined;
		{atomic, [Model]} -> Model;
		_ -> error
	end.


get_by_pid(Pid) ->
	Fun = fun() -> 
		qlc:e(qlc:q([X || X <- mnesia:table(run_user), 
						  X#run_user.pid =:= Pid]))
	end,

	case mnesia:transaction(Fun) of
        {atomic, Models} -> Models;
		_ -> error
	end.


delete_by_pid(Pid) ->
	Fun = fun() ->
		Models = qlc:e(qlc:q([X || X <- mnesia:table(run_user), 
						  			X#run_user.pid =:= Pid])),
		[mnesia:delete({run_user, X#run_user.id}) || X <- Models]
	end,

	mnesia:transaction(Fun).


get_count() ->
	mnesia:table_info(run_user, size).


%% ===================================================================
%% Local Functions
%% ===================================================================
