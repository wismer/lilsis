class PoliticalFundraising < ActiveRecord::Base
  include SingularTable

  belongs_to :entity, inverse_of: :political_fundraising
end