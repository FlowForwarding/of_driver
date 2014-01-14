-module (of_driver_datapath).

-include_lib("of_driver/include/of_driver.hrl").
-include_lib("of_driver/include/of_driver_acl.hrl").

-export([
	insert_datapath_id/2,
	remove_datapath_id/1,
	remove_datapath_aux_id/2,
	remove_aux_id/3,
	add_aux_id/3,
	lookup_datapath_id/1
]).

-spec insert_datapath_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, ConnPID :: pid()) -> boolean().
% @doc
insert_datapath_id(DatapathInfo, ConnPID) ->
    ets:insert_new(?DATAPATH_TBL,                          
                    {DatapathInfo, [{main,ConnPID}]}
                  ).

-spec remove_datapath_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> boolean().
% @doc
remove_datapath_id(DatapathInfo) ->
    ets:delete(?DATAPATH_TBL, DatapathInfo).

-spec remove_datapath_aux_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }, AuxID :: integer()) -> boolean().
% @doc
remove_datapath_aux_id(DatapathInfo, AuxID) ->
    case lookup_datapath_id(DatapathInfo) of
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
        
-spec lookup_datapath_id(DatapathInfo :: { DatapathId :: integer(), DatapathMac :: term() }) -> list().
% @doc
lookup_datapath_id(DatapathInfo) ->
    ets:lookup(?DATAPATH_TBL,DatapathInfo).
