%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% 
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_sup).
-copyright("2013, Erlang Solutions Ltd.").

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    RestartStrategy = one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    
    Restart = permanent,
    Shutdown = 2000,
    Type = worker,

    AChild = {of_driver, {of_driver, start_link, []},
	      Restart, Shutdown, Type, [of_driver]},

    {ok, {SupFlags, [AChild]}}.
