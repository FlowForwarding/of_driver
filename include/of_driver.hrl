-define(DATAPATH_TBL,of_driver_channel_datapath).

%% Opt is an Erlang term that sets options for the handling of this IP address. 
-type allowance() :: [{IpAddr        :: tuple(),
                       SwitchHandler :: atom(), %% usually  ofs_handler
                       Opts          :: list() %% init_opt | enable_ping | ping_timeout | ping_idle | multipart_timeout
                      }].
