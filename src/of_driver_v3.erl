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
