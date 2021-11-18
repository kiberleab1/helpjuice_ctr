class ProductController < ApplicationController
    before_action :set_product, only: [:show, :destroy]
    skip_before_action :authenticate_request
    # before_action :is_admin, :only => [:index,:create,:update,:destroy]
    # before_action :is_supplier, :only => [:find_by_supplier]
    def is_admin
        @role = current_user.type.title
        if @role.eql?'super'
            @role
        else
            render json: {error: 'you are not authorized'}, status: 400
        end
    end

    def is_supplier
      @role = current_user.type.title
      if @role.eql? 'supplier'
          @role
      else
          render json: {error: 'you are not authorized'}, status: 400
      end
    end

    def index
      @page  = params.fetch(:page,0).to_i
      @product=Product.offset(@page * 8).limit(8).order(created_at: :desc).order("created_at DESC")
      render json: @product.with_attached_photo
    end

    def postProducts
      @page  = params.fetch(:page,0).to_i
      @product=Product.where("approved = true").offset(@page * 8).limit(8).order(created_at: :desc).order("created_at DESC")
      render json: @product.with_attached_photo
    end
  
    def create
      @admin = Admin.where(type_id: 1)
      @warehouse_admin = Warehouse.find_by_admin_id(params[:admin_id])
      @customer = Customer.where(type_id: 4)
      @product=Product.new(product_params)   
      if @product.save  
        @notif=NotificationAdmin.new(message:"New Product " + @product.name + " Added",admin_id:@warehouse_admin.admin_id,read: false) 
        @notif.save
        @admin.each do |admin|
          @notif=NotificationAdmin.new(message:"New Product " + @product.name + " Added",admin_id:admin.id ,read: false)
          @notif.save
        end
        @customer.each do |customer|
          # UsermailerMailer.product_email(customer.email,params[:price],params[:name]).deliver_now
          @notif=NotificationCustomer.new(message:"New Product " + @product.name + " Added",customer_id:customer.id ,read: false)
          @notif.save
        end
        render json: @product, status: 200
      else
        render json: @product.errors, status:500
      end
    end

    def product_by_category
      @page  = params.fetch(:page,0).to_i
      @product = Product.where(category_id: params[:category_id], approved: true).offset(@page * 12).limit(12).order(created_at: :desc).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def product_count
      @product = Product.all.count
      render json: @product
    end

    def product_count_category
      @product = Product.where("category_id = #{params[:id]}").count
      render json: @product
    end

    def product_count_sub_category
      @product = Product.where("sub_category_id = #{params[:id]}").count
      render json: @product
    end

    def product_count_discount
      @product = Product.where.not(idDiscounted:[false,nil]).count
      render json: @product
    end

    def product_count_featured
      @product = Product.where.not(isFeatured:[false,nil]).count
      render json: @product
    end

    def product_by_sub_category
      @page  = params.fetch(:page,0).to_i
      @product = Product.where("sub_category_id = #{params[:sub_category_id]}").offset(@page * 12).limit(12).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def top_products

      @order=Order.select(:product_id,'COUNT(product_id)').group(:product_id).order('COUNT(product_id) desc').limit(20)
      @partial_query=""
      @order.each {
        |product|
        @partial_query+=@partial_query+"id=#{product.product.id} or "
       
      }
      @partial_query=@partial_query[0...-3]
      @product=Product.where(@partial_query)
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end
    def products_by_date
      @date=Date.parse(params[:date])
      if @date
        @product=Product.where(:created_at => @date.beginning_of_day..@date.end_of_day)
        if @product
          render json: @product
        else
          render json: {error: 'error'}, status: 400
        end
      else
        render json: {error: 'error'}, status: 400
      end
    end
    def products_by_month
      @date=Date.parse(params[:date])
      if @date
        @product=Product.where(:created_at => @date.beginning_of_month.beginning_of_day..@date.end_of_month.end_of_day)
        if @product
          render json: @product
        else
          render json: {error: 'error'}, status: 400
        end
      else
        render json: {error: 'error'}, status: 400
      end
    end
    
    def filter_by_price
      @lowerRange=params[:lowerRange]
      @upperRange=params[:upperRange]
      @product=Product.where("price BETWEEN #{@lowerRange} AND #{@upperRange}")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end
    def filter_by_rate
      @lowerRange=params[:lowerRange]
      @upperRange=params[:upperRange]
      @product=Product.joins("LEFT JOIN rates ON rates.id=products.rate_id" ).where("rate BETWEEN #{@lowerRange} AND #{@upperRange}")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def product_by_warehouse_count
      @product = Product.where("warehouse_id = #{params[:warehouse_id]}").order(quantity: :ASC)
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def pending_approve_products
      @page  = params.fetch(:page,0).to_i
      @product = Product.where("approved = false").offset(@page * 20).limit(20).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def pending_products
      @page  = params.fetch(:page,0).to_i
      @product = Product.where(approved: false,price: [nil, ""]).offset(@page * 20).limit(20).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def find_by_isbn
      @product=Product.find_by(is_bn: params[:isbn])
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def featured_products
      @page  = params.fetch(:page,0).to_i
      @product = Product.where.not(isFeatured:[false,nil]).offset(@page * 16).limit(16).order(created_at: :desc).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def discounted_products
      @page  = params.fetch(:page,0).to_i
      @product = Product.where.not(idDiscounted:[false,nil]).offset(@page * 16).limit(16).order(created_at: :desc).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def product_by_name
      @page  = params.fetch(:page,0).to_i
      @product = Product.where("lower(name) LIKE :prefix", prefix: "#{params[:name.downcase]}%").offset(@page * 12).limit(12).order(created_at: :desc).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def find
      @page  = params.fetch(:page,0).to_i
      @product = Product.where("warehouse_id = #{params[:warehouse_id]}").offset(@page * 12).limit(12).order(created_at: :desc).order("created_at DESC")
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def product_warehouse_count
      @product = Product.where("warehouse_id = #{params[:warehouse_id]}").count
      if @product
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def show
      render json: @product
    end

    def find_by_supplier
      @page  = params.fetch(:page,0).to_i
      @product = Product.where("admin_id = #{params[:admin_id]}").offset(@page * 12).limit(12).order(created_at: :desc).order("created_at DESC")
      if @product
        render json: @product, status: 200
      else
        render json: {error: 'unable to find product'}, status: 400
      end
    end

    def update
      @product=Product.find(params[:id])
      if @product.update(update_params)
        render json: @product
      else
        render json: @product.errors, status:500
      end
    end

    def checkExpiredDate
      @product = Product.where('expire_date <= ?', Date.today + 6.months)
      @product = @product.where(warehouse_id: params[:warehouse_id])
      if @product
        @product.each do |product|
          @notif=NotificationAdmin.new(message:"Product " + product.name + " Expiration Date is Less than 6 Month",admin_id:product.admin_id,read: false) 
          @notif.save
        end
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def checkProductQuantity
      @product = Product.where('quantity <= ?', 0)
      @product = @product.where(warehouse_id: params[:warehouse_id])
      if @product
        @product.each do |product|
          @notif=NotificationAdmin.new(message:"Product " + product.name + " Quantity Less than 0",admin_id:product.admin_id,read: false) 
          @notif.save
        end
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def checkProductQuantityAdmin
      @admin = Admin.where(type_id: 1)
      @product = Product.where('quantity <= ?', 0)
      if @product
        @admin.each do |admin|
          @product.each do |product|
            @notif=NotificationAdmin.new(message:"Product " + product.name + " Quantity Less than 0",admin_id:admin.id,read: false) 
            @notif.save
          end
        end
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def checkExpiredDateAdmin
      @admin = Admin.where(type_id: 1)
      @page  = params.fetch(:page,0).to_i
      @product = Product.where('expire_date <= ?', Date.today + 6.months).offset(@page * 12).limit(12).order(created_at: :desc).order("created_at DESC")
      if @product
        @admin.each do |admin|
          @product.each do |product|
            @notif=NotificationAdmin.new(message:"Product " + product.name + " Expiration Date is Less than 6 Month",admin_id:admin.id,read: false) 
            @notif.save
          end
        end
        render json: @product
      else
        render json: {error: 'error'}, status: 400
      end
    end

    def destroy
      @np = NotificationProduct.where("product_id = #{params[:id]}")
      if @np
        @np.each do |np|
          np.destroy
        end
        @product.destroy
      else
        @product.destroy
      end
      head :no_content
    end
  
    def product_params
      params.permit(:name,:price,:quantity,:expire_date,:description,:category_id,:sub_category_id,:rate_id,:admin_id,:warehouse_id,:uom_id,:minimum_amount,:idDiscounted,:isFeatured,:discount_rate,:isAvailable,:maximum_price,:minimum_price,:purchase_cost,:is_bn,:shelf,:sale_id,:approved, photo: [])
    end

    def update_params
      params.permit(:name,:price,:quantity,:expire_date,:description,:category_id,:sub_category_id,:rate_id,:admin_id,:warehouse_id,:uom_id,:minimum_amount,:idDiscounted,:isFeatured,:discount_rate,:isAvailable,:maximum_price,:minimum_price,:purchase_cost,:is_bn,:shelf,:sale_id,:approved, photo: [])
    end
    
    def set_product
      @product=Product.find(params[:id])
      if @product
        @product
      else
        render json: {error: 'unable to find product'}, status:400
      end
    end
end
