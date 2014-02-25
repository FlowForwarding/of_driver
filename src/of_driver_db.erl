%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% OF Driver database abstraction module.
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_db).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_driver/include/of_driver.hrl").
-include_lib("of_driver/include/echo_handler_logic.hrl").

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
    [install_try_ets(Tbl, table_opt(Tbl)) || Tbl <- [?DATAPATH_TBL,
                                                     ?ECHO_HANDLER_TBL]].

install_try_ets(Tbl, TblOpts) ->
    case ets:info(Tbl) of
        undefined           -> Tbl = ets:new(Tbl, TblOpts);
        _ExistingTblOptions -> ok
    end.

table_opt(?ECHO_HANDLER_TBL) ->
    [named_table, ordered_set, {keypos, 2}, public];
table_opt(?DATAPATH_TBL) ->
    [bag, public, named_table];
table_opt(_) ->
    [ordered_set, public, named_table].

%%--- Datapath ID/Mac -----------------------------------------------------

-spec insert_connection(DatapathInfo::{DatapathId::integer(), DatapathMac::term()}, AuxId::integer(), ConnPID::pid()) -> boolean().
insert_connection(DatapathInfo, AuxId, ConnectionPid) ->
    of_driver_datapath:insert_connection(DatapathInfo, AuxId, ConnectionPid).

-spec delete_connection(DatapathInfo::{DatapathId::integer(), DatapathMac::term()}, AuxId::integer()) -> true.
delete_connection(DatapathInfo, AuxId) ->
    of_driver_datapath:delete_connection(DatapathInfo, AuxId).

-spec lookup_connection(DatapathInfo::{DatapathId::integer(), DatapathMac::term()}, AuxId::integer()) -> not_found|pid().
lookup_connection(DatapathInfo, AuxId) ->
    of_driver_datapath:lookup_connection(DatapathInfo, AuxId).
