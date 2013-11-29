-module(of_driver_channel_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([start_child/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    C=of_driver_channel,
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok, {SupFlags,
          [{channel_id,{C, start_link, []},temporary, 1000, worker, [C]} 
          ]}
    }.

start_child(Socket) ->
    supervisor:start_child(?MODULE,[Socket]).
