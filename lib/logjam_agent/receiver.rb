module LogjamAgent
  class Receiver
    def initialize
      @socket = ZMQForwarder.context.socket(ZMQ::ROUTER)
      @socket.setsockopt(ZMQ::RCVTIMEO, 100)
      if @socket.bind("inproc://app") < 0
        raise "ZMQ error on binding: #{ZMQ::Util.error_string}"
      end
      at_exit { @socket.close }
    end

    def receive
      answer_parts = []
      if @socket.recv_strings(answer_parts) < 0
        raise "ZMQ error on receiving: #{ZMQ::Util.error_string}"
      end
      answer_parts.shift
      answer_parts[2] = JSON.parse(answer_parts[2])
      answer_parts
    end
  end
end
