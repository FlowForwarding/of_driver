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

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->    
    RestartStrategy = one_for_one,
    
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    
    Restart = permanent,
    Shutdown = 2000,
    Type = worker,
    
    %% Ch = of_driver_channel_sup,
    %% ChSup = {Ch, {Ch, start_link, []}, Restart, Shutdown, Type, [Ch]},
    
    C = of_driver_connection_sup,
    CSup = {C, {C, start_link, []}, Restart, Shutdown, Type, [C]},
    
    L = of_driver_listener,
    LChild = {L, {L, start_link, []}, Restart, Shutdown, Type, [L]},
    
    {ok, {SupFlags, [ %% ChSup,
		      CSup,
                      LChild
		    ]}
    }.
