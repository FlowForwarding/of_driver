-module(of_driver_v4).

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v4.hrl").

-export([features_request/0,
         datapath_id/1,
	 get_aux_id/1
        ]).

features_request() ->
    Body = #ofp_features_request{},
    #ofp_message{version = 4, xid = 0, body = Body}.

datapath_id(Rec) ->
    #ofp_features_reply{ datapath_id = DatapathID } = Rec,
    DatapathID.

get_aux_id(Rec) ->
    #ofp_features_reply{ auxiliary_id = DatapathID } = Rec,
    DatapathID.
