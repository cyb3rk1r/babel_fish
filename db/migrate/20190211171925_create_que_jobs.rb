require 'que'
class CreateQueJobs < ActiveRecord::Migration[5.2]
  def self.up
    Que.migrate! version: 4
  end

  def self.down
    Que.migrate! version: 2
  end
end