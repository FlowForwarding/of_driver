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

-module(of_driver_message).

-include_lib("of_protocol/include/of_protocol.hrl").

-export([ append_body/2 ]).

append_body(#ofp_message{ xid = Xid, type = Type, version = Version } = Msg1, 
            #ofp_message{ xid = Xid, type = Type, version = Version } = Msg2) ->
    Mod = message_module(Version),
    Mod:append_body(Msg1,Msg2);
append_body(_,_) -> %% Non matching...
    false.

message_module(4) ->
    of_driver_message_4;
message_module(5) ->
    of_driver_message_5.