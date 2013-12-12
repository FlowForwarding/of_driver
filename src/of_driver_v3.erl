-module(of_driver_v3).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v3.hrl").

-export([features_request/0,
         datapath_id/1
        ]).

features_request() ->
    Body = #ofp_features_request{},
    #ofp_message{version = 3, xid = 0, body = Body}.

datapath_id(Rec) ->
    #ofp_features_reply{datapath_id = DatapathID} = Rec,
    DatapathID.
