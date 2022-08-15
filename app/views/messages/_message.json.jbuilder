json.extract! message, :id, :images, :created_at, :updated_at
json.url message_url(message, format: :json)
json.images do
  json.array!(message.images) do |image|
    json.id image.id
    json.url url_for(image)
  end
end
