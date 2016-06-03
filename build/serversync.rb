#!/usr/bin/ruby
require 'net/ssh'
require 'net/sftp'
require 'fileutils'

class SiteSync

  attr_accessor :verbose, :server, :user, :passive

  def initialize(host, user, local_path, remote_path, options = {})
    @host = host
    @user = user
    @ignore = options[:ignore]
    @verbose = options[:verbose] || true
    @passive = options[:passive] || false
    @local_path = local_path
    @remote_path = remote_path
    @file_perm = options[:file_perm] || 0644
    @dir_perm = options[:dir_perm] || 0755
    push_dir @local_path, @remote_path
  end

  def push_dir(localpath, remotepath)
    log "Starting Sync"
    Net::SSH.start(@host, @user, :password => ENV["SECRET_CODE"]) do |ssh|
      log "Connecting"
      ssh.sftp.connect do |sftp|
        log "Connected"
        log "Starting Clear"

        files = sftp.dir.glob(remotepath, '**/*')
        files = files.map { |file| [file.name.count("/"), file.name] }
        files = files.sort.map { |file| file[1] }
        files = files.reverse
        files.each do |entry|
          f = entry
          f.gsub("#{localpath}", '')
          local = File.join localpath, f
          remote = "#{remotepath}/#{f}".gsub(/\/+/, '/')
          log "Removing #{remote}"
          unless File.exist?(local)
            if sftp.lstat!(remote).directory?
              log "Removed directory #{remote}"
              sftp.rmdir!(remote)
            else
              log "Removed file #{remote}"
              sftp.remove!(remote)
            end
          end
        end

        log "Finished Clear"
        log "Starting Upload"
        Dir.glob(File.join(localpath, '**', '*')) do |f|
          f.gsub!("#{localpath}", '')
          local = File.join localpath, f
          remote = "#{remotepath}/#{f}".gsub(/\/+/, '/')
          if local !~ /\/export\/(flash\/(haxe|obj)|.build)/
            if File.directory?(local)
              unless remote_file_exists?(sftp, remote)
                log "Creating Remote Directory #{remote}..."
                sftp.mkdir! remote
              end
            elsif File.file?(local)
              log "Pushed file #{remote}"
              sftp.upload! local, remote
              sftp.setstat(remote, :permissions => @file_perm)
            end
          end
        end
        log "Finished Upload"
      end


    end
    log "Finished Sync"
  end


  private
  def remote_file_exists?(sftp, remote_path)
    begin
    sftp.stat!(remote_path) do |response|
      return true if response.ok?
    end
    rescue Net::SFTP::StatusException
      return false
    end
  end

  def log(msg)
    puts msg if @verbose
  end

end

sync = SiteSync.new 'ssh.phx.nearlyfreespeech.net', 'seifertim_january', '_site', '/home/public'
