%%------------------------------------------------------------------------------
%% Copyright 2014 FlowForwarding.org
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%-----------------------------------------------------------------------------

%% @author Erlang Solutions Ltd. <openflow@erlang-solutions.com>
%% @copyright 2014 FlowForwarding.org

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
