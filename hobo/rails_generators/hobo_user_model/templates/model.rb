class <%= class_name %> < ActiveRecord::Base

  hobo_user_model # Don't put anything above this

  fields do
    name :string, :unique
    email_address :email_address, :login => true
    administrator :boolean, :default => false
    timestamps
  end

  # This gives admin rights to the first sign-up.
  # Just remove it if you don't want that
  before_create { |user| user.administrator = true if !Rails.env.test? && count == 0 }

<% if invite_only? -%>
  validates_confirmation_of :password,              :if => "User.count == 0"
<% end -%>
  
  # --- Signup lifecycle --- #

  lifecycle do

<% if invite_only? -%>
    state :invited, :default => true
    state :active

    create :invite,
           :available_to => "acting_user if acting_user.administrator?",
           :params => [:name, :email_address],
           :new_key => true,
           :become => :invited do
       UserMailer.deliver_invite(self, lifecycle.key)
    end
  
    transition :accept_invitation, { :invited => :active }, :available_to => :key_holder,
               :params => [ :password, :password_confirmation ]
  
<% else -%>
    state :active, :default => true

    create :signup, :available_to => "Guest",
           :params => [:name, :email_address, :password, :password_confirmation],
           :become => :active
             
<% end -%>
    transition :request_password_reset, { :active => :active }, :new_key => true do
      <%= class_name %>Mailer.deliver_forgot_password(self, lifecycle.key)
    end

    transition :reset_password, { :active => :active }, :available_to => :key_holder,
               :params => [ :password, :password_confirmation ]

  end
  

  # --- Permissions --- #

  def create_permitted?
<% if invite_only? -%>
    # Only the initial admin user can be created, from there it's invite-only
    User.count == 0
<% else -%>
    false
<% end -%>
  end

  def update_permitted?
    acting_user.administrator? || (acting_user == self && only_changed?(:crypted_password, :email_address))
    # Note: crypted_password has attr_protected so although it is permitted to change, it cannot be changed
    # directly from a form submission.
  end

  def destroy_permitted?
    acting_user.administrator?
  end

  def view_permitted?(field)
    true
  end

end
