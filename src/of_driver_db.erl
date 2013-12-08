-module(of_driver_db).

%% DB API to seperate DB infrastructure from LOOM.

-export([install/0,
	 allowed/1,
         insert_datapath_id/3,
         lookup_datapath_id/1,
	 add_aux_id/3
        ]).

install() ->
    try
	install_try()
    catch
	C:E ->
	    io:format("... [~p] Install failed. ~p.\n...Reason:~p...\n...Stacktrace:~p...\n",[?MODULE,C,E,erlang:get_stacktrace()]),
	    ok
    end.
    
install_try() ->
    application:stop(mnesia),
    mnesia:create_schema([node()]),
    application:start(mnesia),
    
    ok = of_driver_acl:create_table([node()]),
    
    ok = mnesia:wait_for_tables([of_driver_acl_white,of_driver_acl_black],infinity),
    case ets:info(of_driver_channel_datapath) of
        undefined ->
            of_driver_channel_datapath = ets:new(of_driver_channel_datapath,[ordered_set,public,named_table]),
	    ok;
        Options ->
            ok
    end.

allowed(Address) ->
    case of_driver_acl:read(Address,white) of
        true  -> 
            case of_driver_acl:read(Address,black) of
                false -> true; %% Case no black record, Good!
                true -> false  %% Case black record, Bad!
            end;
        false -> false
    end.

insert_datapath_id(DataPathID,ChannelPID,ConnPID) ->
    ets:insert_new(of_driver_channel_datapath,{DataPathID,ChannelPID,ConnPID,AuxConnections=[]}).
    
add_aux_id(Entry,DataPathID,[AuxID,ConnPID]) ->
    CurrentAuxs = element(4,Entry),
    ets:update_element(of_driver_channel_datapath,DataPathID,{4,[[AuxID,ConnPID]|CurrentAuxs]}).

lookup_datapath_id(DataPathID) ->
    ets:lookup(of_driver_channel_datapath,DataPathID).
