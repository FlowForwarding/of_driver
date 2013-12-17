%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% 
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_channel_sup).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([start_child/1
        ]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    C = of_driver_channel,
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok, {SupFlags,
          [{channel_id,{C, start_link, []},temporary, 1000, worker, [C]} 
          ]}
    }.

start_child(DatapathId) ->
    supervisor:start_child(?MODULE, [DatapathId]).
