module LogjamAgent
  self.application_name = "railsapp"
  self.auto_detect_logged_exceptions
  self.add_forwarder(:zmq)
end
