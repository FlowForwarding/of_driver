-module(of_driver_db).

%% DB API to seperate DB infrastructure from LOOM.

-export([allowed/1]).

allowed(Address) ->
    case of_driver_acl:read(Address,white) of
        true  -> 
            case of_driver_acl:read(Address,black) of
                false -> true; %% Case no black record, Good!
                true -> false  %% Case black record, Bad!
            end;
        false -> false
    end.
