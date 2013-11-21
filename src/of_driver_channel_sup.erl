-module(of_driver_channel_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([create/0]).

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
    
    %% Start N amount channles.....
    %% Ch=of_driver_channel,
    %% ChChild = {Ch, {Ch, start_link, []}, Restart, Shutdown, Type, [Ch]},
    %% {ok, {SupFlags, [ChChild]}}.
    {ok,{SupFlags,[]}}.

create() ->
    ok.

