# https://github.com/duleorlovic/minitest_rails/blob/main/db/seeds.rb
logger = Logger.new($stdout)
Rake::Task['db:fixtures:load'].invoke
# https://github.com/rails/rails/blob/master/activerecord/lib/active_record/fixtures.rb
already_proccessed = []
Dir.entries("#{Rails.root}/test/fixtures").each do |file_name|
  next unless file_name.last(4) == '.yml'

  # foreach will read line by line
  File.foreach("#{Rails.root}/test/fixtures/#{file_name}").grep /LABEL/ do |line|
    column = line.match(/(\w*):.*\$LABEL/)[1]
    klass = file_name[0..-5].singularize.camelize
    next if already_proccessed.include? "#{klass}-#{column}"

    logger.info "klass=#{klass} column=#{column}"
    klass.constantize.find_each do |item|
      item.send "#{column}=", item.send(column).humanize
      item.save # email can not be saved with spaces
    end
    already_proccessed.append "#{klass}-#{column}"
  end
end
logger.info 'db:seed and db:fixtures:load completed'
