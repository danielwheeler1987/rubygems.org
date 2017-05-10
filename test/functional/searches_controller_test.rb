require 'test_helper'
include ESHelper

class SearchesControllerTest < ActionController::TestCase
  context 'on GET to show with no search parameters' do
    setup { get :show }

    should respond_with :success
    should "see no results" do
      refute page.has_content?("Results")
    end
  end

  context 'on GET to show with search parameters for a rubygem without versions' do
    setup do
      @sinatra = create(:rubygem, name: "sinatra")
      import_and_refresh
      assert_nil @sinatra.versions.most_recent
      assert @sinatra.reload.versions.count.zero?
      get :show, params: { query: "sinatra" }
    end

    should respond_with :success
    should "see no results" do
      refute page.has_content?("Results")
    end
  end

  context 'on GET to show with search parameters' do
    setup do
      @sinatra = create(:rubygem, name: "sinatra")
      @sinatra_redux = create(:rubygem, name: "sinatra-redux")
      @brando = create(:rubygem, name: "brando")
      create(:version, rubygem: @sinatra)
      create(:version, rubygem: @sinatra_redux)
      create(:version, rubygem: @brando)
      import_and_refresh
      get :show, params: { query: "sinatra" }
    end

    should respond_with :success
    should "see sinatra on the page in the results" do
      assert page.has_content?(@sinatra.name)
      assert page.has_selector?("a[href='#{rubygem_path(@sinatra)}']")
    end
    should "not see brando on the page in the results" do
      refute page.has_content?(@brando.name)
      refute page.has_selector?("a[href='#{rubygem_path(@brando)}']")
    end
    should "display 'gems' in pagination summary" do
      assert page.has_content?("all 2 gems")
    end
  end

  context 'on GET to show with search parameters and ES enabled' do
    setup do
      @sinatra = create(:rubygem, name: 'sinatra')
      @sinatra_redux = create(:rubygem, name: 'sinatra-redux')
      @brando = create(:rubygem, name: 'brando')
      create(:version, rubygem: @sinatra)
      create(:version, rubygem: @sinatra_redux)
      create(:version, rubygem: @brando)
      import_and_refresh
      @request.cookies['new_search'] = 'true'
      get :show, params: { query: 'sinatra' }
    end

    should respond_with :success
    should "see sinatra on the page in the results" do
      page.assert_text(@sinatra.name)
      page.assert_selector("a[href='#{rubygem_path(@sinatra)}']")
    end
    should "not see brando on the page in the results" do
      page.assert_no_text(@brando.name)
      page.assert_no_selector("a[href='#{rubygem_path(@brando)}']")
    end
    should "display pagination summary" do
      page.assert_text('all 2 gems')
    end
    should "not see suggestions" do
      page.assert_no_text('Maybe you mean')
      page.assert_no_selector('.search-suggestions')
    end
  end

  context 'on GET to show with search parameters with a single exact match' do
    setup do
      @sinatra = create(:rubygem, name: "sinatra")
      create(:version, rubygem: @sinatra)
      import_and_refresh
      get :show, params: { query: "sinatra" }
    end

    should respond_with :redirect
    should redirect_to('the gem') { rubygem_path(@sinatra) }
  end

  context 'on GET to show with non string search parameter' do
    setup do
      get :show, params: { query: { foo: "bar" } }
    end

    should respond_with :success
    should "see no results" do
      refute page.has_content?("Results")
    end
  end

  context 'on GET to show with search parameters and no results' do
    setup do
      @sinatra = create(:rubygem, name: "sinatra")
      @sinatra_redux = create(:rubygem, name: "sinatra-redux")
      @brando = create(:rubygem, name: "brando")
      create(:version, rubygem: @sinatra)
      create(:version, rubygem: @sinatra_redux)
      create(:version, rubygem: @brando)
      import_and_refresh
      @request.cookies['new_search'] = 'true'
      get :show, params: { query: "sinatre" }
    end

    should respond_with :success
    should "see sinatra on the page in the suggestions" do
      page.assert_text('Maybe you mean')
      assert page.find('.search__suggestions').has_content?(@sinatra.name)
      assert page.has_selector?("a[href='#{search_path(query: @sinatra.name)}']")
    end
    should "not see sinatra on the page in the results" do
      page.assert_no_selector("a[href='#{rubygem_path(@sinatra)}']")
    end
    should "not see brando on the page in the results" do
      page.assert_no_text(@brando.name)
      page.assert_no_selector("a[href='#{rubygem_path(@brando)}']")
    end
  end

  context "with elasticsearch down" do
    setup do
      @sinatra = create(:rubygem, name: "sinatra")
      @sinatra_redux = create(:rubygem, name: "sinatra-redux")
      create(:version, rubygem: @sinatra)
      create(:version, rubygem: @sinatra_redux)
    end
    should "fallback to legacy search" do
      requires_toxiproxy
      Toxiproxy[:elasticsearch].down do
        @request.cookies['new_search'] = 'true'
        get :show, params: { query: 'sinatra' }
        assert_response :success
        assert page.has_content?('Advanced search is currently unavailable. Falling back to legacy search.')
        assert page.has_content?('Displaying')
      end
    end
  end

  context "with page greater than 100" do
    setup { get :show, page: 204 }

    should "render 404 page" do
      assert_response :not_found
    end
  end
end
