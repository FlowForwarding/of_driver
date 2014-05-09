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

-module(of_driver_db).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/of_driver.hrl").

%% DB API to seperate DB infrastructure from LOOM.

-export([ install/0
        ]).
-export([ insert_connection/3,
          delete_connection/2,
          lookup_connection/2
        ]).

%%--- Provisioning -----------------------------------------------------------

install() ->
    try
	install_try()
    catch
	C:E ->
	    io:format("... [~p] Install failed. ~p.\n...Reason:~p...\n...Stacktrace:~p...\n",
        [?MODULE,C,E,erlang:get_stacktrace()]),
	    ok
    end.

install_try() ->
    [install_try_ets(Tbl, table_opt(Tbl)) || Tbl <- [?DATAPATH_TBL]].

install_try_ets(Tbl, TblOpts) ->
    case ets:info(Tbl) of
        undefined           -> Tbl = ets:new(Tbl, TblOpts);
        _ExistingTblOptions -> ok
    end.

table_opt(?DATAPATH_TBL) ->
    [bag, public, named_table];
table_opt(_) ->
    [ordered_set, public, named_table].

%%--- Datapath ID/Mac -----------------------------------------------------

-spec insert_connection(DatapathMac::term(), AuxId::term(), ConnPID::pid()) -> boolean().
insert_connection(DatapathMac, AuxId, ConnectionPid) ->
    of_driver_datapath:insert_connection(DatapathMac, AuxId, ConnectionPid).

-spec delete_connection(DatapathMac::term(), AuxId :: term()) -> true.
delete_connection(DatapathMac, AuxId) ->
    of_driver_datapath:delete_connection(DatapathMac, AuxId).

-spec lookup_connection(DatapathMac::term(), AuxId :: term()) -> not_found|pid().
lookup_connection(DatapathMac, AuxId) ->
    of_driver_datapath:lookup_connection(DatapathMac, AuxId).
