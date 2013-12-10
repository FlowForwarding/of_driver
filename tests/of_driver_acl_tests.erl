-module(of_driver_acl_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("of_driver/include/of_driver_acl.hrl").

of_driver_acl_test_() ->
    {setup,
     fun() -> 
             application:stop(mnesia),
             mnesia:delete_schema([node()]),
             mnesia:create_schema([node()]),
             application:start(mnesia),
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
    ok = of_driver_acl:write(any,'switch_handler',[]),
    
    ?assertEqual([{?ACL_TBL,any,switch_handler,[]}], 
                 mnesia:dirty_read(any)),
    
    ok = of_driver_acl:write({0,0,0,0},'switch_handler',[]),
    ok = of_driver_acl:write("123.123.123.123",'switch_handler',[]),
    
    ?assertEqual([{?ACL_TBL,{0,0,0,0},switch_handler,[]}],
                 mnesia:dirty_read(?ACL_TBL,{0,0,0,0})),
    
    ?assertEqual([{?ACL_TBL,{123,123,123,123},switch_handler,[]}],
                 mnesia:dirty_read(?ACL_TBL,{123,123,123,123})
                ).

read_any() ->
    delete_entries(),
    ok = of_driver_acl:write(any,'switch_handler',[]),
    
    ?assertEqual(true,
                 of_driver_acl:read({0,0,0,0})),
    ?assertEqual(true,
                 of_driver_acl:read({10,20,30,40})),
    ?assertEqual(true,
                 of_driver_acl:read({110,110,110,110})).
    

read_specific() ->
    delete_entries(),
    
    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    
    ?assertEqual(true,
                 of_driver_acl:read({10,10,10,10})),
    ?assertEqual(false,
                 of_driver_acl:read({102,103,104,105})).

add_any() ->
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    
    ?assertEqual(true,
                 of_driver_acl:read({10,10,10,10})),
    
    ok = of_driver_acl:write(any,'switch_handler',[]),
    
    ?assertEqual([any],
                 mnesia:dirty_all_keys(?ACL_TBL)),
    
    ?assertEqual(true,
                 of_driver_acl:read({10,10,10,10})).
    
add_specific() ->
    delete_entries(),
    
    ok = of_driver_acl:write(any,'switch_handler',[]),    
    ?assertEqual([any],
                 mnesia:dirty_all_keys(?ACL_TBL)),

    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    
    ok = of_driver_acl:write("123.123.123.123",'switch_handler',[]),
    
    ?assertEqual([{?ACL_TBL,{10,10,10,10},switch_handler,[]}],
                 mnesia:dirty_read({10,10,10,10})),
    ?assertEqual([{?ACL_TBL,{123,123,123,123},switch_handler,[]}],
                 mnesia:dirty_read({123,123,123,123})),

    ?assertEqual(true,
                 of_driver_acl:read({10,10,10,10})),
    ?assertEqual(true,
                 of_driver_acl:read({123,123,123,123})).
    
allowed() ->
    delete_entries(),
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    
    delete_entries(),
    ok = of_driver_acl:write(any,'switch_handler',[]),
    ?assertEqual(true,of_driver_db:allowed({0,0,0,0})),
    
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    ?assertEqual(true,of_driver_db:allowed({10,10,10,10})).

delete_entries() ->
    [ begin 
          [ mnesia:dirty_delete(Tbl,Key) || Key <- mnesia:dirty_all_keys(Tbl) ]
      end || Tbl <- [?ACL_TBL]
    ].
