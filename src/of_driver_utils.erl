-module(of_driver_utils).

-include_lib("of_protocol/include/of_protocol.hrl").

-export([send/3,
         setopts/3,
         close/2
        ]).
-export([conf_default/3,
         create_hello/1,
         create_unsupported_hello/1
        ]).

conf_default(Entry,Guard,Default) ->
    case application:get_env(of_driver,Entry) of
	{ok,Value} -> 
            case Guard(Value) of
                true -> Value;
                false -> Default
            end;
	_ -> 
            Default
    end.

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

create_unsupported_hello(Version) ->
    {ok, EncodedHello} = of_protocol:encode(create_hello(Version)),
    <<_:8, Rest/binary>> = EncodedHello,
    <<(16#5):8, Rest/binary>>.

%%------------------------------------------------------------------------------------

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

-spec generate_aux_resource_id(string(), integer()) -> string().
generate_aux_resource_id(MainResourceId, AuxId) ->
    MainResourceId ++ "_aux" ++ AuxId.

max_generation_id() ->
    16#FFFFFFFFFFFFFFFF.
