-module(db_schema).
-include("p2p_server.hrl").
-include_lib("stdlib/include/qlc.hrl").
-export([setup/0]).


%% ===================================================================
%% API functions
%% ===================================================================

setup() ->
	mnesia:start(),
	mnesia:create_table(run_user, [{attributes, record_info(fields, run_user)}, {ram_copies, [node()]}]),

	ok.


%% ===================================================================
%% Local Functions
%% ===================================================================
