json.extract! user, :id, :name, :created_at, :updated_at
json.url user_url(user, format: :json)
json.avatar url_for(user.avatar)
