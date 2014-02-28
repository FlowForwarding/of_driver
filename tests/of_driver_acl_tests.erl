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

-module(of_driver_acl_tests).
-copyright("2013, Erlang Solutions Ltd.").

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
    Rec0 = #?ACL_TBL{ip_address = any,switch_handler = 'switch_handler', opts = []},
    ?assertEqual([Rec0],
                 mnesia:dirty_read(?ACL_TBL,any)),
    ok = of_driver_acl:write({0,0,0,0},'switch_handler',[]),
    ok = of_driver_acl:write("123.123.123.123",'switch_handler',[]),
    Rec1 = #?ACL_TBL{ip_address = {0,0,0,0},switch_handler = 'switch_handler', opts = []},
    ?assertEqual([Rec1],
                 mnesia:dirty_read(?ACL_TBL,{0,0,0,0})),
    Rec2 = #?ACL_TBL{ip_address = {123,123,123,123},switch_handler = 'switch_handler', opts = []},
    ?assertEqual([Rec2],
                 mnesia:dirty_read(?ACL_TBL,{123,123,123,123})
                ).

read_any() ->
    delete_entries(),
    ok = of_driver_acl:write(any,'switch_handler',[]),
    AclEntry0 = #?ACL_TBL{ip_address = any, switch_handler = 'switch_handler', opts=[]},
    ?assertEqual({true,AclEntry0},
                 of_driver_acl:read({0,0,0,0})),
    ?assertEqual({true,AclEntry0},
                 of_driver_acl:read({10,20,30,40})),
    ?assertEqual({true,AclEntry0},
                 of_driver_acl:read({110,110,110,110})).


read_specific() ->
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    AclEntry0 = #?ACL_TBL{ip_address={10,10,10,10}, switch_handler = 'switch_handler', opts=[]},
    ?assertEqual({true,AclEntry0},
                 of_driver_acl:read({10,10,10,10})),
    ?assertEqual(false,
                 of_driver_acl:read({102,103,104,105})).

add_any() ->
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    AclEntry0 = #?ACL_TBL{ip_address={10,10,10,10},switch_handler = 'switch_handler', opts=[]},
    ?assertEqual({true,AclEntry0},
                 of_driver_acl:read({10,10,10,10})),
    
    ok = of_driver_acl:write(any,'switch_handler',[]),
    AclEntry1 = #?ACL_TBL{ip_address=any,switch_handler = 'switch_handler', opts=[]},
    ?assertEqual([any],
                 mnesia:dirty_all_keys(?ACL_TBL)),    
    ?assertEqual({true,AclEntry1},
                 of_driver_acl:read({10,10,10,10})).
    
add_specific() ->
    delete_entries(),
    
    ok = of_driver_acl:write(any,'switch_handler',[]),    
    ?assertEqual([any],
                 mnesia:dirty_all_keys(?ACL_TBL)),

    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    ok = of_driver_acl:write("123.123.123.123",'switch_handler',[]),
    
    Rec0 = #?ACL_TBL{ip_address={10,10,10,10},switch_handler = 'switch_handler', opts=[]},
    ?assertEqual([Rec0],
                 mnesia:dirty_read(?ACL_TBL,{10,10,10,10})),
    Rec1 = #?ACL_TBL{ip_address={123,123,123,123},switch_handler = 'switch_handler', opts=[]},
    ?assertEqual([Rec1],
                 mnesia:dirty_read(?ACL_TBL,{123,123,123,123})),

    ?assertEqual({true,Rec0},
                 of_driver_acl:read({10,10,10,10})),
    ?assertEqual({true,Rec1},
                 of_driver_acl:read({123,123,123,123})).

allowed() ->
    delete_entries(),
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    
    delete_entries(),
    ok = of_driver_acl:write(any,'switch_handler',[]),
    Rec0 = #?ACL_TBL{ip_address=any,switch_handler = 'switch_handler', opts=[]},
    ?assertEqual({true,Rec0},of_driver_db:allowed({0,0,0,0})),
    
    delete_entries(),
    ok = of_driver_acl:write({10,10,10,10},'switch_handler',[]),
    Rec1 = #?ACL_TBL{ip_address={10,10,10,10},switch_handler = 'switch_handler', opts=[]},
    ?assertEqual(false,of_driver_db:allowed({0,0,0,0})),
    ?assertEqual({true,Rec1},of_driver_db:allowed({10,10,10,10})).

delete_entries() ->
    [ begin 
          [ mnesia:dirty_delete(Tbl,Key) || Key <- mnesia:dirty_all_keys(Tbl) ]
      end || Tbl <- [?ACL_TBL]
    ].
