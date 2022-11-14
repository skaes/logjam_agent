# CHANGELOG

## 0.38.1
* Fixed that objects other than strings caused the logger to crash.

## Version 0.38.0
* Support logging embedded json instead of text. Here embedded means
  the usual logger prefix is still added to each line.

## Version 0.37.1
* Changed format of HTTP request completed line to be "Completed: #{data.to_json}"

## Version 0.37.0
* Reduced Rails HTTP Request logging to a single line with JSON content.

## Version 0.36.0
* Support suppressing sending data to Logjam and also loggin to the
  log device via an URL regex pattern list
  `Logjam.ignored_request_urls`.

## Version 0.35.1
* Allow selective logging to be globally disabled

## Version 0.35.0
* Added selective logging

## Version 0.34.3
* Fixed that loggers without log device crashed the agent

## Version 0.34.2
* use monotonic clocks to measure request runtime

## Version 0.34.1
* make Sinatra log formatter configurable and default it to the Ruby default one

## Version 0.34.0
* supports arbitrary log formatters, including the Ruby default one
* drops support for Rails versions before 5.2

## Version 0.33.3
* don't log an error when the response to a sync message is correct

## Version 0.33.2
* don't run at_exit handlers in child processes

## Version 0.33.1
* use Ruby 3.1.1 in GitHub actions
* add wait_time_ms field to logjam request before dispatching
* updated Appraisals
* Rails 6.0.4.4 and Ruby 3.1.0 are not compatible
* added Ruby 3.1.0 to CI/CD
* only test Rails 7.0.0 with Ruby >= 2.7.0
* updated ruby versions for github actions
* updated Appraisals
* switched to GitHub actions
* updated appraisals
* removed gemfiles created by appraisal and ignore them
* added tests for passing sender and trace id headers

## Version 0.33.0
* draft implementation for trace ids
* commented out test output
* added makefile
* db changes
* rails 5 is not compatible with ruby 3
* adapted welcome controller test for different rails versions
* don't check in Gemfile locks
* updated ruby versions for travis
* fixed integration tests
* updated appraisals

## Version 0.32.4
* suppress Ruby 2.7 warnings in action controller tests and crashes in 3.0.0

## Version 0.32.3
* removed deprecated Socket.gethostbyname call

## Version 0.32.2
* patch ffi-rzmq to work with ffi 1.14.0

## Version 0.32.1
* don't deadlock when sending ping fails

## Version 0.32.0
* socket needs to be protected by a mutex to avoid broken ZMQ messages
* updated ruby versions on travis

## Version 0.31.0
* require latest time_bandits version
* try fixing travis build
* added integration tests
* support not sending a ping at exit. defaults to not running in dev or test mode.
* drop logger support for ancient Rails versions
* support inproc protocol for zmq forwarders
* move license to separate file
* Add rails app for testing
* activate Rails support only when Rails::Railtie is defined
* we don't need the sinatra-contrib gem
* make logjam_agent work with active_support 5.2. again
* raise middleware exceptions in Rails test environment
* fix stupidity
* don't send empty fields
* fixed that additions can be nil
* uuid4r is no longer used
* require user to call use LogjamAgent::Sinatra::Middleware
* updated copyright notice
* added Sinatra info to README
* truncate overlog parameters
* handle logjam agent error logs for Sinatra
* set "rack.logger" to the logjam logger
* support ip spoofing in rails again
* test classic Sinatra app support
* simplified Sinatra application setup
* silence stupid warnings about uninitialized variables
* WIP: support Sinatra apps
* Set homepage url to github repository

## Version 0.30.0
* make formatter attributes thread safe
* use ActiveSupport::ParameterFilter when available
* deliver correct html on exception in middleware
* drop obsolete rubyforge_project assignment

## Version 0.29.6
* make sure to install socket at_exit handler after context at_exit handler

## Version 0.29.5
* send app-env as routing key for ping messages

## Version 0.29.4
* only send ping at exit once if socket has been opened

## Version 0.29.3
* only reset zmq connection when we round robin
* Reset socket if publish fails

## Version 0.29.2
* logjam_agent seems rails 6 compatible

## Version 0.29.1
* increased ZQM hwm values to 1000

## Version 0.29.0
* support LZ4 compression

## Version 0.28.0
* dropped support for rabbitmq transport

## Version 0.27.0
* respect LOGJAM_ENV if set
* Set homepage url to github repository

## Version 0.26.6
* fixed bug in line truncation

## Version 0.26.5
* improved line/message truncation algorithm

## Version 0.26.4
* added namespace to forwarded request

## Version to 0.26.3
* forward cluster and datacenter information

## Version 0.26.2
* fixed index out of bounds problem when truncating strings

## Version 0.26.1
* allow cookies values to be as large as LogjamAgent.max_logged_cookie_size

## Version 0.26.0
* protect against logging overlong parameters
* silenced a stupid warning

## Version 0.25.3
* use workaround to place RemoteIp middleware correctly even with Rails 5+

## Version 0.25.2
* fixed a parameter filter regression caused by rails 5.1.2

## Version 0.25.1
* Split soft and hard exceptions by default.

## Version 0.25.0

* Merge pull request #28 from 0robustus1/master

## Version 0.24.10
* only connect to one single logjam device to preserve message sequencing

## Version 0.24.9
* protect against Rails 5 firing on_load multiple times

## Version 0.24.8
* Fix typo on concat
* base soft-exceptions split on a new option
* split exceptions into two classes

## Version to 0.24.7
* return 403 instead of 500 when detecting a spoofing attack

## Version 0.24.6
* need fully qualified class name when rescuing spoof attack exceptions

## Version 0.24.5
* log ip spoofing attacks

## Version 0.24.4
* Allow to log on std outputs only

## Version 0.24.3
* Read version from REVISION file

## Version 0.24.2
* Add support for X-Starttime in seconds

## Version 0.24.1
* no change

## Version 0.24.0
* send ping message to logjam-device/importer on exit

## Version 0.23.1
* support publishing synchronously using LogjamAgent.start_request(:sync => true)

## Version 0.23.0
* switch to using a single DEALER socket for both sync/async messaging
* generate sequence numbers according to spec

## Version 0.22.1
* fixed broken tests
* go back to using alias_method to enable testing with rspec

## Version 0.22.0
* publish events synchronously. on failure, fall back to async

## Version 0.21.1
* fixed broken module.prepend which broke testing

## Version 0.21.0
* reformatted comment
* rack logger seems compatible with rails 5
* rails 5 now logs backtraces etc. with one logger call per line. we don't like that.
* rails 5 has deprecated alias_method_chain
* rails 5 has deprecated strings for middlewares

## Version 0.20.0
* correct default liner value in README
* add ignore_render_events option

## Version 0.19.6
* fixed that forwarder already encodes payload

## Version 0.19.5
* ensure that calling forwarder.forward directly encodes the payload

## Version 0.19.4
* make zmq publisher more robust against setting host to nil or blank string
* disable request forwarding when running in rails test environment

## Version 0.19.3
* allow logjam broker to be nil when logjam agent has been disabled

## Version 0.19.2
* allow specification of multiple hosts for zmq forwarder
* updated README.md
* we'll never need more than one zeromq io thread
* use default pull port for zmq forwarder

## Version 0.19.1

* Merge pull request #20 from markschmidt/master

* Merge pull request #22 from markschmidt/fix_0.19.0
* bugfix: make sure remote ip is a string

## Version 0.19.0
* Revert "set a cookie with the request id in the middleware"

* Merge pull request #21 from markschmidt/remote_ip
* use actionpack remote ip middleware for client ip
* fix incoming etag header in middleware

## Version 0.18.0

* Merge pull request #19 from markschmidt/master
* set a cookie with the request id in the middleware

## Version 0.17.1
* it's zlib compression, not gzip

## Version 0.17.0
* added support for compressing logjam messages

## Version 0.16.0
* allow suppressing disk logging altogether

* Merge pull request #17 from JHK/log_level_device
* configure min severity to error for logging to disk

## Version 0.15.1
* don't send authorisation header

## Version 0.15.0
* provide application revision with each request

## Version 0.14.0
* describe overriding device logging on a per request basis

* Merge pull request #15 from markschmidt/master

* Added Request#log_device_ignored_lines
* Revert "set frame_max option for amqp connection"

* Merge pull request #14 from markschmidt/master
* set frame_max option for amqp connection

## Version 0.13.3.
* avoid calling forwarder when agent has been disabled

## Version 0.13.2

* Merge pull request #13 from BjRo/uuid_v4
* Switch to v4 when using uuid4r

## Version 0.13.1
* added uploaded file size for logging purposes

* Merge pull request #12 from pietbrauer/fix_closing_bracket
* Remove superfluous closing bracket

## Version 0.13.0
* sending started_ms field with requests

## Version 0.12.3
* rescue Unknown HTTP methods

## Version 0.12.2
* reset logger attributes in rack middleware

## Version 0.12.1
* seems to be rails 4.2 compatible
* updated README

## Version 0.12.0
* use new meta_info format for messages

## Version 0.11.3
* only truncate lines with a log level less than error

## Version 0.11.2
* allow publishing of messages for other apps

## Version 0.11.1
* send X-Logjam-Request-Action from middleware

## Version 0.11.0
* send a sequence number and a timestamp on each request

## Version 0.10.2
* removed request-stream- prefix form first zmq frame

## Version 0.10.1

* Merge pull request #8 from plu/master
* Make logjam agent work on heroku.
* README changes

## Version 0.10.0
* limit size if log lines and total size of all log lines

## Version 0.9.12
* protect against negative wait time
* Version 0.9.11
* don't add the Exception class to the list of autodetected exception classes

* Merge pull request #7 from contaxt/changes
* fix for strange implementations of self.<=> in external class definitions
* rescuing from exception raised when collecting exceptions with compare

## Version 0.9.10
* use DONTWAIT instead of obsolete NonBlocking

## Version 0.9.9
* fixed that rails 4.1 calls start_processing twice

## Version 0.9.8
* start processing is still compatible in Rails 4.1.0

## Version 0.9.7
* enable tracking of apache wait time

## Version 0.9.6
* rescue pattern match exceptions potentially caused by character encodings

## Version 0.9.5
* optionally suppress writing log lines to log device

## Version 0.9.4
* configurable logging and forwarding of asset requests

## Version 0.9.3
* fixed fuscator typo
* fix ip logging by patching rack
* README typos
* README improvements
* fixed typo in README

## Version 0.9.2
* only try to obfuscate cookies if list of obfuscations is present
* fixed typo in README
* more ruby syntax coloring
* fix README formatting

## Version 0.9.1
* hide a few more variables
* added cookie obfuscation
* added ip obfuscation
* remove empty debug line
* updated README
* turn on exception class detection by default
* log forwarder exceptions on local log file
* provide add_forwarder method to avoid exposing Forwarders class
* automatically use default app and env names

## Version 0.9.0
* mention that zeromq is also an option
* upped time_bandits requirements
* fall back to SecureRandom if uuid4r cannot be laoded
* require bunny gem when instantiating an amqp forwarder

## Version 0.8.2
* enable flexible start_request syntax

## Version 0.8.1
* lose remnants of rails 2 support
* Rails might not be defined

## Version 0.8.0
* make sure logjam requests are created in test environment
* moved request cycle handling to module LogjamAgent
* removed the dubious hack to silently fetch the logjam request from the main thread

## Version 0.7.3
* fixed wrong version comparison

## Version 0.7.2
* fixed broken exception handling when using tagged logging
* fixed typo
* ignore .rvmrc

## Version 0.7.1
* more robust extraction of time bandits completion info

## Version 0.7.0
* now compatible with rails 4
* don't send caller_id back if it was blank

## Version 0.6.9
* log caller timeouts

## Version 0.6.8
* compatibility with older rails versions

## Version 0.6.7
* added action accessor

## Version 0.6.6
* analyze and set caller_action field on request
* update action filed on request as early as possible

## Version 0.6.5
* fixed json encoding of event fields

## Version 0.6.4
* ported events sending code to zmq forwarder and refactored a bit
* fixed typo in a rescue clause
* Ability to publish events to a new queue

## Version 0.6.3
* allow applications to change the action name sent to logjam

## Version 0.6.2
* support zeromq transport
* removed superflous blank
* switch to using ffi-rzmq

## Version bumped to 0.6.1
* fixed crash in rack logger

## Version 0.6.0
* use thread_variables gem
* user request.remote_ip

## Version 0.5.8
* use oj if application has it

## Version 0.5.7
* protect against trying to send uploaded files across AMQP and hogging the CPU with to_json

## Version 0.5.6
* try to preserve as much request info as possible

## Version 0.5.5
* also translate CONTENT_TYPE

## Version 0.5.4
* flush buffered logger at program exit

## Version 0.5.3
* hide more env variables
* Relax deps for rails version

## Version 0.5.2
* forgot to throw away RAW_POST_DATA

## Version 0.5.1
* fixed memory leak caused by bug in rails

## Version 0.5.0
* log request environment

## Version 0.4.5
* support logging from background threads

## Version 0.4.4
* access log level via logger accessor, because rails3 stores it on the encapsulated logger

## Version 0.4.3
* protect against ripple modifying to_json time formats

## Version 0.4.2
* use SyslogLikeFormatter as default
* automatically require time_bandits and logjam_agent/railtie
* fixed bug which prevented the automatic setting of Rails.logger for Rails version < 3.2

## Version bump for rails 3.2 compatibi
* rails 3.2 compatibility
* close AMQP connections on program exit

## Version 0.3.6
* use - as field separator

## Version 0.3.4
* use uuids for identifying requests

## Version 0.3.3
* need rake for releasing
* made SyslogLikeFormatter compatible with formmatter shipped with ruby stdlib

## Version 0.3.2
* forgotten .first

## Version 0.3.1
* use fully qualified domain names for logging

## Version 0.3.0
* changed the attributes interface

## Version 0.2.4
* move execption tracking setup to LogjamAgent module
* use rails excpetion formatting conventions

## Version 0.2.3
* syntax rulez!

## Version 0.2.2
* ignore anaonymous exception classes when auto detecting exceptions

## Version 0.2.1
* support auto detecting logged exceptions

## Version 0.2.0
* support logging exceptions and forwadring them to the request stream
* all inspecting forwarders easily
* renamed send to forward to avoid horrible confusion in logs
* code cleanup
* format microseconds with leading zeros

## Version 0.1.3
* support overriding environment name globally and per request

## Version 0.1.2
* formatting changes

## Version 0.1.1
* more accurate dependency

## Version 0.1.0
* rails 3 support
* removed whitespace from line for logjam

## Version 0.0.3
* allow disabling of forwarding for testing, for example

## Version 0.0.2
* need engine as part of the routing key

## Version 0.0.1
* we depend on timebandits
* rails 2 gem support
* rack middleware
* forgotten checkin
* allow reconnecting log device
* allow adding fields when starting/finishing requests
* added host name to log line
* provide accessor for setting application name
* next iteration
* somewhat usable now
* initial commit
