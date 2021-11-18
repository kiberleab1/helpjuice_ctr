class OrderController < ApplicationController
    before_action :set_order, only: [:show, :update, :destroy]
    skip_before_action :authenticate_request
    #before_action :is_admin, :except => [:index,:destroy,:show,:find_by_customer]
    #before_action :is_customer, :except => [:create,:update,:destroy,:find_by_customer]

    def is_admin
        @role = current_user.type.title
        if @role == 'super'
            @role
        else
            render json: {error: 'you are not authorized'}
        end
    end

    def is_customer
        @role = current_user.type.title
        if @role == 'customer'
            @role
        else
            render json: {error: 'you are not authorized'}
        end
    end

    def index
      @page  = params.fetch(:page,0).to_i
      @order = Order.offset(@page * 10).limit(10).order(created_at: :desc)
      # @order=Order.all.order(created_at: :desc)
      render json: @order.as_json
    end

    def customer_order
      @order=Order.select(:customer_id ,'COUNT(customer_id)').group(:customer_id).order('COUNT(customer_id) desc').limit(20)
      render json: @order
    end

    def order_by_customer
      @order=Order.where("admin_id = ? and approved = true and reviwed = false",params[:admin_id]).select(:customer_id ,'COUNT(customer_id)').group(:customer_id).order('COUNT(customer_id) desc').limit(20)
      render json: @order
    end

    def product_order
      @order=Order.select(:product_id,'COUNT(product_id)').group(:product_id).order('COUNT(product_id) desc').limit(20)
      render json: @order.as_json( except: :address_id,include: { product: { except: :photo } } )
      # render json: @order.as_json(except: [:address_id,:customer_id])
    end

    def product_order_warehouse
      @order=Order.where("admin_id = ? ",params[:admin_id]).select(:product_id,'COUNT(product_id)').group(:product_id).order('COUNT(product_id) desc').limit(20)
      render json: @order.as_json( except: :address_id,include: { product: { except: :photo } } )
      # render json: @order.as_json(except: [:address_id,:customer_id])
    end
  
    def create
      @admin = Admin.where(type_id: 1)
      @warehouse_admin = Warehouse.find_by_admin_id(params[:admin_id])
      @order=Order.new(order_params)
      if @order.save
        @notif=NotificationAdmin.new(message:"New Order For Product " + @order.product_id.to_s+ " With "+@order.quantity.to_s  + " Quantity Added", admin_id: @warehouse_admin.admin_id ,read: false)
        @notif.save
        @admin.each do |admin|
          @notif=NotificationAdmin.new(message:"New Order For Product " + @order.product_id.to_s+ " With "+@order.quantity.to_s  + " Quantity Added", admin_id:admin.id ,read: false)
          @notif.save
        end
        render json: @order.as_json, status: 200
      else
        render json: {error: @order.errors}, status: 400
      end
    end

    def show
      render json: @order.as_json
    end

    def find_by_customer
        @order = Order.where("customer_id = #{params[:customer_id]}")
        if @order
            render json: @order.as_json, status: 200
        else
            render json: { error: 'unable to find order'}, status: 400
        end
    end

    def find_by_customer_approved
      @order = Order.where("customer_id = ? and approved = true  and reviwed = false", params[:customer_id])
      if @order
          render json: @order.as_json, status: 200
      else
          render json: { error: 'unable to find order'}, status: 400
      end
    end

    def count_product
      @order = Order.where("product_id = #{params[:product_id]}").count
      if @order
          render json: @order
      else
          render json: { error: 'unable to find order'}, status: 400
      end
    end

    def order_monthly
      day_month = Date.current.beginning_of_month
      @orders=Array.new
      for days in 0..29 do
        @orders_day=Order.where('updated_at BETWEEN ? AND ?',day_month+0.day,day_month+1.day).order(:updated_at)
       # @orders_day= Order.where('updated_at BETWEEN ? AND ?',day_month.day, day_month+1.day).order(:updated_at)
       if @orders_day.length!=0 
        @quantity=@orders_day.sum(:quantity)
        @total_price=@orders_day.sum(:total_price)
        @orders_day[0].total_price=@total_price
        @orders_day[0].quantity=@quantity
        @orders << @orders_day[0]
       end
       day_month=day_month+1.day
      end
     ## @orders=Order.where('updated_at BETWEEN ? AND ?',day_month+2.day,day_month+4.day).order(:updated_at)
      render json: @orders.to_json
    end

    def order_monthly_warehouse
      day_month = Date.current.beginning_of_month
      @orders=Array.new
      # @orders_day = Order.where("admin_id = #{params[:admin_id]}" )
      for days in 0..29 do
        @orders_day=Order.where('admin_id = ? and updated_at BETWEEN ? AND ?',params[:admin_id],day_month+0.day,day_month+1.day).order(:updated_at)
       # @orders_day= Order.where('updated_at BETWEEN ? AND ?',day_month.day, day_month+1.day).order(:updated_at)
        if @orders_day.length!=0 
          @quantity=@orders_day.sum(:quantity)
          @total_price=@orders_day.sum(:total_price)
          @orders_day[0].total_price=@total_price
          @orders_day[0].quantity=@quantity
          @orders << @orders_day[0]
       end
        day_month=day_month+1.day
      end
     ## @orders=Order.where('updated_at BETWEEN ? AND ?',day_month+2.day,day_month+4.day).order(:updated_at)
      render json: @orders.to_json
    end

    def sells_monthly
      day_month = Date.current.beginning_of_month
      @orders=Array.new
      for days in 0..29 do
        @sells=Sell.where('updated_at BETWEEN ? AND ?',day_month+0.day,day_month+1.day).order(:updated_at)
        if @sells.length!=0
          @order=Order.where("id = #{@sells[0].order_id}").first
          for i in 1..@sells.length-1 do
            if @sells.length!=0
              @ord=Order.where("id = #{@sells[i].order_id}").first
              @total_price=@ord.total_price
              @order.total_price=@order.total_price+@total_price
            end
          end
          @orders << @order
        end 
        
        
        day_month=day_month+1.day
      end
      render json: @orders.to_json
    end

    def sells_monthly_warehouse
      day_month = Date.current.beginning_of_month
      @orders=Array.new
      @sells = Sell.where("admin_id = #{params[:admin_id]}")
      for days in 0..29 do
        @sells=@sells.where('updated_at BETWEEN ? AND ?',day_month+0.day,day_month+1.day).order(:updated_at)
        if @sells.length!=0
          @order=Order.where("id = #{@sells[0].order_id}").first
          for i in 1..@sells.length-1 do
            if @sells.length!=0
              @ord=Order.where("id = #{@sells[i].order_id}").first
              @total_price=@ord.total_price
              @order.total_price=@order.total_price+@total_price
            end
          end
          @orders << @order
        end 
        
        
        day_month=day_month+1.day
      end
      render json: @orders.to_json
    end

    def count_order
      @order=Order.select('COUNT(created_at)').group(:created_at)
      render json: @order
    end

    def order_products
      @order = Order.select(:product_id,:address_id,:customer_id).distinct(:product_id)
      render json: @order.as_json
    end

    def order_count
      @product = Order.all.count
      render json: @product
    end

    def uniqe_product
      @order = Order.all.group_by(&:product_id).count
      if @order
          render json: @order.as_json
      else
          render json: { error: 'unable to find order'}, status: 400
      end
    end

    def supplier_order
      @page  = params.fetch(:page,0).to_i
      @order = Order.where("admin_id = #{params[:admin_id]}","approved = true").offset(@page * 5).limit(5).order(created_at: :desc)
      if @order
          render json: @order.as_json
      else
          render json: { error: 'unable to find order'}, status: 400
      end
    end

    def warehouse_order_report
      @order = Order.where("admin_id = #{params[:admin_id]}","approved = true").order(created_at: :desc)
      if @order
          render json: @order.as_json
      else
          render json: { error: 'unable to find order'}, status: 400
      end
    end

    def sale_order
      @page  = params.fetch(:page,0).to_i
      @order = Order.where("sale_id = #{params[:sale_id]}").offset(@page * 15).limit(15).order(created_at: :desc)
      if @order
          render json: @order.as_json
      else
          render json: { error: 'unable to find order'}, status: 400
      end
    end

    def update
      if @order.update(update_params)
        render json: @order.as_json
      else
        Rails.logger.info(@order.errors.messages.inspect)
      end
    end

    def destroy
      @order.destroy
      head :no_content
    end
  
    def order_params
      params.permit(:quantity,:total_price,:customer_id,:uom,:product_id,:sale_id,:address_id,:approved,:admin_id,:size,:color,:transaction_type,:transaction_id,:reviwed)
    end

    def update_params
      params.permit(:reviwed,:approved)
    end

    def set_order
      @order=Order.find(params[:id])
      if @order
        @order
      else
        render json: {error: 'unable to find Order'}, status: 400
      end
    end

end
