-module(of_driver_db).

%% DB API to seperate DB infrastructure from LOOM.

-export([allowed/1,
         insert_datapath_id/2,
         read_datapath_id/1
        ]).

allowed(Address) ->
    case of_driver_acl:read(Address,white) of
        true  -> 
            case of_driver_acl:read(Address,black) of
                false -> true; %% Case no black record, Good!
                true -> false  %% Case black record, Bad!
            end;
        false -> false
    end.

insert_datapath_id(ConnPID,DataPathID) ->
    AuxConnections=[],
    case ets:insert_new(of_driver_channel_datapath,{ConnPID,DataPathID,AuxConnections}) of
        true -> true;
        false -> false
    end.

%% add_aux_conn(ConnPID,) 

read_datapath_id(ConnPID) ->
    ets:lookup(of_driver_channel_datapath,ConnPID).

