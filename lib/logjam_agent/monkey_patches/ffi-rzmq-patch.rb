# see https://github.com/chuckremes/ffi-rzmq/pull/133

require 'ffi-rzmq'
require 'ffi-rzmq/message'

module ZMQ
  class Message
    def copy_in_bytes bytes, len
      data_buffer = LibC.malloc len
      # writes the exact number of bytes, no null byte to terminate string
      data_buffer.put_bytes 0, bytes, 0, len

      # use libC to call free on the data buffer; earlier versions used an
      # FFI::Function here that called back into Ruby, but Rubinius won't
      # support that and there are issues with the other runtimes too
      LibZMQ.zmq_msg_init_data @pointer, data_buffer, len, LibC::Free, nil
    end
  end
end
