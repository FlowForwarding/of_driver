-module(of_driver_acl).

-define(WHITE,of_driver_acl_white).
-define(BLACK,of_driver_acl_black).
-define(COLS,{key :: atom() | inet:ip4_address() | inet:ip6_address(),
              val :: any()
             }).

-record(?WHITE,?COLS).
-record(?BLACK,?COLS).

-export([create_table/0,
         create_table/1,
         write/2,
         read/2,
         delete/2
        ]).

create_table() ->
    ok=create_table([node()]),
    write(any,white).

create_table(NodeList) ->
    {atomic,ok} = mnesia:create_table(?WHITE,[{type,set},{disc_copies,NodeList},{attributes, record_info(fields, ?WHITE)}]),                  
    {atomic,ok} = mnesia:create_table(?BLACK,[{type,set},{disc_copies,NodeList},{attributes, record_info(fields, ?BLACK)}]).

write(Address,Tbl) when is_list(Address) ->
    case string:tokens(Address,".:") of
        [O1,O2,O3,O4]             -> write({ti(O1),ti(O2),ti(O3),ti(O4)},Tbl);
        [O1,O2,O3,O4,O5,O6,O7,O8] -> write({ti(O1),ti(O2),ti(O3),ti(O4),ti(O5),ti(O6),ti(O7),ti(O8)},Tbl);
        _                         -> {error, einval}
    end;
write(Address,Tbl) when is_tuple(Address) and ( (size(Address) =:= 4) or (size(Address) =:= 6) ) ->
    TblName=tbl_name(Tbl),
    case mnesia:dirty_read(TblName,any) of
        [E] -> mnesia:dirty_delete(TblName,element(2,E));
        []  -> ok
    end,
    write_valid(Address,Tbl);
write(any,Tbl) ->
    clear(Tbl),
    write_valid(any,Tbl);
write(_,_) ->
    {error,invalid_address}.

write_valid(Address,white) ->
    mnesia:dirty_write(#?WHITE{key=Address});
write_valid(Address,black) ->
    mnesia:dirty_write(#?BLACK{key=Address}).

clear(white) -> {atomic,ok} = mnesia:clear_table(?WHITE);
clear(black) -> {atomic,ok} = mnesia:clear_table(?BLACK).

tbl_name(white) -> ?WHITE;
tbl_name(black) -> ?BLACK.

read(Address,white) ->
    check_tbl(?WHITE,Address);
read(Address,black) ->
    check_tbl(?BLACK,Address).

delete(Address,white) ->
    mnesia:dirty_delete(?WHITE,Address);
delete(Address,black) ->
    mnesia:dirty_delete(?BLACK,Address).

check_tbl(Tbl,Address) ->
    case mnesia:dirty_read(Tbl,any) of
        [_] -> true;
        []  -> table_scan(Tbl,mnesia:dirty_first(Tbl),Address)
    end.

table_scan(_,'$end_of_table',_) ->
    false;
table_scan(_Tbl,Key,Address) when Key =:= Address ->
    true;
table_scan(Tbl,Key,Address) ->
    table_scan(Tbl,mnesia:dirty_next(Tbl,Key),Address).    

ti(V) when is_list(V) ->
    list_to_integer(V);
ti(V) when is_integer(V) ->
    V.
