# Logjam Agent

Client side library for logjam.

Hooks into Rails, collects log lines, performance metrics, error/exception infomation and Rack
environment information and sends this data to [Logjam](https://github.com/skaes/logjam_app).

Currently two alternate mechanisms are available for data transport: AMQP or ZeroMQ.

## Usage

For AMQP, add

```ruby
gem "logjam_agent"
gem "bunny"
```
For ZeroMQ, add

```ruby
gem "logjam_agent"
gem "ffi-rzmq"
```

to your Gemfile.

Add an initializer `config/initializers/logjam_agent.rb` to your app
and configure class `LogjamAgent`.

```ruby
module LogjamAgent
  # Configure the application name (required). Must not contain dots or hyphens.
  self.application_name = "myapp"

  # Configure the environment name (optional). Defaults to Rails.env.
  # self.environment_name = Rails.env

  # Configure request data forwarder for ZeroMQ.
  add_forwarder(:zmq, :host => "logjam.instance.at.your.org", :port => 9605)

  # Configure request data forwarder for AMQP.
  # add_forwarder(:amqp, :host => "message.broker.at.your.org"))

  # Configure ip obfuscation. Defaults to no obfuscation.
  self.obfuscate_ips = true

  # Configure cookie obfuscation. Defaults to [/_session\z/].
  # self.obfuscated_cookies = [/_session\z/]

  # Configure asset request logging and forwarding. Defaults to ignore
  # asset requests in development mode. Set this to false if you need
  # to debug asset request handling.
  # self.ignore_asset_requests = Rails.env.development?

  # Configure lines which will not be logged locally.
  # They will still be sent to the logjam server. Defaults to nil.
  # self.log_device_ignored_lines = /^\s*Rendered/
end
```

### Generating unique request ids

The agent generates unique request ids for all request handled. It
will use [uuid4r](https://github.com/skaes/uuid4r) if this is
avalaibale in the application. Otherwise it will fall back to use the
standard `SecureRandom` class shipped with Ruby.

### Generating JSON

The agent will try to use the [Oj](https://github.com/ohler55/oj) to
generate JSON. If this is not available in your application, it will
fall back to the `to_json` method.

## Troubleshooting

If the agent experiences problems when sending data, it will log information to a file named
`logjam_agent_error.log` which you can find under `Rails.root/log`.

This behavior is customizable via a module level call back method:

```ruby
LogjamAgent.error_handler = lambda {|exception| ... }
```

# License

The MIT License

Copyright (c) 2013 Stefan Kaes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.





