%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% 
%%% @end
%%%-------------------------------------------------------------------
-define(DATAPATH_TBL,   of_driver_datapath).
-define(SWITCH_CONN_TBL,of_driver_switch_connection).
-define(SYNC_MSG_TBL,   of_driver_sync_message).

%% Opt is an Erlang term that sets options for the handling of this IP address. 
-type allowance() :: [{IpAddr        :: tuple(),%% {0,0,0,0}
                       SwitchHandler :: atom(), %% usually  ofs_handler
                       Opts          :: list()  %% init_opt | enable_ping | ping_timeout | ping_idle | multipart_timeout
                      }].
