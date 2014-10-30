require 'posix/spawn'
require 'pp'
require 'sys/proctable'
require 'shellwords'

include Sys
include POSIX::Spawn

class LastPassCLI

  def initialize(opts = {})
    @lpass_path = opts[:path]||`which lpass`
    @lpass_user = opts[:user]||nil
    @lpass_pass = opts[:password]||ENV['LASTPASS_PASSWORD']
    login unless agent_running?
    @folders = Array.new
    load_ls
  end

  def agent_running?
    a = ProcTable.ps
    a.each do |p|
      if p.cmdline.to_s.match(/lpass \[agent\]/)
        return true if Process.kill 0, p.pid
      end
    end
    return false
  end

  def login
    ldp_set = false
    if ENV['LPASS_DISABLE_PINENTRY'].nil?
      ENV['LPASS_DISABLE_PINENTRY'] = 1
      ldp_set=true
    end
    # I tried this with popen4, and it hung, This makes it work, I'll make it right later...
    system("echo #{@lpass_pass} | #{@lpass_path} login #{@lpass_user}")
  end

  def logout
    pid, input, output, errors = popen4(@lpass_path, 'logout')
    input.write("y\n")
    input.close
    # puts output.read
  end

  def folder(name = nil)
    @folders.each do |folder|
      return folder if folder.name == name
    end
    return nil
  end

  def load_ls
    pid, input, output, errors = popen4(@lpass_path, 'ls')
    input.close
    output.read.split(/\n/).each do |line|
      match = line.match(/([^\/]*)\/(.*)\[id: (.*)\]/)
      unless match.nil?
        folder_name = match[1]
        key_name = match[2]
        id = match[3]
        if folder(folder_name).nil?
          @folders.push(LastPassFolder.new(:name => folder_name))
        end
        unless folder(folder_name).nil?
          folder(folder_name).add(:name => key_name,:id => id)
        end
      end
    end
  end

  def folders
    @folders
  end


end

################################################################################
class LastPassFolder
  def initialize(opts={})
    @name = opts[:name] || nil
    @entries = Array.new()
  end

  def add(opts = {})
    name = opts[:name]
    id = opts[:id]
    unless name == " "
      @entries.push(LastPassEntry.new(:name => name, :id => id)) if entry(name).nil?
    end
  end

  def entry(name = nil)
    @entries.each do |entry|
      return entry if entry.name == "#{name} "
    end
    return nil
  end

  def name
    @name
  end

  def entries
    @entries
  end

end

################################################################################
class LastPassEntry
  def initialize(opts={})
    @name = opts[:name]
    @id = opts[:id]
    @dirty = false
  end

  # lpass show [--sync=auto|now|no] [--clip, -c] [--all|--username|--password|--url|--notes|--field=FIELD|--id|--name] {UNIQUENAME|UNIQUEID}
  def get( key = nil )
    case key
    when nil
      key_arg = '--all'
    when 'all'
      key_arg = '--all'
    when 'username'
      key_arg = '--username'
    when 'password'
      key_arg = '--password'
    when 'url'
      key_arg = '--url'
    when 'notes'
      key_arg = '--notes'
    when 'id'
      key_arg = '--id'
    when 'name'
      key_arg = '--name'
    else
      key_arg = "--field=#{key}"
    end
    pid, input, output, errors = popen4( Shellwords.join([ @lpass_path, 'show', "#{key_arg}", @id ]) )
    input.close
    document = output.read
    return document
  end

  def all
    get('all')
  end

  def username(username=nil)
    get('username')
  end

  def password(password=nil)
    get('password')
  end

  def url(url=nil)
    get('url')
  end

  def notes(notes=nil)
    get('notes')
  end

  def id
    @id
  end

  def name
    @name
  end

  def fields
    response = get('all')
  end

end

