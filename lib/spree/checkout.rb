# Custom logic to be included in OrdersController.  It has intentionally been isolated in its own library to make it 
# easier for developers to customize the checkout process.
module Spree::Checkout

  def checkout


    unless request.get?                 # the proper processing
    

      begin
        # need to check valid b/c we dump the creditcard info while saving
        if @order.valid?                       
          if params[:final_answer].blank?
            @order.save
          else                                           
            # now fetch the CC info and do the authorization
            @order.creditcard = Creditcard.new params[:order][:creditcard]
            @order.creditcard.address = @order.bill_address 
            @order.creditcard.order = @order;
            @order.creditcard.authorize(@order.total)

            @order.complete
            session[:order_id] = nil 
          end
        else
          flash.now[:error] = t("unable_to_save_order")  
          render :action => "checkout" and return unless request.xhr?
        end       
      rescue Spree::GatewayError => ge
        flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
        render :action => "checkout" and return 
      end
      

      respond_to do |format|
        format.html do  
          flash[:notice] = t('order_processed_successfully')
          order_params = {:checkout_complete => true}
          order_params[:order_token] = @order.token unless @order.user
          redirect_to order_url(@order, order_params)
        end
        format.js {render :json => { :order_total => number_to_currency(@order.total), 
                                     :ship_amount => number_to_currency(@order.ship_amount), 
                                     :tax_amount => number_to_currency(@order.tax_amount),
                                     :available_methods => rate_hash}.to_json,
                          :layout => false}
      end
      
    end
  end
end
