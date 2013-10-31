class Group < ActiveRecord::Base
	belongs_to :campaign, inverse_of: :groups
	belongs_to :default_network, class_name: "List", inverse_of: :groups
	has_many :users, through: :group_users, inverse_of: :groups
end
