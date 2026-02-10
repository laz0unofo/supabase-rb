# frozen_string_literal: true

module Supabase
  module Auth
    # Admin API for user management (requires service role key).
    # Provides methods for creating, listing, updating, deleting users,
    # inviting users, generating links, and admin sign-out.
    # Accessed via client.admin.
    class AdminApi
      def initialize(client)
        @client = client
      end

      # Creates a new user (admin).
      def create_user(**options)
        body = build_create_user_body(options)
        @client.send(:admin_request, :post, "/admin/users", body: body)
      end

      # Lists users with optional pagination.
      def list_users(page: nil, per_page: nil)
        params = build_list_params(page, per_page)
        path = "/admin/users"
        path += "?#{URI.encode_www_form(params)}" unless params.empty?
        @client.send(:admin_request, :get, path)
      end

      # Gets a user by their ID.
      def get_user_by_id(uid)
        @client.send(:admin_request, :get, "/admin/users/#{uid}")
      end

      # Updates a user by their ID.
      def update_user_by_id(uid, **attributes)
        @client.send(:admin_request, :put, "/admin/users/#{uid}", body: attributes)
      end

      # Deletes a user by their ID.
      def delete_user(uid, should_soft_delete: false)
        body = { should_soft_delete: should_soft_delete }
        @client.send(:admin_request, :delete, "/admin/users/#{uid}", body: body)
      end

      # Invites a user by email.
      def invite_user_by_email(email, data: nil, redirect_to: nil)
        body = { email: email }
        body[:data] = data if data
        body[:redirect_to] = redirect_to if redirect_to
        @client.send(:admin_request, :post, "/invite", body: body)
      end

      # Generates an email link (signup, magiclink, recovery, etc.).
      def generate_link(**options)
        body = build_generate_link_body(options)
        result = @client.send(:admin_request, :post, "/admin/generate_link", body: body)
        return result if result[:error]

        build_generate_link_result(result[:data])
      end

      # Signs out a user by their JWT (admin).
      def sign_out(jwt, scope: :global)
        @client.send(:admin_request, :post, "/logout", jwt: jwt, body: { scope: scope.to_s })
      end

      private

      def build_create_user_body(options)
        body = build_create_user_credentials(options)
        apply_create_user_metadata(body, options)
        body
      end

      def build_create_user_credentials(options)
        body = {}
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        body[:password] = options[:password] if options[:password]
        body[:ban_duration] = options[:ban_duration] if options[:ban_duration]
        body
      end

      def apply_create_user_metadata(body, options)
        body[:user_metadata] = options[:user_metadata] if options[:user_metadata]
        body[:app_metadata] = options[:app_metadata] if options[:app_metadata]
        body[:email_confirm] = options[:email_confirm] unless options[:email_confirm].nil?
        body[:phone_confirm] = options[:phone_confirm] unless options[:phone_confirm].nil?
      end

      def build_list_params(page, per_page)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page
        params
      end

      def build_generate_link_body(options)
        body = { type: options[:type], email: options[:email] }
        body[:password] = options[:password] if options[:password]
        body[:new_email] = options[:new_email] if options[:new_email]
        body[:data] = options[:data] if options[:data]
        body[:redirect_to] = options[:redirect_to] if options[:redirect_to]
        body
      end

      def build_generate_link_result(data)
        properties = extract_link_properties(data)
        { data: { properties: properties, user: data }, error: nil }
      end

      def extract_link_properties(data)
        {
          action_link: data.delete("action_link"),
          email_otp: data.delete("email_otp"),
          hashed_token: data.delete("hashed_token"),
          redirect_to: data.delete("redirect_to"),
          verification_type: data.delete("verification_type")
        }
      end
    end
  end
end
