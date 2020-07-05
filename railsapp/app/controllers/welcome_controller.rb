class WelcomeController < ApplicationController
  def index
    raise "You asked me to raise!" if params[:raise]
  end
end
