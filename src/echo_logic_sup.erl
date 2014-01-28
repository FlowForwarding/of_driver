-module (echo_logic_sup).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/echo_handler_logic.hrl").

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).
-export([start_child/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
	?ECHO_HANDLER_TBL = ets:new(?ECHO_HANDLER_TBL, [named_table, ordered_set, {keypos, 2}, public]),
    C = echo_logic,
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok, {SupFlags,
            [{logic_id, {C, start_link, []}, temporary, 1000, worker, [C]}]}}.

start_child(DataPathId) ->
    supervisor:start_child(?MODULE, [DataPathId]).
