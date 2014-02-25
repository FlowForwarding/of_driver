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
