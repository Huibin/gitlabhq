# frozen_string_literal: true

module API
  class ProjectSnippets < Grape::API::Instance
    include PaginationParams

    before { authenticate! }
    before { check_snippets_enabled }

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      helpers Helpers::SnippetsHelpers
      helpers do
        def check_snippets_enabled
          forbidden! unless user_project.feature_available?(:snippets, current_user)
        end

        def handle_project_member_errors(errors)
          if errors[:project_access].any?
            error!(errors[:project_access], 422)
          end

          not_found!
        end

        def snippets_for_current_user
          SnippetsFinder.new(current_user, project: user_project).execute
        end
      end

      desc 'Get all project snippets' do
        success Entities::ProjectSnippet
      end
      params do
        use :pagination
      end
      get ":id/snippets" do
        present paginate(snippets_for_current_user), with: Entities::ProjectSnippet, current_user: current_user
      end

      desc 'Get a single project snippet' do
        success Entities::ProjectSnippet
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      get ":id/snippets/:snippet_id" do
        snippet = snippets_for_current_user.find(params[:snippet_id])
        present snippet, with: Entities::ProjectSnippet, current_user: current_user
      end

      desc 'Create a new project snippet' do
        success Entities::ProjectSnippet
      end
      params do
        requires :title, type: String, allow_blank: false, desc: 'The title of the snippet'
        optional :description, type: String, desc: 'The description of a snippet'
        requires :visibility, type: String,
                              values: Gitlab::VisibilityLevel.string_values,
                              desc: 'The visibility of the snippet'
        use :create_file_params
      end
      post ":id/snippets" do
        authorize! :create_snippet, user_project
        snippet_params = declared_params(include_missing: false).tap do |create_args|
          create_args[:request] = request
          create_args[:api] = true

          process_file_args(create_args)
        end

        service_response = ::Snippets::CreateService.new(user_project, current_user, snippet_params).execute
        snippet = service_response.payload[:snippet]

        if service_response.success?
          present snippet, with: Entities::ProjectSnippet, current_user: current_user
        else
          render_spam_error! if snippet.spam?

          render_api_error!({ error: service_response.message }, service_response.http_status)
        end
      end

      desc 'Update an existing project snippet' do
        success Entities::ProjectSnippet
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
        optional :title, type: String, allow_blank: false, desc: 'The title of the snippet'
        optional :file_name, type: String, desc: 'The file name of the snippet'
        optional :content, type: String, allow_blank: false, desc: 'The content of the snippet'
        optional :description, type: String, desc: 'The description of a snippet'
        optional :visibility, type: String,
                              values: Gitlab::VisibilityLevel.string_values,
                              desc: 'The visibility of the snippet'
        at_least_one_of :title, :file_name, :content, :visibility
      end
      # rubocop: disable CodeReuse/ActiveRecord
      put ":id/snippets/:snippet_id" do
        snippet = snippets_for_current_user.find_by(id: params.delete(:snippet_id))
        not_found!('Snippet') unless snippet

        authorize! :update_snippet, snippet

        snippet_params = declared_params(include_missing: false)
          .merge(request: request, api: true)

        service_response = ::Snippets::UpdateService.new(user_project, current_user, snippet_params).execute(snippet)
        snippet = service_response.payload[:snippet]

        if service_response.success?
          present snippet, with: Entities::ProjectSnippet, current_user: current_user
        else
          render_spam_error! if snippet.spam?

          render_api_error!({ error: service_response.message }, service_response.http_status)
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Delete a project snippet'
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      delete ":id/snippets/:snippet_id" do
        snippet = snippets_for_current_user.find_by(id: params[:snippet_id])
        not_found!('Snippet') unless snippet

        authorize! :admin_snippet, snippet

        destroy_conditionally!(snippet) do |snippet|
          service = ::Snippets::DestroyService.new(current_user, snippet)
          response = service.execute

          if response.error?
            render_api_error!({ error: response.message }, response.http_status)
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Get a raw project snippet'
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ":id/snippets/:snippet_id/raw" do
        snippet = snippets_for_current_user.find_by(id: params[:snippet_id])
        not_found!('Snippet') unless snippet

        present content_for(snippet)
      end

      desc 'Get raw project snippet file contents from the repository'
      params do
        use :raw_file_params
      end
      get ":id/snippets/:snippet_id/files/:ref/:file_path/raw", requirements: { file_path: API::NO_SLASH_URL_PART_REGEX } do
        snippet = snippets_for_current_user.find_by(id: params[:snippet_id])
        not_found!('Snippet') unless snippet&.repo_exists?

        present file_content_for(snippet)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Get the user agent details for a project snippet' do
        success Entities::UserAgentDetail
      end
      params do
        requires :snippet_id, type: Integer, desc: 'The ID of a project snippet'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ":id/snippets/:snippet_id/user_agent_detail" do
        authenticated_as_admin!

        snippet = Snippet.find_by!(id: params[:snippet_id], project_id: params[:id])

        break not_found!('UserAgentDetail') unless snippet.user_agent_detail

        present snippet.user_agent_detail, with: Entities::UserAgentDetail
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
