require 'street_address'

class Address < ActiveRecord::Base
  include SingularTable

  belongs_to :entity, inverse_of: :addresses
  belongs_to :state, class_name: "AddressState", inverse_of: :addresses

  validates_presence_of :street1, :city, :state, :postal

  def to_s
    "#{street1}, #{street2}, #{street3}, #{city}, #{state.abbreviation} #{postal}".strip.gsub(/ ,/, " ").gsub(/\s+/, " ")
  end

  def self.parse(str, data = {})
    a = new
    a.parse(str)
    a.attributes = data if a.parsed.nil? and data.count > 0
    a
  end

  def parse(str = nil)
    str = str.present? ? str : to_s
    str.gsub!(/\s+/, " ").strip!
    @raw = str
    @parsed = StreetAddress::US.parse(str, informal: false)

    unless @parsed.nil? or @parsed.state.nil?
      parse_street
      self.city = @parsed.city
      self.state = AddressState.find_by(abbreviation: @parsed.state.upcase)
      self.postal = @parsed.postal_code
      @parsed
    end

    titleize
  end

  def raw
    @raw
  end

  def parsed
    @parsed
  end

  def parse_street
    unless parsed.nil?
      self.street1 = "#{parsed.number} #{parsed.prefix} #{parsed.street} #{parsed.street_type}".strip.gsub(/\s+/, " ")

      unless parsed.unit.nil?
        self.street2 = "#{parsed.unit_prefix} #{parsed.unit}".strip
      end
    end

    if (match = street1.match(/ \d+$/)) and street2.nil?
      self.street2 = match[0].strip
      self.street1.gsub!(/\d+$/, "").strip!
    end    
  end

  def titleize
    %w(street1 street2 street3 city).each do |field|
      value = send(field.to_sym)
      next unless value.is_a?(String)
      send(:"#{field}=", value.titleize)
    end

    self
  end

  def comparison_hash
    street1_hash + ":" + postal[0..4]
  end

  def street1_hash
    #street hash is concatenation of first 2-3 street1 parts, depending on whether there's a street prefix
    num = street_prefix? ? 2 : 1
    street1.split(" ")[0..num].join.downcase
  end

  def street_prefix?
    if parsed.nil?
      parts = street1.split(" ")
      return false if parts.count < 3
      # if second part of street1 is a direction and third part is not a street type
      %w(w n e s west north east west).include?(parts[1].downcase) and !StreetAddress::US::STREET_TYPES_LIST.keys.include?(parts[2].downcase)
    else
      !parsed.prefix.nil?
    end
  end

  def same_as?(address)
    return false unless postal and address.postal
    comparison_hash == address.comparison_hash
  end

  def street2_from(address)
    street2 = address.street2 if same_as?(address) and street2.blank? and address.street2.present?
  end
end