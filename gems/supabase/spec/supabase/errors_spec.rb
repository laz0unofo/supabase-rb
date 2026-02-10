# frozen_string_literal: true

RSpec.describe "Supabase Error Hierarchy" do
  # ---------------------------------------------------------------------------
  # Supabase::Error (base)
  # ---------------------------------------------------------------------------
  describe Supabase::Error do
    it "inherits from StandardError" do
      expect(described_class.superclass).to eq(StandardError)
    end

    it "stores message and context" do
      error = described_class.new("something failed", context: { detail: "info" })
      expect(error.message).to eq("something failed")
      expect(error.context).to eq({ detail: "info" })
    end

    it "defaults context to nil" do
      error = described_class.new("oops")
      expect(error.context).to be_nil
    end

    it "can be instantiated with no arguments" do
      error = described_class.new
      expect(error.message).to eq("Supabase::Error")
      expect(error.context).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Supabase::ApiError
  # ---------------------------------------------------------------------------
  describe Supabase::ApiError do
    it "inherits from Supabase::Error" do
      expect(described_class.superclass).to eq(Supabase::Error)
    end

    it "stores message, status, and context" do
      error = described_class.new("Not found", status: 404, context: "resp")
      expect(error.message).to eq("Not found")
      expect(error.status).to eq(404)
      expect(error.context).to eq("resp")
    end

    it "defaults status and context to nil" do
      error = described_class.new("err")
      expect(error.status).to be_nil
      expect(error.context).to be_nil
    end

    it "is a Supabase::Error" do
      expect(described_class.new).to be_a(Supabase::Error)
    end

    it "is a StandardError" do
      expect(described_class.new).to be_a(StandardError)
    end
  end

  # ---------------------------------------------------------------------------
  # Supabase::NetworkError
  # ---------------------------------------------------------------------------
  describe Supabase::NetworkError do
    it "inherits from Supabase::Error" do
      expect(described_class.superclass).to eq(Supabase::Error)
    end

    it "stores message, status, and context" do
      error = described_class.new("timeout", status: 0, context: "ex")
      expect(error.message).to eq("timeout")
      expect(error.status).to eq(0)
      expect(error.context).to eq("ex")
    end

    it "defaults status and context to nil" do
      error = described_class.new("err")
      expect(error.status).to be_nil
      expect(error.context).to be_nil
    end

    it "is a Supabase::Error" do
      expect(described_class.new).to be_a(Supabase::Error)
    end

    it "is a StandardError" do
      expect(described_class.new).to be_a(StandardError)
    end
  end

  # ---------------------------------------------------------------------------
  # Legacy alias
  # ---------------------------------------------------------------------------
  describe "SupabaseError alias" do
    it "is the same class as Supabase::Error" do
      expect(Supabase::SupabaseError).to eq(Supabase::Error)
    end
  end

  # ---------------------------------------------------------------------------
  # AuthNotAvailableError
  # ---------------------------------------------------------------------------
  describe Supabase::AuthNotAvailableError do
    it "inherits from Supabase::Error" do
      expect(described_class.superclass).to eq(Supabase::Error)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-gem hierarchy: all gem base errors inherit from Supabase::Error
  # ---------------------------------------------------------------------------
  describe "gem base errors inherit from Supabase::Error" do
    it "Auth::AuthError is a Module and AuthBaseError is a Supabase::Error" do
      expect(Supabase::Auth::AuthError).to be_a(Module)
      expect(Supabase::Auth::AuthBaseError.new).to be_a(Supabase::Error)
      expect(Supabase::Auth::AuthBaseError.new).to be_a(Supabase::Auth::AuthError)
    end

    it "Storage::StorageError is a Module and StorageBaseError is a Supabase::Error" do
      expect(Supabase::Storage::StorageError).to be_a(Module)
      expect(Supabase::Storage::StorageBaseError.new).to be_a(Supabase::Error)
      expect(Supabase::Storage::StorageBaseError.new).to be_a(Supabase::Storage::StorageError)
    end

    it "PostgREST::PostgrestError is a Supabase::Error" do
      expect(Supabase::PostgREST::PostgrestError.new).to be_a(Supabase::Error)
    end

    it "Functions::FunctionsError is a Module and FunctionsBaseError is a Supabase::Error" do
      expect(Supabase::Functions::FunctionsError).to be_a(Module)
      expect(Supabase::Functions::FunctionsBaseError.new).to be_a(Supabase::Error)
      expect(Supabase::Functions::FunctionsBaseError.new).to be_a(Supabase::Functions::FunctionsError)
    end

    it "Realtime::RealtimeError is a Supabase::Error" do
      expect(Supabase::Realtime::RealtimeError.new).to be_a(Supabase::Error)
    end
  end

  # ---------------------------------------------------------------------------
  # Attribute preservation: gem-specific errors retain their attributes
  # ---------------------------------------------------------------------------
  describe "attribute preservation" do
    it "Auth::AuthApiError preserves status and code" do
      error = Supabase::Auth::AuthApiError.new("msg", status: 422, code: "weak_password")
      expect(error.status).to eq(422)
      expect(error.code).to eq("weak_password")
      expect(error.context).to be_nil
    end

    it "Auth::AuthWeakPasswordError preserves reasons" do
      error = Supabase::Auth::AuthWeakPasswordError.new(
        "weak", status: 422, code: "weak", reasons: ["too short"]
      )
      expect(error.reasons).to eq(["too short"])
      expect(error.status).to eq(422)
      expect(error.code).to eq("weak")
    end

    it "Storage::StorageApiError preserves status and context" do
      error = Supabase::Storage::StorageApiError.new("bad", status: 400, context: "resp")
      expect(error.status).to eq(400)
      expect(error.context).to eq("resp")
    end

    it "PostgREST::PostgrestError preserves details, hint, and code" do
      error = Supabase::PostgREST::PostgrestError.new("msg", details: "det", hint: "hnt", code: "42P01")
      expect(error.details).to eq("det")
      expect(error.hint).to eq("hnt")
      expect(error.code).to eq("42P01")
    end

    it "Functions::FunctionsRelayError preserves status" do
      error = Supabase::Functions::FunctionsRelayError.new("relay err", status: 502)
      expect(error.status).to eq(502)
    end

    it "Realtime::RealtimeConnectionError preserves status" do
      error = Supabase::Realtime::RealtimeConnectionError.new("conn err", status: 500)
      expect(error.status).to eq(500)
    end
  end
end
