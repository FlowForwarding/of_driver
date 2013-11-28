-module(of_driver_acl_tests).

-include_lib("eunit/include/eunit.hrl").

of_driver_acl_test_() ->
    {setup,
     fun() -> 
             application:stop(mnesia),
             mnesia:delete_schema([node()]),
             mnesia:create_schema([node()]),
             application:start(mnesia),
             
             try
                 mnesia:table_info(of_driver_acl_white,all),
                 {atomic,ok}=mnesia:delete_table(of_driver_acl_white)
             catch
                 _C:_E ->
                     ok
             end,
             try
                 mnesia:table_info(of_driver_acl_black,all),
                 {atomic,ok}=mnesia:delete_table(of_driver_acl_black)
             catch
                 _C1:_E2 ->
                     ok
             end,
             of_driver_acl:create_table([node()])
     end,
     fun(_) -> 
             ok
     end,
     {inorder,[ {"write",        fun write/0},
                {"read any",     fun read_any/0},
                {"read specific",fun read_specific/0},
                {"add any",      fun add_any/0},
                {"add specific", fun add_specific/0},
                {"allowed",      fun allowed/0}
              ]}}.

write() ->
    delete_entries(),
    ok = of_driver_acl:write(any,white),
    ok = of_driver_acl:write(any,black),
    
    ?assertEqual([{of_driver_acl_white,any,undefined}],
                 mnesia:dirty_read(of_driver_acl_white,any)),
    ?assertEqual([{of_driver_acl_black,any,undefined}],
                 mnesia:dirty_read(of_driver_acl_black,any)),
    
    ok = of_driver_acl:write({0,0,0,0},white),
    ok = of_driver_acl:write({10,10,10,10},black),
    ok = of_driver_acl:write("123.123.123.123",white),
    ok = of_driver_acl:write("33.33.33.33",black),
    
    ?assertEqual([{of_driver_acl_white,{0,0,0,0},undefined}],
                 mnesia:dirty_read(of_driver_acl_white,{0,0,0,0})),
    ?assertEqual([{of_driver_acl_black,{10,10,10,10},undefined}],
                 mnesia:dirty_read(of_driver_acl_black,{10,10,10,10})),
    
    ?assertEqual([{of_driver_acl_white,{123,123,123,123},undefined}],
                 mnesia:dirty_read(of_driver_acl_white,{123,123,123,123})
                ),
    ?assertEqual([{of_driver_acl_black,{33,33,33,33},undefined}],
                 mnesia:dirty_read(of_driver_acl_black,{33,33,33,33})).

read_any() ->
    delete_entries(),
    ok = of_driver_acl:write(any,white),
    ok = of_driver_acl:write(any,black),
    
    ?assertEqual(true,of_driver_acl:read({0,0,0,0},white)),
    ?assertEqual(true,of_driver_acl:read({0,0,0,0},black)).

read_specific() ->
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},white),
    ok = of_driver_acl:write({1,1,1,1},black),
    
    ?assertEqual(true,of_driver_acl:read({10,10,10,10},white)),
    ?assertEqual(true,of_driver_acl:read({1,1,1,1},black)),
    
    ?assertEqual(false,of_driver_acl:read({102,103,104,105},white)),
    ?assertEqual(false,of_driver_acl:read({12,13,14,15},black)).

add_any() ->
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},white),
    ok = of_driver_acl:write({1,1,1,1},black),
    
    ?assertEqual(true,of_driver_acl:read({10,10,10,10},white)),
    ?assertEqual(true,of_driver_acl:read({1,1,1,1},black)),
    
    ok = of_driver_acl:write(any,white),
    ok = of_driver_acl:write(any,black),
    
    ?assertEqual([any],mnesia:dirty_all_keys(of_driver_acl_white)),
    ?assertEqual([any],mnesia:dirty_all_keys(of_driver_acl_black)).
    
add_specific() ->
    delete_entries(),
    
    ok = of_driver_acl:write(any,white),
    ok = of_driver_acl:write(any,black),
    
    ?assertEqual([any],mnesia:dirty_all_keys(of_driver_acl_white)),
    ?assertEqual([any],mnesia:dirty_all_keys(of_driver_acl_black)),
    

    ok = of_driver_acl:write({10,10,10,10},white),
    ok = of_driver_acl:write({1,1,1,1},black),
    
    ok = of_driver_acl:write("123.123.123.123",white),
    ok = of_driver_acl:write("33.33.33.33",black),
    
    ?assertEqual([{of_driver_acl_white,{10,10,10,10},undefined}],mnesia:dirty_read(of_driver_acl_white,{10,10,10,10})),
    ?assertEqual([{of_driver_acl_black,{1,1,1,1},undefined}],mnesia:dirty_read(of_driver_acl_black,{1,1,1,1})),
    ?assertEqual([{of_driver_acl_white,{123,123,123,123},undefined}],mnesia:dirty_read(of_driver_acl_white,{123,123,123,123})),
    ?assertEqual([{of_driver_acl_black,{33,33,33,33},undefined}],mnesia:dirty_read(of_driver_acl_black,{33,33,33,33})).
    
allowed() ->
    delete_entries(),
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    
    delete_entries(),
    ok = of_driver_acl:write(any,white),
    ?assertEqual(true,of_driver_db:allowed({0,0,0,0})),
    ok = of_driver_acl:write(any,black),
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},white),
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    ?assertEqual(true,of_driver_db:allowed({10,10,10,10})),
    
    ok = of_driver_acl:write({1,1,1,1},black),
    ?assertEqual(false,of_driver_db:allowed({1,1,1,1})),
    
    ok = of_driver_acl:write({10,10,10,10},black),
    ?assertEqual(false,of_driver_db:allowed({10,10,10,10})).

    delete_entries() ->
    [ begin 
          [ mnesia:dirty_delete(Tbl,Key) || Key <- mnesia:dirty_all_keys(Tbl) ]
      end || Tbl <- [of_driver_acl_white,of_driver_acl_black] 
    ].
