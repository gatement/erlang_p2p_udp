-module(model_run_user).
-include("p2p_server.hrl").
-include_lib("stdlib/include/qlc.hrl").
-export([
    create/1, 
	get/1, 
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


get_count() ->
	mnesia:table_info(run_user, size).


%% ===================================================================
%% Local Functions
%% ===================================================================
