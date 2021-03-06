class CourseWareReading < ActiveRecord::Base
  include CourseWareReadingDelta::CourseWareReadingMethods

  attr_accessible :user, :read, :read_count, :course_ware

  belongs_to :user
  belongs_to :course_ware
  belongs_to :chapter # 为了查询方便，冗余存储了
  belongs_to :course # 为了查询方便，冗余存储了

  validate  :validate_read_status
  def validate_read_status
    total_count = course_ware.total_count || 0
    rc = read_count || 0

    return true if rc == 0

    if rc > total_count
      errors.add(:base, '阅读进度超出上限')
      return false
    end

    if !!read == false && rc == total_count
      errors.add(:base, '阅读已完成，但尝试标记为未读')
      return false
    end
  end

  scope :by_user, lambda { |user| { :conditions => ['course_ware_readings.user_id = ?', user.id] } }
  scope :by_read, lambda { |read| { :conditions => ['course_ware_readings.read = ?', read] } }

  before_save :set_default_and_save_delta

  def set_default_and_save_delta
    set_default_read_count_and_percent
    record_reading_delta
    set_chapter_and_course
  end

  def set_default_read_count_and_percent
    self.read_count = 0 if self.read_count.blank?
    self.read_percent = _get_percent
  end

  # 冗余地保存课程和章节
  def set_chapter_and_course
    return true if self.course_ware.blank?
    if (chapter = self.course_ware.chapter).present?
      self.chapter = chapter
      if (course = chapter.course).present?
        self.course = course
      end
    end

    return true
  end

  def _get_percent
    total_count = self.course_ware.total_count

    if total_count.blank? || total_count == 0
      return self.read ? '100%' : '0%'
    end

    p = [(self.read_count.to_f * 100 / total_count).round, 100].min
    return "#{p}%"
  end

  # 记录用户活动
  record_feed :scene => :course_ware_readings,
                        :callbacks => [:create, :update],
                        :before_record_feed => lambda { |course_ware_reading, callback_type|
                          return false if !course_ware_reading.read_count_changed?

                          if callback_type == :update
                            last_feed = Feed.by_user(course_ware_reading.user).first
                            return true if last_feed.blank?
                            return false if last_feed.to == course_ware_reading
                          end

                          return true
                        }

  module UserMethods
    extend ActiveSupport::Concern

    included do
      has_many :course_ware_readings
      has_many :joined_courses, :through => :course_ware_readings, :source => :course, :uniq => true
    end

    module ClassMethods
      # 返回综合学习进度最多的前若干名用户
      def top_study_users(count = 3)
        sql = %~
          SELECT users.*, SUM(course_ware_readings.read_percent) AS SUM
          FROM users
          LEFT JOIN course_ware_readings
          ON users.id = course_ware_readings.user_id
          WHERE users.roles_mask <> 1
          GROUP BY users.id
          ORDER BY SUM DESC
          LIMIT #{count}
        ~

        return User.find_by_sql sql
      end
    end

    # 推荐关注的用户，优先feed比较多的用户
    def recommend_friends(count = 3)
        sql = %~
          SELECT NF.*
          FROM

          (
            SELECT users.*, Q.C AS C
            FROM
            (
              SELECT feeds.user_id, COUNT(1) AS C
              FROM feeds
              GROUP BY feeds.user_id
            ) AS Q

            RIGHT JOIN users ON users.id = Q.user_id
            WHERE users.roles_mask <> 1 AND users.id <> #{self.id}
            # 发过 feed 的人，不是管理员，不是本人的人
          ) AS R

          JOIN 

          (
            SELECT users.*
            FROM
            (
              SELECT users.* 
              FROM users 
              INNER JOIN follows ON users.id = follows.following_user_id 
              WHERE follows.user_id = #{self.id}
            ) AS F
            # 关注的人

            RIGHT JOIN users ON users.id = F.id
            WHERE F.id IS NULL
            # 尚未关注的人
          ) AS NF

          ON R.id = NF.id
          ORDER BY R.C DESC
          LIMIT #{count}
        ~

        return User.find_by_sql sql
    end

    # 正在学习的课程
    def learning_courses
      joined_courses
    end

    # 正在学习的课程中最常用的tag
    def learning_tags(count = 5)
      sql = %~
        SELECT tags.* 
        FROM 
        (
          SELECT courses.* 
          FROM courses 
          INNER JOIN course_ware_readings ON course_ware_readings.course_id = courses.id
          WHERE (course_ware_readings.user_id = #{self.id}) 
          GROUP BY courses.id 
          ORDER BY courses.id desc
        ) AS Q

        JOIN taggings ON taggings.taggable_id = Q.id AND taggings.taggable_type = 'Course'
        JOIN tags ON taggings.tag_id = tags.id
        GROUP by tags.id
        LIMIT #{count}
      ~

      # 这个SQL和上面的区别是，这个是RIGHT JOIN以补全指定数量
      sql2 = %~
        SELECT tags.*, COUNT(tags.id) as C

        FROM 

        (
        SELECT courses.* 
        FROM courses 
        INNER JOIN course_ware_readings ON course_ware_readings.course_id = courses.id
        WHERE (course_ware_readings.user_id = #{self.id}) 
        GROUP BY courses.id 
        ORDER BY courses.id desc
        ) AS Q

        JOIN taggings ON taggings.taggable_id = Q.id AND taggings.taggable_type = 'Course'
        RIGHT JOIN tags ON taggings.tag_id = tags.id
        GROUP BY tags.id
        ORDER BY C DESC
        LIMIT #{count}
      ~

      Tag.find_by_sql sql2
    end

    def advise_courses(count = 5)
      sql = %~
        SELECT NSC.* 
        FROM
        (
          SELECT tags.*, COUNT(tags.id) as C
          FROM 
          (
            SELECT courses.* 
            FROM courses 
            INNER JOIN course_ware_readings ON course_ware_readings.course_id = courses.id 
            WHERE (course_ware_readings.user_id = #{self.id}) 
            GROUP BY courses.id
          ) AS Q
          # 学过的课程

          JOIN taggings ON taggings.taggable_id = Q.id AND taggings.taggable_type = 'Course'
          RIGHT JOIN tags ON taggings.tag_id = tags.id
          GROUP BY tags.id
          ORDER BY C DESC
        ) AS QQ
        # 常学习的关键词

        JOIN taggings ON taggings.tag_id = QQ.id
        JOIN (
          SELECT courses.* 
          FROM
          (
            SELECT courses.* 
            FROM courses
            INNER JOIN course_ware_readings ON course_ware_readings.course_id = courses.id
            WHERE (course_ware_readings.user_id = #{self.id}) 
            GROUP BY courses.id 
          ) AS SC
          # 学过的课程

          RIGHT JOIN courses ON courses.id = SC.id
          WHERE SC.id IS NULL
          GROUP BY courses.id 
        ) AS NSC
        # 没学过的课程

        ON taggings.taggable_id = NSC.id AND taggings.taggable_type = 'Course'
        GROUP BY NSC.id
        ORDER BY QQ.C DESC
        LIMIT #{count}
      ~

      Course.find_by_sql sql
    end
  end
end
