-module(proto_http).

-export([recv/1]).
-export([recv_headers/1]).
-export([recv_body/2]).

-export([response/3]).
-export([path_and_query/1]).

-include("global.hrl").

recv(Socket) ->
    HttpHeaders = recv_headers(Socket),
    ContLen = maps:get('Content-Length', HttpHeaders, undefined),
    %TransEncoding = maps:get('Transfer-Encoding', HttpHeaders, undefined),
    Body = recv_body(Socket, ContLen),
    {HttpHeaders, Body}.


recv_headers(Socket) ->
    inet:setopts(Socket, [{active, false}, {packet, httph_bin}]),
    recv_headers_1(Socket).

recv_headers_1(Socket) -> recv_headers_1(Socket, #{}, 0).
recv_headers_1(_, _, Size) when Size > ?MAX_HEADER_SIZE -> throw(max_header_size_exceeded);
recv_headers_1(Socket, Map, Size) ->
    case gen_tcp:recv(Socket, 0, ?TIMEOUT) of
        {ok, {http_header,_,Key,undefined, Value}} -> 
            recv_headers_1(Socket, Map#{Key=>Value}, Size + size(Value));
        {ok, http_eoh} -> Map
    end.


recv_body(Socket, undefined) -> <<>>;
recv_body(Socket, ContLen) when is_binary(ContLen) -> 
    recv_body(Socket, binary_to_integer(ContLen));
recv_body(Socket, ContLen) when ContLen > ?MAX_BODY_SIZE -> <<>>;
recv_body(Socket, ContLen) ->
    inet:setopts(Socket, [{active, false}, {packet, raw}, binary]),
    {ok, Body} = gen_tcp:recv(Socket, ContLen, ?TIMEOUT),
    Body.




path_and_query(Path) ->
    {CleanPath, Query} = case binary:split(Path, <<"?">>, [trim]) of
        [P, Q] -> 
            KVs = binary:split(Q, <<"&">>, [global]),
            KVsSplit = [binary:split(X, <<"=">>) || X <- KVs],
            KVMap = lists:foldl(fun(KVPair, Acc) ->
                    case KVPair of
                        [A, B] -> maps:put(A, B, Acc);
                        [A] -> maps:put(A, <<"">>, Acc)
                    end
                end, #{}, KVsSplit
            ),
            {P, KVMap};
        _ -> {Path, #{}}
    end,
    {CleanPath, Query}
.







response(Code, B, C) when is_integer(Code) -> response(integer_to_binary(Code), B, C);
response(Code, Headers, Body) ->
    Headers2 = maps:put(<<"Connection">>, <<"close">>, Headers),
    HeadersFinal = maps:put(<<"Content-Length">>, integer_to_binary(size(Body)), Headers),

    Bin = <<"HTTP/1.1 ", Code/binary, " ", (response_code(Code))/binary, "\r\n">>,
    HeaderBin = maps:fold(fun(K,V,Acc) ->
            <<Acc/binary, K/binary, ": ", V/binary, "\r\n">>
        end,
        <<>>,
        HeadersFinal
    ),
    <<Bin/binary, HeaderBin/binary, "\r\n", Body/binary>>
    .




%1×× Informational
response_code(<<"100">>) -> <<"Continue">>;
response_code(<<"101">>) -> <<"Switching Protocols">>;
response_code(<<"102">>) -> <<"Processing">>;

%2×× Success
response_code(<<"200">>) -> <<"OK">>;
response_code(<<"201">>) -> <<"Created">>;
response_code(<<"202">>) -> <<"Accepted">>;
response_code(<<"203">>) -> <<"Non-authoritative Information">>;
response_code(<<"204">>) -> <<"No Content">>;
response_code(<<"205">>) -> <<"Reset Content">>;
response_code(<<"206">>) -> <<"Partial Content">>;
response_code(<<"207">>) -> <<"Multi-Status">>;
response_code(<<"208">>) -> <<"Already Reported">>;
response_code(<<"226">>) -> <<"IM Used">>;

%3×× Redirection
response_code(<<"300">>) -> <<"Multiple Choices">>;
response_code(<<"301">>) -> <<"Moved Permanently">>;
response_code(<<"302">>) -> <<"Found">>;
response_code(<<"303">>) -> <<"See Other">>;
response_code(<<"304">>) -> <<"Not Modified">>;
response_code(<<"305">>) -> <<"Use Proxy">>;
response_code(<<"307">>) -> <<"Temporary Redirect">>;
response_code(<<"308">>) -> <<"Permanent Redirect">>;

%4×× Client Error
response_code(<<"400">>) -> <<"Bad Request">>;
response_code(<<"401">>) -> <<"Unauthorized">>;
response_code(<<"402">>) -> <<"Payment Required">>;
response_code(<<"403">>) -> <<"Forbidden">>;
response_code(<<"404">>) -> <<"Not Found">>;
response_code(<<"405">>) -> <<"Method Not Allowed">>;
response_code(<<"406">>) -> <<"Not Acceptable">>;
response_code(<<"407">>) -> <<"Proxy Authentication Required">>;
response_code(<<"408">>) -> <<"Request Timeout">>;
response_code(<<"409">>) -> <<"Conflict">>;
response_code(<<"410">>) -> <<"Gone">>;
response_code(<<"411">>) -> <<"Length Required">>;
response_code(<<"412">>) -> <<"Precondition Failed">>;
response_code(<<"413">>) -> <<"Payload Too Large">>;
response_code(<<"414">>) -> <<"Request-URI Too Long">>;
response_code(<<"415">>) -> <<"Unsupported Media Type">>;
response_code(<<"416">>) -> <<"Requested Range Not Satisfiable">>;
response_code(<<"417">>) -> <<"Expectation Failed">>;
response_code(<<"418">>) -> <<"I'm a teapot">>;
response_code(<<"421">>) -> <<"Misdirected Request">>;
response_code(<<"422">>) -> <<"Unprocessable Entity">>;
response_code(<<"423">>) -> <<"Locked">>;
response_code(<<"424">>) -> <<"Failed Dependency">>;
response_code(<<"426">>) -> <<"Upgrade Required">>;
response_code(<<"428">>) -> <<"Precondition Required">>;
response_code(<<"429">>) -> <<"Too Many Requests">>;
response_code(<<"431">>) -> <<"Request Header Fields Too Large">>;
response_code(<<"444">>) -> <<"Connection Closed Without Response">>;
response_code(<<"451">>) -> <<"Unavailable For Legal Reasons">>;
response_code(<<"499">>) -> <<"Client Closed Request">>;

%5×× Server Error
response_code(<<"500">>) -> <<"Internal Server Error">>;
response_code(<<"501">>) -> <<"Not Implemented">>;
response_code(<<"502">>) -> <<"Bad Gateway">>;
response_code(<<"503">>) -> <<"Service Unavailable">>;
response_code(<<"504">>) -> <<"Gateway Timeout">>;
response_code(<<"505">>) -> <<"HTTP Version Not Supported">>;
response_code(<<"506">>) -> <<"Variant Also Negotiates">>;
response_code(<<"507">>) -> <<"Insufficient Storage">>;
response_code(<<"508">>) -> <<"Loop Detected">>;
response_code(<<"510">>) -> <<"Not Extended">>;
response_code(<<"511">>) -> <<"Network Authentication Required">>;
response_code(<<"599">>) -> <<"Network Connect Timeout Error">>.