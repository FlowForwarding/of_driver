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

-module(of_driver_utils).
-copyright("2013, Erlang Solutions Ltd.").

-include_lib("of_protocol/include/of_protocol.hrl").

-export([connection_info/1
        ]).

-export([send/3,  
         setopts/3,
         close/2,
         connect/3,
         opts/1
        ]).
-export([conf_default/2,
         conf_default/3,
         proplist_default/3,
         datapath_mac/2
        ]).

-spec connection_info(ConnectionPid :: pid()) -> {ok,record()} | undefined.
% @doc
connection_info(ConnectionPid) ->
    try
        {ok,State} = gen_server:call(ConnectionPid,state)
    catch 
        exit:{noproc,{gen_server,call,[ConnectionPid,state]}} ->
            undefined
    end.

conf_default(Entry, Default) ->
    conf_default(Entry, fun any/1, Default).

conf_default(Entry, GuardFun, Default) ->
    case application:get_env(of_driver, Entry) of
	{ok, Value} -> 
            case GuardFun(Value) of
                true -> Value;
                false -> Default
            end;
	_ -> 
            Default
    end.

proplist_default(Prop,List,Default) ->
    case lists:keyfind(Prop, 1, List) of
        false ->
            Default;
        {Prop,Value} ->
            Value
    end.

any(_) -> true.

connect(tcp, Host, Port) ->
    gen_tcp:connect(Host, Port, opts(tcp), 5000);
connect(tls, Host, Port) ->
    case linc_ofconfig:get_certificates() of
        [] ->
            {error, no_certificates};
        Cs ->
            Certs = [base64:decode(C) || {_, C} <- Cs],
            ssl:connect(Host, Port, [{cacerts, Certs} | opts(tls)], 5000)
    end.

opts(tcp) ->
    [binary, {reuseaddr, true}, {active, once}];
opts(tls) ->
    opts(tcp) ++ [{verify, verify_peer},
                  {fail_if_no_peer_cert, true}]
        ++ [{cert, base64:decode(Cert)}
            || {ok, Cert} <- [application:get_env(linc, certificate)]]
        ++ [{key, {'RSAPrivateKey', base64:decode(Key)}}
            || {ok, Key} <- [application:get_env(linc, rsa_private_key)]].

setopts(tcp, Socket, Opts) ->
    inet:setopts(Socket, Opts);
setopts(tls, Socket, Opts) ->
    ssl:setopts(Socket, Opts).

send(tcp, Socket, Data) ->
    gen_tcp:send(Socket, Data);
send(tls, Socket, Data) ->
    ssl:send(Socket, Data).

close(_, undefined) ->
    ok;
close(tcp, Socket) ->
    gen_tcp:close(Socket);
close(tls, Socket) ->
    ssl:close(Socket).

datapath_mac(SwitchId,MAC) ->
    string:join([integer_to_hex(D) || <<D>> <= <<MAC/binary,SwitchId:16>>],":").

integer_to_hex(I) ->
    case integer_to_list(I, 16) of
        [D] -> [$0, D];
        DD  -> DD
    end.
%%----------------------------------------------------------------------------
