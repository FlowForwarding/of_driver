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

-module (echo_logic_sup).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/echo_handler_logic.hrl").

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).
-export([start_child/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
	?ECHO_HANDLER_TBL = ets:new(?ECHO_HANDLER_TBL, [named_table, ordered_set, {keypos, 2}, public]),
    C = echo_logic,
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok, {SupFlags,
            [{logic_id, {C, start_link, []}, temporary, 1000, worker, [C]}]}}.

start_child(DataPathId) ->
    supervisor:start_child(?MODULE, [DataPathId]).
