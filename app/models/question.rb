class Question < ActiveRecord::Base
  attr_accessible :title, :content, :chapter_id, :ask_to_user_id

  belongs_to :creator, :class_name => 'User', :foreign_key => :creator_id
  belongs_to :ask_to, :class_name => 'User', :foreign_key => :ask_to_user_id
  belongs_to :chapter
  has_many :answers
  has_many :follows, :class_name => 'QuestionFollow', :foreign_key => :question_id

  validates :creator, :title, :content, :presence => true

  default_scope order('id desc')

  scope :today, :conditions => ['DATE(created_at) = ?',Time.now.to_date]
  scope :by_course, lambda {|course|
    ids = course.chapter_ids.to_a
    if ids.blank?
      {:conditions => 'chapter_id = -1'}
    else
      {:conditions => {:chapter_id => ids}}
    end
  }

  after_save :follow_by_creator

  def follow_by_creator
    self.creator.follow_question(self)
  end

  # 记录用户活动
  record_feed :scene => :questions,
                        :callbacks => [ :create, :update]

  def answered_by?(user)
    return false if user.blank?
    return self.answer_of(user).present?
  end

  def answer_of(user)
    return nil if user.blank?
    return self.answers.by_user(user).first
  end

  def followed_by?(user)
    self.follow_by_user(user).persisted?
  end

  def follow_by_user(user)
    self.follows.by_user(user).first || self.follows.build(:user => user)
  end

  module UserMethods
    def self.included(base)
      base.has_many :questions, :foreign_key => 'creator_id'
    end
  end
end