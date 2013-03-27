class AnswerVotesController < ApplicationController
  before_filter :pre_load

  def pre_load
    @answer = Answer.find(params[:answer_id]) if params[:answer_id]
    @answer_vote = AnswerVote.find(params[:id]) if params[:id]
  end

  def setup(kind)
    if @answer.has_voted_by?(current_user)
      return @answer.answer_votes.by_user(current_user).first
    end
    @answer_vote = @answer.answer_votes.create(:creator => current_user, :kind => kind)
  end
  private :setup


  def up
    @answer_vote = setup('VOTE_UP')

    @answer_vote.up

    redirect_to :back
  end

  def down
    @answer_vote = setup('VOTE_DOWN')
    @answer_vote.down

    redirect_to :back
  end

  def destroy
    @answer_vote.destroy

    redirect_to :back
  end

end