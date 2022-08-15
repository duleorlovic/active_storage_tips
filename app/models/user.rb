class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 150]
    attachable.variant :medium, resize_to_limit: [500, 500]
  end
end
