# -*- coding: utf-8 -*-
class CourseWare < ActiveRecord::Base
  include AnswerCourseWare::CourseWareMethods
  include CourseWareReadingModule

  attr_accessible :title, :desc, :url, :creator

  validates :title, :chapter, :creator,
            :presence => true
            
  belongs_to :chapter
  belongs_to :creator, :class_name => 'User'
  belongs_to :file_entity
  belongs_to :media_resource
  has_many :course_ware_readings

  scope :by_course, lambda {|course|
    joins(:chapter).where('chapters.course_id = ?', course.id)
  }

  scope :read_with_user, lambda {|user|
    joins(:course_ware_readings).where(%`
      course_ware_readings.read is true
        and
      course_ware_readings.user_id = #{user.id}
    `)
  }

  def link_file_entity(file_entity)
    path = "/课件/#{self.chapter.course.name}/#{file_entity.attach_file_name}"
    resource = MediaResource.put_file_entity(self.creator, path, file_entity)
    kind = file_entity.content_kind
    
    self.kind = kind
    self.file_entity = file_entity
    self.media_resource = resource
    self.save

    self
  end

  delegate :convert_success?, :to => :file_entity
  delegate :converting?, :to => :file_entity
  delegate :convert_failure?, :to => :file_entity
  delegate :ppt_images, :to => :file_entity

  FileEntity::EXTNAME_HASH.each do |key, value|
    delegate "is_#{key}?", :to => :file_entity
  end

  def is_web_video?
    ['youku'].include? self.kind
  end
end
