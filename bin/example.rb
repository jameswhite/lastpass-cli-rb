#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), "../lib")
require 'lastpass-cli'

lpc = LastPassCLI.new(:path => "#{ENV['HOME']}/bin/lpass", :user => ENV['LASTPASS_USERNAME'], :password => ENV['LASTPASS_PASSWORD'])
lpc.folders.each do |folder|
  puts folder.name
  lpc.folder(folder.name).entries.each do |entry|
     puts "  #{entry.name} #{entry.id}"
  end
end

entry = lpc.folder('Secure Notes').entry("AWS IAM: someuser@example.org")
if entry.nil?
  lpc.folder('Secure Notes').create("AWS IAM: someuser@example.org")
  entry = lpc.folder('Secure Notes').entry("AWS IAM: someuser@example.org")
end

entry.url("https://example.signin.aws.amazon.com/console")
entry.username("someuser@example.org")
entry.password("Bob Loblaw's Law Blog")
entry.notes("Console URL: https://github.signin.aws.amazon.com/console
Access Key ID: ADEADBEEFFACADEBEADE
Secret Access Key: This/Is/My/Secret/Key/There/Are/Many/Lik")

puts "id       => #{entry.id}"
puts "url      => #{entry.url}"
puts "name     => #{entry.name}"
puts "folder   => #{entry.folder.name}"
puts "username => #{entry.username}"
puts "password => #{entry.password}"
puts "notes:"
puts "--------------------------------------------------------------------------------"
puts "#{entry.notes}"
puts "--------------------------------------------------------------------------------"

entry.delete
lpc.logout

