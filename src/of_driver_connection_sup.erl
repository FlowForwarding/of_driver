-module(of_driver_connection_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([start_child/2
        ]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    C=of_driver_connection,
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok, {SupFlags,
          [{conn_id,{C, start_link, []},temporary, 1000, worker, [C]} 
          ]}
    }.

start_child(Socket,SwitchHandler) ->
    supervisor:start_child(?MODULE,[Socket,SwitchHandler]).
