require 'sinatra'
require "google_drive"
require "twilio-ruby"

get '/' do
  "It's alive!"
end

post "/sign_up" do
  check_credentials

  TxtHandler.new(
    to_number: params['To'],
    from_number: params["From"],
    body: params["Body"]
  ).save
end

class TxtHandler
  def config
    @config ||=
      OpenStruct.new(
        spreadsheet_key:    ENV['SPREADSHEET_KEY'],
        worksheet_index:    ENV['WORKSHEET_INDEX'].to_i || 0,
        twilio_account_sid: ENV["TWILIO_ACCOUNT_SID"],
        twilio_auth_token:  ENV["TWILIO_AUTH_TOKEN"]
      )
  end

  def config=(config_hash)
    @config = OpenStruct.new(config_hash)
  end

  attr_reader :from_number, :to_number, :body, :error

  def initialize(from_number:, to_number:, body:)
    @from_number = from_number
    @to_number   = to_number
    @body        = body
  end

  def save
    saved = save_to_sheet if valid_body?

    if !saved && !@error
      @error = "Unknown Error"
    end

    if !confirm_to_sender
      STDERR.puts "Failed to confirm to sender"
      return false
    end

    return !@error
  end

  def valid_body?
    if body.include?('@')
      true
    else
      @error = "Please include your email address"
      false
    end
  end

  def confirmation_message
    @error ? @error : "Thanks!!! 👍"
  end

  private

  def save_to_sheet
    session     = GoogleDrive::Session.
      from_service_account_key("config/google-service-account.json")
    spreadsheet = session.spreadsheet_by_key(config.spreadsheet_key)
    worksheet   = spreadsheet.worksheets[config.worksheet_index]
    row         = worksheet.num_rows + 1

    worksheet[row, 1] = body
    worksheet[row, 2] = from_number
    worksheet[row, 3] = Time.now.strftime("%-m/%-d/%Y %H:%M:%S")

    worksheet.save
  end

  def confirm_to_sender
    if to_number && from_number
      message = twilio_client.account.messages.create({
        to:   from_number,
        from: to_number,
        body: confirmation_message
      })

      return message.status == 'queued'
    end

    return false
  end

  def twilio_client
    @twilio_client ||=
      Twilio::REST::Client.new(
        config.twilio_account_sid, config.twilio_auth_token
      )
  end

end
