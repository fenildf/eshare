require "spec_helper"

describe Answer do
  describe 'Validation' do
    before {
      @user = FactoryGirl.create(:user)

      @answer = FactoryGirl.create(:answer)
      @sum = @answer.vote_sum
      
      @vote = AnswerVote.new(:creator_id => @user.id)
      @vote.answer = @answer

    }

    it "总分数要加1" do
      @vote.kind = 'VOTE_UP'
      @vote.save

      (@answer.vote_sum - @sum).should == 1
    end

    it "总分数要减1" do
      @vote.kind = 'VOTE_DOWN'
      @vote.save

      (@answer.vote_sum - @sum).should == -1
    end


    it "up方法, 总分数要加1" do
      @vote.up

      (@answer.vote_sum - @sum).should == 1
    end

    it "down方法, 总分数要减1" do
      @vote.down

      (@answer.vote_sum - @sum).should == -1
    end


  end
end