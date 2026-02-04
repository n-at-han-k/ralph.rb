# frozen_string_literal: true

# Copyright (c) 2025 Nathan Kidd <nathankidd@hey.com>. All rights reserved.
# SPDX-License-Identifier: Proprietary

require 'json'
require 'time'

# Represents a single todo item with full feature support
class TodoItem
  attr_reader :id, :title, :description, :created_at, :updated_at
  attr_accessor :completed, :priority, :due_date, :tags, :category

  PRIORITIES = { low: 1, medium: 2, high: 3, urgent: 4 }.freeze

  def initialize(title:, description: nil, priority: :medium, due_date: nil, tags: [], category: nil, id: nil)
    @id = id || generate_id
    @title = title
    @description = description
    @completed = false
    @priority = priority
    @due_date = due_date
    @tags = tags || []
    @category = category
    @created_at = Time.now
    @updated_at = Time.now
  end

  def complete!
    if @completed
      @completed = false
    else
      @completed = true
    end
    @updated_at = Time.now
  end

  def completed?
    @completed
  end

  def overdue?
    if @due_date && !@completed
      Time.parse(@due_date) < Time.now
    else
      false
    end
  end

  def due_soon?(hours: 24)
    if @due_date && !@completed
      due_time = Time.parse(@due_date)
      due_time > Time.now && due_time < Time.now + (hours * 3600)
    else
      false
    end
  end

  def priority_value
    PRIORITIES[@priority] || PRIORITIES[:medium]
  end

  def add_tag(tag)
    unless @tags.include?(tag)
      @tags << tag
      @updated_at = Time.now
    end
  end

  def remove_tag(tag)
    if @tags.delete(tag)
      @updated_at = Time.now
    end
  end

  def matches_filter?(query: nil, tags: nil, category: nil, completed: nil, priority: nil)
    if query && !matches_query?(query)
      false
    elsif tags && (tags & @tags).empty?
      false
    elsif category && @category != category
      false
    elsif !completed.nil? && @completed != completed
      false
    elsif priority && @priority != priority
      false
    else
      true
    end
  end

  def to_h
    {
      id: @id,
      title: @title,
      description: @description,
      completed: @completed,
      priority: @priority,
      due_date: @due_date,
      tags: @tags,
      category: @category,
      created_at: @created_at.iso8601,
      updated_at: @updated_at.iso8601
    }
  end

  def self.from_h(hash)
    new(
      id: hash['id'],
      title: hash['title'],
      description: hash['description'],
      priority: hash['priority']&.to_sym || :medium,
      due_date: hash['due_date'],
      tags: hash['tags'] || [],
      category: hash['category']
    ).then do |item|
      item.instance_variable_set(:@completed, hash['completed'] || false)
      item.instance_variable_set(:@created_at, Time.parse(hash['created_at']))
      item.instance_variable_set(:@updated_at, Time.parse(hash['updated_at']))
      item
    end
  end

  private

  def generate_id
    "#{Time.now.to_i}-#{rand(10000)}"
  end

  def matches_query?(query)
    query_lower = query.downcase
    if @title.downcase.include?(query_lower)
      true
    elsif @description && @description.downcase.include?(query_lower)
      true
    elsif @tags.any? { |tag| tag.downcase.include?(query_lower) }
      true
    elsif @category && @category.downcase.include?(query_lower)
      true
    else
      false
    end
  end
end
