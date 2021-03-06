# coding: utf-8

require 'logger'
require File.expand_path('../../ohajiki', __FILE__)
require File.expand_path('../config', __FILE__)
require File.expand_path('../repo', __FILE__)

module Ohajiki 
  class Service 
    def initialize
      @log = Logger.new(File.expand_path(Config::LOG_PATH))
      @interval_sec = Config::SYNC_INTERVAL_SEC 

      dir_path = File.expand_path(Config::SYNC_DIR_PATH) 
      FileUtils.mkdir_p dir_path
      @repo = fetch_repository(dir_path)
    rescue => e
      @log.error "init: #{e.message}"
      raise InitializeError
    end 

    def fetch_repository(dir_path)
      unless Repo.exist? dir_path
        Repo.init(dir_path) do
          remote_add('origin', Config::REMOTE_REPO_URL)
          pull!
        end
      else
        Repo.new dir_path
      end
    end

    def start
      @log.info "start service"
      loop do 
        sync
        update
        sleep @interval_sec
      end
    end

    def sync 
      unless @repo.latest? 
        @log.info "pull #{@repo.remote_head_id}"
        @repo.reset_hard_head!
        @repo.pull!
      else
        @log.info "repository latest"
      end
    rescue => e 
      @log.error "sync: #{e.message}"
    end

    def update
      @repo.add_stage! if @repo.file_changed? and @repo.file_added?
      message = "push #{@repo.changed_count} files"
      if @repo.commit_all!
        @log.info message
        @repo.push!
      else
        @log.info "no changed"
      end
    rescue => e
      @log.error "update: #{e.message}"
    end
  end
end
