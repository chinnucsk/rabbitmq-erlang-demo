-module(rabbitmq_sub).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


start() ->
    register(?MODULE, spawn(fun subscribe/0)).


subscribe() ->
    Connection = amqp_connection:start_network(#amqp_params{host = "lab.ndpar.com"}),
    Channel = amqp_connection:open_channel(Connection),

    Exchange = <<"ndpar.topic">>,
    Queue = <<"ndpar.erlang.client">>,

    DeclareExchange = #'exchange.declare'{exchange = Exchange, type = <<"topic">>},
    #'exchange.declare_ok'{} = amqp_channel:call(Channel, DeclareExchange),

    DeclareQueue = #'queue.declare'{queue = Queue},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, DeclareQueue),

    Binding = #'queue.bind'{queue = Queue, exchange = Exchange, routing_key = <<"NDPAR.ERLANG.#">>},
    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),

    Sub = #'basic.consume'{queue = Queue, no_ack = true},       
    #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(Channel, Sub, self()),

    loop(Channel),

    amqp_channel:close(Channel),
    amqp_connection:close(Connection),
    ok.


loop(Channel) ->
    receive
        #'basic.consume_ok'{} -> loop(Channel);
        #'basic.cancel_ok'{} -> ok;
        {#'basic.deliver'{delivery_tag = _Tag}, Message} ->
            spawn(fun() -> handle(Message) end),
            loop(Channel)
    end.


handle(Message) ->
    {amqp_msg, _Props, Payload} = Message,
    io:format("Received message: ~p~n", [binary_to_list(Payload)]).


stop() ->
    ?MODULE ! #'basic.cancel_ok'{},
    ok.

