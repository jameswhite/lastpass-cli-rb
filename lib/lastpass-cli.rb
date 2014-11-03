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

  def reinitialize(opts = {})
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
    sleep 5 # terrible
    pid, input, output, errors = popen4(@lpass_path, 'logout')
    input.write("y\n")
    input.close
    output.read
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
      match = line.match(/([^\/]*)\/(\S.*\S)\s+\[id: (.*)\]/)
      unless match.nil?
        folder_name = match[1]
        key_name = match[2]
        id = match[3]
        if folder(folder_name).nil?
          @folders.push(LastPassFolder.new(:name => folder_name, :cli => self))
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

  def path
    @lpass_path
  end

end

################################################################################
class LastPassFolder
  def initialize(opts={})
    @name = opts[:name] || nil
    @cli = opts[:cli] || nil
    @entries = Array.new()
  end

  def add(opts = {})
    name = opts[:name]
    @command = opts[:name]
    id = opts[:id]
    unless name == ''
      @entries.push(LastPassEntry.new(:name => name, :id => id, :folder => self)) if entry(name).nil?
    end
  end

  def entry(name = nil)
    @entries.each do |entry|
      # puts "[#{entry.name}] == [#{name}]"
      return entry if entry.name == "#{name}"
    end
    return nil
  end

  def create(entry_name)
    pid, input, output, errors = popen4( Shellwords.join([ cli.path, 'edit', "--name", "--non-interactive", "#{@name}/#{entry_name}" ]) )
    input.write("#{@name}/#{entry_name}\n")
    document = output.read
    cli.reinitialize
  end

  def entrybyid(id = 0)
    entries!
    @entries.each do |entry|
      puts "-=[#{entry.name} #{entry.id}]=-"
      return entry if entry.id == id
    end
    return nil
  end

  def name
    @name
  end

  def entries
    @entries
  end

  def entries!
    cli.load_ls
    @entries = cli.folder(@name).entries
  end

  def cli
    @cli
  end

end

################################################################################
class LastPassEntry
  def initialize(opts={})
    @name = opts[:name].chomp
    @folder = opts[:folder]
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
    pid, input, output, errors = popen4( Shellwords.join([ @folder.cli.path, 'show', "#{key_arg}", @id ]) )
    input.close
    document = output.read
    return document
  end

  def set( key = nil, data = nil )
    case key
    when nil
      return nil
    when 'all'
      return nil
    when 'username'
      key_arg = '--username'
    when 'password'
      key_arg = '--password'
    when 'url'
      key_arg = '--url'
    when 'notes'
      key_arg = '--notes'
    when 'name'
      key_arg = '--name'
    else
      key_arg = "--field=#{key}"
    end
    pid, input, output, errors = popen4( Shellwords.join([ @folder.cli.path, 'edit', "#{key_arg}", "--non-interactive", "--sync=now",  @id ]) )
    input.write("#{data}\n")
    input.close
    document = output.read
    return document
  end

  def delete
    pid, input, output, errors = popen4( Shellwords.join([ @folder.cli.path, 'rm', @id ]) )
    input.close
    document = output.read
    # this doesn't sync automatically.
    pid, input, output, errors = popen4( Shellwords.join([ @folder.cli.path, 'sync' ]) )
    input.close
    document = output.read
    return nil
  end

  def all
    get('all')
  end

  def username(username=nil)
    set('username',username) unless username.nil?
    folder.cli.reinitialize
    get('username')
  end

  def password(password=nil)
    set('password',password) unless password.nil?
    folder.cli.reinitialize
    get('password')
  end

  def url(url=nil)
    set('url',url) unless url.nil?
    folder.cli.reinitialize
    get('url')
  end

  def notes(notes=nil)
    set('notes',notes) unless notes.nil?
    folder.cli.reinitialize
    get('notes')
  end

  def folder(folder=nil)
    return folder.name
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

  def folder
    @folder
  end

  def foldername
    @folder
  end

end

