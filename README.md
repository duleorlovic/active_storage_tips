# Active Storage

https://edgeguides.rubyonrails.org/active_storage_overview.html
After enabling `image_processing` and installing active_storage tables
```
rails active_storage:install
```
it will create 3 tables:
* active_storage_blobs: actual `filename`, `metadata`, `checksum`
* active_storage_attachment: belongs to blob and it belongs polymorphic to any
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

Available services:
* Disk
* S3
* GCS
* AzureStorage
* Mirror

# S3

Enable sdk (otherwise error *Missing service adapter for "S3"*)
```
# Gemfile
gem "aws-sdk-s3", require: false
```
User needs to have: s3:ListBucket, s3:PutObject, s3:GetObject, and
s3:DeleteObject permissions.
AdministratorAccess covers them all.

Use different bucket names for different envs.
If you want to enable public access than you need to have `s3:PutObjectAcl`
permission and change service
```
aws:
  service: S3
  access_key_id: ""
  secret_access_key: ""
  bucket: ""
  region: "" # e.g. 'us-east-1'

public_aws:
  service: aws
  public: true
```

Bucket name can not contain underscore so only hyphen ( minus) is allowed (avoid
dot unless you are using bucket as website).

# Models


```
rails generate scaffold User name avatar:attachment
rails generate scaffold Message content images:attachments
```

You can attach manually
```
@message.images.attach(io: File.open('/path/to/file'), filename: 'file.pdf', content_type: 'application/pdf')

```

Attachment will be automatically deleted when object is deleted.
You can manually trigger:
```
user.avatar.purge
user.avatar.purge_later
```
You can check the number of blobs in db
```
ActiveStorage::Blob.all.size
ActiveStorage::VariantRecord.all
ActiveStorage::Attachment.all
```

To get the file path you can use `url_for` and `rails_blob_path`
```
url_for(user.avatar)
# => /rails/active_storage/blobs/redirect/:signed_id/my-avatar.png
# and this will redirecto to aws

rails_blob_path(user.avatar, disposition: "attachment")
# this is the same, just added ?disposition parameter
# => /rails/active_storage/blobs/redirect/:signed_id/my-avatar.png?disposition=attachment

# outside of controller view context
Rails.application.routes.url_helpers.rails_blob_path(user.avatar, only_path: true)
# => /rails/active_storage/blobs/redirect/:signed_id/my-avatar.png

# actual url on service, not available for Disk service, expires after 300 seconds
user.avatar.url
# => https://active-storage-tips-development-env.s3.amazonaws.com/7hep8p72xmlcmzrei0w4nmdk709w?response-content-disposition=inline%3B%20filename%3D%22 .... X-Amz-Date=20220728T132301Z&X-Amz-Expires=300&X-Amz-SignedHeaders=host&X-Amz-Signature=9c4c49f23d...

rails_storage_proxy_path(@user.avatar)
# => /rails/active_storage/blobs/proxy/:signed_id/my-avatar.png
```

# Variants

https://edgeguides.rubyonrails.org/active_storage_overview.html#displaying-images-videos-and-pdfs
By default new variant proccessor is vips instead of MiniMagick
https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#active-storage-default-variant-processor-changed-to-vips
```
# config/environments/development.rb
config.active_storage.variant_processor = :vips
# or revert to old
config.active_storage.variant_processor = :mini_magick
```
so you need to install
```
# linux
apt install libvips
# mac
brew install vips
```

User -> Attachment -> Blob
        | .variant is called on attachment (avatar.variant) but variant contains reference to original blob_id
        -> VariantRecord -> Attachment -> Blob
        -> VariantRecord -> Attachment -> Blob

For each requested variant image, new `ActiveStorage::VariantRecord` is created.
Variation config is digested so if you update, new variations will be created
for that original blob_id. Each variation means new `ActiveStorage::Blob` and
`ActiveStorage::Attachment` that is attached to that variant is created.
So when you delete user, all attachments and their blobs are deleted, also
all variant_records for each blob (so variant_record -> attachment is also
deleted and so variant_record -> attachment -> blob).
Attachment is polymorhic to user and variant_record.
```
ActiveStorage::Attachment.all
[#<ActiveStorage::Attachment: id: 12, name: "avatar", record_type: "User", record_id: 7, blob_id: 12, created_at: Thu, 28 Jul 2022 14:10:43.499000000 UTC +00:00>,
 #<ActiveStorage::Attachment: id: 13, name: "image", record_type: "ActiveStorage::VariantRecord", record_id: 4, blob_id: 13, created_at: Thu, 28 Jul 2022 14:10:50.893981000 UTC +00:00>]

ActiveStorage::VariantRecord.all
[#<ActiveStorage::VariantRecord: id: 4, blob_id: 12, variation_digest: "o6FvqsFkA8vhEYgai/NTHqoEOlQ=">,
 #<ActiveStorage::VariantRecord: id: 5, blob_id: 15, variation_digest: "o6FvqsFkA8vhEYgai/NTHqoEOlQ=">,
 #<ActiveStorage::VariantRecord: id: 6, blob_id: 15, variation_digest: "58nLvjR5lLpeOdoWw8+s844W40I=">,
```

Variants are created for all services (Disk, S3).

First time it is requested it will download a file, proccess and upload as
variant.
```
url_for user.avatar.variant(resize_to_limit: [100,100])

# instead of rails_blob_path for attachment, for variant you need to use:
Rails.application.routes.url_helpers.rails_representation_url(user.avatar.variant(resize_to_limit: [100,100]))
```

To define variants you can use
```
class MemberPicture < ApplicationRecord
  has_one_attached :active_storage_attachment do |attachable|
    # actual size is 50x50 but in case of retina displays we use double size
    attachable.variant :icon, resize_to_limit: [100, 100]
    attachable.variant :thumb, resize_to_limit: [400, 400]
    attachable.variant :modal, resize_to_limit: [1000, 1000]
    attachable.variant :thumb_blurred, resize_to_limit: [400, 400], gaussian_blur: "0x3" # 0x1 ... 0x10
  end
```

When you upload pdf instead of image, you will see
`ActiveStorage::InvariableError` so you have to limit input field accepted files
like `data-dropzone-accepted-files='image/jpeg,image/png'`.
Even in that case, file can be renamed `my.pdf.jpeg` so need to detect check if
file is variable:
```
    <% if user.avatar.variable? %>
      <%= image_tag user.avatar.variant(:thumb) %>
    <% else %>
      <%# send some admin notification to inspect the file %>
      Can not generate variant
    <% end %>
```

When avatar does not exists we try to show we will see the error
```
<%= url_for user.avatar %>

ActionView::Template::Error: undefined method `persisted?' for nil:NilClass
```
solve it with a check if avatar is present
```
<% if user.avatar.attached? %>
  <%= url_for user.avatar %>
<% end %>
```

# Test

Use fixtures for blobs and attachments
This works in tests env, for example in system test but also in seed for
development.
Blob requires a file to exists on storage/aa/bb/aabbWNGW1VrxZ8Eu4zmyw13A
In system test files will be uploaded to tmp/storage but preview also search
storage so it is enough to copy there
```
mkdir -p storage/aa/bb
cp test/fixtures/files/rails.jpg  storage/aa/bb/aabbWNGW1VrxZ8Eu4zmyw13A
```

For error
```
rails db:seed
rails aborted!
Foreign key violations found in your fixture data. Ensure you aren't referring to labels that don't exist on associations.
/Users/dule/web-tips/active_storage_tips/db/seeds.rb:3:in `<main>'
```
solution is to reset db
```
rails db:migrate:reset
```

# Action Text

https://edgeguides.rubyonrails.org/action_text_overview.html
Install
```
rails action_text:install
```


# CDN

https://edgeguides.rubyonrails.org/active_storage_overview.html#putting-a-cdn-in-front-of-active-storage
