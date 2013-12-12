-module(of_driver_acl).

-include_lib("of_driver/include/of_driver_acl.hrl").

-export([ create_table/0,
          create_table/1,
          write/1,
          write/3,
          read/1,
          delete/1,
          all/0
        ]).

create_table() ->
    ok = create_table([node()]).

create_table(NodeList) ->
    table_exists(?ACL_TBL, NodeList).

table_exists(Tbl, NodeList) ->
    try
	_Props = mnesia:table_info(Tbl,all),
	ok
    catch
	exit:{aborted,{no_exists,?ACL_TBL,all}} ->
	    {atomic,ok} = mnesia:create_table(?ACL_TBL,[{type,set},{disc_copies,NodeList},{attributes, record_info(fields, ?ACL_TBL)}]),
            ok
    end.

write(Address) ->
    write(Address, ofs_handler, []).

write(Address, SwitchHandler, Opts) when is_list(Address) ->
    case string:tokens(Address,".:") of
        [O1,O2,O3,O4]             ->
                    write({ti(O1),ti(O2),ti(O3),ti(O4)}, SwitchHandler, Opts);
        [O1,O2,O3,O4,O5,O6,O7,O8] ->
                    write({ti(O1),ti(O2),ti(O3),ti(O4),
                            ti(O5),ti(O6),ti(O7),ti(O8)}, SwitchHandler, Opts);
        _                         -> {error, einval}
    end;
write(Address, SwitchHandler, Opts) when
    is_tuple(Address) and ((size(Address) =:= 4) or (size(Address) =:= 6) ) ->
    case mnesia:dirty_read(?ACL_TBL, any) of
        [E] -> mnesia:dirty_delete(?ACL_TBL, element(2,E));
        []  -> ok
    end,
    write_valid(Address, SwitchHandler, Opts);
write(any, SwitchHandler, Opts) ->
    clear(),
    write_valid(any, SwitchHandler, Opts);
write(_,_,_) ->
    {error, einval}.

write_valid(Address, SwitchHandler, Opts) ->
    ok = mnesia:dirty_write(#?ACL_TBL{
                                ip_address = Address,
                                switch_handler = SwitchHandler,
                                opts=Opts}).

clear() ->
    {atomic,ok} = mnesia:clear_table(?ACL_TBL).

read(Address) when is_tuple(Address) ->
    case mnesia:dirty_read(?ACL_TBL,any) of
        [E] -> 
            {true, E};
        [] -> 
            case mnesia:dirty_read(?ACL_TBL, Address) of
                [E2] -> {true, E2};
                []   -> false
            end
    end.

delete(Address) when is_tuple(Address) or Address =:= any  ->
    ok = mnesia:dirty_delete(?ACL_TBL, Address).

all() ->
    {atomic, List} = mnesia:transaction(
                        fun() -> all_tbl(mnesia:first(?ACL_TBL),[]) end),
    List.

all_tbl('$end_of_table', Result) ->
    Result; %% Do we really have to reverse ?
all_tbl(Key, Result) ->
    all_tbl(mnesia:next(?ACL_TBL, Key), [mnesia:read(?ACL_TBL, Key) | Result]).

ti(V) when is_list(V) ->
    list_to_integer(V);
ti(V) when is_integer(V) ->
    V.
