defmodule PursuitServices.Util.RabbitConsumer do
  defmacro __using__(_) do
    quote do
      require Logger

      use GenServer
      use AMQP

      def init(_) do 
        # Connect to the server, configure a channel, bind to the 
        # correct exchange and topic

        for {:ok, connection} <- Dotenv.get("RABBITMQ_URL") |> Connection.open,
            {:ok, channel} <- Channel.open(connection),
            {:ok, queue} <- Queue.declare(channel, "", exclusive: true),
            {:ok, exchange} <- Exchange.declare(channel, @exchange, :topic, durable: true),
            do: case Queue.bind(channel, queue, exchange, routing_key: @topic) do
                  :ok = ok -> {ok, channel}
                  _ -> 
                    failure = "Unable to bind to RabbitMQ!"
                    Logger.error(failure)
                    {:stop, failure}
                end
      end

      # Confirmation sent by the broker after registering this process as a consumer
      def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan),
        do: {:noreply, chan}

      # Sent by the broker when the consumer is unexpectedly cancelled 
      # (such as after a queue deletion)
      def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan),
        do: {:stop, :normal, chan}

      # Confirmation sent by the broker to the consumer process after a
      # Basic.cancel
      def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, chan),
        do: {:noreply, chan}
    end
  end
end