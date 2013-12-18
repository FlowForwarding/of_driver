%%%-------------------------------------------------------------------
%%% @copyright (C) 1999-2013, Erlang Solutions Ltd
%%% @author Ruan Pienaar <ruan.pienaar@erlang-solutions.com>
%%% @doc 
%%% 
%%% @end
%%%-------------------------------------------------------------------
-module(of_driver_v3).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_protocol/include/of_protocol.hrl").
-include_lib("of_protocol/include/ofp_v3.hrl").

-export([features_request/0,
         datapath_id/1,
         get_capabilities/1
        ]).

features_request() ->
    Body = #ofp_features_request{},
    {ok,#ofp_message{version = 3, xid = 0, body = Body}}.

datapath_id(Rec) ->
    #ofp_features_reply{datapath_id = DatapathID} = Rec,
    {ok,DatapathID}.

get_capabilities(Rec) ->
	#ofp_features_reply{capabilities = Capabilities} = Rec,
	{ok,Capabilities}.