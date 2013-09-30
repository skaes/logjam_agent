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

  # Configure request data forwarder for ZeroMQ.
  # add_forwarder(:amqp, :host => "message.broker.at.your.org"))

  # Configure ip obfuscation. Defaults to no obfuscation.
  self.obfuscate_ips = true

  # Configure cookie obfuscation. Defaults to [/_session\z/].
  # self.obfuscated_cookies = [/_session\z/]
end
```

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





