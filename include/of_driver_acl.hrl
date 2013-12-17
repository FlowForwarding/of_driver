%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% 
%%% @end
%%%-------------------------------------------------------------------
-define(ACL_TBL,of_driver_acl).
-define(COLS,{ip_address     :: atom() | inet:ip4_address() | inet:ip6_address(),
              switch_handler :: any(),
              opts           :: list()
             }).
-record(?ACL_TBL,?COLS).
