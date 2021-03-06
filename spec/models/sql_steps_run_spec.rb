require 'spec_helper'

describe SqlStep do
  before {
    @user = FactoryGirl.create(:user)
    @sql_step = FactoryGirl.create(:sql_step)

    @sql_step.run("create table articles (title varchar(200));", @user)

  }

  after {
    path = File.join(R::UPLOAD_BASE_PATH, 'sqlite_dbs', "user_#{@user.id}")
    FileUtils.rm_rf path
  }


  describe "正常SQL" do

    describe "查询语句" do
      before {
        @input = 'select * from articles'
        @query = @sql_step.run(@input, @user)
      }

      it "表记录为空" do
        @query[:result].should == []
      end

      it "exception 为空" do
        @query[:exception].should == nil
      end

      it "input 正常" do
        @query[:input].should == @input
      end

    end

    describe "插入语句" do
      before {
        @input = "INSERT INTO articles (title) VALUES ('title1')"
        @query = @sql_step.run(@input, @user)
      }


      it "1条表记录" do
        temp_query = @sql_step.run("select * from articles", @user)
        temp_query[:result].count.should == 1
      end

      it "exception 为空" do
        @query[:exception].should == nil
      end

      it "input 正常" do
        @query[:input].should == @input
      end

      describe "删除语句" do
        before {
          @input = "delete from articles"
          @query = @sql_step.run(@input, @user)
        }

        it "0条表记录" do
          temp_query = @sql_step.run("select * from articles", @user)
          temp_query[:result].count.should == 0
        end

        it "exception 为空" do
          @query[:exception].should == nil
        end

      end

    end

    

  end

  describe "错误SQL" do
    describe "查询语句" do
      before {
        @input = 'select * fr2om articles'
        @query = @sql_step.run(@input, @user)
      }

      it "表记录为空" do
        @query[:result].should == nil
      end

      it "exception 为空" do
        @query[:exception].should == "near \"fr2om\": syntax error"
      end

      it "input 正常" do
        @query[:input].should == @input
      end

    end
  end

  describe 'check' do
    before{
      @sql_step.rule = %`
      begin
        rows = db.execute("select * from articles")
      rescue Exception => e
        return false
      end

      return rows.count == 1
      `
      @sql_step.save!

      @query = @sql_step.run(@input, @user)
      temp_query = @sql_step.run("select * from articles", @user)
    }

    it{
      input = "INSERT INTO articles (title) VALUES ('title1')"
      @sql_step.check(input, @user).should == true
    }

    it{
      input = "select * from articles"
      @sql_step.check(input, @user).should == false
    }
  end
end