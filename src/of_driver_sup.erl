-module(of_driver_sup).

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
    
    L = of_driver_listener,
    LChild = {L, {L, start_link, []}, Restart, Shutdown, Type, [L]},
    
    Ch = of_driver_channel,
    ChSup = {Ch, {Ch, start_link, []}, Restart, Shutdown, Type, [Ch]},
    
    C = of_driver_connection,
    CSup = {C, {C, start_link, []}, Restart, Shutdown, Type, [C]},
    
    {ok, {SupFlags, [ LChild,
		      ChSup,
		      CSup
		    ]}
    }.
