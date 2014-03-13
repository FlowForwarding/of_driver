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

-module (of_driver_datapath).

-include_lib("of_driver/include/of_driver.hrl").

-export([
    insert_connection/3,
    delete_connection/2,
    lookup_connection/2
]).

% @doc
-spec insert_connection(DatapathInfo::{DatapathId::integer(), DatapathMac::term()}, AuxId::integer(), ConnPID::pid()) -> boolean().
insert_connection(DatapathInfo, AuxId, ConnPID) ->
    ets:insert_new(?DATAPATH_TBL, {{DatapathInfo, AuxId}, ConnPID}).

% @doc
-spec delete_connection(DatapathInfo::{DatapathId::integer(), DatapathMac::term()}, AuxId::integer()) -> boolean().
delete_connection(DatapathInfo, AuxId) ->
    ets:delete(?DATAPATH_TBL, {DatapathInfo, AuxId}).

% @doc
-spec lookup_connection(DatapathInfo::{DatapathId::integer(), DatapathMac::term()}, AuxId::integer()) -> not_found|pid().
lookup_connection(DatapathInfo, AuxId) ->
    case ets:lookup(?DATAPATH_TBL, {DatapathInfo, AuxId}) of
        [] -> not_found;
        [{_, ConnectionPid}] -> ConnectionPid
    end.
