-module(of_driver_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    %% RestartStrategy = simple_one_for_one,
    RestartStrategy = one_for_one,
    
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    
    Restart = permanent,
    Shutdown = 2000,
    Type = worker,
    
    Ch = of_driver_channel_sup,
    ChSup = {Ch, {Ch, start_link, []}, Restart, Shutdown, Type, [Ch]},
    
    C = of_driver_connection_sup,
    CSup = {C, {C, start_link, []}, Restart, Shutdown, Type, [C]},
    
    L = of_driver_listener,
    LChild = {L, {L, start_link, []}, Restart, Shutdown, Type, [L]}, %%change child spec,
    
    {ok, {SupFlags, [ ChSup,
		      CSup,
                      LChild
		    ]}
    }.
