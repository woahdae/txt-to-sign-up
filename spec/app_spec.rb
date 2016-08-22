require 'minitest/autorun'
require 'minitest/spec'
require 'vcr'

require_relative '../app'

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
end

describe TxtHandler do

  before do
    @config = {
      spreadsheet_key:    '1iEctU4H3IH3wcPo8g_aVfz4hHKhwzklZMir7TMk-6RQ',
      worksheet_index:    0,
      # Note, test creds
      twilio_account_sid: 'ACb42c4ba98685fe6b93698cff8c738e29',
      twilio_auth_token:  'e2dffee33aa4141b2cea362696a9977e'
    }
  end

  describe '::extract_name_email_from_body' do
    [
      "Barack Obama, president@whitehouse.gov",
      "president@whitehouse.gov, Barack Obama",
      "Barack Obama president@whitehouse.gov",
      "Barack Obama  president@whitehouse.gov",
      "Barack Obama,,president@whitehouse.gov",
    ].each do |body|
      it "parses \"#{body}\" as Barack Obama, president@whitehouse.gov" do
        TxtHandler.extract_name_email_from_body(body).must_equal(
          ["Barack Obama", "president@whitehouse.gov"]
        )
      end
    end

    [
      ", , Barack, Obama, president@whitehouse.gov",
      "president@whitehouse.gov Barack, Obama, "
    ].each do |body|
      it "parses \"#{body}\" as Barack, Obama, president@whitehouse.gov" do
        TxtHandler.extract_name_email_from_body(body).must_equal(
          ["Barack, Obama", "president@whitehouse.gov"]
        )
      end
    end
  end

  describe 'when the senders message has an email address in it' do
    it 'saves a text message to google drive' do
      handler = TxtHandler.new(
        from_number: '12532085505',
        to_number: '15005550006',
        body: 'Woody Peterson, woody.peterson@gmail.com'
      ).tap {|h| h.config = @config}

      VCR.use_cassette("saves a text message to google drive", record: :none) do
        handler.save.must_equal true
        handler.error.must_equal nil
      end
    end
  end

  describe 'when the senders message does not have an email address' do
    it 'does not save a text message to google drive' do
      handler = TxtHandler.new(
        from_number: '12532085505',
        to_number: '15005550006',
        body: 'woody.peterson'
      ).tap {|h| h.config = @config}

      VCR.use_cassette("does not save a text message to google drive", record: :none) do
        handler.save.must_equal false
        handler.error.must_equal(
          'Please include your name and email, ex. "Barack Obama, president@whitehouse.gov"'
        )
      end
    end
  end

end
