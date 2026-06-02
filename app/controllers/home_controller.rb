class HomeController < ApplicationController
  def index
  end

  def ping
    @pinged_at = Time.current

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: I18n.t("home.ping.ready") }
    end
  end
end
