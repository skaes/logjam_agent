previous_handler = Signal.trap(:HUP) do
  previous_handler.call if previous_handler.respond_to?(:call)

  return unless defined?(Rails)

  logger = Rails.logger
  return unless logger.instance_of?(LogjamAgent::BufferedLogger)

  logdev = logger.logdev
  return unless logdev.instance_of?(Logger::LogDevice)

  # reopen filehandle if necessary
  filename = logdev.filename

  current_ino = begin
    File.stat(filename).ino
  rescue
    nil
  end

  if logdev.dev.stat.ino != current_ino
    prev_sync_state = logdev.dev.sync
    logdev.dev.reopen File.new(filename, 'w')
    logdev.dev.sync = prev_sync_state
  end
end
