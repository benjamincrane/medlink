class ResponsesController < ApplicationController
  before_filter :initialize_response, only: [:new, :create]

  # Bullet doesn't seem to realize that we _are_ eager loading phones?
  around_action :skip_bullet, only: [:index]
  def index
    authorize :user, :respond?
    @responses = sort_table archived(accessible_responses), sort_model: User, per_page: 10
  end

  def new
    authorize :user, :respond?
    @orders  = sort_table @user.orders.without_responses.includes(:supply, request: :reorder_of)
    @history = sort_table @user.orders.with_responses.includes(:supply)
  end

  def create
    authorize :user, :respond?
    if orders = params[:orders]
      OrderResponder.
        new(responded_by: current_user, response: @response).
        respond response_params, orders
      redirect_to manage_orders_path, flash:
        { success: I18n.t!("flash.response.sent", user: @user.name) }
    else
      redirect_to manage_orders_path, flash:
        { error: I18n.t!("flash.response.none_selected") }
    end
  end

  def show
    @response = Response.find params[:id]
    @user     = @response.user
    authorize @response
  end

  def cancel
    response = Response.find params[:id]
    authorize response
    response.cancel!
    redirect_to responses_path(redir_params), flash:
      { success: I18n.t!("flash.response.cancelled") }
  end
  def reorder
    response = Response.find params[:id]
    authorize response
    response.reorder! by: current_user
    redirect_to responses_path(redir_params), flash:
      { success: I18n.t!("flash.response.reordered") }
  end
  def redir_params
    { responses: params[:responses], page: params[:page] }
  end
  helper_method :redir_params

  def mark_received
    response = Response.find params[:id]
    authorize response
    response.mark_received! by: current_user
    if response.user_id != current_user.id
      flash[:notice] = I18n.t!("flash.response.archived")
    end
    redirect_to :back
  end

  def flag
    response = Response.find params[:id]
    authorize response
    response.flag!
    redirect_to :back
  end


  private # -----

  def initialize_response
    @user = User.find params[:user_id]
    authorize @user, :respond?
    @response = Response.new user: @user, country: @user.country
  end

  def response_params
    params.require(:response).permit :extra_text
  end

  def accessible_responses
    current_user.country.responses.includes(user: :phones, orders: :supply)
  end

  def archived responses
    if params[:responses] == "archived"
      responses.where "responses.received_at IS NOT NULL OR responses.cancelled_at IS NOT NULL"
    elsif params[:responses] == "all"
      responses
    else
      responses.where received_at: nil, cancelled_at: nil
    end
  end
end
