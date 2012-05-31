# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)
require 'my_controller'

# Re-raise errors caught by the controller.
class MyController; def rescue_action(e) raise e end; end

class MyControllerTest < ActionController::TestCase
  fixtures :users, :user_preferences, :roles, :projects, :issues, :issue_statuses, :trackers, :enumerations, :custom_fields

  def setup
    @controller = MyController.new
    @request    = ActionController::TestRequest.new
    @request.session[:user_id] = 2
    @response   = ActionController::TestResponse.new
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'page'
  end

  def test_page
    get :page
    assert_response :success
    assert_template 'page'
  end

  def test_my_account_should_show_editable_custom_fields
    get :account
    assert_response :success
    assert_template 'account'
    assert_equal User.find(2), assigns(:user)

    assert_tag :input, :attributes => { :name => 'user[custom_field_values][4]'}
  end

  def test_my_account_should_not_show_non_editable_custom_fields
    UserCustomField.find(4).update_attribute :editable, false

    get :account
    assert_response :success
    assert_template 'account'
    assert_equal User.find(2), assigns(:user)

    assert_no_tag :input, :attributes => { :name => 'user[custom_field_values][4]'}
  end

  def test_update_account
    post :account,
      :user => {
        :firstname => "Joe",
        :login => "root",
        :admin => 1,
        :group_ids => ['10'],
        :custom_field_values => {"4" => "0100562500"}
      }

    assert_redirected_to '/my/account'
    user = User.find(2)
    assert_equal user, assigns(:user)
    assert_equal "Joe", user.firstname
    assert_equal "jsmith", user.login
    assert_equal "0100562500", user.custom_value_for(4).value
    # ignored
    assert !user.admin?
    assert user.groups.empty?
  end

  def test_my_account_should_show_destroy_link
    get :account
    assert_select 'a[href=/my/account/destroy]'
  end

  def test_get_destroy_should_display_the_destroy_confirmation
    get :destroy
    assert_response :success
    assert_template 'destroy'
    assert_select 'form[action=/my/account/destroy]' do
      assert_select 'input[name=confirm]'
    end
  end

  def test_post_destroy_without_confirmation_should_not_destroy_account
    assert_no_difference 'User.count' do
      post :destroy
    end
    assert_response :success
    assert_template 'destroy'
  end

  def test_post_destroy_without_confirmation_should_destroy_account
    assert_difference 'User.count', -1 do
      post :destroy, :confirm => '1'
    end
    assert_redirected_to '/'
    assert_match /deleted/i, flash[:notice]
  end

  def test_post_destroy_with_unsubscribe_not_allowed_should_not_destroy_account
    User.any_instance.stubs(:own_account_deletable?).returns(false)

    assert_no_difference 'User.count' do
      post :destroy, :confirm => '1'
    end
    assert_redirected_to '/my/account'
  end

  def test_change_password
    get :password
    assert_response :success
    assert_template 'password'

    # non matching password confirmation
    post :password, :password => 'jsmith',
                    :new_password => 'hello',
                    :new_password_confirmation => 'hello2'
    assert_response :success
    assert_template 'password'
    assert_error_tag :content => /Password doesn't match confirmation/

    # wrong password
    post :password, :password => 'wrongpassword',
                    :new_password => 'hello',
                    :new_password_confirmation => 'hello'
    assert_response :success
    assert_template 'password'
    assert_equal 'Wrong password', flash[:error]

    # good password
    post :password, :password => 'jsmith',
                    :new_password => 'hello',
                    :new_password_confirmation => 'hello'
    assert_redirected_to '/my/account'
    assert User.try_to_login('jsmith', 'hello')
  end

  def test_page_layout
    get :page_layout
    assert_response :success
    assert_template 'page_layout'
  end

  def test_add_block
    xhr :post, :add_block, :block => 'issuesreportedbyme'
    assert_response :success
    assert User.find(2).pref[:my_page_layout]['top'].include?('issuesreportedbyme')
  end

  def test_remove_block
    xhr :post, :remove_block, :block => 'issuesassignedtome'
    assert_response :success
    assert !User.find(2).pref[:my_page_layout].values.flatten.include?('issuesassignedtome')
  end

  def test_order_blocks
    xhr :post, :order_blocks, :group => 'left', 'list-left' => ['documents', 'calendar', 'latestnews']
    assert_response :success
    assert_equal ['documents', 'calendar', 'latestnews'], User.find(2).pref[:my_page_layout]['left']
  end

  def test_reset_rss_key_with_existing_key
    @previous_token_value = User.find(2).rss_key # Will generate one if it's missing
    post :reset_rss_key

    assert_not_equal @previous_token_value, User.find(2).rss_key
    assert User.find(2).rss_token
    assert_match /reset/, flash[:notice]
    assert_redirected_to '/my/account'
  end

  def test_reset_rss_key_without_existing_key
    assert_nil User.find(2).rss_token
    post :reset_rss_key

    assert User.find(2).rss_token
    assert_match /reset/, flash[:notice]
    assert_redirected_to '/my/account'
  end

  def test_reset_api_key_with_existing_key
    @previous_token_value = User.find(2).api_key # Will generate one if it's missing
    post :reset_api_key

    assert_not_equal @previous_token_value, User.find(2).api_key
    assert User.find(2).api_token
    assert_match /reset/, flash[:notice]
    assert_redirected_to '/my/account'
  end

  def test_reset_api_key_without_existing_key
    assert_nil User.find(2).api_token
    post :reset_api_key

    assert User.find(2).api_token
    assert_match /reset/, flash[:notice]
    assert_redirected_to '/my/account'
  end
end
