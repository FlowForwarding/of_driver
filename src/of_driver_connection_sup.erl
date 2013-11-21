-module(of_driver_connection_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([start_child/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    RestartStrategy = one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok,{SupFlags,[]}}.

start_child(Socket) ->
    C=of_driver_connection,
    Restart = temporary,
    Shutdown = 200,
    Type = worker,
    supervisor:start_child(?MODULE,{C, {C, start, [Socket]}, Restart, Shutdown, Type, [C]}).
