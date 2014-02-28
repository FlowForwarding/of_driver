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

-export([list_connections/0,
         list_connections/1,
         connection_info/1
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
         create_hello/1,
         create_features_request/1,
         get_datapath_info/2,
         get_aux_id/2,
         get_capabilities/2
        ]).

-spec list_connections() -> list().
% @doc
list_connections() -> 
    ets:tab2list(of_driver_switch_connection).

-spec list_connections( Arg :: tuple() ) -> list().
list_connections(IpAddr) when is_tuple(IpAddr) ->
    of_driver_switch_connection:lookup_connection_pid(IpAddr).

-spec connection_info(ConnectionPid :: pid()) -> {ok,record()} | undefined.
% @doc
connection_info(ConnectionPid) ->
    try
        {ok,State} = gen_server:call(ConnectionPid,state)
    catch 
        exit:{noproc,{gen_server,call,[ConnectionPid,state]}} ->
            undefined
    end.

mod(3) ->
    {ok, of_driver_v3};
mod(4) ->
    {ok, of_driver_v4};
mod(_) ->
    {error, bad_version}.

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

create_hello(Versions) when is_integer(Versions) ->
    create_hello([Versions]);
create_hello(Versions) when is_list(Versions) ->
    Version = lists:max(Versions),
    Body = if
               Version >= 4 ->
                   #ofp_hello{elements = [{versionbitmap, Versions}]};
               true ->
                   #ofp_hello{}
           end,
    #ofp_message{version = Version, xid = 0, body = Body}.

create_features_request(Version) ->
    apply_version(Version,features_request,[]).

get_datapath_info(Version, OfpFeaturesReply) ->
    apply_version(Version, get_datapath_info, [OfpFeaturesReply]).

get_aux_id(Version, OfpFeaturesReply) -> %% NOTE: v3 has no auxiliary_id
    apply_version(Version, get_aux_id, [OfpFeaturesReply]).

get_capabilities(Version,OfpFeaturesReply) ->
    apply_version(Version,get_capabilities,[OfpFeaturesReply]).

apply_version(Version, Function, Args) ->
    case mod(Version) of
	{ok, M} -> apply(M, Function, Args);
	Error  -> Error
    end.

%%-----------------------------------------------------------------------------

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

%%----------------------------------------------------------------------------
