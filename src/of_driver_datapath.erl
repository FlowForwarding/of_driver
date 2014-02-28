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
-include_lib("of_driver/include/of_driver_acl.hrl").

-export([
	insert_datapath_info/2,
	remove_datapath_info/1,
	remove_datapath_aux_id/2,
	remove_aux_id/3,
	add_aux_id/3,
	lookup_datapath_info/1,
    lookup_datapath_id/1
]).

-spec insert_datapath_info(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, ConnPID :: pid()) -> boolean().
% @doc
insert_datapath_info(DatapathInfo, ConnPID) ->
    ets:insert_new(?DATAPATH_TBL,                          
                    {DatapathInfo, [{main,ConnPID}]}
                  ).

-spec remove_datapath_info(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> boolean().
% @doc
remove_datapath_info(DatapathInfo) ->
    ets:delete(?DATAPATH_TBL, DatapathInfo).

-spec remove_datapath_aux_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
% @doc
remove_datapath_aux_id(DatapathInfo, AuxID) ->
    case lookup_datapath_info(DatapathInfo) of
        []      -> false;
        [Entry] -> remove_aux_id(Entry,DatapathInfo, AuxID)
    end.

-spec remove_aux_id(Entry :: tuple(), DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
% @doc
remove_aux_id(Entry,DatapathInfo, AuxID) ->
    Pos=2,
    CurrentAuxs = element(Pos,Entry),
    Updated=lists:keydelete(AuxID,1,CurrentAuxs),
    ets:update_element(?DATAPATH_TBL, DatapathInfo, [{Pos,Updated}]).

-spec add_aux_id(Entry :: tuple(), DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
% @doc
add_aux_id(Entry,DatapathInfo, Aux) ->
    Pos=2,
    CurrentAuxs = element(Pos, Entry),
    Updated=[Aux | CurrentAuxs],
    ets:update_element(?DATAPATH_TBL, DatapathInfo, [{Pos, Updated}]).
        
-spec lookup_datapath_info(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> list().
% @doc
lookup_datapath_info(DatapathInfo) ->
    ets:lookup(?DATAPATH_TBL,DatapathInfo).

lookup_datapath_id(DatapathId) when is_integer(DatapathId) ->
    case ets:match(?DATAPATH_TBL,{{DatapathId,'$1'},'$2'}) of 
        []                          -> [];
        [[DatapathMac,Connections]] -> [DatapathMac,Connections]
    end.
