bucket = ARGV[0]
region = ARGV[1]

if (ARGV.length < 2)
  puts "Please specify the bucket as the first parameter"
  puts "Please specify the aws region as the second parameter"
  exit(1)
end

cron_line = "20 3 * * * /home/ubuntu/.rbenv/shims/ruby take_backup.rb #{bucket} #{region}"

## Assumes nothing else already exists in crontab
`echo "#{cron_line}" | crontab -`
