# Active Storage

https://edgeguides.rubyonrails.org/active_storage_overview.html
After enabling `image_processing` and installing active_storage tables
```
bin/rails active_storage:install
```
it will create 3 tables:
* active_storage_blobs: actual `filename`, `metadata`, `checksum`
* active_storage_attachment: belongs to blog and it belongs polymorphic to any
  record (it is a join table). It has a `name` field
* active_storage_variant_records:

Services are defined in
```
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```
and used in app
```
# config/environments/development.rb
  config.active_storage.service = :local
```

# S3

Use different bucket names for different envs.
Enable 
