# -*- coding: utf-8 -*-
class IndexController < ApplicationController
  def index
    if !user_signed_in?
      return redirect_to '/account/sign_in'
    end

    if current_user.is_admin?
      return redirect_to "/admin"
    end
    
    redirect_to '/courses'
  end

  def dashboard
    # 教师和学生的工作台页面
  end

  def plan
    # 学习计划和教学计划页面
  end
end
