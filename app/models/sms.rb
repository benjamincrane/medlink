class SMS < ActiveRecord::Base
  MAX_LENGTH = 160

  # Errors raised in the sms logic may need to be displayed to the
  #   user via text. Messages wrapped in this class are assumed to
  #   be presentable.
  class FriendlyError
    def initialize key, subs={}
      msg = Medlink.translate key, subs
      super msg
    end
  end

  self.table_name = "messages"

  enum direction: [ :incoming, :outgoing ]

  has_many :orders, foreign_key: :message_id

  def self.deliver number, text
    sms = SMS.create number: number, text: text, direction: :outgoing

    sid, auth = %w(ACCOUNT_SID AUTH).map { |k| ENV.fetch "TWILIO_#{k}" }
    client = Twilio::REST::Client.new sid, auth
    client.account.sms.messages.create(
      from: ENV['TWILIO_PHONE_NUMBER'],
      to:   number,
      body: text
    )

    sms
  end

  def user
    @_user ||= if parsed.pcv_id
      User.find_by_pcv_id parsed.pcv_id
    else
      User.find_by_phone_number number
    end
  rescue ActiveRecord::RecordNotFound => e
    raise FriendlyError.new "sms.unrecognized_user"
  end

  def supplies
    @_supplies ||= begin
      codes  = parsed.shortcodes.map &:upcase
      found  = Supply.where shortcode: codes
      missed = codes - found.map(&:shortcode)
      if missed.any?
        raise FriendlyError.new "sms.unrecognized_shortcodes", codes: missed.join(', ')
      end
    end
  end

  def create_orders
    supplies.each do |supply|
      orders.create!(
        user_id:      user.id,
        supply_id:    supply.id,
        request_text: parsed.instructions,
        entered_by:   user.id
      )
    end
  end

  def send_confirmation orders
    names = supplies.map { |s| "#{s.name} (#{s.shortcode})" }
    body = "Request received: #{names.join ', '}"
    if body.length > MAX_LENGTH
      body = "Request received: #{names.first} & #{names.length - 1} other items"
    end
    SMS.deliver number, body
  end

  private

  def parsed
    @_parsed ||= Parser.new(text).tap &:run!
  end
end
